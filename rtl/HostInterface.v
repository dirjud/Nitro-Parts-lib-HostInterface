///////////////////////////////////////////////////////////////////////////////
// Author:      Lane Brooks
// Date:        Jun 16, 2006
// License:     GPL
//
// Description: This module abstracts to host interface to the PC
//  to implement two features-- the Device Interface and the Block Transfer
//  Interface.
//
//  Device Interface: The device interface (or register interface) allows
//   the PC to set and get registers.
//
//  Block Transfer Interface: The block transfer interface is controlled
//   by the PC.  This implementation is geared towards applications that
//   are block oriented.  From a high level, the flow is as follows:
//     1.  PC issues a COLLECT_BLOCK trigger
//     2.  When the data is ready, we send back a DATA_READY trigger
//     3.  PC reads the data and returns to step 1.
//
///////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps


module HostInterface
   (

    // physical interface
    input wire if_clock,
    input wire [2:0] ctl,
    input wire [3:0] state,
    output wire rdy,
    output wire out,
    inout wire [15:0] data,

    // Device Interface
    
    input wire resetb,
    //output pcClk,    // use this clock to talk to this module
    
    output reg [15:0] diEpAddr,
    output reg [15:0] diRegAddr,
    output reg [15:0] diRegDataIn,
    input  wire [15:0] diRegDataOut,
    output  reg   diWrite,
    output  reg   diRead,
    output  reg   diReset,
    input wire rdwr_ready
    
 /*   output wire pcRead, // Read enable.  1 cycle of CAS latency
    input wire pcReadReady,
    input wire [15:0] pcReadData,// should contain valid data one cycle after pcRead.

    output wire pcWrite,
    input wire pcWriteReady,
    output wire [15:0] pcWriteData
    */
    );
    


    
// host stuff

reg outr;
assign out=outr;
reg rdyr;
assign rdy=rdyr;

reg [3:0] state_code;
reg rdwr_b;
reg [15:0] hiDataIn;
reg [15:0] hiDataOut;

wire [15:0] datain;
wire [15:0] dataout;

assign dataout = hiDataOut;

reg we; // output enable

always @(posedge if_clock) begin
 state_code <= state;
 hiDataIn <= datain;
 rdwr_b <= ctl[1];
end


IOBuf iob[15:0] (
 .we(we),
 .data(data),
 .in(datain),
 .out(dataout)
);
//assign data = (we) ? hiDataOut: 16'hZ;

// device stuff

//parameter IDLE =        4'b0000;
// op codes
parameter SETEP =       4'b0001;
parameter SETREG =      4'b0010;
parameter SETRVAL =     4'b0011;
parameter RDDATA =      4'b0100;
parameter RESETRVAL =   4'b0101;
parameter WRDATA =      4'b0111;

// states
//parameter IDLE
//parameter RDSINGLE
//parameter WRSINGLE

reg [1:0] state_flgs; // for use within each state
    
always @(posedge if_clock or negedge resetb) begin

 if (!resetb) begin
    diEpAddr <= 0;
    diRegAddr <= 0;
    diRegDataIn <= 0;
    //hiDataOut <= 0;
 end else begin
 
 case (state_code)
    default:
        begin
          state_flgs <= 0;
          diWrite <= 0;
          diReset <= 0;
          diRead <= 0;
          we <= 0;
          rdyr <= 0;
        end
    SETEP:
        if (!state_flgs[0]) begin
             if(rdwr_b) begin
                diEpAddr <= hiDataIn;
                state_flgs[0] <= 1;
             end
        end
    SETREG:
        if (!state_flgs[0]) begin
            if(rdwr_b) begin
                diRegAddr <= hiDataIn;
                state_flgs[0]<= 1;
            end
        end
    SETRVAL:
        if (!state_flgs[0]) begin
            if(rdwr_b) begin
                state_flgs[0] <= 1;
                diRegDataIn <= hiDataIn ;
                diWrite <= 1; // trigger one cycle write
            end
        end else begin
            diWrite <= 0;
        end
    RDDATA:
        begin
           diRead <= rdwr_b;
           we <= 1;
           rdyr <= rdwr_ready;
           hiDataOut <= diRegDataOut; // bogus data on 1st clock cycle
        end
   endcase
 end

end
    

    
    
    
    
/*
   wire [30:0] 	    ok1;
   wire [16:0] 	    ok2;
   
   wire [15:0] triggersIn;
   assign diReset  = triggersIn[0];
   assign diRead   = triggersIn[1];
   assign diWrite  = triggersIn[2];

   // Opal Kelly Instantiations to implement the registers (device interface)

   okWireIn     ep00  // End Point Address
      (.ok1(ok1), .ok2(ok2), .ep_addr(8'h00), .ep_dataout(diEpAddr));

   okWireIn     ep01  // Register Address
      (.ok1(ok1), .ok2(ok2), .ep_addr(8'h01), .ep_dataout(diRegAddr));

   okWireIn     ep02  // Register Data In from PC 
      (.ok1(ok1), .ok2(ok2), .ep_addr(8'h02), .ep_dataout(diRegDataIn));

   okWireOut    ep20  // Register Data Out to PC
      (.ok1(ok1), .ok2(ok2), .ep_addr(8'h20), .ep_datain(diRegDataOut));

   okTriggerIn  ep40 // Triggers From PC
      (.ok1(ok1), .ok2(ok2),
       .ep_addr(8'h40), .ep_clk(pcClk), .ep_trigger(triggersIn));
   
   okPipeIn     ep80 
      (.ok1(ok1), .ok2(ok2),
       .ep_addr(8'h80),  .ep_write(pcWrite), .ep_dataout(pcWriteData) );

   okPipeOut    epA0 
      (.ok1(ok1), .ok2(ok2),
      .ep_addr(8'hA0),  .ep_read(pcRead), .ep_datain(pcReadData) );
   
   okBTPipeOut    epA1 
      (.ok1(ok1), .ok2(ok2),
       .ep_addr(8'hA1),  .ep_read(pcReadBT), .ep_datain(pcReadDataBT),
       .ep_blockstrobe(pcBlockStrobeBT), .ep_ready(pcReadyBT));
   
   // ------------------------------------------------------------------------
   // | Endpoint Type | Address Range  | Sync/Async    | Data Type           |
   // |---------------+----------------+---------------+---------------------|
   // | Wire In       | 0x00 - 0x1F    | Asynchronous  | Signal state        |
   // | Wire Out      | 0x20 - 0x3F    | Asynchronous  | Signal state        |
   // | Trigger In    | 0x40 - 0x5F    | Synchronous   | One-shot            |
   // | Trigger Out   | 0x60 - 0x7F    | Synchronous   | One-shot            |
   // | Pipe In       | 0x80 - 0x9F    | Synchronous   | Multi-byte transfer |
   // | Pipe Out      | 0xA0 - 0xBF    | Synchronous   | Multi-byte transfer |
   //-------------------------------------------------------------------------

   
   // Instantiate the okHostInterface and connect endpoints to
   // the target interface.
   okHostInterface 
      u0_okHI
	 (
	  .hi_in(hi_in),
	  .hi_out(hi_out),
	  .hi_inout(hi_inout),
	  .ti_clk(pcClk),
	  .ok1(ok1),
	  .ok2(ok2)
	  );
*/   
endmodule
