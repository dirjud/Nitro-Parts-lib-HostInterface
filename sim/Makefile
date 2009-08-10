INC_PATHS = rtl_auto

SIM_FILES = tb.v fx2.v ../rtl/HostInterface.v rtl_auto/FastTerminal.v rtl_auto/NeverReadReadyTerminal.v rtl_auto/SlowTerminal.v

test: test.vcd

test.vcd: Vtb.so test.py
	nosetests -v test.py


CUSTOM_CPPFLAGS = -I ~/prj/nitro/drivers/python/include

rtl_auto/%Terminal.v: terminals.py
	mkdir -p rtl_auto
	di -v $* -o rtl_auto terminals.py


include verilator.mk
