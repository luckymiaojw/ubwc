TOP ?= tb_ubwc_dec_meta_data_gen_41x29

VCS ?= vcs
VERDI ?= verdi
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator

SIM_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(SIM_DIR)/../..)
VRF_DIR := $(PROJECT_ROOT)/vrf
VRF_SRC_DIR := $(VRF_DIR)/src
VRF_DEC_SRC_DIR := $(VRF_SRC_DIR)/dec
VRF_ENC_SRC_DIR := $(VRF_SRC_DIR)/enc
VRF_VECTOR_DIR := $(VRF_DIR)/vector
VRF_SCRIPT_DIR := $(VRF_DIR)/scripts
RTL_FLIST_DIR := $(PROJECT_ROOT)/src/flist

BUILD_ROOT ?= build
BUILD_VARIANT_SUFFIX :=
ifneq ($(findstring wrapper_top,$(TOP)),)
ifneq ($(findstring +tb_non_fake_mode,$(RUN_ARGS)),)
BUILD_VARIANT_SUFFIX := _nonfake
else ifneq ($(strip $(TB_REAL_VIVO_MODE)),)
ifeq ($(strip $(TB_REAL_VIVO_MODE)),1)
BUILD_VARIANT_SUFFIX := _real
else
BUILD_VARIANT_SUFFIX := _fake
endif
else ifneq ($(strip $(WRAPPER_CASES_TB_REAL_VIVO_MODE)),)
ifeq ($(strip $(WRAPPER_CASES_TB_REAL_VIVO_MODE)),1)
BUILD_VARIANT_SUFFIX := _real
else
BUILD_VARIANT_SUFFIX := _fake
endif
else ifneq ($(strip $(WRAPPER_NV12_TB_REAL_VIVO_MODE)),)
ifeq ($(strip $(WRAPPER_NV12_TB_REAL_VIVO_MODE)),1)
BUILD_VARIANT_SUFFIX := _real
else
BUILD_VARIANT_SUFFIX := _fake
endif
else
BUILD_VARIANT_SUFFIX := _fake
endif
endif
BUILD_DIR := $(BUILD_ROOT)/$(TOP)$(BUILD_VARIANT_SUFFIX)
SIMV := $(BUILD_DIR)/simv
COMP_LOG := $(BUILD_DIR)/comp.log
RUN_LOG := $(BUILD_DIR)/run.log
SIM_PARAM_SUFFIX :=
ifneq ($(strip $(CASE_ID)),)
SIM_PARAM_SUFFIX := $(SIM_PARAM_SUFFIX)_case$(CASE_ID)
endif
ifneq ($(strip $(TB_REAL_VIVO_MODE)),)
SIM_PARAM_SUFFIX := $(SIM_PARAM_SUFFIX)_tb$(TB_REAL_VIVO_MODE)
endif
ifneq ($(strip $(FORCE_FULL_PAYLOAD_CASE)),)
SIM_PARAM_SUFFIX := $(SIM_PARAM_SUFFIX)_ffpc$(FORCE_FULL_PAYLOAD_CASE)
endif
IVERILOG_BUILD_DIR := $(BUILD_DIR)/iverilog$(SIM_PARAM_SUFFIX)
IVERILOG_SIMV := $(IVERILOG_BUILD_DIR)/simv
IVERILOG_COMP_LOG := $(BUILD_DIR)/iverilog$(SIM_PARAM_SUFFIX)_comp.log
IVERILOG_RUN_LOG := $(BUILD_DIR)/iverilog$(SIM_PARAM_SUFFIX)_run.log
IVERILOG_SUMMARY_LOG := $(BUILD_DIR)/iverilog$(SIM_PARAM_SUFFIX)_summary.txt
VERILATOR_BUILD_DIR := $(BUILD_DIR)/verilator$(SIM_PARAM_SUFFIX)
VERILATOR_OBJ_DIR := $(VERILATOR_BUILD_DIR)/obj
VERILATOR_SIMV := $(VERILATOR_OBJ_DIR)/V$(TOP)
VERILATOR_COMP_LOG := $(BUILD_DIR)/verilator$(SIM_PARAM_SUFFIX)_comp.log
VERILATOR_RUN_LOG := $(BUILD_DIR)/verilator$(SIM_PARAM_SUFFIX)_run.log
VERILATOR_SUMMARY_LOG := $(BUILD_DIR)/verilator$(SIM_PARAM_SUFFIX)_summary.txt

TAJMAHAL_VECTOR_DIR = $(VRF_VECTOR_DIR)/enc_from_mdss_zp_TajMahal_4096x600_rgba8888
TAJMAHAL_TILED_SRC = $(TAJMAHAL_VECTOR_DIR)/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_in0.txt
TAJMAHAL_TILED_COMP_SRC = $(TAJMAHAL_VECTOR_DIR)/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out0.txt
TAJMAHAL_LINEAR_SRC = $(TAJMAHAL_VECTOR_DIR)/visual_from_mdss_writeback_4_wb_2_rec_0_verify_pack10_out0.txt
TAJMAHAL_RGBA_META_SRC = $(TAJMAHAL_VECTOR_DIR)/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out2.txt
TAJMAHAL_TILED_MEMH = $(BUILD_DIR)/tajmahal_tiled.memh
TAJMAHAL_LINEAR_MEMH = $(BUILD_DIR)/tajmahal_linear.memh

TAJMAHAL_RGBA1010102_VECTOR_DIR = $(VRF_VECTOR_DIR)/enc_from_mdss_zp_TajMahal_4096x600_rgba1010102
TAJMAHAL_RGBA1010102_TILED_SRC = $(TAJMAHAL_RGBA1010102_VECTOR_DIR)/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_in0.txt
TAJMAHAL_RGBA1010102_TILED_COMP_SRC = $(TAJMAHAL_RGBA1010102_VECTOR_DIR)/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_out0.txt
TAJMAHAL_RGBA1010102_LINEAR_SRC = $(TAJMAHAL_RGBA1010102_VECTOR_DIR)/visual_from_mdss_writeback_38_wb_2_rec_0_verify_pack10_out0.txt
TAJMAHAL_RGBA1010102_META_SRC = $(TAJMAHAL_RGBA1010102_VECTOR_DIR)/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_out2.txt

TAJMAHAL_NV12_VECTOR_DIR = $(VRF_VECTOR_DIR)/enc_from_mdss_zp_TajMahal_4096x600_nv12
TAJMAHAL_NV12_Y_TILED_UNCOMP_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt
TAJMAHAL_NV12_UV_TILED_UNCOMP_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt
TAJMAHAL_NV12_Y_TILED_COMP_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out0.txt
TAJMAHAL_NV12_UV_TILED_COMP_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out1.txt
TAJMAHAL_NV12_Y_TILED_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt
TAJMAHAL_NV12_UV_TILED_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt
TAJMAHAL_NV12_Y_LINEAR_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out0.txt
TAJMAHAL_NV12_UV_LINEAR_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out1.txt
TAJMAHAL_NV12_META_Y_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt
TAJMAHAL_NV12_META_UV_SRC = $(TAJMAHAL_NV12_VECTOR_DIR)/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt
TAJMAHAL_META_FIFO_BUILD_DIR = $(BUILD_ROOT)/tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12
TAJMAHAL_META_FIFO_EXPECTED = $(TAJMAHAL_META_FIFO_BUILD_DIR)/expected_fifo_stream.txt
TAJMAHAL_META_FIFO_TILE_X := $(if $(strip $(CASE_TILE_X_NUMBERS)),$(CASE_TILE_X_NUMBERS),8)
TAJMAHAL_META_FIFO_TILE_Y := $(if $(strip $(CASE_TILE_Y_NUMBERS)),$(CASE_TILE_Y_NUMBERS),4)

K_OUTDOOR61_G016_VECTOR_DIR = $(VRF_VECTOR_DIR)/enc_from_mdss_01000007_k_outdoor61_4096x600_g016
K_OUTDOOR61_G016_Y_TILED_UNCOMP_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt
K_OUTDOOR61_G016_UV_TILED_UNCOMP_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt
K_OUTDOOR61_G016_Y_TILED_COMP_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out0.txt
K_OUTDOOR61_G016_UV_TILED_COMP_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out1.txt
K_OUTDOOR61_G016_Y_LINEAR_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_pack10_out0.txt
K_OUTDOOR61_G016_UV_LINEAR_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_pack10_out1.txt
K_OUTDOOR61_G016_META_Y_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out2.txt
K_OUTDOOR61_G016_META_UV_SRC = $(K_OUTDOOR61_G016_VECTOR_DIR)/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out3.txt

PYTHON ?= $(shell if command -v python3.11 >/dev/null 2>&1; then echo python3.11; else echo python3; fi)
OTF_CASE_TOOL = $(PYTHON) $(VRF_SCRIPT_DIR)/otf_case_tool.py
META_CASE_TOOL = $(PYTHON) $(VRF_SCRIPT_DIR)/gen_expected_meta_fifo.py

RUN_ARGS ?=
WRAPPER_NV12_VIVO_MODE ?= fake
WRAPPER_CASES_VIVO_MODE ?= $(WRAPPER_NV12_VIVO_MODE)

ifeq ($(WRAPPER_NV12_VIVO_MODE),real)
WRAPPER_RGBA8888_TILE_SRC := $(TAJMAHAL_TILED_COMP_SRC)
WRAPPER_RGBA1010102_TILE_SRC := $(TAJMAHAL_RGBA1010102_TILED_COMP_SRC)
WRAPPER_NV12_TILE_Y_SRC := $(TAJMAHAL_NV12_Y_TILED_COMP_SRC)
WRAPPER_NV12_TILE_UV_SRC := $(TAJMAHAL_NV12_UV_TILED_COMP_SRC)
WRAPPER_NV12_TB_REAL_VIVO_MODE := 1
WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE := 0
else
WRAPPER_RGBA8888_TILE_SRC := $(TAJMAHAL_TILED_SRC)
WRAPPER_RGBA1010102_TILE_SRC := $(TAJMAHAL_RGBA1010102_TILED_SRC)
WRAPPER_NV12_TILE_Y_SRC := $(TAJMAHAL_NV12_Y_TILED_UNCOMP_SRC)
WRAPPER_NV12_TILE_UV_SRC := $(TAJMAHAL_NV12_UV_TILED_UNCOMP_SRC)
WRAPPER_NV12_TB_REAL_VIVO_MODE := 0
WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE := 0
endif

ifeq ($(WRAPPER_CASES_VIVO_MODE),real)
WRAPPER_CASES_TB_REAL_VIVO_MODE := 1
WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE := 0
else
WRAPPER_CASES_TB_REAL_VIVO_MODE := 0
WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE := 1
endif
# Metadata always comes from the TajMahal "Metadata" vectors in both fake/real modes.
WRAPPER_CASES_RGBA8888_META_SRC := $(TAJMAHAL_RGBA_META_SRC)
WRAPPER_CASES_RGBA1010102_META_SRC := $(TAJMAHAL_RGBA1010102_META_SRC)
WRAPPER_CASES_NV12_Y_META_SRC := $(TAJMAHAL_NV12_META_Y_SRC)
WRAPPER_CASES_NV12_UV_META_SRC := $(TAJMAHAL_NV12_META_UV_SRC)
WRAPPER_CASES_RGBA8888_AXI_TILE_SRC := $(TAJMAHAL_TILED_COMP_SRC)
WRAPPER_CASES_RGBA8888_REF_TILE_SRC := $(TAJMAHAL_TILED_SRC)
WRAPPER_CASES_RGBA1010102_AXI_TILE_SRC := $(TAJMAHAL_RGBA1010102_TILED_COMP_SRC)
WRAPPER_CASES_RGBA1010102_REF_TILE_SRC := $(TAJMAHAL_RGBA1010102_TILED_SRC)
WRAPPER_CASES_NV12_Y_AXI_TILE_SRC := $(TAJMAHAL_NV12_Y_TILED_COMP_SRC)
WRAPPER_CASES_NV12_UV_AXI_TILE_SRC := $(TAJMAHAL_NV12_UV_TILED_COMP_SRC)
WRAPPER_CASES_NV12_Y_REF_TILE_SRC := $(TAJMAHAL_NV12_Y_TILED_UNCOMP_SRC)
WRAPPER_CASES_NV12_UV_REF_TILE_SRC := $(TAJMAHAL_NV12_UV_TILED_UNCOMP_SRC)

CASE_BASE_FORMAT ?=
CASE_TILE_X_NUMBERS ?=
CASE_TILE_Y_NUMBERS ?=
CASE_ENABLE_FILE_COMPARE ?=
CASE_ID ?=
TB_REAL_VIVO_MODE ?=
FORCE_FULL_PAYLOAD_CASE ?=
EFFECTIVE_CASE_ID = $(if $(strip $(CASE_ID)),$(CASE_ID),0)

TB_SRC_tb_ubwc_dec_meta_data_gen_41x29 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen_41x29.sv
TB_SRC_tb_ubwc_dec_meta_data_gen := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen.sv
TB_SRC_tb_ubwc_dec_meta_data_gen_tajmahal_cases := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_data_gen_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_meta := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_meta_from_sram.v
TB_SRC_tb_ubwc_dec_axi_rdata_to_sram := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_axi_rdata_to_sram.sv
TB_SRC_tb_ubwc_enc_meta_get_cmd_gen := $(VRF_DEC_SRC_DIR)/tb_ubwc_enc_meta_get_cmd_gen.sv
TB_SRC_tb_ubwc_dec_tile_arcmd_gen := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_arcmd_gen.sv
TB_SRC_tb_ubwc_dec_tile_to_line_path := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_line_path.sv
TB_SRC_tb_ubwc_dec_tile_to_line_image_formats := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_line_image_formats.sv
TB_SRC_tb_ubwc_dec_tile_to_line_hd_formats := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_line_hd_formats.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_1080p_rgba := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_1080p_rgba.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_1920x1080_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_1920x1080_nv12.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_1960x1080_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_1960x1080_nv12.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_tajmahal_cases := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_tile_to_otf_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_tajmahal_cases := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 := $(VRF_DEC_SRC_DIR)/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.sv
TB_SRC_tb_ubwc_enc_wrapper_top_tajmahal_cases := $(VRF_ENC_SRC_DIR)/tb_ubwc_enc_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 := $(VRF_ENC_SRC_DIR)/tb_ubwc_enc_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 := $(VRF_ENC_SRC_DIR)/tb_ubwc_enc_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 := $(VRF_ENC_SRC_DIR)/tb_ubwc_enc_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 := $(VRF_ENC_SRC_DIR)/tb_ubwc_enc_wrapper_top_tajmahal_cases.sv
TB_SRC_tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 := $(VRF_DEC_SRC_DIR)/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12.sv

TB_SRC := $(TB_SRC_$(TOP))

FILELIST_tb_ubwc_dec_tile_to_line_path := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_line_image_formats := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_line_hd_formats := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_1080p_rgba := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_1920x1080_nv12 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_1960x1080_nv12 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_tajmahal_cases := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 := $(RTL_FLIST_DIR)/filelist_otf.f
FILELIST_tb_ubwc_enc_wrapper_top_tajmahal_cases := $(RTL_FLIST_DIR)/filelist_enc.f
FILELIST_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 := $(RTL_FLIST_DIR)/filelist_enc.f
FILELIST_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 := $(RTL_FLIST_DIR)/filelist_enc.f
FILELIST_tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 := $(RTL_FLIST_DIR)/filelist_enc.f
FILELIST_tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 := $(RTL_FLIST_DIR)/filelist_enc.f
FILELIST_tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 := $(RTL_FLIST_DIR)/filelist_encdec.f

DEFAULT_FILELIST := $(RTL_FLIST_DIR)/filelist.f
FILELIST ?= $(if $(FILELIST_$(TOP)),$(FILELIST_$(TOP)),$(DEFAULT_FILELIST))

ifeq ($(strip $(TB_SRC)),)
$(error Unsupported TOP '$(TOP)'. Please choose one of: tb_ubwc_dec_meta_data_gen_41x29, tb_ubwc_dec_meta_data_gen, tb_ubwc_dec_meta_data_gen_tajmahal_cases, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12, tb_ubwc_dec_meta, tb_ubwc_dec_axi_rdata_to_sram, tb_ubwc_enc_meta_get_cmd_gen, tb_ubwc_dec_tile_arcmd_gen, tb_ubwc_dec_tile_to_line_path, tb_ubwc_dec_tile_to_line_image_formats, tb_ubwc_dec_tile_to_line_hd_formats, tb_ubwc_dec_tile_to_otf_1080p_rgba, tb_ubwc_dec_tile_to_otf_1920x1080_nv12, tb_ubwc_dec_tile_to_otf_1960x1080_nv12, tb_ubwc_dec_tile_to_otf_tajmahal_cases, tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888, tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102, tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888, tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12, tb_ubwc_dec_wrapper_top_tajmahal_cases, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12, tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016, tb_ubwc_dec_wrapper_top_tajmahal_rgba8888, tb_ubwc_enc_wrapper_top_tajmahal_cases, tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888, tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102, tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12, tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016, tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12)
endif

TB_PARAM_FLAGS :=
IVERILOG_PARAM_FLAGS :=
VERILATOR_PARAM_FLAGS :=

ifneq ($(strip $(CASE_BASE_FORMAT)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).CASE_BASE_FORMAT=$(CASE_BASE_FORMAT)
IVERILOG_PARAM_FLAGS += -P$(TOP).CASE_BASE_FORMAT=$(CASE_BASE_FORMAT)
VERILATOR_PARAM_FLAGS += -GCASE_BASE_FORMAT=$(CASE_BASE_FORMAT)
endif

ifneq ($(strip $(CASE_TILE_X_NUMBERS)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).CASE_TILE_X_NUMBERS=$(CASE_TILE_X_NUMBERS)
IVERILOG_PARAM_FLAGS += -P$(TOP).CASE_TILE_X_NUMBERS=$(CASE_TILE_X_NUMBERS)
VERILATOR_PARAM_FLAGS += -GCASE_TILE_X_NUMBERS=$(CASE_TILE_X_NUMBERS)
endif

ifneq ($(strip $(CASE_TILE_Y_NUMBERS)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).CASE_TILE_Y_NUMBERS=$(CASE_TILE_Y_NUMBERS)
IVERILOG_PARAM_FLAGS += -P$(TOP).CASE_TILE_Y_NUMBERS=$(CASE_TILE_Y_NUMBERS)
VERILATOR_PARAM_FLAGS += -GCASE_TILE_Y_NUMBERS=$(CASE_TILE_Y_NUMBERS)
endif

ifneq ($(strip $(CASE_ID)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).CASE_ID=$(CASE_ID)
IVERILOG_PARAM_FLAGS += -P$(TOP).CASE_ID=$(CASE_ID)
VERILATOR_PARAM_FLAGS += -GCASE_ID=$(CASE_ID)
endif

ifneq ($(strip $(CASE_ENABLE_FILE_COMPARE)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).CASE_ENABLE_FILE_COMPARE=$(CASE_ENABLE_FILE_COMPARE)
IVERILOG_PARAM_FLAGS += -P$(TOP).CASE_ENABLE_FILE_COMPARE=$(CASE_ENABLE_FILE_COMPARE)
VERILATOR_PARAM_FLAGS += -GCASE_ENABLE_FILE_COMPARE=$(CASE_ENABLE_FILE_COMPARE)
endif

ifneq ($(strip $(TB_REAL_VIVO_MODE)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).TB_REAL_VIVO_MODE=$(TB_REAL_VIVO_MODE)
IVERILOG_PARAM_FLAGS += -P$(TOP).TB_REAL_VIVO_MODE=$(TB_REAL_VIVO_MODE)
VERILATOR_PARAM_FLAGS += -GTB_REAL_VIVO_MODE=$(TB_REAL_VIVO_MODE)
endif

ifneq ($(strip $(FORCE_FULL_PAYLOAD_CASE)),)
TB_PARAM_FLAGS += -pvalue+$(TOP).FORCE_FULL_PAYLOAD_CASE=$(FORCE_FULL_PAYLOAD_CASE)
IVERILOG_PARAM_FLAGS += -P$(TOP).FORCE_FULL_PAYLOAD_CASE=$(FORCE_FULL_PAYLOAD_CASE)
VERILATOR_PARAM_FLAGS += -GFORCE_FULL_PAYLOAD_CASE=$(FORCE_FULL_PAYLOAD_CASE)
endif

VCS_DEBUG_FLAGS := -kdb -debug_access+all
VCS_WAVE_FLAGS := +define+WAVES +define+FSDB
VCS_WARN_FLAGS := +v2k +lint=TFIPC-L +warn=all

VCS_FLAGS := -full64 -sverilog -timescale=1ns/1ps \
	-F $(FILELIST) \
	$(TB_SRC) \
	-top $(TOP) \
	-o $(SIMV) \
	-Mdir=$(BUILD_DIR)/csrc \
	-l $(COMP_LOG) \
	$(VCS_DEBUG_FLAGS) \
	$(VCS_WARN_FLAGS) \
	$(TB_PARAM_FLAGS) \
	$(VCS_WAVE_FLAGS)

ifdef VERDI_HOME
VCS_FLAGS += -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
	$(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
endif

VERDI_FLAGS := -sv -F $(FILELIST) $(TB_SRC) -top $(TOP)
FILELIST_DIR := $(abspath $(dir $(FILELIST)))
FILELIST_NAME := $(notdir $(FILELIST))

IVERILOG_FLAGS := -g2012 \
	-s $(TOP) \
	$(IVERILOG_PARAM_FLAGS) \
	-o $(abspath $(IVERILOG_SIMV)) \
	-f $(FILELIST_NAME) \
	$(TB_SRC)

VERILATOR_FLAGS := --binary --timing -Wno-fatal \
	-Mdir $(VERILATOR_OBJ_DIR) \
	-F $(FILELIST) \
	$(TB_SRC) \
	--top-module $(TOP) \
	$(VERILATOR_PARAM_FLAGS)

.PHONY: iverilog_comp iverilog_run iverilog_all \
	verilator_comp verilator_run verilator_all \
	wrapper_tajmahal_cases_iverilog_comp \
	wrapper_tajmahal_cases_iverilog_run \
	wrapper_tajmahal_cases_iverilog_all \
	wrapper_tajmahal_cases_verilator_comp \
	wrapper_tajmahal_cases_verilator_run \
	wrapper_tajmahal_cases_verilator_all

.PHONY: comp run all verdi verid clean \
	meta_tajmahal_cases_gen_expected \
	meta_tajmahal_cases_comp meta_tajmahal_cases_run \
	meta_tajmahal_cases_all meta_tajmahal_cases_verdi \
	meta_tajmahal_cases_verid \
	meta_tajmahal_4096x600_rgba8888_full_all \
	meta_tajmahal_4096x600_rgba1010102_full_all \
	meta_tajmahal_4096x600_nv12_full_all \
	meta_tajmahal_4096x600_rgba8888_gen_expected \
	meta_tajmahal_4096x600_rgba8888_comp meta_tajmahal_4096x600_rgba8888_run \
	meta_tajmahal_4096x600_rgba8888_all meta_tajmahal_4096x600_rgba8888_verdi \
	meta_tajmahal_4096x600_rgba8888_verid \
	meta_tajmahal_4096x600_rgba1010102_gen_expected \
	meta_tajmahal_4096x600_rgba1010102_comp meta_tajmahal_4096x600_rgba1010102_run \
	meta_tajmahal_4096x600_rgba1010102_all meta_tajmahal_4096x600_rgba1010102_verdi \
	meta_tajmahal_4096x600_rgba1010102_verid \
	meta_tajmahal_4096x600_nv12_gen_expected \
	meta_tajmahal_4096x600_nv12_comp meta_tajmahal_4096x600_nv12_run \
	meta_tajmahal_4096x600_nv12_all meta_tajmahal_4096x600_nv12_verdi \
	meta_tajmahal_4096x600_nv12_verid \
	tile_arcmd_comp tile_arcmd_run tile_arcmd_all \
	tile_arcmd_verdi tile_arcmd_verid \
	otf_1080p_rgba_comp otf_1080p_rgba_run otf_1080p_rgba_all \
	otf_1080p_rgba_verdi otf_1080p_rgba_verid \
	otf_1920x1080_nv12_comp otf_1920x1080_nv12_run otf_1920x1080_nv12_all \
		otf_1920x1080_nv12_verdi otf_1920x1080_nv12_verid \
		otf_1960x1080_nv12_comp otf_1960x1080_nv12_run otf_1960x1080_nv12_all \
			otf_1960x1080_nv12_verdi otf_1960x1080_nv12_verid \
			otf_tajmahal_cases_comp otf_tajmahal_cases_run \
			otf_tajmahal_cases_all otf_tajmahal_cases_verdi \
			otf_tajmahal_cases_verid \
			otf_tajmahal_4096x608_rgba8888_comp otf_tajmahal_4096x608_rgba8888_run \
			otf_tajmahal_4096x608_rgba8888_all otf_tajmahal_4096x608_rgba8888_verdi \
			otf_tajmahal_4096x608_rgba8888_verid \
		otf_tajmahal_4096x608_rgba1010102_comp otf_tajmahal_4096x608_rgba1010102_run \
		otf_tajmahal_4096x608_rgba1010102_all otf_tajmahal_4096x608_rgba1010102_verdi \
		otf_tajmahal_4096x608_rgba1010102_verid \
		otf_tajmahal_linear_in_rgba8888_comp otf_tajmahal_linear_in_rgba8888_run \
		otf_tajmahal_linear_in_rgba8888_all otf_tajmahal_linear_in_rgba8888_verdi \
		otf_tajmahal_linear_in_rgba8888_verid \
		otf_tajmahal_4096x640_nv12_comp otf_tajmahal_4096x640_nv12_run \
		otf_tajmahal_4096x640_nv12_all otf_tajmahal_4096x640_nv12_verdi \
		otf_tajmahal_4096x640_nv12_verid \
		wrapper_tajmahal_cases_prepare wrapper_tajmahal_cases_comp \
		wrapper_tajmahal_cases_run wrapper_tajmahal_cases_all \
		wrapper_tajmahal_cases_verdi wrapper_tajmahal_cases_verid \
		wrapper_tajmahal_4096x600_rgba8888_vivo_comp wrapper_tajmahal_4096x600_rgba8888_vivo_run \
		wrapper_tajmahal_4096x600_rgba8888_vivo_all wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all wrapper_tajmahal_4096x600_rgba8888_vivo_real_all wrapper_tajmahal_4096x600_rgba8888_vivo_verdi \
		wrapper_tajmahal_4096x600_rgba1010102_vivo_comp wrapper_tajmahal_4096x600_rgba1010102_vivo_run \
		wrapper_tajmahal_4096x600_rgba1010102_vivo_all wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all wrapper_tajmahal_4096x600_rgba1010102_vivo_real_all wrapper_tajmahal_4096x600_rgba1010102_vivo_verdi \
		wrapper_tajmahal_4096x600_nv12_vivo_comp wrapper_tajmahal_4096x600_nv12_vivo_run \
		wrapper_tajmahal_4096x600_nv12_vivo_all wrapper_tajmahal_4096x600_nv12_vivo_fake_all wrapper_tajmahal_4096x600_nv12_vivo_real_all wrapper_tajmahal_4096x600_nv12_vivo_verdi \
		wrapper_k_outdoor61_4096x600_g016_vivo_comp wrapper_k_outdoor61_4096x600_g016_vivo_run \
		wrapper_k_outdoor61_4096x600_g016_vivo_all wrapper_k_outdoor61_4096x600_g016_vivo_fake_all wrapper_k_outdoor61_4096x600_g016_vivo_real_all wrapper_k_outdoor61_4096x600_g016_vivo_verdi \
		wrapper_tajmahal_4096x600_nv12_otf_prepare wrapper_tajmahal_4096x600_nv12_otf_comp \
		wrapper_tajmahal_4096x600_nv12_otf_run wrapper_tajmahal_4096x600_nv12_otf_all \
		wrapper_tajmahal_4096x600_nv12_otf_verdi compare_wrapper_tajmahal_4096x600_nv12_otf \
		wrapper_tajmahal_rgba8888_comp wrapper_tajmahal_rgba8888_run \
		wrapper_tajmahal_rgba8888_all wrapper_tajmahal_rgba8888_verdi \
		wrapper_tajmahal_rgba8888_verid \
		enc_wrapper_tajmahal_cases_prepare \
		enc_wrapper_tajmahal_4096x600_rgba8888_comp enc_wrapper_tajmahal_4096x600_rgba8888_run \
		enc_wrapper_tajmahal_4096x600_rgba8888_all enc_wrapper_tajmahal_4096x600_rgba8888_fake_all enc_wrapper_tajmahal_4096x600_rgba8888_nonfake_all enc_wrapper_tajmahal_4096x600_rgba8888_verdi \
		enc_wrapper_tajmahal_4096x600_rgba1010102_comp enc_wrapper_tajmahal_4096x600_rgba1010102_run \
		enc_wrapper_tajmahal_4096x600_rgba1010102_all enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all enc_wrapper_tajmahal_4096x600_rgba1010102_nonfake_all enc_wrapper_tajmahal_4096x600_rgba1010102_verdi \
		enc_wrapper_tajmahal_4096x600_nv12_comp enc_wrapper_tajmahal_4096x600_nv12_run \
		enc_wrapper_tajmahal_4096x600_nv12_all enc_wrapper_tajmahal_4096x600_nv12_fake_all enc_wrapper_tajmahal_4096x600_nv12_nonfake_all enc_wrapper_tajmahal_4096x600_nv12_verdi \
		enc_wrapper_k_outdoor61_4096x600_g016_comp enc_wrapper_k_outdoor61_4096x600_g016_run \
		enc_wrapper_k_outdoor61_4096x600_g016_all enc_wrapper_k_outdoor61_4096x600_g016_fake_all enc_wrapper_k_outdoor61_4096x600_g016_nonfake_all enc_wrapper_k_outdoor61_4096x600_g016_verdi \
		encdec_wrapper_tajmahal_4096x600_nv12_prepare \
		encdec_wrapper_tajmahal_4096x600_nv12_comp \
		encdec_wrapper_tajmahal_4096x600_nv12_run \
		encdec_wrapper_tajmahal_4096x600_nv12_all \
		encdec_wrapper_tajmahal_4096x600_nv12_verdi \
		compare_encdec_wrapper_tajmahal_4096x600_nv12_otf

comp: $(SIMV)

$(SIMV): $(FILELIST) $(TB_SRC)
	@mkdir -p $(BUILD_DIR)
	$(VCS) $(VCS_FLAGS)

run: $(SIMV)
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && ./simv $(RUN_ARGS) -l $(notdir $(RUN_LOG))

all: comp run

iverilog_comp: $(IVERILOG_SIMV)

$(IVERILOG_SIMV): $(FILELIST) $(TB_SRC)
	@mkdir -p $(IVERILOG_BUILD_DIR)
	cd $(FILELIST_DIR) && $(IVERILOG) $(IVERILOG_FLAGS) > $(abspath $(IVERILOG_COMP_LOG)) 2>&1 || { cat $(abspath $(IVERILOG_COMP_LOG)); exit 1; }

iverilog_run: $(IVERILOG_SIMV)
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && { \
		$(VVP) -l $(notdir $(IVERILOG_RUN_LOG)) $(abspath $(IVERILOG_SIMV)) $(RUN_ARGS); \
		status=$$?; \
		if [ -f wrapper_compare_summary.txt ]; then \
			cp wrapper_compare_summary.txt $(notdir $(IVERILOG_SUMMARY_LOG)); \
		fi; \
		exit $$status; \
	}

iverilog_all: iverilog_comp iverilog_run

verilator_comp: $(VERILATOR_SIMV)

$(VERILATOR_SIMV): $(FILELIST) $(TB_SRC)
	@mkdir -p $(VERILATOR_BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) > $(VERILATOR_COMP_LOG) 2>&1 || { cat $(VERILATOR_COMP_LOG); exit 1; }

verilator_run: $(VERILATOR_SIMV)
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && { \
		$(abspath $(VERILATOR_SIMV)) $(RUN_ARGS) > $(notdir $(VERILATOR_RUN_LOG)) 2>&1; \
		status=$$?; \
		if [ -f wrapper_compare_summary.txt ]; then \
			cp wrapper_compare_summary.txt $(notdir $(VERILATOR_SUMMARY_LOG)); \
		fi; \
		exit $$status; \
	}

verilator_all: verilator_comp verilator_run

verdi: $(SIMV)
	@FSDB_FILE=$$(ls $(BUILD_DIR)/*.fsdb 2>/dev/null | head -n 1); \
	if [ -n "$$FSDB_FILE" ]; then \
		$(VERDI) $(VERDI_FLAGS) -ssf $$FSDB_FILE & \
	else \
		$(VERDI) $(VERDI_FLAGS) & \
	fi

verid: verdi

prepare_meta_tajmahal_case:
	@mkdir -p $(BUILD_DIR)
	@case "$(EFFECTIVE_CASE_ID)" in \
		0) \
			cp $(TAJMAHAL_RGBA_META_SRC) $(BUILD_DIR)/input_meta_plane0.txt; \
			$(META_CASE_TOOL) --format rgba8888 --plane0-vector $(BUILD_DIR)/input_meta_plane0.txt --tile-x-numbers $(TAJMAHAL_META_FIFO_TILE_X) --tile-y-numbers $(TAJMAHAL_META_FIFO_TILE_Y) --out $(BUILD_DIR)/expected_fifo_stream.txt; \
			;; \
		1) \
			cp $(TAJMAHAL_RGBA1010102_META_SRC) $(BUILD_DIR)/input_meta_plane0.txt; \
			$(META_CASE_TOOL) --format rgba1010102 --plane0-vector $(BUILD_DIR)/input_meta_plane0.txt --tile-x-numbers $(TAJMAHAL_META_FIFO_TILE_X) --tile-y-numbers $(TAJMAHAL_META_FIFO_TILE_Y) --out $(BUILD_DIR)/expected_fifo_stream.txt; \
			;; \
		2) \
			cp $(TAJMAHAL_NV12_META_Y_SRC) $(BUILD_DIR)/input_meta_plane0.txt; \
			cp $(TAJMAHAL_NV12_META_UV_SRC) $(BUILD_DIR)/input_meta_plane1.txt; \
			$(META_CASE_TOOL) --format nv12 --plane0-vector $(BUILD_DIR)/input_meta_plane0.txt --plane1-vector $(BUILD_DIR)/input_meta_plane1.txt --tile-x-numbers $(TAJMAHAL_META_FIFO_TILE_X) --tile-y-numbers $(TAJMAHAL_META_FIFO_TILE_Y) --out $(BUILD_DIR)/expected_fifo_stream.txt; \
			;; \
		*) \
			echo "Unsupported CASE_ID=$(EFFECTIVE_CASE_ID) for tb_ubwc_dec_meta_data_gen_tajmahal_cases"; \
			exit 1; \
			;; \
	esac

meta_tajmahal_cases_gen_expected:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) prepare_meta_tajmahal_case

meta_tajmahal_cases_comp:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) comp

meta_tajmahal_cases_run: meta_tajmahal_cases_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) run

meta_tajmahal_cases_all: meta_tajmahal_cases_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) all

meta_tajmahal_cases_verdi:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) verdi

meta_tajmahal_cases_verid:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) verid

meta_tajmahal_4096x600_rgba8888_gen_expected:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_ID=0 prepare_meta_tajmahal_case

meta_tajmahal_4096x600_rgba8888_comp:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 comp

meta_tajmahal_4096x600_rgba8888_run: meta_tajmahal_4096x600_rgba8888_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 run

meta_tajmahal_4096x600_rgba8888_all: meta_tajmahal_4096x600_rgba8888_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 all

meta_tajmahal_4096x600_rgba8888_verdi:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 verdi

meta_tajmahal_4096x600_rgba8888_verid:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 verid

meta_tajmahal_4096x600_rgba8888_full_all:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_ID=0 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 prepare_meta_tajmahal_case
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 all

meta_tajmahal_4096x600_rgba1010102_gen_expected:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 CASE_ID=1 prepare_meta_tajmahal_case

meta_tajmahal_4096x600_rgba1010102_comp:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 comp

meta_tajmahal_4096x600_rgba1010102_run: meta_tajmahal_4096x600_rgba1010102_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 run

meta_tajmahal_4096x600_rgba1010102_all: meta_tajmahal_4096x600_rgba1010102_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 all

meta_tajmahal_4096x600_rgba1010102_verdi:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 verdi

meta_tajmahal_4096x600_rgba1010102_verid:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 verid

meta_tajmahal_4096x600_rgba1010102_full_all:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 CASE_ID=1 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 prepare_meta_tajmahal_case
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 all

meta_tajmahal_4096x600_nv12_gen_expected:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 CASE_ID=2 prepare_meta_tajmahal_case

meta_tajmahal_4096x600_nv12_comp:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 comp

meta_tajmahal_4096x600_nv12_run: meta_tajmahal_4096x600_nv12_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 run

meta_tajmahal_4096x600_nv12_all: meta_tajmahal_4096x600_nv12_gen_expected
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 all

meta_tajmahal_4096x600_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 verdi

meta_tajmahal_4096x600_nv12_verid:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 verid

meta_tajmahal_4096x600_nv12_full_all:
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 CASE_ID=2 CASE_TILE_X_NUMBERS=128 CASE_TILE_Y_NUMBERS=80 prepare_meta_tajmahal_case
	$(MAKE) TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 CASE_TILE_X_NUMBERS=128 CASE_TILE_Y_NUMBERS=80 all

tile_arcmd_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_arcmd_gen comp

tile_arcmd_run:
	$(MAKE) TOP=tb_ubwc_dec_tile_arcmd_gen run

tile_arcmd_all:
	$(MAKE) TOP=tb_ubwc_dec_tile_arcmd_gen all

tile_arcmd_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_arcmd_gen verdi

tile_arcmd_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_arcmd_gen verid

otf_1080p_rgba_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1080p_rgba comp

otf_1080p_rgba_run:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1080p_rgba run

otf_1080p_rgba_all:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1080p_rgba all

otf_1080p_rgba_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1080p_rgba verdi

otf_1080p_rgba_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1080p_rgba verid

otf_1920x1080_nv12_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1920x1080_nv12 comp

otf_1920x1080_nv12_run:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1920x1080_nv12 run

otf_1920x1080_nv12_all:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1920x1080_nv12 all

otf_1920x1080_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1920x1080_nv12 verdi

otf_1920x1080_nv12_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1920x1080_nv12 verid

otf_1960x1080_nv12_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1960x1080_nv12 comp

otf_1960x1080_nv12_run:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1960x1080_nv12 run

otf_1960x1080_nv12_all:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1960x1080_nv12 all

otf_1960x1080_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1960x1080_nv12 verdi

otf_1960x1080_nv12_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_1960x1080_nv12 verid

prepare_otf_tajmahal_cases:
	@mkdir -p build/tb_ubwc_dec_tile_to_otf_tajmahal_cases
	@case "$(EFFECTIVE_CASE_ID)" in \
		0) \
			grep -v '^@' $(TAJMAHAL_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/input_rgba_tiled.memh; \
			grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba8888 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --width 4096 --stored-height 608 --out build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/expected_otf_stream.txt; \
			;; \
		1) \
			grep -v '^@' $(TAJMAHAL_RGBA1010102_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/input_rgba_tiled.memh; \
			grep -v '^@' $(TAJMAHAL_RGBA1010102_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba1010102 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --width 4096 --stored-height 608 --out build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/expected_otf_stream.txt; \
			;; \
		2) \
			grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/input_rgba_linear.memh; \
			grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba8888 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --width 4096 --stored-height 608 --out build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/expected_otf_stream.txt; \
			;; \
		3) \
			grep -v '^@' $(TAJMAHAL_NV12_Y_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/input_nv12_y_tiled.memh; \
			grep -v '^@' $(TAJMAHAL_NV12_UV_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/input_nv12_uv_tiled.memh; \
			grep -v '^@' $(TAJMAHAL_NV12_Y_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_y_linear.memh; \
			grep -v '^@' $(TAJMAHAL_NV12_UV_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_uv_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format nv12 --expected-y build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_y_linear.memh --expected-uv build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_uv_linear.memh --width 4096 --stored-y-height 640 --stored-uv-height 320 --out build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/expected_otf_stream.txt; \
			;; \
		*) \
			echo "Unsupported CASE_ID=$(EFFECTIVE_CASE_ID) for tb_ubwc_dec_tile_to_otf_tajmahal_cases"; \
			exit 1; \
			;; \
	esac

compare_otf_tajmahal_cases:
	@case "$(EFFECTIVE_CASE_ID)" in \
		0) \
			$(OTF_CASE_TOOL) compare --format rgba8888 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --actual build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/actual_otf_stream.txt --width 4096 --active-height 600 --stored-height 608 --out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/compare; \
			;; \
		1) \
			$(OTF_CASE_TOOL) compare --format rgba1010102 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --actual build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/actual_otf_stream.txt --width 4096 --active-height 600 --stored-height 608 --out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/compare; \
			;; \
		2) \
			$(OTF_CASE_TOOL) compare --format rgba8888 --expected build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_rgba_linear.memh --actual build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/actual_otf_stream.txt --width 4096 --active-height 600 --stored-height 608 --out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/compare; \
			;; \
		3) \
			$(OTF_CASE_TOOL) compare --format nv12 --expected-y build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_y_linear.memh --expected-uv build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/golden_nv12_uv_linear.memh --actual build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/actual_otf_stream.txt --width 4096 --active-height 600 --stored-y-height 640 --stored-uv-height 320 --out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_cases/compare; \
			;; \
		*) \
			echo "Unsupported CASE_ID=$(EFFECTIVE_CASE_ID) for tb_ubwc_dec_tile_to_otf_tajmahal_cases"; \
			exit 1; \
			;; \
	esac

otf_tajmahal_cases_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) comp

otf_tajmahal_cases_run: prepare_otf_tajmahal_cases
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) run

otf_tajmahal_cases_all: prepare_otf_tajmahal_cases
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) all
	$(MAKE) compare_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID)

otf_tajmahal_cases_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) verdi

otf_tajmahal_cases_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) verid

prepare_otf_tajmahal_4096x608_rgba8888:
	@mkdir -p build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888
	grep -v '^@' $(TAJMAHAL_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/input_rgba_tiled.memh
	grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/golden_rgba_linear.memh
	$(OTF_CASE_TOOL) gen-stream \
		--format rgba8888 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/golden_rgba_linear.memh \
		--width 4096 \
		--stored-height 608 \
		--out build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/expected_otf_stream.txt

compare_otf_tajmahal_4096x608_rgba8888:
	$(OTF_CASE_TOOL) compare \
		--format rgba8888 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/golden_rgba_linear.memh \
		--actual build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-height 608 \
		--out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888/compare

otf_tajmahal_4096x608_rgba8888_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 comp

otf_tajmahal_4096x608_rgba8888_run: prepare_otf_tajmahal_4096x608_rgba8888
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 run

otf_tajmahal_4096x608_rgba8888_all: prepare_otf_tajmahal_4096x608_rgba8888
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 all
	$(MAKE) compare_otf_tajmahal_4096x608_rgba8888

otf_tajmahal_4096x608_rgba8888_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 verdi

otf_tajmahal_4096x608_rgba8888_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888 verid

prepare_otf_tajmahal_4096x608_rgba1010102:
	@mkdir -p build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102
	grep -v '^@' $(TAJMAHAL_RGBA1010102_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/input_rgba_tiled.memh
	grep -v '^@' $(TAJMAHAL_RGBA1010102_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/golden_rgba_linear.memh
	$(OTF_CASE_TOOL) gen-stream \
		--format rgba1010102 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/golden_rgba_linear.memh \
		--width 4096 \
		--stored-height 608 \
		--out build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/expected_otf_stream.txt

compare_otf_tajmahal_4096x608_rgba1010102:
	$(OTF_CASE_TOOL) compare \
		--format rgba1010102 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/golden_rgba_linear.memh \
		--actual build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-height 608 \
		--out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102/compare

otf_tajmahal_4096x608_rgba1010102_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 comp

otf_tajmahal_4096x608_rgba1010102_run: prepare_otf_tajmahal_4096x608_rgba1010102
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 run

otf_tajmahal_4096x608_rgba1010102_all: prepare_otf_tajmahal_4096x608_rgba1010102
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 all
	$(MAKE) compare_otf_tajmahal_4096x608_rgba1010102

otf_tajmahal_4096x608_rgba1010102_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 verdi

otf_tajmahal_4096x608_rgba1010102_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102 verid

prepare_otf_tajmahal_linear_in_rgba8888:
	@mkdir -p build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888
	grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/input_rgba_linear.memh
	grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/golden_rgba_linear.memh
	$(OTF_CASE_TOOL) gen-stream \
		--format rgba8888 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/golden_rgba_linear.memh \
		--width 4096 \
		--stored-height 608 \
		--out build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/expected_otf_stream.txt

compare_otf_tajmahal_linear_in_rgba8888:
	$(OTF_CASE_TOOL) compare \
		--format rgba8888 \
		--expected build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/golden_rgba_linear.memh \
		--actual build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-height 608 \
		--out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888/compare

otf_tajmahal_linear_in_rgba8888_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 comp

otf_tajmahal_linear_in_rgba8888_run: prepare_otf_tajmahal_linear_in_rgba8888
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 run

otf_tajmahal_linear_in_rgba8888_all: prepare_otf_tajmahal_linear_in_rgba8888
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 all
	$(MAKE) compare_otf_tajmahal_linear_in_rgba8888

otf_tajmahal_linear_in_rgba8888_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 verdi

otf_tajmahal_linear_in_rgba8888_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888 verid

prepare_otf_tajmahal_4096x640_nv12:
	@mkdir -p build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12
	grep -v '^@' $(TAJMAHAL_NV12_Y_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/input_nv12_y_tiled.memh
	grep -v '^@' $(TAJMAHAL_NV12_UV_TILED_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/input_nv12_uv_tiled.memh
	grep -v '^@' $(TAJMAHAL_NV12_Y_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_y_linear.memh
	grep -v '^@' $(TAJMAHAL_NV12_UV_LINEAR_SRC) > build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_uv_linear.memh
	$(OTF_CASE_TOOL) gen-stream \
		--format nv12 \
		--expected-y build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_y_linear.memh \
		--expected-uv build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_uv_linear.memh \
		--width 4096 \
		--stored-y-height 640 \
		--stored-uv-height 320 \
		--out build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/expected_otf_stream.txt

compare_otf_tajmahal_4096x640_nv12:
	$(OTF_CASE_TOOL) compare \
		--format nv12 \
		--expected-y build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_y_linear.memh \
		--expected-uv build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/golden_nv12_uv_linear.memh \
		--actual build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-y-height 640 \
		--stored-uv-height 320 \
		--out-dir build/tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12/compare

otf_tajmahal_4096x640_nv12_comp:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 comp

otf_tajmahal_4096x640_nv12_run: prepare_otf_tajmahal_4096x640_nv12
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 run

otf_tajmahal_4096x640_nv12_all: prepare_otf_tajmahal_4096x640_nv12
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 all
	$(MAKE) compare_otf_tajmahal_4096x640_nv12

otf_tajmahal_4096x640_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 verdi

otf_tajmahal_4096x640_nv12_verid:
	$(MAKE) TOP=tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12 verid

wrapper_tajmahal_cases_prepare:
	@mkdir -p $(BUILD_DIR)
	@case "$(EFFECTIVE_CASE_ID)" in \
		0) \
			grep -v '^@' $(WRAPPER_CASES_RGBA8888_META_SRC) > $(BUILD_DIR)/input_meta_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_RGBA8888_AXI_TILE_SRC) > $(BUILD_DIR)/input_tile_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_RGBA8888_REF_TILE_SRC) > $(BUILD_DIR)/inject_tile_plane0.txt; \
			grep -v '^@' $(TAJMAHAL_LINEAR_SRC) > $(BUILD_DIR)/golden_rgba_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba8888 --expected $(BUILD_DIR)/golden_rgba_linear.memh --width 4096 --stored-height 608 --out $(BUILD_DIR)/expected_otf_stream.txt; \
			: > $(BUILD_DIR)/input_meta_plane1.txt; \
			: > $(BUILD_DIR)/input_tile_plane1.txt; \
			: > $(BUILD_DIR)/inject_tile_plane1.txt; \
			;; \
		1) \
			grep -v '^@' $(WRAPPER_CASES_RGBA1010102_META_SRC) > $(BUILD_DIR)/input_meta_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_RGBA1010102_AXI_TILE_SRC) > $(BUILD_DIR)/input_tile_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_RGBA1010102_REF_TILE_SRC) > $(BUILD_DIR)/inject_tile_plane0.txt; \
			grep -v '^@' $(TAJMAHAL_RGBA1010102_LINEAR_SRC) > $(BUILD_DIR)/golden_rgba_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba1010102 --expected $(BUILD_DIR)/golden_rgba_linear.memh --width 4096 --stored-height 608 --out $(BUILD_DIR)/expected_otf_stream.txt; \
			: > $(BUILD_DIR)/input_meta_plane1.txt; \
			: > $(BUILD_DIR)/input_tile_plane1.txt; \
			: > $(BUILD_DIR)/inject_tile_plane1.txt; \
			;; \
		2) \
			grep -v '^@' $(WRAPPER_CASES_NV12_Y_META_SRC) > $(BUILD_DIR)/input_meta_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_NV12_UV_META_SRC) > $(BUILD_DIR)/input_meta_plane1.txt; \
			grep -v '^@' $(WRAPPER_CASES_NV12_Y_AXI_TILE_SRC) > $(BUILD_DIR)/input_tile_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_NV12_UV_AXI_TILE_SRC) > $(BUILD_DIR)/input_tile_plane1.txt; \
			grep -v '^@' $(WRAPPER_CASES_NV12_Y_REF_TILE_SRC) > $(BUILD_DIR)/inject_tile_plane0.txt; \
			grep -v '^@' $(WRAPPER_CASES_NV12_UV_REF_TILE_SRC) > $(BUILD_DIR)/inject_tile_plane1.txt; \
			grep -v '^@' $(TAJMAHAL_NV12_Y_LINEAR_SRC) > $(BUILD_DIR)/golden_nv12_y_linear.memh; \
			grep -v '^@' $(TAJMAHAL_NV12_UV_LINEAR_SRC) > $(BUILD_DIR)/golden_nv12_uv_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format nv12 --expected-y $(BUILD_DIR)/golden_nv12_y_linear.memh --expected-uv $(BUILD_DIR)/golden_nv12_uv_linear.memh --width 4096 --stored-y-height 640 --stored-uv-height 320 --out $(BUILD_DIR)/expected_otf_stream.txt; \
			;; \
		3) \
			grep -v '^@' $(K_OUTDOOR61_G016_META_Y_SRC) > $(BUILD_DIR)/input_meta_plane0.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_META_UV_SRC) > $(BUILD_DIR)/input_meta_plane1.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_Y_TILED_COMP_SRC) > $(BUILD_DIR)/input_tile_plane0.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_UV_TILED_COMP_SRC) > $(BUILD_DIR)/input_tile_plane1.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_Y_TILED_UNCOMP_SRC) > $(BUILD_DIR)/inject_tile_plane0.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_UV_TILED_UNCOMP_SRC) > $(BUILD_DIR)/inject_tile_plane1.txt; \
			grep -v '^@' $(K_OUTDOOR61_G016_Y_LINEAR_SRC) > $(BUILD_DIR)/golden_p010_y_linear.memh; \
			grep -v '^@' $(K_OUTDOOR61_G016_UV_LINEAR_SRC) > $(BUILD_DIR)/golden_p010_uv_linear.memh; \
			$(OTF_CASE_TOOL) gen-stream --format p010 --expected-y $(BUILD_DIR)/golden_p010_y_linear.memh --expected-uv $(BUILD_DIR)/golden_p010_uv_linear.memh --width 4096 --stored-y-height 608 --stored-uv-height 304 --p010-uv-phase odd --out $(BUILD_DIR)/expected_otf_stream.txt; \
			;; \
		*) \
			echo "Unsupported CASE_ID=$(EFFECTIVE_CASE_ID) for wrapper TajMahal cases"; \
			exit 1; \
			;; \
	esac

wrapper_tajmahal_cases_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_tajmahal_cases_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) run

wrapper_tajmahal_cases_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) all

wrapper_tajmahal_cases_iverilog_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) iverilog_comp

wrapper_tajmahal_cases_iverilog_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) iverilog_run

wrapper_tajmahal_cases_iverilog_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) iverilog_all

wrapper_tajmahal_cases_verilator_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verilator_comp

wrapper_tajmahal_cases_verilator_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verilator_run

wrapper_tajmahal_cases_verilator_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verilator_all

wrapper_tajmahal_cases_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_tajmahal_cases_verid:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases CASE_ID=$(EFFECTIVE_CASE_ID) TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verid

define DECLARE_WRAPPER_OPEN_SIM_TARGETS
.PHONY: $(1)_iverilog_comp $(1)_iverilog_run $(1)_iverilog_all \
	$(1)_iverilog_fake_all $(1)_iverilog_real_all \
	$(1)_verilator_comp $(1)_verilator_run $(1)_verilator_all \
	$(1)_verilator_fake_all $(1)_verilator_real_all

$(1)_iverilog_comp:
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) iverilog_comp

$(1)_iverilog_run:
	$$(MAKE) TOP=$(2) CASE_ID=$(5) TB_REAL_VIVO_MODE=$(3) wrapper_tajmahal_cases_prepare
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) iverilog_run

$(1)_iverilog_all:
	$$(MAKE) TOP=$(2) CASE_ID=$(5) TB_REAL_VIVO_MODE=$(3) wrapper_tajmahal_cases_prepare
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) iverilog_all

$(1)_iverilog_fake_all:
	$$(MAKE) WRAPPER_NV12_VIVO_MODE=fake $(1)_iverilog_all

$(1)_iverilog_real_all:
	$$(MAKE) WRAPPER_NV12_VIVO_MODE=real $(1)_iverilog_all

$(1)_verilator_comp:
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) verilator_comp

$(1)_verilator_run:
	$$(MAKE) TOP=$(2) CASE_ID=$(5) TB_REAL_VIVO_MODE=$(3) wrapper_tajmahal_cases_prepare
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) verilator_run

$(1)_verilator_all:
	$$(MAKE) TOP=$(2) CASE_ID=$(5) TB_REAL_VIVO_MODE=$(3) wrapper_tajmahal_cases_prepare
	$$(MAKE) TOP=$(2) TB_REAL_VIVO_MODE=$(3) FORCE_FULL_PAYLOAD_CASE=$(4) verilator_all

$(1)_verilator_fake_all:
	$$(MAKE) WRAPPER_NV12_VIVO_MODE=fake $(1)_verilator_all

$(1)_verilator_real_all:
	$$(MAKE) WRAPPER_NV12_VIVO_MODE=real $(1)_verilator_all
endef

$(eval $(call DECLARE_WRAPPER_OPEN_SIM_TARGETS,wrapper_tajmahal_4096x600_rgba8888_vivo,tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888,$(WRAPPER_CASES_TB_REAL_VIVO_MODE),$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE),0))
$(eval $(call DECLARE_WRAPPER_OPEN_SIM_TARGETS,wrapper_tajmahal_4096x600_rgba1010102_vivo,tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102,$(WRAPPER_CASES_TB_REAL_VIVO_MODE),$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE),1))
$(eval $(call DECLARE_WRAPPER_OPEN_SIM_TARGETS,wrapper_tajmahal_4096x600_nv12_vivo,tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12,$(WRAPPER_NV12_TB_REAL_VIVO_MODE),$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE),2))
$(eval $(call DECLARE_WRAPPER_OPEN_SIM_TARGETS,wrapper_k_outdoor61_4096x600_g016_vivo,tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016,$(WRAPPER_CASES_TB_REAL_VIVO_MODE),$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE),3))

wrapper_tajmahal_4096x600_rgba8888_vivo_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_tajmahal_4096x600_rgba8888_vivo_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 CASE_ID=0 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) run

wrapper_tajmahal_4096x600_rgba8888_vivo_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 CASE_ID=0 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) all

wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba8888_vivo_all

wrapper_tajmahal_4096x600_rgba8888_vivo_real_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba8888_vivo_all

wrapper_tajmahal_4096x600_rgba8888_vivo_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_tajmahal_4096x600_rgba1010102_vivo_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_tajmahal_4096x600_rgba1010102_vivo_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 CASE_ID=1 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) run

wrapper_tajmahal_4096x600_rgba1010102_vivo_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 CASE_ID=1 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) all

wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba1010102_vivo_all

wrapper_tajmahal_4096x600_rgba1010102_vivo_real_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba1010102_vivo_all

wrapper_tajmahal_4096x600_rgba1010102_vivo_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_tajmahal_4096x600_nv12_vivo_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_tajmahal_4096x600_nv12_vivo_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 CASE_ID=2 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) run

wrapper_tajmahal_4096x600_nv12_vivo_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 CASE_ID=2 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) all

wrapper_tajmahal_4096x600_nv12_vivo_fake_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_vivo_all

wrapper_tajmahal_4096x600_nv12_vivo_real_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_vivo_all

wrapper_tajmahal_4096x600_nv12_vivo_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_k_outdoor61_4096x600_g016_vivo_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_k_outdoor61_4096x600_g016_vivo_run:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 CASE_ID=3 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) run

wrapper_k_outdoor61_4096x600_g016_vivo_all:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 CASE_ID=3 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) all

wrapper_k_outdoor61_4096x600_g016_vivo_fake_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_k_outdoor61_4096x600_g016_vivo_all

wrapper_k_outdoor61_4096x600_g016_vivo_real_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_k_outdoor61_4096x600_g016_vivo_all

wrapper_k_outdoor61_4096x600_g016_vivo_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 TB_REAL_VIVO_MODE=$(WRAPPER_CASES_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_CASES_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_tajmahal_4096x600_nv12_otf_prepare:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 CASE_ID=2 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) wrapper_tajmahal_cases_prepare

wrapper_tajmahal_4096x600_nv12_otf_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) comp

wrapper_tajmahal_4096x600_nv12_otf_run: wrapper_tajmahal_4096x600_nv12_otf_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) run

compare_wrapper_tajmahal_4096x600_nv12_otf:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) compare_wrapper_tajmahal_4096x600_nv12_otf_inner

compare_wrapper_tajmahal_4096x600_nv12_otf_inner:
	$(OTF_CASE_TOOL) compare \
		--format nv12 \
		--expected-y $(BUILD_DIR)/golden_nv12_y_linear.memh \
		--expected-uv $(BUILD_DIR)/golden_nv12_uv_linear.memh \
		--actual $(BUILD_DIR)/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-y-height 640 \
		--stored-uv-height 320 \
		--out-dir $(BUILD_DIR)/compare

wrapper_tajmahal_4096x600_nv12_otf_all: wrapper_tajmahal_4096x600_nv12_otf_prepare
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) all
	$(MAKE) compare_wrapper_tajmahal_4096x600_nv12_otf

wrapper_tajmahal_4096x600_nv12_otf_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 TB_REAL_VIVO_MODE=$(WRAPPER_NV12_TB_REAL_VIVO_MODE) FORCE_FULL_PAYLOAD_CASE=$(WRAPPER_NV12_FORCE_FULL_PAYLOAD_CASE) verdi

wrapper_tajmahal_4096x600_nv12_otf_fake_run:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_run

wrapper_tajmahal_4096x600_nv12_otf_fake_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_all

wrapper_tajmahal_4096x600_nv12_otf_fake_verdi:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_verdi

wrapper_tajmahal_4096x600_nv12_otf_real_run:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_run

wrapper_tajmahal_4096x600_nv12_otf_real_all:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_all

wrapper_tajmahal_4096x600_nv12_otf_real_verdi:
	$(MAKE) WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_verdi

wrapper_tajmahal_rgba8888_comp:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 comp

wrapper_tajmahal_rgba8888_run:
	@mkdir -p build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888
	grep -v '^@' $(TAJMAHAL_RGBA_META_SRC) > build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888/tajmahal_meta.memh
	grep -v '^@' $(TAJMAHAL_TILED_SRC) > build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888/tajmahal_tile.memh
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 run

wrapper_tajmahal_rgba8888_all:
	@mkdir -p build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888
	grep -v '^@' $(TAJMAHAL_RGBA_META_SRC) > build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888/tajmahal_meta.memh
	grep -v '^@' $(TAJMAHAL_TILED_SRC) > build/tb_ubwc_dec_wrapper_top_tajmahal_rgba8888/tajmahal_tile.memh
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 all

wrapper_tajmahal_rgba8888_verdi:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 verdi

wrapper_tajmahal_rgba8888_verid:
	$(MAKE) TOP=tb_ubwc_dec_wrapper_top_tajmahal_rgba8888 verid

enc_wrapper_tajmahal_cases_prepare:
	@mkdir -p $(BUILD_DIR)
	@case "$(TOP)" in \
		tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888) \
			grep -v '^@' $(TAJMAHAL_TILED_SRC) > $(BUILD_DIR)/expected_tile_plane0.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba8888 --expected $(TAJMAHAL_LINEAR_SRC) --width 4096 --stored-height 608 --out $(BUILD_DIR)/input_otf_stream.txt; \
			;; \
		tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102) \
			grep -v '^@' $(TAJMAHAL_RGBA1010102_TILED_SRC) > $(BUILD_DIR)/expected_tile_plane0.memh; \
			$(OTF_CASE_TOOL) gen-stream --format rgba1010102 --expected $(TAJMAHAL_RGBA1010102_LINEAR_SRC) --width 4096 --stored-height 608 --out $(BUILD_DIR)/input_otf_stream.txt; \
			;; \
		tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12) \
			grep -v '^@' $(TAJMAHAL_NV12_Y_TILED_UNCOMP_SRC) > $(BUILD_DIR)/expected_tile_plane0.memh; \
			grep -v '^@' $(TAJMAHAL_NV12_UV_TILED_UNCOMP_SRC) > $(BUILD_DIR)/expected_tile_plane1.memh; \
			$(OTF_CASE_TOOL) gen-stream --format nv12 --expected-y $(TAJMAHAL_NV12_Y_LINEAR_SRC) --expected-uv $(TAJMAHAL_NV12_UV_LINEAR_SRC) --width 4096 --stored-y-height 640 --stored-uv-height 320 --nv12-uv-phase even --out $(BUILD_DIR)/input_otf_stream.txt; \
			;; \
		tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016) \
			grep -v '^@' $(K_OUTDOOR61_G016_Y_TILED_UNCOMP_SRC) > $(BUILD_DIR)/expected_tile_plane0.memh; \
			grep -v '^@' $(K_OUTDOOR61_G016_UV_TILED_UNCOMP_SRC) > $(BUILD_DIR)/expected_tile_plane1.memh; \
			$(OTF_CASE_TOOL) gen-stream --format p010 --expected-y $(K_OUTDOOR61_G016_Y_LINEAR_SRC) --expected-uv $(K_OUTDOOR61_G016_UV_LINEAR_SRC) --width 4096 --stored-y-height 608 --stored-uv-height 304 --out $(BUILD_DIR)/input_otf_stream.txt; \
			;; \
		*) \
			echo "Unsupported TOP=$(TOP) for encoder wrapper TajMahal prepare"; \
			exit 1; \
			;; \
	esac

enc_wrapper_tajmahal_4096x600_rgba8888_comp:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" comp

enc_wrapper_tajmahal_4096x600_rgba8888_run:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" run

enc_wrapper_tajmahal_4096x600_rgba8888_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" all

enc_wrapper_tajmahal_4096x600_rgba8888_fake_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 all

enc_wrapper_tajmahal_4096x600_rgba8888_nonfake_all:
	$(MAKE) enc_wrapper_tajmahal_4096x600_rgba8888_all

enc_wrapper_tajmahal_4096x600_rgba8888_verdi:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" verdi

enc_wrapper_tajmahal_4096x600_rgba1010102_comp:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" comp

enc_wrapper_tajmahal_4096x600_rgba1010102_run:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" run

enc_wrapper_tajmahal_4096x600_rgba1010102_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" all

enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 all

enc_wrapper_tajmahal_4096x600_rgba1010102_nonfake_all:
	$(MAKE) enc_wrapper_tajmahal_4096x600_rgba1010102_all

enc_wrapper_tajmahal_4096x600_rgba1010102_verdi:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" verdi

enc_wrapper_tajmahal_4096x600_nv12_comp:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" comp

enc_wrapper_tajmahal_4096x600_nv12_run:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" run

enc_wrapper_tajmahal_4096x600_nv12_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" all

enc_wrapper_tajmahal_4096x600_nv12_fake_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 all

enc_wrapper_tajmahal_4096x600_nv12_nonfake_all:
	$(MAKE) enc_wrapper_tajmahal_4096x600_nv12_all

enc_wrapper_tajmahal_4096x600_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" verdi

enc_wrapper_k_outdoor61_4096x600_g016_comp:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" comp

enc_wrapper_k_outdoor61_4096x600_g016_run:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" run

enc_wrapper_k_outdoor61_4096x600_g016_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" all

enc_wrapper_k_outdoor61_4096x600_g016_fake_all:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 enc_wrapper_tajmahal_cases_prepare
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 all

enc_wrapper_k_outdoor61_4096x600_g016_nonfake_all:
	$(MAKE) enc_wrapper_k_outdoor61_4096x600_g016_all

enc_wrapper_k_outdoor61_4096x600_g016_verdi:
	$(MAKE) TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 RUN_ARGS="+tb_non_fake_mode $(RUN_ARGS)" verdi

encdec_wrapper_tajmahal_4096x600_nv12_prepare:
	@mkdir -p build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12
	grep -v '^@' $(TAJMAHAL_NV12_META_Y_SRC) > build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/input_meta_plane0.txt
	grep -v '^@' $(TAJMAHAL_NV12_META_UV_SRC) > build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/input_meta_plane1.txt
	grep -v '^@' $(TAJMAHAL_NV12_Y_LINEAR_SRC) > build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/golden_nv12_y_linear.memh
	grep -v '^@' $(TAJMAHAL_NV12_UV_LINEAR_SRC) > build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/golden_nv12_uv_linear.memh
	$(OTF_CASE_TOOL) gen-stream --format nv12 --expected-y $(TAJMAHAL_NV12_Y_LINEAR_SRC) --expected-uv $(TAJMAHAL_NV12_UV_LINEAR_SRC) --width 4096 --stored-y-height 640 --stored-uv-height 320 --nv12-uv-phase even --out build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/input_otf_stream.txt

encdec_wrapper_tajmahal_4096x600_nv12_comp:
	$(MAKE) TOP=tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 comp

encdec_wrapper_tajmahal_4096x600_nv12_run: encdec_wrapper_tajmahal_4096x600_nv12_prepare
	$(MAKE) TOP=tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 run

compare_encdec_wrapper_tajmahal_4096x600_nv12_otf:
	$(OTF_CASE_TOOL) compare \
		--format nv12 \
		--expected-y build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/golden_nv12_y_linear.memh \
		--expected-uv build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/golden_nv12_uv_linear.memh \
		--actual build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/actual_otf_stream.txt \
		--width 4096 \
		--active-height 600 \
		--stored-y-height 640 \
		--stored-uv-height 320 \
		--out-dir build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/compare

encdec_wrapper_tajmahal_4096x600_nv12_all:
	$(MAKE) TOP=tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 encdec_wrapper_tajmahal_4096x600_nv12_prepare
	$(MAKE) TOP=tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 all
	$(MAKE) compare_encdec_wrapper_tajmahal_4096x600_nv12_otf

encdec_wrapper_tajmahal_4096x600_nv12_verdi:
	$(MAKE) TOP=tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12 verdi

clean:
	rm -rf $(BUILD_ROOT) csrc simv* *.daidir DVEfiles novas* verdiLog ucli.key *.vpd *.vcd *.fsdb
