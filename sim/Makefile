INC_PATHS = rtl_auto

SIM_FILES = tb.v ../models/fx2.v fpga.v ../rtl/HostInterface.v rtl_auto/FastTerminal.v rtl_auto/NeverReadReadyTerminal.v rtl_auto/SlowTerminal.v


test: test.vcd

vlog: sim.vcd

# these are verilator tests
test.vcd: Vtb.so test.py
	nosetests -v test.py

# these are iverilog tests
sim.vcd: $(SIM_FILES) tests.v
	iverilog -o sim.vvp -I rtl_auto tests.v $(SIM_FILES)
	vvp sim.vvp

CUSTOM_CPPFLAGS:=-I `python -c 'import os, nitro; print os.path.join ( os.path.split( nitro.__file__ )[0], "include" )'` $(CPPFLAGS)

rtl_auto/%Terminal.v: terminals.py
	mkdir -p rtl_auto
	di -v $* -o rtl_auto terminals.py

rtl_auto/terminals_defs.v: terminals.py
	mkdir -p rtl_auto
	di -o rtl_auto terminals.py

include verilator.mk
