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
VERIL_DIR       ?= $(realpath $(CURDIR))/../verilator
VERIL_BUILD_DIR ?= $(BUILD_DIR)/verilator_build

TOP_MODULE       = rt_top_unpacked
VERIL_TOP        = $(VERIL_DIR)/$(TOP_MODULE).cpp

# if VERILATOR_ROOT is undefined, assume that it is in PATH
ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
VERILATOR_COVERAGE = verilator_coverage
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
VERILATOR_COVERAGE = $(VERILATOR_ROOT)/bin/verilator_coverage
endif

VERIL_WARN_SUPPRESS ?= \
  -Wno-BLKANDNBLK      \
  -Wno-WIDTHEXPAND     \
  -Wno-UNOPTFLAT       \
  -Wno-UNSIGNED        \
  -Wno-WIDTHCONCAT     \
  -Wno-WIDTHTRUNC      \
  -Wno-COMBDLY         \
  -Wno-LATCH           \
  -Wno-LITENDIAN       \
  -Wno-CASEINCOMPLETE  \
  -Wno-PINMISSING      \
  -Wno-MULTIDRIVEN     \
  -Wno-CMPCONST        \
  -Wno-IMPLICIT        \
  -Wno-BLKLOOPINIT     
       
VERIL_DEFINES ?= \
	+define+VERILATOR=1 \
	+define+RVFI \
	+define+COMMON_CELLS_ASSERTS_OFF

ifdef TRACE
VERIL_DEFINES += +define+RVFI +define+DEBUG
VERIL_WARN_SUPPRESS += -Wno-MULTIDRIVEN 
endif

VERIL_INCLUDES ?= \
	+incdir+$(shell bender path common_cells)/include \
	+incdir+$(shell bender path apb)/include \
	+incdir+$(shell bender path axi)/include \
	+incdir+$(shell bender path register_interface)/include \
	+incdir+$(VERIL_DIR)/../src/ip/obi/include \
	+incdir+$(shell bender path rt-ibex)/vendor/lowrisc_ip/dv/sv/dv_utils \
	+incdir+$(shell bender path rt-ibex)/vendor/lowrisc_ip/ip/prim/rtl \
	+incdir+$(shell bender path rt-ibex)/rtl

BENDER_TARGETS ?= \
	-t tech_cells_generic_exclude_deprecated \
	-t verilator

VERIL_FLAGS ?= \
	$(VERIL_DEFINES) \
	$(VERIL_INCLUDES) \
	$(VERIL_PARAMS) \
	$(VERIL_WARN_SUPPRESS) \
	-O3 \
	-sv \
	--timing \
	--trace-fst \
	--trace-structs \
	--trace-params \
	--hierarchical \
	--exe $(VERIL_TOP) \
	--cc \
	--unroll-count 4 \
	$(VERIL_DIR)/$(TOP_MODULE).vlt \
	--top-module $(TOP_MODULE) \
	$(shell bender script flist $(BENDER_TARGETS)) \
	--Mdir $(VERIL_BUILD_DIR) \
	--build \
	-j `nproc`

.PHONY: init
init:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(VERIL_BUILD_DIR)

.PHONY: lint
lint:
	$(VERILATOR) --lint-only \
	$(VERIL_INCLUDES) \
	--top-module $(TOP_MODULE) \
	$(shell bender script flist $(BENDER_TARGETS)) \
	

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

