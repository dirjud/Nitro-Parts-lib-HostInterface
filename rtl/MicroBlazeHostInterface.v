/**
 * Copyright (C) 2013 BrooksEE, LLC.
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
   input [15:0]      GPO1,
   input [7:0] 	     GPO2,
   output reg [15:0] GPI1,
   
   output [15:0]     di_term_addr,
   output [31:0]     di_reg_addr,
   output [31:0]     di_len,

   output reg 	     di_read_mode,
   output reg 	     di_read_req,
   output reg 	     di_read,
   input wire 	     di_read_rdy,
   input [31:0]      di_reg_datao,

   output reg 	     di_write,
   input wire 	     di_write_rdy,
   output reg 	     di_write_mode,
   output [31:0]     di_reg_datai,
   input [15:0]      di_transfer_status
   );


   assign di_term_addr = GPO1;
   assign di_reg_addr  = {4'b0, IO_Address[29:2] }; // TOP two bits of mcs addr are always 1
   assign di_len       = 1;
   assign di_reg_datai = IO_Write_Data;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 di_read_mode  <= 0;
	 di_write_mode <= 0;
	 IO_Ready      <= 0;
	 IO_Read_Data  <= 0;
	 di_read_req   <= 0;
	 di_read       <= 0;
	 GPI1          <= 0;
      end else begin
	 if(di_read || di_write) begin
	    IO_Ready <= 1;
	    GPI1     <= di_transfer_status;
	 end else begin
	    IO_Ready <= 0;
	 end
	 IO_Read_Data <= di_reg_datao;
	 
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
	 end else if(di_write_mode) begin
	    if(di_write) begin
	       di_write_mode <= 0;
	       di_write <= 0;
	    end else begin
	       di_write <= di_write_rdy;
	    end
	 end else begin
	    di_write <= 0;
	 end
      end
   end
   
endmodule
