INC_PATHS = rtl_auto

SIM_FILES = tb.v fx2.v fpga.v ../rtl/HostInterface.v rtl_auto/FastTerminal.v rtl_auto/NeverReadReadyTerminal.v rtl_auto/SlowTerminal.v

test: test.vcd

test.vcd: Vtb.so test.py
	nosetests -v test.py


CUSTOM_CPPFLAGS:=-I `python -c 'import os, nitro; print os.path.join ( os.path.split( nitro.__file__ )[0], "include" )'` $(CPPFLAGS)
CUSTOM_LDFLAGS:=$(CUSTOM_LDFLAGS)
ifdef LD_LIBRARY_PATH
 LDPATHS=$(subst :, , $(LD_LIBRARY_PATH)) 
 CUSTOM_LDFLAGS+=$(foreach p, $(LDPATHS), -L$(p) )
endif

rtl_auto/%Terminal.v: terminals.py
	mkdir -p rtl_auto
	di -v $* -o rtl_auto terminals.py


include verilator.mk
