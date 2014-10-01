/**
 * Copyright (C) 2014 Brooksee, LLC 
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
   Date: 11/29/2014
 
   This is a combinatorial arbiter of the Host Interface to allow multiple
   masters access to the same devices. It uses the ready signals to delay
   a master if another master is currently in process of using the bus.
 
   Since this is combinatorial, it is really adding one more layer of 
   muxing on the bus, so if timing becomes an issue, registering should be
   done as much as possible in the host and device.
 */


module hi_arbiter
  #(parameter NUM_HOSTS=2)
  (
   input wire 		      ifclk,
   input wire 		      resetb,

   input [16*NUM_HOSTS-1:0]   I_di_term_addr,
   input [32*NUM_HOSTS-1:0]   I_di_reg_addr,
   input [32*NUM_HOSTS-1:0]   I_di_len,

   input [NUM_HOSTS-1:0]      I_di_write,
   input [NUM_HOSTS-1:0]      I_di_write_mode,
   input [32*NUM_HOSTS-1:0]   I_di_reg_datai,

   input [NUM_HOSTS-1:0]      I_di_read_mode,
   input [NUM_HOSTS-1:0]      I_di_read_req,
   input [NUM_HOSTS-1:0]      I_di_read,

   input [NUM_HOSTS-1:0]      I_lock_arbiter,

   output reg [NUM_HOSTS-1:0] O_di_write_rdy,
   output reg [NUM_HOSTS-1:0] O_di_read_rdy,
   output [32*NUM_HOSTS-1:0]  O_di_reg_datao,
   output [16*NUM_HOSTS-1:0]  O_di_transfer_status,

   output [15:0] 	      di_term_addr,
   output [31:0] 	      di_reg_addr,
   output [31:0] 	      di_len,

   output 		      di_read_mode,
   output 		      di_read_req,
   output 		      di_read,
   input 		      di_read_rdy,
   input [31:0] 	      di_reg_datao,

   output 		      di_write,
   input 		      di_write_rdy,
   output 		      di_write_mode,
   output [31:0] 	      di_reg_datai,
   input [15:0] 	      di_transfer_status
   
   );

   /////////////////////////////////////////////////////////////////////////////
   // The following packing and unpacking of arrays could be handled by using
   // arrays in ports, but since xst does not support systemverilog, we have
   // to resort to manually doing it.
   /////////////////////////////////////////////////////////////////////////////
   wire [15:0] 		     I0_di_term_addr[NUM_HOSTS-1:0];
   wire [31:0] 		     I0_di_reg_addr[NUM_HOSTS-1:0];
   wire [31:0] 		     I0_di_len[NUM_HOSTS-1:0];
   wire [31:0] 		     I0_di_reg_datai[NUM_HOSTS-1:0];

   genvar 		     unpk_idx;
`define ARBITER_UNPACK_ARRAY(PK_WIDTH, PK_LEN, PK_SRC, PK_DEST)   generate for (unpk_idx=0; unpk_idx<(PK_LEN); unpk_idx=unpk_idx+1) begin; assign PK_DEST[unpk_idx][((PK_WIDTH)-1):0] = PK_SRC[((PK_WIDTH)*unpk_idx+(PK_WIDTH-1)):((PK_WIDTH)*unpk_idx)]; end; endgenerate
   
   `ARBITER_UNPACK_ARRAY(16, NUM_HOSTS, I_di_term_addr,  I0_di_term_addr  )
   `ARBITER_UNPACK_ARRAY(32, NUM_HOSTS, I_di_reg_addr,   I0_di_reg_addr   )
   `ARBITER_UNPACK_ARRAY(32, NUM_HOSTS, I_di_len,        I0_di_len	  )
   `ARBITER_UNPACK_ARRAY(32, NUM_HOSTS, I_di_reg_datai,  I0_di_reg_datai  )
   
   reg [31:0] O0_di_reg_datao[NUM_HOSTS-1:0];
   reg [15:0] O0_di_transfer_status[NUM_HOSTS-1:0];

   genvar     pk_idx;
`define ARBITER_PACK_ARRAY(PK_WIDTH, PK_LEN, PK_DEST, PK_SRC)     generate for (pk_idx=0; pk_idx<(PK_LEN); pk_idx=pk_idx+1) begin; assign PK_DEST[((PK_WIDTH)*pk_idx+((PK_WIDTH)-1)):((PK_WIDTH)*pk_idx)] = PK_SRC[pk_idx][((PK_WIDTH)-1):0]; end; endgenerate

   `ARBITER_PACK_ARRAY(32,NUM_HOSTS, O_di_reg_datao,	  O0_di_reg_datao      )
   `ARBITER_PACK_ARRAY(16,NUM_HOSTS, O_di_transfer_status,O0_di_transfer_status)
   /////////////////////////////////////////////////////////////////////////////
   
   reg [$clog2(NUM_HOSTS)-1:0] host, next_host;
   reg [NUM_HOSTS-1:0] read_fault;
   wire busy = di_read_mode || di_write_mode || I_lock_arbiter[host];
   reg 	read_req_fault;

   assign di_term_addr  = I0_di_term_addr[host];
   assign di_reg_addr   = I0_di_reg_addr[host]; 
   assign di_len        = I0_di_len[host];      
   assign di_read_mode  = I_di_read_mode[host];
   assign di_read_req   = I_di_read_req[host] || read_req_fault; 
   assign di_read       = I_di_read[host];     
   assign di_write      = I_di_write[host];     
   assign di_write_mode = I_di_write_mode[host];
   assign di_reg_datai  = I0_di_reg_datai[host];

   reg [31:0] idx, k, n;
   always @(*) begin
      for(idx=0; idx<NUM_HOSTS; idx=idx+1) begin
	 /* verilator lint_off WIDTH */
	 if(idx == host) begin
	 /* verilator lint_on WIDTH */
	    O_di_read_rdy[idx]         = di_read_rdy;	
	    O0_di_reg_datao[idx]       = di_reg_datao;	
	    O_di_write_rdy[idx]        = di_write_rdy;	
	    O0_di_transfer_status[idx] = di_transfer_status;
	 end else begin
	    // unactive hosts report they are not ready
	    O_di_read_rdy[idx]         = 0;	
	    O_di_write_rdy[idx]        = 0;	
	    O0_di_reg_datao[idx]       = 0;	
	    O0_di_transfer_status[idx] = 0;
	 end
      end
   end

   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 host <= 0;
	 read_req_fault <= 0;
	 read_fault <= 0;
      end else begin
	 next_host = host;
	 if(read_req_fault) begin
	    read_req_fault <= 0;
	 end else if(read_fault[host]) begin
	    read_req_fault <= 1;
	 end else if(!busy) begin
	    for(k=0; k<NUM_HOSTS; k=k+1) begin
	       if(I_di_read_mode[k] || I_di_write_mode[k]) begin
		  /* verilator lint_off WIDTH */
		  next_host = k;
		  /* verilator lint_on WIDTH */
	       end
	    end
	 end
	 host <= next_host;
	 read_req_fault <= read_fault[host];
	 
	 for(n=0; n<NUM_HOSTS; n=n+1) begin
	    /* verilator lint_off WIDTH */
	    if(n == host) begin
	    /* verilator lint_on WIDTH */
	       // clear the read fault for the active host
	       read_fault[n] <= 0; 
	    end else begin
	       // save off any read req received when it is not your turn
	       read_fault[n] <= I_di_read_req[n] || read_fault[n]; 
	    end
	 end
      end
   end
   
endmodule
