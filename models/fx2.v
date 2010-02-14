/**
 * Copyright (C) 2009 Ubixum, Inc. 
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 **/


module fx2
  (
   input clk,
   
   output fx2_ifclk,
   output fx2_clkout,
   
   output fx2_hics_b,
   output [2:0] fx2_flags,
   input fx2_sloe_b,
   input fx2_slrd_b,
   input fx2_slwr_b,
   input fx2_slcs_b,
   input fx2_pktend_b,
   input [1:0] fx2_fifo_addr,
   inout [15:0] fx2_fd,
   
   inout SCL,
   inout SDA
   );

   reg sloe_b;
   reg hics_b             /* verilator public */;
   reg [15:0] rbuf[0:255] /* verilator public */;
   reg [8:0]  rptr        /* verilator public */;
   reg rdone              /* verilator public */;
   reg [15:0] wbuf[0:255] /* verilator public */;
   reg [8:0]  wptr        /* verilator public */;
   reg [8:0]  wend        /* verilator public */;
   reg [15:0] datao       /* verilator public */;
   reg empty_b            /* verilator public */;
   reg full_b             /* verilator public */;

   assign SCL = 1'bz;
   assign SDA = 1'bz;

   assign fx2_ifclk  = !clk; // invert clk
   assign fx2_clkout = clk;
   assign fx2_hics_b = hics_b;
   
   wire slrd_b    = fx2_slrd_b | (fx2_fifo_addr != 0);
   wire slwr_b    = fx2_slwr_b | (fx2_fifo_addr != 2);

   wire [15:0] datao1 = (fx2_fifo_addr == 0) ? datao : 0;

   assign fx2_flags = { 1'b0, full_b, empty_b };
   assign fx2_fd = (sloe_b) ? 16'hZZZZ : datao1;
   wire [15:0] fd_in = fx2_fd;
   
   always @(posedge clk) begin
      sloe_b  <= fx2_sloe_b;
      
      empty_b <= !((wptr >= wend) || (!slrd_b && wptr+1 == wend));
      if(!slrd_b && (wptr <= wend)) begin
         wptr  <= wptr + 1;
         datao <= wbuf[wptr + 1];
      end

      full_b = !(rptr > 255-4);
      if(!slwr_b && (rptr <= 255)) begin
         rbuf[rptr[7:0]] <= fd_in;
         rptr <= rptr + 1;
      end

      if(!fx2_pktend_b) begin
         rdone <= 1;
      end
   end

   initial begin
      hics_b=1;
      rptr=0;
      rdone=0;
      wptr=0;
      wend=0;
      datao=0;
   end

`ifndef verilator
/***********************************************************/
/********************** GENERIC VERILOG MODEL **************/
/***********************************************************/
   
    integer i;
    integer txcount;
    integer rxcount;

    parameter RDWR_BUF_SIZE = 1024; // default size. Override at instanteation for larger read/writes.
    
    // final destination buffer for reads and writes
    reg [7:0] rdwr_data_buf[0:RDWR_BUF_SIZE-1];
    reg [31:0] rdwr_data_cur; 

   /**
    * each io call sends a command to the FPGA
    **/
   task _sendcmd;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [7:0]  cmd;
      input [31:0] length;
      begin
	 
	 hics_b=1;
	 repeat (50) @(posedge clk);
	 hics_b=0;
	 repeat (20) @(posedge clk);
	 wbuf[0] = { 8'hc3, cmd };
	 wbuf[1] = term_addr;
	 wbuf[2] = reg_addr[15:0];
	 wbuf[3] = reg_addr[31:16];
	 wbuf[4] = length[15:0];
	 wbuf[5] = length[31:16];
	 wbuf[6] = 0; // reserved
	 wbuf[7] = 16'haa55; // ack
	 datao=wbuf[0];
	 wend = 8;
	 wptr = 0;
	 rptr = 0;
	 rdone = 0;
	 
	 repeat (3) @(posedge clk);
      end
   endtask


   /**
    * Simulate an FX2 get command.
    **/
   task get;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      output [15:0] value;
      begin
	 read(term_addr,reg_addr, 2);
	 value = { rdwr_data_buf[1], rdwr_data_buf[0] };
      end
   endtask

   // Get a register wider than 16b. specify the width of the register in
   // in bits and this will loop through starting at 'reg_addr' doing 16b
   // gets until it has retrieved all words in the wide register. Return
   // value has a max of 1024 bits.
   task getW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      output [1023:0] value;
      integer 	     wcount;
      begin
	 value = 0;//clear out the return value first
	 for(wcount=0; wcount<width; wcount=wcount+16) begin // loop through reg
	    read(term_addr,reg_addr+(wcount/16), 2);
	    value = value | ({ rdwr_data_buf[1], rdwr_data_buf[0] } << wcount);
	    `ifdef DEBUG_FX2 
	    $display("%d getW: wcount=%d buf[0]=0x%x buf[1]=0x%x",$time, wcount, rdwr_data_buf[0], rdwr_data_buf[1]);
	    
	    `endif
	 end
	`ifdef DEBUG_FX2 
	 $display("%d getW: value=0x%x",$time, value);
	`endif
      end
   endtask


   
   /**
    * Simulate an FX2 set command
    **/
   task set;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [15:0] value;
      begin
	 rdwr_data_cur=0; 
	 rdwr_data_buf[0] = value[7:0];
	 rdwr_data_buf[1] = value[15:8];
	 write(term_addr,reg_addr,2);
      end
   endtask

   // Set a wide register. See getW() documentation.
   task setW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      input [1023:0] value;
      integer 	     wcount;
      for(wcount=0; wcount<width; wcount=wcount+16) begin
	 rdwr_data_cur=0; 
	 rdwr_data_buf[0] = 8'hFF & (value >> wcount);
	 rdwr_data_buf[1] = 8'hFF & (value >> (wcount+8));
	 write(term_addr,reg_addr+(wcount/16),2);
      end
   endtask


   /**
    * Simulate an FX2 read command
    **/
   task read;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] length;
      begin
	 _sendcmd( term_addr, reg_addr, 1, length ); 
	 rxcount = 0;
	 while(rxcount < length + 4) begin 
	    if(rdone || (full_b==0)) begin 
               repeat (10) @(posedge clk);

               for(i=0; i<rptr; i=i+1) begin 
		  rdwr_data_buf[rxcount] = rbuf[i][7:0];
		  rdwr_data_buf[rxcount+1] = rbuf[i][15:8];
		  rxcount = rxcount + 2;
               end 
               rdone = 0;
               rptr  = 0;
	    end 
	    @(posedge clk);
	    
	    //if(main_time >= timeout_time) {
	    //  free(rx_data);                         
	    //  throw Exception(USB_COMM, "Timed out");
	    //}
	 end 
      end
   endtask

   /**
    * Simulate an FX2 write command
    **/
   task write;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] length;
      begin
	 
	 _sendcmd ( term_addr, reg_addr, 2, length );
	 txcount = 0;
	 
	 while (txcount < length) begin
            while ( empty_b ) begin
	       @(posedge clk);
            end
	    for (i=0;i<256 && txcount < length; i=i+1) begin
               wbuf[i] = { rdwr_data_buf[txcount+1] , rdwr_data_buf[txcount] };
               txcount = txcount + 2;
	    end
	    datao = wbuf[0];
	    wptr = 0;
	    wend = i;

	    repeat(4) @(posedge clk);
	 end

	 // wait for ack
	 while (rptr < 4) begin
	    @(posedge clk);
	 end
	 
	 repeat (10) @(posedge clk);
      end
   endtask

`else 
/***********************************************************/
/********************** VERILATOR CODE *********************/
/***********************************************************/

 `systemc_header
#ifndef FX2_H
#define FX2_H

#include "verilated.h"
#include "nitro.h"
#include <limits.h>

using namespace Nitro;
enum {
  READ_CMD=1,
  WRITE_CMD=2
};

extern void advance_clk(unsigned int cycles);
extern unsigned int main_time;

class FX2Device : public Device {
private:

   
    void send_cmd(int cmd, int term, int reg, int len) {

    *hics_b  = 1;
    advance_clk(50);
    *hics_b  = 0;
    advance_clk(20);

    wbuf[0] = 0xC300 | (cmd & 0xFF);
    wbuf[1] = term;
    wbuf[2] = reg & 0xFFFF;
    wbuf[3] = (reg >> 16) & 0xFFFF;
    wbuf[4] = len & 0xFFFF;
    wbuf[5] = (len >> 16) & 0xFFFF;
    wbuf[6]= 0;
    wbuf[7]= 0xAA55;
    *datao  = wbuf[0];
    *wend   = 8;
    *wptr   = 0;
    *rptr   = 0;
    *rdone  = 0;

    advance_clk(20);
  }

  uint32_t get_timeout_time(uint32_t timeout) {
    uint32_t timeout_time;
    if(timeout == 0) { 
      timeout_time = UINT_MAX;
    } else {
      timeout_time = main_time + (timeout * 1000); // this scale factor is arbitrary
    }
    return timeout_time;
  }

protected:
  DataType _get(uint32 terminal_addr, uint32 reg_addr, uint32 timeout ) {
    uint16 val;
    uint32_t timeout_time = get_timeout_time(timeout);
    if(reg_addr == 4 and terminal_addr == 6) {// hack to pass firmware version
       return DataType( static_cast<uint32>(512));
    }					      
    _read(terminal_addr, reg_addr, (uint8*) (&val), 2, timeout);
    return DataType( static_cast<uint32>((uint32) val));
  }

  void _read( uint32 terminal_addr, uint32 reg_addr, uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    send_cmd(READ_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);

    size_t rx_count = 0;
    uint16 *rx_data = (uint16 *) malloc(length + 8);

    while(rx_count < length/2 + 4) {
      if(*rdone || (*full_b==0)) {
        advance_clk(10);
        for(int pos=0; pos<*rptr; pos++) {
          rx_data[rx_count] = rbuf[pos];
          rx_count++;
        }
        *rdone = 0;
        *rptr  = 0;
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        free(rx_data);                         
        throw Exception(USB_COMM, "Timed out");
      }
    }
    // copy rx_data into data buffer and separate out the training ack
    uint16 checksum=0;
    for(int pos=0; pos<length/2; pos++) {
       ((uint16*)data)[pos] = rx_data[pos];
       checksum += rx_data[pos];       
    }

    uint16 *ack_buf = rx_data + length/2;
    char msg[256];
    if(ack_buf[0] != 0xA50F) {
      free(rx_data);                           
      throw Exception(USB_COMM, "Unexpected ack code returns");
    }
    // check checksum
    checksum = checksum & 0xFFFF;
    if(ack_buf[1] != checksum) {
      free(rx_data);                           
      sprintf(msg, "Checksum mismatch: 0x%04x/0x%04x", ack_buf[1], checksum);
      throw Exception(USB_COMM, msg);
    }
    // check status word
    if(ack_buf[2] != 0) {
      int err = ack_buf[2];			 
      free(rx_data);
      sprintf(msg, "Non-zero ACK status 0x%x (%d) returned.", err, err);
      throw Exception(USB_COMM, msg, err);
    }

    advance_clk(1);
    free(rx_data);                             
  }

  void _set(uint32 terminal_addr, uint32 reg_addr, const DataType& type, uint32 timeout ) {
    uint16 data = (uint16) static_cast<uint32>(type);
    _write(terminal_addr, reg_addr, (uint8*) (&data), 2, timeout);
  }

  void _write( uint32 terminal_addr, uint32 reg_addr, const uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    unsigned int checksum = 0;
    send_cmd(WRITE_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);
    // wait for the command buffer to empty
    while(*empty_b) {
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(USB_COMM, "Timed out sending command.");
      }
    }

    // write the data
    size_t tx_count = 0;
    while(tx_count < length) {
      if(*wptr >= *wend) {
        advance_clk(10);
        // fill the tx buffer
        int i;
        for(i=0; (i<256) && (tx_count<length); i++) {
          wbuf[i] = data[tx_count] + (data[tx_count + 1] << 8);
          checksum += wbuf[i];                                       
          //printf("wbuf[%d]=0x%x\n", i, wbuf[i]);
          tx_count += 2;
        }
        *datao = wbuf[0];
        *wptr = 0;
        *wend = i;
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(USB_COMM, "Timed out waiting transfer");
      }
    }

    // wait for ack
    while(*rptr < 4) {
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(USB_COMM, "Timed out waiting for ack");
      }
    }
    // check ack
    *rptr = 0;

    char msg[256];
    if(rbuf[0] != 0xA50F) {
      throw Exception(USB_COMM, "Unexpected ack code returns");
    }
    // check checksum
    checksum = checksum & 0xFFFF;
    if(rbuf[1] != checksum) {
      sprintf(msg, "Checksum mismatch: 0x%04x/0x%04x", rbuf[1], checksum);
      throw Exception(USB_COMM, msg);
    }
    // check status word
    if(rbuf[2] != 0) {
      sprintf(msg, "Non-zero ACK status 0x%x (%d) returned.", rbuf[2], rbuf[2]);
      throw Exception(USB_COMM, msg, rbuf[2]);
    }

    advance_clk(3);

  }


  void _close() {}
  
 public:
  
  FX2Device() {}
  ~FX2Device() throw() {}
  
  SData *wbuf, *rbuf, *wptr, *rptr, *wend, *datao;
  CData *rdone, *hics_b, *full_b, *empty_b;
  

};
#endif

 `systemc_interface
   FX2Device *fx2_dev;    // Pointer to object we are embedding
 `systemc_ctor
   fx2_dev = new FX2Device(); // Construct contained object
   fx2_dev->wbuf = wbuf;
   fx2_dev->rbuf = rbuf;
   fx2_dev->wptr = &wptr;
   fx2_dev->rptr = &rptr;
   fx2_dev->wend = &wend;
   fx2_dev->datao= &datao;
   fx2_dev->rdone= &rdone;
   fx2_dev->hics_b= &hics_b;
   fx2_dev->full_b= &full_b;
   fx2_dev->empty_b= &empty_b;
 `systemc_dtor
   delete fx2_dev;    // Destruct contained object
 `verilog
`endif
   
endmodule
