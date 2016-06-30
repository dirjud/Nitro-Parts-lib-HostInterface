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

module i2c_host
  (
   input 	 clk,
   
   inout 	 SCL,
   inout 	 SDA
   );

   reg [6:0] term_addr     /* verilator public */;
   reg [15:0] reg_addr     /* verilator public */;
   reg [31:0] reg_datai    /* verilator public */;
   reg [31:0] reg_datao    /* verilator public */;
   reg write_mode          /* verilator public */;
   reg i2c_re              /* verilator public */;
   reg i2c_we              /* verilator public */;
   wire i2c_done           /* verilator public */;
   wire i2c_busy           /* verilator public */;
   wire [6:0] i2c_status   /* verilator public */;

   initial begin
      term_addr=0;
      reg_addr =0;
      reg_datai=0;
      write_mode=0;
      i2c_we =0;
      i2c_re =0;
   end


   pullup p1(SCL);
   pullup p2(SDA);

   wire sda_in, sda_out, sda_oeb, scl_in, scl_out, scl_oeb;

   assign sda_in = SDA;
   assign scl_in = SCL;

   assign SDA = (sda_oeb == 0) ? sda_out : 1'bz;
   assign SCL = (scl_oeb == 0) ? scl_out : 1'bz;

   reg [3:0] reset_count = 0;
   wire reset_n = &reset_count;
   always @(posedge clk) begin
      if(!reset_n) begin
	 reset_count <= reset_count + 1;
      end
   end
   wire [11:0] clk_divider = 12'd4;
   
   
   i2c_master
     #(.NUM_ADDR_BYTES(2),
       .NUM_DATA_BYTES(4))
   i2c_master
     (
      .clk(clk),
      .reset_n(reset_n),
      .clk_divider(clk_divider), // sets the 1/4 scl period
      .chip_addr(term_addr),
      .reg_addr(reg_addr),
      .datai(reg_datai),
      .open_drain_mode(1'b1),
      .we(i2c_we),
      .write_mode(write_mode),
      .re(i2c_re),
      .status(i2c_status),
      .done(i2c_done),
      .busy(i2c_busy),
      .datao(reg_datao),
      .sda_in(sda_in),
      .sda_out(sda_out),
      .sda_oeb(sda_oeb),
      .scl_in(scl_in),
      .scl_out(scl_out),
      .scl_oeb(scl_oeb)
      );
   
`ifndef verilator
/***********************************************************/
/********************** GENERIC VERILOG MODEL **************/
/***********************************************************/
   
    integer i;
    integer txcount;
    integer rxcount;

    wire [15:0] rd_buf_size = 1024*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER; 
    wire [15:0] wr_buf_size = 1024*`FX3_WRITE_BUFFERS*`FX3_BUF_MULTIPLIER; 
    // final destination buffer for reads and writes
    reg [7:0] rdwr_data_buf[0:1024*`FX3_READ_BUFFERS*`FX3_BUF_MULTIPLIER-1];

   /**
    * each io call sends a command to the FPGA
    **/
   task _sendcmd;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [7:0]  cmd;
      input [31:0] length;
      begin
         hics_b=1;
         repeat (50) @(posedge clk);
         hics_b=0;
         repeat (20) @(posedge clk);
         cbuf[0] = {
             cmd == 1 ? rd_buf_size :
                        wr_buf_size,
                        8'hc3, cmd };
         cbuf[1] = { 16'b0, term_addr };
         cbuf[2] = reg_addr;
         cbuf[3] = length;
         cmd_ptr = 0;
         wptr = 0;
         wend = 0;
         rptr = 0;
         rdone = 0;
         repeat (3) @(posedge clk);
      end
   endtask


   /**
    * Simulate an FX3 get command.
    **/
   task get;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      output [31:0] value;
      begin
         read(term_addr,reg_addr, 4);
         value = { rdwr_data_buf[3], rdwr_data_buf[2], rdwr_data_buf[1], rdwr_data_buf[0] };
      end
   endtask

   // Get a register wider than 32b. specify the width of the register in
   // in bits and this will loop through starting at 'reg_addr' doing 16b
   // gets until it has retrieved all words in the wide register. Return
   // value has a max of 1024 bits.
   task getW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      output [1023:0] value;
      integer        wcount;
      begin
         value = 0;//clear out the return value first
         for(wcount=0; wcount<width; wcount=wcount+32) begin // loop through reg
            read(term_addr,reg_addr+(wcount/32), 4);
            value = value | ({ rdwr_data_buf[3], rdwr_data_buf[2], rdwr_data_buf[1], rdwr_data_buf[0] } << wcount);
            `ifdef DEBUG_FX3 
              $display("%d getW: wcount=%d buf[0]=0x%x buf[1]=0x%x buf[2]=0x%x buf[3]=0x%x",$time, wcount, rdwr_data_buf[0], rdwr_data_buf[1], rdwr_data_buf[2], rdwr_data_buf[3]);
            `endif
         end
        `ifdef DEBUG_FX3 
         $display("%d getW: value=0x%x",$time, value);
        `endif
      end
   endtask


   
   /**
    * Simulate an FX3 set command
    **/
   task set;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] value;
      begin
         rdwr_data_buf[0] = value[7:0];
         rdwr_data_buf[1] = value[15:8];
         rdwr_data_buf[2] = value[23:16];
         rdwr_data_buf[3] = value[31:24];
         write(term_addr,reg_addr,4);
      end
   endtask

   // Set a wide register. See getW() documentation.
   task setW;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [9:0] width;
      input [1023:0] value;
      integer        wcount;
      for(wcount=0; wcount<width; wcount=wcount+32) begin
         rdwr_data_buf[0] = 8'hFF & (value >> wcount);
         rdwr_data_buf[1] = 8'hFF & (value >> (wcount+8));
         rdwr_data_buf[2] = 8'hFF & (value >> (wcount+16));
         rdwr_data_buf[3] = 8'hFF & (value >> (wcount+23));
         write(term_addr,reg_addr+(wcount/32),4);
      end
   endtask


   /**
    * Simulate an FX3 read command
    **/
   task read;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] length;
      begin
         _sendcmd( term_addr, reg_addr, 1, length ); 
         rxcount = 0;
         while(rxcount < length + 8) begin 
            if(rdone || (full_b==0)) begin 
               repeat (10) @(posedge clk);

               for(i=0; i<rptr; i=i+1) begin 
                  rdwr_data_buf[rxcount] = rbuf[i][7:0];
                  rdwr_data_buf[rxcount+1] = rbuf[i][15:8];
                  rdwr_data_buf[rxcount+2] = rbuf[i][23:16];
                  rdwr_data_buf[rxcount+3] = rbuf[i][31:24];
                  rxcount = rxcount + 4;
               end 
               rdone = 0;
               rptr  = 0;
            end 
            @(posedge clk);
            
            //if(main_time >= timeout_time) {
            //  free(rx_data);                         
            //  throw Exception(USB_COMM, "Timed out");
            //}
         end 
      end
   endtask

   /**
    * Simulate an FX3 write command
    **/
   task write;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [31:0] length;
      begin
         _sendcmd ( term_addr, reg_addr, 2, length );
         txcount = 0;
         
         while (txcount < length) begin
            while ( empty_b ) begin
               @(posedge clk);
            end
            for (i=0;i<256 && txcount < length; i=i+1) begin
               wbuf[i] = { rdwr_data_buf[txcount+3], rdwr_data_buf[txcount+2], rdwr_data_buf[txcount+1] , rdwr_data_buf[txcount] };
               txcount = txcount + 4;
            end
            wptr = 0;
            wend = i;

            repeat(4) @(posedge clk);
         end

         // wait for ack
         while (rptr < 2) begin
            @(posedge clk);
         end
         
         repeat (10) @(posedge clk);
      end
   endtask

`else 
/***********************************************************/
/********************** VERILATOR CODE *********************/
/***********************************************************/

 `systemc_header
#include <i2c_verilator.cpp>
 `systemc_interface
   I2CDevice *i2c_dev;    // Pointer to object we are embedding
 `systemc_ctor
   i2c_dev = new I2CDevice(); // Construct contained object
   i2c_dev->term_addr  = &term_addr ;
   i2c_dev->reg_addr   = &reg_addr  ;
   i2c_dev->i2c_status = &i2c_status;
   i2c_dev->reg_datai  = &reg_datai ;
   i2c_dev->reg_datao  = &reg_datao ;
   i2c_dev->i2c_re     = &i2c_re    ;
   i2c_dev->i2c_we     = &i2c_we    ;
   i2c_dev->write_mode = &write_mode;
   i2c_dev->i2c_busy   = &i2c_busy  ;
 `systemc_dtor
   delete i2c_dev;    // Destruct contained object
 `verilog
`endif
   
endmodule
