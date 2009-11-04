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
module tb
  (
`ifdef verilator
   input clk
`endif
   );

`ifndef verilator
   reg 	 clk;
   initial clk=0;
   always #11 clk = !clk; // # 48MHz clock
`endif
   
   wire [15:0] fx2_fd;
   wire [1:0]  fx2_fifo_addr;
   wire [2:0]  fx2_flags;
   wire        fx2_ifclk, fx2_hics_b, fx2_sloe_b, fx2_slrd_b, fx2_slwr_b;
   wire        fx2_pktend_b;
   
   
   fx2 fx2
     (
      .clk                                 (clk),
      .fx2_ifclk                           (fx2_ifclk),
      .fx2_hics_b                          (fx2_hics_b),
      .fx2_sloe_b                          (fx2_sloe_b),
      .fx2_slrd_b                          (fx2_slrd_b),
      .fx2_slwr_b                          (fx2_slwr_b),
      .fx2_pktend_b                        (fx2_pktend_b),
      .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
      .fx2_fd                              (fx2_fd),
      .fx2_flags                           (fx2_flags)
      );
   
   fpga fpga 
     (
      .fx2_ifclk                           (fx2_ifclk),
      .fx2_hics_b                          (fx2_hics_b),
      .fx2_sloe_b                          (fx2_sloe_b),
      .fx2_slrd_b                          (fx2_slrd_b),
      .fx2_slwr_b                          (fx2_slwr_b),
      .fx2_pktend_b                        (fx2_pktend_b),
      .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
      .fx2_fd                              (fx2_fd),
      .fx2_flags                           (fx2_flags)
      );
   
endmodule
