`timescale 1ns / 1ps

// Async FWFT FIFO for clock domain crossing.
module async_fifo_fwft_256w #(
    parameter DATA_WIDTH = 256,
    parameter ADDR_WIDTH = 7,  // 2^7 = 128, enough for line jitter
    parameter DEPTH      = 128
)(
    // --- Write Domain ---
    input  wire                   wr_clk,
    input  wire                   wr_rst_n,
    input  wire                   wr_clr,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  din,
    output wire                   full,

    // --- Read Domain ---
    input  wire                   rd_clk,
    input  wire                   rd_rst_n,
    input  wire                   rd_clr,
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  dout,
    output wire                   empty
);

    // ==========================================
    // 1. Memory array (dual-port RAM)
    // ==========================================
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ==========================================
    // 2. Pointer registers (binary and Gray code)
    // ==========================================
    reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;
    reg [DATA_WIDTH-1:0] dout_reg;
    reg                  dout_valid;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    // ==========================================
    // 3. CDC synchronizers
    // ==========================================
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    // Sync the read Gray pointer into the write clock domain.
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else if (wr_clr) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // Sync the write Gray pointer into the read clock domain.
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else if (rd_clr) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    // ==========================================
    // 4. Write-side control
    // ==========================================
    wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + 1'b1;
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

    // Full when the next write Gray pointer matches the inverted read Gray pointer.
    assign full = (wr_ptr_gray_next == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                         rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_clr) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= din;
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // ==========================================
    // 5. Read-side control
    // ==========================================
    wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + 1'b1;
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;
    wire                 mem_has_data    = (rd_ptr_gray != wr_ptr_gray_sync2);

    // Empty reflects the FWFT output register state.
    assign empty = !dout_valid;
    assign dout  = dout_reg;

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
            dout_reg    <= {DATA_WIDTH{1'b0}};
            dout_valid  <= 1'b0;
        end else if (rd_clr) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
            dout_reg    <= {DATA_WIDTH{1'b0}};
            dout_valid  <= 1'b0;
        end else if (!dout_valid) begin
            if (mem_has_data) begin
                dout_reg    <= mem[rd_addr];
                dout_valid  <= 1'b1;
                rd_ptr_bin  <= rd_ptr_bin_next;
                rd_ptr_gray <= rd_ptr_gray_next;
            end
        end else if (rd_en) begin
            if (mem_has_data) begin
                dout_reg    <= mem[rd_addr];
                rd_ptr_bin  <= rd_ptr_bin_next;
                rd_ptr_gray <= rd_ptr_gray_next;
            end else begin
                dout_valid  <= 1'b0;
            end
        end
    end

endmodule
