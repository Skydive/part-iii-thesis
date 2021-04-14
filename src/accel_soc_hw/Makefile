###  -*-Makefile-*-

# *** DO NOT EDIT! ***
# *** This file is program-generated, not hand-written. ***
# ================================================================

REPO ?= Piccolo
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
	-D FABRIC64    

TEST ?= rv32ui-p-add

#================================================================
# Common boilerplate rules

include Include_Common_AccelSoCPiccolo.mk

#================================================================
# Makefile rules for building for specific simulator: verilator

include $(REPO)/builds/Resources/Include_verilator.mk

