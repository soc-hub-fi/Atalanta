######################################################################
# SS local vsim makefile
# Author: Matti Käyrä (Matti.kayra@tuni.fi)
#
######################################################################
BUILD_DIR ?= $(realpath $(CURDIR))/../build
START_TIME=`date +%F_%H:%M`
DATE=`date +%F`

SHELL=bash

DUT = tb_rt_ss

# library specific OPTS etc can be appended in actual library target

COMMON_CELLS_INC_DIRS = +incdir+../ips/common_cells/include/ \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/ \
						+incdir+../ips/register_interface/include \
						+incdir+../ips/apb/include \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/dv/sv/dv_utils/
AXI_INC_DIRS = $(COMMON_CELLS_INC_DIRS) +incdir+../ips/axi/include/


SOC_CONNECTIVITY =
DEBUG =
RVFI =

VLOG_DEFINES = $(SOC_CONNECTIVITY) $(DEBUG) $(RVFI)

# Test params
TEST      ?= dummy
jtag_test ?= 0
SW_TEST   ?= 0

ifeq ($(TEST), jtag_test)
	jtag_test = 1
else
	SW_TEST = 1
	IMEM_STIM = "../stims/$(TEST)_imem.hex"
	DMEM_STIM = "../stims/$(TEST)_dmem.hex"
endif

LOAD ?= JTAG


TEST_PARAMS =   -G TestName=$(TEST) \
				-G ImemStim=$(IMEM_STIM) \
				-G DmemStim=$(DMEM_STIM) \
				-G JtagTest=$(jtag_test) \
				-G Load=$(LOAD) \
				-G SoftwareTest=$(SW_TEST)



LIBS = \
	-L $(BUILD_DIR)/rt_ss_lib 

VOPT_OPTS = "-check_synthesis"
VOPT_OPTS += "-pedanticerrors"
VOPT_OPTS += "+acc=npr"
#Prints out information where elaboration picks up the module
VOPT_OPTS += "-libverbose=prlib"

VSIM_OPTS = "-c"

#generally no supresses allowd: need to be approved to be included
VLOG_SUPPRESS = -suppress vlog-2583 \
				-suppress vlog-2244
VCOM_SUPPRESS =
VOPT_SUPPRESS = -suppress vopt-2577 \
				-suppress vopt-13262
VSIM_SUPPRESS = -suppress vsim-8360


PHONY: check_env
check_env:
	mkdir -p $(BUILD_DIR)/logs/compile
	mkdir -p $(BUILD_DIR)/logs/opt
	mkdir -p $(BUILD_DIR)/logs/sim


.PHONY: compile
compile: check_env
	vlib $(BUILD_DIR)/rt_ss_lib
	vmap rt_ss_lib $(BUILD_DIR)/rt_ss_lib
	vlog -sv -work rt_ss_lib $(VLOG_DEFINES) \
	$(AXI_INC_DIRS) $(VLOG_SUPPRESS) $(LIBS) \
	-f ../src/ss-files.list -f ../src/tb-files.list \
	-l $(BUILD_DIR)/logs/compile/$(START_TIME)_verilog_vlog.log

.PHONY: compile_tieoff
compile_tieoff: check_env
	cd $(BUILD_DIR)
	vlog -sv ../src/wrapper/rt_ss_wrapper_0_tieoff.sv \
	-l $(BUILD_DIR)/logs/compile/vlog-tieoff.log

.PHONY: elaborate
elaborate: check_env
	cd $(BUILD_DIR)
	vopt \
	$(VOPT_OPTS) \
	$(TEST_PARAMS) \
	$(VOPT_SUPPRESS) \
	$(VSIM_SUPPRESS) \
	$(LIBS) \
	-work $(BUILD_DIR)/rt_ss_lib \
	$(DUT) \
	-o $(DUT)_opt \
	-l $(BUILD_DIR)/logs/opt/$(START_TIME)_$(DUT)_vopt.log

.PHONY: dut_sanity_check
dut_sanity_check: check_env elaborate
	cd $(BUILD_DIR)
	vsim \
	$(VSIM_OPTS) \
	$(VOPT_SUPPRESS) \
	$(VSIM_SUPPRESS) \
	$(LIBS) \
	-work $(BUILD_DIR)/rt_ss_lib \
	$(DUT)_opt \
	-do "run 0; exit" \
	-l $(BUILD_DIR)/logs/sim/$(DUT)_vsim.log

.PHONY: run_batch
run_batch: check_env elaborate
	cd $(BUILD_DIR)
	vsim \
	$(VSIM_OPTS) \
	-wlf wave.wlf \
	$(VOPT_SUPPRESS) \
	$(VSIM_SUPPRESS) \
	$(LIBS) \
	-work $(BUILD_DIR)/rt_ss_lib \
	$(DUT)_opt \
	-do 	"log -r /*; \
			run -all; \
	 		exit" \
	-l $(BUILD_DIR)/logs/sim/$(DUT)_vsim.log

.PHONY: run_gui
run_gui: check_env elaborate
	cd $(BUILD_DIR)
	vsim \
	$(VOPT_SUPPRESS) \
	$(VSIM_SUPPRESS) \
	$(LIBS) \
	-work $(BUILD_DIR)/rt_ss_lib \
	$(DUT)_opt \
	-do "log -r /*;" \
	-l $(BUILD_DIR)/logs/sim/$(DUT)_vsim.log

.PHONY: wave
wave:
	vsim wave.wlf
