CASE_NAME := $(notdir $(CURDIR))
PROJECT_ROOT := $(abspath $(CURDIR)/../../..)
SIM_DIR := $(abspath $(CURDIR)/..)
CASE_BUILD_ROOT ?= $(SIM_DIR)/build/$(CASE_NAME)
ENV_SHELL := /bin/tcsh

.DEFAULT_GOAL := __forward

.PHONY: __forward
__forward:
	@$(ENV_SHELL) -c 'cd "$(PROJECT_ROOT)"; source prj_setup.env; $(MAKE) -C "$(SIM_DIR)" BUILD_ROOT="$(CASE_BUILD_ROOT)" $(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)'

%: __forward
	@:
