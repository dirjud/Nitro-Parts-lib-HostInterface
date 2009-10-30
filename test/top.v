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

module top;


   // module wires
   reg clk;
   always #1 clk = !clk;
   reg reset_b;

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

   // fpga outputs
   wire fx2_pktend_b,fx2_sloe_b, fx2_slwr_b, fx2_slrd_b;
   wire [1:0] fx2_fifo_addr; 

   wire [7:0] PA = { 1'b0, fx2_pktend_b, fx2_fifo_addr, 1'b0, fx2_sloe_b, 1'b0, 1'bz };
   wire [1:0] RDY = { fx2_slwr_b, fx2_slrd_b };
   wire [2:0] fx2_flags = CTL;

   wire WAKEUP=1;
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
   .RESET_b                             (reset_b),
   .WAKEUP                              (WAKEUP),
   .RDY                                 (RDY[1:0]),
   .PA                                  (PA[7:0]));

fpga fpga (
   .ifclk                               (ifclk),
   .fx2_hi_cs                           (PA[0]),
   .fx2_sloe_b                          (fx2_sloe_b),
   .fx2_slrd_b                          (fx2_slrd_b),
   .fx2_slwr_b                          (fx2_slwr_b),
   .fx2_pktend_b                        (fx2_pktend_b),
   .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
   .fx2_fd                              (FD),
   .fx2_flags                           (fx2_flags)
 
);


reg [15:0] value;

initial begin
 $dumpfile ( "sim.vcd" );
 $dumpvars ( 0, top );
 $display( "Running Simulation" );

 reset_b = 0;
 clk=0;

 # 30 reset_b = 1;

 //fx2.set(0,1,16'hbb);
 //fx2.set(1,0,16'haa);
 //fx2.get(0,1,value);
 //$display ( "Get should be bb (187): ", value );

 do_bbsets(0,0,160); // Fast, fast_buf
 do_bbsets(1,0,160); // Slow, slow_buf

 do_bbgets(0,160); // fast
 do_bbgets(1,160); // slow

 $finish;
end

integer i;
task do_bbsets;
 input [15:0] term_addr;
 input [31:0] reg_addr;
 input [7:0] count;
 begin
  for (i = 0; i< count; i=i+1 ) begin
    fx2.set ( term_addr, reg_addr+i, i );
  end

  for (i=0; i< count; i=i+1 ) begin
    fx2.get ( term_addr, reg_addr+i, value );
    if ( value != i ) begin
     $display ( "Get/Set mismatch ", term_addr, reg_addr+i, " Got ", value, " Expected", i );
     $finish;
    end
  end

 end
endtask

reg [15:0] tmp;
task do_bbgets;
 input [15:0] term_addr;
 input [31:0] reg_addr;

 begin
   fx2.get(term_addr, reg_addr, value ); 
   for (i=0;i<10;i=i+1) begin
    fx2.get(term_addr,reg_addr, tmp );
    if (value != tmp) begin
     $display ( "Back-to-back get mismatch value: " , tmp , " expected: " , value );
     $finish;
    end
   end

 end
endtask

endmodule


