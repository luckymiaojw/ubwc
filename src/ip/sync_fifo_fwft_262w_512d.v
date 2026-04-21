`timescale 1ns / 1ps

// Synchronous FWFT FIFO
module sync_fifo_fwft_262w_512d #(
    parameter DATA_WIDTH = 262,
    parameter ADDR_WIDTH = 9,  // 2^9 = 512
    parameter DEPTH      = 512
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clr,

    // Write Interface
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  din,
    output wire                   full,

    // Read Interface (FWFT Mode)
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  dout,
    output wire                   empty
);

    // FIFO storage and pointers for queued data behind the FWFT output register.
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg  [ADDR_WIDTH-1:0]   wr_ptr;
    reg  [ADDR_WIDTH-1:0]   rd_ptr;
    reg  [DATA_WIDTH-1:0]   dout_reg;
    reg  [ADDR_WIDTH:0]     item_count;
    localparam [ADDR_WIDTH:0] DEPTH_VAL = DEPTH;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr;
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr;
    wire                  rd_fire = rd_en && (item_count != 0);
    wire                  wr_fire = wr_en && ((item_count != DEPTH_VAL) || rd_fire);

    // Full and empty logic
    assign empty = (item_count == 0);
    assign full  = (item_count == DEPTH_VAL);
    assign dout  = dout_reg;

    // FWFT behavior is implemented with a dedicated output register.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr <= 0;
            dout_reg   <= {DATA_WIDTH{1'b0}};
            item_count <= {(ADDR_WIDTH+1){1'b0}};
        end else if (clr) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            dout_reg   <= {DATA_WIDTH{1'b0}};
            item_count <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            case ({wr_fire, rd_fire})
                2'b10: begin
                    if (item_count == 0) begin
                        dout_reg   <= din;
                        item_count <= {{ADDR_WIDTH{1'b0}}, 1'b1};
                    end else begin
                        mem[wr_addr] <= din;
                        wr_ptr       <= wr_ptr + 1'b1;
                        item_count   <= item_count + 1'b1;
                    end
                end
                2'b01: begin
                    if (item_count == 1) begin
                        item_count <= {(ADDR_WIDTH+1){1'b0}};
                    end else begin
                        dout_reg   <= mem[rd_addr];
                        rd_ptr     <= rd_ptr + 1'b1;
                        item_count <= item_count - 1'b1;
                    end
                end
                2'b11: begin
                    if (item_count == 1) begin
                        dout_reg <= din;
                    end else begin
                        mem[wr_addr] <= din;
                        wr_ptr       <= wr_ptr + 1'b1;
                        dout_reg     <= mem[rd_addr];
                        rd_ptr       <= rd_ptr + 1'b1;
                    end
                end
                default: begin
                end
            endcase
        end
    end

endmodule
