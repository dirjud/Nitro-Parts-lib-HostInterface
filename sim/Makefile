

rtl_files = ../rtl/HostInterface.v \
		    ../rtl/IOBuf.v \
			di/XEM3010EndPoint.v

top = top.v

all:
	verilator -cc -Idi $(top) $(rtl_files)
