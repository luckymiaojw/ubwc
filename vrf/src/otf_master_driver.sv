//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-15  03:37:50
// Module Name       : otf_master_driver.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module enc_otf_driver
#(
    parameter string  INPUT_FILE = "input.txt"
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start,
    output reg          done,
    output reg          error_flag,
    input  wire [15:0]  img_width ,
    input  wire [15:0]  img_height,

    // OTF out
    output reg          otf_vsync,
    output reg          otf_hsync,
    output reg          otf_de,
    output reg  [127:0] otf_data,
    output reg  [3:0]   otf_fcnt,
    output reg  [11:0]  otf_lcnt,
    input  wire         otf_ready
);

    wire    [15:0]  BEATS_PER_LINE = (img_width + 3) / 4;

    // FSM States
    localparam ST_IDLE  = 3'd0;
    localparam ST_VSYNC = 3'd1;
    localparam ST_HSYNC = 3'd2;
    localparam ST_DATA  = 3'd3;

    reg [2:0] state_r;
    
    integer fin;
    integer r;
    integer beat_idx_r;
    integer line_idx_r;

    reg [1023:0] line_buf;
    reg load_ok;
    reg [127:0] load_data;

    // ------------------------------------------------------------
    // 读下一拍数据 (Task)
    // ------------------------------------------------------------
    task automatic load_next_beat;
        output reg         ok;
        output reg [127:0] data_out;
    begin
        ok = 1'b0;
        data_out = 128'd0;

        if (!$feof(fin)) begin
            r = $fgets(line_buf, fin);
            if (r != 0) begin
                r = $sscanf(line_buf, "%h", data_out);
                if (r == 1) ok = 1'b1;
            end
        end
    end
    endtask

    // ------------------------------------------------------------
    // 带有标准消隐时序的主状态机
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            otf_vsync    <= 1'b0;
            otf_hsync    <= 1'b0;
            otf_de       <= 1'b0;
            otf_data     <= 128'd0;
            otf_fcnt     <= 4'd0;
            otf_lcnt     <= 12'd0;

            done         <= 1'b0;
            error_flag   <= 1'b0;
            beat_idx_r   <= 0;
            line_idx_r   <= 0;
            state_r      <= ST_IDLE;
            fin          <= 0;
        end else begin
            done <= 1'b0;

            case (state_r)
                // ------------------------------------------------
                // IDLE: 等待启动命令
                // ------------------------------------------------
                ST_IDLE: begin
                    otf_vsync <= 1'b0;
                    otf_hsync <= 1'b0;
                    otf_de    <= 1'b0;
                    
                    if (start) begin
                        if (fin != 0) begin
                            $fclose(fin);
                            fin = 0;
                        end
                        fin = $fopen(INPUT_FILE, "r");
                        if (fin == 0) begin
                            $display("ERROR: cannot open %s", INPUT_FILE);
                            error_flag <= 1'b1;
                        end else begin
                            error_flag <= 1'b0;
                            beat_idx_r <= 0;
                            line_idx_r <= 0;
                            
                            // 切换到帧同步状态，并提前拉高 vsync 脉冲
                            state_r   <= ST_VSYNC;
                            otf_vsync <= 1'b1; 
                        end
                    end
                end

                // ------------------------------------------------
                // VSYNC: 仅存在 1 拍的干净垂直同步脉冲
                // ------------------------------------------------
                ST_VSYNC: begin
                    otf_vsync <= 1'b0; 
                    otf_hsync <= 1'b1; // 提前拉高 HSYNC 脉冲
                    state_r   <= ST_HSYNC;
                end

                // ------------------------------------------------
                // HSYNC: 仅存在 1 拍的水平同步脉冲 (预取下一行数据)
                // ------------------------------------------------
                ST_HSYNC: begin
                    otf_hsync <= 1'b0;
                    
                    load_next_beat(load_ok, load_data);
                    if (!load_ok) begin
                        $display("ERROR: early EOF in %s", INPUT_FILE);
                        error_flag <= 1'b1;
                        if (fin != 0) begin
                            $fclose(fin);
                            fin = 0;
                        end
                        state_r    <= ST_IDLE;
                    end else begin
                        // 准备开始吐数据
                        otf_de   <= 1'b1;
                        otf_data <= load_data;
                        otf_lcnt <= line_idx_r[11:0];
                        otf_fcnt <= 4'd0;
                        state_r  <= ST_DATA;
                    end
                end

                // ------------------------------------------------
                // DATA: 连续吐有效数据，配合 downstream 的 ready 反压
                // ------------------------------------------------
                ST_DATA: begin
                    // 只有下游 Ready 接收了，才切数据
                    if (otf_ready) begin
                        if (beat_idx_r == BEATS_PER_LINE - 1) begin
                            // --- 当前行结束 ---
                            if (line_idx_r == img_height - 1) begin
                                // 最后一行的最后一拍，一帧结束
                                done      <= 1'b1;
                                otf_de    <= 1'b0;
                                if (fin != 0) begin
                                    $fclose(fin);
                                    fin = 0;
                                end
                                state_r   <= ST_IDLE;
                            end else begin
                                // 开启下一行，拉低 DE，触发干净的 HSYNC
                                beat_idx_r <= 0;
                                line_idx_r <= line_idx_r + 1;
                                otf_de     <= 1'b0;
                                otf_hsync  <= 1'b1;
                                // HSYNC 脉冲所在拍需要带着“下一行”的行号，
                                // 否则依赖 HSYNC 锁存 lcnt 的下游会滞后一行。
                                otf_lcnt   <= line_idx_r + 1;
                                state_r    <= ST_HSYNC;
                            end
                        end else begin
                            // --- 行内切数据 ---
                            beat_idx_r <= beat_idx_r + 1;
                            load_next_beat(load_ok, load_data);
                            if (!load_ok) begin
                                $display("ERROR: input file ended early at line=%0d beat=%0d", line_idx_r, beat_idx_r);
                                error_flag <= 1'b1;
                                otf_de     <= 1'b0;
                                if (fin != 0) begin
                                    $fclose(fin);
                                    fin = 0;
                                end
                                state_r    <= ST_IDLE;
                            end else begin
                                otf_data <= load_data;
                            end
                        end
                    end
                    // 若 ready 为 0，则当前状态（otf_de=1 和旧数据）原封不动保持
                end

                default: state_r <= ST_IDLE;
            endcase
        end
    end

endmodule
