SRC_BSV_DIR = src_BSV
SRC_C_DIR   = src_C
TOPFILE = $(SRC_BSV_DIR)/Tb.bsv
TOPMODULE = mkTb

BSCFLAGS = -keep-fires -aggressive-conditions -no-warn-action-shadowing -steps-warn-interval 250000

default: compile  link

# ----------------------------------------------------------------
# FOR BLUESIM

BSCDIRS_BSIM  = -simdir build_bsim -bdir build -info-dir build
BSCPATH_BSIM  = -p .:./src_BSV:%/Prelude:%/Libraries

BSIM_EXE = bsim.exe

build_bsim:
	mkdir -p $@

build:
	mkdir -p $@

.PHONY: compile
compile: build build_bsim
	@echo Compiling for Bluesim ...
	bsc -u -sim $(BSCDIRS_BSIM) $(BSCFLAGS) $(BSCPATH_BSIM) $(TOPFILE)
	@echo Compilation for Bluesim finished

.PHONY: link
link:
	@echo Linking Bluesim...
	bsc -e $(TOPMODULE) -keep-fires -sim  -o ./$(BSIM_EXE)  $(BSCDIRS_BSIM)  $(BSCPATH_BSIM)
	@echo Bluesim linking finished

.PHONY: simulate
bsim:
	@echo Simulating \(Bluesim\) and generating VCD waveform file ...
	./$(BSIM_EXE)  -V bsim_waves.vcd
	@echo Bluesim simulation finished

# ----------------------------------------------------------------
# FOR VERILOG

BSCDIRS_V = -vdir verilog  -bdir build_v  -info-dir build_v
BSCPATH_V = -p .:./src_BSV:%/Prelude:%/Libraries

# Set VSIM to desired Verilog simulator
# VSIM = modelsim
# VSIM = cvc
VSIM = iverilog

VSIM_EXE = vsim.exe

build_v:
	mkdir -p $@

verilog:
	mkdir -p $@

.PHONY: rtl
rtl: build build_v verilog
	@echo Compiling to Verilog ...
	bsc -u -elab -verilog $(BSCDIRS_V) $(BSCFLAGS) $(BSCPATH_V) $(TOPFILE)
	@echo Compilation to Verilog finished

.PHONY: vlink
vlink:
	@echo Linking Verilog ...
	bsc -e $(TOPMODULE) -verilog -o $(VSIM_EXE) -vdir verilog -vsim $(VSIM) -keep-fires \
		verilog/$(TOPMODULE).v
	@echo Verilog linking finished

.PHONY: vsim
vsim:
	@echo Simulating Verilog and generating VCD waveform file ...
	./$(VSIM_EXE)  +bscvcd
	@echo Verilog simulation finished

# ----------------------------------------------------------------

.PHONY: clean
clean:
	rm -f  *~  src_*/*~  src_*/*.o  build/*  build_bsim/*  build_v/*

.PHONY: full_clean
full_clean: clean
	rm -f  $(BSIM_EXE)  $(BSIM_EXE).so  $(VSIM_EXE)  verilog/*  *.vcd
