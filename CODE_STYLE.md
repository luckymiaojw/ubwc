# UBWC 代码规范

本文档是本工程自有代码的强制编码规范。后续所有新增代码、重构代码、bugfix 代码都必须按本文执行。

适用范围：

- `src/enc`、`src/dec` 下的项目自有 RTL。
- `vrf/src` 下的项目自有 testbench、driver、monitor、model。
- `ubwc_cfg`、`vrf/include` 下的项目自有 SV/C 配置代码。

例外范围：

- `src/ip/ubwc_x2x`、`src/ip/axi_2t1_int` 等第三方或工具生成 IP，默认保持原样。
- 如必须修改第三方 IP，修改部分也要尽量遵守本文规范，并在 commit/message 中说明原因。
- `*_apb_reg_blk.v` / `*_apb_reg_blk.sv` 属于寄存器映射模块，不强制执行“一个 always 只更新一个寄存器”。APB 寄存器复位默认值、APB 写 decode、读回 mux、跨时钟同步寄存器、地址 FIFO 指针/计数等，可以按寄存器组或功能组集中在一个时序块中，方便保持地址表和软件行为一致。

## RTL 模块结构顺序

项目自有 Verilog/SystemVerilog 模块必须按统一结构组织，便于 code review、lint 检查和后续维护。

推荐顺序：

1. `module` 声明
2. `parameter` / `localparam` 形式的模块参数
3. 端口列表
4. 模块内部 `localparam`
5. `wire` 声明
6. `reg` / `logic` 声明
7. 连续赋值 `assign`
8. 时序或组合 `always`
9. 子模块 `instance`
10. `endmodule`

如果使用 ANSI 风格端口，`parameter` 和端口列表可以放在 `module #(...) (...)` 头部，但模块体内部仍按 `localparam`、`wire`、`reg`、`assign`、`always`、`instance` 的顺序排列。

推荐骨架：

```verilog
module example_module #(
    parameter                                       DATA_W                  = 32
) (
    input   wire                                    clk                     ,
    input   wire                                    rst_n                   ,
    input   wire    [DATA_W              -1 :0]     i_data                  ,
    output  wire    [DATA_W              -1 :0]     o_data
);

localparam                                      IDLE                    = 1'b0;
localparam                                      ACT                     = 1'b1;

wire                                            fire                    ;
wire                                            next_valid              ;

reg                                             state                   ;
reg                                             data_valid              ;
reg         [DATA_W              -1 :0]         data_r                  ;

assign fire                         = data_valid;
assign next_valid                   = fire && (state == ACT);
assign o_data                       = data_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else if (fire)
        state <= ACT;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_valid <= 1'b0;
    else
        data_valid <= next_valid;
end

always @(posedge clk) begin
    if (fire)
        data_r <= i_data;
end

sub_module u_sub_module (
    .clk    ( clk  ),
    .rst_n  ( rst_n)
);

endmodule
```

禁止在模块中把 `wire/reg` 声明散落到 `assign`、`always` 或 instance 后面。确实因为工具兼容、generate 作用域或参数化结构需要局部声明时，只允许在对应的局部作用域内声明，并保持该作用域内部同样按先声明、后赋值、再实例化的顺序组织。

## 对齐与排版

项目自有 RTL 采用类似 `src/enc/ubwc_enc_wrapper_top.sv` 的按列对齐风格。排版目标是让端口方向、数据类型、位宽、信号名、连接表达式在纵向上能快速扫描。

强制要求：

- 使用 4 空格缩进，不使用硬 tab。
- 同一声明区域内，`parameter/localparam`、`input/output/inout`、`wire/reg/logic`、位宽、信号名、行尾 `,` 或 `;` 按列对齐。
- `parameter/localparam` 也必须按“关键字列、类型/位宽列、名字列、赋值列”对齐；不能只把 `=` 对齐而忽略位宽列和名字列。
- scalar 声明也必须保留“空位宽列”，不能写成 `wire demux_is_yuv420_uv;`。必须让 scalar 信号名和 vector 信号名落在同一列。
- `reg`、`logic`、`output reg`、memory array 声明也执行同一规则；memory array 的 array range 跟随 signal name，不挤进位宽列。
- 位宽表达式内部也必须对齐，`:` 要落在固定列。推荐写法是 `[AXI_DW              -1 :0]`、`[TW_DW                 :0]`、`[CORE_AXI_DW/8      -1 :0]`，不要写成 `[AXI_DW-1:0]` 或 `[TW_DW:0]`。同一声明区域内，不管是常量宽度还是参数宽度，`:` 都必须在同一列。
- 子模块 parameter override 和 port map 必须一行一个连接，端口名列、左括号列、连接表达式列、右括号列对齐。
- 子模块 port map 处禁止直接写组合表达式。端口连接必须接命名清楚的 `wire/reg/logic` 信号或简单常量；拼接、截位补位、取反、位选择、逻辑运算、比较、三目选择等组合关系必须提前用独立 `assign` 展开。
- `assign` 左侧禁止拼接解包。不能写 `assign {field_a, field_b} = bus;`；必须拆成一条 assign 一个左值，右侧用固定 bit range / part-select 解包。
- 空连接也保留对齐后的括号位置，便于看出该端口是有意悬空。
- 连续 `assign` 必须按列对齐：`assign` 关键字、左值、`=`、右值起始位置分别对齐。不能写成多行 `=` 参差不齐的形式。
- 多行三目或优先级表达式不能把 `=` 单独放在行尾。第一项表达式必须和 `assign lhs =` 同行，后续条件和最后默认项按表达式起始列对齐。
- 禁止同一个文件里混用 tab 对齐和空格对齐。

推荐写法：

```verilog
input   wire    [DATA_W              -1 :0]      i_data              ,
output  wire                                o_valid             ,

localparam  [4                     :0]     FMT_RGBA8888            = 5'd0;
localparam  integer                         DATA_FIFO_DEPTH         = 16;

wire        [ADDR_W              -1 :0]    addr_next               ;
wire                                        demux_is_yuv420_uv      ;
wire                                        data_fire               ;

reg         [40                    :0]     payload_hold            ;
reg                                         payload_valid           ;
reg         [DATA_W              -1 :0]    data_mem [0:DEPTH-1]    ;

assign data_fire                  = i_valid && o_ready;
assign addr_next                  = addr_r + {{(ADDR_W-1){1'b0}}, 1'b1};
assign selected_rdata             = (lane_sel == 2'd0) ? data_bus[ 63:  0] :
                                    (lane_sel == 2'd1) ? data_bus[127: 64] :
                                    (lane_sel == 2'd2) ? data_bus[191:128] :
                                                         data_bus[255:192];

sub_module
#(
    .DATA_W                     ( DATA_W                        )
)
u_sub_module
(
    .clk                        ( clk                           ),
    .rst_n                      ( rst_n                         ),
    .i_data                     ( i_data                        ),
    .o_data                     (                               )
);
```

禁止写法：

```verilog
mg_sync_fifo
#(
    .PROG_DEPTH                 ( 1                             ),
    .DWIDTH                     ( OUT_FIFO_W                    ),
    .DEPTH                      ( 32                            ),
    .SHOW_AHEAD                 ( 1                             )
)
u_meta_data_fifo
(
    .clk                        ( clk                           ),
    .rst_n                      ( rst_n                         ),
    .sclr                       ( start                         ),
    .wr_en                      ( out_fifo_wr_en                ),
    .din                        ( {selected_rdata, rsp_meta_format, rsp_meta_xcoord, rsp_meta_ycoord, r_meta_fcnt} )
);
```

推荐写法：

```verilog
wire        [OUT_FIFO_W           -1 :0]          meta_data_fifo_din         ;
wire        [META_AW              -1 :0]          meta_addr                  ;
wire        [3                       :0]          meta_fcnt                  ;

assign meta_data_fifo_din          = {selected_rdata,
                                      rsp_meta_format,
                                      rsp_meta_xcoord,
                                      rsp_meta_ycoord,
                                      r_meta_fcnt};
assign meta_addr                   = meta_addr_fifo_dout[0 +: META_AW];
assign meta_fcnt                   = meta_addr_fifo_dout[META_ADDR_FIFO_W-1 -: 4];

mg_sync_fifo
#(
    .PROG_DEPTH                 ( 1                             ),
    .DWIDTH                     ( OUT_FIFO_W                    ),
    .DEPTH                      ( 32                            ),
    .SHOW_AHEAD                 ( 1                             )
)
u_meta_data_fifo
(
    .clk                        ( clk                           ),
    .rst_n                      ( rst_n                         ),
    .sclr                       ( start                         ),
    .wr_en                      ( out_fifo_wr_en                ),
    .din                        ( meta_data_fifo_din            )
);
```

## FIFO 使用规范

项目自有同步 FIFO 默认统一使用 `src/ip/mg_sync_fifo.v`。禁止新增 `*_simple_fifo`、`*_sync_fifo` 等临时自写 FIFO，除非有明确的 SRAM macro、时序、协议差异，并在模块注释中说明不能复用 `mg_sync_fifo` 的原因。

替换旧 FIFO 时注意参数口径：

- 旧 FIFO 如果使用 `AWIDTH` 表示深度，替换为 `mg_sync_fifo` 时使用 `DEPTH = 1 << AWIDTH`。
- 旧 FIFO 如果使用绝对阈值 `PROG_FULL_LEVEL`，替换为 `mg_sync_fifo` 时使用 `PROG_DEPTH = DEPTH - PROG_FULL_LEVEL - 1`。
- 需要 FWFT/show-ahead 行为时，`SHOW_AHEAD` 必须配置为 `1`。
- 未使用的 `valid` / `data_count` 端口可以有意空接，但端口位置仍需按列对齐。

## RTL 时序代码

### 一变量一 Always

强制要求：一个时序寄存器只能由一个 `always @(posedge ... or negedge ...)` 块驱动；一个时序 `always` 块原则上只更新一个寄存器。

禁止把多个状态寄存器、计数器、标志位揉在同一个巨大 `always` 块里。FSM 状态、坐标计数、valid 标志、fcnt、done 标志、pipeline 寄存器等，都要拆成独立 always。

例外：`*_apb_reg_blk` 模块不按“一变量一 Always”强制检查。APB reg block 允许按寄存器地址段、软件配置事务、CDC 同步组、状态读回组来组织 always，但仍必须保证同一个寄存器只有一个驱动源，不能把真实数据通路/FSM 流水线逻辑混进 APB 配置块。

推荐写法：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tile_x <= 16'd0;
    else if (tile_done)
        tile_x <= 16'd0;
    else if (tile_advance)
        tile_x <= tile_x + 16'd1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tile_y <= 16'd0;
    else if (frame_start)
        tile_y <= 16'd0;
    else if (line_done)
        tile_y <= tile_y + 16'd1;
end
```

禁止写法：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tile_x <= 16'd0;
        tile_y <= 16'd0;
        frame_done <= 1'b0;
        state <= IDLE;
    end else begin
        ...
    end
end
```

### 组合逻辑

优先使用 `wire` 和 `assign` 表达组合逻辑。不要为了生成多个组合输出写一个巨大的 `always @(*)`。

强制要求：`wire` 声明和组合赋值必须分离。禁止使用 `wire signal = expr;` 这种声明即赋值的写法。统一写成先声明，再单独 `assign`。

推荐写法：

```verilog
wire fire_a;
wire fire_b;
wire fifo_a_accept;

assign fire_a                     = fifo_a_vld && fifo_a_rdy;
assign fire_b                     = fifo_b_vld && fifo_b_rdy;
assign fifo_a_accept              = fire_a && !block;

assign fifo_a_rdy                 = !block && fifo_a_can_fire;
assign fifo_b_rdy                 = !block && !fifo_a_can_fire && fifo_b_can_fire;
```

禁止写法：

```verilog
wire fire_a = fifo_a_vld && fifo_a_rdy;
wire fire_b = fifo_b_vld && fifo_b_rdy;
wire fifo_a_accept = fire_a && !block;
```

如果确实需要组合 `always @(*)`，也必须保持职责单一，避免一个块里同时给大量信号赋值。

### Function 使用限制

项目自有 RTL 默认不新增 `function` 数据通路代码。简单连线、重命名、截位、补位、常量选择、位宽转换都必须直接用 `assign`、位选择、拼接或清晰命名的中间 `wire` 表达，不允许包一层 function。

禁止写法：

```verilog
function [3:0] axi_id_to_fcnt;
    input [ID_WIDTH-1:0] axi_id;
    begin
        axi_id_to_fcnt = axi_id;
    end
endfunction

assign meta_fcnt                   = axi_id_to_fcnt(m_axi_rid);
```

推荐写法：

```verilog
assign meta_fcnt                   = m_axi_rid[3:0];
```

如果逻辑复杂到必须复用，也优先拆成独立模块、明确流水级，或用命名清楚的组合 `wire/assign` 分段展开。确实需要保留 `function` 时，必须满足以下条件：不含运行期除法/取模/乘法等重逻辑、不隐藏跨拍状态、不隐藏握手路径，并在代码注释中说明为什么不能用直连或独立模块表达。

### FSM 拆分

FSM 的 `state` 可以独立一个 always；与 FSM 相关的坐标、计数、valid、done 寄存器必须拆成各自的 always。公共判断条件先用命名清楚的 `wire` 收敛，例如：

```verilog
wire rd_start;
wire rd_done;

assign rd_start                   = rd_state_idle && bank_ready;
assign rd_done                    = rd_state_act && last_word && last_tile;
```

然后各寄存器只引用这些事件信号，避免每个 always 重复嵌套复杂 case/if。

### Pipeline 寄存器

即使是同一拍锁存的一组 pipeline 信号，也按一变量一 always 拆开：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pipe_valid <= 1'b0;
    else
        pipe_valid <= fire;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pipe_fcnt <= 4'd0;
    else if (fire)
        pipe_fcnt <= in_fcnt;
end
```

## 声明风格

寄存器声明一行一个变量，便于查找驱动关系：

```verilog
reg [15:0] tile_x;
reg [15:0] tile_y;
reg        frame_done;
```

不要写成：

```verilog
reg [15:0] tile_x, tile_y;
reg        frame_done, frame_busy;
```

## 算术表达式

项目自有 RTL 中，运行期逻辑避免直接使用乘法、除法、取模。若数值关系固定为 2 的幂，优先使用位拼接表达固定 stride/offset。确实需要非 2 的幂计算时，必须明确说明综合意图，并优先在 APB 配置或软件侧预计算。

## 修改检查

每次修改 RTL 后至少执行：

```bash
git diff --check
```

涉及 ENC wrapper：

```bash
cd src/flist
verilator --lint-only --timing -Wno-fatal --top-module ubwc_enc_wrapper_top -f filelist_enc.f
```

涉及 DEC wrapper：

```bash
cd src/flist
verilator --lint-only --timing -Wno-fatal --top-module ubwc_dec_wrapper_top -f filelist.f
```
