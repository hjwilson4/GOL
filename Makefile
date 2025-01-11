# Compiler and Verilator flags
VERILATOR = verilator
VERILATOR_FLAGS = --cc --trace --build -Wno-fatal -Wno-UNUSED -Wno-PINMISSING -Wno-STMTDLY

# Files
TOP_MODULE = GOL
SV_SOURCES = GOL.sv GOLCell.sv  # List of your SystemVerilog source files
TESTBENCH = GOL_tb.cpp
OUTPUT_DIR = obj_dir

# Parameters (customize as needed)
GOL_PARAMS = -Gcolumns=10 -Grows=6

# SFML Flags (you can also verify that SFML paths are correct)
SFML_FLAGS = $(shell pkg-config --cflags --libs sfml-graphics sfml-window sfml-system)

# Default target
all: compile run

# Compile and build the executable
compile:
	@echo "Compiling RTL and C++ sources with Verilator..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(GOL_PARAMS) $(SV_SOURCES) --exe $(TESTBENCH) -LDFLAGS "$(SFML_FLAGS)" #> /dev/null 2>&1

# Run the simulation
run:
	@echo "Linking and running the simulation..."
	./$(OUTPUT_DIR)/V$(TOP_MODULE)

# Clean up generated files
clean:
	@echo "Cleaning up..."
	rm -rf $(OUTPUT_DIR) waveform.vcd
