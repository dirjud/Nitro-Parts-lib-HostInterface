/**
 * Copyright (C) 2014 BrooksEE, LLC.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 **/

/* Author: Lane Brooks
   Date: 9/30/2014
 
 */


module MicroBlazeHostInterface
 #(DI_DATA_WIDTH=32)
  (
   input wire 	     ifclk,
   input wire 	     resetb,

   input 	     IO_Addr_Strobe, 
   input 	     IO_Read_Strobe, 
   input 	     IO_Write_Strobe, 
   input [31:0]      IO_Address,
   input [3:0] 	     IO_Byte_Enable, 
   input [31:0]      IO_Write_Data, 
   output reg [31:0] IO_Read_Data, 
   output reg 	     IO_Ready, 
   input [15:0]      mcs_term_addr,
   output reg [15:0] mcs_transfer_status,
   
   output [15:0]     di_term_addr,
   output [31:0]     di_reg_addr,
   output [31:0]     di_len,

   output reg 	     di_read_mode,
   output reg 	     di_read_req,
   output reg 	     di_read,
   input wire 	     di_read_rdy,
   input [DI_DATA_WIDTH-1:0]      di_reg_datao,

   output reg 	     di_write,
   input wire 	     di_write_rdy,
   output reg 	     di_write_mode,
   output [DI_DATA_WIDTH-1:0]     di_reg_datai,
   input [15:0]      di_transfer_status
   );


   assign di_term_addr = mcs_term_addr;
   assign di_reg_addr  = {4'b0, IO_Address[29:2] }; // TOP two bits of mcs addr are always 1
   assign di_len       = IO_Byte_Enable == 4'hF ? 4 :
                         IO_Byte_Enable == 4'h3 ? 2 :
                         IO_Byte_Enable == 4'h1 ? 1 :
                         1;
   // verilator lint_off WIDTH
   // TODO for 16 bit di width this is ignoring the top 16 bits.
   assign di_reg_datai = IO_Write_Data;
   // verilator lint_on WIDTH
   reg 		     di_wrote, di_write_done;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 di_read_mode  <= 0;
	 di_write_mode <= 0;
	 IO_Ready      <= 0;
	 IO_Read_Data  <= 0;
	 di_read_req   <= 0;
	 di_read       <= 0;
	 di_write      <= 0;
	 di_wrote      <= 0;
	 di_write_done <= 0;
     mcs_transfer_status <= 0;
      end else begin
	 if(di_read || di_write_done) begin
	    IO_Ready <= 1;
	    mcs_transfer_status   <= di_transfer_status;
	 end else begin
	    IO_Ready <= 0;
	 end
     // verilator lint_off WIDTH
	 IO_Read_Data <= di_reg_datao;
     // verilator lint_on WIDTH
	 
	 if(IO_Read_Strobe) begin
	    di_read_mode <= 1;
	    di_read_req  <= 1;
	 end else begin
	    di_read_req  <= 0;
	    if(di_read_mode) begin
	       if(di_read) begin
		  di_read      <= 0;
		  di_read_mode <= 0;
	       end else begin
		  di_read <= di_read_rdy;
	       end
	    end else begin
	       di_read <= 0;
	    end
	 end

	 if(IO_Write_Strobe) begin
	    di_write_mode <= 1;
	    di_write <= 0;
	    di_wrote <= 0;
	    di_write_done <= 0;
	 end else if(di_write_mode) begin
	    if(di_write) begin
	       di_wrote <= 1; // record write so can watch for write_rdy afterward
	    end
	    if(di_wrote && di_write_rdy) begin
	       di_write_mode <= 0;
	       di_write_done <= 1;
	    end
	    if(di_write) begin
	       //di_write_mode <= 0;
	       di_write <= 0;
	    end else if(!di_wrote) begin
	       di_write <= di_write_rdy;
	    end
	 end else begin
	    di_write <= 0;
	    di_write_done <= 0;
	 end
      end
   end
   
endmodule
