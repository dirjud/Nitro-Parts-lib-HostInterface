
module fpga 
(
   input ifclk,

   input [2:0] fx2_flags,
   output fx2_sloe_b,
   output fx2_slrd_b,
   output fx2_slwr_b,
   output fx2_pktend_b,
   output [1:0] fx2_fifo_addr,
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
   .fx2_sloe_b                          (fx2_sloe_b),
   .fx2_slrd_b                          (fx2_slrd_b),
   .fx2_slwr_b                          (fx2_slwr_b),
   .fx2_pktend_b                        (fx2_pktend_b),
   .fx2_fifo_addr                       (fx2_fifo_addr[1:0]),
   .di_term_addr                        (di_term_addr[15:0]),
   .di_reg_addr                         (di_reg_addr[31:0]),
   .di_len                              (di_len[31:0]),
   .di_read_mode                        (di_read_mode),
   .di_read_req                         (di_read_req),
   .di_read                             (di_read),
   .di_write                            (di_write),
   .di_write_mode                       (di_write_mode),
   .di_reg_datai                        (di_reg_datai[15:0]),
   // Inputs
   .ifclk                               (ifclk),
   .resetb                              (resetb),
   .fx2_flags                           (fx2_flags[2:0]),
   .di_read_rdy                         (di_read_rdy),
   .di_reg_datao                        (di_reg_datao[15:0]),
   .di_write_rdy                        (di_write_rdy),
   .di_transfer_status                  (di_transfer_status[15:0]));

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
         di_transfer_status = {15'b0, (di_reg_addr > 161) };
      end else if(di_term_addr == `EP_NeverReadReady) begin
         di_reg_datao     = 16'h2222;
         di_read_rdy      = 0;
         di_write_rdy     = 1;
         di_transfer_status=0;
      end else if(di_term_addr == `EP_Slow) begin
         di_reg_datao     = slow_reg_datao;
         di_read_rdy      = slow_read_rdy;
         di_write_rdy     = slow_write_rdy;
         di_transfer_status=0;
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
