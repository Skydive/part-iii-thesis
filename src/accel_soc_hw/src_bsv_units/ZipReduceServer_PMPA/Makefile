
TMP_DIRS  = -bdir build_dir  -simdir build_dir  -info-dir build_dir
BSC_COMPILATION_FLAGS += \
	-keep-fires -aggressive-conditions -no-warn-action-shadowing -no-show-timestamps -check-assert \
	-suppress-warnings G0020    \
	+RTS -K128M -RTS  -show-range-conflict

BSC_PATH ?=
TOPFILE = ./Main.bsv
TOPMODULE = mkMain


build_dir:
	mkdir -p $@

.PHONY: compile
compile: build_dir
	@echo "INFO: Re-compiling Core (CPU, Caches)"
	bsc -u -elab -sim  $(TMP_DIRS)  $(BSC_COMPILATION_FLAGS)  $(TOPFILE)
	@echo "INFO: Re-compiled  Core (CPU, Caches)"

SIM_EXE_FILE = exe_HW_sim

.PHONY: simulator
simulator:
	@echo "INFO: linking bsc-compiled objects into Bluesim executable"
	bsc -sim -parallel-sim-link 8 \
		$(TMP_DIRS) \
		-e $(TOPMODULE) -o ./$(SIM_EXE_FILE)
	@echo "INFO: linked bsc-compiled objects into Bluesim executable"

.PHONY: clean
clean:
	rm -r -f  *~  Makefile_*  symbol_table.txt  build_dir  obj_dir
