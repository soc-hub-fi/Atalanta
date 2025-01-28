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
VERILATOR_CFLAGS="-O0 -ffunction-sections -fdata-sections -g -c -DVERILATOR"

BENDER ?= bender
TARGET ?= riscv32emc-unknown-none-elf

######################################################################
# Repository targets
######################################################################

repository_init:
	@echo "Pulling Bender dependencies"
	@bender update
	@echo "Pulling vendored IPs"
	@bender vendor init

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

.PHONY: build_standalone
build_standalone:
	$(MAKE) -C vsim compile elaborate dut_sanity_check DEBUG=+define+STANDALONE BUILD_DIR=$(BUILD_DIR)

.PHONY: compile_fpga_mem
compile_fpga:
	$(MAKE) -C vsim compile FPGA=+define+FPGA_MEM BUILD_DIR=$(BUILD_DIR)

.PHONY: elaborate
elaborate:
	$(MAKE) -C vsim elaborate BUILD_DIR=$(BUILD_DIR)

.PHONY: fpga
fpga:
	$(MAKE) -C fpga all FPGA_DIR=$(FPGA_DIR)

######################################################################
# formal targets
######################################################################

.PHONY: autocheck
autocheck: check-env
	$(MAKE) -C formal qverify_autocheck_compile DUT=rt_top

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


.PHONY: simulate
simulate: check-env smoke_compile
	$(MAKE) -C vsim run_batch

.PHONY: gui
gui: check-env
	$(MAKE) -C vsim run_gui

.PHONY: vsim_wave
vsim_wave: check-env
	$(MAKE) -C vsim wave

#####################
# C compile
#####################
.PHONY: test_check
test_check:
ifeq ($(TEST),)
	$(error "No TEST specified. Exiting.")
	exit 0
endif

.PHONY: smoke_compile
smoke_compile: test_check
	@$(MAKE) -C $(CURDIR)/examples/smoke_tests $(TEST)


#####################
# Verilator
#####################

TEST_DIR ?= $(CURDIR)/examples/smoke_tests

.PHONY: $(TEST)
$(TEST):
	$(MAKE) -C $(TEST_DIR) $(TEST) CFLAGS=$(VERILATOR_CFLAGS)

.PHONY: verilate
verilate: $(TEST)
	TARGET=$(TARGET) $(MAKE) -C verilator verilate

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
# clean target
######################################################################

.PHONY: clean_ips
clean_ips:
	rm -rf .bender

.PHONY: clean_build
clean_build:
	rm -rf build
	git clean vsim/ -f

.PHONY: clean_all
clean_all: clean_ips clean_build

