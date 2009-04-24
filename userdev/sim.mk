# In your makefile:
# defin USERDEV_PATH = the path where this Makefile and tb.cpp are located
# define SIM_FILES = all the files to 
# define SIM_TOP location of your pcb.v file.
# 	SIM_TOP must have the host interface pins defined 
#   and it must be named pcb.v (until we fix verilator to be able to dynamically set control pins by a name
#   See pcb.v.sample
# define OBJ_DIR = Where ever you want the verilator output dumpted.
# define INCLUDE_PATHS = any additional include directories for verilator

Vpcb.so: $(OBJ_DIR)/Vpcb.mk $(USERDEV_PATH)/tb.cpp
	make -C $(OBJ_DIR) -f Vpcb.mk \
	USER_CPPFLAGS="-I $(OBJ_DIR) -fPIC -g" \
	USER_LDFLAGS="-lnitro -shared -o Vpcb.so"
	cp $(OBJ_DIR)/Vpcb ./Vpcb.so

$(OBJ_DIR): $(OBJ_DIR)
	mkdir -p $(OBJ_DIR)

$(OBJ_DIR)/Vpcb.mk: $(SIM_TOP) $(SIM_FILES)
	verilator -cc -I$(INCLUDE_PATHS) $(SIM_TOP) $(SIM_FILES) -exe $(USERDEV_PATH)/tb.cpp --trace

