# ------------------------------------------------------------------------------
# Makefile for FPGA prototyping of RT-SS
#
# Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
# Date     : 03-dec-2023
#
# Description: Top Makefile to build the FPGA Prototype of the RT-SS
# ------------------------------------------------------------------------------

## global variables

export SUBSYTEM         ?= RT-SS
export PROJECT_NAME     ?= $(SUBSYTEM)_fpga
## valid values: PYNQZ1 | PYNQZ1
export FPGA_BOARD       ?= PYNQZ1
export DUT_TOP_MODULE   ?= rt_top_fpga_wrapper_$(FPGA_BOARD)
export TB_TOP_MODULE    ?= tb_rt_ss

export FPGA_DIR          ?= $(PWD)
export REPO_DIR          ?= $(realpath $(FPGA_DIR)/..)
export FPGA_BUILD_DIR    ?= $(FPGA_DIR)/build
export FPGA_PROJECT_DIR  ?= $(FPGA_BUILD_DIR)/$(PROJECT_NAME)
export FPGA_TCL_DIR      ?= $(FPGA_DIR)/scripts
export FPGA_IP_DIR       ?= $(FPGA_DIR)/ips
export FPGA_IP_BUILD_DIR ?= $(FPGA_BUILD_DIR)/ips
export FPGA_CONSTR_DIR   ?= $(FPGA_DIR)/constraints
export BOARD_FILES_DIR   ?= $(FPGA_DIR)/board_files

# Project synthesis defines
export FPGA_SYNTH_DEFINES ?= \
	FPGA=1
# Project simulation defines
export FPGA_SIM_DEFINES ?= \
	XSIM=1 \
	FPGA=1 \
	VERILATOR=1 \
	$(FPGA_BOARD)

# Parameters for DUT
export FPGA_DUT_PARAMS ?= \
	AXI_ADDR_WIDTH=32 \
	AXI_DATA_WIDTH=32

# Parameters for TB
export FPGA_TB_PARAMS ?=

# List of FPGA IPs used in design !!MAKE SURE THESE ARE SEPARATED BY EXACTLY ONE SPACE!!
export FPGA_IP_LIST ?= \
	top_clock


## local variables

BITSTREAM   ?= $(FPGA_PROJECT_DIR).bit
# ILA probe file (if exists)
PROBE_FILE  ?= $(FPGA_PROJECT_DIR).ltx
FPGA_IP_XCI := $(foreach ip, $(FPGA_IP_LIST), $(FPGA_IP_BUILD_DIR)/$(ip)/$(ip).srcs)

.PHONY: all
all: clean_all top

# initialise build directory
.PHONY: init
init:
	@mkdir -p $(FPGA_BUILD_DIR)	


# launch a Vivado project and move output products into the build directory
#ToDo : Create logs directory which works in a similar way to SoCHub ASIC Flow
.PHONY: top
top: init clean_top all_ips
	@rm -f $(BITSTREAM) $(PROBE_FILE)
	@echo "INFO: Building FPGA design for $(PROJECT_NAME)"
	@mkdir -p $(FPGA_PROJECT_DIR)
	cd $(FPGA_PROJECT_DIR) && \
	vivado -mode batch -source $(FPGA_TCL_DIR)/$(PROJECT_NAME)_run.tcl -notrace \
	-log vivado_$(PROJECT_NAME).log -journal vivado_$(PROJECT_NAME).jou
	@cp -f $(FPGA_PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1/$(DUT_TOP_MODULE).bit $(BITSTREAM)
ifneq ($(shell test -e $(FPGA_PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1/$(DUT_TOP_MODULE).ltx), )
	@cp -f $(FPGA_PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1/$(DUT_TOP_MODULE).ltx $(PROBE_FILE)
endif 


# launch synthesis for all IPs in FPGA_IP_LIST
.PHONY: all_ips
all_ips: init $(FPGA_IP_LIST)
	@echo "running all_ips recipe"


# call corresponding Makefile for each IP in FPGA_IP_LIST
$(FPGA_IP_LIST):
	$(MAKE) -C $(FPGA_IP_DIR)/$@ build_ip IP_PROJECT=$@


# clean top project files only (not IPs)
.PHONY: clean_top
clean_top:
	@echo "INFO: Deleting $(PROJECT_NAME) top build directory and artefacts..."
	@rm -f $(BITSTREAM)
	@rm -f $(PROBE_FILE) 
	@rm -rf $(FPGA_PROJECT_DIR)


# clean IPs only (not top project)
.PHONY: clean_ips
clean_ips:
	@echo "INFO: Deleting IP build directory and artefacts..."
	@rm -rf $(FPGA_IP_DIR)/build/ips


# clean everything
.PHONY: clean_all
clean_all:
	@echo "INFO: Deleting build directory..."
	@rm -rf $(FPGA_BUILD_DIR)
