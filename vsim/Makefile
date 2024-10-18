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

BENDER ?= bender

# library specific OPTS etc can be appended in actual library target

#COMMON_CELLS_INC_DIRS = +incdir+../ips/bow-common-ips/ips/pulp-common-cells/include/ \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/ \
						+incdir+../ips/register_interface/include \
						+incdir+../ips/apb/include \
						+incdir+../ips/obi/include \
						+incdir+../ips/rt-ibex/vendor/lowrisc_ip/dv/sv/dv_utils/
#AXI_INC_DIRS = $(COMMON_CELLS_INC_DIRS) +incdir+../ips/bow-common-ips/ips/axi/include/

COMMON_CELLS_DIR ?= $(shell $(BENDER) path common_cells)
OBI_DIR          ?= $(shell $(BENDER) path obi)
AXI_DIR          ?= $(shell $(BENDER) path axi)
APB_DIR          ?= $(shell $(BENDER) path apb)
RT_IBEX_DIR      ?= $(shell $(BENDER) path rt-ibex)
REGIF_DIR        ?= $(shell $(BENDER) path register_interface)

INCLUDES ?= \
	+incdir+$(COMMON_CELLS_DIR)/include \
	+incdir+$(AXI_DIR)/include \
	+incdir+$(APB_DIR)/include \
	+incdir+$(OBI_DIR)/include \
	+incdir+$(REGIF_DIR)/include \
	+incdir+$(RT_IBEX_DIR)/vendor/lowrisc_ip/dv/sv/dv_utils \
	+incdir+$(RT_IBEX_DIR)/vendor/lowrisc_ip/ip/prim/rtl


SOC_CONNECTIVITY =
DEBUG =
RVFI =
FPGA = 
SYNTH_WRAPPER =

VLOG_DEFINES = $(SOC_CONNECTIVITY) $(DEBUG) $(RVFI) $(FPGA) $(SYNTH_WRAPPER)

# if using synthesisable memory models
ifdef SYNTH_MEM
VLOG_DEFINES += \
  +define+SYNTH_MEM=1 \
	+define+ARM_UD_MODEL \
	+define+ARM_DISABLE_EMA_CHECK \
	+define+NO_SDTC
endif

# Test params
TEST      ?= nop_loop
jtag_test ?= 0
SW_TEST   ?= 0
IMEM_STIM ?= "../ips/atalanta/stims/nop_loop.hex"
DMEM_STIM ?= "../ips/atalanta/stims/nop_loop.hex"
IBEX_USE_RVE  ?= 1

ifeq ($(TEST), jtag_test)
	jtag_test = 1
else
	SW_TEST = 1
	IMEM_STIM = "../ips/atalanta/stims/$(TEST)_imem.hex"
	DMEM_STIM = "../ips/atalanta/stims/$(TEST)_dmem.hex"
endif

LOAD ?= READMEM


TEST_PARAMS =   -G TestName=$(TEST) \
				-G ImemStim=$(IMEM_STIM) \
				-G DmemStim=$(DMEM_STIM) \
				-G JtagTest=$(jtag_test) \
				-G IbexRve=$(IBEX_USE_RVE) \
				-G Load=$(LOAD) \
				-G SoftwareTest=$(SW_TEST)


LIBS = \
	-L $(BUILD_DIR)/atalanta_lib \

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
VSIM_SUPPRESS = -suppress vsim-8360 \
				-suppress vsim-8386


PHONY: check_env
check_env:
	mkdir -p $(BUILD_DIR)/logs/compile
	mkdir -p $(BUILD_DIR)/logs/opt
	mkdir -p $(BUILD_DIR)/logs/sim

# This target is used to map the compiled libraries correctly for vsim
.PHONY: library_mapping
library_mapping: check_env
	cd $(BUILD_DIR)
	vmap atalanta_lib $(BUILD_DIR)/atalanta_lib

.PHONY: compile
compile: check_env
	echo $(PWD)
	vlib $(BUILD_DIR)/atalanta_lib
	vmap atalanta_lib $(BUILD_DIR)/atalanta_lib
	vlog -sv -work atalanta_lib $(VLOG_DEFINES) \
	$(INCLUDES) $(VLOG_SUPPRESS) $(LIBS) \
	$(shell bender script flist -t simulation -t test) \
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
	-work $(BUILD_DIR)/atalanta_lib \
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
	-work $(BUILD_DIR)/atalanta_lib \
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
	-work $(BUILD_DIR)/atalanta_lib \
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
	-work $(BUILD_DIR)/atalanta_lib \
	$(DUT)_opt \
	-do "log -r /*;" \
	-l $(BUILD_DIR)/logs/sim/$(DUT)_vsim.log

.PHONY: wave
wave:
	vsim wave.wlf
