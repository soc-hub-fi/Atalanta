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

TEST			  ?=


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
$(TEST): env_check init
	$(MAKE) -C $(TEST) 



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



	
