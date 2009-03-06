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
    input wire rd_ready,
    input wire wr_ready
    );

//parameter IDLE =        4'b0000;
// op codes
parameter SETEP =       4'b0001;
parameter SETREG =      4'b0010;
parameter SETRVAL =     4'b0011;
parameter RDDATA =      4'b0100;
parameter RESETRVAL =   4'b0101;
parameter GETRVAL =     4'b0110;
parameter RDTC    =     4'b0111;
parameter WRDATA =      4'b1000;

    
// host stuff
reg [3:0] state_code;
reg hi_drive_rdy, hi_rdy, hi_drive_data;
assign rdy=hi_drive_rdy?hi_rdy:
       state_code == SETRVAL ? wr_ready:
       rd_ready;

reg [3:0] state_code_old; // for detecting sc change
reg [2:0] ctlreg;
wire rdwr_b = ctlreg[1];
reg [15:0] hiDataIn;
reg [15:0] hiDataOut;
reg [15:0] rd_tc;
reg [15:0] rd_rdy_cnt;

wire [15:0] datain;
wire [15:0] dataout;

reg hi_read_save,hi_read_save_s;
reg [15:0] hi_save_data;

wire [1:0] gpif_debug = {ctl[2],ctl[0]};

assign dataout = hi_drive_data ? hiDataOut : diRegDataOut;

reg we; // output enable

// register inputs
always @(posedge if_clock) begin
 state_code <= state;
 state_code_old <= state_code;
 hiDataIn <= datain;

 ctlreg <= ctl;
end



IOBuf iob[15:0] (
 .we(we),//.we(we_n),
 .data(data),
 .in(datain),
 .out(dataout)
);
//assign data = (we) ? hiDataOut: 16'hZ;

// device stuff


reg [1:0] state_flgs; // for use within each state
    
always @(posedge if_clock or negedge resetb) begin

 if (!resetb) begin
    diEpAddr <= 0;
    diRegAddr <= 0;
    diRegDataIn <= 0;
    //hiDataOut <= 0;
    rd_tc <= 0;
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
  hi_drive_rdy <= 0;
  hi_rdy <= 0;
  hi_drive_data <= 0;
  rd_rdy_cnt <= 0;
  hi_read_save <= 0;
  hi_read_save_s <= 0;
  hi_save_data <= 0;
 end else begin
    case (state_code)
        default:
         begin end
       SETEP:
            begin
             hi_drive_rdy <= 1;
             hi_rdy <= 1;
             if(rdwr_b) begin
                diEpAddr <= hiDataIn;
             end
            end
       SETREG:
        begin
            hi_drive_rdy <= 1;
            hi_rdy <= 1;
            if(rdwr_b) begin
                diRegAddr <= hiDataIn;
            end
        end
       SETRVAL:
            begin
                diWrite <= ctl[1];
                diRegDataIn <= datain;
            end
       GETRVAL:
            begin
                diRead <= ctl[1];
                we <= 1;
            end
       RDTC:
            begin
                hi_drive_rdy <= 1;
                hi_rdy <= 1;
                if ( rdwr_b ) begin
                    rd_tc <= hiDataIn;
                end
            end
       RDDATA:
            begin
                hi_drive_rdy <= 1;
                hi_drive_data <= 1;

/*
                if (!rdwr_b && diRead) begin
                    hi_rdy <= 0;
                    hi_read_save <= 1;
                    hi_save_data <= diRegDataOut;
                end else begin
                    hi_rdy <= diRead;
                end

                if (hi_read_save && rdwr_b) begin
                   hi_rdy <= 1; 
                   hi_read_save <= 0;
                   hi_read_save_s <= 1;
                end

                if (hi_read_save_s) begin
                    hiDataOut <= hi_save_data;
                    hi_read_save_s <= 0;
                end else begin
                    hiDataOut <= diRegDataOut;
                end */

                hi_rdy <= diRead;
                hiDataOut <= diRegDataOut;

               if (rdwr_b && rd_ready && rd_tc>0) begin //&& !hi_read_save) begin
                  diRead <= 1;
                  rd_tc <= rd_tc - 1;
                end else begin
                  diRead <= 0;
                end
                we <= 1; 
            end
      endcase
   end
 end

end
    
    
endmodule
