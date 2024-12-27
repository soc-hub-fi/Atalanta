#-{ Project Relative Paths }--------------------------------------------------------
INCLUDE_DIR       =$(CURDIR)/include
CRUNTIME		  =$(CURDIR)/common/crt0
L_SCRIPT  		  =$(CURDIR)/common/link.ld
BUILD_DIR 		  =$(CURDIR)/build

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
CFLAGS 			 ?=-O0 -ffunction-sections -fdata-sections -g -c

# Linker flags
LDFLAGS 		  = -T$(L_SCRIPT) -nostartfiles

#-{ Rules for the build }-----------------------------------------------------------

TEST			  			?=
HARDWARE_STACKING ?=0
DEFINES     			?=dummy

# Check for toolchain existence and PATH
.PHONY: env_check
env_check:
	@for tool in $(RVGCC) $(RVOBJDUMP) $(RVGDB); do \
		if ! command -v $$tool ; then \
			echo "Error: Tool $$tool not found in PATH."; \
			exit 1; \
		fi; \
	done
	@echo "All tools found in PATH."



# Build the entire program
.PHONY: $(TEST)
$(TEST): env_check all
	@echo "ELF generated in "$(BUILD_DIR)/$(TEST)/$(TEST).elf
	@echo "ELF dumped in" $(BUILD_DIR)/$(TEST)/$(TEST).dump



# Delete the build directory
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

# Prepare for the build
.PHONY: init
init: clean
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/$(TEST)
	@echo "Building" $(TEST)"..."

# Compile $(TEST)
.PHONY: compile
compile: init
	$(RVGCC) $(ARCH_FLAGS) $(CFLAGS) -D $(DEFINES) -I $(INCLUDE_DIR) -DLANGUAGE_ASSEMBLY $(CRUNTIME).S \
	-o $(BUILD_DIR)/crt0.o

	$(RVGCC) $(ARCH_FLAGS) $(CFLAGS) -I $(INCLUDE_DIR) $(CURDIR)/$(TEST).c \
	-o $(BUILD_DIR)/$(TEST)/$(TEST).o

# Link necessary object files
.PHONY: link
link: compile
#$(RVLD) $(LDFLAGS) $(BUILD_DIR)/crt0.o $(BUILD_DIR)/$(TEST)/$(TEST).o -o $(BUILD_DIR)/$(TEST).elf
	@$(RVGCC) $(ARCH_FLAGS) $(LDFLAGS) -I $(INCLUDE_DIR) -o $(BUILD_DIR)/$(TEST)/$(TEST).elf  $(BUILD_DIR)/crt0.o $(BUILD_DIR)/$(TEST)/$(TEST).o

# Dump the generated .elf file 
.PHONY: objdump
objdump: #link
	@$(RVOBJDUMP) $(BUILD_DIR)/$(TEST)/$(TEST).elf $(OBJDUMP_OPT) -Ssd > $(BUILD_DIR)/$(TEST)/$(TEST).dump
# Delete the build artifacts
.PHONY: all
all: link objdump
	@rm $(BUILD_DIR)/$(TEST)/*.o

#openOCD
.PHONY: openOCD
openOCD:
	@openocd -f ../../fpga/utils/ft232_openocd_RT-SS.cfg

#GDB
.PHONY: gdb
gdb:
	@$(RVGDB) $(BUILD_DIR)/$(TEST)/$(TEST).elf -x ../../fpga/utils/connect-and-load.gdb


	
