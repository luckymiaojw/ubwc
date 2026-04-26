`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen_41x29;

    localparam integer ADDR_WIDTH     = 32;
    localparam integer ID_WIDTH       = 4;
    localparam integer AXI_DATA_WIDTH = 256;
    localparam integer SRAM_ADDR_W    = 12;
    localparam integer SRAM_RD_DW     = 64;
    // Case selection:
    //   5'b00000 -> RGBA8888
    //   5'b00001 -> RGBA1010102
    //   5'b00010 -> YUV420 8-bit
    //   5'b00011 -> YUV420 10-bit
    //   5'b00100 -> YUV422 8-bit
    //   5'b00101 -> YUV422 10-bit
    parameter [4:0] CASE_BASE_FORMAT      = 5'b00010;
    parameter integer CASE_TILE_X_NUMBERS = 41;
    parameter integer CASE_TILE_Y_NUMBERS = 29;

    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;
    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_YUV420_Y    = 5'b01000;
    localparam [4:0] META_FMT_YUV420_UV   = 5'b01001;
    localparam [4:0] META_FMT_YUV422_Y    = 5'b01010;
    localparam [4:0] META_FMT_YUV422_UV   = 5'b01011;
    localparam [4:0] META_FMT_YUV422_10_Y = 5'b01100;
    localparam [4:0] META_FMT_YUV422_10_UV= 5'b01101;
    localparam [4:0] META_FMT_YUV420_10_Y = 5'b01110;
    localparam [4:0] META_FMT_YUV420_10_UV= 5'b01111;

    localparam CASE_IS_RGBA   = (CASE_BASE_FORMAT == BASE_FMT_RGBA8888) || (CASE_BASE_FORMAT == BASE_FMT_RGBA1010102);
    localparam CASE_IS_YUV420 = (CASE_BASE_FORMAT == BASE_FMT_YUV420_8) || (CASE_BASE_FORMAT == BASE_FMT_YUV420_10);
    localparam CASE_IS_YUV422 = (CASE_BASE_FORMAT == BASE_FMT_YUV422_8) || (CASE_BASE_FORMAT == BASE_FMT_YUV422_10);

    localparam integer CASE_PASS_COUNT = CASE_IS_YUV420 ? 3 : 2;

    localparam integer EXPECTED_META_CMDS        = CASE_TILE_X_NUMBERS * CASE_TILE_Y_NUMBERS * CASE_PASS_COUNT;
    localparam integer EXPECTED_SRAM_READ_REQS   = EXPECTED_META_CMDS * 8;
    localparam integer EXPECTED_SRAM_LANE_WRITES = EXPECTED_META_CMDS * 8;
    localparam integer EXPECTED_FIFO_OUTPUTS     = EXPECTED_META_CMDS * 64;

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

    wire [31:0]                 ar_cnt;
    wire [31:0]                 arlen_warn_cnt;
    wire [31:0]                 rlast_cnt;
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

    reg  [63:0]                 active_word;
    reg                         active_word_vld;
    reg                         active_word_pp;
    reg  [1:0]                  active_word_lane;
    reg  [SRAM_ADDR_W-1:0]      active_word_addr;

    integer                     cycle_cnt;
    integer                     fifo_out_cnt;
    integer                     rd_word_wr_ptr;
    integer                     rd_word_rd_ptr;
    integer                     rd_word_overflow_cnt;
    integer                     rd_word_underflow_cnt;
    integer                     shadow_word_missing_cnt;
    integer                     rd_mapping_mismatch_cnt;
    integer                     seq_mismatch_cnt;
    integer                     data_mismatch_cnt;
    integer                     sample_print_cnt;
    integer                     miss_print_cnt;

    integer                     exp_tile_y;
    integer                     exp_pass;
    integer                     exp_row_phase;
    integer                     exp_tile_x;
    integer                     exp_byte_idx;
    reg                         exp_stream_done;

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

    tb_axi_read_slave_model #(
        .ADDR_WIDTH       (ADDR_WIDTH),
        .ID_WIDTH         (ID_WIDTH),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
        .STRICT_AXI_BURST (1'b0),
        .PRAGMATIC_BEATS  (2)
    ) u_axi_slave_model (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_araddr   (m_axi_araddr),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arid     (m_axi_arid),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rid      (m_axi_rid),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .ar_cnt         (ar_cnt),
        .arlen_warn_cnt (arlen_warn_cnt),
        .rlast_cnt      (rlast_cnt)
    );

    function automatic [4:0] expected_output_format;
        input integer pass_idx;
        begin
            if (CASE_BASE_FORMAT == BASE_FMT_RGBA1010102) begin
                expected_output_format = META_FMT_RGBA1010102;
            end else if (CASE_BASE_FORMAT == BASE_FMT_RGBA8888) begin
                expected_output_format = META_FMT_RGBA8888;
            end else if (CASE_BASE_FORMAT == BASE_FMT_YUV420_10) begin
                expected_output_format = (pass_idx == 2) ? META_FMT_YUV420_10_UV : META_FMT_YUV420_10_Y;
            end else if (CASE_BASE_FORMAT == BASE_FMT_YUV420_8) begin
                expected_output_format = (pass_idx == 2) ? META_FMT_YUV420_UV : META_FMT_YUV420_Y;
            end else if (CASE_BASE_FORMAT == BASE_FMT_YUV422_10) begin
                expected_output_format = (pass_idx == 0) ? META_FMT_YUV422_10_Y : META_FMT_YUV422_10_UV;
            end else begin
                expected_output_format = (pass_idx == 0) ? META_FMT_YUV422_Y : META_FMT_YUV422_UV;
            end
        end
    endfunction

    function automatic integer expected_output_y;
        input integer tile_y_idx;
        input integer pass_idx;
        input integer row_phase_idx;
        begin
            if (CASE_IS_RGBA) begin
                expected_output_y = (pass_idx == 0) ? (tile_y_idx * 16 + row_phase_idx)
                                                   : (tile_y_idx * 16 + 8 + row_phase_idx);
            end else if (CASE_IS_YUV420) begin
                    if (pass_idx == 0) expected_output_y = tile_y_idx * 16 + row_phase_idx;
                    else if (pass_idx == 1) expected_output_y = tile_y_idx * 16 + 8 + row_phase_idx;
                    else                    expected_output_y = tile_y_idx * 8 + row_phase_idx;
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
            if (CASE_IS_RGBA) begin
                pass_base = (pass_idx == 0) ? 12'h000 : 12'h100;
            end else if (CASE_IS_YUV420) begin
                    if (pass_idx == 0)      pass_base = 12'h000;
                    else if (pass_idx == 1) pass_base = 12'h100;
                    else                    pass_base = 12'h200;
            end else begin
                pass_base = (pass_idx == 0) ? 12'h000 : 12'h200;
            end
            expected_sram_addr = pass_base + (tile_x_idx * 2) + (row_phase_idx >> 2);
        end
    endfunction

    function automatic expected_last_pass;
        input integer pass_idx;
        begin
            expected_last_pass = CASE_IS_YUV420 ? (pass_idx == 2) : (pass_idx == 1);
        end
    endfunction

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
            while ((fifo_out_cnt < EXPECTED_FIFO_OUTPUTS) && (timeout < 5000000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 5000000) begin
                $display("TIMEOUT DEBUG: fifo_out_cnt=%0d ar_cnt=%0d rlast_cnt=%0d sram_wr_cnt=%0d sram_rd_req_cnt=%0d",
                         fifo_out_cnt, ar_cnt, rlast_cnt, sram_wr_cnt, sram_rd_req_cnt);
                $display("TIMEOUT DEBUG: cmd_ok_cnt=%0d cmd_fail_cnt=%0d error_cnt=%0d",
                         cmd_ok_cnt, cmd_fail_cnt, error_cnt);
                $display("TIMEOUT DEBUG: exp_tile_y=%0d exp_pass=%0d exp_row_phase=%0d exp_tile_x=%0d exp_byte_idx=%0d",
                         exp_tile_y, exp_pass, exp_row_phase, exp_tile_x, exp_byte_idx);
                $display("TIMEOUT DEBUG: meta_get_state=%0d read_state=%0d row_phase=%0d scan_pass=%0d beat_cnt=%0d sram_pending=%0b",
                         dut.u_meta_get_cmd_gen.frame_done,
                         dut.u_meta_data_from_sram.state,
                         dut.u_meta_data_from_sram.row_phase,
                         dut.u_axi_rdata_to_sram.sram_base_addr_offset,
                         1'b0,
                         dut.u_meta_pingpong_sram.rd_pending_valid);
                $display("TIMEOUT DEBUG: axi_slave_rsp_active=%0b axi_slave_beats_left=%0d axi_rready=%0b",
                         u_axi_slave_model.rsp_active,
                         u_axi_slave_model.beats_left,
                         m_axi_rready);
                $display("TIMEOUT DEBUG: meta_fifo empty=%0b full=%0b data_fifo empty=%0b full=%0b bfifo_prog_full=%0b",
                         dut.u_axi_rdata_to_sram.m_fifo_empty,
                         dut.u_axi_rdata_to_sram.m_fifo_full,
                         dut.u_axi_rdata_to_sram.d_fifo_empty,
                         dut.u_axi_rdata_to_sram.d_fifo_full,
                         dut.u_meta_data_from_sram.bfifo_prog_full);
                $fatal(1, "Timeout waiting for expected FIFO outputs.");
            end
            repeat (64) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Keep downstream always ready in the large regression case.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            fifo_rdy  <= 1'b1;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            fifo_rdy  <= 1'b1;
        end
    end

    // SRAM read-response capture queue
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
            fifo_out_cnt             <= 0;
            sample_print_cnt         <= 0;
            seq_mismatch_cnt         <= 0;
            data_mismatch_cnt        <= 0;
            rd_mapping_mismatch_cnt  <= 0;
            exp_tile_y               <= 0;
            exp_pass                 <= 0;
            exp_row_phase            <= 0;
            exp_tile_x               <= 0;
            exp_byte_idx             <= 0;
            exp_stream_done          <= 1'b0;
            active_word              <= 64'd0;
            active_word_vld          <= 1'b0;
            active_word_pp           <= 1'b0;
            active_word_lane         <= 2'd0;
            active_word_addr         <= {SRAM_ADDR_W{1'b0}};
            rd_word_rd_ptr           <= 0;
            rd_word_underflow_cnt    <= 0;
            shadow_word_missing_cnt  <= 0;
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

            fifo_out_cnt <= fifo_out_cnt + 1;

            expected_x_byte = exp_tile_x * 8 + exp_byte_idx;
            expected_y_row  = expected_output_y(exp_tile_y, exp_pass, exp_row_phase);
            expected_addr   = expected_sram_addr(exp_pass, exp_tile_x, exp_row_phase);
            expected_lane   = (exp_row_phase & 3);
            expected_fmt    = expected_output_format(exp_pass);
            expected_eol    = (exp_tile_x == (CASE_TILE_X_NUMBERS - 1));
            expected_last   = expected_last_pass(exp_pass);
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
                        if (exp_pass == (CASE_PASS_COUNT - 1)) begin
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
        base_format            = CASE_BASE_FORMAT;
        meta_base_addr_rgba_y = 32'h1000_0000;
        meta_base_addr_uv       = 32'h2000_0000;
        tile_x_numbers         = CASE_TILE_X_NUMBERS[15:0];
        tile_y_numbers         = CASE_TILE_Y_NUMBERS[15:0];

        #25;
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        $display("");
        $display("============================================================");
        $display("TB: ubwc_dec_meta_data_gen self-check");
        $display("Case format      : %0d", CASE_BASE_FORMAT);
        $display("tile_x_numbers   : %0d", CASE_TILE_X_NUMBERS);
        $display("tile_y_numbers   : %0d", CASE_TILE_Y_NUMBERS);
        $display("expected_cmds    : %0d", EXPECTED_META_CMDS);
        $display("expected_reads   : %0d", EXPECTED_SRAM_READ_REQS);
        $display("expected_outputs : %0d", EXPECTED_FIFO_OUTPUTS);
        $display("============================================================");

        pulse_start();
        wait_until_done();

        $display("");
        $display("---------------- Summary ----------------");
        $display("AR handshakes         : %0d", ar_cnt);
        $display("ARLEN warnings        : %0d", arlen_warn_cnt);
        $display("R last count          : %0d", rlast_cnt);
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
        $display("read map mismatches   : %0d", rd_mapping_mismatch_cnt);
        $display("shadow word missing   : %0d", shadow_word_missing_cnt);
        $display("read queue underflow  : %0d", rd_word_underflow_cnt);
        $display("read queue overflow   : %0d", rd_word_overflow_cnt);
        $display("-----------------------------------------");

        if (ar_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "AR count mismatch.");
        end
        if (cmd_ok_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "cmd_ok_cnt mismatch.");
        end
        if (rlast_cnt != EXPECTED_META_CMDS) begin
            $fatal(1, "RLAST count mismatch.");
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
        if (rd_mapping_mismatch_cnt != 0) begin
            $fatal(1, "SRAM read address/lane mapping mismatches observed.");
        end
        if (shadow_word_missing_cnt != 0) begin
            $fatal(1, "Shadow SRAM had unreadable words.");
        end
        if ((rd_word_underflow_cnt != 0) || (rd_word_overflow_cnt != 0)) begin
            $fatal(1, "Read-word capture queue overflow/underflow observed.");
        end

        #50;
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_meta_data_gen_41x29.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_meta_data_gen_41x29);
        $fsdbDumpMDA(0, tb_ubwc_dec_meta_data_gen_41x29);
`else
        $dumpfile("tb_ubwc_dec_meta_data_gen_41x29.vcd");
        $dumpvars(0, tb_ubwc_dec_meta_data_gen_41x29);
`endif
`endif
    end

endmodule
