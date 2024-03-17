######################################################################
# Template-ss top-level makefile
# Author: Matti Käyrä (Matti.kayra@tuni.fi)
# Project: SoC-HUB
# Chip: Experimental
######################################################################

START_TIME=`date +%F_%H:%M`
DATE=`date +%F`

SHELL=bash
BUILD_DIR ?= $(realpath $(CURDIR))/build/
FPGA_DIR   = $(realpath $(CURDIR))/fpga

######################################################################
# Makefile common setup
######################################################################

START_TIME=`date +%F_%H:%M`
SHELL=bash

######################################################################
# Repository targets
######################################################################

repository_init: 
	git fetch 
	git submodule foreach 'git stash' #stash is to avoid override by accident
	git submodule update --init --recursive

.PHONY: check-env
check-env:
	mkdir -p $(BUILD_DIR)/logs/compile
	mkdir -p $(BUILD_DIR)/logs/opt
	mkdir -p $(BUILD_DIR)/logs/sim

######################################################################
# hw build targets 
######################################################################

.PHONY: compile
compile:
	$(MAKE) -C vsim compile BUILD_DIR=$(BUILD_DIR)

.PHONY: compile_debug
compile_debug:
	$(MAKE) -C vsim compile DEBUG=+define+DEBUG RVFI=+define+RVFI BUILD_DIR=$(BUILD_DIR)

.PHONY: compile_soc
compile_soc:
	$(MAKE) -C vsim compile SOC_CONNECTIVITY=+define+SOC_CONNECTIVITY BUILD_DIR=$(BUILD_DIR)

.PHONY: elaborate
elaborate:
	$(MAKE) -C vsim elaborate BUILD_DIR=$(BUILD_DIR)

.PHONY: elab_syn
elab_syn: check-env
	$(MAKE) -C syn elab_syn

.PHONY: elab_lec
elab_lec: check-env
	$(MAKE) -C syn elab_lec

.PHONY: fpga
fpga:
	$(MAKE) -C fpga all FPGA_DIR=$(FPGA_DIR)

######################################################################
# formal targets 
######################################################################

.PHONY: autocheck
autocheck: check-env
	$(MAKE) -C formal qverify_autocheck

.PHONY: xcheck
xcheck: check-env
	$(MAKE) -C formal qverify_xcheck

.PHONY: formal
formal: check-env
	$(MAKE) -C formal qverify_formal

.PHONY: check_formal_result
check_formal_result: check-env
	$(MAKE) -C formal check_formal_result

#####################
# hw sim
#####################

.PHONY: sanity_check
sanity_check: check-env
	$(MAKE) -C vsim dut_sanity_check

# TODO: rename & expand
.PHONY: simulate
simulate: check-env
	$(MAKE) -C vsim run_batch

.PHONY: gui
gui: check-env
	$(MAKE) -C vsim run_gui

.PHONY: vsim_wave
vsim_wave: check-env
	$(MAKE) -C vsim wave

#####################
# Verilator
#####################

.PHONY: verilate
verilate:
	$(MAKE) -C verilator verilate

.PHONY: simv
simv:
	$(MAKE) -C verilator simv

.PHONY: wavev
wavev:
	$(MAKE) -C verilator wave

.PHONY: initv
initv:
	$(MAKE) -C verilator init

######################################################################
# CI pipeline variables  targets 
######################################################################

.PHONY: echo_success
echo_success:
	echo -e "\n\n##################################################\n\n OK! \n\n##################################################\n"


######################################################################
# clean target 
######################################################################

.PHONY: clean
clean:
	rm -rf build