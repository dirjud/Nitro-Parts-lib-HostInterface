SYN_FILES=top.v ../models/fx2.v fpga.v \
	rtl_auto/*Terminal.v \
	../rtl/HostInterface.v

all: sim.vcd

sim: $(SYN_FILES)
	iverilog -o sim -I rtl_auto $(SYN_FILES)

sim.vcd: sim
	vvp sim
