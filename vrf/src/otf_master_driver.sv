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
    // Read the next beat (Task)
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
    // Main state machine with standard blanking timing
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
                // IDLE: wait for the start command
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
                            
                            // Switch to the frame-sync state and assert the vsync pulse early
                            state_r   <= ST_VSYNC;
                            otf_vsync <= 1'b1; 
                        end
                    end
                end

                // ------------------------------------------------
                // VSYNC: clean vertical sync pulse lasting exactly one beat
                // ------------------------------------------------
                ST_VSYNC: begin
                    otf_vsync <= 1'b0; 
                    otf_hsync <= 1'b1; // Assert the HSYNC pulse early
                    state_r   <= ST_HSYNC;
                end

                // ------------------------------------------------
                // HSYNC: horizontal sync pulse lasting exactly one beat (prefetch next-line data)
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
                        // Prepare to emit data
                        otf_de   <= 1'b1;
                        otf_data <= load_data;
                        otf_lcnt <= line_idx_r[11:0];
                        otf_fcnt <= 4'd0;
                        state_r  <= ST_DATA;
                    end
                end

                // ------------------------------------------------
                // DATA: continuously emit valid data while honoring downstream ready backpressure
                // ------------------------------------------------
                ST_DATA: begin
                    // Advance data only when downstream Ready accepts it
                    if (otf_ready) begin
                        if (beat_idx_r == BEATS_PER_LINE - 1) begin
                            // --- End of current line ---
                            if (line_idx_r == img_height - 1) begin
                                // Last beat of the last line; frame complete
                                done      <= 1'b1;
                                otf_de    <= 1'b0;
                                if (fin != 0) begin
                                    $fclose(fin);
                                    fin = 0;
                                end
                                state_r   <= ST_IDLE;
                            end else begin
                                // Start the next line, deassert DE, and trigger a clean HSYNC
                                beat_idx_r <= 0;
                                line_idx_r <= line_idx_r + 1;
                                otf_de     <= 1'b0;
                                otf_hsync  <= 1'b1;
                                // The HSYNC pulse beat must carry the "next line" index;
                                // otherwise downstream logic that latches lcnt on HSYNC will lag by one line.
                                otf_lcnt   <= line_idx_r + 1;
                                state_r    <= ST_HSYNC;
                            end
                        end else begin
                            // --- Advance within the current line ---
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
                    // If ready is 0, hold the current state (otf_de=1 and previous data) unchanged
                end

                default: state_r <= ST_IDLE;
            endcase
        end
    end

endmodule
