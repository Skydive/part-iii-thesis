###  -*-Makefile-*-

# *** DO NOT EDIT! ***
# *** This file is program-generated, not hand-written. ***
# ================================================================

BASE ?= ../..
REPO ?= $(BASE)/Piccolo
ARCH ?= RV32ACFIMU

BSC_COMPILATION_FLAGS += \
	-D RV32 \
	-D ISA_PRIV_M  -D ISA_PRIV_U  \
	-D SV32  \
	-D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C \
	-D ISA_F  -D INCLUDE_FDIV  -D INCLUDE_FSQRT \
	-D SHIFT_BARREL    \
	-D MULT_SYNTH    \
	-D Near_Mem_Caches    \
	-D FABRIC64 \
	-show-schedule

TEST ?= rv32ui-p-add

#================================================================
# Common boilerplate rules

include $(BASE)/Include_Common_AccelSoCPiccolo.mk


TESTBENCH_PATH = $(REPO)/src_Testbench
TESTBENCH_DIRS = $(TESTBENCH_PATH)/Top:$(TESTBENCH_PATH)/SoC:$(TESTBENCH_PATH)/Fabrics/AXI4

CUSTOM_DIRS := $(BASE)/src_bsv_units/ZipReduceServer_FusedMA:$(BASE)/src_bsv_units/MultiPortMemory:./src

BSC_PATH := $(CUSTOM_DIRS):$(CORE_DIRS):$(TESTBENCH_DIRS):+


TOPFILE = ./src/Top_HW_Side.bsv



#================================================================
# Makefile rules for building for specific simulator: verilator

include $(REPO)/builds/Resources/Include_verilator.mk

