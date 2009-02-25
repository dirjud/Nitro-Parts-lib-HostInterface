
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
    reg rd_ready,wr_ready;
    
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
        .wr_ready(wr_ready),
        .rd_ready(rd_ready)
    );
    
    
    reg [4:0] resetcount;
    assign resetb = &resetcount;
    assign out = 0;
    
    reg [4:0] slow_writer_timeout;
    
    reg [15:0] counter_out,counter_reg;// counter_reg_n;
    reg diReadReg;
    // for test purposes, lets say the counter only
    // is ready after a wait
    reg [2:0] counter_wait;
    reg counter_get_read;
    parameter STATE_IDLE = 2'b0;
    parameter STATE_WAIT = 2'b01;
    parameter STATE_READ = 2'b10;
    reg [1:0] counter_state;
    wire rd_ready_n = (counter_state == STATE_WAIT && counter_wait >= 3'd6) ||
                         (counter_state == STATE_READ && counter_wait < 3'd7);
                         
    always @(posedge if_clock) begin    
        if (!resetb) begin
         resetcount <= resetcount + 1;
         wr_ready <= 0;
         rd_ready <= 0;
         counter_wait <= 0;
         counter_state <= STATE_WAIT;
         counter_get_read <= 0;
         slow_writer_timeout <= 0;
        end else begin
            // this block demonstrates how to use DI with read data
            // rdwr_ready must predict a read in two cycles.
            // when diRead is high, you must clock out the value for that read
            // one cycle later
            if (diEpAddr == `EP_XEM3010 && diRegAddr == `REG_XEM3010_counter_fifo_0) begin
                rd_ready <= rd_ready_n;
                counter_out <= counter_reg;
                if (diRead) begin
                    counter_reg <= counter_reg+1;
                end
                case (counter_state)
                    default: begin end // I screwed up
                    STATE_WAIT:
                        begin
                            counter_wait <= counter_wait + 1;
                            if (&counter_wait) begin
                                counter_state <= STATE_READ;
                            end
                        end 
                    STATE_READ:
                        if (diRead) begin
                            counter_wait <= counter_wait + 1;
                            if (&counter_wait) begin
                                counter_state <= STATE_WAIT;
                            end
                        end
                endcase 

                /* rd_ready <= 1;
                counter_out <= counter_reg;
                if (diRead) begin
                 counter_reg <= counter_reg + 1;
                end */
            
            end else if (diEpAddr == `EP_XEM3010 && diRegAddr == `REG_XEM3010_counter_get_0) begin
                // in this case, you'll get a oneshot read.
                // when you clock out the data, also clock out rdwr_ready = 1
                // you can tie it high if you simply want to clock out the
                // value each time a read is issued.
                counter_out <= counter_reg;
                if (diRead || counter_get_read) begin
                    if (counter_state == STATE_READ) begin // read this cycle
                        counter_get_read <= 0;
                    end else if (diRead) begin
                        counter_get_read <= 1; // read at a later cycle
                    end
                    case (counter_state)
                        default: begin end
                        STATE_WAIT:
                            begin
                                counter_wait <= counter_wait + 1;
                                rd_ready <= 0;
                                if (&counter_wait) begin
                                    counter_state <= STATE_READ;
                                end
                            end
                        STATE_READ:
                            begin
                                rd_ready <= 1;
                                counter_reg <= counter_reg + 1;
                                counter_wait <= counter_wait + 1;
                                if (&counter_wait) begin
                                    counter_state <= STATE_WAIT;
                                end
                            end
                    endcase
                end else begin
                    rd_ready <= 0;
                end
                
            end else if (diEpAddr == `EP_XEM3010 && diRegAddr == `REG_XEM3010_slow_writer_0) begin
                // this guy you can't read/write to for a while
                if (&slow_writer_timeout) begin
                    if (diRead || diWrite) begin
                        slow_writer_timeout <= 0; // have to wait again
                        wr_ready <= 0;
                        rd_ready <= 0;
                    end else begin
                        wr_ready <= 1;
                        rd_ready <= 1;
                    end
                    
                end else begin
                    slow_writer_timeout <= slow_writer_timeout + 1;
                    wr_ready <= 0;
                    rd_ready <= 0;
                end
            end else begin
                rd_ready <= 1; // always ready for other registers
                wr_ready <= 1;
            end
        end
    end
    
        
    // test FPGA terminal as output by simple di file
    wire clk=if_clock;
    `include "XEM3010EndPointInstance.v"
    assign buttons = 2'b01;
    assign counter_fifo = counter_out;
    assign counter_get = counter_out;
        
    assign diRegDataOut = diEpAddr == `EP_XEM3010 ? XEM3010EndPoint_out : 0;
        
    
endmodule
