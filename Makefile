# Makefile for c-ompiler

# Define variables
C_OMPILER_DIR := $(HOME)/code/c-ompiler
ODIN := odin
BUILD_TARGET := $(C_OMPILER_DIR)/c-ompiler
OUTPUT_BIN := $(C_OMPILER_DIR)/c-ompiler.bin

# Default target
all: build

# Build target
build:
	@echo "Building c-ompiler..."
	@$(ODIN) build $(BUILD_TARGET) -out:$(OUTPUT_BIN)
	@echo "Build complete. Binary created at $(OUTPUT_BIN)"

debug:
	@echo "Building debug c-ompiler..."
	@$(ODIN) build $(BUILD_TARGET) -debug -out:$(OUTPUT_BIN)
	@echo "Build complete. Binary created at $(OUTPUT_BIN)"

# Clean target (optional, for removing built files)
clean:
	@echo "Cleaning up..."
	@rm -f $(OUTPUT_BIN)
	@echo "Cleanup complete."

# Phony targets
.PHONY: all build clean debug
