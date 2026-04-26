`timescale 1ns/1ps
`default_nettype none

module tb_ubwc_enc_wrapper_top_monitor #(
    parameter AXI_AW = 64
) (
    input  wire                    meta_data_valid,
    input  wire                    meta_data_ready,
    input  wire [66-1:0]           meta_data,
    input  wire                    meta_addr_valid,
    input  wire                    meta_addr_ready,
    input  wire [AXI_AW-1:0]       meta_addr,
    input  wire [AXI_AW-1:0]       meta_uv_base_offset_addr,

    input  wire                    meta_axi_awvalid,
    input  wire                    meta_axi_awready,
    input  wire [AXI_AW-1:0]       meta_axi_awaddr,
    input  wire                    b_tile_info_vld,
    input  wire                    enc_co_ready,
    input  wire                    otf_tile_last,
    input  wire [4-1:0]            otf_tile_fcnt,
    input  wire                    err_bline,
    input  wire                    err_bframe,

    output wire                    meta_valid,
    output wire                    meta_ready,
    output wire                    meta_last,
    output wire                    meta_sel_y,
    output wire                    meta_sel_uv,

    output wire                    y_meta_valid,
    output wire                    y_meta_last,
    output wire                    y_meta_ready,
    output wire [64-1:0]           y_meta_data,
    output wire [AXI_AW-1:0]       y_meta_addr,

    output wire                    uv_meta_valid,
    output wire                    uv_meta_last,
    output wire                    uv_meta_ready,
    output wire [64-1:0]           uv_meta_data,
    output wire [AXI_AW-1:0]       uv_meta_addr,

    output wire                    meta_aw_fire,
    output wire                    meta_aw_sel_uv,
    output wire [AXI_AW-1:0]       meta_aw_y_addr,
    output wire [AXI_AW-1:0]       meta_aw_uv_addr,
    output wire                    b_co_valid,
    output wire                    b_co_fire,
    output wire                    dbg_otf_tile_last,
    output wire [4-1:0]            dbg_otf_tile_fcnt,
    output wire                    dbg_err_bline,
    output wire                    dbg_err_bframe
);

    assign meta_valid      = meta_data_valid & meta_addr_valid;
    assign meta_ready      = meta_data_ready & meta_addr_ready;
    assign meta_last       = 1'b1;
    assign meta_sel_uv     = (meta_addr >= meta_uv_base_offset_addr) &&
                             (meta_uv_base_offset_addr != {AXI_AW{1'b0}});
    assign meta_sel_y      = ~meta_sel_uv;

    assign y_meta_valid    = meta_valid & meta_sel_y;
    assign y_meta_last     = meta_last;
    assign y_meta_ready    = meta_ready & meta_sel_y;
    assign y_meta_data     = meta_data[0+:64];
    assign y_meta_addr     = meta_sel_y ? meta_addr : {AXI_AW{1'b0}};

    assign uv_meta_valid   = meta_valid & meta_sel_uv;
    assign uv_meta_last    = meta_last;
    assign uv_meta_ready   = meta_ready & meta_sel_uv;
    assign uv_meta_data    = meta_data[0+:64];
    assign uv_meta_addr    = meta_sel_uv ? meta_addr : {AXI_AW{1'b0}};

    assign meta_aw_fire    = meta_axi_awvalid & meta_axi_awready;
    assign meta_aw_sel_uv  = (meta_axi_awaddr >= meta_uv_base_offset_addr) &&
                             (meta_uv_base_offset_addr != {AXI_AW{1'b0}});
    assign meta_aw_y_addr  = meta_aw_sel_uv ? {AXI_AW{1'b0}} : meta_axi_awaddr;
    assign meta_aw_uv_addr = meta_aw_sel_uv ? meta_axi_awaddr : {AXI_AW{1'b0}};
    assign b_co_valid      = b_tile_info_vld;
    assign b_co_fire       = b_tile_info_vld & enc_co_ready;
    assign dbg_otf_tile_last = otf_tile_last;
    assign dbg_otf_tile_fcnt = otf_tile_fcnt;
    assign dbg_err_bline     = err_bline;
    assign dbg_err_bframe    = err_bframe;

endmodule

`default_nettype wire
