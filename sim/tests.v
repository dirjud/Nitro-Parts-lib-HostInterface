/**
 * Copyright (C) 2009 Ubixum, Inc. 
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


/* Desciption: These are some verilog self-checking tests of gets and
 sets.  They are written in behavioral verilog, so they are simulator
 neutral. They do not work with verilator.
 */

`include "terminals_defs.v"

module tests;
   integer i;
   reg [15:0]  value;
   reg [15:0]  set_val[0:3];
   reg [15:0]  get_val[0:3];
   reg [`WIDTH_Fast_wide_reg-1:0] wide_reg_get, wide_reg_set;
   
   reg 	       passed;
   
   initial begin
      tb.fpga.reset_cnt = 0;
      
      $dumpfile ( "sim.vcd" );
      $dumpvars ( 0, tb );
      $display( "Running Simulation" );

      passed = 1;
      
      set_val[0] = 16'hAAAA;
      set_val[1] = 16'h5555;
      set_val[2] = 16'h1234;
      set_val[3] = 16'hFEDC;

      
      // do some sets and gets and verify
      tb.fx2.set(`TERM_Fast, `Fast_fast_buf0, set_val[0]);
      tb.fx2.set(`TERM_Slow, `Slow_slow_buf0, set_val[2]);
      tb.fx2.set(`TERM_Fast, `Fast_fast_buf1, set_val[1]);
      tb.fx2.set(`TERM_Slow, `Slow_slow_buf1, set_val[3]);

      tb.fx2.get(`TERM_Fast, `Fast_fast_buf0, get_val[0]);
      tb.fx2.get(`TERM_Fast, `Fast_fast_buf1, get_val[1]);
      tb.fx2.get(`TERM_Slow, `Slow_slow_buf0, get_val[2]);
      tb.fx2.get(`TERM_Slow, `Slow_slow_buf1, get_val[3]);

      for(i=0; i<4; i=i+1) begin
	 if(set_val[i] !== get_val[i]) begin
	    passed = 0;
	    $display("FAIL: Set/Get verify %d: set=0x%x get=0x%x", i, set_val[i], get_val[i]);
	 end else begin
	    $display("PASS: Set/Get verify %d: set=0x%x get=0x%x", i, set_val[i], get_val[i]);
	 end
      end
      
      do_bbsets(`TERM_Fast, 0, 160);
      do_bbsets(`TERM_Slow, 0, 160);
      do_bbgets(`TERM_Fast, 160);
      do_bbgets(`TERM_Slow, 160);

      wide_reg_set = 73'h123fedcba9876543211;// initial reset value
      tb.fx2.getW(`TERM_Fast, `Fast_wide_reg, `WIDTH_Fast_wide_reg, wide_reg_get);
      check_setW_getW();

      wide_reg_set = 73'h0ff3debc9a785634124;
      tb.fx2.setW(`TERM_Fast, `Fast_wide_reg, `WIDTH_Fast_wide_reg, wide_reg_set);
      tb.fx2.getW(`TERM_Fast, `Fast_wide_reg, `WIDTH_Fast_wide_reg, wide_reg_get);
      check_setW_getW();
      
      if(passed) begin
	 $display("PASS: All tests");
      end else begin
	 $display("FAIL: All tests");
      end

      
      
      #100
      
      $finish;
   end

   task check_setW_getW;
      begin
	 if(wide_reg_get !== wide_reg_set) begin
	    $display("FAIL: getW test: set:0x%x get:0x%x", wide_reg_set, wide_reg_get);
	    passed = 0;
	 end else begin
	    $display("PASS: getW test: set:0x%x get:0x%x", wide_reg_set, wide_reg_get);
	 end
      end
   endtask // check_setW_getW
   

   task do_bbsets;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      input [7:0]  count;
      begin
	 for (i = 0; i< count; i=i+1 ) begin
	    tb.fx2.set ( term_addr, reg_addr+i, i );
	 end
	 
	 for (i=0; i< count; i=i+1 ) begin
	    tb.fx2.get ( term_addr, reg_addr+i, value );
	    if ( value != i ) begin
	       $display ( "Get/Set mismatch ", term_addr, reg_addr+i, " Got ", value, " Expected", i );
	       passed =0;
	       
	    end
	 end
	 
      end
   endtask
   
   reg [15:0] tmp;
   task do_bbgets;
      input [15:0] term_addr;
      input [31:0] reg_addr;
      begin
	 
	 tb.fx2.get(term_addr, reg_addr, value ); 
	 for (i=0;i<10;i=i+1) begin
	    tb.fx2.get(term_addr,reg_addr, tmp );
	    if (value != tmp) begin
	       $display ( "Back-to-back get mismatch value: " , tmp , " expected: " , value );
	       passed=0;
	    end
	 end
      end
   endtask
endmodule