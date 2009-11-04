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

`include "terminals_defs.v"
module fpga 
(
   input fx2_ifclk,
   input fx2_hics_b,
   input [2:0] fx2_flags,
   output fx2_sloe_b,
   output fx2_slrd_b,
   output fx2_slwr_b,
   output fx2_pktend_b,
   output [1:0] fx2_fifo_addr,
   output fx2_slcs_b,
   inout [15:0] fx2_fd
);

wire [31:0]          di_len;                 // From HostInterface2 of HostInterface2.v
wire                 di_read;                // From HostInterface2 of HostInterface2.v
wire                 di_read_mode;           // From HostInterface2 of HostInterface2.v
wire                 di_read_req;            // From HostInterface2 of HostInterface2.v
wire [31:0]          di_reg_addr;            // From HostInterface2 of HostInterface2.v
wire [15:0]          di_reg_datai;           // From HostInterface2 of HostInterface2.v
wire [15:0]          di_term_addr;           // From HostInterface2 of HostInterface2.v
wire                 di_write;               // From HostInterface2 of HostInterface2.v
wire                 di_write_mode;          // From HostInterface2 of HostInterface2.v

reg [15:0] di_reg_datao;
reg di_read_rdy, di_write_rdy;
reg [15:0] di_transfer_status;

reg [4:0] reset_cnt;
wire resetb = &reset_cnt;
   wire ifclk = fx2_ifclk;
   
always @(posedge ifclk) begin
    if (!resetb) begin
        reset_cnt <= reset_cnt + 1;
    end
end

HostInterface HostInterface
  (
   .fx2_fd                              (fx2_fd),

   /*AUTOINST*/
   // Outputs
   .fx2_sloe_b				(fx2_sloe_b),
   .fx2_slrd_b				(fx2_slrd_b),
   .fx2_slwr_b				(fx2_slwr_b),
   .fx2_slcs_b				(fx2_slcs_b),
   .fx2_pktend_b			(fx2_pktend_b),
   .fx2_fifo_addr			(fx2_fifo_addr[1:0]),
   .di_term_addr			(di_term_addr[15:0]),
   .di_reg_addr				(di_reg_addr[31:0]),
   .di_len				(di_len[31:0]),
   .di_read_mode			(di_read_mode),
   .di_read_req				(di_read_req),
   .di_read				(di_read),
   .di_write				(di_write),
   .di_write_mode			(di_write_mode),
   .di_reg_datai			(di_reg_datai[15:0]),
   // Inputs
   .ifclk				(ifclk),
   .resetb				(resetb),
   .fx2_hics_b				(fx2_hics_b),
   .fx2_flags				(fx2_flags[2:0]),
   .di_read_rdy				(di_read_rdy),
   .di_reg_datao			(di_reg_datao[15:0]),
   .di_write_rdy			(di_write_rdy),
   .di_transfer_status			(di_transfer_status[15:0]));

   
   wire di_clk           = ifclk;
   wire slow_read_rdy, slow_write_rdy;

   always @(*) begin
      if(di_term_addr == `TERM_Fast) begin
         di_reg_datao     = FastTerminal_reg_datao;
         di_read_rdy      = 1;  // always ready on other registers
         di_write_rdy     = 1;
         di_transfer_status = {15'b0, (di_reg_addr > 161) };
      end else if(di_term_addr == `TERM_NeverReadReady) begin
         di_reg_datao     = 16'h2222;
         di_read_rdy      = 0;
         di_write_rdy     = 1;
         di_transfer_status=0;
      end else if(di_term_addr == `TERM_Slow) begin
         di_reg_datao     = SlowTerminal_reg_datao;
         di_read_rdy      = slow_read_rdy;
         di_write_rdy     = slow_write_rdy;
         di_transfer_status=0;
      end
   end

   
`include "FastTerminalInstance.v"
`include "NeverReadReadyTerminalInstance.v"
`include "SlowTerminalInstance.v"


   reg[5:0] slow_count;
   assign slow_read_rdy   = &slow_count && !di_read_req;
   assign slow_write_rdy  = &slow_count && !di_write;

   always @(posedge ifclk) begin
      if(di_term_addr == `TERM_Slow) begin
         if(di_read_req || di_write) begin
            slow_count   <= 0;
         end else if(!slow_read_rdy || !slow_write_rdy) begin
            slow_count   <= slow_count + 1;
         end
      end else begin
         slow_count <= -1;
      end
   end


endmodule
// Local Variables:
// verilog-library-flags:("-y ../rtl")
// End:
