/////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2018 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang jiawang.miao@magicip.com.cn
// Create Date       : 2019-10-05  07:54:38
// Design Name       :
// Module Name       : async_fifo_v1000.v
// Project Name      :
// Target Devices    :
// Tool versions     :
// Description       :
// Editor            : Gvim, tab size (4)
// Dependencies      :
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
//
//		Revision 1.01 - File Modified by	:
//		Description							:
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module mg_async_fifo
    #(
        parameter   AF          = 1         ,
        parameter   DATA_BITS   = 8         ,
        parameter   DEPTH_BITS  = 8         ,
        parameter   SHOW_AHEAD  = 0         ,
/* verilator lint_off UNUSEDPARAM */
        parameter   RAM_STYLE   = "block"
/* verilator lint_on UNUSEDPARAM */
    )(
        // write
        input   wire                        wr_clk          ,
        input   wire                        wr_rstn         ,
        input   wire                        wr_en           ,
        input   wire    [DATA_BITS-1:0]     din             ,
        output  reg     [DEPTH_BITS:0]      wr_data_count   ,
        output  reg                         prog_full       ,
        output  reg                         full            ,

        // read
        input   wire                        rd_clk          ,
        input   wire                        rd_rstn         ,
        input   wire                        rd_en           ,
        output  reg     [DATA_BITS-1:0]     dout            ,
        output  reg                         valid           ,
        output  reg     [DEPTH_BITS:0]      rd_data_count   ,
        output  wire                        pre_empty       ,
        output  reg                         empty
    );

    //------------------------Parameter----------------------

        localparam DEPTH = 1 << DEPTH_BITS;

    //------------------------Local signal-------------------
        (* ram_style = RAM_STYLE *)
        reg     [DATA_BITS-1:0]     mem[0:DEPTH-1]      ;

        wire                        fifo_rstn                ;
        wire                        wr_sync_rstn        ;
        wire                        rd_sync_rstn        ;

        reg     [3:0]               wr_sync_rstn_r      ;
        reg     [3:0]               rd_sync_rstn_r      ;

        wire                        full_next           ;
        wire                        empty_next          ;
        reg     [DEPTH_BITS:0]      wr_addr_bin         ;
        reg     [DEPTH_BITS:0]      rd_addr_bin         ;
        wire    [DEPTH_BITS-1:0]    wr_addr             ;
        wire    [DEPTH_BITS-1:0]    rd_addr             ;
        wire    [DEPTH_BITS:0]      wr_addr_bin_next    ;
        wire    [DEPTH_BITS:0]      rd_addr_bin_next    ;
        wire    [DEPTH_BITS:0]      wr_addr_gray_next   ;
        wire    [DEPTH_BITS:0]      rd_addr_gray_next   ;
        reg     [DEPTH_BITS:0]      wr_addr_gray_sync0  ;
        reg     [DEPTH_BITS:0]      rd_addr_gray_sync0  ;
        reg     [DEPTH_BITS:0]      wr_addr_gray_sync1  ;
        reg     [DEPTH_BITS:0]      rd_addr_gray_sync1  ;
        reg     [DEPTH_BITS:0]      wr_addr_gray_sync2  ;
        reg     [DEPTH_BITS:0]      rd_addr_gray_sync2  ;
        wire    [DEPTH_BITS:0]      wr_addr_bin_sync    ;
        wire    [DEPTH_BITS:0]      rd_addr_bin_sync    ;
        wire    [DEPTH_BITS:0]      full_mask           ;

   //------------------------Instantiation------------------

    //------------------------Body---------------------------

    assign  fifo_rstn        = wr_rstn & rd_rstn ;

    assign  pre_empty   = (rd_data_count >= 'd2)?1'b0:1'b1;
    assign  full_mask   = {{2{1'b1}}, {(DEPTH_BITS-1){1'b0}}};
    assign  full_next   = (wr_addr_gray_next == (rd_addr_gray_sync2 ^ full_mask));
    assign  empty_next  = (rd_addr_gray_next == wr_addr_gray_sync2);

    assign  wr_addr     = wr_addr_bin[DEPTH_BITS-1:0];
    generate
        if (SHOW_AHEAD) begin : gen_show_ahead_raddr
            assign  rd_addr  = rd_addr_bin_next[DEPTH_BITS-1:0];
        end else begin : gen_normal_raddr
            assign  rd_addr  = rd_addr_bin[DEPTH_BITS-1:0];
        end
    endgenerate

    assign  wr_addr_bin_next    = (~full  & wr_en)? wr_addr_bin + 1'b1 : wr_addr_bin;
    assign  rd_addr_bin_next    = (~empty & rd_en)? rd_addr_bin + 1'b1 : rd_addr_bin;

    assign  wr_addr_gray_next   = wr_addr_bin_next ^ (wr_addr_bin_next >> 1);
    assign  rd_addr_gray_next   = rd_addr_bin_next ^ (rd_addr_bin_next >> 1);

    // gray to bin
    assign wr_addr_bin_sync[DEPTH_BITS] = wr_addr_gray_sync2[DEPTH_BITS];
    assign rd_addr_bin_sync[DEPTH_BITS] = rd_addr_gray_sync2[DEPTH_BITS];

    genvar i;
    generate
        for (i = 0; i < DEPTH_BITS; i = i + 1) begin : gen_gray_to_bin
            assign  wr_addr_bin_sync[i] = wr_addr_gray_sync2[i] ^ wr_addr_bin_sync[i+1];
            assign  rd_addr_bin_sync[i] = rd_addr_gray_sync2[i] ^ rd_addr_bin_sync[i+1];
        end
    endgenerate

    assign  wr_sync_rstn        = wr_sync_rstn_r[3];

    always @(posedge wr_clk or negedge fifo_rstn) begin
        if (~fifo_rstn)
            wr_sync_rstn_r  <= 4'd0 ;
        else
            wr_sync_rstn_r  <= {wr_sync_rstn_r[2:0],1'b1};
    end

    // @ wr_clk domain
    // full, wr_addr_bin, wr_addr_gray_sync0, rd_addr_gray_sync1, rd_addr_gray_sync2
    always @(posedge wr_clk or negedge wr_sync_rstn) begin
        if (~wr_sync_rstn) begin
            prog_full           <= 1'b0;
            full                <= 1'b0;
            wr_addr_bin         <= {(DEPTH_BITS+1){1'b0}};
            wr_addr_gray_sync0  <= {(DEPTH_BITS+1){1'b0}};
            rd_addr_gray_sync1  <= {(DEPTH_BITS+1){1'b0}};
            rd_addr_gray_sync2  <= {(DEPTH_BITS+1){1'b0}};
        end
        else begin
            prog_full           <= (wr_data_count >= (2**DEPTH_BITS -1 -AF))?1'b1:1'b0;
            full                <= full_next;
            wr_addr_bin         <= wr_addr_bin_next;
            wr_addr_gray_sync0  <= wr_addr_gray_next;
            rd_addr_gray_sync1  <= rd_addr_gray_sync0;
            rd_addr_gray_sync2  <= rd_addr_gray_sync1;
        end
    end

    // mem
    always @(posedge wr_clk) begin
        if (~full & wr_en)
            mem[wr_addr] <= din;
    end

    // wr_data_count
    always @(posedge wr_clk or negedge wr_sync_rstn) begin
        if (~wr_sync_rstn)
            wr_data_count <= {(DEPTH_BITS+1){1'b0}};
        else
            wr_data_count <= wr_addr_bin_next - rd_addr_bin_sync;
    end

    assign  rd_sync_rstn    = rd_sync_rstn_r[3] ;

    always @(posedge rd_clk or negedge fifo_rstn) begin
        if (~fifo_rstn)
            rd_sync_rstn_r  <= 4'd0 ;
        else
            rd_sync_rstn_r  <= {rd_sync_rstn_r[2:0],1'b1};
    end

    // @ rd_clk domain
    // empty, rd_addr_bin, rd_addr_gray_sync0, wr_addr_gray_sync1, wr_addr_gray_sync2
    always @(posedge rd_clk or negedge rd_sync_rstn) begin
        if (~rd_sync_rstn) begin
            empty               <= 1'b1;
            rd_addr_bin         <= {(DEPTH_BITS+1){1'b0}};
            rd_addr_gray_sync0  <= {(DEPTH_BITS+1){1'b0}};
            wr_addr_gray_sync1  <= {(DEPTH_BITS+1){1'b0}};
            wr_addr_gray_sync2  <= {(DEPTH_BITS+1){1'b0}};
        end
        else begin
            empty               <= empty_next;
            rd_addr_bin         <= rd_addr_bin_next;
            rd_addr_gray_sync0  <= rd_addr_gray_next;
            wr_addr_gray_sync1  <= wr_addr_gray_sync0;
            wr_addr_gray_sync2  <= wr_addr_gray_sync1;
        end
    end

    // dout
    generate
        if (SHOW_AHEAD) begin : gen_show_ahead_q
            always @(posedge rd_clk) begin
                dout    <= mem[rd_addr];
            end
            always @(*) begin
                valid   = ~empty ;
            end
        end
        else begin : gen_normal_q
            always @(posedge rd_clk) begin
                if (~empty & rd_en) begin
                    dout    <= mem[rd_addr];
                    valid   <= 1'b1;
                end else begin
                    valid   <= 1'b0;
                end
            end
        end
    endgenerate

    // rd_data_count
    always @(posedge rd_clk or negedge rd_sync_rstn) begin
        if (~rd_sync_rstn)
            rd_data_count <= {(DEPTH_BITS+1){1'b0}};
        else
            rd_data_count <= wr_addr_bin_sync - rd_addr_bin_next;
    end

endmodule

/* MagicIP fifo instance example
    mg_async_fifo
    #(
        .AF                 ( 1                 ),
        .DATA_BITS          ( 8                 ),
        .DEPTH_BITS         ( 8                 ),
        .SHOW_AHEAD         ( 0                 ),
        .RAM_STYLE          ( "block"           )
    )
    (
        // write
        .wr_clk             ( wr_clk            ),
        .wr_rstn                     ( wr_rstn                      ),
        .wr_en              ( wr_en             ),
        .din                ( din               ),
        .wr_data_count      ( wr_data_count     ),
        .prog_full          ( prog_full         ),
        .full               ( full              ),

        // read
        .rd_clk             ( rd_clk            ),
        .rd_rstn                     ( rd_rstn                      ),
        .rd_en              ( rd_en             ),
        .dout               ( dout              ),
        .rd_data_count      ( rd_data_count     ),
        .pre_empty          ( pre_empty         ),
        .empty              ( empty             )
    );
*/
