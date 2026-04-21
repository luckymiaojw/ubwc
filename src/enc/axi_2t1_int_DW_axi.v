//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-11  08:57:08
// Module Name       : axi_2t1_int_DW_axi.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps


module axi_2t1_int_DW_axi
    #(
        parameter   AXI_AW          = 64    ,
        parameter   AXI_DW          = 256   ,
        parameter   AXI_LENW        = 256   ,
        parameter   AXI_IDW         = 6
    )(
        input   wire                                aclk                    ,
        input   wire                                aresetn                 ,

        // M1 AW Channel
        input   wire    [AXI_IDW    -1:0]           awid_m1                 ,
        input   wire    [AXI_AW     -1:0]           awaddr_m1               ,
        input   wire    [AXI_LENW   -1:0]           awlen_m1                ,
        input   wire    [3          -1:0]           awsize_m1               ,
        input   wire    [2          -1:0]           awburst_m1              ,
        input   wire    [2          -1:0]           awlock_m1               ,
        input   wire    [4          -1:0]           awcache_m1              ,
        input   wire    [3          -1:0]           awprot_m1               ,
        input   wire                                awvalid_m1              ,
        output  wire                                awready_m1              ,

        // M1 W Channel
        input   wire    [AXI_IDW    -1:0]           wid_m1                  ,
        input   wire    [AXI_DW     -1:0]           wdata_m1                ,
        input   wire    [AXI_DW/8   -1:0]           wstrb_m1                ,
        input   wire                                wlast_m1                ,
        input   wire                                wvalid_m1               ,
        output  wire                                wready_m1               ,

        // M1 B Channel
        output  wire    [AXI_IDW    -1:0]           bid_m1                  ,
        output  wire    [2          -1:0]           bresp_m1                ,
        output  wire                                bvalid_m1               ,
        input   wire                                bready_m1               ,

        // M1 AR Channel
        input   wire    [AXI_IDW    -1:0]           arid_m1                 ,
        input   wire    [AXI_AW     -1:0]           araddr_m1               ,
        input   wire    [AXI_LENW   -1:0]           arlen_m1                ,
        input   wire    [3          -1:0]           arsize_m1               ,
        input   wire    [2          -1:0]           arburst_m1              ,
        input   wire    [2          -1:0]           arlock_m1               ,
        input   wire    [4          -1:0]           arcache_m1              ,
        input   wire    [3          -1:0]           arprot_m1               ,
        input   wire                                arvalid_m1              ,
        output  wire                                arready_m1              ,

        // M1 R Channel
        output  wire    [AXI_IDW    -1:0]           rid_m1                  ,
        output  wire    [AXI_DW     -1:0]           rdata_m1                ,
        output  wire    [2          -1:0]           rresp_m1                ,
        output  wire                                rvalid_m1               ,
        output  wire                                rlast_m1                ,
        input   wire                                rready_m1               ,

        // M2 AW Channel
        input   wire    [AXI_IDW    -1:0]           awid_m2                 ,
        input   wire    [AXI_AW     -1:0]           awaddr_m2               ,
        input   wire    [AXI_LENW   -1:0]           awlen_m2                ,
        input   wire    [3          -1:0]           awsize_m2               ,
        input   wire    [2          -1:0]           awburst_m2              ,
        input   wire    [2          -1:0]           awlock_m2               ,
        input   wire    [4          -1:0]           awcache_m2              ,
        input   wire    [3          -1:0]           awprot_m2               ,
        input   wire                                awvalid_m2              ,
        output  wire                                awready_m2              ,

        // M2 W Channel
        input   wire    [AXI_IDW    -1:0]           wid_m2                  ,
        input   wire    [AXI_DW     -1:0]           wdata_m2                ,
        input   wire    [AXI_DW/8   -1:0]           wstrb_m2                ,
        input   wire                                wlast_m2                ,
        input   wire                                wvalid_m2               ,
        output  wire                                wready_m2               ,

        // M2 B Channel
        output  wire    [AXI_IDW    -1:0]           bid_m2                  ,
        output  wire    [2          -1:0]           bresp_m2                ,
        output  wire                                bvalid_m2               ,
        input   wire                                bready_m2               ,

        // M2 AR Channel
        input   wire    [AXI_IDW    -1:0]           arid_m2                 ,
        input   wire    [AXI_AW     -1:0]           araddr_m2               ,
        input   wire    [AXI_LENW   -1:0]           arlen_m2                ,
        input   wire    [3          -1:0]           arsize_m2               ,
        input   wire    [2          -1:0]           arburst_m2              ,
        input   wire    [2          -1:0]           arlock_m2               ,
        input   wire    [4          -1:0]           arcache_m2              ,
        input   wire    [3          -1:0]           arprot_m2               ,
        input   wire                                arvalid_m2              ,
        output  wire                                arready_m2              ,

        // M2 R Channel
        output  wire    [AXI_IDW    -1:0]           rid_m2                  ,
        output  wire    [AXI_DW     -1:0]           rdata_m2                ,
        output  wire    [2          -1:0]           rresp_m2                ,
        output  wire                                rvalid_m2               ,
        output  wire                                rlast_m2                ,
        input   wire                                rready_m2               ,

        // S1 Channels
        output  wire    [AXI_IDW      :0]           awid_s1                 ,
        output  wire    [AXI_AW     -1:0]           awaddr_s1               ,
        output  wire    [AXI_LENW   -1:0]           awlen_s1                ,
        output  wire    [3          -1:0]           awsize_s1               ,
        output  wire    [2          -1:0]           awburst_s1              ,
        output  wire    [2          -1:0]           awlock_s1               ,
        output  wire    [4          -1:0]           awcache_s1              ,
        output  wire    [3          -1:0]           awprot_s1               ,
        output  wire                                awvalid_s1              ,
        input   wire                                awready_s1              ,

        output  wire    [AXI_IDW      :0]           wid_s1                  ,
        output  wire    [AXI_DW     -1:0]           wdata_s1                ,
        output  wire    [AXI_DW/8   -1:0]           wstrb_s1                ,
        output  wire                                wlast_s1                ,
        output  wire                                wvalid_s1               ,
        input   wire                                wready_s1               ,

        input   wire    [AXI_IDW      :0]           bid_s1                  ,
        input   wire    [2          -1:0]           bresp_s1                ,
        input   wire                                bvalid_s1               ,
        output  wire                                bready_s1               ,

        output  wire    [AXI_IDW      :0]           arid_s1                 ,
        output  wire    [AXI_AW     -1:0]           araddr_s1               ,
        output  wire    [AXI_LENW   -1:0]           arlen_s1                ,
        output  wire    [3          -1:0]           arsize_s1               ,
        output  wire    [2          -1:0]           arburst_s1              ,
        output  wire    [2          -1:0]           arlock_s1               ,
        output  wire    [4          -1:0]           arcache_s1              ,
        output  wire    [3          -1:0]           arprot_s1               ,
        output  wire                                arvalid_s1              ,
        input   wire                                arready_s1              ,

        input   wire    [AXI_IDW      :0]           rid_s1                  ,
        input   wire    [AXI_DW     -1:0]           rdata_s1                ,
        input   wire    [2          -1:0]           rresp_s1                ,
        input   wire                                rvalid_s1               ,
        input   wire                                rlast_s1                ,
        output  wire                                rready_s1               ,

        // DBG S0 Channels
        output  wire    [AXI_IDW      :0]           dbg_awid_s0             ,
        output  wire    [AXI_AW     -1:0]           dbg_awaddr_s0           ,
        output  wire    [AXI_LENW   -1:0]           dbg_awlen_s0            ,
        output  wire    [3          -1:0]           dbg_awsize_s0           ,
        output  wire    [2          -1:0]           dbg_awburst_s0          ,
        output  wire    [2          -1:0]           dbg_awlock_s0           ,
        output  wire    [4          -1:0]           dbg_awcache_s0          ,
        output  wire    [3          -1:0]           dbg_awprot_s0           ,
        output  wire                                dbg_awvalid_s0          ,
        output  wire                                dbg_awready_s0          ,

        output  wire    [AXI_IDW      :0]           dbg_wid_s0              ,
        output  wire    [AXI_DW     -1:0]           dbg_wdata_s0            ,
        output  wire    [AXI_DW/8   -1:0]           dbg_wstrb_s0            ,
        output  wire                                dbg_wlast_s0            ,
        output  wire                                dbg_wvalid_s0           ,
        output  wire                                dbg_wready_s0           ,

        output  wire    [AXI_IDW      :0]           dbg_bid_s0              ,
        output  wire    [2          -1:0]           dbg_bresp_s0            ,
        output  wire                                dbg_bvalid_s0           ,
        output  wire                                dbg_bready_s0           ,

        output  wire    [AXI_IDW      :0]           dbg_arid_s0             ,
        output  wire    [AXI_AW     -1:0]           dbg_araddr_s0           ,
        output  wire    [AXI_LENW   -1:0]           dbg_arlen_s0            ,
        output  wire    [3          -1:0]           dbg_arsize_s0           ,
        output  wire    [2          -1:0]           dbg_arburst_s0          ,
        output  wire    [2          -1:0]           dbg_arlock_s0           ,
        output  wire    [4          -1:0]           dbg_arcache_s0          ,
        output  wire    [3          -1:0]           dbg_arprot_s0           ,
        output  wire                                dbg_arvalid_s0          ,
        output  wire                                dbg_arready_s0          ,

        output  wire    [AXI_IDW      :0]           dbg_rid_s0              ,
        output  wire    [AXI_DW     -1:0]           dbg_rdata_s0            ,
        output  wire    [2          -1:0]           dbg_rresp_s0            ,
        output  wire                                dbg_rvalid_s0           ,
        output  wire                                dbg_rlast_s0            ,
        output  wire                                dbg_rready_s0
    );

    localparam integer WR_CMD_FIFO_DEPTH = 32;
    localparam integer WR_CMD_FIFO_PTR_W = $clog2(WR_CMD_FIFO_DEPTH);

    reg                         wr_cmd_src_fifo [0:WR_CMD_FIFO_DEPTH-1];
    reg [WR_CMD_FIFO_PTR_W-1:0] wr_cmd_wr_ptr;
    reg [WR_CMD_FIFO_PTR_W-1:0] wr_cmd_rd_ptr;
    reg [WR_CMD_FIFO_PTR_W  :0] wr_cmd_count;

    // =========================================================================
    // 1. 写地址通道 (AW Channel) - 严格优先级 M1 > M2
    //    关键点：W 通道必须严格跟随 AW 实际发往 slave 的顺序
    // =========================================================================
    wire wr_cmd_fifo_full  = (wr_cmd_count == WR_CMD_FIFO_DEPTH);
    wire wr_cmd_fifo_valid = (wr_cmd_count != 0);
    wire wr_cmd_src_m2     = wr_cmd_src_fifo[wr_cmd_rd_ptr];

    wire aw_gnt_m1 = awvalid_m1;
    wire aw_gnt_m2 = awvalid_m2 && !awvalid_m1;
    wire aw_fire_m1;
    wire aw_fire_m2;

    assign awvalid_s1 = !wr_cmd_fifo_full &&
                        (aw_gnt_m1 ? awvalid_m1 : (aw_gnt_m2 ? awvalid_m2 : 1'b0));
    assign awready_m1 = (!wr_cmd_fifo_full && aw_gnt_m1) ? awready_s1 : 1'b0;
    assign awready_m2 = (!wr_cmd_fifo_full && aw_gnt_m2) ? awready_s1 : 1'b0;

    assign aw_fire_m1 = awvalid_m1 && awready_m1;
    assign aw_fire_m2 = awvalid_m2 && awready_m2;

    // 拼接ID: M1最高位补0, M2最高位补1
    assign awid_s1    = aw_gnt_m1 ? {1'b0, awid_m1}    : {1'b1, awid_m2};
    assign awaddr_s1  = aw_gnt_m1 ? awaddr_m1  : awaddr_m2;
    assign awlen_s1   = aw_gnt_m1 ? awlen_m1   : awlen_m2;
    assign awsize_s1  = aw_gnt_m1 ? awsize_m1  : awsize_m2;
    assign awburst_s1 = aw_gnt_m1 ? awburst_m1 : awburst_m2;
    assign awlock_s1  = aw_gnt_m1 ? awlock_m1  : awlock_m2;
    assign awcache_s1 = aw_gnt_m1 ? awcache_m1 : awcache_m2;
    assign awprot_s1  = aw_gnt_m1 ? awprot_m1  : awprot_m2;

    // =========================================================================
    // 2. 写数据通道 (W Channel) - 严格跟随 AW 已接收顺序
    // =========================================================================
    wire w_gnt_m1 = wr_cmd_fifo_valid && !wr_cmd_src_m2;
    wire w_gnt_m2 = wr_cmd_fifo_valid &&  wr_cmd_src_m2;
    wire w_fire_m1;
    wire w_fire_m2;

    assign wvalid_s1 = w_gnt_m1 ? wvalid_m1 : (w_gnt_m2 ? wvalid_m2 : 1'b0);
    assign wready_m1 = w_gnt_m1 ? wready_s1 : 1'b0;
    assign wready_m2 = w_gnt_m2 ? wready_s1 : 1'b0;

    assign wid_s1    = w_gnt_m1 ? {1'b0, wid_m1}   : {1'b1, wid_m2};
    assign wdata_s1  = w_gnt_m1 ? wdata_m1 : wdata_m2;
    assign wstrb_s1  = w_gnt_m1 ? wstrb_m1 : wstrb_m2;
    assign wlast_s1  = w_gnt_m1 ? wlast_m1 : wlast_m2;

    assign w_fire_m1 = w_gnt_m1 && wvalid_m1 && wready_s1;
    assign w_fire_m2 = w_gnt_m2 && wvalid_m2 && wready_s1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_cmd_wr_ptr <= {WR_CMD_FIFO_PTR_W{1'b0}};
            wr_cmd_rd_ptr <= {WR_CMD_FIFO_PTR_W{1'b0}};
            wr_cmd_count  <= {(WR_CMD_FIFO_PTR_W+1){1'b0}};
        end else begin
            if (aw_fire_m1) begin
                wr_cmd_src_fifo[wr_cmd_wr_ptr] <= 1'b0;
            end else if (aw_fire_m2) begin
                wr_cmd_src_fifo[wr_cmd_wr_ptr] <= 1'b1;
            end

            if (aw_fire_m1 || aw_fire_m2) begin
                if (wr_cmd_wr_ptr == (WR_CMD_FIFO_DEPTH - 1))
                    wr_cmd_wr_ptr <= {WR_CMD_FIFO_PTR_W{1'b0}};
                else
                    wr_cmd_wr_ptr <= wr_cmd_wr_ptr + {{(WR_CMD_FIFO_PTR_W-1){1'b0}}, 1'b1};
            end

            if ((w_fire_m1 && wlast_m1) || (w_fire_m2 && wlast_m2)) begin
                if (wr_cmd_rd_ptr == (WR_CMD_FIFO_DEPTH - 1))
                    wr_cmd_rd_ptr <= {WR_CMD_FIFO_PTR_W{1'b0}};
                else
                    wr_cmd_rd_ptr <= wr_cmd_rd_ptr + {{(WR_CMD_FIFO_PTR_W-1){1'b0}}, 1'b1};
            end

            case ({(aw_fire_m1 || aw_fire_m2), ((w_fire_m1 && wlast_m1) || (w_fire_m2 && wlast_m2))})
                2'b10: wr_cmd_count <= wr_cmd_count + {{WR_CMD_FIFO_PTR_W{1'b0}}, 1'b1};
                2'b01: wr_cmd_count <= wr_cmd_count - {{WR_CMD_FIFO_PTR_W{1'b0}}, 1'b1};
                default: wr_cmd_count <= wr_cmd_count;
            endcase
        end
    end

    // =========================================================================
    // 3. 写响应通道 (B Channel) - 基于 ID 最高位路由
    // =========================================================================
    wire b_to_m1 = (bid_s1[AXI_IDW] == 1'b0);
    wire b_to_m2 = (bid_s1[AXI_IDW] == 1'b1);

    assign bvalid_m1 = bvalid_s1 && b_to_m1;
    assign bvalid_m2 = bvalid_s1 && b_to_m2;
    
    // 如果收到异常 ID，默认拉高 ready 防止总线死锁
    assign bready_s1 = b_to_m1 ? bready_m1 : (b_to_m2 ? bready_m2 : 1'b1);

    assign bid_m1    = bid_s1[AXI_IDW-1:0];
    assign bid_m2    = bid_s1[AXI_IDW-1:0];
    assign bresp_m1  = bresp_s1;
    assign bresp_m2  = bresp_s1;

    // =========================================================================
    // 4. 读地址通道 (AR Channel) - 严格优先级 M1 > M2
    // =========================================================================
    wire ar_gnt_m1 = arvalid_m1;
    wire ar_gnt_m2 = arvalid_m2 && !arvalid_m1;

    assign arvalid_s1 = ar_gnt_m1 ? arvalid_m1 : (ar_gnt_m2 ? arvalid_m2 : 1'b0);
    assign arready_m1 = ar_gnt_m1 ? arready_s1 : 1'b0;
    assign arready_m2 = ar_gnt_m2 ? arready_s1 : 1'b0;

    assign arid_s1    = ar_gnt_m1 ? {1'b0, arid_m1}    : {1'b1, arid_m2};
    assign araddr_s1  = ar_gnt_m1 ? araddr_m1  : araddr_m2;
    assign arlen_s1   = ar_gnt_m1 ? arlen_m1   : arlen_m2;
    assign arsize_s1  = ar_gnt_m1 ? arsize_m1  : arsize_m2;
    assign arburst_s1 = ar_gnt_m1 ? arburst_m1 : arburst_m2;
    assign arlock_s1  = ar_gnt_m1 ? arlock_m1  : arlock_m2;
    assign arcache_s1 = ar_gnt_m1 ? arcache_m1 : arcache_m2;
    assign arprot_s1  = ar_gnt_m1 ? arprot_m1  : arprot_m2;

    // =========================================================================
    // 5. 读数据通道 (R Channel) - 基于 ID 最高位路由
    // =========================================================================
    wire r_to_m1 = (rid_s1[AXI_IDW] == 1'b0);
    wire r_to_m2 = (rid_s1[AXI_IDW] == 1'b1);

    assign rvalid_m1 = rvalid_s1 && r_to_m1;
    assign rvalid_m2 = rvalid_s1 && r_to_m2;
    
    assign rready_s1 = r_to_m1 ? rready_m1 : (r_to_m2 ? rready_m2 : 1'b1);

    assign rid_m1    = rid_s1[AXI_IDW-1:0];
    assign rid_m2    = rid_s1[AXI_IDW-1:0];
    assign rdata_m1  = rdata_s1;
    assign rdata_m2  = rdata_s1;
    assign rresp_m1  = rresp_s1;
    assign rresp_m2  = rresp_s1;
    assign rlast_m1  = rlast_s1;
    assign rlast_m2  = rlast_s1;

    // =========================================================================
    // 6. Debug 端口处理 (dbg_s0)
    // =========================================================================
    assign dbg_awid_s0    = 'd0;
    assign dbg_awaddr_s0  = 'd0;
    assign dbg_awlen_s0   = 'd0;
    assign dbg_awsize_s0  = 'd0;
    assign dbg_awburst_s0 = 'd0;
    assign dbg_awlock_s0  = 'd0;
    assign dbg_awcache_s0 = 'd0;
    assign dbg_awprot_s0  = 'd0;
    assign dbg_awvalid_s0 = 1'b0;
    assign dbg_awready_s0 = 1'b0;
    
    assign dbg_wid_s0     = 'd0;
    assign dbg_wdata_s0   = 'd0;
    assign dbg_wstrb_s0   = 'd0;
    assign dbg_wlast_s0   = 1'b0;
    assign dbg_wvalid_s0  = 1'b0;
    assign dbg_wready_s0  = 1'b0;
    
    assign dbg_bid_s0     = 'd0;
    assign dbg_bresp_s0   = 'd0;
    assign dbg_bvalid_s0  = 1'b0;
    assign dbg_bready_s0  = 1'b0;
    
    assign dbg_arid_s0    = 'd0;
    assign dbg_araddr_s0  = 'd0;
    assign dbg_arlen_s0   = 'd0;
    assign dbg_arsize_s0  = 'd0;
    assign dbg_arburst_s0 = 'd0;
    assign dbg_arlock_s0  = 'd0;
    assign dbg_arcache_s0 = 'd0;
    assign dbg_arprot_s0  = 'd0;
    assign dbg_arvalid_s0 = 1'b0;
    assign dbg_arready_s0 = 1'b0;
    
    assign dbg_rid_s0     = 'd0;
    assign dbg_rdata_s0   = 'd0;
    assign dbg_rresp_s0   = 'd0;
    assign dbg_rvalid_s0  = 1'b0;
    assign dbg_rlast_s0   = 1'b0;
    assign dbg_rready_s0  = 1'b0;

endmodule
