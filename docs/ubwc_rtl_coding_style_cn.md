# UBWC RTL 编码规范

本文档细化根目录 `CODE_STYLE.md` 中的 RTL 编码规则。后续所有项目自有 RTL 和验证代码修改，除明确例外外，都必须遵守“一变量一 Always”的编码规范。

## 核心规则

1. 一个寄存器只允许一个 `always @(posedge ... or negedge ...)` 驱动。
2. 一个时序 `always` 原则上只更新一个寄存器。
3. 禁止把 FSM 状态、计数器、坐标、valid、done、fcnt、pipeline 字段揉在同一个大 always 块中。
4. 公共条件先提成命名清晰的 `wire`，各寄存器 always 只消费这些事件信号。
5. 组合逻辑优先使用 `wire/assign`，避免多输出组合 always。
6. 寄存器声明一行一个变量。
7. `wire` 声明和组合赋值必须分离，禁止 `wire signal = expr;`；统一使用 `wire signal;` 加 `assign signal = expr;`。

## 例外：APB Register Block

`*_apb_reg_blk.v` / `*_apb_reg_blk.sv` 是软件可见寄存器映射模块，不强制执行“一个 always 只更新一个寄存器”。

允许按以下功能组集中组织 always：

- APB 寄存器复位默认值和 APB 写 decode。
- 软件配置事务相关的地址 FIFO 指针、计数、push/pop。
- APB clock 和 core/axi clock 之间的同步寄存器组。
- 状态/统计寄存器读回同步组。

约束仍然保留：同一个寄存器只能有一个驱动源；真实数据通路、FSM 流水线、OTF/AXI payload 处理逻辑不能借 APB 例外混进大 always。

## 推荐模板

```verilog
wire start_event;
wire done_event;

assign start_event = state_idle && cfg_valid;
assign done_event  = state_busy && last_beat;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else if (start_event)
        state <= BUSY;
    else if (done_event)
        state <= DONE;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        beat_cnt <= 16'd0;
    else if (start_event)
        beat_cnt <= 16'd0;
    else if (beat_fire)
        beat_cnt <= beat_cnt + 16'd1;
end
```

## 禁止模板

```verilog
wire start_event = state_idle && cfg_valid;
wire done_event  = state_busy && last_beat;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        beat_cnt <= 16'd0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            ...
        endcase
    end
end
```

## 代码审查检查项

- 是否存在一个时序 always 同时更新多个寄存器？
  - `*_apb_reg_blk` 可按功能组例外处理。
- 是否存在一个寄存器被多个 always 驱动？
- 是否存在巨大 `always @(*)` 同时生成多个组合输出？
- 是否存在 `wire signal = expr;` 声明即赋值写法？应改成 `wire signal; assign signal = expr;`。
- FSM 状态、计数器、valid/done 是否拆开？
- pipeline 字段是否拆成一字段一个 always？
- 寄存器声明是否一行一个变量？
- 项目自有 RTL 是否避免运行期乘法、除法、取模？
