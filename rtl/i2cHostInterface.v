// Author: Lane Brooks
// Date: May 26, 2016
//
// Description: This implemenents a i2c slave to host interface
// controller.  This will match any i2c chip address and set it as the
// terminal address.  A future implementation could take in an array
// of terminal addresses to match.


module i2cHostInterface
  #(parameter NUM_ADDR_BYTES=2,
    parameter NUM_DATA_BYTES=4,
    parameter REG_ADDR_WIDTH=8*NUM_ADDR_BYTES,
    parameter REG_DATA_WIDTH=8*NUM_DATA_BYTES)
   (
    input 	      clk,
    input 	      reset_n,
    input 	      sda_in,
    output 	      sda_out,
    output 	      sda_oeb,
    input 	      scl_in,
    output 	      scl_out,
    output reg	      scl_oeb,

    output reg [15:0] di_term_addr,
    output [31:0]     di_reg_addr,
    output [31:0]     di_len,

    output reg 	      di_read_mode,
    output reg 	      di_read_req,
    output reg 	      di_read,
    input wire 	      di_read_rdy,
    input [31:0]      di_reg_datao,

    output 	      di_write,
    input wire 	      di_write_rdy,
    output reg 	      di_write_mode,
    output reg [31:0] di_reg_datai,
    input [15:0]      di_transfer_status

    );

   parameter STATE_WAIT=0,
             STATE_SHIFT=1,
             STATE_ACK=2, 
             STATE_ACK2=3,
             STATE_WRITE=4,
             STATE_CHECK_ACK=5,
             STATE_SEND=6,
             STATE_WRITE_WAIT=7;
   
   reg we, done, busy;
   reg [REG_ADDR_WIDTH-1:0] reg_addr;
   reg [2:0] state;
   reg       scl_s, sda_s, scl_ss, sda_ss, sda_reg, oeb_reg;
   reg [7:0]  sr;
   reg [1:0]  reg_byte_count;
   reg [1:0]  addr_byte_count;
   reg        rw_bit;
   reg [REG_DATA_WIDTH-1:0] sr_send;
   reg        nack;

   assign scl_out = 0;
   assign sda_oeb = oeb_reg;
   assign sda_out = sda_reg;

   assign di_len = NUM_DATA_BYTES;
   assign di_write = we;
   
   wire       open_drain_mode = 1;
   function set_sda_reg;
      input   out1;
      begin
         set_sda_reg = (open_drain_mode) ? 0 : out1;
      end
   endfunction
   function set_oeb_reg;
      input   oeb;
      input   out1;
      begin
         set_oeb_reg = (open_drain_mode) ? out1 : oeb;
      end
   endfunction
      
   /* verilator lint_off WIDTH */
   assign di_reg_addr = reg_addr;
   /* verilator lint_on WIDTH */

   
   always @(posedge clk) begin
      scl_s <= scl_in;
      scl_ss <= scl_s;
      sda_s <= sda_in;
      sda_ss <= sda_s;
   end

   wire [7:0] word = { sr[6:0], sda_s };
   /* verilator lint_off WIDTH */
   wire [REG_DATA_WIDTH-1:0] word_expanded = word;
   /* verilator lint_on WIDTH */
   

   wire       scl_rising  =  scl_s && !scl_ss;
   wire       scl_falling = !scl_s &&  scl_ss;
   wire       sda_rising  =  sda_s && !sda_ss;
   wire       sda_falling = !sda_s &&  sda_ss;
   

   wire [REG_ADDR_WIDTH+8-1:0] shifted_reg_addr = { reg_addr, word };
   
   
`ifdef SYNC_RESET
   always @(posedge clk) begin
`else
   always @(posedge clk or negedge reset_n) begin
`endif      
      if(!reset_n) begin
	 scl_oeb <= 1;
	 di_write_mode <= 0;
	 di_term_addr <= 0;
	 di_read_mode <= 0;
 	 di_read_req <= 0;
	 di_read <= 0;
	 di_reg_datai <= 0;
         sda_reg <= 1;
         oeb_reg <= 1;
         reg_byte_count <= 0;
	 addr_byte_count <= 0;
         sr <= 8'h01;
         state <= STATE_WAIT;
         di_reg_datai <= 0;
         reg_addr <= 0;
         we   <= 0;
         rw_bit <= 0;
         sr_send <= 0;
         nack <= 0;
         done <= 0;
         busy <= 0;
      end else begin
         if(scl_ss && sda_falling) begin // start code
            reg_byte_count <= 0;
            addr_byte_count <= 0;
            sr <= 8'h01;
            state <= STATE_SHIFT;
            sda_reg <= set_sda_reg(1);
            oeb_reg <= set_oeb_reg(1, 1);
            we <= 0;
            busy <= 1;
            done <= 0;
	    scl_oeb <= 1;
	    di_write_mode <= 0;
	    di_read_mode <= 0;
 	    di_read_req <= 0;
	    di_read <= 0;
         end else if(scl_ss && sda_rising) begin // stop code
            state <= STATE_WAIT;
            sda_reg <= set_sda_reg(1);
            oeb_reg <= set_oeb_reg(1, 1);
            we <= 0;
            if(busy) done <= 1;
	    scl_oeb <= 1;
	    di_write_mode <= 0;
	    di_read_mode <= 0;
 	    di_read_req <= 0;
	    di_read <= 0;
         end else begin
	    if(state == STATE_WRITE_WAIT) begin
	       if(di_write_rdy) begin
                  we <= 1;
	       	  /* verilator lint_off WIDTH */
		  reg_byte_count <= reg_byte_count + 1 - NUM_DATA_BYTES;
		  /* verilator lint_on WIDTH */
		  state <= STATE_WRITE;
		  scl_oeb <= 1;
	       end else if(scl_s == 0) begin
		  scl_oeb <= 0; // if the clock goes low and we are still not ready, then hold the clock low to clock extend.
	       end
            end if(state == STATE_WAIT) begin
	       scl_oeb <= 1;
               done <= 0;
               we <= 0;
               reg_byte_count <= 0;
               addr_byte_count <= 0;
               sr <= 8'h01; // preload sr with LSB 1.  When that 1 reaches the MSB of the shift register, we know we are done.
               sda_reg <= set_sda_reg(1);
               oeb_reg <= set_oeb_reg(1, 1);
               busy <= 0;
            end else if(state == STATE_SHIFT) begin
	       scl_oeb <= 1;
               sda_reg <= set_sda_reg(1);
               oeb_reg <= set_oeb_reg(1, 1);
               if(scl_rising) begin
                  sr <= word;
                  if(sr[7]) begin
		     if(addr_byte_count <= NUM_ADDR_BYTES) begin
			addr_byte_count <= addr_byte_count + 1;

			if(addr_byte_count == 0) begin // 1st byte (i2c addr)
			   /* verilator lint_off WIDTH */
			   di_term_addr <= { 9'b0, word[7:1] };
			   /* verilator lint_on WIDTH */
                           rw_bit <= word[0];
                           sr_send <= di_reg_datao; 
                           state <= STATE_ACK;
			   if (word[0]) begin // read
			      di_read_mode <= 1;
			      di_read_req  <= 1;
			   end
			end else begin // remaining addr bytes (reg addr)
                           state <= STATE_ACK;
                           reg_addr <= shifted_reg_addr[REG_ADDR_WIDTH-1:0];
			end
                     end else begin 
			// LSB of transfer count is used to track which
			// byte of the 16 bit word is being collected.
			// MSB of transfer count is only 0 at the begining
			// of the packet to signal the address is being
			// collected.  After the address has been received,
			// then it is all data after that.
			di_reg_datai <= (di_reg_datai << 8) | word_expanded;
			di_write_mode <= 1;
			
			/* verilator lint_off WIDTH */
                        if(reg_byte_count == NUM_DATA_BYTES-1) begin // Least significant byte
			/* verilator lint_on WIDTH */
                           state <= STATE_WRITE_WAIT;
                        end else begin              // Most significant byte
                           state <= STATE_ACK;
			   reg_byte_count <= reg_byte_count + 1;
                        end                     
                     end
                  end
               end
            end else if(state == STATE_WRITE) begin
               // Stay here one clock cycle before moving to ACK to
               // give 'we' a single clock cycle high.
	       if(|di_transfer_status) begin
		  state <= STATE_WAIT; // NACK
	       end else begin
		  state <= STATE_ACK;
	       end
	       reg_addr  <= reg_addr + 1; // advance addr for the case of seq writes
               we    <= 0;
               sda_reg <= set_sda_reg(1);
               oeb_reg <= set_oeb_reg(1, 1);
            end else if(state == STATE_ACK) begin
	       di_read_req <= 0;
               we <= 0;
               // when scl falls, drive sda low to ack the received byte
               if(!scl_ss) begin
		  if(|di_transfer_status || !di_read_rdy) begin
		     // if there is an error or if the terminal is
		     // not ready to read. TO DO: implement
		     // clock stretching in the event di_read_rdy is not
		     // ready.
                     state <= STATE_WAIT; // NACK
                     done <= 1;
		  end else begin
		     if(di_read_mode) begin
			di_read <= 1;
			di_read_req <= 1;
		     end
                     sda_reg <= set_sda_reg(0);
                     oeb_reg <= set_oeb_reg(0, 0);
                     state <= STATE_ACK2;
                     if(rw_bit && (reg_byte_count == 0)) begin
			sr_send <= di_reg_datao;
		     end
		  end
               end             
            end else if(state == STATE_ACK2) begin
	       di_read <= 0;
	       di_read_req <= 0;
               sr <= 8'h01;
               we <= 0;
               // on the falling edge go back to shifting in data
               if(scl_falling) begin
                  if(rw_bit) begin // when master is reading, go to STATE_SEND
                     state <= STATE_SEND;
                     sda_reg <= set_sda_reg(sr_send[REG_DATA_WIDTH-1]);
                     oeb_reg <= set_oeb_reg(0, sr_send[REG_DATA_WIDTH-1]);
                     sr_send <= sr_send << 1;
                  end else begin // when master writing, receive in STATE_SHIFT
                     state <= STATE_SHIFT;
                     sda_reg <= set_sda_reg(1);
                     oeb_reg <= set_oeb_reg(1, 1);
                  end
               end
            end else if(state == STATE_CHECK_ACK) begin
               sr <= 8'h01;
               if(scl_rising) begin
                  nack <= sda_s;
               end 
               if(scl_falling) begin
                  if(nack) begin
                     state <= STATE_WAIT; // we received a nack, so we are done
                     done <= 1;
                     sda_reg <= set_sda_reg(1);
                     oeb_reg <= set_oeb_reg(1, 1);
                  end else begin
                     state <= STATE_SEND; // we received an ack, so more data requested
                     sda_reg <= set_sda_reg(sr_send[REG_DATA_WIDTH-1]);
                     oeb_reg <= set_oeb_reg(0, sr_send[REG_DATA_WIDTH-1]);
                     sr_send <= sr_send << 1;
                  end
               end
            end else if(state == STATE_SEND) begin
               if(scl_falling) begin
                  sr <= word;
                  if(sr[7]) begin
                     reg_byte_count <= reg_byte_count + 1;
                     sda_reg <= set_sda_reg(1);
                     oeb_reg <= set_oeb_reg(1, 1);
                     state <= STATE_CHECK_ACK;

		     /* verilator lint_off WIDTH */
                     if(reg_byte_count == NUM_DATA_BYTES-1) begin
			/* verilator lint_on WIDTH */
                        reg_addr <= reg_addr + 1; // advance the internal address so that the next address data is available after this transfer.
			reg_byte_count <= 0;
                     end
                     

                  end else begin
                     sda_reg <= set_sda_reg(sr_send[REG_DATA_WIDTH-1]);
                     oeb_reg <= set_oeb_reg(0, sr_send[REG_DATA_WIDTH-1]);
                     sr_send <= sr_send << 1;
                  end
               end
            end
         end
      end
   end 
endmodule // i2c_slave
