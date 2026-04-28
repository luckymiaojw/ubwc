//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_wrapper_top.v
// Description       : Thin integration shell that instantiates
//                     ubwc_enc_wrapper_top and ubwc_dec_wrapper_top.
//                     The two sub-block interfaces are exposed separately
//                     with enc_/dec_ prefixes and are not internally tied.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_wrapper_top #(
    parameter ENC_SB_WIDTH           = 1,
    parameter ENC_APB_AW             = 16,
    parameter ENC_APB_DW             = 32,
    parameter ENC_APB_BLK_NREG       = 64,
    parameter ENC_AXI_AW             = 64,
    parameter ENC_AXI_DW             = 64,
    parameter ENC_AXI_LENW           = 8,
    parameter ENC_AXI_IDW            = 5,
    parameter ENC_COM_BUF_AW         = 16,
    parameter ENC_COM_BUF_DW         = 128,
    parameter DEC_SB_WIDTH           = 1,
    parameter DEC_APB_AW             = 16,
    parameter DEC_APB_DW             = 32,
    parameter DEC_AXI_AW             = 64,
    parameter DEC_AXI_DW             = 64,
    parameter DEC_AXI_IDW            = 5,
    parameter DEC_AXI_LENW           = 8,
    parameter DEC_COM_BUF_AW         = 13,
    parameter DEC_COM_BUF_DW         = 128,
    parameter DEC_FORCE_FULL_PAYLOAD = 0
) (
    // ---------------------------------------------------------------------
    // Encoder APB slave interface
    // ---------------------------------------------------------------------
    input  wire                             enc_PCLK,
    input  wire                             enc_PRESETn,
    input  wire                             enc_PSEL,
    input  wire                             enc_PENABLE,
    input  wire [ENC_APB_AW-1:0]            enc_PADDR,
    input  wire                             enc_PWRITE,
    input  wire [ENC_APB_DW-1:0]            enc_PWDATA,
    output wire                             enc_PREADY,
    output wire                             enc_PSLVERR,
    output wire [ENC_APB_DW-1:0]            enc_PRDATA,

    // ---------------------------------------------------------------------
    // Encoder clock/reset
    // ---------------------------------------------------------------------
    input  wire                             enc_i_clk,
    input  wire                             enc_i_otf_clk,
    input  wire                             enc_i_rstn,

    // ---------------------------------------------------------------------
    // Encoder OTF input
    // ---------------------------------------------------------------------
    input  wire                             enc_i_otf_vsync,
    input  wire                             enc_i_otf_hsync,
    input  wire                             enc_i_otf_de,
    input  wire [127:0]                     enc_i_otf_data,
    input  wire [3:0]                       enc_i_otf_fcnt,
    input  wire [11:0]                      enc_i_otf_lcnt,
    output wire                             enc_o_otf_ready,

    // ---------------------------------------------------------------------
    // Encoder SRAM bank0
    // ---------------------------------------------------------------------
    output wire                             enc_o_bank0_en,
    output wire                             enc_o_bank0_wen,
    output wire [ENC_COM_BUF_AW-1:0]        enc_o_bank0_addr,
    output wire [ENC_COM_BUF_DW-1:0]        enc_o_bank0_din,
    input  wire [ENC_COM_BUF_DW-1:0]        enc_i_bank0_dout,
    input  wire                             enc_i_bank0_dout_vld,

    // ---------------------------------------------------------------------
    // Encoder SRAM bank1
    // ---------------------------------------------------------------------
    output wire                             enc_o_bank1_en,
    output wire                             enc_o_bank1_wen,
    output wire [ENC_COM_BUF_AW-1:0]        enc_o_bank1_addr,
    output wire [ENC_COM_BUF_DW-1:0]        enc_o_bank1_din,
    input  wire [ENC_COM_BUF_DW-1:0]        enc_i_bank1_dout,
    input  wire                             enc_i_bank1_dout_vld,

    // ---------------------------------------------------------------------
    // Encoder AXI write master
    // ---------------------------------------------------------------------
    output wire [ENC_AXI_IDW:0]             enc_o_m_axi_awid,
    output wire [ENC_AXI_AW-1:0]            enc_o_m_axi_awaddr,
    output wire [ENC_AXI_LENW-1:0]          enc_o_m_axi_awlen,
    output wire [2:0]                       enc_o_m_axi_awsize,
    output wire [1:0]                       enc_o_m_axi_awburst,
    output wire [1:0]                       enc_o_m_axi_awlock,
    output wire [3:0]                       enc_o_m_axi_awcache,
    output wire [2:0]                       enc_o_m_axi_awprot,
    output wire                             enc_o_m_axi_awvalid,
    input  wire                             enc_i_m_axi_awready,
    output wire [ENC_AXI_DW-1:0]            enc_o_m_axi_wdata,
    output wire [(ENC_AXI_DW/8)-1:0]        enc_o_m_axi_wstrb,
    output wire                             enc_o_m_axi_wvalid,
    output wire                             enc_o_m_axi_wlast,
    input  wire                             enc_i_m_axi_wready,
    input  wire [ENC_AXI_IDW:0]             enc_i_m_axi_bid,
    input  wire [1:0]                       enc_i_m_axi_bresp,
    input  wire                             enc_i_m_axi_bvalid,
    output wire                             enc_o_m_axi_bready,
    output wire [7:0]                       enc_o_stage_done,
    output wire                             enc_o_frame_done,
    output wire                             enc_o_irq,

    // ---------------------------------------------------------------------
    // Decoder APB slave interface
    // ---------------------------------------------------------------------
    input  wire                             dec_PCLK,
    input  wire                             dec_PRESETn,
    input  wire                             dec_PSEL,
    input  wire                             dec_PENABLE,
    input  wire [DEC_APB_AW-1:0]            dec_PADDR,
    input  wire                             dec_PWRITE,
    input  wire [DEC_APB_DW-1:0]            dec_PWDATA,
    output wire                             dec_PREADY,
    output wire                             dec_PSLVERR,
    output wire [DEC_APB_DW-1:0]            dec_PRDATA,

    // ---------------------------------------------------------------------
    // Decoder OTF output clock/reset
    // ---------------------------------------------------------------------
    input  wire                             dec_i_otf_clk,
    input  wire                             dec_i_otf_rstn,
    output wire                             dec_o_otf_vsync,
    output wire                             dec_o_otf_hsync,
    output wire                             dec_o_otf_de,
    output wire [127:0]                     dec_o_otf_data,
    output wire [3:0]                       dec_o_otf_fcnt,
    output wire [11:0]                      dec_o_otf_lcnt,
    input  wire                             dec_i_otf_ready,

    // ---------------------------------------------------------------------
    // Decoder external OTF SRAM banks
    // ---------------------------------------------------------------------
    output wire                             dec_o_bank0_en,
    output wire                             dec_o_bank0_wen,
    output wire [DEC_COM_BUF_AW-1:0]        dec_o_bank0_addr,
    output wire [DEC_COM_BUF_DW-1:0]        dec_o_bank0_din,
    input  wire [DEC_COM_BUF_DW-1:0]        dec_i_bank0_dout,
    input  wire                             dec_i_bank0_dout_vld,
    output wire                             dec_o_bank1_en,
    output wire                             dec_o_bank1_wen,
    output wire [DEC_COM_BUF_AW-1:0]        dec_o_bank1_addr,
    output wire [DEC_COM_BUF_DW-1:0]        dec_o_bank1_din,
    input  wire [DEC_COM_BUF_DW-1:0]        dec_i_bank1_dout,
    input  wire                             dec_i_bank1_dout_vld,

    // ---------------------------------------------------------------------
    // Decoder AXI read master clock/reset
    // ---------------------------------------------------------------------
    input  wire                             dec_i_axi_clk,
    input  wire                             dec_i_axi_rstn,
    output wire [DEC_AXI_IDW:0]             dec_o_m_axi_arid,
    output wire [DEC_AXI_AW-1:0]            dec_o_m_axi_araddr,
    output wire [DEC_AXI_LENW-1:0]          dec_o_m_axi_arlen,
    output wire [3:0]                       dec_o_m_axi_arsize,
    output wire [1:0]                       dec_o_m_axi_arburst,
    output wire [0:0]                       dec_o_m_axi_arlock,
    output wire [3:0]                       dec_o_m_axi_arcache,
    output wire [2:0]                       dec_o_m_axi_arprot,
    output wire                             dec_o_m_axi_arvalid,
    input  wire                             dec_i_m_axi_arready,
    input  wire [DEC_AXI_IDW:0]             dec_i_m_axi_rid,
    input  wire [DEC_AXI_DW-1:0]            dec_i_m_axi_rdata,
    input  wire                             dec_i_m_axi_rvalid,
    input  wire [1:0]                       dec_i_m_axi_rresp,
    input  wire                             dec_i_m_axi_rlast,
    output wire                             dec_o_m_axi_rready,
    output wire [4:0]                       dec_o_stage_done,
    output wire                             dec_o_frame_done,
    output wire                             dec_o_irq
);

    ubwc_enc_wrapper_top #(
        .SB_WIDTH       (ENC_SB_WIDTH),
        .APB_AW         (ENC_APB_AW),
        .APB_DW         (ENC_APB_DW),
        .APB_BLK_NREG   (ENC_APB_BLK_NREG),
        .AXI_AW         (ENC_AXI_AW),
        .AXI_DW         (ENC_AXI_DW),
        .AXI_LENW       (ENC_AXI_LENW),
        .AXI_IDW        (ENC_AXI_IDW),
        .COM_BUF_AW     (ENC_COM_BUF_AW),
        .COM_BUF_DW     (ENC_COM_BUF_DW)
    ) u_ubwc_enc_wrapper_top (
        .PCLK           (enc_PCLK),
        .PRESETn        (enc_PRESETn),
        .PSEL           (enc_PSEL),
        .PENABLE        (enc_PENABLE),
        .PADDR          (enc_PADDR),
        .PWRITE         (enc_PWRITE),
        .PWDATA         (enc_PWDATA),
        .PREADY         (enc_PREADY),
        .PSLVERR        (enc_PSLVERR),
        .PRDATA         (enc_PRDATA),
        .i_clk          (enc_i_clk),
        .i_otf_clk      (enc_i_otf_clk),
        .i_rstn         (enc_i_rstn),
        .i_otf_vsync    (enc_i_otf_vsync),
        .i_otf_hsync    (enc_i_otf_hsync),
        .i_otf_de       (enc_i_otf_de),
        .i_otf_data     (enc_i_otf_data),
        .i_otf_fcnt     (enc_i_otf_fcnt),
        .i_otf_lcnt     (enc_i_otf_lcnt),
        .o_otf_ready    (enc_o_otf_ready),
        .o_bank0_en     (enc_o_bank0_en),
        .o_bank0_wen    (enc_o_bank0_wen),
        .o_bank0_addr   (enc_o_bank0_addr),
        .o_bank0_din    (enc_o_bank0_din),
        .i_bank0_dout   (enc_i_bank0_dout),
        .i_bank0_dout_vld(enc_i_bank0_dout_vld),
        .o_bank1_en     (enc_o_bank1_en),
        .o_bank1_wen    (enc_o_bank1_wen),
        .o_bank1_addr   (enc_o_bank1_addr),
        .o_bank1_din    (enc_o_bank1_din),
        .i_bank1_dout   (enc_i_bank1_dout),
        .i_bank1_dout_vld(enc_i_bank1_dout_vld),
        .o_m_axi_awid   (enc_o_m_axi_awid),
        .o_m_axi_awaddr (enc_o_m_axi_awaddr),
        .o_m_axi_awlen  (enc_o_m_axi_awlen),
        .o_m_axi_awsize (enc_o_m_axi_awsize),
        .o_m_axi_awburst(enc_o_m_axi_awburst),
        .o_m_axi_awlock (enc_o_m_axi_awlock),
        .o_m_axi_awcache(enc_o_m_axi_awcache),
        .o_m_axi_awprot (enc_o_m_axi_awprot),
        .o_m_axi_awvalid(enc_o_m_axi_awvalid),
        .i_m_axi_awready(enc_i_m_axi_awready),
        .o_m_axi_wdata  (enc_o_m_axi_wdata),
        .o_m_axi_wstrb  (enc_o_m_axi_wstrb),
        .o_m_axi_wvalid (enc_o_m_axi_wvalid),
        .o_m_axi_wlast  (enc_o_m_axi_wlast),
        .i_m_axi_wready (enc_i_m_axi_wready),
        .i_m_axi_bid    (enc_i_m_axi_bid),
        .i_m_axi_bresp  (enc_i_m_axi_bresp),
        .i_m_axi_bvalid (enc_i_m_axi_bvalid),
        .o_m_axi_bready (enc_o_m_axi_bready),
        .o_stage_done   (enc_o_stage_done),
        .o_frame_done   (enc_o_frame_done),
        .o_irq          (enc_o_irq)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW             (DEC_APB_AW),
        .APB_DW             (DEC_APB_DW),
        .AXI_AW             (DEC_AXI_AW),
        .AXI_DW             (DEC_AXI_DW),
        .AXI_IDW            (DEC_AXI_IDW),
        .AXI_LENW           (DEC_AXI_LENW),
        .SB_WIDTH           (DEC_SB_WIDTH),
        .COM_BUF_AW         (DEC_COM_BUF_AW),
        .COM_BUF_DW         (DEC_COM_BUF_DW),
        .FORCE_FULL_PAYLOAD (DEC_FORCE_FULL_PAYLOAD)
    ) u_ubwc_dec_wrapper_top (
        .PCLK               (dec_PCLK),
        .PRESETn            (dec_PRESETn),
        .PSEL               (dec_PSEL),
        .PENABLE            (dec_PENABLE),
        .PADDR              (dec_PADDR),
        .PWRITE             (dec_PWRITE),
        .PWDATA             (dec_PWDATA),
        .PREADY             (dec_PREADY),
        .PSLVERR            (dec_PSLVERR),
        .PRDATA             (dec_PRDATA),
        .i_otf_clk          (dec_i_otf_clk),
        .i_otf_rstn         (dec_i_otf_rstn),
        .o_otf_vsync        (dec_o_otf_vsync),
        .o_otf_hsync        (dec_o_otf_hsync),
        .o_otf_de           (dec_o_otf_de),
        .o_otf_data         (dec_o_otf_data),
        .o_otf_fcnt         (dec_o_otf_fcnt),
        .o_otf_lcnt         (dec_o_otf_lcnt),
        .i_otf_ready        (dec_i_otf_ready),
        .o_bank0_en         (dec_o_bank0_en),
        .o_bank0_wen        (dec_o_bank0_wen),
        .o_bank0_addr       (dec_o_bank0_addr),
        .o_bank0_din        (dec_o_bank0_din),
        .i_bank0_dout       (dec_i_bank0_dout),
        .i_bank0_dout_vld   (dec_i_bank0_dout_vld),
        .o_bank1_en         (dec_o_bank1_en),
        .o_bank1_wen        (dec_o_bank1_wen),
        .o_bank1_addr       (dec_o_bank1_addr),
        .o_bank1_din        (dec_o_bank1_din),
        .i_bank1_dout       (dec_i_bank1_dout),
        .i_bank1_dout_vld   (dec_i_bank1_dout_vld),
        .i_axi_clk          (dec_i_axi_clk),
        .i_axi_rstn         (dec_i_axi_rstn),
        .o_m_axi_arid       (dec_o_m_axi_arid),
        .o_m_axi_araddr     (dec_o_m_axi_araddr),
        .o_m_axi_arlen      (dec_o_m_axi_arlen),
        .o_m_axi_arsize     (dec_o_m_axi_arsize),
        .o_m_axi_arburst    (dec_o_m_axi_arburst),
        .o_m_axi_arlock     (dec_o_m_axi_arlock),
        .o_m_axi_arcache    (dec_o_m_axi_arcache),
        .o_m_axi_arprot     (dec_o_m_axi_arprot),
        .o_m_axi_arvalid    (dec_o_m_axi_arvalid),
        .i_m_axi_arready    (dec_i_m_axi_arready),
        .i_m_axi_rid        (dec_i_m_axi_rid),
        .i_m_axi_rdata      (dec_i_m_axi_rdata),
        .i_m_axi_rvalid     (dec_i_m_axi_rvalid),
        .i_m_axi_rresp      (dec_i_m_axi_rresp),
        .i_m_axi_rlast      (dec_i_m_axi_rlast),
        .o_m_axi_rready     (dec_o_m_axi_rready),
        .o_stage_done       (dec_o_stage_done),
        .o_frame_done       (dec_o_frame_done),
        .o_irq              (dec_o_irq)
    );

endmodule
