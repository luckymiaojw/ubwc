`timescale 1ns/1ps

module tb_ubwc_enc_apb_cfg_commit;

    localparam  [15                     :0]         REG_TILE_CFG0                   = 16'h0008;
    localparam  [15                     :0]         REG_TILE_CFG1                   = 16'h000c;
    localparam  [15                     :0]         REG_OTF_CFG0                    = 16'h0020;
    localparam  [15                     :0]         REG_OTF_CFG1                    = 16'h0024;
    localparam  [15                     :0]         REG_OTF_CFG2                    = 16'h0028;
    localparam  [15                     :0]         REG_OTF_CFG3                    = 16'h002c;
    localparam  [15                     :0]         REG_META_BASE_Y_LO             = 16'h0030;
    localparam  [15                     :0]         REG_META_BASE_Y_HI             = 16'h0034;
    localparam  [15                     :0]         REG_TILE_BASE_Y_LO             = 16'h0038;
    localparam  [15                     :0]         REG_TILE_BASE_Y_HI             = 16'h003c;
    localparam  [15                     :0]         REG_META_BASE_UV_LO            = 16'h0040;
    localparam  [15                     :0]         REG_META_BASE_UV_HI            = 16'h0044;
    localparam  [15                     :0]         REG_TILE_BASE_UV_LO            = 16'h0048;
    localparam  [15                     :0]         REG_TILE_BASE_UV_HI            = 16'h004c;
    localparam  [15                     :0]         REG_META_ACTIVE_SIZE           = 16'h0050;
    localparam  [15                     :0]         REG_META_PITCH                 = 16'h0054;
    localparam  [15                     :0]         REG_STATUS0                    = 16'h0058;
    localparam  [15                     :0]         REG_IRQ_CTRL                   = 16'h0060;

    reg                                             PCLK                            ;
    reg                                             PRESETn                         ;
    reg                                             PSEL                            ;
    reg                                             PENABLE                         ;
    reg         [15                     :0]         PADDR                           ;
    reg                                             PWRITE                          ;
    reg         [31                     :0]         PWDATA                          ;
    reg                                             i_clk                           ;
    reg                                             i_rstn                          ;

    wire        [31                     :0]         PRDATA                          ;
    wire        [15                     :0]         o_otf_cfg_width                 ;
    wire        [15                     :0]         o_otf_cfg_height                ;
    wire        [31                     :0]         o_meta_data_plane_pitch         ;
    wire        [63                     :0]         o_y_base_offset_addr            ;
    wire                                            o_addr_cfg_valid                ;
    wire                                            o_cfg_valid                     ;

    task automatic apb_write;
        input   [15                     :0]         addr                            ;
        input   [31                     :0]         data                            ;
        begin
            @(negedge PCLK);
            PSEL    = 1'b1;
            PENABLE = 1'b1;
            PWRITE  = 1'b1;
            PADDR   = addr;
            PWDATA  = data;
            @(negedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = 16'd0;
            PWDATA  = 32'd0;
        end
    endtask

    task automatic apb_read;
        input   [15                     :0]         addr                            ;
        output  [31                     :0]         data                            ;
        begin
            @(negedge PCLK);
            PSEL    = 1'b1;
            PENABLE = 1'b1;
            PWRITE  = 1'b0;
            PADDR   = addr;
            @(posedge PCLK);
            #1;
            data    = PRDATA;
            @(negedge PCLK);
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PADDR   = 16'd0;
        end
    endtask

    task automatic wait_commit;
        begin
            repeat (8) @(posedge i_clk);
            repeat (4) @(posedge PCLK);
        end
    endtask

    reg         [31                     :0]         read_data                       ;

    initial begin
        PCLK    = 1'b0;
        i_clk   = 1'b0;
        PRESETn = 1'b0;
        i_rstn  = 1'b0;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PADDR   = 16'd0;
        PWRITE  = 1'b0;
        PWDATA  = 32'd0;

        repeat (4) @(posedge PCLK);
        PRESETn = 1'b1;
        i_rstn  = 1'b1;

        apb_write(REG_TILE_CFG0,        32'h0000_0001);
        apb_write(REG_TILE_CFG1,        32'h0020_0001);
        apb_write(REG_OTF_CFG0,         32'h0000_0000);
        apb_write(REG_OTF_CFG1,         32'h0080_0080);
        apb_write(REG_OTF_CFG2,         32'h0004_0010);
        apb_write(REG_OTF_CFG3,         32'h0000_0008);
        apb_write(REG_META_BASE_Y_LO,   32'h0000_3000);
        apb_write(REG_META_BASE_Y_HI,   32'h0000_0000);
        apb_write(REG_TILE_BASE_Y_LO,   32'h0000_1000);
        apb_write(REG_TILE_BASE_Y_HI,   32'h0000_0000);
        apb_write(REG_META_BASE_UV_LO,  32'h0000_0000);
        apb_write(REG_META_BASE_UV_HI,  32'h0000_0000);
        apb_write(REG_TILE_BASE_UV_LO,  32'h0000_0000);
        apb_write(REG_TILE_BASE_UV_HI,  32'h0000_0000);
        apb_write(REG_META_ACTIVE_SIZE, 32'h0080_0080);
        apb_write(REG_META_PITCH,       32'h0000_0040);

        if (o_cfg_valid || (o_otf_cfg_width != 16'd0) ||
            o_addr_cfg_valid)
            $fatal(1, "Working registers changed committed configuration before START");

        apb_write(REG_IRQ_CTRL, 32'h0000_0021);
        wait_commit();

        if (!o_cfg_valid)
            $fatal(1, "Valid configuration was not accepted by START");
        if ((o_otf_cfg_width != 16'd128) || (o_otf_cfg_height != 16'd128))
            $fatal(1, "Committed geometry mismatch");
        if (!o_addr_cfg_valid || (o_y_base_offset_addr != 64'h1000))
            $fatal(1, "Committed address configuration mismatch");

        apb_read(REG_STATUS0, read_data);
        if (!read_data[14])
            $fatal(1, "STATUS0 cfg_valid bit was not set");
        if (!read_data[10] || (read_data[12:11] != 2'b00))
            $fatal(1, "STATUS0 single-address valid/reserved fields mismatch");

        apb_write(REG_OTF_CFG1, 32'h0040_0040);
        apb_write(REG_META_BASE_Y_LO,  32'h0000_b000);
        apb_write(REG_META_BASE_Y_HI,  32'h0000_0000);
        apb_write(REG_TILE_BASE_Y_LO,  32'h0000_9000);
        apb_write(REG_TILE_BASE_Y_HI,  32'h0000_0000);
        apb_write(REG_META_BASE_UV_LO, 32'h0000_d000);
        apb_write(REG_META_BASE_UV_HI, 32'h0000_0000);
        apb_write(REG_TILE_BASE_UV_LO, 32'h0000_c000);
        apb_write(REG_TILE_BASE_UV_HI, 32'h0000_0000);
        repeat (8) @(posedge i_clk);
        if ((o_otf_cfg_width != 16'd128) || (o_otf_cfg_height != 16'd128))
            $fatal(1, "Live configuration changed without START");
        if (!o_addr_cfg_valid || (o_y_base_offset_addr != 64'h1000))
            $fatal(1, "Committed address changed without START");

        apb_write(REG_IRQ_CTRL, 32'h0000_0021);
        wait_commit();
        if ((o_otf_cfg_width != 16'd64) || (o_otf_cfg_height != 16'd64))
            $fatal(1, "Second START did not switch the committed configuration");
        if (!o_addr_cfg_valid || (o_y_base_offset_addr != 64'h9000))
            $fatal(1, "Second START did not switch the committed address");

        apb_write(REG_META_PITCH, 32'h0000_0000);
        apb_write(REG_IRQ_CTRL, 32'h0000_0021);
        wait_commit();
        if (o_cfg_valid)
            $fatal(1, "Invalid configuration was accepted");
        apb_read(REG_STATUS0, read_data);
        if (read_data[14])
            $fatal(1, "STATUS0 cfg_valid did not clear after invalid START");

        apb_write(REG_IRQ_CTRL, 32'h0000_0041);
        apb_read(REG_IRQ_CTRL, read_data);
        if (read_data[6])
            $fatal(1, "IRQ_CTRL[6] must be reserved and read as zero");

        $display("PASS: START only commits configuration; invalid commit blocks cfg_valid");
        $finish;
    end

    always #5 PCLK  = ~PCLK;
    always #2 i_clk = ~i_clk;

    ubwc_enc_apb_reg_blk u_dut
    (
        .PCLK                            ( PCLK                            ),
        .PRESETn                         ( PRESETn                         ),
        .PSEL                            ( PSEL                            ),
        .PENABLE                         ( PENABLE                         ),
        .PADDR                           ( PADDR                           ),
        .PWRITE                          ( PWRITE                          ),
        .PWDATA                          ( PWDATA                          ),
        .PREADY                          (                                 ),
        .PSLVERR                         (                                 ),
        .PRDATA                          ( PRDATA                          ),
        .i_clk                           ( i_clk                           ),
        .i_rstn                          ( i_rstn                          ),
        .o_otf_cfg_width                 ( o_otf_cfg_width                 ),
        .o_otf_cfg_height                ( o_otf_cfg_height                ),
        .o_meta_data_plane_pitch         ( o_meta_data_plane_pitch         ),
        .o_y_base_offset_addr            ( o_y_base_offset_addr            ),
        .o_addr_cfg_valid                ( o_addr_cfg_valid                ),
        .i_addr_cfg_check_valid          ( 1'b0                            ),
        .i_enc_idle                      ( 1'b1                            ),
        .i_enc_error                     ( 1'b0                            ),
        .i_otf_to_tile_busy              ( 1'b0                            ),
        .i_otf_to_tile_overflow          ( 1'b0                            ),
        .i_otf_err_bline                 ( 1'b0                            ),
        .i_otf_err_bframe                ( 1'b0                            ),
        .i_meta_err_0                    ( 1'b0                            ),
        .i_meta_err_1                    ( 1'b0                            ),
        .i_rst_drain_timeout             ( 1'b0                            ),
        .i_frame_done                    ( 1'b0                            ),
        .i_stage_done                    ( 8'd0                            ),
        .i_irq_pending                   ( 1'b0                            ),
        .i_irq_correct_pending           ( 1'b0                            ),
        .i_irq_error_pending             ( 1'b0                            ),
        .i_meta_count0                   ( 32'd0                           ),
        .i_meta_count1                   ( 32'd0                           ),
        .i_tile_addr_count0              ( 32'd0                           ),
        .i_tile_addr_count1              ( 32'd0                           ),
        .i_otf_tile_count0               ( 32'd0                           ),
        .i_otf_tile_count1               ( 32'd0                           ),
        .i_otf_de_count0                 ( 32'd0                           ),
        .i_otf_de_count1                 ( 32'd0                           ),
        .i_otf_line_count0               ( 32'd0                           ),
        .i_otf_line_count1               ( 32'd0                           ),
        .i_tile_axi_w_count0             ( 32'd0                           ),
        .i_tile_axi_w_count1             ( 32'd0                           ),
        .i_meta_axi_w_count0             ( 32'd0                           ),
        .i_meta_axi_w_count1             ( 32'd0                           ),
        .o_cfg_valid                     ( o_cfg_valid                     ),
        .o_irq_enable                    (                                 ),
        .o_irq_clear_pulse               (                                 )
    );

endmodule
