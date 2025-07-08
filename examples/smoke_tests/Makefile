#-{ Project Relative Paths }--------------------------------------------------------

BUILD_DIR 		  =$(CURDIR)/build

#-{ Toolchain Specifications }------------------------------------------------------ 

XLEN 			 ?= 32
TOOLCHAIN_PATH   := /opt/poc/rv64gcc/bin/
TOOLCHAIN_PREFIX ?= riscv$(XLEN)-unknown-elf-
RVGCC			  =$(TOOLCHAIN_PREFIX)gcc
RVOBJDUMP		  =$(TOOLCHAIN_PREFIX)objdump
RVGDB		      =$(TOOLCHAIN_PREFIX)gdb

#-{ TEST }-----------------------------------------------------------

#-{ Rules for the build }-----------------------------------------------------------

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
	$(MAKE) -C $(CURDIR)/src/$(TEST) 

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



	
