# Detailed Implementation Strategy

The core idea of this design is **data-flow driven execution** and **decoupled mapping**. By layering data reception, parsing, address mapping, and synchronization triggers, it implements a multiplier-free high-throughput pipeline.

## 1. FIFO and Format Bundling

In multi-plane video streams, such as interleaved YUV, directly using top-level sideband signals to control the core FSM can cause timing misalignment. Therefore, the 256-bit Tile data, the `TLAST` signal, and the 5-bit `i_ci_format` signal are concatenated into a 262-bit bus and pushed into a synchronous FIFO together.

When data is popped from the FIFO, the accompanying Format signal is naturally aligned with the current Tile. The Format Decoder is pure combinational logic and immediately decodes the current Tile properties, such as dimensions and shift parameters, for later pipeline stages.

## 2. DSP-Free Address Mapping

When scattering 2D Tile data into 1D SRAM, the traditional formula is $Addr = Base + Y \times Stride + X$, which usually consumes DSP or hardware multiplier resources.

To optimize area and target a very high clock frequency, this design uses a **hard-wired shift method**:

* For every format on the 128-bit SRAM interface, one Tile always equals 16 writes.
* The `px_shift` and `is_y_stride_1k` control bits from the Format Decoder fix the row stride to either 1024 words or 256 words ($2^{10}$ or $2^{8}$).
* Address calculation concatenates `y_in_tile` with `10'd0` instead of multiplying, and uses `px_cnt >> px_shift` instead of dividing. This keeps combinational delay very low.

## 3. Robust Unaligned Cropping and TLAST Safeguard

In real use cases, `cfg_img_width`, such as 1920, is often not divisible by the Tile width, such as 32.

Instead of adding complex padding-removal logic, the design **accepts all incoming data** and writes redundant padding directly into unused space at the end of each SRAM row.

The core FSM forces a line wrap by checking `(px_cnt + tile_w_pixels >= cfg_img_width)`. It also introduces `current_tlast` as a Tile-end alignment guard so that even if the upstream stream slips by one bit, the next Tile can recover automatically and the FSM will not deadlock.

## 4. Multi-Planar Synchronization

For YUV420 and YUV422 formats, multiple planes must be collected before a line can be output.

The design introduces independent row accumulators, `y_row_cnt` and `uv_row_cnt`. The Format Decoder dynamically emits the completion conditions for the current format: `req_y_rows` and `req_uv_rows`.

Whenever a full Tile row is written, only the counter for the corresponding plane is incremented. Only when both Y and UV reach their respective targets does `trigger_switch` assert, triggering the ping-pong switch and asserting `buffer_vld`. This event-driven mechanism is robust against out-of-order or interleaved Y/UV packets on the AXI bus.
