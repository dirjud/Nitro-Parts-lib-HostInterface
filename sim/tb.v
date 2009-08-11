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

   wire [7:0] PA = { 1'b0, fx2_pktend_b, fx2_fifo_addr, 1'b0, fx2_sloe_b, 2'b0 };
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
   .PA                                  (PA[7:0]));

fpga fpga (
   .ifclk                               (ifclk),
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
