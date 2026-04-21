`default_nettype none

module ubwc_enc_line_to_tile#(
    parameter ADDR_W = 16
)(
    input  wire                clk,
    input  wire                rst_n,

    // static config
    input  wire [2:0]          cfg_format,
    input  wire [15:0]         cfg_a_tile_cols,
    input  wire [15:0]         cfg_b_tile_cols,

    // A FIFO input
    // {fcnt[3:0], lcnt[11:0], vsync, hsync, tlast, tkeep[15:0], tdata[127:0]}
    input  wire                fifo_a_vld,
    output reg                 fifo_a_rdy,
    input  wire [162:0]        fifo_a_data,

    // B FIFO input
    input  wire                fifo_b_vld,
    output reg                 fifo_b_rdy,
    input  wire [162:0]        fifo_b_data,

    // bank0 single-port SRAM
    output reg                 bank0_en,
    output reg                 bank0_wen,
    output reg  [ADDR_W-1:0]   bank0_addr,
    output reg  [127:0]        bank0_din,
    input  wire [127:0]        bank0_dout,
    input  wire                bank0_dout_vld,

    // bank1 single-port SRAM
    output reg                 bank1_en,
    output reg                 bank1_wen,
    output reg  [ADDR_W-1:0]   bank1_addr,
    output reg  [127:0]        bank1_din,
    input  wire [127:0]        bank1_dout,
    input  wire                bank1_dout_vld,

    // tile output: 128bit
    output wire                o_tile_vld,
    input  wire                i_tile_rdy,
    output wire [127:0]        o_tile_data,
    output wire [15:0]         o_tile_keep,
    output wire                o_tile_last,
    output wire                o_plane,      // 0:A 1:B
    output wire [15:0]         o_tile_x,
    output wire [15:0]         o_tile_y, // 内部自动计数的 Tile Y 坐标 (0,1,2,3...)
    output wire [3:0]          o_tile_fcnt
);

    // ------------------------------------------------------------------------
    // Format MUX (查表，彻底消除计算)
    // ------------------------------------------------------------------------
    localparam FMT_RGBA8888  = 3'd0;
    localparam FMT_RGBA10    = 3'd1;
    localparam FMT_YUV420_8  = 3'd2;
    localparam FMT_YUV420_10 = 3'd3;
    localparam FMT_YUV422_8  = 3'd4;
    localparam FMT_YUV422_10 = 3'd5;

    wire is_rgba      = (cfg_format == FMT_RGBA8888) || (cfg_format == FMT_RGBA10);
    wire is_yuv420    = (cfg_format == FMT_YUV420_8) || (cfg_format == FMT_YUV420_10);
    wire is_yuv420_10 = (cfg_format == FMT_YUV420_10);
    wire need_b       = !is_rgba;

    reg [15:0] a_tile_row_words;
    reg [15:0] b_tile_row_words;
    reg [3:0]  a_tile_row_words_shift;
    reg [3:0]  b_tile_row_words_shift; 
    reg [15:0] cfg_tile_h_act;         

    always @(*) begin
        case (cfg_format)
            FMT_RGBA8888, FMT_RGBA10: begin
                a_tile_row_words       = 16'd4;
                b_tile_row_words       = 16'd0;
                a_tile_row_words_shift = 4'd2;  
                b_tile_row_words_shift = 4'd0;
                cfg_tile_h_act         = 16'd4;
            end
            FMT_YUV420_10: begin
                a_tile_row_words       = 16'd4;
                b_tile_row_words       = 16'd4;
                a_tile_row_words_shift = 4'd2;
                b_tile_row_words_shift = 4'd2;
                cfg_tile_h_act         = 16'd4;
            end
            FMT_YUV420_8, FMT_YUV422_8, FMT_YUV422_10: begin
                a_tile_row_words       = 16'd2;
                b_tile_row_words       = 16'd2;
                a_tile_row_words_shift = 4'd1;  
                b_tile_row_words_shift = 4'd1;
                cfg_tile_h_act         = 16'd8;
            end
            default: begin
                a_tile_row_words       = 16'd0;
                b_tile_row_words       = 16'd0;
                a_tile_row_words_shift = 4'd0;
                b_tile_row_words_shift = 4'd0;
                cfg_tile_h_act         = 16'd0;
            end
        endcase
    end

    wire [15:0] a_region_words = cfg_a_tile_cols << 4;
    wire [15:0] b_region_words = cfg_b_tile_cols << 4;
    wire [15:0] b_total_lines  = is_yuv420 ? {cfg_tile_h_act[14:0], 1'b0} : cfg_tile_h_act;

    // ------------------------------------------------------------------------
    // Parse FIFO Payload & Extract vsync
    // ------------------------------------------------------------------------
    wire [3:0]   a_fcnt  = fifo_a_data[162:159]; 
    wire         a_vsync = fifo_a_data[146];     // 提取 vsync 信号
    wire         a_tlast = fifo_a_data[144];     
    wire [127:0] a_tdata = fifo_a_data[127:0];
    
    wire [3:0]   b_fcnt  = fifo_b_data[162:159]; 
    wire         b_vsync = fifo_b_data[146];     
    wire         b_tlast = fifo_b_data[144];     
    wire [127:0] b_tdata = fifo_b_data[127:0];

    // ------------------------------------------------------------------------
    // Bank Bookkeeping & 2D Counters
    // ------------------------------------------------------------------------
    reg        wr_bank_sel;
    reg        rd_bank_sel_act;
    
    localparam RD_IDLE = 2'd0;
    localparam RD_ACT  = 2'd1;
    localparam RD_FIN  = 2'd2;
    reg [1:0]  rd_state;

    reg [15:0] bank0_a_line_idx, bank0_a_tile_x, bank0_a_word_in_tile;
    reg [15:0] bank0_b_line_idx, bank0_b_tile_x, bank0_b_word_in_tile;
    reg        bank0_a_done, bank0_b_done, bank0_meta_vld;
    reg [3:0]  bank0_fcnt;
    reg        bank0_vsync; // 新增：锁存 vsync

    reg [15:0] bank1_a_line_idx, bank1_a_tile_x, bank1_a_word_in_tile;
    reg [15:0] bank1_b_line_idx, bank1_b_tile_x, bank1_b_word_in_tile;
    reg        bank1_a_done, bank1_b_done, bank1_meta_vld;
    reg [3:0]  bank1_fcnt;
    reg        bank1_vsync; // 新增：锁存 vsync

    wire bank0_ready_for_read = bank0_a_done && (!need_b || bank0_b_done);
    wire bank1_ready_for_read = bank1_a_done && (!need_b || bank1_b_done);
    wire cur_bank_ready_for_read = (wr_bank_sel == 1'b0) ? bank0_ready_for_read : bank1_ready_for_read;
    wire oth_bank_sel            = ~wr_bank_sel;
    wire oth_bank_ready_for_read = (oth_bank_sel == 1'b0) ? bank0_ready_for_read : bank1_ready_for_read;
    wire oth_bank_is_reading     = (rd_state != RD_IDLE) && (rd_bank_sel_act == oth_bank_sel);
    wire oth_bank_free_for_write = (!oth_bank_ready_for_read) && (!oth_bank_is_reading);

    wire write_side_block = cur_bank_ready_for_read && !oth_bank_free_for_write;
    wire wr_bank_switch   = cur_bank_ready_for_read && oth_bank_free_for_write;
    wire wr_bank_sel_eff  = wr_bank_switch ? ~wr_bank_sel : wr_bank_sel;

    always @(*) begin
        fifo_a_rdy = 1'b0; fifo_b_rdy = 1'b0;
        if (!write_side_block) begin
            if (fifo_a_vld)                fifo_a_rdy = 1'b1;
            else if (need_b && fifo_b_vld) fifo_b_rdy = 1'b1;
        end
    end
    wire fire_a = fifo_a_vld && fifo_a_rdy;
    wire fire_b = fifo_b_vld && fifo_b_rdy;

    // ------------------------------------------------------------------------
    // Write Address Generation
    // ------------------------------------------------------------------------
    reg [ADDR_W-1:0] a_wr_addr_cur, b_wr_addr_cur;

    always @(*) begin
        a_wr_addr_cur = {ADDR_W{1'b0}}; 
        b_wr_addr_cur = {ADDR_W{1'b0}};

        if (wr_bank_sel_eff == 1'b0) begin
            a_wr_addr_cur = (bank0_a_tile_x << 4) + (bank0_a_line_idx << a_tile_row_words_shift) + bank0_a_word_in_tile;
            if (is_yuv420_10) begin
                // G016/P010 stores two 4-line Y subrows per tile group.
                b_wr_addr_cur = a_region_words +
                                (bank0_b_line_idx[2] ? b_region_words : 16'd0) +
                                (bank0_b_tile_x << 4) +
                                ({14'd0, bank0_b_line_idx[1:0]} << b_tile_row_words_shift) +
                                bank0_b_word_in_tile;
            end else begin
                b_wr_addr_cur = a_region_words +
                                ((is_yuv420 && bank0_b_line_idx[3]) ? b_region_words : 16'd0) +
                                (bank0_b_tile_x << 4) +
                                ((is_yuv420 ? {13'd0, bank0_b_line_idx[2:0]} : bank0_b_line_idx) << b_tile_row_words_shift) +
                                bank0_b_word_in_tile;
            end
        end else begin
            a_wr_addr_cur = (bank1_a_tile_x << 4) + (bank1_a_line_idx << a_tile_row_words_shift) + bank1_a_word_in_tile;
            if (is_yuv420_10) begin
                b_wr_addr_cur = a_region_words +
                                (bank1_b_line_idx[2] ? b_region_words : 16'd0) +
                                (bank1_b_tile_x << 4) +
                                ({14'd0, bank1_b_line_idx[1:0]} << b_tile_row_words_shift) +
                                bank1_b_word_in_tile;
            end else begin
                b_wr_addr_cur = a_region_words +
                                ((is_yuv420 && bank1_b_line_idx[3]) ? b_region_words : 16'd0) +
                                (bank1_b_tile_x << 4) +
                                ((is_yuv420 ? {13'd0, bank1_b_line_idx[2:0]} : bank1_b_line_idx) << b_tile_row_words_shift) +
                                bank1_b_word_in_tile;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Read Side Signals & Counters
    // ------------------------------------------------------------------------
    reg        rd_plane;
    reg        rd_y_subrow;
    reg [15:0] rd_tile_x;
    reg [15:0] rd_word_in_tile;
    reg [15:0] rd_group_y;
    reg [3:0]  rd_fcnt;
    reg        rd_pipe_vld_r;
    reg        rd_pipe_bank_sel_r;
    reg        rd_pipe_last_r;
    reg        rd_pipe_plane_r;
    reg [15:0] rd_pipe_x_r;
    reg [15:0] rd_pipe_y_r;
    reg [3:0]  rd_pipe_fcnt_r;
    
    reg [15:0] rd_tile_grp_y_cnt; // 读端专用的核心 Tile Y 行计数器

    wire [15:0] cur_tile_cols   = (rd_plane == 1'b0) ? cfg_a_tile_cols : cfg_b_tile_cols;
    wire [15:0] cur_region_base = (rd_plane == 1'b0) ? 16'd0 :
                                  (is_yuv420 && rd_y_subrow) ? (a_region_words + b_region_words) :
                                                                a_region_words;

    wire last_word_in_tile = (rd_word_in_tile == 16'd15);
    localparam integer RESP_FIFO_W = 128 + 16 + 1 + 1 + 16 + 16 + 4;
    localparam integer RESP_FIFO_DEPTH = 8;
    localparam integer RESP_FIFO_AF_LEVEL = RESP_FIFO_DEPTH - 2;

    wire                   resp_fifo_full;
    wire                   resp_fifo_almost_full;
    wire                   resp_fifo_empty;
    wire [RESP_FIFO_W-1:0] resp_fifo_din;
    wire [RESP_FIFO_W-1:0] resp_fifo_dout;
    wire                   resp_fifo_wr_en;
    wire                   resp_fifo_rd_en;

    wire issue_read = (rd_state == RD_ACT) && !resp_fifo_almost_full;
    
    wire [ADDR_W-1:0] calc_rd_addr = cur_region_base + (rd_tile_x << 4) + rd_word_in_tile;
    wire              read_data_vld = rd_pipe_vld_r &&
                                      (rd_pipe_bank_sel_r ? bank1_dout_vld : bank0_dout_vld);
    wire [127:0]      read_data     = rd_pipe_bank_sel_r ? bank1_dout : bank0_dout;
    assign resp_fifo_din = {rd_pipe_fcnt_r, rd_pipe_y_r, rd_pipe_x_r, rd_pipe_plane_r, rd_pipe_last_r, 16'hFFFF, read_data};
    assign resp_fifo_wr_en = read_data_vld;
    assign resp_fifo_rd_en = !resp_fifo_empty && i_tile_rdy;

    assign o_tile_vld  = !resp_fifo_empty;
    assign {o_tile_fcnt, o_tile_y, o_tile_x, o_plane, o_tile_last, o_tile_keep, o_tile_data} = resp_fifo_dout;

    // ------------------------------------------------------------------------
    // SRAM MUX & Combinational Data Output
    // ------------------------------------------------------------------------
    reg               do_wr_bank0, do_wr_bank1;
    reg [ADDR_W-1:0]  wr_addr_bank0, wr_addr_bank1;
    reg [127:0]       wr_data_bank0, wr_data_bank1;
    reg               wr_wen_bank0,  wr_wen_bank1;
    wire              read_conflict = (rd_bank_sel_act == 1'b0) ? do_wr_bank0 : do_wr_bank1;
    wire              read_grant    = issue_read && !read_conflict;

    always @(*) begin
        do_wr_bank0 = 0; do_wr_bank1 = 0; wr_addr_bank0 = 0; wr_addr_bank1 = 0;
        wr_data_bank0 = 0; wr_data_bank1 = 0; wr_wen_bank0 = 0; wr_wen_bank1 = 0;

        if (fire_a) begin
            if (wr_bank_sel_eff == 1'b0) begin
                do_wr_bank0=1; wr_addr_bank0=a_wr_addr_cur; wr_data_bank0=a_tdata; wr_wen_bank0=1;
            end else begin
                do_wr_bank1=1; wr_addr_bank1=a_wr_addr_cur; wr_data_bank1=a_tdata; wr_wen_bank1=1;
            end
        end else if (fire_b) begin
            if (wr_bank_sel_eff == 1'b0) begin
                do_wr_bank0=1; wr_addr_bank0=b_wr_addr_cur; wr_data_bank0=b_tdata; wr_wen_bank0=1;
            end else begin
                do_wr_bank1=1; wr_addr_bank1=b_wr_addr_cur; wr_data_bank1=b_tdata; wr_wen_bank1=1;
            end
        end
    end

    always @(*) begin
        bank0_en = 0; bank0_wen = 0; bank0_addr = 0; bank0_din = 0;
        bank1_en = 0; bank1_wen = 0; bank1_addr = 0; bank1_din = 0;

        if (do_wr_bank0) begin
            bank0_en=1; bank0_wen=wr_wen_bank0; bank0_addr=wr_addr_bank0; bank0_din=wr_data_bank0;
        end else if (read_grant && rd_bank_sel_act == 1'b0) begin
            bank0_en=1; bank0_addr=calc_rd_addr; 
        end

        if (do_wr_bank1) begin
            bank1_en=1; bank1_wen=wr_wen_bank1; bank1_addr=wr_addr_bank1; bank1_din=wr_data_bank1;
        end else if (read_grant && rd_bank_sel_act == 1'b1) begin
            bank1_en=1; bank1_addr=calc_rd_addr;
        end

    end

    sync_fifo_af #(
        .DATA_WIDTH (RESP_FIFO_W),
        .DEPTH      (RESP_FIFO_DEPTH),
        .AF_LEVEL   (RESP_FIFO_AF_LEVEL)
    ) u_resp_fifo (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (resp_fifo_wr_en),
        .din         (resp_fifo_din),
        .full        (resp_fifo_full),
        .almost_full (resp_fifo_almost_full),
        .rd_en       (resp_fifo_rd_en),
        .dout        (resp_fifo_dout),
        .empty       (resp_fifo_empty)
    );

    // ------------------------------------------------------------------------
    // FSM & Metadata Pipeline Registers
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bank_sel      <= 1'b0; 
            rd_bank_sel_act  <= 1'b1; 
            rd_state         <= RD_IDLE;
            
            // 内部读端 Y 计数器复位
            rd_tile_grp_y_cnt<= 16'd0; 

            // Bank0 复位
            bank0_a_line_idx <= 16'd0; bank0_a_tile_x <= 16'd0; bank0_a_word_in_tile <= 16'd0;
            bank0_b_line_idx <= 16'd0; bank0_b_tile_x <= 16'd0; bank0_b_word_in_tile <= 16'd0;
            bank0_a_done     <= 1'b0;  bank0_b_done   <= 1'b0;  bank0_meta_vld       <= 1'b0; 
            bank0_fcnt       <= 4'd0;  bank0_vsync    <= 1'b0;

            // Bank1 复位
            bank1_a_line_idx <= 16'd0; bank1_a_tile_x <= 16'd0; bank1_a_word_in_tile <= 16'd0;
            bank1_b_line_idx <= 16'd0; bank1_b_tile_x <= 16'd0; bank1_b_word_in_tile <= 16'd0;
            bank1_a_done     <= 1'b0;  bank1_b_done   <= 1'b0;  bank1_meta_vld       <= 1'b0; 
            bank1_fcnt       <= 4'd0;  bank1_vsync    <= 1'b0;

            // 读流水线及输出复位
            rd_plane <= 1'b0; rd_y_subrow <= 1'b0; rd_tile_x <= 16'd0; rd_word_in_tile <= 16'd0; rd_group_y <= 16'd0; rd_fcnt <= 4'd0;
            rd_pipe_vld_r <= 1'b0; rd_pipe_bank_sel_r <= 1'b0; rd_pipe_last_r <= 1'b0; rd_pipe_plane_r <= 1'b0;
            rd_pipe_x_r <= 16'd0; rd_pipe_y_r <= 16'd0; rd_pipe_fcnt_r <= 4'd0;
        end else begin
            // ==================== Write Side Logic ====================
            if (wr_bank_switch)
                wr_bank_sel <= ~wr_bank_sel;

            // --- A 通道写入 ---
            if (fire_a) begin
                if (wr_bank_sel_eff == 1'b0) begin
                    // 锁存 vsync (防抖: 一行里只要有就抓取)
                    if (a_vsync) bank0_vsync <= 1'b1;

                    if (!bank0_meta_vld) begin 
                        bank0_meta_vld <= 1'b1; 
                        bank0_fcnt     <= a_fcnt; 
                    end
                    if (a_tlast) begin
                        bank0_a_tile_x <= 16'd0;
                        bank0_a_word_in_tile <= 16'd0;
                        if (bank0_a_line_idx + 16'd1 >= cfg_tile_h_act) bank0_a_done <= 1'b1; 
                        else bank0_a_line_idx <= bank0_a_line_idx + 16'd1;
                    end else begin
                        if (bank0_a_word_in_tile + 16'd1 >= a_tile_row_words) begin
                            bank0_a_word_in_tile <= 16'd0;
                            bank0_a_tile_x       <= bank0_a_tile_x + 16'd1;
                        end else begin
                            bank0_a_word_in_tile <= bank0_a_word_in_tile + 16'd1;
                        end
                    end
                end else begin
                    // 锁存 vsync
                    if (a_vsync) bank1_vsync <= 1'b1;

                    if (!bank1_meta_vld) begin 
                        bank1_meta_vld <= 1'b1; 
                        bank1_fcnt     <= a_fcnt; 
                    end
                    if (a_tlast) begin
                        bank1_a_tile_x <= 16'd0;
                        bank1_a_word_in_tile <= 16'd0;
                        if (bank1_a_line_idx + 16'd1 >= cfg_tile_h_act) bank1_a_done <= 1'b1; 
                        else bank1_a_line_idx <= bank1_a_line_idx + 16'd1;
                    end else begin
                        if (bank1_a_word_in_tile + 16'd1 >= a_tile_row_words) begin
                            bank1_a_word_in_tile <= 16'd0;
                            bank1_a_tile_x       <= bank1_a_tile_x + 16'd1;
                        end else begin
                            bank1_a_word_in_tile <= bank1_a_word_in_tile + 16'd1;
                        end
                    end
                end
            end

            // --- B 通道写入 ---
            if (fire_b) begin
                if (wr_bank_sel_eff == 1'b0) begin
                    if (b_vsync) bank0_vsync <= 1'b1;

                    if (!bank0_meta_vld) begin 
                        bank0_meta_vld <= 1'b1; 
                        bank0_fcnt     <= b_fcnt; 
                    end
                    if (b_tlast) begin
                        bank0_b_tile_x <= 16'd0;
                        bank0_b_word_in_tile <= 16'd0;
                        if (bank0_b_line_idx + 16'd1 >= b_total_lines) bank0_b_done <= 1'b1; 
                        else bank0_b_line_idx <= bank0_b_line_idx + 16'd1;
                    end else begin
                        if (bank0_b_word_in_tile + 16'd1 >= b_tile_row_words) begin
                            bank0_b_word_in_tile <= 16'd0;
                            bank0_b_tile_x       <= bank0_b_tile_x + 16'd1;
                        end else begin
                            bank0_b_word_in_tile <= bank0_b_word_in_tile + 16'd1;
                        end
                    end
                end else begin
                    if (b_vsync) bank1_vsync <= 1'b1;

                    if (!bank1_meta_vld) begin 
                        bank1_meta_vld <= 1'b1; 
                        bank1_fcnt     <= b_fcnt; 
                    end
                    if (b_tlast) begin
                        bank1_b_tile_x <= 16'd0;
                        bank1_b_word_in_tile <= 16'd0;
                        if (bank1_b_line_idx + 16'd1 >= b_total_lines) bank1_b_done <= 1'b1; 
                        else bank1_b_line_idx <= bank1_b_line_idx + 16'd1;
                    end else begin
                        if (bank1_b_word_in_tile + 16'd1 >= b_tile_row_words) begin
                            bank1_b_word_in_tile <= 16'd0;
                            bank1_b_tile_x       <= bank1_b_tile_x + 16'd1;
                        end else begin
                            bank1_b_word_in_tile <= bank1_b_word_in_tile + 16'd1;
                        end
                    end
                end
            end

            // ==================== Read Side FSM 及释放 ====================
            if (rd_state == RD_IDLE) begin
                if (bank0_ready_for_read && (wr_bank_sel != 1'b0)) begin
                    rd_bank_sel_act <= 1'b0; rd_state <= RD_ACT;
                    rd_plane <= is_yuv420 ? 1'b1 : 1'b0;
                    rd_y_subrow <= 1'b0;
                    rd_tile_x <= 16'd0; rd_word_in_tile <= 16'd0;
                    rd_fcnt <= bank0_fcnt;

                    // 检测到 vsync：清零内部计数器
                    if (bank0_vsync) begin
                        rd_tile_grp_y_cnt <= 16'd0;
                        rd_group_y        <= 16'd0;
                    end else begin
                        rd_group_y        <= rd_tile_grp_y_cnt;
                    end
                end else if (bank1_ready_for_read && (wr_bank_sel != 1'b1)) begin
                    rd_bank_sel_act <= 1'b1; rd_state <= RD_ACT;
                    rd_plane <= is_yuv420 ? 1'b1 : 1'b0;
                    rd_y_subrow <= 1'b0;
                    rd_tile_x <= 16'd0; rd_word_in_tile <= 16'd0;
                    rd_fcnt <= bank1_fcnt;

                    // 检测到 vsync：清零内部计数器
                    if (bank1_vsync) begin
                        rd_tile_grp_y_cnt <= 16'd0;
                        rd_group_y        <= 16'd0;
                    end else begin
                        rd_group_y        <= rd_tile_grp_y_cnt;
                    end
                end
            end else if (rd_state == RD_ACT) begin
                if (read_grant) begin
                    if (last_word_in_tile) begin
                        if (rd_tile_x + 16'd1 >= cur_tile_cols) begin
                            if (is_yuv420) begin
                                if (rd_plane == 1'b1) begin
                                    if (!rd_y_subrow) begin
                                        rd_y_subrow <= 1'b1;
                                        rd_tile_x <= 16'd0;
                                        rd_word_in_tile <= 16'd0;
                                    end else begin
                                        rd_plane <= 1'b0;
                                        rd_y_subrow <= 1'b0;
                                        rd_tile_x <= 16'd0;
                                        rd_word_in_tile <= 16'd0;
                                    end
                                end else begin
                                    rd_state <= RD_FIN;
                                end
                            end else if ((rd_plane == 1'b0) && need_b) begin
                                // 切换到 B 通道，A 和 B 共享当前的 rd_group_y
                                rd_plane <= 1'b1; rd_tile_x <= 16'd0; rd_word_in_tile <= 16'd0;
                            end else begin
                                // A区和B区全部处理完毕，准备收尾
                                rd_state <= RD_FIN; 
                            end
                        end else begin
                            rd_tile_x <= rd_tile_x + 16'd1; rd_word_in_tile <= 16'd0;
                        end
                    end else begin
                        rd_word_in_tile <= rd_word_in_tile + 16'd1;
                    end
                end
            end else if (rd_state == RD_FIN) begin
                // 流水线排空，释放当前 Bank 资源
                if (resp_fifo_empty && !rd_pipe_vld_r) begin 
                    // 当前 Tile 行（A通道和B通道全部处理完毕）
                    // 在此处将内部 Y 坐标计数器 + 1
                    rd_tile_grp_y_cnt <= rd_tile_grp_y_cnt + 16'd1;

                    if (rd_bank_sel_act == 1'b0) begin
                        bank0_a_line_idx <= 16'd0; bank0_a_tile_x <= 16'd0; bank0_a_word_in_tile <= 16'd0;
                        bank0_b_line_idx <= 16'd0; bank0_b_tile_x <= 16'd0; bank0_b_word_in_tile <= 16'd0;
                        bank0_a_done     <= 1'b0;  bank0_b_done   <= 1'b0;  bank0_meta_vld       <= 1'b0; 
                        bank0_fcnt       <= 4'd0;  bank0_vsync    <= 1'b0; // 清除 vsync 标志
                    end else begin
                        bank1_a_line_idx <= 16'd0; bank1_a_tile_x <= 16'd0; bank1_a_word_in_tile <= 16'd0;
                        bank1_b_line_idx <= 16'd0; bank1_b_tile_x <= 16'd0; bank1_b_word_in_tile <= 16'd0;
                        bank1_a_done     <= 1'b0;  bank1_b_done   <= 1'b0;  bank1_meta_vld       <= 1'b0; 
                        bank1_fcnt       <= 4'd0;  bank1_vsync    <= 1'b0; // 清除 vsync 标志
                    end
                    rd_state <= RD_IDLE;
                end
            end

            // ==================== Read Metadata Pipeline ====================
            rd_pipe_vld_r <= read_grant;
            if (read_grant) begin
                rd_pipe_bank_sel_r <= rd_bank_sel_act;
                rd_pipe_last_r     <= last_word_in_tile;
                rd_pipe_plane_r    <= rd_plane;
                rd_pipe_x_r        <= rd_tile_x;
                rd_pipe_y_r        <= (is_yuv420 && rd_plane) ? ((rd_group_y << 1) + {15'd0, rd_y_subrow}) : rd_group_y;
                rd_pipe_fcnt_r     <= rd_fcnt;
            end
        end
    end

endmodule
`default_nettype wire
