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
   input clk,
   input resetb
   );

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 CLKOUT;                 // From fx2 of fx2.v
   wire [2:0]           CTL;                    // From fx2 of fx2.v
   wire                 DMINUS;                 // To/From fx2 of fx2.v
   wire                 DPLUS;                  // To/From fx2 of fx2.v
   wire [15:0]          FD;                     // To/From fx2 of fx2.v
   wire                 IFCLK;                  // From fx2 of fx2.v
   wire                 SCL;                    // To/From fx2 of fx2.v
   wire                 SDA;                    // To/From fx2 of fx2.v
   wire                 XTALOUT;                // From fx2 of fx2.v
  // End of automatics


   wire fx2_pktend_b,fx2_sloe_b, fx2_slwr_b, fx2_slrd_b;
   wire [1:0] fx2_fifo_addr; 

   wire [6:0] PA71 = { 1'b0, fx2_pktend_b, fx2_fifo_addr, 1'b0, fx2_sloe_b, 1'b0 };
   wire PA0;
   wire [1:0] RDY = { fx2_slwr_b, fx2_slrd_b };
   wire [2:0] fx2_flags = CTL;

   wire WAKEUP=1;
   wire RESET_b= resetb;
   wire ifclk = IFCLK;
   wire XTALIN  = clk;
   
fx2 fx2
  (/*AUTOINST*/
   // Outputs
   .XTALOUT                             (XTALOUT),
   .IFCLK                               (IFCLK),
   .CLKOUT                              (CLKOUT),
   .CTL                                 (CTL[2:0]),
   // Inouts
   .FD                                  (FD[15:0]),
   .SCL                                 (SCL),
   .SDA                                 (SDA),
   .DMINUS                              (DMINUS),
   .DPLUS                               (DPLUS),
   // Inputs
   .XTALIN                              (XTALIN),
   .RESET_b                             (RESET_b),
   .WAKEUP                              (WAKEUP),
   .RDY                                 (RDY[1:0]),
   .PA71                                  (PA71[6:0]),
   .PA0                                 (PA0));

fpga fpga (
   .ifclk                               (ifclk),
   .fx2_hi_csb                          (PA0),
   .fx2_sloe_b                          (fx2_sloe_b),
   .fx2_slrd_b                          (fx2_slrd_b),
   .fx2_slwr_b                          (fx2_slwr_b),
   .fx2_pktend_b                        (fx2_pktend_b),
   .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
   .fx2_fd                              (FD),
   .fx2_flags                           (fx2_flags)
 
);
   
endmodule
// Local Variables:
// verilog-library-flags:("-y ../rtl")
// End:
