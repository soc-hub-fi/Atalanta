ifndef DEBUG
MAYBE_RELEASE = --release
endif

# Build the entire program
.PHONY: $(TEST)
$(TEST):
	cargo build $(MAYBE_RELEASE) -Frtl-tb --example $(TEST) $(CARGO_FLAGS)
