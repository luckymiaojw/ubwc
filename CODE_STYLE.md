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

assign fire_a = fifo_a_vld && fifo_a_rdy;
assign fire_b = fifo_b_vld && fifo_b_rdy;
assign fifo_a_accept = fire_a && !block;

assign fifo_a_rdy = !block && fifo_a_can_fire;
assign fifo_b_rdy = !block && !fifo_a_can_fire && fifo_b_can_fire;
```

禁止写法：

```verilog
wire fire_a = fifo_a_vld && fifo_a_rdy;
wire fire_b = fifo_b_vld && fifo_b_rdy;
wire fifo_a_accept = fire_a && !block;
```

如果确实需要组合 `always @(*)`，也必须保持职责单一，避免一个块里同时给大量信号赋值。

### FSM 拆分

FSM 的 `state` 可以独立一个 always；与 FSM 相关的坐标、计数、valid、done 寄存器必须拆成各自的 always。公共判断条件先用命名清楚的 `wire` 收敛，例如：

```verilog
wire rd_start;
wire rd_done;

assign rd_start = rd_state_idle && bank_ready;
assign rd_done  = rd_state_act && last_word && last_tile;
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
