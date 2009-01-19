
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
        //.out(out),
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
    assign out = 0;
    
    
    reg [15:0] counter_out,counter_reg;// counter_reg_n;
    reg diReadReg;
    // for test purposes, lets say the counter only
    // is ready after a wait
    reg [2:0] counter_wait;
    parameter STATE_IDLE = 2'b0;
    parameter STATE_WAIT = 2'b01;
    parameter STATE_READ = 2'b10;
    reg [1:0] counter_state;
    wire [2:0] counter_wait_ = counter_wait + 1;
    wire rdwr_ready_n = (counter_state == STATE_WAIT && counter_wait >= 3'd5) ||
                         (counter_state == STATE_READ && counter_wait < 3'd6);
                         
    always @(posedge if_clock) begin    
        if (!resetb) begin
         resetcount <= resetcount + 1;
         rdwr_ready <= 0;
         counter_wait <= 0;
         counter_state <= STATE_WAIT;
        end else begin
            // if reading the counter, increment it
            if (diEpAddr == `EP_XEM3010 && diRegAddr == `REG_XEM3010_counter_0) begin
                rdwr_ready <= rdwr_ready_n;
                if (diRead) begin
                    counter_out <= counter_reg;
                    counter_reg <= counter_reg+1;
                end
                case (counter_state)
                    default: begin end // I screwed up
                    STATE_WAIT:
                        if (&counter_wait) begin
                            counter_state <= STATE_READ;
                            counter_wait <= 0;
                        end else begin
                            counter_wait <= counter_wait + 1;
                        end
                    STATE_READ:
                        if (diRead) begin
                            counter_wait <= counter_wait + 1;
                            if (&counter_wait) begin
                                counter_wait <= 0;
                                counter_state <= STATE_WAIT;
                            end
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
    assign counter = counter_out;
        
    assign diRegDataOut = diEpAddr == `EP_XEM3010 ? XEM3010EndPoint_out : 0;
        
    
endmodule