

// NOTES:
// - Need to make sure FX2 drives databus during IDLE

module HostInterface
  (
   input wire ifclk,
   input wire [2:0] ctl,
   input wire [3:0] state,
   output reg [1:0] rdy,
   inout wire [15:0] data,
   
   input wire resetb,
   
   output reg [15:0] di_term_addr,
   output reg [15:0] di_reg_addr,
   output reg [15:0] di_reg_datai,
   input      [15:0] di_reg_datao,
   output reg        di_read,
   input wire        di_read_rdy,
   output reg        di_write,
   input wire        di_write_rdy
   );

   // states
   //parameter IDLE =         0;
   parameter SETEP =       1;
   parameter SETREG =      2;
   parameter SETRVAL =     3;
   parameter RDDATA =      4;
   parameter RESETRVAL =   5;
   parameter GETRVAL =     6;
   parameter RDTC    =     7;
   parameter WRDATA =      8;
   
   
   wire [15:0] datai;
   reg [15:0] datao;
   reg        oe;
   reg [15:0] datai_reg;
   reg [3:0]  state_reg;
   reg [2:0]  ctl_reg;
   wire rdwr = ctl_reg[1];

   reg [15:0] tc;
   reg [15:0] tc_reset;

   IOBuf iob[15:0] 
     (.oe(oe),
      .data(data),
      .in(datai),
      .out(datao)
      );

   always @(posedge ifclk or negedge resetb) begin
      if (!resetb) begin
         di_term_addr <= 0;
         di_reg_addr  <= 0;
         di_reg_datai <= 0;
         tc           <= 0;
         tc_reset     <= 0;
         datao        <= 0;
         rdy          <= 0;
         di_write     <= 0;
         di_read      <= 0;
         oe           <= 0;
         datai_reg    <= 0;
         state_reg    <= 0;
         ctl_reg      <= 0;

      end else begin
         state_reg    <= state;
         ctl_reg      <= ctl;
         datao        <= di_reg_datao;
         datai_reg    <= datai;
         
         case (state_reg)
           SETEP: begin
              rdy      <= 1;
              di_write <= 0;
              di_read  <= 0;
              oe       <= 0;
              if(rdwr) di_term_addr <= datai_reg;
           end
      
           SETREG: begin
              rdy      <= 1;
              di_write <= 0;
              di_read  <= 0;
              oe       <= 0;
              if(rdwr) di_reg_addr <= datai_reg;
           end
      
           SETRVAL: begin
              rdy         <= {1'b0, di_write_rdy };
              di_write    <= rdwr;
              di_read     <= 0;
              oe          <= 0;
              di_reg_datai<= datai_reg;
              if(di_write) di_reg_addr <= di_reg_addr + 1;
           end
      
           GETRVAL: begin
              rdy         <= {1'b0, di_read_rdy };
              di_write    <= 0;
              di_read     <= rdwr;
              oe          <= 1;
              if(di_read) di_reg_addr <= di_reg_addr + 1;
           end
      
           RDTC: begin
              rdy         <= 1;
              di_write    <= 0;
              di_read     <= 0;
              oe          <= 0;

              if(rdwr) begin
                 tc       <= datai_reg;
                 tc_reset <= datai_reg;
              end
           end
      
           RDDATA: begin
              rdy        <=  { 1'b0, di_read };
              di_write   <= 0;
              oe         <= 1; 
         
              if (!ctl_reg[2]) begin // new gpif
                 di_read <= 0;
                 tc      <= tc_reset;
              end else if (rdwr && di_read_rdy && tc>0) begin
                 di_read <= 1;
                 tc      <= tc - 1;
              end else begin
                 di_read <= 0;
              end
              if(di_read) di_reg_addr <= di_reg_addr + 1;
           end
           
           default: begin
              rdy      <= 0;
              di_write <= 0;
              di_read  <= 0;
              oe       <= 0;
              tc       <= 0;
           end
         endcase
      end
   end
endmodule
