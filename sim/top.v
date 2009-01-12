
`include "XEM3010EndPointDefs.v"

module Wrapper(
    
    input wire if_clock,
    input wire [2:0] ctl,
    input wire [3:0] state,
    output wire rdy,
    output wire out,
    input wire we,
    input wire [15:0] datain,
    output wire [15:0] dataout
);

  wire [15:0] dataio = we ? datain : 16'hZ;
  assign dataout = dataio;

  DiSim sim(
    .if_clock(!if_clock),
    .ctl(ctl),
    .state(state),
    .rdy(rdy),
    .out(out),
    .data(dataio)
  );

endmodule

module DiSim (
    input wire if_clock,
    input wire [2:0] ctl,
    input wire [3:0] state,
    output wire rdy,
    output wire out,
    inout wire [15:0] data
    
    );
    

    // hi wires
    wire resetb;
    wire [15:0] diEpAddr;
    wire [15:0] diRegAddr;
    wire [15:0] diRegDataIn;
    wire [15:0] diRegDataOut;
    wire diWrite;
    wire diRead;
    wire diReset;
    reg rdwr_ready;
    
    HostInterface hi(
        .if_clock(if_clock),
        .ctl(ctl),
        .rdy(rdy),
        .out(out),
        .state(state),
        .data(data),
        .resetb(resetb),
        .diEpAddr(diEpAddr),
        .diRegAddr(diRegAddr),
        .diRegDataIn(diRegDataIn),
        .diRegDataOut(diRegDataOut),
        .diWrite(diWrite),
        .diRead(diRead),
        .diReset(diReset),
        .rdwr_ready(rdwr_ready)
    );
    
    
    reg [4:0] resetcount;
    assign resetb = &resetcount;
    
    reg [15:0] counter_reg;
    // for test purposes, lets say the counter only
    // is ready after a wait
    reg [2:0] counter_wait;
    parameter STATE_IDLE = 0;
    parameter STATE_WAIT = 1;
    reg counter_state;
    
    always @(posedge if_clock) begin    
        if (!resetb) begin
         resetcount <= resetcount + 1;
         rdwr_ready <= 0;
         counter_wait <= 0;
         counter_state <= STATE_IDLE;
        end else begin
            // if reading the counter, increment it
            if (diEpAddr == `EP_XEM3010 && diRegAddr == `REG_XEM3010_counter_0) begin
                case (counter_state)
                    STATE_IDLE:
                        if (diRead) begin
                            counter_state <= STATE_WAIT;
                            counter_wait <= 0;
                            rdwr_ready <= 0;
                        end
                    STATE_WAIT:
                        if (&counter_wait) begin
                            rdwr_ready <= 1;
                            counter_reg <= counter_reg+1;
                            counter_state <= STATE_IDLE;
                        end else begin
                            counter_wait <= counter_wait + 1;
                        end
                endcase
            
            end else begin
                rdwr_ready <= 1; // always ready for other registers
            end
        end
    end
    
        
    // test FPGA terminal as output by simple di file
    wire clk=if_clock;
    `include "XEM3010EndPointInstance.v"
    assign buttons = 2'b01;
    assign counter = counter_reg;
        
    assign diRegDataOut = diEpAddr == `EP_XEM3010 ? XEM3010EndPoint_out : 0;
        
    
endmodule