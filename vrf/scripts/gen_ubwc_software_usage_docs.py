#!/usr/bin/env python3
"""Generate UBWC Chinese software usage HTML and DOCX documents."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
HTML_OUT = DOCS / "ubwc_software_usage_cn.html"
DOCX_OUT = DOCS / "ubwc_software_usage_cn.docx"


FORMAT_ROWS = [
    ("RGBA8888", "0", "16", "4", "单平面 RGBA，4 byte/pixel"),
    ("RGBA1010102", "1", "16", "4", "单平面 RGBA，4 byte/pixel"),
    ("YUV420_8 / NV12", "2", "32", "8", "Y + UV 双平面"),
    ("YUV420_10 / P010", "3", "32", "4", "Y + UV 双平面，16 bit component 存储"),
]


ENC_CONFIG_ROWS = [
    ("0x000", "VERSION", "上电后读取一次", "只读"),
    ("0x004", "DATE", "上电后读取一次", "只读"),
    ("0x060[0]", "IRQ enable", "上电后或中断策略变化时配置", "寄存器复位值 0；需要中断时软件写 1"),
    ("0x00C", "REG_TILE_CFG1: 4-line/lossy/tile_pitch", "更改图像格式时配置", "按格式计算"),
    ("0x008", "REG_TILE_CFG0: ubwc/bank/swizzle", "更改图像格式时配置", "按系统策略"),
    ("0x014", "REG_ENC_CI_CFG1: lossy", "更改图像格式时配置", "0 或按格式"),
    ("0x018", "REG_ENC_CI_CFG2: reserved cfg", "更改图像格式时配置", "0"),
    ("0x01C", "REG_ENC_CI_CFG3: reserved cfg", "更改图像格式时配置", "0"),
    ("0x010", "REG_ENC_CI_CFG0: input_type/alen", "更改图像格式时配置", "寄存器复位值 0；普通 tiled UBWC 路径软件写 input_type=1、alen=7"),
    ("0x024", "REG_OTF_CFG1: width/height", "更改图像格式时配置", "按图像尺寸"),
    ("0x028", "REG_OTF_CFG2: tile_w/tile_h", "更改图像格式时配置", "RGBA=16x4; YUV420_8=32x8; YUV420_10=32x4"),
    ("0x02C", "REG_OTF_CFG3: tile columns", "更改图像格式时配置", "[15:0] y_tile_cols；[31:16] uv_tile_cols，RGBA 的 uv 写 0"),
    ("0x050", "REG_META_ACTIVE_SIZE", "更改图像格式时配置", "按图像尺寸"),
    ("0x054", "REG_META_PITCH", "更改图像格式时配置", "按格式/宽度计算"),
    ("0x020", "REG_OTF_CFG0: format", "更改图像格式时配置", "0/1/2/3"),
    ("0x030", "REG_META_BASE_Y_LO", "每次配置", "压缩后 Y metadata 存储基地址低 32 bit；RGBA 使用该槽位"),
    ("0x034", "REG_META_BASE_Y_HI", "每次配置", "压缩后 Y metadata 存储基地址高 32 bit；RGBA 使用该槽位"),
    ("0x038", "REG_TILE_BASE_Y_LO", "每次配置", "压缩后 Y 压缩数据存储基地址低 32 bit；RGBA 使用该槽位"),
    ("0x03C", "REG_TILE_BASE_Y_HI", "每次配置", "压缩后 Y 压缩数据存储基地址高 32 bit；RGBA 使用该槽位"),
    ("0x040", "REG_META_BASE_UV_LO", "每次配置", "压缩后 UV metadata 存储基地址低 32 bit；RGBA 写 0"),
    ("0x044", "REG_META_BASE_UV_HI", "每次配置", "压缩后 UV metadata 存储基地址高 32 bit；RGBA 写 0"),
    ("0x048", "REG_TILE_BASE_UV_LO", "每次配置", "压缩后 UV 压缩数据存储基地址低 32 bit；RGBA 写 0"),
    ("0x04C", "REG_TILE_BASE_UV_HI", "每次配置", "压缩后 UV 压缩数据存储基地址高 32 bit；最后写入提交本帧地址组"),
]


DEC_CONFIG_ROWS = [
    ("0x000", "VERSION", "上电后读取一次", "只读"),
    ("0x004", "DATE", "上电后读取一次", "只读"),
    ("0x060[0]", "IRQ enable", "上电后或中断策略变化时配置", "寄存器复位值 0；需要中断时软件写 1"),
    ("0x008", "APB_ADDR_TILE_CFG0: swizzle/layout", "更改图像格式时配置", "按系统策略"),
    ("0x00C", "APB_ADDR_TILE_CFG1: tile pitch", "更改图像格式时配置", "按格式/宽度计算"),
    ("0x010", "APB_ADDR_TILE_CFG2: CI cfg", "更改图像格式时配置", "寄存器复位值 0；普通 tiled UBWC 路径软件写 input_type=1，其余按格式"),
    ("0x014", "APB_ADDR_VIVO_CFG", "更改图像格式时配置", "寄存器复位值 0；启动 decode 前软件写 vivo_ubwc_en=1"),
    ("0x018", "APB_ADDR_OTF_CFG0: img_width/format", "更改图像格式时配置", "按输出图像配置"),
    ("0x01C", "APB_ADDR_OTF_CFG1: h_total/h_sync", "更改图像格式时配置", "按 OTF timing 配置"),
    ("0x020", "APB_ADDR_OTF_CFG2: h_bp/h_act", "更改图像格式时配置", "按 OTF timing 配置"),
    ("0x024", "APB_ADDR_OTF_CFG3: v_total/v_sync", "更改图像格式时配置", "按 OTF timing 配置"),
    ("0x028", "APB_ADDR_OTF_CFG4: v_bp/v_act", "更改图像格式时配置", "按 OTF timing 配置"),
    ("0x02C", "APB_ADDR_META_CFG0: tile_x/y", "更改图像格式时配置", "按图像尺寸计算；YUV420 的 UV tile 数内部推导"),
    ("0x030", "REG_META_BASE_Y_LO", "每次配置", "RGBA/Y PLANE metadata 读取基地址低 32 bit"),
    ("0x034", "REG_META_BASE_Y_HI", "每次配置", "RGBA/Y PLANE metadata 读取基地址高 32 bit"),
    ("0x038", "REG_TILE_BASE_Y_LO", "每次配置", "RGBA/Y PLANE 压缩数据读取基地址低 32 bit"),
    ("0x03C", "REG_TILE_BASE_Y_HI", "每次配置", "RGBA/Y PLANE 压缩数据读取基地址高 32 bit"),
    ("0x040", "REG_META_BASE_UV_LO", "每次配置", "UV PLANE metadata 读取基地址低 32 bit"),
    ("0x044", "REG_META_BASE_UV_HI", "每次配置", "UV PLANE metadata 读取基地址高 32 bit"),
    ("0x048", "REG_TILE_BASE_UV_LO", "每次配置", "UV PLANE 压缩数据读取基地址低 32 bit；RGBA 图像不关心"),
    ("0x04C", "REG_TILE_BASE_UV_HI", "每次配置", "UV PLANE 压缩数据读取基地址高 32 bit；RGBA 图像不关心"),
]

CONFIG_HEADERS = ["寄存器地址", "寄存器功能", "配置模式", "默认配置/说明"]


ENC_ADDR_ROWS = [
    ("Y metadata base", "0x030 / 0x034", "低 32 bit / 高 32 bit；RGBA 使用该槽位"),
    ("Y tile base", "0x038 / 0x03C", "低 32 bit / 高 32 bit；RGBA 使用该槽位"),
    ("UV metadata base", "0x040 / 0x044", "低 32 bit / 高 32 bit；RGBA 写 0"),
    ("UV tile base", "0x048 / 0x04C", "低 32 bit / 高 32 bit；最后写 0x04C high 提交本帧地址组"),
]


DEC_ADDR_ROWS = [
    ("metadata RGBA/Y base", "0x030 / 0x034", "低 32 bit / 高 32 bit"),
    ("tile RGBA/Y base", "0x038 / 0x03C", "低 32 bit / 高 32 bit"),
    ("metadata UV base", "0x040 / 0x044", "低 32 bit / 高 32 bit"),
    ("tile UV base", "0x048 / 0x04C", "低 32 bit / 高 32 bit；RGBA 图像不关心"),
]


FIRST_NEXT_ROWS = [
    ("首次配置", "读取 VERSION/DATE；使能中断；配置格式、尺寸、tile layout、CI/VIVO、metadata geometry、DEC OTF timing；写入第一帧 ENC/DEC 地址。"),
    ("后续帧配置", "如果格式、尺寸、layout、timing 不变，只写新一帧的 base address；ENC 等上游 OTF 输入，DEC 地址写好后硬件按配置自动处理。"),
    ("重新配置静态项", "只有格式、分辨率、layout 或 DEC OTF timing 变化时才重写静态项；应先确认当前帧处理完成，再切换静态配置。"),
]


OTF_ROWS = [
    ("cfg_otf_h_sync", "HSA", "水平 sync 宽度"),
    ("cfg_otf_h_bp", "HBP", "水平 back porch"),
    ("cfg_otf_h_act", "HACT", "水平 active 宽度"),
    ("cfg_otf_h_total", "HSA + HBP + HACT + HFP", "水平总长度"),
    ("cfg_otf_v_sync", "VSA", "垂直 sync 宽度"),
    ("cfg_otf_v_bp", "VBP", "垂直 back porch"),
    ("cfg_otf_v_act", "VACT", "垂直 active 高度"),
    ("cfg_otf_v_total", "VSA + VBP + VACT + VFP", "垂直总行数"),
]


OTF_MARKER_ROWS = [
    ("HSA", "Horizontal Sync Active", "每一行开头的水平同步脉冲宽度，对应 cfg_otf_h_sync。"),
    ("HBP", "Horizontal Back Porch", "HS 结束后到 active pixel 开始前的水平空白区，对应 cfg_otf_h_bp。"),
    ("HACT", "Horizontal Active", "一行内有效显示/有效数据宽度，对应 cfg_otf_h_act，通常等于输出图像宽度。"),
    ("HFP", "Horizontal Front Porch", "active pixel 结束后到下一行 HS 前的水平空白区，不单独配置，由 h_total 减去 HSA/HBP/HACT 得到。"),
    ("VSA", "Vertical Sync Active", "一帧开头的垂直同步行数，对应 cfg_otf_v_sync。"),
    ("VBP", "Vertical Back Porch", "VS 结束后到 active line 开始前的垂直空白区，对应 cfg_otf_v_bp。"),
    ("VACT", "Vertical Active", "一帧内有效显示/有效数据行数，对应 cfg_otf_v_act，通常等于输出图像高度。"),
    ("VFP", "Vertical Front Porch", "active line 结束后到下一帧 VS 前的垂直空白区，不单独配置，由 v_total 减去 VSA/VBP/VACT 得到。"),
]


IRQ_ROWS = [
    ("ENC STATUS0", "0x058", "idle/error/busy/frame_done/addr_cfg_invalid/addr_cfg_valid0/1"),
    ("ENC IRQ_CTRL", "0x060", "irq_enable、irq_clear、irq_pending、correct/error pending"),
    ("ENC 统计", "0x068..0x09C", "metadata、tileaddr、OTF、AXI 写计数"),
    ("DEC STATUS0", "0x050", "frame_active、meta/tile/vivo/otf busy、idle 状态"),
    ("DEC IRQ_CTRL", "0x060", "irq_enable、irq_clear、irq_pending、error/correct pending"),
    ("DEC 统计", "0x068..0x078", "metadata tile、tileaddr、OTF tile、line、de beat 计数"),
]


def align_up(value: int, align: int) -> int:
    return ((value + align - 1) // align) * align


def hex32(value: int) -> str:
    return f"0x{value & 0xffffffff:08X}"


ENC_REFERENCE_FORMATS = [
    ("RGBA8888", 0),
    ("YUV420_8 / NV12", 2),
    ("YUV420_10 / P010", 3),
]


ENC_FORMAT_INFO = {
    0: ("RGBA8888", 16, 4, 4),
    2: ("YUV420_8 / NV12", 32, 8, 1),
    3: ("YUV420_10 / P010", 32, 4, 2),
}


ENC_PITCH_ADDR_FORMULA = """// 基础函数
ceil_div(a, b) = (a + b - 1) / b
align_up(a, n) = ceil_div(a, n) * n

// 格式参数
RGBA8888:           format=0, tile_w=16, tile_h=4, bpp=4
YUV420_8 / NV12:    format=2, tile_w=32, tile_h=8, bpp=1
YUV420_10 / P010:   format=3, tile_w=32, tile_h=4, bpp=2

// ENC pitch / tile 数
aligned_width_px    = align_up(width_px, tile_w * 4)
y_tile_cols         = ceil_div(aligned_width_px, tile_w)
uv_tile_cols        = 0 for RGBA; otherwise y_tile_cols
stored_y_height     = align_up(height_px, tile_h * 4)
stored_uv_height    = align_up(ceil_div(height_px, 2), tile_h * 4)  // only YUV420
surface_pitch_bytes = align_up(width_px * bpp, tile_w * 4 * bpp)
tile_pitch          = surface_pitch_bytes / 16
meta_pitch          = align_up(y_tile_cols, 64)

// ENC metadata / tile size
y_tile_rows      = ceil_div(stored_y_height, tile_h)
uv_tile_rows     = ceil_div(stored_uv_height, tile_h)                // only YUV420
meta_y_size      = align_up(meta_pitch * align_up(y_tile_rows, 16), 4096)
tile_y_size      = align_up(surface_pitch_bytes * stored_y_height, 4096)
meta_uv_size     = 0 for RGBA; otherwise align_up(meta_pitch * align_up(uv_tile_rows, 16), 4096)
tile_uv_size     = 0 for RGBA; otherwise align_up(surface_pitch_bytes * stored_uv_height, 4096)

// 连续输出 buffer 地址，base 是 Y/RGBA metadata 起始地址
REG_META_BASE_Y  = base
REG_TILE_BASE_Y  = REG_META_BASE_Y + meta_y_size
REG_META_BASE_UV = 0 for RGBA; otherwise REG_TILE_BASE_Y + tile_y_size
REG_TILE_BASE_UV = 0 for RGBA; otherwise REG_META_BASE_UV + meta_uv_size
total_size       = meta_y_size + tile_y_size + meta_uv_size + tile_uv_size"""


DEC_PITCH_ADDR_FORMULA = """// 基础函数
ceil_div(a, b) = (a + b - 1) / b
align_up(a, n) = ceil_div(a, n) * n

// 格式参数
RGBA8888:           format=0, tile_w=16, tile_h=4, bpp=4
YUV420_8 / NV12:    format=2, tile_w=32, tile_h=8, bpp=1
YUV420_10 / P010:   format=3, tile_w=32, tile_h=4, bpp=2

// DEC pitch / metadata tile 数
aligned_width_px    = align_up(width_px, tile_w * 4)
meta_tile_x_numbers = ceil_div(aligned_width_px, tile_w)             // RGBA/Y plane
stored_y_height     = align_up(height_px, tile_h * 4)
stored_uv_height    = align_up(ceil_div(height_px, 2), tile_h * 4)   // only YUV420
meta_tile_y_numbers = ceil_div(stored_y_height, tile_h)              // RGBA/Y plane
surface_pitch_bytes = align_up(width_px * bpp, tile_w * 4 * bpp)
tile_pitch          = surface_pitch_bytes / 16
meta_pitch          = align_up(meta_tile_x_numbers, 64)

// DEC metadata / tile size
meta_y_size      = align_up(meta_pitch * align_up(meta_tile_y_numbers, 16), 4096)
tile_y_size      = align_up(surface_pitch_bytes * stored_y_height, 4096)
meta_uv_rows     = ceil_div(stored_uv_height, tile_h)                // only YUV420
meta_uv_size     = 0 for RGBA; otherwise align_up(meta_pitch * align_up(meta_uv_rows, 16), 4096)
tile_uv_size     = 0 for RGBA; otherwise align_up(surface_pitch_bytes * stored_uv_height, 4096)

// 连续输入 UBWC buffer 地址，base 是 RGBA/Y metadata 起始地址
REG_META_BASE_Y  = base
REG_TILE_BASE_Y  = REG_META_BASE_Y + meta_y_size
REG_META_BASE_UV = 0 for RGBA; otherwise REG_TILE_BASE_Y + tile_y_size
REG_TILE_BASE_UV = 0 for RGBA; otherwise REG_META_BASE_UV + meta_uv_size
total_size       = meta_y_size + tile_y_size + meta_uv_size + tile_uv_size

// DEC OTF timing 示例
h_total = HSA + HBP + HACT + HFP
v_total = VSA + VBP + VACT + VFP
OTF_CFG0 = {format[4:0], width_px}
OTF_CFG1 = {HSA, h_total}
OTF_CFG2 = {HACT, HBP}
OTF_CFG3 = {VSA, v_total}
OTF_CFG4 = {VACT, VBP}"""


def enc_format_example(format_code: int, width: int, height: int) -> dict[str, int]:
    _, tile_w, tile_h, bytes_per_pixel = ENC_FORMAT_INFO[format_code]
    is_rgba = format_code == 0
    aligned_width = align_up(width, tile_w * 4)
    y_tile_cols = aligned_width // tile_w
    uv_tile_cols = 0 if is_rgba else y_tile_cols
    stored_y_height = align_up(height, tile_h * 4)
    uv_height = (height + 1) // 2
    stored_uv_height = 0 if is_rgba else align_up(uv_height, tile_h * 4)
    y_tile_rows = stored_y_height // tile_h
    uv_tile_rows = 0 if is_rgba else stored_uv_height // tile_h
    surface_pitch_bytes = align_up(width * bytes_per_pixel,
                                   tile_w * 4 * bytes_per_pixel)
    tile_pitch = surface_pitch_bytes // 16
    meta_pitch = align_up(y_tile_cols, 64)
    meta_y_size = align_up(meta_pitch * align_up(y_tile_rows, 16), 4096)
    tile_y_size = align_up(surface_pitch_bytes * stored_y_height, 4096)
    meta_uv_size = 0 if is_rgba else align_up(meta_pitch * align_up(uv_tile_rows, 16), 4096)
    tile_uv_size = 0 if is_rgba else align_up(surface_pitch_bytes * stored_uv_height, 4096)
    return {
        "format": format_code,
        "width": width,
        "height": height,
        "tile_w": tile_w,
        "tile_h": tile_h,
        "bytes_per_pixel": bytes_per_pixel,
        "y_tile_cols": y_tile_cols,
        "uv_tile_cols": uv_tile_cols,
        "y_tile_rows": y_tile_rows,
        "uv_tile_rows": uv_tile_rows,
        "stored_y_height": stored_y_height,
        "stored_uv_height": stored_uv_height,
        "surface_pitch_bytes": surface_pitch_bytes,
        "tile_pitch": tile_pitch,
        "meta_pitch": meta_pitch,
        "meta_y_size": meta_y_size,
        "tile_y_size": tile_y_size,
        "meta_uv_size": meta_uv_size,
        "tile_uv_size": tile_uv_size,
        "total_size": meta_y_size + tile_y_size + meta_uv_size + tile_uv_size,
        "enc_tile_cfg1": (tile_pitch << 16) | (1 if is_rgba else 0),
        "enc_otf_cfg1": (height << 16) | width,
        "enc_otf_cfg2": (tile_h << 16) | tile_w,
        "enc_otf_cfg3": (uv_tile_cols << 16) | y_tile_cols,
        "enc_meta_active": (height << 16) | width,
        "enc_meta_pitch": meta_pitch,
        "enc_otf_cfg0": format_code,
    }


def dec_format_example(format_code: int, width: int, height: int) -> dict[str, int]:
    ex = enc_format_example(format_code, width, height)
    is_rgba = format_code == 0
    h_sync = 4
    h_bp = 8
    h_fp = 20
    v_sync = 2
    v_bp = 4
    v_fp = 6
    h_total = width + h_sync + h_bp + h_fp
    v_total = height + v_sync + v_bp + v_fp
    tile_cfg0 = (1 << 1) | (1 << 2) | (16 << 4) | (1 << 9) | ((1 if is_rgba else 0) << 10)
    ex.update({
        "dec_tile_cfg0": tile_cfg0,
        "dec_tile_cfg1": ex["tile_pitch"],
        "dec_tile_cfg2": 1,
        "dec_otf_cfg0": width | (format_code << 16),
        "dec_otf_cfg1": h_total | (h_sync << 16),
        "dec_otf_cfg2": h_bp | (width << 16),
        "dec_otf_cfg3": v_total | (v_sync << 16),
        "dec_otf_cfg4": v_bp | (height << 16),
        "dec_meta_cfg0": ex["y_tile_cols"] | (ex["y_tile_rows"] << 16),
    })
    return ex


def rgba8888_example(width: int, height: int) -> dict[str, int]:
    tile_w = 16
    tile_h = 4
    bytes_per_pixel = 4
    aligned_width = align_up(width, tile_w * 4)
    stored_height = align_up(height, tile_h * 4)
    tile_cols = aligned_width // tile_w
    tile_rows = stored_height // tile_h
    surface_pitch_bytes = align_up(width * bytes_per_pixel, tile_w * 4 * bytes_per_pixel)
    tile_pitch = surface_pitch_bytes // 16
    meta_pitch = align_up(tile_cols, 64)
    h_sync = 4
    h_bp = 8
    h_fp = 20
    v_sync = 2
    v_bp = 4
    v_fp = 6
    return {
        "width": width,
        "height": height,
        "tile_w": tile_w,
        "tile_h": tile_h,
        "tile_cols": tile_cols,
        "tile_rows": tile_rows,
        "stored_height": stored_height,
        "tile_pitch": tile_pitch,
        "meta_pitch": meta_pitch,
        "enc_tile_cfg1": (tile_pitch << 16) | 1,
        "enc_otf_cfg1": (height << 16) | width,
        "enc_otf_cfg2": (tile_h << 16) | tile_w,
        "enc_otf_cfg3": tile_cols,
        "enc_meta_active": (height << 16) | width,
        "enc_meta_pitch": meta_pitch,
        "enc_otf_cfg0": 0,
        "dec_tile_cfg1": tile_pitch,
        "dec_meta_cfg0": (tile_rows << 16) | tile_cols,
        "dec_otf_cfg0": width,
        "dec_otf_cfg1": (h_sync << 16) | (width + h_sync + h_bp + h_fp),
        "dec_otf_cfg2": (width << 16) | h_bp,
        "dec_otf_cfg3": (v_sync << 16) | (height + v_sync + v_bp + v_fp),
        "dec_otf_cfg4": (height << 16) | v_bp,
    }


def build_example_rows(module: str) -> list[tuple[str, str, str]]:
    rows = []
    for width, height in [(128, 128), (544, 1200), (1920, 1080), (4096, 600)]:
        ex = rgba8888_example(width, height)
        calc = (
            f"tile={ex['tile_w']}x{ex['tile_h']}\n"
            f"tile_cols={ex['tile_cols']}, tile_rows={ex['tile_rows']}\n"
            f"stored_height={ex['stored_height']}\n"
            f"tile_pitch={ex['tile_pitch']}, meta_pitch={ex['meta_pitch']}"
        )
        if module == "enc":
            writes = (
                f"0x00C REG_TILE_CFG1       = {hex32(ex['enc_tile_cfg1'])}\n"
                f"0x024 REG_OTF_CFG1        = {hex32(ex['enc_otf_cfg1'])}\n"
                f"0x028 REG_OTF_CFG2        = {hex32(ex['enc_otf_cfg2'])}\n"
                f"0x02C REG_OTF_CFG3        = {hex32(ex['enc_otf_cfg3'])}\n"
                f"0x050 REG_META_ACTIVE_SIZE= {hex32(ex['enc_meta_active'])}\n"
                f"0x054 REG_META_PITCH      = {hex32(ex['enc_meta_pitch'])}\n"
                f"0x020 REG_OTF_CFG0        = {hex32(ex['enc_otf_cfg0'])}"
            )
        else:
            writes = (
                f"0x00C TILE_CFG1 = {hex32(ex['dec_tile_cfg1'])}\n"
                f"0x018 OTF_CFG0  = {hex32(ex['dec_otf_cfg0'])}\n"
                f"0x01C OTF_CFG1  = {hex32(ex['dec_otf_cfg1'])}\n"
                f"0x020 OTF_CFG2  = {hex32(ex['dec_otf_cfg2'])}\n"
                f"0x024 OTF_CFG3  = {hex32(ex['dec_otf_cfg3'])}\n"
                f"0x028 OTF_CFG4  = {hex32(ex['dec_otf_cfg4'])}\n"
                f"0x02C META_CFG0 = {hex32(ex['dec_meta_cfg0'])}"
            )
        rows.append((f"{width}x{height}", calc, writes))
    return rows


def build_enc_reference_rows() -> list[tuple[str, str, str, str]]:
    rows = []
    for label, format_code in ENC_REFERENCE_FORMATS:
        for width, height in [(128, 128), (544, 1200), (1920, 1080), (4096, 600)]:
            ex = enc_format_example(format_code, width, height)
            calc = (
                f"tile={ex['tile_w']}x{ex['tile_h']}, bpp={ex['bytes_per_pixel']}\n"
                f"Y cols/rows={ex['y_tile_cols']}/{ex['y_tile_rows']}\n"
                f"UV cols/rows={ex['uv_tile_cols']}/{ex['uv_tile_rows']}\n"
                f"stored Y/UV={ex['stored_y_height']}/{ex['stored_uv_height']}\n"
                f"tile_pitch={ex['tile_pitch']}, meta_pitch={ex['meta_pitch']}\n"
                f"size Y(meta/tile)=0x{ex['meta_y_size']:X}/0x{ex['tile_y_size']:X}\n"
                f"size UV(meta/tile)=0x{ex['meta_uv_size']:X}/0x{ex['tile_uv_size']:X}"
            )
            writes = (
                f"0x00C REG_TILE_CFG1       = {hex32(ex['enc_tile_cfg1'])}\n"
                f"0x024 REG_OTF_CFG1        = {hex32(ex['enc_otf_cfg1'])}\n"
                f"0x028 REG_OTF_CFG2        = {hex32(ex['enc_otf_cfg2'])}\n"
                f"0x02C REG_OTF_CFG3        = {hex32(ex['enc_otf_cfg3'])}\n"
                f"0x050 REG_META_ACTIVE_SIZE= {hex32(ex['enc_meta_active'])}\n"
                f"0x054 REG_META_PITCH      = {hex32(ex['enc_meta_pitch'])}\n"
                f"0x020 REG_OTF_CFG0        = {hex32(ex['enc_otf_cfg0'])}"
            )
            rows.append((label, f"{width}x{height}", calc, writes))
    return rows


def build_dec_reference_rows() -> list[tuple[str, str, str, str]]:
    rows = []
    for label, format_code in ENC_REFERENCE_FORMATS:
        for width, height in [(128, 128), (544, 1200), (1920, 1080), (4096, 600)]:
            ex = dec_format_example(format_code, width, height)
            calc = (
                f"tile={ex['tile_w']}x{ex['tile_h']}, bpp={ex['bytes_per_pixel']}\n"
                f"Y meta cols/rows={ex['y_tile_cols']}/{ex['y_tile_rows']}\n"
                f"UV meta cols/rows={ex['uv_tile_cols']}/{ex['uv_tile_rows']}\n"
                f"stored Y/UV={ex['stored_y_height']}/{ex['stored_uv_height']}\n"
                f"tile_pitch={ex['tile_pitch']}, meta_pitch={ex['meta_pitch']}\n"
                f"size Y(meta/tile)=0x{ex['meta_y_size']:X}/0x{ex['tile_y_size']:X}\n"
                f"size UV(meta/tile)=0x{ex['meta_uv_size']:X}/0x{ex['tile_uv_size']:X}"
            )
            writes = (
                f"0x008 TILE_CFG0 = {hex32(ex['dec_tile_cfg0'])}\n"
                f"0x00C TILE_CFG1 = {hex32(ex['dec_tile_cfg1'])}\n"
                f"0x010 TILE_CFG2 = {hex32(ex['dec_tile_cfg2'])}\n"
                f"0x018 OTF_CFG0  = {hex32(ex['dec_otf_cfg0'])}\n"
                f"0x01C OTF_CFG1  = {hex32(ex['dec_otf_cfg1'])}\n"
                f"0x020 OTF_CFG2  = {hex32(ex['dec_otf_cfg2'])}\n"
                f"0x024 OTF_CFG3  = {hex32(ex['dec_otf_cfg3'])}\n"
                f"0x028 OTF_CFG4  = {hex32(ex['dec_otf_cfg4'])}\n"
                f"0x02C META_CFG0 = {hex32(ex['dec_meta_cfg0'])}"
            )
            rows.append((label, f"{width}x{height}", calc, writes))
    return rows


ENC_REFERENCE_ROWS = build_enc_reference_rows()
DEC_REFERENCE_ROWS = build_dec_reference_rows()
DEC_RGBA8888_EXAMPLE_ROWS = build_example_rows("dec")


def html_table(headers: list[str], rows: list[tuple[str, ...]]) -> str:
    def cell(text: str, tag: str) -> str:
        return f"<{tag}>{escape(text).replace(chr(10), '<br>')}</{tag}>"

    head = "".join(cell(h, "th") for h in headers)
    body = "\n".join("<tr>" + "".join(cell(c, "td") for c in row) + "</tr>" for row in rows)
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def write_html() -> None:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>UBWC ENC/DEC 软件使用说明</title>
  <style>
    :root {{
      --ink: #111827;
      --muted: #4b5563;
      --line: #d6dde8;
      --blue: #1d4ed8;
      --purple: #7c3aed;
      --green: #059669;
      --amber: #b45309;
      --bg: #f6f7fb;
      --card: #ffffff;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font: 15px/1.65 -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", Arial, sans-serif;
      color: var(--ink);
      background: var(--bg);
    }}
    main {{ max-width: 1120px; margin: 0 auto; padding: 34px 28px 56px; }}
    header {{ margin-bottom: 26px; }}
    h1 {{ margin: 0 0 8px; font-size: 34px; line-height: 1.2; }}
    .subtitle {{ color: var(--muted); margin: 0; }}
    nav {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 10px;
      margin: 22px 0 28px;
    }}
    nav a {{
      color: var(--blue);
      text-decoration: none;
      padding: 10px 12px;
      border: 1px solid var(--line);
      background: var(--card);
      border-radius: 8px;
      font-weight: 600;
    }}
    section {{
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 22px 24px;
      margin: 18px 0;
    }}
    h2 {{ margin: 0 0 14px; font-size: 23px; }}
    h3 {{ margin: 22px 0 10px; font-size: 18px; }}
    .callout {{
      border-left: 5px solid var(--green);
      background: #ecfdf5;
      padding: 12px 14px;
      margin: 14px 0;
      border-radius: 8px;
    }}
    .warn {{ border-left-color: var(--amber); background: #fffbeb; }}
    table {{ width: 100%; border-collapse: collapse; margin: 12px 0 18px; }}
    th, td {{ border: 1px solid var(--line); padding: 9px 10px; vertical-align: top; }}
    th {{ background: #eef2ff; text-align: left; font-weight: 700; }}
    code, pre {{
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      background: #f8fafc;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
    }}
    code {{ padding: 1px 4px; }}
    pre {{ padding: 12px 14px; overflow: auto; }}
    .grid2 {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 14px; }}
    .badge {{ display: inline-block; padding: 2px 7px; border-radius: 999px; background: #dbeafe; color: #1e40af; font-weight: 700; font-size: 12px; }}
    footer {{ color: var(--muted); margin-top: 24px; font-size: 13px; }}
  </style>
</head>
<body>
<main>
  <header>
    <h1>UBWC ENC/DEC 软件使用说明</h1>
    <p class="subtitle">生成时间：{escape(now)}。说明软件首次配置、后续帧配置、中断处理和 DEC OTF timing 参数填写方式。</p>
  </header>
  <nav>
    <a href="#basic">基础约定</a>
    <a href="#freq">配置频率</a>
    <a href="#enc">ENC 使用流程</a>
    <a href="#dec">DEC 使用流程</a>
    <a href="#otf">DEC OTF timing</a>
    <a href="#irq">状态与中断</a>
  </nav>

  <section id="basic">
    <h2>1. 基础约定</h2>
    <p>APB 寄存器为 32 bit 宽，地址按 4 byte 对齐。所有 64 bit base address 都按低 32 bit、高 32 bit 的顺序写入。</p>
    {html_table(["格式", "编码", "tile_w", "tile_h", "说明"], FORMAT_ROWS)}
    <div class="callout">连续帧模式下，如果格式、分辨率、tile layout 和 OTF timing 不变，软件通常只需要每帧更新 UBWC buffer base address。</div>
  </section>

  <section id="freq">
    <h2>2. 首次配置和后续配置</h2>
    {html_table(["场景", "软件动作"], FIRST_NEXT_ROWS)}
    <h3>2.1 ENC 配置清单</h3>
    {html_table(CONFIG_HEADERS, ENC_CONFIG_ROWS)}
    <h3>2.2 DEC 配置清单</h3>
    {html_table(CONFIG_HEADERS, DEC_CONFIG_ROWS)}
    <h3>2.3 ENC 分辨率参考配置</h3>
    <p>下面只列 ENC 静态几何相关寄存器，覆盖 RGBA8888、YUV420_8/NV12、YUV420_10/P010。每帧 base address 仍按实际输出 buffer 地址单独写入。</p>
    {html_table(["格式", "分辨率", "关键计算", "ENC 写值参考"], ENC_REFERENCE_ROWS)}
    <h4>2.3.1 ENC 地址和 pitch 计算方法</h4>
    <pre>{escape(ENC_PITCH_ADDR_FORMULA)}</pre>
    <h3>2.4 DEC 分辨率参考配置</h3>
    <p>下面只列 DEC 静态几何和 OTF timing 相关寄存器，覆盖 RGBA8888、YUV420_8/NV12、YUV420_10/P010。OTF 示例默认 HSA=4、HBP=8、HFP=20、VSA=2、VBP=4、VFP=6；如果系统 timing 不同，只替换 OTF_CFG1..4。</p>
    {html_table(["格式", "分辨率", "关键计算", "DEC 写值参考"], DEC_REFERENCE_ROWS)}
    <h4>2.4.1 DEC 地址、pitch 和 OTF timing 计算方法</h4>
    <pre>{escape(DEC_PITCH_ADDR_FORMULA)}</pre>
  </section>

  <section id="enc">
    <h2>3. ENC 使用流程</h2>
    <div class="callout warn">ENC 没有 APB start bit。软件先配置好静态参数和输出 buffer 地址，上游 OTF 输入流的 vsync/hsync/de/data 到来后，ENC 自动开始处理。</div>
    <h3>3.1 首次或格式变化时配置</h3>
    <pre>read(0x000); // VERSION
read(0x004); // DATE
write(0x00C, REG_TILE_CFG1);      // [0] four_line_format; [1] lossy_rgba_2_1; [26:16] tile_pitch
write(0x008, REG_TILE_CFG0);      // [0] ubwc_en; [3:1] bank_swizzle; [12:8] highest_bank_bit; [16] bank_spread
write(0x014, REG_ENC_CI_CFG1);    // [16] enc_ci_lossy
write(0x018, REG_ENC_CI_CFG2);    // [30:0] enc_ci_ubwc_cfg_0..9，建议写 0
write(0x01C, REG_ENC_CI_CFG3);    // [5:0] cfg_10; [13:8] cfg_11，建议写 0
write(0x010, REG_ENC_CI_CFG0);    // reset=0; [0] input_type 写 1; [10:8] alen 写 7
write(0x024, REG_OTF_CFG1);       // [15:0] width; [31:16] height
write(0x028, REG_OTF_CFG2);       // [15:0] tile_w; [19:16] tile_h
write(0x02C, REG_OTF_CFG3);       // [15:0] y_tile_cols; [31:16] uv_tile_cols，RGBA 的 uv 写 0
write(0x050, REG_META_ACTIVE_SIZE); // [15:0] active_width; [31:16] active_height
write(0x054, REG_META_PITCH);     // [31:0] meta_data_plane_pitch
write(0x020, REG_OTF_CFG0);       // [2:0] format</pre>
    <h3>3.2 每帧地址配置</h3>
    {html_table(["地址项", "APB 地址", "说明"], ENC_ADDR_ROWS)}
    <p><b>写入顺序建议：</b>按 meta Y、tile Y、meta UV、tile UV 顺序写。<code>REG_TILE_BASE_UV_HI @ 0x04C</code> 必须作为本帧地址组最后一笔写入，使本帧四个 base 地址生效。</p>
    <h3>3.3 后续帧配置</h3>
    <p>如果格式和尺寸不变，后续帧只需要重复 3.2 的每帧地址配置，然后送入下一帧 OTF 输入流。</p>
  </section>

  <section id="dec">
    <h2>4. DEC 使用流程</h2>
    <div class="callout">DEC 软件不需要额外写 start。首次配置静态参数和一组输入 UBWC buffer 地址后，硬件会按已配置地址自动处理；后续帧只需要继续写入新的输入 buffer 地址。</div>
    <h3>4.1 首次或格式/timing 变化时配置</h3>
    <pre>read(0x000); // VERSION
read(0x004); // DATE
write(0x008, APB_ADDR_TILE_CFG0); // [2:0] bank_swizzle; [8:4] highest_bank_bit; [9] bank_spread; [10] 4line; [11] lossy_rgba_2_1
write(0x00C, APB_ADDR_TILE_CFG1); // [11:0] tile_cfg_pitch
write(0x010, APB_ADDR_TILE_CFG2); // reset=0; [0] ci_input_type 写 1; [8] ci_lossy; [10:9] alpha_mode
write(0x014, VIVO_CFG);           // [0] vivo_ubwc_en; [1] vivo_sreset
write(0x02C, META_CFG0);          // [15:0] Y/RGBA tile_x_numbers; [31:16] Y/RGBA tile_y_numbers
write(0x018, OTF_CFG0);           // [15:0] img_width; [20:16] format
write(0x01C, OTF_CFG1);           // [15:0] h_total; [31:16] h_sync/HSA
write(0x020, OTF_CFG2);           // [15:0] h_bp/HBP; [31:16] h_act/HACT
write(0x024, OTF_CFG3);           // [15:0] v_total; [31:16] v_sync/VSA
write(0x028, OTF_CFG4);           // [15:0] v_bp/VBP; [31:16] v_act/VACT</pre>
    <h3>4.2 每帧地址配置</h3>
    {html_table(["地址项", "APB 地址", "说明"], DEC_ADDR_ROWS)}
    <p><b>写入顺序建议：</b>每个 64 bit 地址都按 low word、high word 顺序写。四类地址都写完后，该帧输入 buffer 地址配置完成。后续帧如果格式和 timing 不变，只重复本节地址配置。</p>
  </section>

  <section id="otf">
    <h2>5. DEC OTF timing 配置</h2>
    <p>软件可以按 video mode timing 图中的 HSA/HBP/HACT/HFP 和 VSA/VBP/VACT/VFP 计算当前 RTL 的 OTF_CFG。RTL APB 写像素/行单位，内部水平计数会转换为 128-bit OTF beat。</p>
    {html_table(["图中标记", "名称", "软件配置含义"], OTF_MARKER_ROWS)}
    {html_table(["RTL 配置项", "video timing 对应项", "说明"], OTF_ROWS)}
    <pre>write(0x01C, {{HSA, HSA + HBP + HACT + HFP}});
write(0x020, {{HACT, HBP}});
write(0x024, {{VSA, VSA + VBP + VACT + VFP}});
write(0x028, {{VACT, VBP}});</pre>
    <div class="callout warn">当前 <code>ubwc_dec_otf_driver.v</code> 中 hsync 只在 active vertical 区间内输出。如果要严格模拟标准 display timing，需要让 hsync 在每一行都按 HSA 输出。</div>
  </section>

  <section id="irq">
    <h2>6. 状态、中断和统计</h2>
    {html_table(["类别", "地址", "说明"], IRQ_ROWS)}
    <pre>// ENC 清中断
write(0x060, old_irq_enable | (1 &lt;&lt; 1));

// DEC 清中断
write(0x060, old_irq_enable | (1 &lt;&lt; 1));</pre>
  </section>

  <footer>UBWC ENC/DEC software usage guide. Generated from repository configuration notes and current APB register semantics.</footer>
</main>
</body>
</html>
"""
    HTML_OUT.write_text(html, encoding="utf-8")
    print(f"wrote {HTML_OUT}")


def w_text(text: str, preserve: bool = False) -> str:
    attr = ' xml:space="preserve"' if preserve or text.startswith(" ") or text.endswith(" ") else ""
    return f"<w:t{attr}>{escape(text)}</w:t>"


def run(text: str, bold: bool = False, color: str | None = None, size: int = 22, mono: bool = False) -> str:
    rpr = [f'<w:sz w:val="{size}"/>', f'<w:szCs w:val="{size}"/>']
    if bold:
        rpr.append("<w:b/>")
    if color:
        rpr.append(f'<w:color w:val="{color}"/>')
    font = "Consolas" if mono else "Arial"
    rpr.append(f'<w:rFonts w:ascii="{font}" w:hAnsi="{font}" w:eastAsia="Microsoft YaHei"/>')
    return f"<w:r><w:rPr>{''.join(rpr)}</w:rPr>{w_text(text, preserve=mono)}</w:r>"


def para(text: str = "", style: str | None = None, keep_next: bool = False) -> str:
    props = []
    if style:
        props.append(f'<w:pStyle w:val="{style}"/>')
    if keep_next:
        props.append("<w:keepNext/>")
    props.append('<w:spacing w:after="120" w:line="260" w:lineRule="auto"/>')
    return f"<w:p><w:pPr>{''.join(props)}</w:pPr>{run(text)}</w:p>"


def bullet(text: str) -> str:
    ppr = '<w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr><w:spacing w:after="100"/></w:pPr>'
    return f"<w:p>{ppr}{run(text)}</w:p>"


def code_block(code: str) -> str:
    rows = []
    for line in code.splitlines():
        rows.append(
            '<w:p><w:pPr><w:pStyle w:val="Code"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>'
            + run(line, size=20, mono=True)
            + "</w:p>"
        )
    return "".join(rows)


def table(headers: list[str], rows: list[tuple[str, ...]], widths: list[int]) -> str:
    def cell(text: str, width: int, header: bool = False) -> str:
        fill = '<w:shd w:fill="EEF2FF"/>' if header else ""
        lines = text.splitlines() or [""]
        paragraphs = "".join(
            f'<w:p><w:pPr><w:spacing w:after="60"/></w:pPr>{run(line, bold=header, size=20 if header else 19)}</w:p>'
            for line in lines
        )
        return (
            f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/>'
            '<w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="120" w:type="dxa"/>'
            '<w:bottom w:w="90" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>'
            f"{fill}</w:tcPr>"
            f"{paragraphs}</w:tc>"
        )

    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    trs = [
        "<w:tr>"
        + "".join(cell(h, widths[i], True) for i, h in enumerate(headers))
        + "</w:tr>"
    ]
    for row in rows:
        trs.append("<w:tr>" + "".join(cell(c, widths[i]) for i, c in enumerate(row)) + "</w:tr>")
    borders = (
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="CBD5E1"/>'
        '<w:left w:val="single" w:sz="4" w:color="CBD5E1"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="CBD5E1"/>'
        '<w:right w:val="single" w:sz="4" w:color="CBD5E1"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="CBD5E1"/>'
        '<w:insideV w:val="single" w:sz="4" w:color="CBD5E1"/></w:tblBorders>'
    )
    return (
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="9360" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/>'
        + borders
        + f'</w:tblPr><w:tblGrid>{grid}</w:tblGrid>'
        + "".join(trs)
        + "</w:tbl>"
    )


def document_xml() -> str:
    body: list[str] = []
    body.append(para("UBWC ENC/DEC 软件使用说明", "Title"))
    body.append(para("说明软件首次配置、后续帧配置、中断处理和 DEC OTF timing 参数填写方式。"))
    body.append(para("1. 基础约定", "Heading1", True))
    body.append(para("APB 寄存器为 32 bit 宽，地址按 4 byte 对齐。所有 64 bit base address 都按低 32 bit、高 32 bit 的顺序写入。"))
    body.append(table(["格式", "编码", "tile_w", "tile_h", "说明"], FORMAT_ROWS, [2100, 800, 900, 900, 4660]))
    body.append(para("连续帧模式下，如果格式、分辨率、tile layout 和 OTF timing 不变，软件通常只需要每帧更新 UBWC buffer base address。"))

    body.append(para("2. 首次配置和后续配置", "Heading1", True))
    body.append(table(["场景", "软件动作"], FIRST_NEXT_ROWS, [2200, 7160]))
    body.append(para("2.1 ENC 配置清单", "Heading2", True))
    body.append(table(["寄存器地址", "寄存器功能", "配置模式", "默认配置/说明"], ENC_CONFIG_ROWS, [1350, 2850, 1900, 3260]))
    body.append(para("2.2 DEC 配置清单", "Heading2", True))
    body.append(table(["寄存器地址", "寄存器功能", "配置模式", "默认配置/说明"], DEC_CONFIG_ROWS, [1350, 2850, 1900, 3260]))
    body.append(para("2.3 ENC 分辨率参考配置", "Heading2", True))
    body.append(para("下面只列 ENC 静态几何相关寄存器，覆盖 RGBA8888、YUV420_8/NV12、YUV420_10/P010。每帧 base address 仍按实际输出 buffer 地址单独写入。"))
    body.append(table(["格式", "分辨率", "关键计算", "ENC 写值参考"], ENC_REFERENCE_ROWS, [1350, 1250, 2900, 3860]))
    body.append(para("2.3.1 ENC 地址和 pitch 计算方法", "Heading2", True))
    body.append(code_block(ENC_PITCH_ADDR_FORMULA))
    body.append(para("2.4 DEC 分辨率参考配置", "Heading2", True))
    body.append(para("下面只列 DEC 静态几何和 OTF timing 相关寄存器，覆盖 RGBA8888、YUV420_8/NV12、YUV420_10/P010。OTF 示例默认 HSA=4、HBP=8、HFP=20、VSA=2、VBP=4、VFP=6；如果系统 timing 不同，只替换 OTF_CFG1..4。"))
    body.append(table(["格式", "分辨率", "关键计算", "DEC 写值参考"], DEC_REFERENCE_ROWS, [1350, 1250, 2900, 3860]))
    body.append(para("2.4.1 DEC 地址、pitch 和 OTF timing 计算方法", "Heading2", True))
    body.append(code_block(DEC_PITCH_ADDR_FORMULA))

    body.append(para("3. ENC 使用流程", "Heading1", True))
    body.append(para("ENC 没有 APB start bit。软件先配置好静态参数和输出 buffer 地址，上游 OTF 输入流的 vsync/hsync/de/data 到来后，ENC 自动开始处理。"))
    body.append(para("3.1 首次或格式变化时配置", "Heading2", True))
    body.append(code_block("""read(0x000); // VERSION
read(0x004); // DATE
write(0x00C, REG_TILE_CFG1);
write(0x008, REG_TILE_CFG0);
write(0x014, REG_ENC_CI_CFG1);
write(0x018, REG_ENC_CI_CFG2);
write(0x01C, REG_ENC_CI_CFG3);
write(0x010, REG_ENC_CI_CFG0); // reset=0, software writes input_type=1 and alen=7
write(0x024, REG_OTF_CFG1);
write(0x028, REG_OTF_CFG2);
write(0x02C, REG_OTF_CFG3);
write(0x050, REG_META_ACTIVE_SIZE);
write(0x054, REG_META_PITCH);
write(0x020, REG_OTF_CFG0); // format"""))
    body.append(para("3.2 每帧地址配置", "Heading2", True))
    body.append(table(["地址项", "APB 地址", "说明"], ENC_ADDR_ROWS, [2600, 1900, 4860]))
    body.append(para("写入顺序建议：按 meta Y、tile Y、meta UV、tile UV 顺序写。REG_TILE_BASE_UV_HI @ 0x04C 必须作为本帧地址组最后一笔写入，使本帧四个 base 地址生效。"))
    body.append(para("3.3 后续帧配置", "Heading2", True))
    body.append(para("如果格式和尺寸不变，后续帧只需要重复 3.2 的每帧地址配置，然后送入下一帧 OTF 输入流。"))

    body.append(para("4. DEC 使用流程", "Heading1", True))
    body.append(para("DEC 软件不需要额外写 start。首次配置静态参数和一组输入 UBWC buffer 地址后，硬件会按已配置地址自动处理；后续帧只需要继续写入新的输入 buffer 地址。"))
    body.append(para("4.1 首次或格式/timing 变化时配置", "Heading2", True))
    body.append(code_block("""read(0x000); // VERSION
read(0x004); // DATE
write(0x008, APB_ADDR_TILE_CFG0);
write(0x00C, APB_ADDR_TILE_CFG1);
write(0x010, APB_ADDR_TILE_CFG2);
write(0x014, VIVO_CFG);
write(0x02C, META_CFG0);
write(0x018, OTF_CFG0);
write(0x01C, OTF_CFG1);
write(0x020, OTF_CFG2);
write(0x024, OTF_CFG3);
write(0x028, OTF_CFG4);"""))
    body.append(para("4.2 每帧地址配置", "Heading2", True))
    body.append(table(["地址项", "APB 地址", "说明"], DEC_ADDR_ROWS, [2600, 1900, 4860]))
    body.append(para("写入顺序建议：每个 64 bit 地址都按 low word、high word 顺序写。四类地址都写完后，该帧输入 buffer 地址配置完成。后续帧如果格式和 timing 不变，只重复本节地址配置。"))

    body.append(para("5. DEC OTF timing 配置", "Heading1", True))
    body.append(para("软件可以按 video mode timing 图中的 HSA/HBP/HACT/HFP 和 VSA/VBP/VACT/VFP 计算当前 RTL 的 OTF_CFG。RTL APB 写像素/行单位，内部水平计数会转换为 128-bit OTF beat。"))
    body.append(table(["图中标记", "名称", "软件配置含义"], OTF_MARKER_ROWS, [1400, 2400, 5560]))
    body.append(table(["RTL 配置项", "video timing 对应项", "说明"], OTF_ROWS, [2600, 3500, 3260]))
    body.append(code_block("""write(0x01C, {HSA, HSA + HBP + HACT + HFP});
write(0x020, {HACT, HBP});
write(0x024, {VSA, VSA + VBP + VACT + VFP});
write(0x028, {VACT, VBP});"""))
    body.append(para("注意：当前 ubwc_dec_otf_driver.v 中 hsync 只在 active vertical 区间内输出。如果要严格模拟标准 display timing，需要让 hsync 在每一行都按 HSA 输出。"))

    body.append(para("6. 状态、中断和统计", "Heading1", True))
    body.append(table(["类别", "地址", "说明"], IRQ_ROWS, [2200, 1600, 5560]))
    body.append(code_block("""// ENC 清中断
write(0x060, old_irq_enable | (1 << 1));

// DEC 清中断
write(0x060, old_irq_enable | (1 << 1));"""))
    sect = (
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>'
        "</w:sectPr>"
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        "<w:body>"
        + "".join(body)
        + sect
        + "</w:body></w:document>"
    )


def styles_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Microsoft YaHei"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:after="220"/></w:pPr>
    <w:rPr><w:b/><w:color w:val="111827"/><w:sz w:val="44"/><w:szCs w:val="44"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>
    <w:pPr><w:keepNext/><w:spacing w:before="260" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:color w:val="1D4ED8"/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>
    <w:pPr><w:keepNext/><w:spacing w:before="200" w:after="100"/></w:pPr>
    <w:rPr><w:b/><w:color w:val="334155"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Code">
    <w:name w:val="Code"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="240"/><w:spacing w:after="0"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:eastAsia="Microsoft YaHei"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:color="CBD5E1"/><w:left w:val="single" w:sz="4" w:color="CBD5E1"/><w:bottom w:val="single" w:sz="4" w:color="CBD5E1"/><w:right w:val="single" w:sz="4" w:color="CBD5E1"/><w:insideH w:val="single" w:sz="4" w:color="CBD5E1"/><w:insideV w:val="single" w:sz="4" w:color="CBD5E1"/></w:tblBorders></w:tblPr>
  </w:style>
</w:styles>"""


def numbering_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>
  </w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>"""


def write_docx() -> None:
    content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""
    doc_rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>"""
    now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    core = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>UBWC ENC/DEC 软件使用说明</dc:title><dc:creator>Codex</dc:creator>'
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>'
        "</cp:coreProperties>"
    )
    with zipfile.ZipFile(DOCX_OUT, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", rels)
        zf.writestr("word/_rels/document.xml.rels", doc_rels)
        zf.writestr("word/document.xml", document_xml())
        zf.writestr("word/styles.xml", styles_xml())
        zf.writestr("word/numbering.xml", numbering_xml())
        zf.writestr("docProps/core.xml", core)
    print(f"wrote {DOCX_OUT}")


def main() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    write_html()
    write_docx()


if __name__ == "__main__":
    main()
