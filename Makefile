PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PYTHON       ?= $(shell if [ -n "$$PYTHON3" ]; then echo "$$PYTHON3"; elif command -v python3.12 >/dev/null 2>&1; then echo python3.12; elif command -v python3.11 >/dev/null 2>&1; then echo python3.11; elif command -v python3.10 >/dev/null 2>&1; then echo python3.10; elif command -v python3.9 >/dev/null 2>&1; then echo python3.9; elif command -v python3 >/dev/null 2>&1; then echo python3; else echo python; fi)
FLOW         := $(PROJECT_ROOT)/vrf/scripts/ubwc_sim_flow.py

SRC            ?=
SOURCE_TAG     ?= ubwc
BASE_ADDR      ?= 0x0000000080000000
FORCE          ?= 0
RESET_DB       ?= 0

MODE           ?=
CNUM           ?=
FRAME_NUM      ?= 1
RAND_OTF       ?= 0
RAND_AXI       ?= 0
BANK_DLY       ?= 1
SEED           ?= 1
AXI_READ_DELAY ?= 0
ROT            ?= 0
SUBMIT         ?= local

.DEFAULT_GOAL := help

.PHONY: help bvector comp_enc comp_dec comp_dec_rotation comp_loop run

help:
	@echo "Clean UBWC simulation commands:"
	@echo "  make bvector [SRC=/path/to/raw_vectors] [SOURCE_TAG=ubwc] [FORCE=1] [RESET_DB=1]"
	@echo "  make comp_enc  [CNUM=0001|all]"
	@echo "  make comp_dec  [CNUM=0001|all]  # uses dec_rotation ROT=0"
	@echo "  make comp_dec_rotation [CNUM=0001|all] [ROT=0|90|270]"
	@echo "  make comp_loop [CNUM=0001|all]"
	@echo "  make run MODE=enc  CNUM=0001 [FRAME_NUM=1..100] [RAND_OTF=0|1] [RAND_AXI=0|1] [BANK_DLY=1..4] [SUBMIT=local|bsub]"
	@echo "  make run MODE=dec  CNUM=0001 [FRAME_NUM=1..100] [RAND_OTF=0|1] [RAND_AXI=0|1] [BANK_DLY=1..4] [AXI_READ_DELAY=N]  # uses dec_rotation ROT=0"
	@echo "  make run MODE=dec_rotation CNUM=0001 [ROT=0|90|270] [FRAME_NUM=1..100]"
	@echo "  make run MODE=loop CNUM=0001 [FRAME_NUM=1..100]"

bvector:
	@$(PYTHON) $(FLOW) bvector \
		$(if $(SRC),--src "$(SRC)",) \
		--source-tag "$(SOURCE_TAG)" \
		--base-addr "$(BASE_ADDR)" \
		$(if $(filter 1,$(FORCE)),--force,) \
		$(if $(filter 1,$(RESET_DB)),--reset,)

comp_enc:
	@$(PYTHON) $(FLOW) comp --mode enc --cnum "$(if $(CNUM),$(CNUM),all)"

comp_dec:
	@$(PYTHON) $(FLOW) comp --mode dec_rotation --cnum "$(if $(CNUM),$(CNUM),all)" --rotation 0

comp_dec_rotation:
	@$(PYTHON) $(FLOW) comp --mode dec_rotation --cnum "$(if $(CNUM),$(CNUM),all)" --rotation "$(ROT)"

comp_loop:
	@$(PYTHON) $(FLOW) comp --mode loop --cnum "$(if $(CNUM),$(CNUM),all)"

run:
	@test -n "$(MODE)" || (echo "ERROR: MODE must be enc, dec, dec_rotation, or loop"; exit 1)
	@test -n "$(CNUM)" || (echo "ERROR: CNUM is required"; exit 1)
	@$(PYTHON) $(FLOW) run \
		--mode "$(MODE)" \
		--cnum "$(CNUM)" \
		--frame-num "$(FRAME_NUM)" \
		--rand-otf "$(RAND_OTF)" \
		--rand-axi "$(RAND_AXI)" \
		--bank-dly "$(BANK_DLY)" \
		--seed "$(SEED)" \
		--axi-read-delay "$(AXI_READ_DELAY)" \
		--rotation "$(ROT)" \
		--submit "$(SUBMIT)"
