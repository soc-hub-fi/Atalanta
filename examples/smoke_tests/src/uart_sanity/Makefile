#-{ Project Relative Paths }--------------------------------------------------------
TOP_LEVEL_DIR     =../..
INCLUDE_DIR       =$(TOP_LEVEL_DIR)/include
L_SCRIPT  		  =$(TOP_LEVEL_DIR)/common/link.ld
BUILD_DIR 		  =$(TOP_LEVEL_DIR)/build

ifneq ($(wildcard $(CURDIR)/crt0.S),)
CRUNTIME		  =$(CURDIR)/crt0
else 
CRUNTIME		  =$(TOP_LEVEL_DIR)/common/crt0
endif

#-{ Toolchain Specifications }------------------------------------------------------ 

XLEN 			 ?= 64
TOOLCHAIN_PATH   := /opt/poc/rv64gcc/bin/
TOOLCHAIN_PREFIX ?= riscv$(XLEN)-unknown-elf-
RVGCC			  =$(TOOLCHAIN_PREFIX)gcc
RVOBJDUMP		  =$(TOOLCHAIN_PREFIX)objdump
RVGDB		      =$(TOOLCHAIN_PREFIX)gdb

# Object copy (for converting formats if needed) 
OBJCOPY		      =$(TOOLCHAIN_PREFIX)objcopy

# Architecture and Compiler flags
ARCH_FLAGS       ?=-march=rv32emc_zicsr -mabi=ilp32e
CFLAGS 			 ?=-Os -ffunction-sections -fdata-sections -g -c

# Linker flags
LDFLAGS 		  = -T$(L_SCRIPT) -nostartfiles

#-{ Rules for the build }-----------------------------------------------------------

TEST			  ?= uart_sanity


# Delete the build artifacts
.PHONY: all
all: link objdump
	rm $(BUILD_DIR)/$(TEST)/*.o


# Compile $(TEST)
.PHONY: compile
compile: 
	$(RVGCC) $(ARCH_FLAGS) $(CFLAGS) -I $(INCLUDE_DIR) -DLANGUAGE_ASSEMBLY $(CRUNTIME).S \
	-o $(BUILD_DIR)/crt0.o

	$(RVGCC) $(ARCH_FLAGS) $(CFLAGS) -I $(INCLUDE_DIR) $(CURDIR)/$(TEST).c \
	-o $(BUILD_DIR)/$(TEST)/$(TEST).o

# Link necessary object files
.PHONY: link
link: compile
#$(RVLD) $(LDFLAGS) $(BUILD_DIR)/crt0.o $(BUILD_DIR)/$(TEST)/$(TEST).o -o $(BUILD_DIR)/$(TEST).elf
	$(RVGCC) $(ARCH_FLAGS) $(LDFLAGS) -I $(INCLUDE_DIR) -o $(BUILD_DIR)/$(TEST)/$(TEST).elf  $(BUILD_DIR)/crt0.o $(BUILD_DIR)/$(TEST)/$(TEST).o

# Dump the generated .elf file 
.PHONY: objdump
objdump: #link
	$(RVOBJDUMP) $(BUILD_DIR)/$(TEST)/$(TEST).elf $(OBJDUMP_OPT) -SsdhwD > $(BUILD_DIR)/$(TEST)/$(TEST).dump
