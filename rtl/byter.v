// Converts a DI interface write/read, which is either 16 or 32 bits wide,
// into a single byte stream.

module byter
  #(parameter DI_DATA_WIDTH=32)
  (
   input 		      resetb, 
   input 		      ifclk, 
   input 		      enable,

   /* word side */
   input [31:0] 	      di0_len,
   input 		      di0_write_mode,
   input 		      di0_write,
   input [DI_DATA_WIDTH-1:0]  di0_reg_datai,
   output 		      di0_write_rdy,
   input 		      di0_read_mode,
   input 		      di0_read_req,
   input 		      di0_read,
   output [DI_DATA_WIDTH-1:0] di0_reg_datao,
   output 		      di0_read_rdy,

   /* byte side */
   output reg 		      di1_read_req,
   output reg 		      di1_read,
   input [7:0] 		      di1_reg_datao,
   input 		      di1_read_rdy,
   output reg 		      di1_write,
   output [7:0] 	      di1_reg_datai,
   input 		      di1_write_rdy
   );

   reg [DI_DATA_WIDTH-1:0] 	  sr;
   assign di1_reg_datai = sr[7:0];
   reg [31:0] 			  count;
   wire [31:0] 			  next_count = count + 1;
   reg [2:0] 			  byte_pos;
   wire [2:0] 			  next_byte_pos = byte_pos + 1;
   reg 				  state;
   reg				  di0_read_rdy0;
   localparam STATE_IDLE=0, STATE_SHIFTING=1;
   reg 				  di0_write_rdy0;
   assign di0_write_rdy = di0_write_rdy0 && di1_write_rdy;
   assign di0_read_rdy = di0_read_rdy0 && !di0_read;

   assign di0_reg_datao = sr;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 di0_write_rdy0 <= 0;
	 di1_write      <= 0;
	 sr             <= 0;
	 byte_pos       <= 0;
	 di0_read_rdy0  <= 0;
	 di1_read_req   <= 0;
	 di1_read       <= 0;
	 count          <= 0;
	 state          <= 0;
	 
      end else begin
	 if(!enable || !(di0_read_mode || di0_write_mode)) begin
	    count          <= 0;
	    byte_pos       <= 0;
	    di0_write_rdy0 <= di1_write_rdy;
	    di1_write      <= 0;
	    sr             <= 0;
	    byte_pos       <= 0;
	    di0_read_rdy0  <= 0;
	    di1_read_req   <= 0;
	    di1_read       <= 0;
	    count          <= 0;
	    state          <= 0;

	 end else begin

	    if(di0_read_mode) begin
	       if(state == STATE_IDLE) begin
		  byte_pos <= 0;
		  if(di0_read) begin
		     di0_read_rdy0 <= 0;
		  end
		  di1_read <= 0;
		  
		  if(di0_read_req) begin
		     di1_read_req <= 1;
		     state <= STATE_SHIFTING;
		  end else begin
		     di1_read_req <= 0;
		  end
		  
	       end else if(state == STATE_SHIFTING) begin
		  if(di1_read_rdy && !di1_read) begin
		     di1_read <= 1;
		  end else begin
		     di1_read <= 0;
		  end
		  
		  if(di1_read) begin
		     /* verilator lint_off WIDTH */
		     if((next_byte_pos == (DI_DATA_WIDTH/8)) || (next_count == di0_len)) begin
			/* verilator lint_on WIDTH */
			state <= STATE_IDLE;
			di0_read_rdy0 <= 1;
			di1_read_req <= 0;
		     end else begin
			di1_read_req <= 1;
		     end
		     
		     byte_pos <= next_byte_pos;
		     count <= next_count;
		     /* verilator lint_off WIDTH */
		     if(byte_pos == 0) begin
			sr[DI_DATA_WIDTH-1:0] <= di1_reg_datao;
		     end else if(byte_pos == 1) begin
			sr[DI_DATA_WIDTH-1:8] <= di1_reg_datao;
		     end else if(byte_pos == 2) begin
			// these are hacks to get 16b to compile
			sr[DI_DATA_WIDTH-1:DI_DATA_WIDTH-16] <= di1_reg_datao;
		     end else if(byte_pos == 3) begin
			// these are hacks to get 16b to compile
			sr[DI_DATA_WIDTH-1:DI_DATA_WIDTH-8] <= di1_reg_datao;
		     end
		     /* verilator lint_on WIDTH */
		     
		  end else begin
		     di1_read_req <= 0;
		  end
	       end

	    end else if(di0_write_mode) begin
	       if(di1_write) begin
		  count <= next_count;
	       end
	       
	       if(state == STATE_IDLE) begin
		  if(di0_write) begin
		     di1_write     <= 1;
		     di0_write_rdy0 <= 0;
		     sr            <= di0_reg_datai;
		     byte_pos      <= 0;
		     state         <= STATE_SHIFTING;
		  end else begin
		     di1_write     <= 0;
		     di0_write_rdy0 <= di1_write_rdy;
		  end
	       end else if(state == STATE_SHIFTING) begin
		  if(di1_write_rdy && !di1_write) begin
		     byte_pos <= next_byte_pos;
		     /* verilator lint_off WIDTH */
		     if((next_byte_pos == DI_DATA_WIDTH/8) || (count == di0_len)) begin
			/* verilator lint_on WIDTH */
			di0_write_rdy0 <= 1;
			state <= STATE_IDLE;
		     end else begin
			di1_write <= 1;
			sr <= sr >> 8;
		     end
		  end else begin
		     di1_write <= 0;
		  end
	       end
	    end
	 end
      end
   end
endmodule
