`timescale 1ns/1ps

module tb_ubwc_dec_tile_arcmd_gen;

    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 256;
    localparam integer AXI_IDW  = 6;
    localparam integer SB_WIDTH = 1;

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_10_Y   = 5'b01100;
    localparam [AXI_AW-1:0] TEST_BASE_ADDR_RGBA_UV = 64'h0000_0000_8028_5000;
    localparam [AXI_AW-1:0] TEST_BASE_ADDR_Y       = 64'h0000_0000_8000_3000;

    reg                      clk;
    reg                      rst_n;

    reg                      i_cfg_lvl2_bank_swizzle_en;
    reg                      i_cfg_lvl3_bank_swizzle_en;
    reg  [4:0]               i_cfg_highest_bank_bit;
    reg                      i_cfg_bank_spread_en;
    reg                      i_cfg_is_lossy_rgba_2_1_format;
    reg  [11:0]              i_cfg_pitch;

    reg                      i_cfg_ci_input_type;
    reg  [SB_WIDTH-1:0]      i_cfg_ci_sb;
    reg                      i_cfg_ci_lossy;
    reg  [1:0]               i_cfg_ci_alpha_mode;
    reg  [AXI_AW-1:0]        i_cfg_base_addr_rgba_uv;
    reg  [AXI_AW-1:0]        i_cfg_base_addr_y;

    reg  [37:0]              fifo_wdata;
    reg                      fifo_vld;
    wire                     fifo_rdy;
    wire                     dec_meta_valid;
    wire                     dec_meta_ready;
    wire [4:0]               dec_meta_format;
    wire [3:0]               dec_meta_flag;
    wire [2:0]               dec_meta_alen;
    wire                     dec_meta_has_payload;
    wire [11:0]              dec_meta_x;
    wire [9:0]               dec_meta_y;

    wire                     m_axi_arvalid;
    reg                      m_axi_arready;
    wire [AXI_AW-1:0]        m_axi_araddr;
    wire [7:0]               m_axi_arlen;
    wire [2:0]               m_axi_arsize;
    wire [1:0]               m_axi_arburst;
    wire [AXI_IDW-1:0]       m_axi_arid;

    reg                      m_axi_rvalid;
    reg  [AXI_IDW-1:0]       m_axi_rid;
    reg  [AXI_DW-1:0]        m_axi_rdata;
    reg  [1:0]               m_axi_rresp;
    reg                      m_axi_rlast;
    wire                     m_axi_rready;

    wire                     o_ci_valid;
    reg                      i_ci_ready;
    wire                     o_ci_input_type;
    wire [2:0]               o_ci_alen;
    wire [4:0]               o_ci_format;
    wire [3:0]               o_ci_metadata;
    wire                     o_ci_lossy;
    wire [1:0]               o_ci_alpha_mode;
    wire [SB_WIDTH-1:0]      o_ci_sb;
    wire                     o_tile_coord_vld;
    wire [4:0]               o_tile_format;
    wire [11:0]              o_tile_x_coord;
    wire [9:0]               o_tile_y_coord;

    wire                     o_cvi_valid;
    wire [255:0]             o_cvi_data;
    wire                     o_cvi_last;
    reg                      i_cvi_ready;

    integer                  ci_count;
    integer                  ar_count;
    integer                  cvi_count;
    integer                  tile_coord_count;
    reg   [4:0]              last_ci_format;
    reg   [3:0]              last_ci_metadata;
    reg   [2:0]              last_ci_alen;
    reg   [AXI_AW-1:0]       last_ar_addr;
    reg   [7:0]              last_ar_len;
    reg   [AXI_AW-1:0]       ar_addr_hist [0:15];
    reg   [7:0]              ar_len_hist  [0:15];
    reg   [AXI_DW-1:0]       last_cvi_data;
    reg   [4:0]              last_tile_format;
    reg   [11:0]             last_tile_x_coord;
    reg   [9:0]              last_tile_y_coord;

    ubwc_dec_meta_data_decode u_decode_metadata (
        .clk                             (clk),
        .rst_n                           (rst_n),
        .i_cfg_is_lossy_rgba_2_1_format  (i_cfg_is_lossy_rgba_2_1_format),
        .i_meta_valid                    (fifo_vld),
        .o_meta_ready                    (fifo_rdy),
        .i_meta_format                   (fifo_wdata[26:22]),
        .i_meta_data                     (fifo_wdata[34:27]),
        .i_meta_error                    (fifo_wdata[37]),
        .i_meta_eol                      (fifo_wdata[36]),
        .i_meta_last_pass                (fifo_wdata[35]),
        .i_meta_x                        (fifo_wdata[21:10]),
        .i_meta_y                        (fifo_wdata[9:0]),
        .o_dec_valid                     (dec_meta_valid),
        .i_dec_ready                     (dec_meta_ready),
        .o_dec_format                    (dec_meta_format),
        .o_dec_flag                      (dec_meta_flag),
        .o_dec_alen                      (dec_meta_alen),
        .o_dec_has_payload               (dec_meta_has_payload),
        .o_dec_x                         (dec_meta_x),
        .o_dec_y                         (dec_meta_y)
    );

    ubwc_dec_tile_arcmd_gen #(
        .AXI_AW   (AXI_AW),
        .AXI_DW   (AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .SB_WIDTH (SB_WIDTH)
    ) dut (
        .clk                             (clk),
        .rst_n                           (rst_n),
        .i_frame_start                   (1'b0),
        .i_cfg_lvl2_bank_swizzle_en      (i_cfg_lvl2_bank_swizzle_en),
        .i_cfg_lvl3_bank_swizzle_en      (i_cfg_lvl3_bank_swizzle_en),
        .i_cfg_highest_bank_bit          (i_cfg_highest_bank_bit),
        .i_cfg_bank_spread_en            (i_cfg_bank_spread_en),
        .i_cfg_is_lossy_rgba_2_1_format  (i_cfg_is_lossy_rgba_2_1_format),
        .i_cfg_pitch                     (i_cfg_pitch),
        .i_cfg_ci_input_type             (i_cfg_ci_input_type),
        .i_cfg_ci_sb                     (i_cfg_ci_sb),
        .i_cfg_ci_lossy                  (i_cfg_ci_lossy),
        .i_cfg_ci_alpha_mode             (i_cfg_ci_alpha_mode),
        .i_cfg_base_addr_rgba_uv         (i_cfg_base_addr_rgba_uv),
        .i_cfg_base_addr_y               (i_cfg_base_addr_y),
        .dec_meta_valid                  (dec_meta_valid),
        .dec_meta_ready                  (dec_meta_ready),
        .dec_meta_format                 (dec_meta_format),
        .dec_meta_flag                   (dec_meta_flag),
        .dec_meta_alen                   (dec_meta_alen),
        .dec_meta_has_payload            (dec_meta_has_payload),
        .dec_meta_x                      (dec_meta_x),
        .dec_meta_y                      (dec_meta_y),
        .m_axi_arvalid                   (m_axi_arvalid),
        .m_axi_arready                   (m_axi_arready),
        .m_axi_araddr                    (m_axi_araddr),
        .m_axi_arlen                     (m_axi_arlen),
        .m_axi_arsize                    (m_axi_arsize),
        .m_axi_arburst                   (m_axi_arburst),
        .m_axi_arid                      (m_axi_arid),
        .m_axi_rvalid                    (m_axi_rvalid),
        .m_axi_rid                       (m_axi_rid),
        .m_axi_rdata                     (m_axi_rdata),
        .m_axi_rresp                     (m_axi_rresp),
        .m_axi_rlast                     (m_axi_rlast),
        .m_axi_rready                    (m_axi_rready),
        .o_ci_valid                      (o_ci_valid),
        .i_ci_ready                      (i_ci_ready),
        .o_ci_input_type                 (o_ci_input_type),
        .o_ci_alen                       (o_ci_alen),
        .o_ci_format                     (o_ci_format),
        .o_ci_metadata                   (o_ci_metadata),
        .o_ci_lossy                      (o_ci_lossy),
        .o_ci_alpha_mode                 (o_ci_alpha_mode),
        .o_ci_sb                         (o_ci_sb),
        .o_tile_coord_vld                (o_tile_coord_vld),
        .o_tile_format                   (o_tile_format),
        .o_tile_x_coord                  (o_tile_x_coord),
        .o_tile_y_coord                  (o_tile_y_coord),
        .o_cvi_valid                     (o_cvi_valid),
        .o_cvi_data                      (o_cvi_data),
        .o_cvi_last                      (o_cvi_last),
        .i_cvi_ready                     (i_cvi_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic send_meta;
        input [7:0]  meta_byte;
        input [4:0]  meta_format;
        input [11:0] tile_x;
        input [9:0]  tile_y;
        begin
            fifo_wdata <= {1'b0, 1'b0, 1'b0, meta_byte, meta_format, tile_x, tile_y};
            fifo_vld   <= 1'b1;
            while (!fifo_rdy) @(posedge clk);
            @(posedge clk);
            fifo_vld   <= 1'b0;
            fifo_wdata <= 38'd0;
        end
    endtask

    task automatic wait_ci_count;
        input integer target_count;
        integer timeout;
        begin
            timeout = 0;
            while ((ci_count < target_count) && (timeout < 200)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 200) begin
                $fatal(1, "Timeout waiting for CI count %0d", target_count);
            end
        end
    endtask

    task automatic wait_ar_count;
        input integer target_count;
        integer timeout;
        begin
            timeout = 0;
            while ((ar_count < target_count) && (timeout < 200)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 200) begin
                $fatal(1, "Timeout waiting for AR count %0d", target_count);
            end
        end
    endtask

    task automatic wait_cvi_count;
        input integer target_count;
        integer timeout;
        begin
            timeout = 0;
            while ((cvi_count < target_count) && (timeout < 200)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 200) begin
                $fatal(1, "Timeout waiting for CVI beat count %0d", target_count);
            end
        end
    endtask

    task automatic wait_tile_coord_count;
        input integer target_count;
        integer timeout;
        begin
            timeout = 0;
            while ((tile_coord_count < target_count) && (timeout < 200)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 200) begin
                $fatal(1, "Timeout waiting for tile coord count %0d", target_count);
            end
        end
    endtask

    task automatic send_r_burst;
        input [AXI_DW-1:0] start_data;
        input integer      beats;
        integer            beat_idx;
        reg   [AXI_DW-1:0] exp_data;
        begin
            for (beat_idx = 0; beat_idx < beats; beat_idx = beat_idx + 1) begin
                exp_data   = start_data + beat_idx;
                m_axi_rdata  <= exp_data;
                m_axi_rvalid <= 1'b1;
                m_axi_rlast  <= (beat_idx == beats - 1);
                #1;
                if (!o_cvi_valid || !m_axi_rready || (o_cvi_data != exp_data)) begin
                    $fatal(1, "CVI passthrough mismatch on beat %0d. exp=0x%0h got=0x%0h valid=%0b ready=%0b",
                           beat_idx, exp_data, o_cvi_data, o_cvi_valid, m_axi_rready);
                end
                @(posedge clk);
            end
            m_axi_rvalid <= 1'b0;
            m_axi_rlast  <= 1'b0;
            m_axi_rdata  <= '0;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ci_count <= 0;
            ar_count <= 0;
            cvi_count <= 0;
            tile_coord_count <= 0;
            last_ci_format <= 5'd0;
            last_ci_metadata <= 4'd0;
            last_ci_alen <= 3'd0;
            last_ar_addr <= {AXI_AW{1'b0}};
            last_ar_len <= 8'd0;
            last_cvi_data <= {AXI_DW{1'b0}};
            last_tile_format <= 5'd0;
            last_tile_x_coord <= 12'd0;
            last_tile_y_coord <= 10'd0;
        end else begin
            if (o_ci_valid && i_ci_ready) begin
                ci_count <= ci_count + 1;
                last_ci_format <= o_ci_format;
                last_ci_metadata <= o_ci_metadata;
                last_ci_alen <= o_ci_alen;
            end
            if (m_axi_arvalid && m_axi_arready) begin
                if (ar_count < 16) begin
                    ar_addr_hist[ar_count] <= m_axi_araddr;
                    ar_len_hist[ar_count] <= m_axi_arlen;
                end
                ar_count <= ar_count + 1;
                last_ar_addr <= m_axi_araddr;
                last_ar_len <= m_axi_arlen;
            end
            if (o_cvi_valid && i_cvi_ready) begin
                cvi_count <= cvi_count + 1;
                last_cvi_data <= o_cvi_data;
            end
            if (o_tile_coord_vld) begin
                tile_coord_count <= tile_coord_count + 1;
                last_tile_format <= o_tile_format;
                last_tile_x_coord <= o_tile_x_coord;
                last_tile_y_coord <= o_tile_y_coord;
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        i_cfg_lvl2_bank_swizzle_en = 1'b1;
        i_cfg_lvl3_bank_swizzle_en = 1'b1;
        i_cfg_highest_bank_bit = 5'd16;
        i_cfg_bank_spread_en = 1'b1;
        i_cfg_is_lossy_rgba_2_1_format = 1'b0;
        // Pitch is configured in 16-byte units here. 16 -> 256 bytes.
        i_cfg_pitch = 12'd16;

        i_cfg_ci_input_type = 1'b1;
        i_cfg_ci_sb = '0;
        i_cfg_ci_lossy = 1'b0;
        i_cfg_ci_alpha_mode = 2'd0;
        i_cfg_base_addr_rgba_uv = TEST_BASE_ADDR_RGBA_UV;
        i_cfg_base_addr_y = TEST_BASE_ADDR_Y;

        fifo_wdata = 38'd0;
        fifo_vld = 1'b0;

        m_axi_arready = 1'b1;
        m_axi_rvalid = 1'b0;
        m_axi_rid = '0;
        m_axi_rdata = '0;
        m_axi_rresp = 2'b00;
        m_axi_rlast = 1'b0;

        i_ci_ready = 1'b1;
        i_cvi_ready = 1'b1;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        if (i_cfg_base_addr_rgba_uv == i_cfg_base_addr_y) begin
            $fatal(1, "TB config error: rgba_uv and y base addresses must differ");
        end

        $display("TB: ubwc_dec_tile_arcmd_gen smoke");

        send_meta(8'h10, META_FMT_NV12_Y, 12'd0, 10'd0);
        wait_ci_count(1);
        wait_ar_count(1);
        wait_tile_coord_count(1);
        if (last_ci_format != META_FMT_NV12_Y || last_ci_metadata != 4'd0 || last_ci_alen != 3'd0) begin
            $fatal(1, "YUV420 CI mismatch. fmt=%0h meta=%0h alen=%0d",
                   last_ci_format, last_ci_metadata, last_ci_alen);
        end
        if ((last_tile_format != META_FMT_NV12_Y) || (last_tile_x_coord != 12'd0) || (last_tile_y_coord != 10'd0)) begin
            $fatal(1, "YUV420 tile header mismatch. fmt=%0h x=%0d y=%0d",
                   last_tile_format, last_tile_x_coord, last_tile_y_coord);
        end
        if (last_ar_addr != TEST_BASE_ADDR_Y || last_ar_len != 8'd0) begin
            $fatal(1, "YUV420 AR mismatch. addr=0x%0h len=%0d", last_ar_addr, last_ar_len);
        end
        send_r_burst(256'h0123_4567_89ab_cdef_fedc_ba98_7654_3210_0011_2233_4455_6677_8899_aabb_ccdd_eeff, 1);
        wait_cvi_count(1);

        i_cfg_is_lossy_rgba_2_1_format = 1'b1;
        send_meta(8'h3e, META_FMT_RGBA8888, 12'd0, 10'd1);
        wait_ci_count(2);
        wait_ar_count(2);
        wait_tile_coord_count(2);
        if (last_ci_format != META_FMT_RGBA8888 || last_ci_metadata != 4'd7 || last_ci_alen != 3'd3) begin
            $fatal(1, "Lossy RGBA CI mismatch. fmt=%0h meta=%0h alen=%0d",
                   last_ci_format, last_ci_metadata, last_ci_alen);
        end
        if ((last_tile_format != META_FMT_RGBA8888) || (last_tile_x_coord != 12'd0) || (last_tile_y_coord != 10'd1)) begin
            $fatal(1, "Lossy RGBA tile header mismatch. fmt=%0h x=%0d y=%0d",
                   last_tile_format, last_tile_x_coord, last_tile_y_coord);
        end
        if (last_ar_addr != (TEST_BASE_ADDR_RGBA_UV + 64'h80) || last_ar_len != 8'd3) begin
            $fatal(1, "Lossy RGBA AR mismatch. addr=0x%0h len=%0d", last_ar_addr, last_ar_len);
        end
        send_r_burst(256'h1000_0000_0000_0000_2000_0000_0000_0000_3000_0000_0000_0000_4000_0000_0000_0000, 4);
        wait_cvi_count(5);

        i_cfg_is_lossy_rgba_2_1_format = 1'b0;
        i_cfg_pitch = 12'd256;
        send_meta(8'h18, META_FMT_RGBA8888, 12'd2, 10'd7);
        wait_ci_count(3);
        wait_ar_count(3);
        wait_tile_coord_count(3);
        if (last_ci_format != META_FMT_RGBA8888 || last_ci_metadata != 4'd4 || last_ci_alen != 3'd4) begin
            $fatal(1, "Real RGBA CI mismatch. fmt=%0h meta=%0h alen=%0d",
                   last_ci_format, last_ci_metadata, last_ci_alen);
        end
        if ((last_tile_format != META_FMT_RGBA8888) || (last_tile_x_coord != 12'd2) || (last_tile_y_coord != 10'd7)) begin
            $fatal(1, "Real RGBA tile header mismatch. fmt=%0h x=%0d y=%0d",
                   last_tile_format, last_tile_x_coord, last_tile_y_coord);
        end
        if (ar_addr_hist[2] != 64'h0000_0000_8029_db00 || ar_len_hist[2] != 8'd4) begin
            $fatal(1, "Real RGBA AR mismatch. addr=0x%0h len=%0d",
                   ar_addr_hist[2], ar_len_hist[2]);
        end
        send_r_burst(256'h5000_0000_0000_0000_6000_0000_0000_0000_7000_0000_0000_0000_8000_0000_0000_0000, 5);
        wait_cvi_count(10);

        i_cfg_pitch = 12'd16;
        send_meta(8'h00, META_FMT_NV16_10_Y, 12'd0, 10'd0);
        wait_ci_count(4);
        wait_tile_coord_count(4);
        repeat (8) @(posedge clk);
        if (ar_count != 3) begin
            $fatal(1, "No-payload metadata unexpectedly generated AR commands. ar_count=%0d", ar_count);
        end
        if (last_ci_format != META_FMT_NV16_10_Y || last_ci_metadata != 4'h8 || last_ci_alen != 3'd0) begin
            $fatal(1, "No-payload CI mismatch. fmt=%0h meta=%0h alen=%0d",
                   last_ci_format, last_ci_metadata, last_ci_alen);
        end
        if ((last_tile_x_coord != 12'd0) || (last_tile_y_coord != 10'd0)) begin
            $fatal(1, "No-payload tile coord mismatch. x=%0d y=%0d", last_tile_x_coord, last_tile_y_coord);
        end
        if (cvi_count != 10) begin
            $fatal(1, "Unexpected CVI beat count. cvi_count=%0d", cvi_count);
        end
        if (tile_coord_count != 4) begin
            $fatal(1, "Unexpected tile coord count. tile_coord_count=%0d", tile_coord_count);
        end

        send_meta(8'h10, META_FMT_NV12_UV, 12'd0, 10'd0);
        wait_ci_count(5);
        wait_ar_count(4);
        wait_tile_coord_count(5);
        if (last_ar_addr != TEST_BASE_ADDR_RGBA_UV || last_ar_len != 8'd0) begin
            $fatal(1, "Tile base AR mismatch. addr=0x%0h len=%0d", last_ar_addr, last_ar_len);
        end
        send_r_burst(256'hd000_0000_0000_0000_e000_0000_0000_0000_f000_0000_0000_0000_1111_0000_0000_0000, 1);
        wait_cvi_count(11);

        $display("PASS: ubwc_dec_tile_arcmd_gen smoke");
        #20;
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_arcmd_gen.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_arcmd_gen);
`else
        $dumpfile("tb_ubwc_dec_tile_arcmd_gen.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_arcmd_gen);
`endif
`endif
    end

endmodule
