/* Author: Lane Brooks
   Date: 8/8/2009
 
   Slave fifo implementation of a read/write interface to the cypress FX2
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
 
             ___ _______________________________________________________
     di_len  ___X__0x2__________________________________________________
                       _________________________________________________
     di_write_mode ___/
                                ___                 ___
     di_write      ____________/   \_______________/   \________________
                   ________________             _______           ______
     di_write_rdy                  \___________/       \_________/
                   ____________ ___________________ ____________________
     di_reg_datai  ____________X___________________X____________________
                                      byte 0            byte 1

 
             ___ _______________________________________________________
     di_len  ___X__0x2__________________________________________________
                       _________________________________________________
     di_write_mode ___/
                                ___     ___
     di_write      ____________/   \___/   \____________________________
                   _____________________________________________________
     di_write_rdy                  
                                          
 
 
 
 */


module HostInterface
  (
   input wire ifclk,
   input wire resetb,

   input [2:0] fx2_flags,
   output reg fx2_sloe_b,
   output reg fx2_slrd_b,
   output reg fx2_slwr_b,
   output reg fx2_pktend_b,
   output reg [1:0] fx2_fifo_addr,
   inout [15:0] fx2_fd,
   
   output     [15:0] di_term_addr,
   output reg [31:0] di_reg_addr,
   output reg [31:0] di_len,

   output reg        di_read_mode,
   output reg        di_read_req,
   output reg        di_read,
   input wire        di_read_rdy,
   input      [15:0] di_reg_datao,

   output reg        di_write,
   input wire        di_write_rdy,
   output reg        di_write_mode,
   output reg [15:0] di_reg_datai,
   input [15:0]      di_transfer_status
   );

   wire [31:0] transfer_len;
   reg [2:0] flags;
   wire  empty_b     = flags[0];
   wire  full_b      = flags[1];
   wire  cmd_start   = flags[2];

   reg [15:0] fd_in, fd_out;
   reg [15:0] cmd_buf[0:7];
   wire [15:0] fx2_fd_in =fx2_fd;
   assign fx2_fd = (fx2_sloe_b) ? fd_out : 16'hZZZZ;
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
         flags <= 0;
         fd_in <= 0;
      end else begin
         flags <= fx2_flags;
         fd_in <= fx2_fd_in;
      end
   end
   
   parameter [1:0] WRITE_EP = 0;
   parameter [1:0] READ_EP  = 2;
   parameter 
     IDLE          = 0,
     RCV_CMD       = 1,
     PROCESS_CMD   = 2,
     SEND_ACK      = 3;
   reg [1:0] state;
   reg [31:0] tcount;
   wire [31:0] next_tcount = tcount + 1;
   
   parameter [15:0] READ_CMD = 16'hC301;
   parameter [15:0] WRITE_CMD= 16'hC302;
  
   wire [15:0] cmd     = cmd_buf[0];
   assign di_term_addr     = cmd_buf[1];
   reg [15:0] checksum, status;
   
   reg wait_buf;
   wire wait_ok = &wait_buf;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
         state            <= IDLE;
         di_read_mode     <= 0;
         di_write_mode    <= 0;
         di_write         <= 0;
         di_read          <= 0;
         di_read_req      <= 0;
         tcount           <= 0;
         di_reg_datai     <= 0;
         
         fx2_sloe_b       <= 0; // FX2 drives the bus when reset
         fx2_slrd_b       <= 1; // No read enable yet
         fx2_slwr_b       <= 1; // No write enable
         fx2_pktend_b     <= 1; // No write enable
         fx2_fifo_addr    <= WRITE_EP;

         fd_out           <= 0;
         wait_buf         <= 0;
         checksum         <= 0;
         status           <= 0;
      end else begin
         di_read_mode     <= (state == PROCESS_CMD) && (cmd == READ_CMD);
         di_write_mode    <= (state == PROCESS_CMD) && (cmd == WRITE_CMD);
         status           <= di_transfer_status;
         
         if(cmd_start) begin
            state         <= RCV_CMD;
            tcount        <= 0;
            fx2_sloe_b    <= 0; 
            fx2_slrd_b    <= 1; // No read enable yet
            fx2_slwr_b    <= 1; // No write enable
            fx2_pktend_b  <= 1; // No write enable
            fx2_fifo_addr <= WRITE_EP;
            tcount        <= 0;
            checksum      <= 0;
            
         end else begin

            case(state)
              IDLE: begin
                 fx2_sloe_b    <= 0; // FX2 drives the bus when idel
                 fx2_slrd_b    <= 1; // No read enable yet
                 fx2_slwr_b    <= 1; // No write enable
                 fx2_pktend_b  <= 1; // No write enable
                 fx2_fifo_addr <= WRITE_EP;
                 tcount <= 0;
                 checksum      <= 0;
              end
              
              RCV_CMD: begin

                 if(fx2_slrd_b) begin
                    if (!wait_ok) begin
                        wait_buf <= wait_buf + 1;
                    end
                    if(empty_b && wait_ok) begin
                       cmd_buf[tcount[2:0]] <= fd_in; // sample the input 
                       tcount <= next_tcount;      // advance the cmd buf addr
                       fx2_slrd_b <= 0;         // assert read enable
                    end
                 end else begin
                    fx2_slrd_b <= 1; // deassert read enable
                    wait_buf <= 0;
                    if(tcount[3:0] == 8) begin
                       state <= PROCESS_CMD;
                       tcount <= 0;
                       di_reg_addr  <= { cmd_buf[3], cmd_buf[2] };
                       di_len       <= { cmd_buf[5], cmd_buf[4] } >> 1;
                    end
                 end
              end
            
              SEND_ACK: begin // tcount should be zero upon entry
                 fx2_fifo_addr   <= READ_EP;
                 if(fx2_sloe_b==0) begin
                    fx2_sloe_b      <= 1; // we drive bus to send ack
                 end else if(fx2_slwr_b) begin
                    fx2_slwr_b      <= 0; // send the ack packet back
                    tcount          <= tcount + 1;
                    case(tcount)
                      0: fd_out          <= 16'hA50F;
                      1: fd_out          <= checksum;
                      2: fd_out          <= status;
                      default:fd_out     <= tcount[15:0];
                    endcase
                 end else begin
                    fx2_slwr_b      <= 1;
                    if(tcount >= 4) begin
                       state           <= IDLE;
                       fx2_pktend_b <= 0; // commit the short packet.
                    end
                 end
              end

              PROCESS_CMD: begin
                 
                 case(cmd)
                    READ_CMD: begin
                       fx2_sloe_b     <= 1;     // We drive the bus
                       fx2_fifo_addr  <= READ_EP;
                       fx2_slwr_b     <= !di_read;
                       if(di_read) begin
                          fd_out      <= di_reg_datao;
                          checksum    <= checksum + di_reg_datao;//calc checksum
                       end
                       
                       if(!di_read_mode) begin // the first cycle of read_mode
                          di_read_req <= 1;
                          
                       end else if(tcount >= di_len) begin // we're done
                          di_read              <= 0;
                          di_read_req          <= 0;
                          if (!fx2_slwr_b) begin // send pktend after slwr_b 
			     fx2_slwr_b   <= 1;
			     fx2_pktend_b <= 0; // commit the packet.
                          end else if(!fx2_pktend_b) begin
			     fx2_pktend_b <= 1;
                             tcount <= 0;
			     state  <= SEND_ACK;
			  end
                          
                       end else begin

                          if (!wait_ok) begin
                            wait_buf <= wait_buf + 1;
                          end

                          if(full_b && di_read_rdy && wait_ok) begin
                             di_read           <= 1;
                             tcount            <= next_tcount;
                             di_reg_addr       <= di_reg_addr + 1;
                             di_read_req       <= (next_tcount < di_len);
                             wait_buf <= 0;
                          end else begin
                             di_read_req       <= 0;
                             di_read           <= 0;
                          end
                       end
                    end
                   
                   WRITE_CMD: begin
                      if(di_write) begin
                         di_reg_addr         <= di_reg_addr + 1;
                      end
                      
                      if(!di_write_mode) begin
                         fx2_fifo_addr          <= WRITE_EP;
                         fx2_sloe_b          <= 0; //  FX2 drives the bus
                      end else if(tcount >= di_len) begin // we're done
                         fx2_slrd_b         <= 1;
                         di_write           <= 0;
                         if(di_write_rdy) begin// wait for last write to finish
                            tcount <= 0;
                            state <= SEND_ACK;
                         end
                         
                      end else begin
                         fx2_fifo_addr <= WRITE_EP;
                         if(fx2_slrd_b) begin
                            if(empty_b && di_write_rdy) begin
                               fx2_slrd_b   <= 0;       // assert read enable
                               di_write     <= 1;
                               di_reg_datai <= fd_in;   // sample the data
                               checksum     <= checksum + fd_in; //calc checksum
                               tcount       <= next_tcount; // advance tcount
                            end
                         end else begin
                            fx2_slrd_b      <= 1; // deassert read enable
                            di_write        <= 0;
                         end
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
endmodule
