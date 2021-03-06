/**
 * Copyright (C) 2013 BrooksEE, LLC.
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

`define FX3_READ_BUFFERS 14
`define FX3_WRITE_BUFFERS 1
`define FX3_BUF_MULTIPLIER 2

module fx3
  (
   input 	 clk,
   
   output 	 fx3_ifclk,
   output 	 fx3_clkout,
   
   output 	 fx3_hics_b,
//   output [2:0] fx3_flags,
   output 	 fx3_dma_rdy_b,
   input 	 fx3_sloe_b,
   input 	 fx3_slrd_b,
   input 	 fx3_slwr_b,
   input 	 fx3_slcs_b,
   input 	 fx3_pktend_b,
   input [1:0] 	 fx3_fifo_addr,
   inout [31:0]  fx3_fd,
//   input [31:0]  fx3_fd_in,
//   output [31:0] fx3_fd_out,
//   output 	 fx3_fd_oe,
   
   inout 	 SCL,
   inout 	 SDA
   );

   reg sloe_b;
   reg hics_b             /* verilator public */;
   reg [31:0] rbuf[0:256*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER-1] /* verilator public */;
   reg [15:0]  rptr        /* verilator public */;
   reg rdone              /* verilator public */;
   reg [31:0] wbuf[0:256*`FX3_WRITE_BUFFERS*`FX3_BUF_MULTIPLIER-1] /* verilator public */;
   reg [31:0] cbuf[0:3]   /* verilator public */;
   reg [15:0]  wptr        /* verilator public */;
   reg [15:0]  wend        /* verilator public */;
   reg empty_b            /* verilator public */;
   reg cmd_empty_b        /* verilator public */;
   reg [2:0] cmd_ptr  /* verilator public */ = 4;
   reg full_b             /* verilator public */;
   reg [31:0] datao;
   reg [31:0] cmd_datao;

   pullup p1(SCL);
   pullup p2(SDA);

   reg [1:0] fifo_addr;
   assign fx3_ifclk  = clk; // invert clk
   assign fx3_clkout = clk;
   assign fx3_hics_b = hics_b;
   
   wire        wfifo_active    = fifo_addr == 3;
   wire        rfifo_active    = fifo_addr == 0;
   wire        cmd_fifo_active = fifo_addr == 2;

   wire        slwr_b    = !(!fx3_slwr_b && rfifo_active);

   reg [31:0]  datao1;
   

//   assign fx3_flags = { 1'b0, full_b, empty_b };
   
   assign fx3_dma_rdy_b = wfifo_active    ? !empty_b :
			  cmd_fifo_active ? !cmd_empty_b :
			  rfifo_active    ? !full_b :
			  1'b1;

   assign fx3_fd = (sloe_b) ? 32'hZZZZZZZZ : datao1;
   wire [31:0] fd_in = fx3_fd;
   
//   assign fx3_fd_out = datao1;
//   assign fx3_fd_oe  = !sloe_b;
//   wire [31:0] fd_in = fx3_fd_in;
   
   always @(posedge clk) begin
      fifo_addr <= fx3_fifo_addr;
      sloe_b    <= fx3_sloe_b;
      
      empty_b <= !(wptr >= wend);
      if(!fx3_slrd_b && wfifo_active) begin
         wptr  <= wptr + 1;
         /* verilator lint_off WIDTH */
         datao <= wbuf[wptr];
         /* verilator lint_on WIDTH */
      end

      cmd_empty_b <= !(cmd_ptr >= 4);
      if(!fx3_slrd_b && cmd_empty_b && cmd_fifo_active) begin
	 cmd_ptr <= cmd_ptr+1;
         cmd_datao <= cbuf[cmd_ptr[1:0]];
      end

      datao1 <= #1 (wfifo_active) ? datao : 
	        cmd_fifo_active ? cmd_datao : 0;
      
      full_b <= !((rptr > `FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER*256-1 ) || rdone);
      if(!slwr_b && (rptr <= `FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER*256-1 )) begin
         /* verilator lint_off WIDTH */
         rbuf[rptr] <= fd_in;
         /* verilator lint_on WIDTH */
         rptr <= rptr + 1;
      end

      if(!fx3_pktend_b) begin
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

    wire [15:0] rd_buf_size = 1024*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER; 
    wire [15:0] wr_buf_size = 1024*`FX3_WRITE_BUFFERS*`FX3_BUF_MULTIPLIER; 
    // final destination buffer for reads and writes
   //reg [7:0]    rdwr_data_buf[0:1024*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER-1];
   reg [7:0]    rdwr_data_buf[0:2**24-1];//1024*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER-1];

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
         cbuf[0] = {
             cmd == 1 ? rd_buf_size :
                        wr_buf_size,
                        8'hc3, cmd };
         cbuf[1] = { 16'b0, term_addr };
         cbuf[2] = reg_addr;
         cbuf[3] = length;
         cmd_ptr = 0;
         wptr = 0;
         wend = 0;
         rptr = 0;
         rdone = 0;
         repeat (3) @(posedge clk);
      end
   endtask


   /**
    * Simulate an FX3 get command.
    **/
   task get;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      output [31:0] value;
      begin
         read(term_addr,reg_addr, 4);
         value = { rdwr_data_buf[3], rdwr_data_buf[2], rdwr_data_buf[1], rdwr_data_buf[0] };
      end
   endtask

   // Get a register wider than 32b. specify the width of the register in
   // in bits and this will loop through starting at 'reg_addr' doing 16b
   // gets until it has retrieved all words in the wide register. Return
   // value has a max of 1024 bits.
   task getW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      output [1023:0] value;
      integer        wcount;
      begin
         value = 0;//clear out the return value first
         for(wcount=0; wcount<width; wcount=wcount+32) begin // loop through reg
            read(term_addr,reg_addr+(wcount/32), 4);
            value = value | ({ rdwr_data_buf[3], rdwr_data_buf[2], rdwr_data_buf[1], rdwr_data_buf[0] } << wcount);
            `ifdef DEBUG_FX3 
              $display("%d getW: wcount=%d buf[0]=0x%x buf[1]=0x%x buf[2]=0x%x buf[3]=0x%x",$time, wcount, rdwr_data_buf[0], rdwr_data_buf[1], rdwr_data_buf[2], rdwr_data_buf[3]);
            `endif
         end
        `ifdef DEBUG_FX3 
         $display("%d getW: value=0x%x",$time, value);
        `endif
      end
   endtask


   
   /**
    * Simulate an FX3 set command
    **/
   task set;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] value;
      begin
         rdwr_data_buf[0] = value[7:0];
         rdwr_data_buf[1] = value[15:8];
         rdwr_data_buf[2] = value[23:16];
         rdwr_data_buf[3] = value[31:24];
         write(term_addr,reg_addr,4);
      end
   endtask

   // Set a wide register. See getW() documentation.
   task setW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      input [1023:0] value;
      integer        wcount;
      for(wcount=0; wcount<width; wcount=wcount+32) begin
         rdwr_data_buf[0] = 8'hFF & (value >> wcount);
         rdwr_data_buf[1] = 8'hFF & (value >> (wcount+8));
         rdwr_data_buf[2] = 8'hFF & (value >> (wcount+16));
         rdwr_data_buf[3] = 8'hFF & (value >> (wcount+24));
         write(term_addr,reg_addr+(wcount/32),4);
      end
   endtask


   /**
    * Simulate an FX3 read command
    **/
   task read;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] length;
      begin
         _sendcmd( term_addr, reg_addr, 1, length ); 
         rxcount = 0;
         while(rxcount < length + 8) begin 
            if(rdone || (full_b==0)) begin 
               repeat (10) @(posedge clk);

               for(i=0; i<rptr; i=i+1) begin 
                  rdwr_data_buf[rxcount] = rbuf[i][7:0];
                  rdwr_data_buf[rxcount+1] = rbuf[i][15:8];
                  rdwr_data_buf[rxcount+2] = rbuf[i][23:16];
                  rdwr_data_buf[rxcount+3] = rbuf[i][31:24];
                  rxcount = rxcount + 4;
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
    * Simulate an FX3 write command
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
            for (i=0;i<(wr_buf_size/4) && txcount < length; i=i+1) begin
               wbuf[i] = { rdwr_data_buf[txcount+3], rdwr_data_buf[txcount+2], rdwr_data_buf[txcount+1] , rdwr_data_buf[txcount] };
               txcount = txcount + 4;
	       //$display(" wbuf[%d] = 0x%x txcount=%d length=%d", i, wbuf[i], txcount, length);
            end
            wptr = 0;
            wend = i;

            repeat(4) @(posedge clk);
         end

         // wait for ack
         while (rptr < 2) begin
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
#include <fx3_verilator.cpp>
 `systemc_interface
   FX3Device *fx3_dev;    // Pointer to object we are embedding
 `systemc_ctor
   fx3_dev = new FX3Device(); // Construct contained object
   fx3_dev->cbuf = cbuf;
   fx3_dev->wbuf = wbuf;
   fx3_dev->rbuf = rbuf;
   fx3_dev->wptr = &wptr;
   fx3_dev->rptr = &rptr;
   fx3_dev->cmd_ptr = &cmd_ptr;
   fx3_dev->wend = &wend;
   fx3_dev->rdone= &rdone;
   fx3_dev->hics_b= &hics_b;
   fx3_dev->full_b= &full_b;
   fx3_dev->empty_b= &empty_b;
 `systemc_dtor
   delete fx3_dev;    // Destruct contained object
 `verilog
`endif
   
endmodule
