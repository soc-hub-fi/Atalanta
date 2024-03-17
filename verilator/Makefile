######################################################################
# RT-SS verilator makefile
# Author(s): Tom Szymkowiak (thomas.szymkowiak@tuni.fi)
#			 Antti Nurmi    (antti.nurmi@tuni.fi)
# Project: SoC-HUB
# Chip: Bow
######################################################################

ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

BUILD_DIR       ?= $(realpath $(CURDIR))/../build
SRC_DIR         ?= $(realpath $(CURDIR))/../src
VERIL_DIR       ?= $(realpath $(CURDIR))/../verilator
VERIL_BUILD_DIR ?= $(BUILD_DIR)/verilator_build

# if VERILATOR_ROOT is undefined, assume that it is in PATH
ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
VERILATOR_COVERAGE = verilator_coverage
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
VERILATOR_COVERAGE = $(VERILATOR_ROOT)/bin/verilator_coverage
endif

TOP_MODULE ?= tb_rt_ss
VERIL_TOP  ?= $(VERIL_DIR)/$(TOP_MODULE).cpp


gpio_blink = 0
uart_test  = 0
csr_tests  = 0
clic_tests = 0
timer_test = 0

# memory initialisation file used for L2
TEST               ?= hello_world
$(TEST) = 1
TEST_IMEM_FILE      := $(BUILD_DIR)/../stims/$(TEST)_imem.hex
TEST_DMEM_FILE      := $(BUILD_DIR)/../stims/$(TEST)_dmem.hex
IMEM_INIT_FILE      := $(BUILD_DIR)/memory_init/test_imem_init.mem
DMEM_INIT_FILE      := $(BUILD_DIR)/memory_init/test_dmem_init.mem
# results file when running in ideal dispatcher mode
IDEAL_RESULTS_FILE := $(BUILD_DIR)/ideal_results_veril.log
# used for ideal_dispatcher fifo
#VTRACE_FILE        ?= $(BUILD_DIR)/../sw/ideal_dispatcher/dispatch.hex
N_VINSN            ?=

VERIL_PARAMS = 	-GBLINK_TEST=$(gpio_blink) \
				-GUART_TEST=$(uart_test) \
				-GTIMER_TEST=$(timer_test) \
				-GCSR_TESTS=$(csr_tests) \
				-GCLIC_TESTS=$(clic_tests)

VERIL_WARN_SUPPRESS ?= \
  -Wno-BLKANDNBLK      \
  -Wno-CASEINCOMPLETE  \
  -Wno-CMPCONST        \
  -Wno-LATCH           \
  -Wno-LITENDIAN       \
  -Wno-UNOPTFLAT       \
  -Wno-UNPACKED        \
  -Wno-UNSIGNED        \
  -Wno-WIDTH           \
  -Wno-WIDTHCONCAT     \
  -Wno-ENUMVALUE       \
  -Wno-COMBDLY         \
	-Wno-TIMESCALEMOD
       
VERIL_DEFINES ?= \
	+define+VERILATOR=1

ifdef TRACE
VERIL_DEFINES += +define+RVFI +define+DEBUG
VERIL_WARN_SUPPRESS += -Wno-MULTIDRIVEN 
endif

VERIL_INCLUDES ?= \
	+incdir+../ips/bow-common-ips/ips/pulp-common-cells/include/ \
	+incdir+../ips/rt-ibex/vendor/lowrisc_ip/ip/prim/rtl/ \
	+incdir+../ips/rt-ibex/rtl/ \
	+incdir+../ips/register_interface/include \
	+incdir+../ips/apb/include \
	+incdir+../ips/rt-ibex/vendor/lowrisc_ip/dv/sv/dv_utils/ \
	+incdir+../ips/bow-common-ips/ips/axi/include/

RTL_SRC_LIST   ?= $(SRC_DIR)/ss-files.list
EXTRA_SRC_LIST ?= $(SRC_DIR)/verilator.list
TB_SRC_LIST    ?= $(SRC_DIR)/tb-files.list

VERIL_FLAGS ?= \
	--binary \
	-f $(RTL_SRC_LIST) \
	-f $(EXTRA_SRC_LIST) \
	-f $(TB_SRC_LIST) \
	$(VERIL_DEFINES) \
	$(VERIL_INCLUDES) \
	$(VERIL_PARAMS) \
	$(VERIL_WARN_SUPPRESS) \
	-O3 \
	-sv \
	--timing \
	--trace-fst \
	--hierarchical \
	$(VERIL_DIR)/$(TOP_MODULE).vlt \
	--top-module $(TOP_MODULE) \
	--Mdir $(VERIL_BUILD_DIR) \
	--build \
	-j `nproc`


.PHONY: init
init:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(VERIL_BUILD_DIR)
	@rm -f $(IMEM_INIT_FILE)
	@rm -f $(DMEM_INIT_FILE)
	@mkdir -p $(BUILD_DIR)/memory_init
	@echo "Copying $(TEST_IMEM_FILE) into $(IMEM_INIT_FILE)"
	@echo "Copying $(TEST_DMEM_FILE) into $(DMEM_INIT_FILE)"
	@cp -f $(TEST_IMEM_FILE) $(IMEM_INIT_FILE)
	@cp -f $(TEST_DMEM_FILE) $(DMEM_INIT_FILE)


.PHONY: verilate
verilate: clean init
	$(VERILATOR) $(VERIL_FLAGS)

.PHONY: simv
simv: init
	cd $(VERIL_BUILD_DIR) && \
	./V$(TOP_MODULE)

.PHONY: wave
wave:
	gtkwave ../build/verilator_build/waveform.fst &

.PHONY: clean
clean:
	@rm -rf $(VERIL_BUILD_DIR)

