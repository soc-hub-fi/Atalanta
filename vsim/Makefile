######################################################################
# SS local vsim makefile
# Author: Matti Käyrä (Matti.kayra@tuni.fi)
#
######################################################################
BUILD_DIR ?= $(realpath $(CURDIR))/../build/
START_TIME=`date +%F_%H:%M`
DATE=`date +%F`

SHELL=bash

DUT = tb_rt_ss

# library specific OPTS etc can be appended in actual library target

COMMON_CELLS_INC_DIRS = +incdir+../ips/bow-common-ips/ips/pulp-common-cells/include/ \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/ \
						+incdir+../ips/register_interface/include \
						+incdir+../ips/apb/include \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/dv/sv/dv_utils/
AXI_INC_DIRS = $(COMMON_CELLS_INC_DIRS) +incdir+../ips/bow-common-ips/ips/axi/include/


SOC_CONNECTIVITY =
DEBUG =
RVFI =

VLOG_DEFINES = $(SOC_CONNECTIVITY) $(DEBUG) $(RVFI)

# Test params
IMEM_STIM = "../stims/nop_loop.hex"
DMEM_STIM = "../stims/nop_loop.hex"
JTAG_SANITY = 0
JTAG_HALT = 0
BLINK_TEST = 0
JTAG_LOAD = 0
CSR_TESTS = 0
UART_TEST = 0
TIMER_TEST = 0
DEBUG_SIM = 0
# CPU configuration
IBEX_RVE = 1


TEST_PARAMS =   -G IMEM_STIM=$(IMEM_STIM) \
				-G DMEM_STIM=$(DMEM_STIM) \
				-G JTAG_SANITY=$(JTAG_SANITY) \
				-G BLINK_TEST=$(BLINK_TEST) \
				-G JTAG_HALT=$(JTAG_HALT) \
				-G JTAG_LOAD=$(JTAG_LOAD) \
				-G CSR_TESTS=$(CSR_TESTS) \
				-G DEBUG_SIM=$(DEBUG_SIM) \
				-G UART_TEST=$(UART_TEST) \
				-G TIMER_TEST=$(TIMER_TEST) \
				-G IBEX_RVE=$(IBEX_RVE)    \
				-G CLIC_TESTS=$(CLIC_TESTS)


LIBS = \
	-L $(BUILD_DIR)/common_cells_lib \
	-L $(BUILD_DIR)/axi_lib \
	-L $(BUILD_DIR)/pll_lib \
	-L $(BUILD_DIR)/common_components_lib \
	-L $(BUILD_DIR)/rt_ss_lib \

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

# This target is used to map the compiled libraries correctly for vsim
.PHONY: library_mapping
library_mapping: check_env
	cd $(BUILD_DIR)
	vmap axi_lib $(BUILD_DIR)/axi_lib
	vmap common_cells_lib $(BUILD_DIR)/common_cells_lib
	vmap common_components_lib $(BUILD_DIR)/common_components_lib
	vmap pll_lib $(BUILD_DIR)/pll_lib
	vmap rt_ss_lib $(BUILD_DIR)/rt_ss_lib

.PHONY: compile_common_ips_libs
compile_common_ips_libs:
	$(MAKE) -C ../ips/bow-common-ips/vsim compile BUILD_DIR=$(BUILD_DIR)

.PHONY: compile
compile: check_env compile_common_ips_libs
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
elaborate: check_env library_mapping
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
dut_sanity_check: check_env library_mapping elaborate
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
run_batch: check_env library_mapping elaborate
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
run_gui: check_env library_mapping elaborate
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
