CXX := c++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra

BUILD_DIR := build
TARGET := $(BUILD_DIR)/tinycpu

SRC := \
	src/main.cpp \
	src/control_unit.cpp \
	src/bus.cpp \
	src/alu.cpp \
	src/assembler.cpp \
	src/isa.cpp

.PHONY: all fib hello timer trace dump clean help

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRC)

fib: $(TARGET)
	@echo "Assembling Fibonacci program..."
	$(TARGET) asm examples/fib.asm -o $(BUILD_DIR)/fib.bin
	@echo
	@echo "Running Fibonacci program..."
	@echo "Expected output:"
	@echo "00 01 01 02 03 05 08 0d 15 22 37"
	@echo
	@echo "Actual output:"
	$(TARGET) run $(BUILD_DIR)/fib.bin | xxd -p -c 256 | sed 's/../& /g' | sed 's/ $$//'

hello: $(TARGET)
	@echo "Assembling Hello World program..."
	$(TARGET) asm examples/hello.asm -o $(BUILD_DIR)/hello.bin
	@echo
	@echo "Running Hello World program..."
	$(TARGET) run $(BUILD_DIR)/hello.bin

timer: $(TARGET)
	@echo "Assembling Timer program..."
	$(TARGET) asm examples/timer.asm -o $(BUILD_DIR)/timer.bin
	@echo
	@echo "Running Timer program..."
	$(TARGET) run $(BUILD_DIR)/timer.bin

trace: $(TARGET)
	@echo "Assembling Timer program..."
	$(TARGET) asm examples/timer.asm -o $(BUILD_DIR)/timer.bin
	@echo
	@echo "Running Timer program with trace enabled..."
	$(TARGET) run $(BUILD_DIR)/timer.bin --trace

dump: $(TARGET)
	@echo "Assembling Fibonacci program..."
	$(TARGET) asm examples/fib.asm -o $(BUILD_DIR)/fib.bin
	@echo
	@echo "Dumping Fibonacci memory image..."
	$(TARGET) dump $(BUILD_DIR)/fib.bin

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "TinyCPU Makefile commands:"
	@echo "  make        - Build the TinyCPU emulator"
	@echo "  make fib    - Assemble and run Fibonacci demo"
	@echo "  make hello  - Assemble and run Hello World demo"
	@echo "  make timer  - Assemble and run Timer demo"
	@echo "  make trace  - Run Timer demo with instruction trace"
	@echo "  make dump   - Dump Fibonacci memory image"
	@echo "  make clean  - Remove build files"