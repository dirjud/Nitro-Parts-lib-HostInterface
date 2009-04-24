
USERDEV_PATH=../userdev
SIM_TOP=pcb.v
OBJ_DIR=obj_dir
SIM_FILES = ../rtl/HostInterface.v \
		    ../rtl/IOBuf.v \
			di/XEM3010EndPoint.v
INCLUDE_PATHS=di			

include ../userdev/sim.mk


trace.vcd: Vpcb.so
	python test.py

