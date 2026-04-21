`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen_tajmahal_core #(
    parameter integer CASE_ID = 0,
    parameter integer CASE_TILE_X_NUMBERS = 8,
    parameter integer CASE_TILE_Y_NUMBERS = 4,
    parameter integer CASE_ENABLE_FILE_COMPARE = 1
);

    function automatic integer ceil_div;
        input integer value;
        input integer divisor;
        begin
            if (value <= 0) begin
                ceil_div = 0;
            end else begin
                ceil_div = (value + divisor - 1) / divisor;
            end
        end
    endfunction

    localparam integer CASE_RGBA8888    = 0;
    localparam integer CASE_RGBA1010102 = 1;
    localparam integer CASE_NV12        = 2;

    localparam integer ADDR_WIDTH     = 32;
    localparam integer ID_WIDTH       = 4;
    localparam integer AXI_DATA_WIDTH = 256;
    localparam integer SRAM_ADDR_W    = 12;
    localparam integer SRAM_RD_DW     = 64;

    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;

    localparam [ADDR_WIDTH-1:0] RGBA_META_BASE_ADDR    = 32'h8000_0000;
    localparam [ADDR_WIDTH-1:0] NV12_META_BASE_ADDR_Y  = 32'h8000_0000;
    localparam [ADDR_WIDTH-1:0] NV12_META_BASE_ADDR_UV = 32'h8028_3000;

    localparam integer RGBA_META_WORDS   = 5120;
    localparam integer NV12_Y_META_WORDS = 1536;
    localparam integer NV12_UV_META_WORDS = 1024;

    localparam integer CASE_IS_NV12         = (CASE_ID == CASE_NV12);
    localparam integer CASE_IS_RGBA1010102  = (CASE_ID == CASE_RGBA1010102);

    localparam [4:0] CASE_BASE_FORMAT = CASE_IS_NV12
                                      ? BASE_FMT_YUV420_8
                                      : (CASE_IS_RGBA1010102 ? BASE_FMT_RGBA1010102 : BASE_FMT_RGBA8888);

    localparam [ADDR_WIDTH-1:0] CASE_PLANE0_BASE_ADDR = CASE_IS_NV12 ? NV12_META_BASE_ADDR_Y : RGBA_META_BASE_ADDR;
    localparam [ADDR_WIDTH-1:0] CASE_PLANE1_BASE_ADDR = CASE_IS_NV12 ? NV12_META_BASE_ADDR_UV : RGBA_META_BASE_ADDR;

    localparam integer CASE_PLANE0_WORDS = CASE_IS_NV12 ? NV12_Y_META_WORDS : RGBA_META_WORDS;
    localparam integer CASE_PLANE1_WORDS = CASE_IS_NV12 ? NV12_UV_META_WORDS : 0;
    localparam integer CASE_PLANE0_BYTES = CASE_PLANE0_WORDS * 8;
    localparam integer CASE_PLANE1_BYTES = CASE_PLANE1_WORDS * 8;

    localparam integer CASE_CMD_X_COUNT       = ceil_div(CASE_TILE_X_NUMBERS, 8);
    localparam integer RGBA_BLOCK_Y_COUNT     = ceil_div(CASE_TILE_Y_NUMBERS, 8);
    localparam integer RGBA_GROUP_COUNT       = ceil_div(CASE_TILE_Y_NUMBERS, 16);
    localparam integer NV12_UV_TILE_Y_NUMBERS = ceil_div(CASE_TILE_Y_NUMBERS, 2);
    localparam integer NV12_Y_BLOCK_COUNT     = ceil_div(CASE_TILE_Y_NUMBERS, 8);
    localparam integer NV12_UV_BLOCK_COUNT    = ceil_div(NV12_UV_TILE_Y_NUMBERS, 8);
    localparam integer NV12_GROUP_COUNT       = ceil_div(CASE_TILE_Y_NUMBERS, 16);

    localparam integer CASE_TILE_Y_GROUPS   = CASE_IS_NV12 ? NV12_GROUP_COUNT : RGBA_GROUP_COUNT;
    localparam integer CASE_EXPECTED_PLANE0_CMDS = CASE_IS_NV12
                                                 ? (CASE_CMD_X_COUNT * NV12_Y_BLOCK_COUNT)
                                                 : (CASE_CMD_X_COUNT * RGBA_BLOCK_Y_COUNT);
    localparam integer CASE_EXPECTED_PLANE1_CMDS = CASE_IS_NV12
                                                 ? (CASE_CMD_X_COUNT * NV12_UV_BLOCK_COUNT)
                                                 : 0;
    localparam integer CASE_EXPECTED_META_CMDS       = CASE_EXPECTED_PLANE0_CMDS + CASE_EXPECTED_PLANE1_CMDS;
    localparam integer CASE_EXPECTED_SRAM_READ_REQS  = CASE_IS_NV12
                                                     ? (CASE_CMD_X_COUNT * (CASE_TILE_Y_NUMBERS + NV12_UV_TILE_Y_NUMBERS))
                                                     : (CASE_EXPECTED_META_CMDS * 8);
    localparam integer CASE_EXPECTED_FIFO_OUTPUTS    = CASE_EXPECTED_SRAM_READ_REQS * 8;
    localparam integer CASE_EXPECTED_SRAM_LANE_WRITES= CASE_EXPECTED_META_CMDS * 8;
    localparam integer CASE_TIMEOUT                  = 2000000;

    reg  [63:0] plane0_meta_words [0:RGBA_META_WORDS-1];
    reg  [63:0] plane1_meta_words [0:NV12_UV_META_WORDS-1];

    reg                         clk;
    reg                         rst_n;
    reg                         start;
    reg  [4:0]                  base_format;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_rgba_uv;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_y;
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

    reg  [63:0]                 rd_word_queue [0:CASE_EXPECTED_SRAM_READ_REQS-1];
    reg                         rd_word_vld_queue [0:CASE_EXPECTED_SRAM_READ_REQS-1];
    reg                         rd_word_pp_queue [0:CASE_EXPECTED_SRAM_READ_REQS-1];
    reg  [1:0]                  rd_word_lane_queue [0:CASE_EXPECTED_SRAM_READ_REQS-1];
    reg  [SRAM_ADDR_W-1:0]      rd_word_addr_queue [0:CASE_EXPECTED_SRAM_READ_REQS-1];
    reg  [37:0]                 expected_fifo_wdata [0:CASE_EXPECTED_FIFO_OUTPUTS-1];
    reg                         expected_fifo_vld [0:CASE_EXPECTED_FIFO_OUTPUTS-1];
    reg                         expected_fifo_rdy [0:CASE_EXPECTED_FIFO_OUTPUTS-1];

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
    integer                     plane0_words_loaded;
    integer                     plane1_words_loaded;
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
    integer                     axi_plane0_cmd_cnt;
    integer                     axi_plane1_cmd_cnt;
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
    reg  [8*256-1:0]            plane0_meta_file;
    reg  [8*256-1:0]            plane1_meta_file;
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
        .meta_base_addr_rgba_uv (meta_base_addr_rgba_uv),
        .meta_base_addr_y       (meta_base_addr_y),
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

    function automatic integer expected_pass_count;
        input integer tile_y_group_idx;
        integer luma_rows_remaining;
        begin
            luma_rows_remaining = CASE_TILE_Y_NUMBERS - tile_y_group_idx * 16;
            if (luma_rows_remaining > 8) begin
                expected_pass_count = 2;
            end else if (luma_rows_remaining > 0) begin
                expected_pass_count = 1;
            end else begin
                expected_pass_count = 0;
            end
        end
    endfunction

    function automatic vector_word_hit;
        input [ADDR_WIDTH-1:0] addr;
        begin
            vector_word_hit =
                ((addr >= CASE_PLANE0_BASE_ADDR) &&
                 (addr < (CASE_PLANE0_BASE_ADDR + CASE_PLANE0_BYTES)) &&
                 (addr[2:0] == 3'b000)) ||
                (CASE_IS_NV12 &&
                 (addr >= CASE_PLANE1_BASE_ADDR) &&
                 (addr < (CASE_PLANE1_BASE_ADDR + CASE_PLANE1_BYTES)) &&
                 (addr[2:0] == 3'b000));
        end
    endfunction

    function automatic [63:0] vector_word_data;
        input [ADDR_WIDTH-1:0] addr;
        integer                word_idx;
        begin
            vector_word_data = 64'd0;
            if ((addr >= CASE_PLANE0_BASE_ADDR) &&
                (addr < (CASE_PLANE0_BASE_ADDR + CASE_PLANE0_BYTES)) &&
                (addr[2:0] == 3'b000)) begin
                word_idx = (addr - CASE_PLANE0_BASE_ADDR) >> 3;
                vector_word_data = plane0_meta_words[word_idx];
            end else if (CASE_IS_NV12 &&
                         (addr >= CASE_PLANE1_BASE_ADDR) &&
                         (addr < (CASE_PLANE1_BASE_ADDR + CASE_PLANE1_BYTES)) &&
                         (addr[2:0] == 3'b000)) begin
                word_idx = (addr - CASE_PLANE1_BASE_ADDR) >> 3;
                vector_word_data = plane1_meta_words[word_idx];
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

    function automatic integer expected_nv12_slot_valid;
        input integer tile_y_group_idx;
        input integer slice_idx;
        input integer slot_idx;
        integer luma_rows_remaining;
        integer chroma_rows_remaining;
        integer y_row_in_group;
        begin
            luma_rows_remaining   = CASE_TILE_Y_NUMBERS - tile_y_group_idx * 16;
            chroma_rows_remaining = NV12_UV_TILE_Y_NUMBERS - tile_y_group_idx * 8;

            if (tile_y_group_idx >= CASE_TILE_Y_GROUPS) begin
                expected_nv12_slot_valid = 0;
            end else if (slot_idx == 2) begin
                expected_nv12_slot_valid = (slice_idx < chroma_rows_remaining);
            end else begin
                y_row_in_group = slice_idx * 2 + slot_idx;
                expected_nv12_slot_valid = (y_row_in_group < luma_rows_remaining);
            end
        end
    endfunction

    function automatic integer expected_output_row_phase;
        input integer tile_y_idx;
        input integer pass_idx;
        input integer row_phase_idx;
        begin
            if (CASE_IS_NV12) begin
                if (pass_idx == 2) begin
                    expected_output_row_phase = row_phase_idx;
                end else begin
                    expected_output_row_phase = (row_phase_idx * 2 + pass_idx) & 7;
                end
            end else begin
                expected_output_row_phase = row_phase_idx;
            end
        end
    endfunction

    function automatic [4:0] expected_output_format;
        input integer tile_y_idx;
        input integer pass_idx;
        begin
            if (CASE_IS_NV12) begin
                expected_output_format = (pass_idx == 2) ? META_FMT_NV12_UV : META_FMT_NV12_Y;
            end else begin
                expected_output_format = CASE_IS_RGBA1010102 ? META_FMT_RGBA1010102 : META_FMT_RGBA8888;
            end
        end
    endfunction

    function automatic integer expected_output_y;
        input integer tile_y_idx;
        input integer pass_idx;
        input integer row_phase_idx;
        begin
            if (CASE_IS_NV12) begin
                if (pass_idx == 2) begin
                    expected_output_y = tile_y_idx * 8 + row_phase_idx;
                end else begin
                    expected_output_y = tile_y_idx * 16 + (row_phase_idx * 2) + pass_idx;
                end
            end else begin
                expected_output_y = tile_y_idx * 16 + (pass_idx * 8) + row_phase_idx;
            end
        end
    endfunction

    function automatic [SRAM_ADDR_W-1:0] expected_sram_addr;
        input integer tile_y_idx;
        input integer pass_idx;
        input integer tile_x_idx;
        input integer row_phase_idx;
        reg   [SRAM_ADDR_W-1:0] pass_base;
        integer actual_row_phase_idx;
        begin
            if (CASE_IS_NV12) begin
                actual_row_phase_idx = expected_output_row_phase(tile_y_idx, pass_idx, row_phase_idx);
                if (pass_idx == 2) begin
                    pass_base = 12'h200;
                end else if (((row_phase_idx * 2) + pass_idx) < 8) begin
                    pass_base = 12'h000;
                end else begin
                    pass_base = 12'h100;
                end
                expected_sram_addr = pass_base + (tile_x_idx * 2) + (actual_row_phase_idx >> 2);
            end else begin
                pass_base = (pass_idx == 0) ? 12'h000 : 12'h100;
                expected_sram_addr = pass_base + (tile_x_idx * 2) + (row_phase_idx >> 2);
            end
        end
    endfunction

    function automatic integer expected_last_pass;
        input integer tile_y_idx;
        input integer pass_idx;
        begin
            if (CASE_IS_NV12) begin
                expected_last_pass = (pass_idx == 2);
            end else begin
                expected_last_pass = (pass_idx == (expected_pass_count(tile_y_idx) - 1));
            end
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

    task automatic load_plane0_vector;
        integer              fd;
        integer              chars;
        integer              word_idx;
        reg [8*256-1:0]      line_buf;
        reg [ADDR_WIDTH-1:0] file_base;
        reg [63:0]           word64;
        begin
            fd = $fopen(plane0_meta_file, "r");
            if (fd == 0) begin
                $fatal(1, "Failed to open plane0 metadata vector: %0s", plane0_meta_file);
            end

            file_base = {ADDR_WIDTH{1'b0}};
            word_idx  = 0;
            while (!$feof(fd)) begin
                line_buf = {8*256{1'b0}};
                chars = $fgets(line_buf, fd);
                if (chars != 0) begin
                    if ($sscanf(line_buf, "@%h", file_base) == 1) begin
                        if (file_base != CASE_PLANE0_BASE_ADDR) begin
                            $fatal(1, "Unexpected plane0 metadata base address. got=0x%08h exp=0x%08h",
                                   file_base, CASE_PLANE0_BASE_ADDR);
                        end
                    end else if ($sscanf(line_buf, "%h", word64) == 1) begin
                        if (word_idx >= CASE_PLANE0_WORDS) begin
                            $fatal(1, "Plane0 metadata vector is longer than expected.");
                        end
                        plane0_meta_words[word_idx] = word64;
                        word_idx = word_idx + 1;
                    end
                end
            end

            $fclose(fd);
            plane0_words_loaded = word_idx;
            if (plane0_words_loaded != CASE_PLANE0_WORDS) begin
                $fatal(1, "Plane0 metadata vector word count mismatch. got=%0d exp=%0d",
                       plane0_words_loaded, CASE_PLANE0_WORDS);
            end
        end
    endtask

    task automatic load_plane1_vector;
        integer              fd;
        integer              chars;
        integer              word_idx;
        reg [8*256-1:0]      line_buf;
        reg [ADDR_WIDTH-1:0] file_base;
        reg [63:0]           word64;
        begin
            if (!CASE_IS_NV12) begin
                plane1_words_loaded = 0;
            end else begin
                fd = $fopen(plane1_meta_file, "r");
                if (fd == 0) begin
                    $fatal(1, "Failed to open plane1 metadata vector: %0s", plane1_meta_file);
                end

                file_base = {ADDR_WIDTH{1'b0}};
                word_idx  = 0;
                while (!$feof(fd)) begin
                    line_buf = {8*256{1'b0}};
                    chars = $fgets(line_buf, fd);
                    if (chars != 0) begin
                        if ($sscanf(line_buf, "@%h", file_base) == 1) begin
                            if (file_base != CASE_PLANE1_BASE_ADDR) begin
                                $fatal(1, "Unexpected plane1 metadata base address. got=0x%08h exp=0x%08h",
                                       file_base, CASE_PLANE1_BASE_ADDR);
                            end
                        end else if ($sscanf(line_buf, "%h", word64) == 1) begin
                            if (word_idx >= CASE_PLANE1_WORDS) begin
                                $fatal(1, "Plane1 metadata vector is longer than expected.");
                            end
                            plane1_meta_words[word_idx] = word64;
                            word_idx = word_idx + 1;
                        end
                    end
                end

                $fclose(fd);
                plane1_words_loaded = word_idx;
                if (plane1_words_loaded != CASE_PLANE1_WORDS) begin
                    $fatal(1, "Plane1 metadata vector word count mismatch. got=%0d exp=%0d",
                           plane1_words_loaded, CASE_PLANE1_WORDS);
                end
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
                        if (loaded_idx >= CASE_EXPECTED_FIFO_OUTPUTS) begin
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
            if (expected_fifo_loaded != CASE_EXPECTED_FIFO_OUTPUTS) begin
                $fatal(1, "Expected FIFO stream count mismatch. got=%0d exp=%0d",
                       expected_fifo_loaded, CASE_EXPECTED_FIFO_OUTPUTS);
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
            while ((fifo_out_cnt < CASE_EXPECTED_FIFO_OUTPUTS) && (timeout < CASE_TIMEOUT)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= CASE_TIMEOUT) begin
                $display("TIMEOUT DEBUG(case=%0d): fifo_out_cnt=%0d ar_cnt=%0d rlast_cnt=%0d sram_wr_cnt=%0d sram_rd_req_cnt=%0d",
                         CASE_ID, fifo_out_cnt, ar_cnt, rlast_cnt, sram_wr_cnt, sram_rd_req_cnt);
                $display("TIMEOUT DEBUG(case=%0d): cmd_ok_cnt=%0d cmd_fail_cnt=%0d error_cnt=%0d vector_miss=%0d",
                         CASE_ID, cmd_ok_cnt, cmd_fail_cnt, error_cnt, vector_lane_miss_cnt);
                $display("TIMEOUT DEBUG(case=%0d): exp_tile_y=%0d exp_pass=%0d exp_row_phase=%0d exp_tile_x=%0d exp_byte_idx=%0d",
                         CASE_ID, exp_tile_y, exp_pass, exp_row_phase, exp_tile_x, exp_byte_idx);
                $display("TIMEOUT DEBUG(case=%0d): meta_get_state=%0d read_state=%0d row_phase=%0d scan_pass=%0d beat_cnt=%0d sram_pending=%0b",
                         CASE_ID,
                         dut.u_meta_get_cmd_gen.state,
                         dut.u_meta_data_from_sram.state,
                         dut.u_meta_data_from_sram.row_phase,
                         dut.u_axi_rdata_to_sram.scan_pass,
                         dut.u_axi_rdata_to_sram.beat_cnt,
                         dut.u_meta_pingpong_sram.rd_pending_valid);
                $fatal(1, "Timeout waiting for expected FIFO outputs. CASE_ID=%0d", CASE_ID);
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
        plane0_meta_file   = "input_meta_plane0.txt";
        plane1_meta_file   = "input_meta_plane1.txt";
        expected_fifo_file = "expected_fifo_stream.txt";
        actual_fifo_file   = "actual_fifo_stream.txt";

        for (idx = 0; idx < RGBA_META_WORDS; idx = idx + 1) begin
            plane0_meta_words[idx] = 64'd0;
        end
        for (idx = 0; idx < NV12_UV_META_WORDS; idx = idx + 1) begin
            plane1_meta_words[idx] = 64'd0;
        end
        for (idx = 0; idx < CASE_EXPECTED_FIFO_OUTPUTS; idx = idx + 1) begin
            expected_fifo_wdata[idx] = 38'd0;
            expected_fifo_vld[idx]   = 1'b0;
            expected_fifo_rdy[idx]   = 1'b0;
        end

        load_plane0_vector();
        load_plane1_vector();
        if (CASE_ENABLE_FILE_COMPARE != 0) begin
            load_expected_fifo();
        end else begin
            expected_fifo_loaded = 0;
        end

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
            axi_plane0_cmd_cnt    <= 0;
            axi_plane1_cmd_cnt    <= 0;
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

                if (CASE_IS_NV12 && (m_axi_araddr >= CASE_PLANE1_BASE_ADDR)) begin
                    axi_plane1_cmd_cnt <= axi_plane1_cmd_cnt + 1;
                end else begin
                    axi_plane0_cmd_cnt <= axi_plane0_cmd_cnt + 1;
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
                if (rd_word_wr_ptr < CASE_EXPECTED_SRAM_READ_REQS) begin
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
            fifo_out_cnt              <= 0;
            sample_print_cnt          <= 0;
            seq_mismatch_cnt          <= 0;
            data_mismatch_cnt         <= 0;
            rd_mapping_mismatch_cnt   <= 0;
            expected_fifo_idx         <= 0;
            expected_fifo_missing_cnt <= 0;
            file_compare_mismatch_cnt <= 0;
            exp_tile_y                <= 0;
            exp_pass                  <= 0;
            exp_row_phase             <= 0;
            exp_tile_x                <= 0;
            exp_byte_idx              <= 0;
            exp_stream_done           <= 1'b0;
            active_word               <= 64'd0;
            active_word_vld           <= 1'b0;
            active_word_pp            <= 1'b0;
            active_word_lane          <= 2'd0;
            active_word_addr          <= {SRAM_ADDR_W{1'b0}};
            rd_word_rd_ptr            <= 0;
            rd_word_underflow_cnt     <= 0;
            shadow_word_missing_cnt   <= 0;
        end else if (fifo_vld && fifo_rdy) begin
            integer expected_x_byte;
            integer expected_y_row;
            integer expected_addr;
            integer expected_lane;
            integer expected_row_phase_idx;
            integer current_pass_count;
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
            integer next_nv12_group;
            integer next_nv12_slice;
            integer next_nv12_slot;
            reg     found_next_nv12;

            fifo_out_cnt <= fifo_out_cnt + 1;
            expected_fifo_idx <= expected_fifo_idx + 1;

            if (actual_fifo_fd != 0) begin
                $fdisplay(actual_fifo_fd, "%0d %0d %0d %010h", fifo_out_cnt, fifo_vld, fifo_rdy, fifo_wdata);
            end

            if (CASE_ENABLE_FILE_COMPARE != 0) begin
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
            end

            current_pass_count = expected_pass_count(exp_tile_y);
            expected_x_byte = exp_tile_x * 8 + exp_byte_idx;
            expected_y_row  = expected_output_y(exp_tile_y, exp_pass, exp_row_phase);
            expected_row_phase_idx = expected_output_row_phase(exp_tile_y, exp_pass, exp_row_phase);
            expected_addr   = expected_sram_addr(exp_tile_y, exp_pass, exp_tile_x, exp_row_phase);
            expected_lane   = (expected_row_phase_idx & 3);
            expected_fmt    = expected_output_format(exp_tile_y, exp_pass);
            expected_eol    = (exp_tile_x == (CASE_CMD_X_COUNT - 1));
            expected_last   = expected_last_pass(exp_tile_y, exp_pass);
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
                if (exp_tile_x == (CASE_CMD_X_COUNT - 1)) begin
                    exp_tile_x <= 0;
                    if (CASE_IS_NV12) begin
                        next_nv12_group = exp_tile_y;
                        next_nv12_slice = exp_row_phase;
                        next_nv12_slot  = exp_pass;
                        found_next_nv12 = 1'b0;

                        while (!found_next_nv12) begin
                            if (next_nv12_slot == 2) begin
                                next_nv12_slot = 0;
                                next_nv12_slice = next_nv12_slice + 1;
                            end else begin
                                next_nv12_slot = next_nv12_slot + 1;
                            end

                            if (next_nv12_slice >= 8) begin
                                next_nv12_slice = 0;
                                next_nv12_group = next_nv12_group + 1;
                            end

                            if (next_nv12_group >= CASE_TILE_Y_GROUPS) begin
                                found_next_nv12 = 1'b1;
                            end else if (expected_nv12_slot_valid(next_nv12_group, next_nv12_slice, next_nv12_slot)) begin
                                found_next_nv12 = 1'b1;
                            end
                        end

                        if (next_nv12_group >= CASE_TILE_Y_GROUPS) begin
                            exp_stream_done <= 1'b1;
                        end else begin
                            exp_tile_y    <= next_nv12_group;
                            exp_row_phase <= next_nv12_slice;
                            exp_pass      <= next_nv12_slot;
                        end
                    end else begin
                        if (exp_row_phase == 7) begin
                            exp_row_phase <= 0;
                            if (exp_pass == (current_pass_count - 1)) begin
                                exp_pass <= 0;
                                if (exp_tile_y == (CASE_TILE_Y_GROUPS - 1)) begin
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
        base_format            = CASE_BASE_FORMAT;
        meta_base_addr_rgba_uv = CASE_IS_NV12 ? CASE_PLANE1_BASE_ADDR : CASE_PLANE0_BASE_ADDR;
        meta_base_addr_y       = CASE_PLANE0_BASE_ADDR;
        tile_x_numbers         = CASE_TILE_X_NUMBERS[15:0];
        tile_y_numbers         = CASE_TILE_Y_NUMBERS[15:0];

        #25;
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        $display("");
        $display("================================================================");
        case (CASE_ID)
            CASE_RGBA8888: begin
                $display("TB: ubwc_dec_meta_data_gen TajMahal RGBA8888 metadata input");
            end
            CASE_RGBA1010102: begin
                $display("TB: ubwc_dec_meta_data_gen TajMahal RGBA1010102 metadata input");
            end
            default: begin
                $display("TB: ubwc_dec_meta_data_gen TajMahal NV12 metadata input");
            end
        endcase
        $display("Plane0 vector   : %0s", plane0_meta_file);
        if (CASE_IS_NV12) begin
            $display("Plane1 vector   : %0s", plane1_meta_file);
        end
        $display("Expected FIFO   : %0s", expected_fifo_file);
        $display("Actual FIFO     : %0s", actual_fifo_file);
        $display("Plane0 base     : 0x%08h", CASE_PLANE0_BASE_ADDR);
        if (CASE_IS_NV12) begin
            $display("Plane1 base     : 0x%08h", CASE_PLANE1_BASE_ADDR);
        end
        $display("tile_x_numbers  : %0d", CASE_TILE_X_NUMBERS);
        $display("tile_y_numbers  : %0d", CASE_TILE_Y_NUMBERS);
        $display("cmd_x_count     : %0d", CASE_CMD_X_COUNT);
        $display("tile_y_groups   : %0d", CASE_TILE_Y_GROUPS);
        $display("loaded plane0   : %0d", plane0_words_loaded);
        if (CASE_IS_NV12) begin
            $display("loaded plane1   : %0d", plane1_words_loaded);
        end
        $display("loaded exp fifo : %0d", expected_fifo_loaded);
        $display("expected_cmds   : %0d", CASE_EXPECTED_META_CMDS);
        $display("expected_reads  : %0d", CASE_EXPECTED_SRAM_READ_REQS);
        $display("expected_fifo   : %0d", CASE_EXPECTED_FIFO_OUTPUTS);
        $display("file_compare    : %0d", CASE_ENABLE_FILE_COMPARE);
        $display("================================================================");

        pulse_start();
        wait_until_done();

        $display("");
        $display("---------------- Summary ----------------");
        $display("AR handshakes         : %0d", ar_cnt);
        $display("AR plane0 cmds        : %0d", axi_plane0_cmd_cnt);
        $display("AR plane1 cmds        : %0d", axi_plane1_cmd_cnt);
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

        if (ar_cnt != CASE_EXPECTED_META_CMDS) begin
            $fatal(1, "AR count mismatch.");
        end
        if (axi_plane0_cmd_cnt != CASE_EXPECTED_PLANE0_CMDS) begin
            $fatal(1, "Plane0 AR count mismatch.");
        end
        if (axi_plane1_cmd_cnt != CASE_EXPECTED_PLANE1_CMDS) begin
            $fatal(1, "Plane1 AR count mismatch.");
        end
        if (cmd_ok_cnt != CASE_EXPECTED_META_CMDS) begin
            $fatal(1, "cmd_ok_cnt mismatch.");
        end
        if (rlast_cnt != CASE_EXPECTED_META_CMDS) begin
            $fatal(1, "RLAST count mismatch.");
        end
        if (vector_lane_miss_cnt != 0) begin
            $fatal(1, "AXI vector model read outside the loaded metadata range.");
        end
        if (sram_wr_cnt != CASE_EXPECTED_SRAM_LANE_WRITES) begin
            $fatal(1, "SRAM lane write count mismatch.");
        end
        if (sram_rd_req_cnt != CASE_EXPECTED_SRAM_READ_REQS) begin
            $fatal(1, "SRAM read request count mismatch.");
        end
        if (sram_rd_rsp_cnt != CASE_EXPECTED_SRAM_READ_REQS) begin
            $fatal(1, "SRAM read response count mismatch.");
        end
        if (fifo_out_cnt != CASE_EXPECTED_FIFO_OUTPUTS) begin
            $fatal(1, "FIFO output count mismatch.");
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
        if (CASE_ENABLE_FILE_COMPARE != 0) begin
            if (expected_fifo_loaded != CASE_EXPECTED_FIFO_OUTPUTS) begin
                $fatal(1, "Expected FIFO file count mismatch.");
            end
            if (file_compare_mismatch_cnt != 0) begin
                $fatal(1, "Expected FIFO file mismatches observed.");
            end
            if (expected_fifo_missing_cnt != 0) begin
                $fatal(1, "Expected FIFO file is shorter than DUT output stream.");
            end
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
        case (CASE_ID)
            CASE_RGBA8888:    $fsdbDumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888.fsdb");
            CASE_RGBA1010102: $fsdbDumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102.fsdb");
            default:          $fsdbDumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12.fsdb");
        endcase
        $fsdbDumpvars(0);
        $fsdbDumpMDA(0);
`else
        case (CASE_ID)
            CASE_RGBA8888:    $dumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888.vcd");
            CASE_RGBA1010102: $dumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102.vcd");
            default:          $dumpfile("tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12.vcd");
        endcase
        $dumpvars(0);
`endif
`endif
    end

endmodule

module tb_ubwc_dec_meta_data_gen_tajmahal_cases #(
    parameter integer CASE_ID = 0,
    parameter integer CASE_TILE_X_NUMBERS = 8,
    parameter integer CASE_TILE_Y_NUMBERS = 4,
    parameter integer CASE_ENABLE_FILE_COMPARE = 1
);
    tb_ubwc_dec_meta_data_gen_tajmahal_core #(
        .CASE_ID             (CASE_ID),
        .CASE_TILE_X_NUMBERS (CASE_TILE_X_NUMBERS),
        .CASE_TILE_Y_NUMBERS (CASE_TILE_Y_NUMBERS),
        .CASE_ENABLE_FILE_COMPARE (CASE_ENABLE_FILE_COMPARE)
    ) u_core ();
endmodule

module tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 #(
    parameter integer CASE_TILE_X_NUMBERS = 8,
    parameter integer CASE_TILE_Y_NUMBERS = 4,
    parameter integer CASE_ENABLE_FILE_COMPARE = 1
);
    tb_ubwc_dec_meta_data_gen_tajmahal_core #(
        .CASE_ID             (0),
        .CASE_TILE_X_NUMBERS (CASE_TILE_X_NUMBERS),
        .CASE_TILE_Y_NUMBERS (CASE_TILE_Y_NUMBERS),
        .CASE_ENABLE_FILE_COMPARE (CASE_ENABLE_FILE_COMPARE)
    ) u_core ();
endmodule

module tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102 #(
    parameter integer CASE_TILE_X_NUMBERS = 8,
    parameter integer CASE_TILE_Y_NUMBERS = 4,
    parameter integer CASE_ENABLE_FILE_COMPARE = 1
);
    tb_ubwc_dec_meta_data_gen_tajmahal_core #(
        .CASE_ID             (1),
        .CASE_TILE_X_NUMBERS (CASE_TILE_X_NUMBERS),
        .CASE_TILE_Y_NUMBERS (CASE_TILE_Y_NUMBERS),
        .CASE_ENABLE_FILE_COMPARE (CASE_ENABLE_FILE_COMPARE)
    ) u_core ();
endmodule

module tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12 #(
    parameter integer CASE_TILE_X_NUMBERS = 8,
    parameter integer CASE_TILE_Y_NUMBERS = 4,
    parameter integer CASE_ENABLE_FILE_COMPARE = 1
);
    tb_ubwc_dec_meta_data_gen_tajmahal_core #(
        .CASE_ID             (2),
        .CASE_TILE_X_NUMBERS (CASE_TILE_X_NUMBERS),
        .CASE_TILE_Y_NUMBERS (CASE_TILE_Y_NUMBERS),
        .CASE_ENABLE_FILE_COMPARE (CASE_ENABLE_FILE_COMPARE)
    ) u_core ();
endmodule
