module fx2
  (
   input XTALIN,
   input RESET_b,
   input WAKEUP,
   
   output XTALOUT,
   output IFCLK,
   output CLKOUT,

   input  [1:0] RDY,
   output [2:0] CTL, // flags C,B,A
   
   inout [15:0] FD,
   input [7:0] PA,
   
   inout SCL,
   inout SDA,
   
   inout DMINUS,
   inout DPLUS
   );

   
   assign XTALOUT = XTALIN;
   assign IFCLK   = !XTALIN; // invert clk
   assign CLKOUT  = XTALIN;

   wire       pktend_b  = PA[6];
   wire [1:0] fifo_addr = PA[5:4];
   wire       slrd_b    = RDY[0];
   wire       slwr_b    = RDY[1];
   wire       clk       = XTALIN;


   reg sloe_b;
   reg [6:0] state;
   parameter SEND_CMD = 1;

   reg flagc /* verilator public */;


   reg [15:0] rbuf[0:255] /* verilator public */;
   reg [8:0]  rptr /* verilator public */;
   reg rdone /* verilator public */;
 
   reg [15:0] wbuf[0:255] /* verilator public */;
   reg [8:0]  wptr /* verilator public */;
   reg [8:0]  wend /* verilator public */;
   reg [15:0] datao /* verilator public */;
   reg empty_b /* verilator public */;
   reg full_b /* verilator public */;
   wire [15:0] datao1 = (fifo_addr == 0) ? datao : 0;

   assign CTL = { flagc, full_b, empty_b };
   assign FD = (sloe_b) ? 16'hZZZZ : datao1;
   wire [15:0] fd_in = FD;
   
   always @(posedge clk) begin
      sloe_b  <= PA[2];
      
      empty_b <= !((wptr >= wend) || (!slrd_b && wptr+1 == wend));
      if(!slrd_b && (wptr <= wend)) begin
         wptr  <= wptr + 1;
         datao <= wbuf[wptr + 1];
      end

      full_b = !(rptr > 255-4);
      if(!slwr_b && (rptr <= 255)) begin
         rbuf[rptr] <= fd_in;
         rptr <= rptr + 1;
      end

      if(!pktend_b) begin
         rdone <= 1;
      end
   end

   wire [15:0] rbuf00=rbuf[0];
   wire [15:0] rbuf01=rbuf[1];
   wire [15:0] rbuf02=rbuf[2];

   
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

    *flagc  = 1;
    advance_clk(50);
    *flagc  = 0;
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
    _read(terminal_addr, reg_addr, (uint8*) (&val), 2, timeout);
    return DataType( static_cast<uint32>((uint32) val));
  }

  void _read( uint32 terminal_addr, uint32 reg_addr, uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    send_cmd(READ_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);

    size_t rx_count = 0;
    
    while(rx_count < length) {
      if(*rdone || (*full_b==0)) {
        advance_clk(10);
        for(int i=0; i<*rptr; i++) {
          data[rx_count] = rbuf[i] & 0xFF;
          ++rx_count;
          data[rx_count] = (rbuf[i] >> 8) & 0xFF;
          ++rx_count;
        }
        *rdone = 0;
        *rptr  = 0;
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(-1, "Timed out");
      }
    }
  }


  void _set(uint32 terminal_addr, uint32 reg_addr, const DataType& type, uint32 timeout ) {
    uint16 data = (uint16) static_cast<uint32>(type);
    _write(terminal_addr, reg_addr, (uint8*) (&data), 2, timeout);
  }

  void _write( uint32 terminal_addr, uint32 reg_addr, const uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    send_cmd(WRITE_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);
    // wait for the command buffer to empty
    while(*empty_b) {
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(-1, "Timed out sending command.");
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
          //printf("wbuf[%d]=0x%x\n", i, wbuf[i]);
          tx_count += 2;
        }
        *datao = wbuf[0];
        *wptr = 0;
        *wend = i;
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(-3, "Timed out waiting transfer");
      }
    }

    // wait for ack
    while(*rptr == 0) {
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(-1, "Timed out waiting for ack");
      }
    }
    // check ack
    *rptr = 0;
    //printf("ack = 0x%x\n", rbuf[0]);
    if(rbuf[0] != 0xA50F) {
      throw Exception(-2, "Unexpected ack code returns");
    }
    advance_clk(3);

  }


  void _close() {}
  
 public:
  
  FX2Device() {}
  ~FX2Device() throw() {}
  
  SData *wbuf, *rbuf, *wptr, *rptr, *wend, *datao;
  CData *rdone, *flagc, *full_b, *empty_b;
  

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
   fx2_dev->flagc= &flagc;
   fx2_dev->full_b= &full_b;
   fx2_dev->empty_b= &empty_b;
 `systemc_dtor
   delete fx2_dev;    // Destruct contained object
 `verilog

   
endmodule
