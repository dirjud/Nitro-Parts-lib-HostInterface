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

module fx2(
   input XTALIN,
   input RESET_b,
   input WAKEUP,
   
   output XTALOUT,
   output IFCLK,
   output CLKOUT,

   input  [1:0] RDY,
   output [2:0] CTL, // flags C,B,A
   
   inout [15:0] FD,
   inout [7:0] PA,
   
   inout SCL,
   inout SDA,
   
   inout DMINUS,
   inout DPLUS
);
    integer i;
    integer txcount;
    integer rxcount;

    parameter RDWR_BUF_SIZE = 100; // default 100 bytes
    
    assign SCL = 1'bz;
    assign SDA = 1'bz;

    // final destination buffer for reads and writes
    reg [7:0] rdwr_data_buf[0:RDWR_BUF_SIZE-1];
    reg [31:0] rdwr_data_cur;

    assign XTALOUT = XTALIN;
    assign IFCLK   = !XTALIN; // invert clk
    assign CLKOUT  = XTALIN;
 
    wire       pktend_b  = PA[6];
    wire [1:0] fifo_addr = PA[5:4];
    wire       slrd_b    = RDY[0] | (fifo_addr != 0);
    wire       slwr_b    = RDY[1] | (fifo_addr != 2);
    wire       clk       = XTALIN;
 
 
    reg sloe_b;
    parameter SEND_CMD = 1;
 
    reg flagc;
 
 
    reg [15:0] rbuf[0:255] ;
    reg [8:0]  rptr;
    reg rdone;
  
    reg [15:0] wbuf[0:255];

    // debug
    //
    //
    wire [15:0] wbuf0=wbuf[0];
    //
    reg [8:0]  wptr;
    reg [8:0]  wend;
    reg [15:0] datao;
    reg empty_b;
    reg full_b;

    initial begin
     flagc=1;
     rptr=0;
     rdone=0;
     wptr=0;
     wend=0;
     datao=0;
    end

    wire [15:0] datao1 = (fifo_addr == 0) ? datao : 0;
 
    assign CTL = { 1'b0, full_b, empty_b };
    assign PA[0] = flagc;
    
    assign FD = (sloe_b) ? 16'hZZZZ : datao1;
    wire [15:0] fd_in = FD;
    
    always @(posedge clk) begin
       sloe_b  <= PA[2];
       
       empty_b <= !((wptr >= wend) || (!slrd_b && wptr+1 == wend));
       if(!slrd_b && (wptr <= wend)) begin
          wptr  <= wptr + 1;
          datao <= wbuf[wptr + 1];
       end
 
       full_b <= !(rptr > 255-4);
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


/**
 * each io call sends a command to the FPGA
 **/
task _sendcmd;
 input [15:0] term_addr;
 input [31:0] reg_addr;
 input [7:0] cmd;
 input [31:0] length;
begin

  flagc=1;
  repeat (50) @(posedge clk);
  flagc=0;
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
 *
 **/
task write;
 input [15:0] term_addr;
 input [31:0] reg_addr;
 input [31:0] length;
 begin

  _sendcmd ( term_addr, reg_addr, 2, length );
  txcount = 0;

  while (txcount < length) begin
      for (i=0;i<256 && txcount < length; i=i+1) begin
          while ( empty_b ) begin
            @(posedge clk);
          end
          wbuf[i] = { rdwr_data_buf[txcount+1] , rdwr_data_buf[txcount] };
          txcount = txcount + 2;
      end
      datao = wbuf[0];
      wptr = 0;
      wend = i;

      @(posedge clk);
  end

  while (rptr < 4) begin
    @(posedge clk);
  end

  repeat (10) @(posedge clk);
   
 end
endtask

endmodule
