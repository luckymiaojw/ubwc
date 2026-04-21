PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SIM_DIR := $(PROJECT_ROOT)/vrf/sim
ENV_SHELL := /bin/tcsh

.DEFAULT_GOAL := __forward

.PHONY: __forward
__forward:
	@$(ENV_SHELL) -c 'cd "$(PROJECT_ROOT)"; source prj_setup.env; $(MAKE) -C "$(SIM_DIR)" $(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)'

%: __forward
	@:
