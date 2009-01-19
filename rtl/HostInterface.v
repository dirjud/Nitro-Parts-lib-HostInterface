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
//    output wire out, // unused?
    inout wire [15:0] data,

    // Device Interface
    input wire resetb,
    
    output reg [15:0] diEpAddr,
    output reg [15:0] diRegAddr,
    output reg [15:0] diRegDataIn,
    input  wire [15:0] diRegDataOut,
    output  reg   diWrite,
    output  reg   diRead,
    output  reg   diReset,
    input wire rdwr_ready
 
    );

    
// host stuff


reg rdyr,rdyr_n;
assign rdy=rdwr_ready; //rdyr;//rdyr_n;

reg [3:0] state_code;
reg [3:0] state_code_old; // for detecting sc change
reg [2:0] ctlreg;
wire rdwr_b = ctlreg[1];
reg [15:0] hiDataIn;
reg [15:0] hiDataOut,hiDataOut_n;

wire [15:0] datain;
wire [15:0] dataout;

assign dataout = hiDataOut; //, hiDataOut_n;

reg we,we_n; // output enable

// register inputs
always @(posedge if_clock) begin
 state_code <= state;
 state_code_old <= state_code;
 hiDataIn <= datain;
 ctlreg <= ctl;
end

// register outputs
/* always @(negedge if_clock) begin
 rdyr_n <= rdyr;
 hiDataOut_n <= hiDataOut;
 we_n <= we;
 // add a negedge for out if we decide to use that one too.
end */


IOBuf iob[15:0] (
 .we(we),//.we(we_n),
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
parameter SETRVAL =     4'b0011; // should just use wrdata
parameter RDDATA =      4'b0100;
parameter RESETRVAL =   4'b0101;
parameter WRDATA =      4'b0111;


reg [1:0] state_flgs; // for use within each state
    
always @(posedge if_clock or negedge resetb) begin

 if (!resetb) begin
    diEpAddr <= 0;
    diRegAddr <= 0;
    diRegDataIn <= 0;
    //hiDataOut <= 0;
 end else begin

 // you following block causes the host interface
 // to require at least one clock cycle between
 // changing states and setting rdwr_b.
 // shouldn't be a problem since states are set on the firmware
 // side before enabling the gpif
 if (state_code_old != state_code) begin
  state_flgs <= 0;
  diWrite <= 0;
  diRead <= 0;
  diReset <= 0;
  we <= 0;
  rdyr <= 0;
 end else begin
    case (state_code)
        default:
         begin end
       SETEP:
           //if (!state_flgs[0]) begin
                if(rdwr_b) begin
                   diEpAddr <= hiDataIn;
           //        state_flgs[0] <= 1;
                end
           //end
       SETREG:
           //if (!state_flgs[0]) begin
               if(rdwr_b) begin
                   diRegAddr <= hiDataIn;
           //        state_flgs[0]<= 1;
               end
           //end
       SETRVAL:
            begin
                diWrite <= ctl[1];
                diRegDataIn <= datain;
            end
           //if (!state_flgs[0]) begin
           //    if(rdwr_b) begin
           //        state_flgs[0] <= 1;
           //        diRegDataIn <= hiDataIn ;
           //        diWrite <= 1; // trigger one cycle write
           //    end
           //end else begin
           //    diWrite <= 0;
           //end
       RDDATA:
            begin
                //diRead <= rdwr_b;
                diRead <= ctl[1];
                we <= 1;
                hiDataOut <= diRegDataOut;
                rdyr <= rdwr_ready;
            end
      endcase
   end
 end

end
    
    
endmodule
