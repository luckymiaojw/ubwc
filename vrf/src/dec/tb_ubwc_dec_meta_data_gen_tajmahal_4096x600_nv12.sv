`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12;

    localparam integer ADDR_WIDTH     = 32;
    localparam integer ID_WIDTH       = 4;
    localparam integer AXI_DATA_WIDTH = 256;
    localparam integer SRAM_ADDR_W    = 12;
    localparam integer SRAM_RD_DW     = 64;

    localparam [4:0] BASE_FMT_YUV420_8 = 5'b00010;
    localparam [4:0] META_FMT_NV12_Y   = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV  = 5'b01001;

    localparam [ADDR_WIDTH-1:0] META_BASE_ADDR_Y  = 32'h8000_0000;
    localparam [ADDR_WIDTH-1:0] META_BASE_ADDR_UV = 32'h8028_3000;

    localparam integer CASE_TILE_X_NUMBERS = 8;
    localparam integer CASE_TILE_Y_NUMBERS = 4;

    localparam integer Y_META_WORDS = 1536;
    localparam integer UV_META_WORDS = 1024;
    localparam integer Y_META_BYTES = Y_META_WORDS * 8;
    localparam integer UV_META_BYTES = UV_META_WORDS * 8;

    localparam integer EXPECTED_Y_CMDS          = CASE_TILE_X_NUMBERS * CASE_TILE_Y_NUMBERS * 2;
    localparam integer EXPECTED_UV_CMDS         = CASE_TILE_X_NUMBERS * CASE_TILE_Y_NUMBERS;
    localparam integer EXPECTED_META_CMDS       = EXPECTED_Y_CMDS + EXPECTED_UV_CMDS;
    localparam integer EXPECTED_SRAM_READ_REQS  = EXPECTED_META_CMDS * 8;
    localparam integer EXPECTED_FIFO_OUTPUTS    = EXPECTED_META_CMDS * 64;
    localparam integer EXPECTED_SRAM_LANE_WRITES= EXPECTED_META_CMDS * 8;

    reg  [63:0] y_meta_words [0:Y_META_WORDS-1];
    reg  [63:0] uv_meta_words [0:UV_META_WORDS-1];

    reg                         clk;
    reg                         rst_n;
    reg                         start;
    reg  [4:0]                  base_format;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_rgba_y;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_uv;
    reg  [15:0]                 tile_x_numbers;
    reg  [15:0]                 tile_y_numbers;

    wire                        m_axi_arvalid;
    wire                        m_axi_arready;
    wire [ADDR_WIDTH-1:0]       m_axi_araddr;
    wire [7:0]                  m_axi_arlen;
    wire [2:0]                  m_axi_arsize;
    wire [1:0]                  m_axi_arburst;
    wire [ID_WIDTH-1:0]         m_axi_arid;

    wire                        m_axi_rvalid;
    wire                        m_axi_rready;
    wire [AXI_DATA_WIDTH-1:0]   m_axi_rdata;
    wire [ID_WIDTH-1:0]         m_axi_rid;
    wire [1:0]                  m_axi_rresp;
    wire                        m_axi_rlast;

    wire [37:0]                 fifo_wdata;
    wire                        fifo_vld;
    reg                         fifo_rdy;

    wire [31:0]                 error_cnt;
    wire [31:0]                 cmd_ok_cnt;
    wire [31:0]                 cmd_fail_cnt;

    wire [SRAM_RD_DW-1:0]       sram_rd_rdata      = dut.u_meta_pingpong_sram.rd_rdata;
    wire                        sram_rd_rvalid     = dut.u_meta_pingpong_sram.rd_rvalid;
    wire                        sram_rd_rsp_bank_b = dut.u_meta_pingpong_sram.rd_rsp_bank_b;
    wire [1:0]                  sram_rd_rsp_lane   = dut.u_meta_pingpong_sram.rd_rsp_lane;
    wire [SRAM_ADDR_W-1:0]      sram_rd_rsp_addr   = dut.u_meta_pingpong_sram.rd_rsp_addr;
    wire                        sram_rd_rsp_hit    = dut.u_meta_pingpong_sram.rd_rsp_hit;
    wire [31:0]                 sram_wr_cnt        = dut.u_meta_pingpong_sram.wr_cnt;
    wire [31:0]                 sram_rd_req_cnt    = dut.u_meta_pingpong_sram.rd_req_cnt;
    wire [31:0]                 sram_rd_rsp_cnt    = dut.u_meta_pingpong_sram.rd_rsp_cnt;
    wire [31:0]                 sram_rd_miss_cnt   = dut.u_meta_pingpong_sram.rd_miss_cnt;

    reg  [63:0]                 rd_word_queue [0:EXPECTED_SRAM_READ_REQS-1];
    reg                         rd_word_vld_queue [0:EXPECTED_SRAM_READ_REQS-1];
    reg                         rd_word_pp_queue [0:EXPECTED_SRAM_READ_REQS-1];
    reg  [1:0]                  rd_word_lane_queue [0:EXPECTED_SRAM_READ_REQS-1];
    reg  [SRAM_ADDR_W-1:0]      rd_word_addr_queue [0:EXPECTED_SRAM_READ_REQS-1];
    reg  [37:0]                 expected_fifo_wdata [0:EXPECTED_FIFO_OUTPUTS-1];
    reg                         expected_fifo_vld [0:EXPECTED_FIFO_OUTPUTS-1];
    reg                         expected_fifo_rdy [0:EXPECTED_FIFO_OUTPUTS-1];

    reg                         axi_rvalid_reg;
    reg  [AXI_DATA_WIDTH-1:0]   axi_rdata_reg;
    reg  [ID_WIDTH-1:0]         axi_rid_reg;
    reg  [1:0]                  axi_rresp_reg;
    reg                         axi_rlast_reg;
    reg                         rsp_active;
    reg  [ADDR_WIDTH-1:0]       rsp_addr;
    reg  [ID_WIDTH-1:0]         rsp_id;

    reg  [31:0]                 ar_cnt;
    reg  [31:0]                 arlen_warn_cnt;
    reg  [31:0]                 rlast_cnt;

    integer                     rsp_wait_cycles;
    integer                     rsp_beats_left;
    integer                     rsp_beat_idx;
    integer                     y_words_loaded;
    integer                     uv_words_loaded;
    integer                     cycle_cnt;
    integer                     fifo_out_cnt;
    integer                     rd_word_wr_ptr;
    integer                     rd_word_rd_ptr;
    integer                     rd_word_underflow_cnt;
    integer                     rd_word_overflow_cnt;
    integer                     shadow_word_missing_cnt;
    integer                     rd_mapping_mismatch_cnt;
    integer                     seq_mismatch_cnt;
    integer                     data_mismatch_cnt;
    integer                     sample_print_cnt;
    integer                     miss_print_cnt;
    integer                     vector_lane_hit_cnt;
    integer                     vector_lane_miss_cnt;
    integer                     vector_miss_print_cnt;
    integer                     axi_y_cmd_cnt;
    integer                     axi_uv_cmd_cnt;
    integer                     expected_fifo_loaded;
    integer                     expected_fifo_idx;
    integer                     expected_fifo_missing_cnt;
    integer                     file_compare_mismatch_cnt;
    integer                     actual_fifo_fd;

    integer                     exp_tile_y;
    integer                     exp_pass;
    integer                     exp_row_phase;
    integer                     exp_tile_x;
    integer                     exp_byte_idx;

    reg                         exp_stream_done;
    reg  [63:0]                 active_word;
    reg                         active_word_vld;
    reg                         active_word_pp;
    reg  [1:0]                  active_word_lane;
    reg  [SRAM_ADDR_W-1:0]      active_word_addr;
    reg  [8*256-1:0]            y_meta_file;
    reg  [8*256-1:0]            uv_meta_file;
    reg  [8*256-1:0]            expected_fifo_file;
    reg  [8*256-1:0]            actual_fifo_file;

    assign m_axi_arready = !rsp_active;
    assign m_axi_rvalid  = axi_rvalid_reg;
    assign m_axi_rdata   = axi_rdata_reg;
    assign m_axi_rid     = axi_rid_reg;
    assign m_axi_rresp   = axi_rresp_reg;
    assign m_axi_rlast   = axi_rlast_reg;

    ubwc_dec_meta_data_gen #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .SRAM_ADDR_W    (SRAM_ADDR_W),
        .SRAM_RD_DW     (SRAM_RD_DW)
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (start),
        .base_format            (base_format),
        .meta_base_addr_rgba_y (meta_base_addr_rgba_y),
        .meta_base_addr_uv       (meta_base_addr_uv),
        .tile_x_numbers         (tile_x_numbers),
        .tile_y_numbers         (tile_y_numbers),
        .m_axi_arvalid          (m_axi_arvalid),
        .m_axi_arready          (m_axi_arready),
        .m_axi_araddr           (m_axi_araddr),
        .m_axi_arlen            (m_axi_arlen),
        .m_axi_arsize           (m_axi_arsize),
        .m_axi_arburst          (m_axi_arburst),
        .m_axi_arid             (m_axi_arid),
        .m_axi_rvalid           (m_axi_rvalid),
        .m_axi_rready           (m_axi_rready),
        .m_axi_rdata            (m_axi_rdata),
        .m_axi_rid              (m_axi_rid),
        .m_axi_rresp            (m_axi_rresp),
        .m_axi_rlast            (m_axi_rlast),
        .fifo_wdata             (fifo_wdata),
        .fifo_vld               (fifo_vld),
        .fifo_rdy               (fifo_rdy),
        .error_cnt              (error_cnt),
        .cmd_ok_cnt             (cmd_ok_cnt),
        .cmd_fail_cnt           (cmd_fail_cnt)
    );

    function automatic vector_word_hit;
        input [ADDR_WIDTH-1:0] addr;
        begin
            vector_word_hit =
                ((addr >= META_BASE_ADDR_Y) &&
                 (addr < (META_BASE_ADDR_Y + Y_META_BYTES)) &&
                 (addr[2:0] == 3'b000)) ||
                ((addr >= META_BASE_ADDR_UV) &&
                 (addr < (META_BASE_ADDR_UV + UV_META_BYTES)) &&
                 (addr[2:0] == 3'b000));
        end
    endfunction

    function automatic [63:0] vector_word_data;
        input [ADDR_WIDTH-1:0] addr;
        integer                word_idx;
        begin
            vector_word_data = 64'd0;
            if ((addr >= META_BASE_ADDR_Y) &&
                (addr < (META_BASE_ADDR_Y + Y_META_BYTES)) &&
                (addr[2:0] == 3'b000)) begin
                word_idx = (addr - META_BASE_ADDR_Y) >> 3;
                vector_word_data = y_meta_words[word_idx];
            end else if ((addr >= META_BASE_ADDR_UV) &&
                         (addr < (META_BASE_ADDR_UV + UV_META_BYTES)) &&
                         (addr[2:0] == 3'b000)) begin
                word_idx = (addr - META_BASE_ADDR_UV) >> 3;
                vector_word_data = uv_meta_words[word_idx];
            end
        end
    endfunction

    function automatic [AXI_DATA_WIDTH-1:0] assemble_axi_word;
        input [ADDR_WIDTH-1:0] beat_addr;
        integer                lane_idx;
        reg   [ADDR_WIDTH-1:0] lane_addr;
        begin
            assemble_axi_word = {AXI_DATA_WIDTH{1'b0}};
            for (lane_idx = 0; lane_idx < (AXI_DATA_WIDTH / 64); lane_idx = lane_idx + 1) begin
                lane_addr = beat_addr + (lane_idx * 8);
                assemble_axi_word[lane_idx*64 +: 64] = vector_word_data(lane_addr);
            end
        end
    endfunction

    function automatic [4:0] expected_output_format;
        input integer pass_idx;
        begin
            expected_output_format = (pass_idx == 2) ? META_FMT_NV12_UV : META_FMT_NV12_Y;
        end
    endfunction

    function automatic integer expected_output_y;
        input integer tile_y_idx;
        input integer pass_idx;
        input integer row_phase_idx;
        begin
            if (pass_idx == 0) begin
                expected_output_y = tile_y_idx * 16 + row_phase_idx;
            end else if (pass_idx == 1) begin
                expected_output_y = tile_y_idx * 16 + 8 + row_phase_idx;
            end else begin
                expected_output_y = tile_y_idx * 8 + row_phase_idx;
            end
        end
    endfunction

    function automatic [SRAM_ADDR_W-1:0] expected_sram_addr;
        input integer pass_idx;
        input integer tile_x_idx;
        input integer row_phase_idx;
        reg   [SRAM_ADDR_W-1:0] pass_base;
        begin
            if (pass_idx == 0) begin
                pass_base = 12'h000;
            end else if (pass_idx == 1) begin
                pass_base = 12'h100;
            end else begin
                pass_base = 12'h200;
            end
            expected_sram_addr = pass_base + (tile_x_idx * 2) + (row_phase_idx >> 2);
        end
    endfunction

    task automatic count_vector_beat;
        input [ADDR_WIDTH-1:0] beat_addr;
        integer                lane_idx;
        reg   [ADDR_WIDTH-1:0] lane_addr;
        begin
            for (lane_idx = 0; lane_idx < (AXI_DATA_WIDTH / 64); lane_idx = lane_idx + 1) begin
                lane_addr = beat_addr + (lane_idx * 8);
                if (vector_word_hit(lane_addr)) begin
                    vector_lane_hit_cnt = vector_lane_hit_cnt + 1;
                end else begin
                    vector_lane_miss_cnt = vector_lane_miss_cnt + 1;
                    if (vector_miss_print_cnt < 16) begin
                        $display("[%0t] VECTOR_MISS addr=0x%08h", $time, lane_addr);
                        vector_miss_print_cnt = vector_miss_print_cnt + 1;
                    end
                end
            end
        end
    endtask

    task automatic load_y_vector;
        integer             fd;
        integer             chars;
        integer             word_idx;
        reg [8*256-1:0]     line_buf;
        reg [ADDR_WIDTH-1:0]file_base;
        reg [63:0]          word64;
        begin
            fd = $fopen(y_meta_file, "r");
            if (fd == 0) begin
                $fatal(1, "Failed to open Y metadata vector: %0s", y_meta_file);
            end

            file_base = {ADDR_WIDTH{1'b0}};
            word_idx  = 0;
            while (!$feof(fd)) begin
                line_buf = {8*256{1'b0}};
                chars = $fgets(line_buf, fd);
                if (chars != 0) begin
                    if ($sscanf(line_buf, "@%h", file_base) == 1) begin
                        if (file_base != META_BASE_ADDR_Y) begin
                            $fatal(1, "Unexpected Y metadata base address. got=0x%08h exp=0x%08h",
                                   file_base, META_BASE_ADDR_Y);
                        end
                    end else if ($sscanf(line_buf, "%h", word64) == 1) begin
                        if (word_idx >= Y_META_WORDS) begin
                            $fatal(1, "Y metadata vector is longer than expected.");
                        end
                        y_meta_words[word_idx] = word64;
                        word_idx = word_idx + 1;
                    end
                end
            end

            $fclose(fd);
            y_words_loaded = word_idx;
            if (y_words_loaded != Y_META_WORDS) begin
                $fatal(1, "Y metadata vector word count mismatch. got=%0d exp=%0d",
                       y_words_loaded, Y_META_WORDS);
            end
        end
    endtask

    task automatic load_uv_vector;
        integer              fd;
        integer              chars;
        integer              word_idx;
        reg [8*256-1:0]      line_buf;
        reg [ADDR_WIDTH-1:0] file_base;
        reg [63:0]           word64;
        begin
            fd = $fopen(uv_meta_file, "r");
            if (fd == 0) begin
                $fatal(1, "Failed to open UV metadata vector: %0s", uv_meta_file);
            end

            file_base = {ADDR_WIDTH{1'b0}};
            word_idx  = 0;
            while (!$feof(fd)) begin
                line_buf = {8*256{1'b0}};
                chars = $fgets(line_buf, fd);
                if (chars != 0) begin
                    if ($sscanf(line_buf, "@%h", file_base) == 1) begin
                        if (file_base != META_BASE_ADDR_UV) begin
                            $fatal(1, "Unexpected UV metadata base address. got=0x%08h exp=0x%08h",
                                   file_base, META_BASE_ADDR_UV);
                        end
                    end else if ($sscanf(line_buf, "%h", word64) == 1) begin
                        if (word_idx >= UV_META_WORDS) begin
                            $fatal(1, "UV metadata vector is longer than expected.");
                        end
                        uv_meta_words[word_idx] = word64;
                        word_idx = word_idx + 1;
                    end
                end
            end

            $fclose(fd);
            uv_words_loaded = word_idx;
            if (uv_words_loaded != UV_META_WORDS) begin
                $fatal(1, "UV metadata vector word count mismatch. got=%0d exp=%0d",
                       uv_words_loaded, UV_META_WORDS);
            end
        end
    endtask

    task automatic load_expected_fifo;
        integer              fd;
        integer              chars;
        integer              sample_idx;
        integer              sample_vld;
        integer              sample_rdy;
        integer              loaded_idx;
        reg [8*256-1:0]      line_buf;
        reg [37:0]           sample_wdata;
        begin
            fd = $fopen(expected_fifo_file, "r");
            if (fd == 0) begin
                $fatal(1, "Failed to open expected FIFO stream: %0s", expected_fifo_file);
            end

            loaded_idx = 0;
            while (!$feof(fd)) begin
                line_buf = {8*256{1'b0}};
                chars = $fgets(line_buf, fd);
                if (chars != 0) begin
                    if ($sscanf(line_buf, "%d %d %d %h", sample_idx, sample_vld, sample_rdy, sample_wdata) == 4) begin
                        if (loaded_idx >= EXPECTED_FIFO_OUTPUTS) begin
                            $fatal(1, "Expected FIFO stream is longer than expected.");
                        end
                        if (sample_idx != loaded_idx) begin
                            $fatal(1, "Expected FIFO stream index mismatch. got=%0d exp=%0d",
                                   sample_idx, loaded_idx);
                        end
                        expected_fifo_vld[loaded_idx]   = sample_vld[0];
                        expected_fifo_rdy[loaded_idx]   = sample_rdy[0];
                        expected_fifo_wdata[loaded_idx] = sample_wdata;
                        loaded_idx = loaded_idx + 1;
                    end
                end
            end

            $fclose(fd);
            expected_fifo_loaded = loaded_idx;
            if (expected_fifo_loaded != EXPECTED_FIFO_OUTPUTS) begin
                $fatal(1, "Expected FIFO stream count mismatch. got=%0d exp=%0d",
                       expected_fifo_loaded, EXPECTED_FIFO_OUTPUTS);
            end
        end
    endtask

    task automatic pulse_start;
        begin
            @(posedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
        end
    endtask

    task automatic wait_until_done;
        integer timeout;
        begin
            timeout = 0;
            while ((fifo_out_cnt < EXPECTED_FIFO_OUTPUTS) && (timeout < 2000000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 2000000) begin
                $display("TIMEOUT DEBUG: fifo_out_cnt=%0d ar_cnt=%0d rlast_cnt=%0d sram_wr_cnt=%0d sram_rd_req_cnt=%0d",
                         fifo_out_cnt, ar_cnt, rlast_cnt, sram_wr_cnt, sram_rd_req_cnt);
                $display("TIMEOUT DEBUG: cmd_ok_cnt=%0d cmd_fail_cnt=%0d error_cnt=%0d vector_miss=%0d",
                         cmd_ok_cnt, cmd_fail_cnt, error_cnt, vector_lane_miss_cnt);
                $display("TIMEOUT DEBUG: exp_tile_y=%0d exp_pass=%0d exp_row_phase=%0d exp_tile_x=%0d exp_byte_idx=%0d",
                         exp_tile_y, exp_pass, exp_row_phase, exp_tile_x, exp_byte_idx);
                $display("TIMEOUT DEBUG: meta_get_state=%0d read_state=%0d row_phase=%0d scan_pass=%0d beat_cnt=%0d sram_pending=%0b",
                         dut.u_meta_get_cmd_gen.frame_done,
                         dut.u_meta_data_from_sram.state,
                         dut.u_meta_data_from_sram.row_phase,
                         dut.u_axi_rdata_to_sram.sram_base_addr_offset,
                         1'b0,
                         dut.u_meta_pingpong_sram.rd_pending_valid);
                $fatal(1, "Timeout waiting for expected FIFO outputs.");
            end
            repeat (64) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin : init_vectors
        integer idx;
        y_meta_file  = "../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt";
        uv_meta_file = "../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt";
        expected_fifo_file = "expected_fifo_stream.txt";
        actual_fifo_file   = "actual_fifo_stream.txt";

        for (idx = 0; idx < Y_META_WORDS; idx = idx + 1) begin
            y_meta_words[idx] = 64'd0;
        end
        for (idx = 0; idx < UV_META_WORDS; idx = idx + 1) begin
            uv_meta_words[idx] = 64'd0;
        end
        for (idx = 0; idx < EXPECTED_FIFO_OUTPUTS; idx = idx + 1) begin
            expected_fifo_wdata[idx] = 38'd0;
            expected_fifo_vld[idx]   = 1'b0;
            expected_fifo_rdy[idx]   = 1'b0;
        end

        load_y_vector();
        load_uv_vector();
        load_expected_fifo();

        actual_fifo_fd = $fopen(actual_fifo_file, "w");
        if (actual_fifo_fd == 0) begin
            $fatal(1, "Failed to open actual FIFO dump file: %0s", actual_fifo_file);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            fifo_rdy  <= 1'b1;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            fifo_rdy  <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_rvalid_reg        <= 1'b0;
            axi_rdata_reg         <= {AXI_DATA_WIDTH{1'b0}};
            axi_rid_reg           <= {ID_WIDTH{1'b0}};
            axi_rresp_reg         <= 2'b00;
            axi_rlast_reg         <= 1'b0;
            rsp_active            <= 1'b0;
            rsp_addr              <= {ADDR_WIDTH{1'b0}};
            rsp_id                <= {ID_WIDTH{1'b0}};
            rsp_wait_cycles       <= 0;
            rsp_beats_left        <= 0;
            rsp_beat_idx          <= 0;
            ar_cnt                <= 32'd0;
            arlen_warn_cnt        <= 32'd0;
            rlast_cnt             <= 32'd0;
            vector_lane_hit_cnt   <= 0;
            vector_lane_miss_cnt  <= 0;
            vector_miss_print_cnt <= 0;
            axi_y_cmd_cnt         <= 0;
            axi_uv_cmd_cnt        <= 0;
        end else begin
            axi_rvalid_reg <= 1'b0;
            axi_rlast_reg  <= 1'b0;

            if (m_axi_arvalid && m_axi_arready) begin
                rsp_active      <= 1'b1;
                rsp_addr        <= m_axi_araddr;
                rsp_id          <= m_axi_arid;
                rsp_wait_cycles <= 1;
                rsp_beats_left  <= 2;
                rsp_beat_idx    <= 0;
                ar_cnt          <= ar_cnt + 1'b1;

                if (m_axi_araddr >= META_BASE_ADDR_UV) begin
                    axi_uv_cmd_cnt <= axi_uv_cmd_cnt + 1;
                end else begin
                    axi_y_cmd_cnt <= axi_y_cmd_cnt + 1;
                end

                if (m_axi_arlen != 8'd1) begin
                    arlen_warn_cnt <= arlen_warn_cnt + 1'b1;
                    $display("[%0t] WARN: ARLEN=%0d, expected 1 for 64-byte metadata fetch.",
                             $time, m_axi_arlen);
                end
                if (m_axi_arsize != 3'd5) begin
                    $display("[%0t] WARN: ARSIZE=%0d, expected 5 for 256-bit AXI beats.",
                             $time, m_axi_arsize);
                end
                if (m_axi_arburst != 2'b01) begin
                    $display("[%0t] WARN: ARBURST=%0d, expected INCR burst.",
                             $time, m_axi_arburst);
                end
            end else if (rsp_active && (rsp_wait_cycles != 0)) begin
                rsp_wait_cycles <= rsp_wait_cycles - 1;
            end else if (rsp_active) begin
                axi_rvalid_reg <= 1'b1;
                axi_rdata_reg  <= assemble_axi_word(rsp_addr + (rsp_beat_idx * 32));
                axi_rid_reg    <= rsp_id;
                axi_rresp_reg  <= 2'b00;
                axi_rlast_reg  <= (rsp_beats_left == 1);

                if (m_axi_rready) begin
                    count_vector_beat(rsp_addr + (rsp_beat_idx * 32));
                    if (rsp_beats_left == 1) begin
                        rsp_active     <= 1'b0;
                        rsp_beats_left <= 0;
                        rsp_beat_idx   <= 0;
                        rlast_cnt      <= rlast_cnt + 1'b1;
                    end else begin
                        rsp_beats_left <= rsp_beats_left - 1;
                        rsp_beat_idx   <= rsp_beat_idx + 1;
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_word_wr_ptr        <= 0;
            rd_word_overflow_cnt  <= 0;
            miss_print_cnt        <= 0;
        end else begin
            if (sram_rd_rvalid) begin
                if (rd_word_wr_ptr < EXPECTED_SRAM_READ_REQS) begin
                    rd_word_pp_queue[rd_word_wr_ptr]   <= sram_rd_rsp_bank_b;
                    rd_word_lane_queue[rd_word_wr_ptr] <= sram_rd_rsp_lane;
                    rd_word_addr_queue[rd_word_wr_ptr] <= sram_rd_rsp_addr;
                    rd_word_vld_queue[rd_word_wr_ptr]  <= sram_rd_rsp_hit;
                    rd_word_queue[rd_word_wr_ptr]      <= sram_rd_rdata;
                    rd_word_wr_ptr <= rd_word_wr_ptr + 1;
                end else begin
                    rd_word_overflow_cnt <= rd_word_overflow_cnt + 1;
                end

                if (!sram_rd_rsp_hit && (miss_print_cnt < 16)) begin
                    $display("[%0t] SRAM_MISS bank=%s lane=%0d addr=0x%0h",
                             $time, sram_rd_rsp_bank_b ? "B" : "A",
                             sram_rd_rsp_lane, sram_rd_rsp_addr);
                    miss_print_cnt <= miss_print_cnt + 1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_out_cnt            <= 0;
            sample_print_cnt        <= 0;
            seq_mismatch_cnt        <= 0;
            data_mismatch_cnt       <= 0;
            rd_mapping_mismatch_cnt <= 0;
            expected_fifo_idx       <= 0;
            expected_fifo_missing_cnt <= 0;
            file_compare_mismatch_cnt <= 0;
            exp_tile_y              <= 0;
            exp_pass                <= 0;
            exp_row_phase           <= 0;
            exp_tile_x              <= 0;
            exp_byte_idx            <= 0;
            exp_stream_done         <= 1'b0;
            active_word             <= 64'd0;
            active_word_vld         <= 1'b0;
            active_word_pp          <= 1'b0;
            active_word_lane        <= 2'd0;
            active_word_addr        <= {SRAM_ADDR_W{1'b0}};
            rd_word_rd_ptr          <= 0;
            rd_word_underflow_cnt   <= 0;
            shadow_word_missing_cnt <= 0;
        end else if (fifo_vld && fifo_rdy) begin
            integer expected_x_byte;
            integer expected_y_row;
            integer expected_addr;
            integer expected_lane;
            reg [4:0] expected_fmt;
            reg       expected_eol;
            reg       expected_last;
            reg       expected_pp;
            reg [63:0] word_for_check;
            reg        word_vld_for_check;
            reg        word_pp_for_check;
            reg [1:0]  word_lane_for_check;
            reg [SRAM_ADDR_W-1:0] word_addr_for_check;
            reg [7:0]  expected_meta_byte;
            reg [37:0] expected_file_wdata;
            reg        expected_file_vld;
            reg        expected_file_rdy;

            fifo_out_cnt <= fifo_out_cnt + 1;
            expected_fifo_idx <= expected_fifo_idx + 1;

            if (actual_fifo_fd != 0) begin
                $fdisplay(actual_fifo_fd, "%0d %0d %0d %010h", fifo_out_cnt, fifo_vld, fifo_rdy, fifo_wdata);
            end

            if (fifo_out_cnt < expected_fifo_loaded) begin
                expected_file_wdata = expected_fifo_wdata[fifo_out_cnt];
                expected_file_vld   = expected_fifo_vld[fifo_out_cnt];
                expected_file_rdy   = expected_fifo_rdy[fifo_out_cnt];
                if ((expected_file_vld != fifo_vld) ||
                    (expected_file_rdy != fifo_rdy) ||
                    (expected_file_wdata != fifo_wdata)) begin
                    file_compare_mismatch_cnt <= file_compare_mismatch_cnt + 1;
                    if (sample_print_cnt < 16) begin
                        $display("[%0t] FILE_MISMATCH idx=%0d exp[vld=%0b rdy=%0b wdata=%010h] got[vld=%0b rdy=%0b wdata=%010h]",
                                 $time, fifo_out_cnt,
                                 expected_file_vld, expected_file_rdy, expected_file_wdata,
                                 fifo_vld, fifo_rdy, fifo_wdata);
                        sample_print_cnt <= sample_print_cnt + 1;
                    end
                end
            end else begin
                expected_fifo_missing_cnt <= expected_fifo_missing_cnt + 1;
                if (sample_print_cnt < 16) begin
                    $display("[%0t] FILE_MISMATCH idx=%0d no expected FIFO sample available",
                             $time, fifo_out_cnt);
                    sample_print_cnt <= sample_print_cnt + 1;
                end
            end

            expected_x_byte = exp_tile_x * 8 + exp_byte_idx;
            expected_y_row  = expected_output_y(exp_tile_y, exp_pass, exp_row_phase);
            expected_addr   = expected_sram_addr(exp_pass, exp_tile_x, exp_row_phase);
            expected_lane   = (exp_row_phase & 3);
            expected_fmt    = expected_output_format(exp_pass);
            expected_eol    = (exp_tile_x == (CASE_TILE_X_NUMBERS - 1));
            expected_last   = (exp_pass == 2);
            expected_pp     = exp_tile_y[0];

            word_for_check      = active_word;
            word_vld_for_check  = active_word_vld;
            word_pp_for_check   = active_word_pp;
            word_lane_for_check = active_word_lane;
            word_addr_for_check = active_word_addr;

            if (exp_byte_idx == 0) begin
                if (rd_word_rd_ptr < rd_word_wr_ptr) begin
                    word_for_check      = rd_word_queue[rd_word_rd_ptr];
                    word_vld_for_check  = rd_word_vld_queue[rd_word_rd_ptr];
                    word_pp_for_check   = rd_word_pp_queue[rd_word_rd_ptr];
                    word_lane_for_check = rd_word_lane_queue[rd_word_rd_ptr];
                    word_addr_for_check = rd_word_addr_queue[rd_word_rd_ptr];

                    active_word      <= rd_word_queue[rd_word_rd_ptr];
                    active_word_vld  <= rd_word_vld_queue[rd_word_rd_ptr];
                    active_word_pp   <= rd_word_pp_queue[rd_word_rd_ptr];
                    active_word_lane <= rd_word_lane_queue[rd_word_rd_ptr];
                    active_word_addr <= rd_word_addr_queue[rd_word_rd_ptr];
                    rd_word_rd_ptr   <= rd_word_rd_ptr + 1;
                end else begin
                    rd_word_underflow_cnt <= rd_word_underflow_cnt + 1;
                    word_for_check      = 64'd0;
                    word_vld_for_check  = 1'b0;
                    word_pp_for_check   = 1'b0;
                    word_lane_for_check = 2'd0;
                    word_addr_for_check = {SRAM_ADDR_W{1'b0}};
                end

                if ((word_pp_for_check != expected_pp) ||
                    (word_lane_for_check != expected_lane[1:0]) ||
                    (word_addr_for_check != expected_addr[SRAM_ADDR_W-1:0])) begin
                    rd_mapping_mismatch_cnt <= rd_mapping_mismatch_cnt + 1;
                    if (sample_print_cnt < 16) begin
                        $display("[%0t] READ_MAP_MISMATCH exp_pp=%0b got_pp=%0b exp_lane=%0d got_lane=%0d exp_addr=0x%0h got_addr=0x%0h",
                                 $time, expected_pp, word_pp_for_check, expected_lane, word_lane_for_check,
                                 expected_addr[SRAM_ADDR_W-1:0], word_addr_for_check);
                        sample_print_cnt <= sample_print_cnt + 1;
                    end
                end

                if (!word_vld_for_check) begin
                    shadow_word_missing_cnt <= shadow_word_missing_cnt + 1;
                end
            end

            expected_meta_byte = word_for_check[exp_byte_idx*8 +: 8];

            if ((fifo_wdata[37]    != 1'b0) ||
                (fifo_wdata[36]    != expected_eol) ||
                (fifo_wdata[35]    != expected_last) ||
                (fifo_wdata[26:22] != expected_fmt) ||
                (fifo_wdata[21:10] != expected_x_byte[11:0]) ||
                (fifo_wdata[9:0]   != expected_y_row[9:0])) begin
                seq_mismatch_cnt <= seq_mismatch_cnt + 1;
                if (sample_print_cnt < 16) begin
                    $display("[%0t] SEQ_MISMATCH exp[eol=%0b last=%0b fmt=%0h x=%0d y=%0d] got[eol=%0b last=%0b fmt=%0h x=%0d y=%0d]",
                             $time,
                             expected_eol, expected_last, expected_fmt, expected_x_byte, expected_y_row,
                             fifo_wdata[36], fifo_wdata[35], fifo_wdata[26:22], fifo_wdata[21:10], fifo_wdata[9:0]);
                    sample_print_cnt <= sample_print_cnt + 1;
                end
            end

            if (fifo_wdata[34:27] != expected_meta_byte) begin
                data_mismatch_cnt <= data_mismatch_cnt + 1;
                if (sample_print_cnt < 16) begin
                    $display("[%0t] DATA_MISMATCH exp_meta=%02h got_meta=%02h exp_addr=0x%0h exp_lane=%0d x=%0d y=%0d",
                             $time, expected_meta_byte, fifo_wdata[34:27], expected_addr[SRAM_ADDR_W-1:0],
                             expected_lane, expected_x_byte, expected_y_row);
                    sample_print_cnt <= sample_print_cnt + 1;
                end
            end

            if ((fifo_out_cnt < 8) && (sample_print_cnt < 16)) begin
                $display("[%0t] SAMPLE fmt=%0h x=%0d y=%0d meta=%02h",
                         $time, fifo_wdata[26:22], fifo_wdata[21:10], fifo_wdata[9:0], fifo_wdata[34:27]);
                sample_print_cnt <= sample_print_cnt + 1;
            end

            if (exp_byte_idx == 7) begin
                exp_byte_idx <= 0;
                if (exp_tile_x == (CASE_TILE_X_NUMBERS - 1)) begin
                    exp_tile_x <= 0;
                    if (exp_row_phase == 7) begin
                        exp_row_phase <= 0;
                        if (exp_pass == 2) begin
                            exp_pass <= 0;
                            if (exp_tile_y == (CASE_TILE_Y_NUMBERS - 1)) begin
                                exp_stream_done <= 1'b1;
                            end else begin
                                exp_tile_y <= exp_tile_y + 1;
                            end
                        end else begin
                            exp_pass <= exp_pass + 1;
                        end
                    end else begin
                        exp_row_phase <= exp_row_phase + 1;
                    end
                end else begin
                    exp_tile_x <= exp_tile_x + 1;
                end
            end else begin
                exp_byte_idx <= exp_byte_idx + 1;
            end
        end
    end

    initial begin
        rst_n                  = 1'b0;
        start                  = 1'b0;
        base_format            = BASE_FMT_YUV420_8;
        meta_base_addr_rgba_y = META_BASE_ADDR_Y;
        meta_base_addr_uv     = META_BASE_ADDR_UV;
        tile_x_numbers         = CASE_TILE_X_NUMBERS[15:0];
        tile_y_numbers         = CASE_TILE_Y_NUMBERS[15:0];

        #25;
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        $display("");
        $display("================================================================");
        $display("TB: ubwc_dec_meta_data_gen TajMahal 4096x600 NV12 metadata input");
        $display("Y vector       : %0s", y_meta_file);
        $display("UV vector      : %0s", uv_meta_file);
        $display("Expected FIFO  : %0s", expected_fifo_file);
        $display("Actual FIFO    : %0s", actual_fifo_file);
        $display("Y base         : 0x%08h", META_BASE_ADDR_Y);
        $display("UV base        : 0x%08h", META_BASE_ADDR_UV);
        $display("tile_x_numbers : %0d", CASE_TILE_X_NUMBERS);
        $display("tile_y_numbers : %0d", CASE_TILE_Y_NUMBERS);
        $display("loaded Y words : %0d", y_words_loaded);
        $display("loaded UV words: %0d", uv_words_loaded);
        $display("loaded exp fifo: %0d", expected_fifo_loaded);
        $display("expected_cmds  : %0d", EXPECTED_META_CMDS);
        $display("expected_reads : %0d", EXPECTED_SRAM_READ_REQS);
        $display("expected_fifo  : %0d", EXPECTED_FIFO_OUTPUTS);
        $display("NOTE           : default 8x4 keeps every AXI read inside both vector files.");
        $display("================================================================");

        pulse_start();
        wait_until_done();

        $display("");
        $display("---------------- Summary ----------------");
        $display("AR handshakes         : %0d", ar_cnt);
        $display("AR Y cmds             : %0d", axi_y_cmd_cnt);
        $display("AR UV cmds            : %0d", axi_uv_cmd_cnt);
        $display("ARLEN warnings        : %0d", arlen_warn_cnt);
        $display("R last count          : %0d", rlast_cnt);
        $display("Vector lane hits      : %0d", vector_lane_hit_cnt);
        $display("Vector lane misses    : %0d", vector_lane_miss_cnt);
        $display("SRAM lane writes      : %0d", sram_wr_cnt);
        $display("SRAM read reqs        : %0d", sram_rd_req_cnt);
        $display("SRAM read rsps        : %0d", sram_rd_rsp_cnt);
        $display("SRAM read misses      : %0d", sram_rd_miss_cnt);
        $display("FIFO outputs          : %0d", fifo_out_cnt);
        $display("cmd_ok_cnt            : %0d", cmd_ok_cnt);
        $display("cmd_fail_cnt          : %0d", cmd_fail_cnt);
        $display("error_cnt             : %0d", error_cnt);
        $display("seq mismatches        : %0d", seq_mismatch_cnt);
        $display("data mismatches       : %0d", data_mismatch_cnt);
        $display("file mismatches       : %0d", file_compare_mismatch_cnt);
        $display("file missing samples  : %0d", expected_fifo_missing_cnt);
        $display("read map mismatches   : %0d", rd_mapping_mismatch_cnt);
        $display("shadow word missing   : %0d", shadow_word_missing_cnt);
        $display("read queue underflow  : %0d", rd_word_underflow_cnt);
        $display("read queue overflow   : %0d", rd_word_overflow_cnt);
        $display("-----------------------------------------");

        if (ar_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "AR count mismatch.");
        end
        if (axi_y_cmd_cnt != EXPECTED_Y_CMDS) begin
            $fatal(1, "Y-plane AR count mismatch.");
        end
        if (axi_uv_cmd_cnt != EXPECTED_UV_CMDS) begin
            $fatal(1, "UV-plane AR count mismatch.");
        end
        if (cmd_ok_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "cmd_ok_cnt mismatch.");
        end
        if (rlast_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "RLAST count mismatch.");
        end
        if (vector_lane_miss_cnt != 0) begin
            $fatal(1, "AXI vector model read outside the loaded metadata range.");
        end
        if (sram_wr_cnt != EXPECTED_SRAM_LANE_WRITES) begin
            $fatal(1, "SRAM lane write count mismatch.");
        end
        if (sram_rd_req_cnt != EXPECTED_SRAM_READ_REQS) begin
            $fatal(1, "SRAM read request count mismatch.");
        end
        if (sram_rd_rsp_cnt != EXPECTED_SRAM_READ_REQS) begin
            $fatal(1, "SRAM read response count mismatch.");
        end
        if (fifo_out_cnt != EXPECTED_FIFO_OUTPUTS) begin
            $fatal(1, "FIFO output count mismatch.");
        end
        if (expected_fifo_loaded != EXPECTED_FIFO_OUTPUTS) begin
            $fatal(1, "Expected FIFO file count mismatch.");
        end
        if (!exp_stream_done) begin
            $fatal(1, "Expected output stream did not fully complete.");
        end
        if (arlen_warn_cnt != 0) begin
            $fatal(1, "ARLEN warnings observed.");
        end
        if (cmd_fail_cnt != 0) begin
            $fatal(1, "cmd_fail_cnt is non-zero.");
        end
        if (error_cnt != 0) begin
            $fatal(1, "error_cnt is non-zero.");
        end
        if (sram_rd_miss_cnt != 0) begin
            $fatal(1, "SRAM read misses observed.");
        end
        if (seq_mismatch_cnt != 0) begin
            $fatal(1, "FIFO sequence mismatches observed.");
        end
        if (data_mismatch_cnt != 0) begin
            $fatal(1, "FIFO data mismatches observed.");
        end
        if (file_compare_mismatch_cnt != 0) begin
            $fatal(1, "Expected FIFO file mismatches observed.");
        end
        if (expected_fifo_missing_cnt != 0) begin
            $fatal(1, "Expected FIFO file is shorter than DUT output stream.");
        end
        if (rd_mapping_mismatch_cnt != 0) begin
            $fatal(1, "SRAM read address/lane mapping mismatches observed.");
        end
        if (shadow_word_missing_cnt != 0) begin
            $fatal(1, "Shadow SRAM had unreadable words.");
        end
        if ((rd_word_underflow_cnt != 0) || (rd_word_overflow_cnt != 0)) begin
            $fatal(1, "Read-word capture queue overflow/underflow observed.");
        end

        if (actual_fifo_fd != 0) begin
            $fclose(actual_fifo_fd);
        end
        #50;
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12);
        $fsdbDumpMDA(0, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12);
`else
        $dumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12.vcd");
        $dumpvars(0, tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12);
`endif
`endif
    end

endmodule
