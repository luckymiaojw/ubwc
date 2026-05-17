# RTL Coding Style

本文档只描述 Verilog/SystemVerilog 编码风格与可综合 RTL 写法约束。

不放在本文档里的内容：

- Git 分支、commit、push、merge 流程。
- lint、仿真、回归、CI 命令。
- 发布、评审、问题单、版本管理流程。
- 某个工程专用的 IP 选型策略，除非它直接影响端口连接或实例化风格。

这些内容应放在执行规范、验证规范、README 或项目流程文档中。

## 基本原则

- 代码优先服务于可读性、可维护性、lint 友好和 ASIC/FPGA 综合稳定性。
- 所有自有 RTL 遵守同一套结构、对齐、命名和 always 拆分规则。
- 第三方 IP、工具生成代码默认保持原样；自有 wrapper 或胶水代码仍按本文执行。
- 寄存器映射模块可以有特殊组织方式，但真实数据通路和复杂 FSM 不应混入寄存器块。

## 模块结构顺序

自有 RTL 模块按如下顺序组织：

1. `module` 声明
2. `parameter` 参数
3. 端口列表
4. 模块内部 `localparam`
5. `wire` / net 声明
6. `reg` / `logic` 声明
7. 连续赋值 `assign`
8. `always` 时序或组合逻辑
9. 子模块 instance
10. `endmodule`

ANSI 风格端口允许把 parameter 和端口写在 module 头部，模块体内部仍按
`localparam`、`wire`、`reg`、`assign`、`always`、`instance` 排列。

推荐骨架：

```verilog
module example_module
#(
    parameter                                       DATA_W                  = 32
)
(
    input   wire                                    clk                     ,
    input   wire                                    rst_n                   ,
    input   wire    [DATA_W              -1 :0]     i_data                  ,
    input   wire                                    i_valid                 ,
    output  wire                                    i_ready                 ,
    output  wire    [DATA_W              -1 :0]     o_data                  ,
    output  wire                                    o_valid
);

localparam                                          ST_IDLE                 = 1'b0;
localparam                                          ST_ACT                  = 1'b1;

wire                                                in_fire                 ;
wire                                                state_is_act            ;

reg                                                 state_r                 ;
reg                                                 data_valid_r            ;
reg         [DATA_W              -1 :0]             data_r                  ;

assign in_fire                       = i_valid && i_ready;
assign state_is_act                  = (state_r == ST_ACT);
assign i_ready                       = state_is_act;
assign o_data                        = data_r;
assign o_valid                       = data_valid_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state_r <= ST_IDLE;
    else if (in_fire)
        state_r <= ST_ACT;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_valid_r <= 1'b0;
    else
        data_valid_r <= in_fire;
end

always @(posedge clk) begin
    if (in_fire)
        data_r <= i_data;
end

sub_module
#(
    .DATA_W                         ( DATA_W                        )
)
u_sub_module
(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .i_data                         ( data_r                        )
);

endmodule
```

## 对齐与排版

### 通用排版

- 使用 4 空格缩进，不使用硬 tab。
- 同一声明区域内，关键字、位宽、信号名、赋值符号、行尾 `,` 或 `;` 按列对齐。
- `parameter`、`localparam`、`wire`、`reg`、`logic`、端口声明都使用同一套列对齐规则。
- scalar 信号也保留空位宽列，使信号名与 vector 信号名落在同一列。
- 一行只声明一个信号，不把多个变量写在同一行。
- 文件中避免连续多个空行；一个空行用于分隔逻辑区域即可。

推荐：

```verilog
localparam                                          FMT_RGBA8888            = 5'd0;
localparam                                          FMT_YUV420_8            = 5'd1;
localparam  [4                    :0]              FMT_YUV420_10           = 5'd2;

wire                                                data_fire               ;
wire        [ADDR_W              -1 :0]             addr_next               ;
wire        [DATA_W              -1 :0]             fifo_wdata              ;

reg                                                 payload_valid_r         ;
reg         [40                   :0]               payload_hold_r          ;
reg         [DATA_W              -1 :0]             data_mem [0:DEPTH-1]    ;
```

不推荐：

```verilog
wire data_fire;
wire [ADDR_W-1:0] addr_next;
reg [15:0] tile_x, tile_y;
```

### 位宽写法

- 位宽表达式内部也要按列对齐，冒号 `:` 落在固定列。
- 推荐写 `[DATA_W              -1 :0]`，不要写 `[DATA_W-1:0]`。
- 常量位宽和参数位宽在同一区域内也要保持冒号列一致。

推荐：

```verilog
wire        [AXI_DW              -1 :0]             axi_wdata               ;
wire        [AXI_DW/8            -1 :0]             axi_wstrb               ;
wire        [TW_DW                  :0]             tile_x_ext              ;
wire        [7                    :0]               byte_data               ;
```

### assign 对齐

- `assign` 关键字、左值、`=`、右值起始位置按列对齐。
- 多行三目表达式第一项和 `assign lhs =` 同行，后续条件与默认项按表达式起始列对齐。
- `wire signal = expr;` 禁止使用，必须先声明再单独 `assign`。

推荐：

```verilog
wire                                                fifo_a_push             ;
wire                                                fifo_b_push             ;
wire        [63                   :0]               selected_rdata          ;

assign fifo_a_push                   = fifo_a_valid && fifo_a_ready;
assign fifo_b_push                   = fifo_b_valid && fifo_b_ready;
assign selected_rdata                = (lane_sel == 2'd0) ? rdata[ 63:  0] :
                                       (lane_sel == 2'd1) ? rdata[127: 64] :
                                       (lane_sel == 2'd2) ? rdata[191:128] :
                                                            rdata[255:192];
```

禁止：

```verilog
wire fifo_a_push = fifo_a_valid && fifo_a_ready;

assign selected_rdata =
    (lane_sel == 2'd0) ? rdata[63:0] :
    rdata[255:192];
```

### assign 解包

`assign` 左侧禁止拼接解包。左边必须是一个信号，右边用固定 bit range 或 part-select。

禁止：

```verilog
assign {
    cmd_addr,
    cmd_fcnt
} = cmd_fifo_dout;
```

推荐：

```verilog
assign cmd_fcnt                      = cmd_fifo_dout[0 +: 4];
assign cmd_addr                      = cmd_fifo_dout[CMD_FIFO_W-1 -: ADDR_W];
```

## 子模块实例化

- 子模块 parameter override 和 port map 一行一个连接。
- parameter 名、端口名、左括号、连接表达式、右括号按列对齐。
- port map 中禁止直接写组合表达式。
- 拼接、截位补位、取反、比较、三目、逻辑运算必须提前用命名清楚的 wire/assign 展开。
- 空接端口也保留对齐后的括号位置，表示有意不连接。

禁止：

```verilog
mg_sync_fifo
#(
    .DWIDTH                         ( OUT_FIFO_W                    )
)
u_fifo
(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n && !start               ),
    .wr_en                          ( valid && ready                ),
    .din                            ( {data, fcnt}                  ),
    .dout                           ( fifo_dout                     )
);
```

推荐：

```verilog
wire                                                fifo_wr_en              ;
wire        [OUT_FIFO_W          -1 :0]             fifo_din                ;
wire                                                rst_n_clean             ;

assign fifo_wr_en                    = valid && ready;
assign fifo_din                      = {data, fcnt};
assign rst_n_clean                   = rst_n;

mg_sync_fifo
#(
    .DWIDTH                         ( OUT_FIFO_W                    )
)
u_fifo
(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n_clean                   ),
    .wr_en                          ( fifo_wr_en                    ),
    .din                            ( fifo_din                      ),
    .dout                           ( fifo_dout                     )
);
```

## 时序 always 规则

### 一变量一 always

- 一个寄存器只能由一个 `always` 块驱动。
- 一个时序 `always` 块原则上只更新一个寄存器。
- 不把多个状态寄存器、计数器、valid、done、数据寄存器揉在同一个巨大 always 中。
- FSM 状态、坐标计数、valid 标志、done 标志、pipeline 字段分别拆开。

推荐：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tile_x_r <= 16'd0;
    else if (line_done)
        tile_x_r <= 16'd0;
    else if (tile_advance)
        tile_x_r <= tile_x_r + 16'd1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tile_y_r <= 16'd0;
    else if (frame_start)
        tile_y_r <= 16'd0;
    else if (line_done)
        tile_y_r <= tile_y_r + 16'd1;
end
```

禁止：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tile_x_r <= 16'd0;
        tile_y_r <= 16'd0;
        state_r  <= ST_IDLE;
        done_r   <= 1'b0;
    end else begin
        ...
    end
end
```

### 寄存器映射模块例外

APB/CSR register block 可以按寄存器地址段、软件事务、CDC 同步组、读回 mux 分组组织 always。

但仍必须满足：

- 同一个寄存器只有一个驱动源。
- 不把真实数据通路和复杂 FSM 混入寄存器映射模块。
- 寄存器默认值、W1C/W1P/RW/RO 行为要清楚可追踪。

### Pipeline 数据寄存器

同一拍锁存的一组 pipeline 字段也按一变量一 always 拆开。控制类 valid 必须复位；纯数据类寄存器如果由 valid 门控，下游不会在 invalid 时使用，可以不加复位。

推荐：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pipe_valid_r <= 1'b0;
    else
        pipe_valid_r <= in_fire;
end

always @(posedge clk) begin
    if (in_fire)
        pipe_data_r <= i_data;
end
```

## 组合逻辑规则

- 优先使用 `wire` + `assign` 表达组合逻辑。
- 不为了生成多个组合输出写巨大的 `always @(*)`。
- 如果必须使用组合 always，职责必须单一，并在块开头给所有输出默认值。
- 不允许组合逻辑驱动异步复位端。
- 不允许把长 ready 路径从下游经复杂组合逻辑反推回上游；需要用 skid buffer 或寄存器切断。

推荐事件收敛：

```verilog
wire                                                rd_start                ;
wire                                                rd_done                 ;

assign rd_start                     = rd_state_idle && bank_ready;
assign rd_done                      = rd_state_act && last_word && last_tile;
```

然后各寄存器只引用这些事件信号。

## Function 使用限制

自有 RTL 默认不新增 function 数据通路代码。

简单连线、重命名、截位、补位、常量选择、位宽转换必须直接使用 `assign`、位选择、拼接或中间 wire 表达。

禁止：

```verilog
function [3:0] axi_id_to_fcnt;
    input [ID_WIDTH-1:0] axi_id;
    begin
        axi_id_to_fcnt = axi_id;
    end
endfunction

assign meta_fcnt                    = axi_id_to_fcnt(m_axi_rid);
```

推荐：

```verilog
assign meta_fcnt                    = m_axi_rid[3:0];
```

确实需要 function 时必须满足：

- 不包含运行期乘法、除法、取模。
- 不隐藏跨拍状态或握手路径。
- 不把复杂数据通路藏在函数里。
- 注释说明为什么不能用 assign 分段或独立模块表达。

## 算术表达式

- 自有 RTL 运行期逻辑避免直接使用 `*`、`/`、`%`。
- 固定 2 的幂关系用位选择、位拼接、固定左移/右移表达。
- 更推荐把 stride、pitch、base offset 等复杂计算在配置阶段或软件侧预计算。
- 必须支持非 2 的幂运算时，使用明确的多周期模块或流水线 IP，不写单周期组合除法器/取模器。
- 简单 `+1` 计数优先使用增量寄存器，不每拍重算大加法树。

推荐：

```verilog
assign line_base_next               = line_base_r + line_stride;
assign word_addr_next               = word_addr_r + {{(ADDR_W-1){1'b0}}, 1'b1};
```

## 复位规则

- 异步复位输入只能接纯净复位信号，不接组合表达式。
- 禁止 `.rst_n(rst_n && !start)` 这类组合复位写法。
- 跨时钟域复位释放必须在目标时钟域同步。
- 控制寄存器、FSM state、valid、计数器、done/error sticky 标志需要复位。
- 纯数据通路寄存器如果有 valid 保护，可以不复位，避免额外 reset mux 和 reset tree 负担。

推荐：

```verilog
wire                                                fifo_rst_n              ;

assign fifo_rst_n                   = rst_n_sync;

mg_sync_fifo u_fifo
(
    .clk                            ( clk                           ),
    .rst_n                          ( fifo_rst_n                    )
);
```

## 接口边界

- 模块边界输出尽量寄存器化，尤其是宽数据总线、SRAM 控制、跨层级 ready/valid 路径。
- SRAM macro 的 `en`、`wen`、`addr`、`din` 等输入建议寄存器化，避免毛刺风险。
- 不在模块端口处直接输出宽组合 mux 的结果。
- ready/valid 接口避免由输入 payload 数据直接组合生成 ready。

## 命名建议

- 输入端口使用 `i_` 前缀，输出端口使用 `o_` 前缀。
- AXI/APB 等标准接口可以保留协议命名，如 `m_axi_awvalid`、`s_apb_paddr`。
- 时序寄存器建议使用 `_r` 后缀。
- 下一拍组合值建议使用 `_n` 或 `_next` 后缀。
- one-cycle 事件建议使用 `_pulse`、`_fire`、`_hit`。
- ready/valid 握手事件统一命名为 `xxx_fire = xxx_valid && xxx_ready`。
- active-low reset 统一使用 `rst_n` 或带域名的 `rst_n_sys`、`rst_n_otf`。

## 注释

- 注释解释“为什么这样做”，不要重复代码表面含义。
- 对协议边界、CDC、reset、地址 layout、stride、ping-pong slot 切换等关键设计点保留简短注释。
- 临时 workaround 必须标注原因和移除条件。
