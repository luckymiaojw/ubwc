`timescale 1ns/1ps

module tb_ubwc_dec_wrapper_top_tajmahal_rgba8888;

    localparam integer APB_AW            = 16;
    localparam integer APB_DW            = 32;
    localparam integer AXI_AW            = 64;
    localparam integer AXI_DW            = 256;
    localparam integer AXI_IDW           = 6;
    localparam integer AXI_LENW          = 8;
    localparam integer SB_WIDTH          = 3;

    localparam integer IMG_W             = 4096;
    localparam integer IMG_H_ACTUAL      = 600;
    localparam integer IMG_H_ALIGNED     = 608;
    localparam integer META_PITCH_BYTES  = 256;
    localparam integer META_HEIGHT_LINES = 160;
    localparam integer TILE_PITCH_BYTES  = 16384;
    localparam integer EXPECTED_OTF_DE_BEATS = (IMG_W / 4) * IMG_H_ALIGNED;

    localparam integer META_WORDS64      = (META_PITCH_BYTES * META_HEIGHT_LINES) / 8;
    localparam integer TILE_WORDS64      = (TILE_PITCH_BYTES * IMG_H_ALIGNED) / 8;

    localparam [63:0] META_BASE_ADDR     = 64'h0000_0000_8000_0000;
    localparam [4:0]  BASE_FMT_RGBA8888  = 5'b00000;

    reg                       PCLK;
    reg                       PRESETn;
    reg                       PSEL;
    reg                       PENABLE;
    reg  [APB_AW-1:0]         PADDR;
    reg                       PWRITE;
    reg  [APB_DW-1:0]         PWDATA;
    wire                      PREADY;
    wire                      PSLVERR;
    wire [APB_DW-1:0]         PRDATA;

    reg                       i_axi_clk;
    reg                       i_axi_rstn;
    reg                       i_otf_clk;
    reg                       i_otf_rstn;

    wire                      o_otf_vsync;
    wire                      o_otf_hsync;
    wire                      o_otf_de;
    wire [127:0]              o_otf_data;
    wire [3:0]                o_otf_fcnt;
    wire [11:0]               o_otf_lcnt;
    reg                       i_otf_ready;

    wire                      o_otf_sram_a_wen;
    wire [12:0]               o_otf_sram_a_waddr;
    wire [127:0]              o_otf_sram_a_wdata;
    wire                      o_otf_sram_a_ren;
    wire [12:0]               o_otf_sram_a_raddr;
    wire [127:0]              i_otf_sram_a_rdata;
    wire                      o_otf_sram_b_wen;
    wire [12:0]               o_otf_sram_b_waddr;
    wire [127:0]              o_otf_sram_b_wdata;
    wire                      o_otf_sram_b_ren;
    wire [12:0]               o_otf_sram_b_raddr;
    wire [127:0]              i_otf_sram_b_rdata;
    wire                      o_bank0_en;
    wire                      o_bank0_wen;
    wire [12:0]               o_bank0_addr;
    wire [127:0]              o_bank0_din;
    wire [127:0]              i_bank0_dout;
    reg                       i_bank0_dout_vld;
    wire                      o_bank1_en;
    wire                      o_bank1_wen;
    wire [12:0]               o_bank1_addr;
    wire [127:0]              o_bank1_din;
    wire [127:0]              i_bank1_dout;
    reg                       i_bank1_dout_vld;

    wire [AXI_IDW:0]          o_m_axi_arid;
    wire [AXI_AW-1:0]         o_m_axi_araddr;
    wire [AXI_LENW-1:0]       o_m_axi_arlen;
    wire [3:0]                o_m_axi_arsize;
    wire [1:0]                o_m_axi_arburst;
    wire [0:0]                o_m_axi_arlock;
    wire [3:0]                o_m_axi_arcache;
    wire [2:0]                o_m_axi_arprot;
    wire                      o_m_axi_arvalid;
    reg                       i_m_axi_arready;
    reg  [AXI_DW-1:0]         i_m_axi_rdata;
    reg                       i_m_axi_rvalid;
    reg  [1:0]                i_m_axi_rresp;
    reg                       i_m_axi_rlast;
    wire                      o_m_axi_rready;
    assign o_otf_sram_a_wen   = o_bank0_en && o_bank0_wen;
    assign o_otf_sram_a_waddr = o_bank0_addr;
    assign o_otf_sram_a_wdata = o_bank0_din;
    assign o_otf_sram_a_ren   = o_bank0_en && !o_bank0_wen;
    assign o_otf_sram_a_raddr = o_bank0_addr;
    assign i_bank0_dout       = i_otf_sram_a_rdata;
    assign o_otf_sram_b_wen   = o_bank1_en && o_bank1_wen;
    assign o_otf_sram_b_waddr = o_bank1_addr;
    assign o_otf_sram_b_wdata = o_bank1_din;
    assign o_otf_sram_b_ren   = o_bank1_en && !o_bank1_wen;
    assign o_otf_sram_b_raddr = o_bank1_addr;
    assign i_bank1_dout       = i_otf_sram_b_rdata;

    reg  [63:0]               meta_words [0:META_WORDS64-1];
    reg  [63:0]               tile_words [0:TILE_WORDS64-1];

    reg                       axi_rsp_active;
    reg                       axi_rsp_is_meta;
    reg  [AXI_AW-1:0]         axi_rsp_addr;
    reg  [7:0]                axi_rsp_beats_left;
    reg  [7:0]                axi_rsp_beat_idx;

    integer                   meta_ar_cnt;
    integer                   tile_ar_cnt;
    integer                   axi_rbeat_cnt;
    integer                   otf_de_beat_cnt;
    integer                   last_progress_cycle;
    integer                   otf_fd;
    integer                   cycle_cnt;

    function automatic [AXI_DW-1:0] pack_axi_word;
        input integer is_meta;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if (is_meta != 0) begin
                word64_base = ((addr - META_BASE_ADDR) >> 3) + beat_idx * 4;
                w0 = (word64_base + 0 < META_WORDS64) ? meta_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < META_WORDS64) ? meta_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < META_WORDS64) ? meta_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < META_WORDS64) ? meta_words[word64_base + 3] : 64'd0;
            end else begin
                word64_base = (addr >> 3) + beat_idx * 4;
                w0 = (word64_base + 0 < TILE_WORDS64) ? tile_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < TILE_WORDS64) ? tile_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < TILE_WORDS64) ? tile_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < TILE_WORDS64) ? tile_words[word64_base + 3] : 64'd0;
            end
            pack_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    task automatic apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge PCLK);
            PENABLE <= 1'b1;
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
            PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_wrapper_regs;
        begin
            // TILE_CFG0
            apb_write(16'h0008, {20'd0, 1'b0, 1'b1, 1'b1, 5'd16, 1'b1, 1'b1, 1'b0});
            // TILE_CFG1: pitch in 16-byte units
            apb_write(16'h000c, 32'd1024);
            // TILE_CFG2: ci_input_type=1, ci_sb=7, ci_lossy=0, ci_alpha_mode=0
            apb_write(16'h0010, 32'h0000_000f);
            // VIVO_CFG: ubwc_en=1, sreset=0
            apb_write(16'h0014, 32'h0000_0001);

            // META base and geometry
            apb_write(16'h001c, META_BASE_ADDR[31:0]);
            apb_write(16'h0020, META_BASE_ADDR[63:32]);
            apb_write(16'h0024, 32'h0000_0000);
            apb_write(16'h0028, 32'h0000_0000);
            // TajMahal RGBA image tile geometry:
            // - tile width  = 16 pixels  -> 4096 / 16 = 256 tiles
            // - tile height = 4 pixels   -> 608  / 4  = 152 aligned tile rows
            apb_write(16'h002c, {16'd152, 16'd256});

            // OTF timing. Use aligned 608 active lines so the full stored vector can be observed.
            apb_write(16'h0030, {11'd0, BASE_FMT_RGBA8888, 16'd4096});
            apb_write(16'h0034, {16'd44, 16'd4400});
            apb_write(16'h0038, {16'd4096, 16'd148});
            apb_write(16'h003c, {16'd5, 16'd650});
            apb_write(16'h0040, {16'd608, 16'd36});

            // META_CFG0: start=1, base_format=RGBA8888
            apb_write(16'h0018, 32'h0000_0001);
        end
    endtask

    sram_pdp_8192x128 u_otf_sram_bank_a (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_a_wen),
        .waddr (o_otf_sram_a_waddr),
        .wdata (o_otf_sram_a_wdata),
        .ren   (o_otf_sram_a_ren),
        .raddr (o_otf_sram_a_raddr),
        .rdata (i_otf_sram_a_rdata)
    );

    sram_pdp_8192x128 u_otf_sram_bank_b (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_b_wen),
        .waddr (o_otf_sram_b_waddr),
        .wdata (o_otf_sram_b_wdata),
        .ren   (o_otf_sram_b_ren),
        .raddr (o_otf_sram_b_raddr),
        .rdata (i_otf_sram_b_rdata)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW   (APB_AW),
        .APB_DW   (APB_DW),
        .AXI_AW   (AXI_AW),
        .AXI_DW   (AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW),
        .SB_WIDTH (SB_WIDTH)
    ) dut (
        .PCLK              (PCLK),
        .PRESETn           (PRESETn),
        .PSEL              (PSEL),
        .PENABLE           (PENABLE),
        .PADDR             (PADDR),
        .PWRITE            (PWRITE),
        .PWDATA            (PWDATA),
        .PREADY            (PREADY),
        .PSLVERR           (PSLVERR),
        .PRDATA            (PRDATA),
        .i_otf_clk         (i_otf_clk),
        .i_otf_rstn        (i_otf_rstn),
        .o_otf_vsync       (o_otf_vsync),
        .o_otf_hsync       (o_otf_hsync),
        .o_otf_de          (o_otf_de),
        .o_otf_data        (o_otf_data),
        .o_otf_fcnt        (o_otf_fcnt),
        .o_otf_lcnt        (o_otf_lcnt),
        .i_otf_ready       (i_otf_ready),
        .o_bank0_en        (o_bank0_en),
        .o_bank0_wen       (o_bank0_wen),
        .o_bank0_addr      (o_bank0_addr),
        .o_bank0_din       (o_bank0_din),
        .i_bank0_dout      (i_bank0_dout),
        .i_bank0_dout_vld  (i_bank0_dout_vld),
        .o_bank1_en        (o_bank1_en),
        .o_bank1_wen       (o_bank1_wen),
        .o_bank1_addr      (o_bank1_addr),
        .o_bank1_din       (o_bank1_din),
        .i_bank1_dout      (i_bank1_dout),
        .i_bank1_dout_vld  (i_bank1_dout_vld),
        .i_axi_clk         (i_axi_clk),
        .i_axi_rstn        (i_axi_rstn),
        .o_m_axi_arid      (o_m_axi_arid),
        .o_m_axi_araddr    (o_m_axi_araddr),
        .o_m_axi_arlen     (o_m_axi_arlen),
        .o_m_axi_arsize    (o_m_axi_arsize),
        .o_m_axi_arburst   (o_m_axi_arburst),
        .o_m_axi_arlock    (o_m_axi_arlock),
        .o_m_axi_arcache   (o_m_axi_arcache),
        .o_m_axi_arprot    (o_m_axi_arprot),
        .o_m_axi_arvalid   (o_m_axi_arvalid),
        .i_m_axi_arready   (i_m_axi_arready),
        .i_m_axi_rdata     (i_m_axi_rdata),
        .i_m_axi_rvalid    (i_m_axi_rvalid),
        .i_m_axi_rresp     (i_m_axi_rresp),
        .i_m_axi_rlast     (i_m_axi_rlast),
        .o_m_axi_rready    (o_m_axi_rready)
    );

    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        i_axi_clk = 1'b0;
        forever #2 i_axi_clk = ~i_axi_clk;
    end

    initial begin
        i_otf_clk = 1'b0;
        forever #3 i_otf_clk = ~i_otf_clk;
    end

    always @(posedge i_axi_clk) begin
        cycle_cnt <= cycle_cnt + 1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_bank0_dout_vld <= 1'b0;
            i_bank1_dout_vld <= 1'b0;
        end else begin
            i_bank0_dout_vld <= o_otf_sram_a_ren;
            i_bank1_dout_vld <= o_otf_sram_b_ren;
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_m_axi_arready   <= 1'b1;
            i_m_axi_rvalid    <= 1'b0;
            i_m_axi_rdata     <= {AXI_DW{1'b0}};
            i_m_axi_rresp     <= 2'b00;
            i_m_axi_rlast     <= 1'b0;
            axi_rsp_active    <= 1'b0;
            axi_rsp_is_meta   <= 1'b0;
            axi_rsp_addr      <= {AXI_AW{1'b0}};
            axi_rsp_beats_left<= 8'd0;
            axi_rsp_beat_idx  <= 8'd0;
            meta_ar_cnt       <= 0;
            tile_ar_cnt       <= 0;
            axi_rbeat_cnt     <= 0;
            last_progress_cycle <= 0;
        end else begin
            i_m_axi_rvalid <= 1'b0;
            i_m_axi_rlast  <= 1'b0;

            if (!axi_rsp_active) begin
                if (o_m_axi_arvalid && i_m_axi_arready) begin
                    axi_rsp_active     <= 1'b1;
                    axi_rsp_is_meta    <= (o_m_axi_araddr >= META_BASE_ADDR);
                    axi_rsp_addr       <= o_m_axi_araddr;
                    axi_rsp_beats_left <= o_m_axi_arlen + 1'b1;
                    axi_rsp_beat_idx   <= 8'd0;
                    last_progress_cycle <= cycle_cnt;
                    if (o_m_axi_araddr >= META_BASE_ADDR) begin
                        meta_ar_cnt <= meta_ar_cnt + 1;
                    end else begin
                        tile_ar_cnt <= tile_ar_cnt + 1;
                    end
                end
            end else begin
                i_m_axi_rvalid <= 1'b1;
                i_m_axi_rdata  <= pack_axi_word(axi_rsp_is_meta, axi_rsp_addr, axi_rsp_beat_idx);
                i_m_axi_rresp  <= 2'b00;
                i_m_axi_rlast  <= (axi_rsp_beats_left == 8'd1);
                if (o_m_axi_rready) begin
                    axi_rbeat_cnt <= axi_rbeat_cnt + 1;
                    last_progress_cycle <= cycle_cnt;
                    if (axi_rsp_beats_left == 8'd1) begin
                        axi_rsp_active     <= 1'b0;
                        axi_rsp_beats_left <= 8'd0;
                        axi_rsp_beat_idx   <= 8'd0;
                    end else begin
                        axi_rsp_beats_left <= axi_rsp_beats_left - 1'b1;
                        axi_rsp_beat_idx   <= axi_rsp_beat_idx + 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn) begin
            otf_de_beat_cnt <= 0;
        end else if (i_otf_ready && o_otf_de) begin
            otf_de_beat_cnt <= otf_de_beat_cnt + 1;
            last_progress_cycle <= cycle_cnt;
            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%0d %032h\n", o_otf_lcnt, o_otf_data);
            end
        end
    end

    initial begin
        $readmemh("tajmahal_meta.memh", meta_words);
        $readmemh("tajmahal_tile.memh", tile_words);

        if (^meta_words[0] === 1'bx) begin
            $fatal(1, "Failed to load tajmahal_meta.memh");
        end
        if (^tile_words[0] === 1'bx) begin
            $fatal(1, "Failed to load tajmahal_tile.memh");
        end

        PRESETn        = 1'b0;
        i_axi_rstn     = 1'b0;
        i_otf_rstn     = 1'b0;
        PSEL           = 1'b0;
        PENABLE        = 1'b0;
        PADDR          = {APB_AW{1'b0}};
        PWRITE         = 1'b0;
        PWDATA         = {APB_DW{1'b0}};
        i_otf_ready    = 1'b1;
        i_m_axi_arready= 1'b1;
        i_m_axi_rdata  = {AXI_DW{1'b0}};
        i_m_axi_rvalid = 1'b0;
        i_m_axi_rresp  = 2'b00;
        i_m_axi_rlast  = 1'b0;
        axi_rsp_active = 1'b0;
        axi_rsp_is_meta = 1'b0;
        axi_rsp_addr    = {AXI_AW{1'b0}};
        axi_rsp_beats_left = 8'd0;
        axi_rsp_beat_idx = 8'd0;
        meta_ar_cnt     = 0;
        tile_ar_cnt     = 0;
        axi_rbeat_cnt   = 0;
        otf_de_beat_cnt = 0;
        cycle_cnt       = 0;
        last_progress_cycle = 0;
        otf_fd          = 0;

        repeat (8) @(posedge i_axi_clk);
        PRESETn    = 1'b1;
        i_axi_rstn = 1'b1;
        i_otf_rstn = 1'b1;
        repeat (4) @(posedge i_axi_clk);

        otf_fd = $fopen("wrapper_tajmahal_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open wrapper_tajmahal_otf_stream.txt");
        end

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_wrapper_top TajMahal RGBA8888 vector smoke");
        $display("Meta vector : tajmahal_meta.memh");
        $display("Tile vector : tajmahal_tile.memh");
        $display("Image size  : %0dx%0d actual, %0dx%0d aligned", IMG_W, IMG_H_ACTUAL, IMG_W, IMG_H_ALIGNED);
        $display("==============================================================");

        program_wrapper_regs();
    end

    initial begin : finish_block
        integer timeout_cycles;
        timeout_cycles = 0;
        wait (PRESETn && i_axi_rstn && i_otf_rstn);
        repeat (100) @(posedge i_axi_clk);
        while ((otf_de_beat_cnt < EXPECTED_OTF_DE_BEATS) &&
               ((cycle_cnt - last_progress_cycle) <= 200000) &&
               (timeout_cycles < 5000000)) begin
            @(posedge i_axi_clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (otf_fd != 0) begin
            $fclose(otf_fd);
        end

        $display("Wrapper vector run summary:");
        $display("  meta AR count   : %0d", meta_ar_cnt);
        $display("  tile AR count   : %0d", tile_ar_cnt);
        $display("  AXI R beat count: %0d", axi_rbeat_cnt);
        $display("  OTF DE beats    : %0d", otf_de_beat_cnt);

        if (meta_ar_cnt == 0) begin
            $fatal(1, "No metadata AXI reads were observed.");
        end
        if (tile_ar_cnt == 0) begin
            $fatal(1, "No tile AXI reads were observed.");
        end
        if (axi_rbeat_cnt == 0) begin
            $fatal(1, "No AXI read data beats were observed.");
        end
        if (otf_de_beat_cnt == 0) begin
            $display("WARN: No active OTF DE beat was observed in this run.");
        end
        if (otf_de_beat_cnt < EXPECTED_OTF_DE_BEATS) begin
            $display("WARN: OTF DE beats did not reach one full aligned frame. got=%0d exp=%0d",
                     otf_de_beat_cnt, EXPECTED_OTF_DE_BEATS);
        end

        $display("PASS: wrapper_top consumed TajMahal meta/tile vectors.");
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_rgba8888);
        $fsdbDumpMDA(0, tb_ubwc_dec_wrapper_top_tajmahal_rgba8888);
`else
        $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.vcd");
        $dumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_rgba8888);
`endif
`endif
    end

endmodule
