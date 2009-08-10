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
   wire [31:0]          di_len;                 // From HostInterface2 of HostInterface2.v
   wire                 di_read;                // From HostInterface2 of HostInterface2.v
   wire                 di_read_mode;           // From HostInterface2 of HostInterface2.v
   wire                 di_read_req;            // From HostInterface2 of HostInterface2.v
   wire [31:0]          di_reg_addr;            // From HostInterface2 of HostInterface2.v
   wire [15:0]          di_reg_datai;           // From HostInterface2 of HostInterface2.v
   wire [15:0]          di_term_addr;           // From HostInterface2 of HostInterface2.v
   wire                 di_write;               // From HostInterface2 of HostInterface2.v
   wire                 di_write_mode;          // From HostInterface2 of HostInterface2.v
   wire [15:0]          fx2_fd;                 // To/From HostInterface2 of HostInterface2.v
   wire [1:0]           fx2_fifo_addr;          // From HostInterface2 of HostInterface2.v
   wire                 fx2_pktend_b;           // From HostInterface2 of HostInterface2.v
   wire                 fx2_sloe_b;             // From HostInterface2 of HostInterface2.v
   wire                 fx2_slrd_b;             // From HostInterface2 of HostInterface2.v
   wire                 fx2_slwr_b;             // From HostInterface2 of HostInterface2.v
   // End of automatics


   wire [7:0] PA = { 1'b0, fx2_pktend_b, fx2_fifo_addr, 1'b0, fx2_sloe_b, 2'b0 };
   wire [1:0] RDY = { fx2_slwr_b, fx2_slrd_b };
   wire [2:0] fx2_flags = CTL;

   wire WAKEUP=1;
   wire RESET_b= resetb;
   wire ifclk = IFCLK;
   reg [15:0] di_reg_datao;
   reg di_read_rdy, di_write_rdy;
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


HostInterface HostInterface
  (
   .fx2_fd                              (FD),

   /*AUTOINST*/
   // Outputs
   .fx2_sloe_b                          (fx2_sloe_b),
   .fx2_slrd_b                          (fx2_slrd_b),
   .fx2_slwr_b                          (fx2_slwr_b),
   .fx2_pktend_b                        (fx2_pktend_b),
   .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
   .di_term_addr                        (di_term_addr[15:0]),
   .di_reg_addr                         (di_reg_addr[31:0]),
   .di_reg_datai                        (di_reg_datai[15:0]),
   .di_len                              (di_len[31:0]),
   .di_read_req                         (di_read_req),
   .di_read                             (di_read),
   .di_write                            (di_write),
   .di_read_mode                        (di_read_mode),
   .di_write_mode                       (di_write_mode),
   // Inouts
   // Inputs
   .ifclk                               (ifclk),
   .fx2_flags                           (fx2_flags[2:0]),
   .resetb                              (resetb),
   .di_reg_datao                        (di_reg_datao[15:0]),
   .di_read_rdy                         (di_read_rdy),
   .di_write_rdy                        (di_write_rdy));

`include "FastTerminalDefs.v"
`include "NeverReadReadyTerminalDefs.v"
`include "SlowTerminalDefs.v"
   
   reg[15:0] fast_reg_datao, slow_reg_datao;
   wire di_clk           = ifclk;
   wire slow_read_rdy, slow_write_rdy;

   always @(*) begin
      if(di_term_addr == `EP_Fast) begin
         di_reg_datao     = fast_reg_datao;
         di_read_rdy      = 1;  // always ready on other registers
         di_write_rdy     = 1;
      end else if(di_term_addr == `EP_NeverReadReady) begin
         di_reg_datao     = 16'h2222;
         di_read_rdy      = 0;
         di_write_rdy     = 1;
      end else if(di_term_addr == `EP_Slow) begin
         di_reg_datao     = slow_reg_datao;
         di_read_rdy      = slow_read_rdy;
         di_write_rdy     = slow_write_rdy;
         
//      end else if(di_term_addr == `EP_ImageData) begin
//         di_reg_datao   = (read_ptr) ?  sdramDataOut2    :  sdramDataOut1;
//         di_read_rdy    = (read_ptr) ? ~sdram_read_wait2 : ~sdram_read_wait1;
//         di_write_rdy   = 0;
//      end else if(di_term_addr == `EP_DRAM) begin
//         di_reg_datao   = (dram_rmode1) ? sdramDataOut1     :  sdramDataOut2;
//         di_read_rdy    = (dram_rmode1) ? ~sdram_read_wait1 : ~sdram_read_wait2;
//         di_write_rdy   = 1;
//      end else if(di_term_addr == `EP_Hydro) begin
//         di_reg_datao   = (mode_virt_hydro_sel) ? virt_hydro_datao : i2c18_datao;
//         di_read_rdy    =  (mode_virt_hydro_sel) ? 1 : i2c18_rdy & !di_read_req;
//         di_write_rdy   = ~i2c18_busy;
//      end else begin
//         di_reg_datao   = 16'hAAAA;
//         di_read_rdy    = 1;
//         di_write_rdy   = 1;
      end
   end

   
`include "FastTerminalInstance.v"
`include "NeverReadReadyTerminalInstance.v"
`include "SlowTerminalInstance.v"

   always @(posedge ifclk) begin
      fast_reg_datao     <= FastTerminal_reg_datao;
      slow_reg_datao     <= SlowTerminal_reg_datao;
   end

   reg[5:0] slow_count;
   assign slow_read_rdy   = &slow_count && !di_read_req;
   assign slow_write_rdy  = &slow_count && !di_write;

   always @(posedge ifclk) begin
      if(di_term_addr == `EP_Slow) begin
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
