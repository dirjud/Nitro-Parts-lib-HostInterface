

rtl_files = ../rtl/HostInterface.v \
		    ../rtl/IOBuf.v \
			di/XEM3010EndPoint.v

TOP = top.v

trace.vcd: Vtop
	./Vtop

Vtop: obj_dir/Vtop.mk top.cpp
	make -C obj_dir -f Vtop.mk Vtop && cp obj_dir/Vtop .

obj_dir/Vtop.mk: $(TOP) $(rtl_files)
	verilator -cc -Idi $(TOP) $(rtl_files) -exe top.cpp --trace

