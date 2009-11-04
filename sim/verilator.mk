##############################################################################
# Author:  Lane Brooks
# Date:    04/28/2006
# License: GPL
# Desc:    This is a Makefile intended to take a verilog rtl design and
#          simulate it with verilator.  This file is generic and just a
#          template.  As such all design specific options such as source files,
#          library paths, options, etc, should be set in a top Makefile prior
#          to including this file.  Alternatively, all parameters can be passed
#          in from the command line as well.
#
##############################################################################
#
# Parameter:
#   SIM_FILES - Space seperated list of Simulation files
#   SYN_FILES - Space seperated list of RTL files
#   SIM_LIBS  - Space seperated list of library paths to include for simulation
#   SIM_DEFS  - Space seperated list of `defines that should be set for sim
#   SIM_ARGS  - Space seperated list of args for $test$plusargs("arg") options
#
# Example "../config.mk" Makefile:
#
#   SIM_FILES = testbench.v
#   SYN_FILES = fpga.v fifo.v clks.v
#   SIM_LIBS  = /opt/xilinx/ise/verilog/unisyms
#   SIM_DEFS  = GATES ASYNC_RESET
#   SIM_ARGS  = testIO
############################################################################# 
# This file gets called in the sim directory
#

# verilator command and path
VERILATOR=verilator

# verilator cpp file
VERILATOR_CPP_FILE=$(SIM_DIR)tb.cpp
TOP_MODULE=tb

VERILATOR_CPPFLAGS=-I ../ -fPIC -I`python -c 'import  distutils.sysconfig; print distutils.sysconfig.get_python_inc()'` -I`python -c 'import numpy; print \"/\".join(numpy.__file__.split(\"/\")[:-1])+\"/core/include\"'`
VERILATOR_LDFLAGS=`python -c 'import distutils.sysconfig as x; print x.get_config_var(\"LIBS\"), x.get_config_var(\"BLDLIBRARY\")'` -shared -lnitro

CUSTOM_LDFLAGS:=$(CUSTOM_LDFLAGS)
ifdef LD_LIBRARY_PATH
 LDPATHS=$(subst :, , $(LD_LIBRARY_PATH)) 
 CUSTOM_LDFLAGS+=$(foreach p, $(LDPATHS), -L$(p) )
endif


# Check for and include local Makefiles for any project specific
# targets check for a local config file
-include ../config.mk



SIM_FLAGS = $(patsubst %, +define+%, $(SIM_DEFS)) $(SIM_ARGS) $(patsubst %, +incdir+%,$(INC_PATHS))
LIB_ARGS  = +libext+.v $(patsubst %,-y %,$(SIM_LIBS)) 

#LIB_ARGS  = +libext+.v $(patsubst %,-y %,$(SIM_LIBS)) 
#SIM_FLAGS = +ncaccess+rw +define+SIM $(patsubst %, +define+%, $(SIM_DEFS)) $(patsubst %, +%, $(SIM_ARGS))

.PHONY: lint sim

sim: V$(TOP_MODULE).so

# This target copies the file to have an .so file, which is necessary
# when making it a shared object like a python module.
V$(TOP_MODULE).so: obj_dir/V$(TOP_MODULE)
	cp obj_dir/V$(TOP_MODULE) V$(TOP_MODULE).so

# This target verilates and builds the simulation
obj_dir/V$(TOP_MODULE): $(SIM_FILES) $(SYN_FILES) $(INC_FILES) $(VERILATOR_FILES)
	$(VERILATOR) --trace  --cc $(SIM_FLAGS) $(LIB_ARGS)  $(VERILATOR_FILES) $(SIM_FILES) $(SYN_FILES) --exe $(VERILATOR_CPP_FILE)
	make -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE) \
	USER_CPPFLAGS="$(VERILATOR_CPPFLAGS) $(CUSTOM_CPPFLAGS)" \
	USER_LDFLAGS="$(VERILATOR_LDFLAGS) $(CUSTOM_LDFLAGS)"



lint: $(SIM_FILES) $(SYN_FILES) $(INC_FILES)
	$(VERILATOR) --lint-only $(SIM_FLAGS) $(LIB_ARGS) $(SIM_FILES) $(SYN_FILES)

clean:
	rm -rf obj_dir
	rm -f V$(TOP_MODULE).so
	rm -f *.pyc
	rm -f *.vcd
	rm -f *.vvp
	rm -rf rtl_auto

distclean: clean
	-find ./ -type f -name "*~" -exec rm -rf {} \;

