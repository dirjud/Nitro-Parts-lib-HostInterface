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
   Date: 1/30/2013
 
   Slave fifo implementation of a read/write interface to the cypress FX3
   part.
 
   There are two modes of operation, read_mode and write_mode
 
   read_mode: When 'di_read_mode' goes high, the 'di_term_addr', 'di_len',
     outputs will be valid.  To host can cancel a read in the middle at
     any time by sending 'di_read_mode' low.  The user must be able to
     recover from such an event and be ready for the next read or write
     operation.
 
     Each word to be read will be preceeded with 'di_read_req' being
     high.  The user feeds back 'di_read_rdy' and must hold it high
     until the host responds with a 'di_read' pulse.  When this is
     high, then the host will issue a 'di_read' and advance the
     'di_reg_addr'.  If more bytes are to be transfered, 'di_read_req'
     will go high.  You can tie 'di_read_rdy' high for any terminals
     for maximal data rates if the terminal can retrieve data fast
     enough.
 
     ########################################################################
     ########################    SLOW READ EXAMPLE    #######################
     ########################################################################
             ___ _______________________________________________________
     di_len  ___X__0x2__________________________________________________
                    ________________________________________________
     di_read_mode _/                                                \___
                    __                     __
     di_read_req  _/  \___________________/  \__________________________
                                _____________           _____
     di_read_rdy  _____________/             \_________/     \__________
                                           __              __
     di_read      ________________________/  \____________/  \__________
                                ______________          ______
     di_reg_datao XXXXXXXXXXXXXX______________XXXXXXXXXX______XXXXXXXXXX
                                    byte 0                1
                  ________________________ _______________ _____________
     di_reg_addr  ________________________X_______________X_____________
                         addr 0                  1              2

     In this example, the host reads two words.  The user receives the
     'di_read_req' pulse and responsed when his data is available by
     raising 'di_read_rdy'. He holds it high until the host pulses the
     'di_read'.  Simultaneously, the host issues the second
     'di_read_req' pulse, to which the user responds similarly.  The
     host issues a final 'di_read' without an associated 'di_read_req'
     to end the transfer.
 
     ########################################################################
     ########################    FAST READ EXAMPLE    #######################
     ########################################################################
              ___ _______________________________________________________
     di_len   ___X__0x6__________________________________________________
                      ________________________________________________
     di_read_mode____/                                                \__
                      _______________             _______
     di_read_req ____/               \___________/       \_______________
                  _______________________________________________________
     di_read_rdy_/                                            
                          _______________             _______
     di_read      _______/               \___________/       \___________
                  ___________ ___ ___ ___ _______________ ___ ___________
     di_reg_datao ___________X___X___X___X_______________X___X___________
                      byte 0   1   2   3               4   5
                  _______ ___ ___ ___ _______________ ___ _______________
     di_reg_addr  _______X___X___X___X_______________X___X_______________
                  addr 0   1   2   3               4   5   6

     In this example, the host reads six words.  The user is holding 
     'di_read_rdy' high, so the host will clock data out as fast it can.
     The host throttles the read after the first four words by dropping 
     'di_read_req/di_read'.

     The 'di_reg_addr' changes with 'di_read', so the user can register
     'di_reg_datao' if necessary. 
 
     ########################################################################
     ########################      WRITE EXAMPLES     #######################
     ########################################################################

     For terminals that can write in a single clock cycle, you can hold
     the di_write_rdy high and sample the di_reg_datai when di_write goes
     high.

             ___ _______________________________________________________
     di_len  ___X__0x2__________________________________________________
                       _________________________________________________
     di_write_mode ___/
                                ___     ___
     di_write      ____________/   \___/   \____________________________
                   _____________________________________________________
     di_write_rdy                  
                   ____________ _______ ____________________
     di_reg_datai  ____________X_______X____________________
                                byte 0   byte 1          

                  _____________ _______ ___________________
     di_reg_addr  _____________X_______X___________________
                                addr+0    addr+1   

     For terminals (like serial devices) that require time to write
     the data, you should drop the di_write_rdy signal when di_write
     goes high and raise it when the write has completed. For a slow
     terminal, you should gate di_write_rdy combinatorial with di_write
     like this:

        assign di_write_rdy = !di_write && !my_terminal_is_busy;

     With this approach, you can kick off the write to your terminal
     using the write signal and use the di_write_rdy to signal when
     the write has completed. The host interface will wait to issue
     the next write until the di_write_rdy is received. You must
     hold di_write_rdy normally high in order to receive the first
     di_write pulse.
 
             ___ _______________________________________________________
     di_len  ___X__0x2__________________________________________________
                       _________________________________________________
     di_write_mode ___/
                                ___                 ___
     di_write      ____________/   \_______________/   \________________
                   ____________                 ___               ______
     di_write_rdy              \_______________/   \_____________/
                   ____________ ___________________ ____________________
     di_reg_datai  ____________X___________________X____________________
                                      byte 0            byte 1
                  _____________ ___________________ ________________
     di_reg_addr  _____________X___________________X________________
                                      addr+0            addr+1

 */


module Fx3HostInterface
  (
   input wire 	     ifclk,
   input wire 	     resetb,

   input wire 	     fx3_hics_b,
   input 	     fx3_dma_rdy_b,
   output reg 	     fx3_sloe_b,
   output reg 	     fx3_slrd_b,
   output reg 	     fx3_slwr_b,
   output reg 	     fx3_pktend_b,
   output reg [1:0]  fx3_fifo_addr,
   input [31:0]      fx3_fd_in,
   output [31:0]     fx3_fd_out,
   output 	     fx3_fd_oe,
//   inout [31:0]      fx3_fd,
   
   output [15:0]     di_term_addr,
   output reg [31:0] di_reg_addr,
   output [31:0]     di_len,

   output reg 	     di_read_mode,
   output reg 	     di_read_req,
   output reg 	     di_read,
   input wire 	     di_read_rdy,
   input [31:0]      di_reg_datao,

   input [15:0] 	     i2c_addr,
   output [7:0]     i2c_data,

   output reg [15:0] checksum,
   output reg [15:0] status,
   
   output reg 	     di_write,
   input wire 	     di_write_rdy,
   output reg 	     di_write_mode,
   output [31:0]     di_reg_datai,
   input [15:0]      di_transfer_status
   );

   // synthesis attribute IOB of fd_out        is "TRUE";
   // synthesis attribute IOB of fx3_hics_b    is "TRUE";
   // synthesis attribute IOB of fx3_fifo_addr is "TRUE";
   // synthesis attribute IOB of fx3_slrd_b    is "TRUE";
   // synthesis attribute IOB of fx3_slwr_b    is "TRUE";
   // synthesis attribute IOB of fx3_sloe_b    is "TRUE";
   // synthesis attribute IOB of fx3_pktend_b  is "TRUE";
   // synthesis attribute IOB of fx3_dma_rdy_b is "TRUE";
   // synthesis attribute IOB of fd_in         is "TRUE";
   
   wire [31:0] transfer_len;
   reg  cmd_start;
   reg 	dma_rdy_b;
   wire dma_rdy = !dma_rdy_b;
   reg [31:0] fd_in, fd_out;
   reg [31:0] cmd_buf[0:3];

   reg [7:0]  tmp_count;
   
//   assign fx3_fd = (fx3_sloe_b) ? fd_out : 32'hZZZZZZZZ;
   assign fx3_fd_oe = fx3_sloe_b;
   assign fx3_fd_out = fd_out;
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
         dma_rdy_b <= 0;
         fd_in <= 0;
         cmd_start <= 1;
      end else begin
         dma_rdy_b <= fx3_dma_rdy_b;
         fd_in <= fx3_fd_in;
         cmd_start <= fx3_hics_b;
      end
   end
   
   parameter [1:0] WRITE_EP = 3;
   parameter [1:0] CMD_EP   = 1;
   parameter [1:0] READ_EP  = 0;
   parameter 
     IDLE          = 0,
     RCV_CMD       = 1,
     PROCESS_CMD   = 2,
     SEND_ACK      = 3;
   reg [1:0] state;
   reg [31:0] tcount; // transfer count
   wire [31:0] next_tcount = tcount + 4;

   reg [11:0] bcount; // buffer count  
   wire [11:0] next_bcount = bcount + 4;
 
   parameter [15:0] READ_CMD = 16'hC301;
   parameter [15:0] WRITE_CMD= 16'hC302;
   wire [31:0] di_starting_reg_addr;
   
   wire [15:0] cmd             = cmd_buf[0][15:0];
   wire [11:0] buffer_length   = cmd_buf[0][27:16];
   assign di_term_addr         = cmd_buf[1][15:0];
   // cmd_buf[1][31:16] is unused
   assign di_starting_reg_addr = cmd_buf[2];
   assign di_len               = cmd_buf[3];

//   reg [15:0] checksum, status;
   reg 	      slrd_b_s, slrd_b_ss, slrd_b_sss;
   
   wire       write_in_process =  !fx3_slrd_b || !slrd_b_s || !slrd_b_ss || !slrd_b_sss || di_write;
   wire       latch_fd_in = !slrd_b_sss;
   reg 	      wait_for_next_buffer;
   wire [31:0] fifo_rdata;
   wire        fifo_full, fifo_empty;
   reg 	       pktend;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
         state            <= IDLE;
         di_read_mode     <= 0;
         di_write_mode    <= 0;
         di_write         <= 0;
         di_read          <= 0;
         di_read_req      <= 0;
         tcount           <= 0;
         bcount           <= 0;
//         di_reg_datai     <= 0;
	 di_reg_addr      <= 0;
         
         fx3_sloe_b       <= 0; // FX3 drives the bus when reset
         fx3_slrd_b       <= 1; // No read enable yet
         fx3_slwr_b       <= 1; // No write enable
         fx3_pktend_b     <= 1;
         pktend           <= 0;
         fx3_fifo_addr    <= 2'b11;

         fd_out           <= 0;
         checksum         <= 0;
         status           <= 0;
	 cmd_buf[0] <= 0;
	 cmd_buf[1] <= 0;
	 cmd_buf[2] <= 0;
	 cmd_buf[3] <= 0;
	 slrd_b_s   <= 1;
	 slrd_b_ss  <= 1;
	 slrd_b_sss <= 1;
	 wait_for_next_buffer <= 0;

	 tmp_count <= 0;
	 
      end else begin
         di_read_mode     <= ((state == PROCESS_CMD) || (state == SEND_ACK)) && (cmd == READ_CMD);
         di_write_mode    <= ((state == PROCESS_CMD) || (state == SEND_ACK)) && (cmd == WRITE_CMD);
         status           <= di_transfer_status;

	 slrd_b_s  <= fx3_slrd_b;
	 slrd_b_ss <= slrd_b_s;
	 slrd_b_sss <= slrd_b_ss;
	 
	 
         if(cmd_start) begin
	    // When cmd_start (flagc) goes high, it must force the
	    // host interface to stop any other commands in progress
	    // and receive the new command.  This is a way to ensure
	    // the PC can always pull the FX3 and the FPGA into a
	    // known state no matter what it may have done.
            state         <= RCV_CMD;
            tcount        <= 0;
            bcount        <= 0;
            fx3_sloe_b    <= 0; 
            fx3_slrd_b    <= 1; // No read enable yet
            fx3_slwr_b    <= 1; // No write enable
            fx3_pktend_b  <= 1; 
            pktend        <= 0; 
            fx3_fifo_addr <= CMD_EP;
            checksum      <= 0;

            di_read_mode  <= 0;
            di_write_mode <= 0;
            di_write      <= 0;
            di_read       <= 0;
            di_read_req   <= 0;
//            di_reg_datai  <= 0;
	    di_reg_addr   <= 0;

            fd_out        <= 0;
            status        <= 0;
	    cmd_buf[0]    <= 0;
	    cmd_buf[1]    <= 0;
	    cmd_buf[2]    <= 0;
	    cmd_buf[3]    <= 0;
            
         end else begin

            case(state)
              IDLE: begin
		 // There is no way out of the idle state from within
		 // this logic.  Instead, the fx3 raises flagc, which
		 // causes the if statement above to take priority and
		 // pull us out of the idle state.
                 fx3_sloe_b    <= 0; // FX3 drives the bus when idle
                 fx3_slrd_b    <= 1; // No read enable yet
                 fx3_slwr_b    <= 1; // No write enable
                 fx3_pktend_b  <= 1; // No write enable
                 pktend        <= 0; // No write enable
                 fx3_fifo_addr <= CMD_EP;
                 tcount        <= 0;
		 bcount        <= 0;
                 checksum      <= 0;
              end
              
              RCV_CMD: begin
                 if(tcount >= 16) begin // check if we are done
		    if(!dma_rdy) begin // wait to switch states until the current dma buffer is done
                       state  <= PROCESS_CMD;
                       tcount <= 0;
		       bcount <= 0;
		       tmp_count <= tmp_count + 1;

		       if (cmd == WRITE_CMD) begin
			  di_reg_addr    <= di_starting_reg_addr - 1;
			  fx3_fifo_addr  <= WRITE_EP;
		       end else begin
			  di_reg_addr    <= di_starting_reg_addr;
			  fx3_fifo_addr  <= READ_EP;
		       end
		    end
                 end else begin
                    if(dma_rdy && (bcount < 16)) begin
                       fx3_slrd_b <= 0;         // assert read enable
		       bcount <= next_bcount;
                    end else begin
		       fx3_slrd_b <= 1;
		    end
		    
                    if(latch_fd_in) begin
                       cmd_buf[tcount[3:2]] <= fd_in; // sample the input 
                       tcount <= next_tcount;      // advance the cmd buf addr
		    end
		 end
              end
            
              SEND_ACK: begin // tcount should be zero upon entry
                 fx3_sloe_b    <= 1; // we drive bus to send ack
                 if (dma_rdy || (|tcount[1:0])) begin
                    fx3_slwr_b <= 0; // send the ack packet back
                    tcount     <= tcount + 1;
                    case(tcount)
		      0: fd_out <= { checksum, 16'hA50F };
		      1: begin
			 fd_out <= { 16'h0001, status   };
			 state        <= IDLE;
			 fx3_pktend_b <= 0; // commit the short packet.
		      end
		      default:fd_out <= 0;
                    endcase
		 end else begin // if (dma_rdy || (|tcount[1:0]))
                    fx3_slwr_b <= 1;
		 end
              end

              PROCESS_CMD: begin
                 
                 case(cmd)
                    READ_CMD: begin
                       fx3_sloe_b     <= 1;     // We drive the bus
                       fx3_slwr_b     <= !di_read;                       
		       fx3_pktend_b   <= !pktend;
		       
		       
                       if(di_read) begin
                          fd_out      <= di_reg_datao;
                          checksum    <= checksum + di_reg_datao[15:0];//calc checksum
                       end
                       
                       if(!di_read_mode) begin // the first cycle of read_mode
                          di_read_req <= 1;
                          di_read     <= 0;
                          
                       end else if(tcount >= di_len) begin // we're done
                          di_read      <= 0;
                          di_read_req  <= 0;
			  pktend       <= 0;
			  if(!dma_rdy) begin
			     state  <= SEND_ACK;
			     bcount <= 0;
			     tcount <= 0;
			  end
                       end else begin
			  if(dma_rdy && (bcount < buffer_length) && di_read_rdy) begin
			     di_read <= 1;
			     bcount <= next_bcount;
			     tcount <= next_tcount;
                             di_reg_addr       <= di_reg_addr + 1;
                             di_read_req       <= (next_tcount < di_len);
			     if (next_tcount >= di_len && next_bcount < buffer_length) begin
				pktend <= 1; // indicate this is a short packet to end the transfer
			     end
			  end else begin
			     di_read_req <= 0;
			     di_read     <= 0;
			     if(!dma_rdy) begin
				bcount <= 0;
			     end
			  end
                       end
                    end
                   
                   WRITE_CMD: begin
                      fx3_sloe_b    <= 0; //  FX3 drives the bus

		      if(tcount >= di_len) begin
			 fx3_slrd_b <= 1;
			 if(fifo_empty && !dma_rdy && !write_in_process) begin
			    fx3_fifo_addr <= READ_EP;
			    state <= SEND_ACK;
			    tcount <= 0;
			    bcount <= 0;
			 end
		      end else if(dma_rdy && (bcount < buffer_length) && !fifo_full) begin
			 fx3_slrd_b <= 0;
			 bcount <= next_bcount;
			 tcount <= next_tcount;
                      end else begin
			 fx3_slrd_b <= 1;
			 if(!dma_rdy) begin
			    bcount <= 0;
			 end
		      end

		      if(latch_fd_in) begin
                         checksum <= checksum + fd_in[15:0]; //calc checksum
		      end

		      if(!fifo_empty && di_write_rdy) begin
			 di_write     <= 1;
			 di_reg_addr  <= di_reg_addr + 1;
			 //di_reg_datai <= fifo_rdata;
		      end else begin
			 di_write <= 0;
		      end

                   end
                      
                   default: begin
                      state <= IDLE;
                   end
                 endcase
              end
            endcase
         end
      end
   end

   wire fifo_re = !fifo_empty && di_write_rdy;
   wire fifo_we = di_write_mode && latch_fd_in;
   
   fx3_fifo fx3_fifo
     (.clk   (ifclk),
      .resetb(di_write_mode),
      .we    (fifo_we),
      .wdata (fd_in),
      .re    (di_write),
      .rdata (di_reg_datai), //(fifo_rdata),
      .full  (fifo_full),
      .empty (fifo_empty)
      );
   
   assign i2c_data = (i2c_addr == 0) ? 8'hed :
 		     (i2c_addr == 1) ? tmp_count            :
		     (i2c_addr == 2) ? cmd_buf[0][7:0]      :
		     (i2c_addr == 3) ? cmd_buf[0][15:8]     :
		     (i2c_addr == 4) ? cmd_buf[0][23:16]    :
		     (i2c_addr == 5) ? cmd_buf[0][31:24]    :
		     (i2c_addr == 6) ? cmd_buf[1][7:0]      :
		     (i2c_addr == 7) ? cmd_buf[1][15:8]     :
		     (i2c_addr == 8) ? cmd_buf[1][23:16]    :
		     (i2c_addr == 9) ? cmd_buf[1][31:24]    :
		     (i2c_addr ==10) ? cmd_buf[2][7:0]      :
		     (i2c_addr ==11) ? cmd_buf[2][15:8]     :
		     (i2c_addr ==12) ? cmd_buf[2][23:16]    :
		     (i2c_addr ==13) ? cmd_buf[2][31:24]    :
		     (i2c_addr ==14) ? cmd_buf[3][7:0]      :
		     (i2c_addr ==15) ? cmd_buf[3][15:8]     :
		     (i2c_addr ==16) ? cmd_buf[3][23:16]    :
		     (i2c_addr ==17) ? cmd_buf[3][31:24]    :
		     (i2c_addr ==18) ? { dma_rdy, cmd_start, state } :
		     8'h00;

endmodule

module fx3_fifo
  #(parameter LOG2_DEPTH=2)
  (
   input clk,
   input resetb,
   input we,
   input [31:0] wdata,
   input re,
   output [31:0] rdata,
   output full,
   output empty
   );

   
   reg [31:0] data[0:(1<<LOG2_DEPTH)-1];
   reg [LOG2_DEPTH-1:0] waddr, raddr, count;
   wire [LOG2_DEPTH-1:0] next_waddr = waddr + 1;
   wire [LOG2_DEPTH-1:0] next_raddr = raddr + 1;

   assign rdata = data[raddr];

   assign full = count > 1;
   assign empty = ((count == 0) || (count == 1 && re)) && !we;
   
   always@(posedge clk) begin
      if(!resetb) begin
	 waddr <= 0;
	 raddr <= 0;
	 count <= 0;
      end else begin
	 if(we) begin
	    data[waddr] <= wdata;
	    if(re || !full) begin
	       waddr <= next_waddr;
	    end
	 end
	 if(re) begin
	    if(we || !empty) begin
	       raddr <= next_raddr;
	    end
	 end

	 // update empty and full flags
	 if(we || re) begin
	    if(we && re) begin
	       // empty and full flags don't change when re and we happen
	       // simultanesouly
	    end else if(re) begin
	       count <= count - 1;
	    end else begin
	       count <= count + 1;
	    end
	 end
      end
   end // always@ (posedge clk)

endmodule
