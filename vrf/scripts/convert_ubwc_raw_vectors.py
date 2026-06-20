#!/usr/bin/env python3
"""Convert raw/UBWC binaries into regression vector directories.

The default source package contains pairs such as:

    pattern_w720_h1548_yuv420_nv12.raw
    pattern_w720_h1548_yuv420_nv12.raw.ubwc

This helper converts them into the existing regression layout:

    vrf/vector/enc_from_ubwc_pattern_720x1548_nv12/

Each generated text file contains an @base-address line followed by 64-bit
hex words in source byte order.  The source tag and output directory/file
prefixes are configurable for each vector drop.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
VECTOR_ROOT = PROJECT_ROOT / "vrf" / "vector"
DEFAULT_SOURCE = VECTOR_ROOT / "20260522_UBWC_for_R7130_v2"
DEFAULT_SOURCE_TAG = "ubwc"
DEFAULT_BASE_ADDR = 0x0000000080000000

SOURCE_PATTERNS = [
    re.compile(r".*?_(?P<width>[0-9]+)x(?P<height>[0-9]+)_s(?P<stored_width>[0-9]+)x(?P<stored_height>[0-9]+)_(?P<fmt>.+)\.raw"),
    re.compile(r".*?_w(?P<width>[0-9]+)_h(?P<height>[0-9]+)_(?P<fmt>.+)\.raw"),
    re.compile(r".*?(?P<width>[0-9]+)x(?P<height>[0-9]+)_(?P<fmt>.+)\.raw"),
]

FORMAT_ALIASES = {
    "rgba8888": "rgba8888",
    "rgba_8888": "rgba8888",
    "rgba1010102": "rgba1010102",
    "rgba_1010102": "rgba1010102",
    "nv12": "yuv420_nv12",
    "yuv420_nv12": "yuv420_nv12",
    "p010": "yuv420_p010",
    "p1010": "yuv420_p010",
    "yuv420_p010": "yuv420_p010",
    "yuv420_p1010": "yuv420_p010",
}


def align(value: int, boundary: int) -> int:
    return ((value + boundary - 1) // boundary) * boundary


@dataclass(frozen=True)
class Layout:
    src_fmt: str
    fmt: str
    source_tag: str
    source_note: str
    base_addr: int
    width: int
    height: int
    stored_width: int
    explicit_stored_size: bool
    has_uv: bool
    bpp: int
    tile_w: int
    tile_h: int
    stored_y: int
    stored_uv: int
    pitch_y: int
    pitch_uv: int
    meta_pitch_y: int
    meta_pitch_uv: int
    meta_lines_y: int
    meta_lines_uv: int
    meta_size_y: int
    meta_size_uv: int
    tile_size_y: int
    tile_size_uv: int
    source_tile_size_y: int
    meta_base_y: int
    tile_base_y: int
    meta_base_uv: int
    tile_base_uv: int
    linear_size_y: int
    linear_size_uv: int

    @property
    def case_name(self) -> str:
        return f"{self.width}x{self.height}_{self.fmt}"

    @property
    def out_dir_name(self) -> str:
        return f"enc_from_{self.source_tag}_pattern_{self.case_name}"

    @property
    def prefix(self) -> str:
        return f"visual_from_{self.source_tag}_pattern_{self.width}x{self.height}_{self.source_tag}_{self.fmt}_verify"

    @property
    def format_readme(self) -> str:
        return self.fmt.upper()


def normalize_format(raw_fmt: str) -> str:
    fmt = raw_fmt.lower()
    if fmt in FORMAT_ALIASES:
        return FORMAT_ALIASES[fmt]
    return fmt


def parse_source_name(path: Path) -> tuple[int, int, int | None, int | None, str] | None:
    for pattern in SOURCE_PATTERNS:
        match = pattern.fullmatch(path.name)
        if match:
            stored_width = match.groupdict().get("stored_width")
            stored_height = match.groupdict().get("stored_height")
            return (
                int(match.group("width")),
                int(match.group("height")),
                int(stored_width) if stored_width is not None else None,
                int(stored_height) if stored_height is not None else None,
                normalize_format(match.group("fmt")),
            )
    return None


def make_layout(
    width: int,
    height: int,
    stored_width: int | None,
    stored_height: int | None,
    src_fmt: str,
    source_tag: str,
    source_note: str,
    base_addr: int,
) -> Layout:
    explicit_stored_size = stored_width is not None or stored_height is not None
    if src_fmt == "rgba8888":
        fmt = "rgba8888"
        has_uv = False
        bpp = 4
        tile_w = 16
        tile_h = 4
        stored_width_eff = stored_width if stored_width is not None else align(width, 64)
        stored_y = stored_height if stored_height is not None else align(height, 16)
        stored_uv = 0
        pitch_y = stored_width_eff * bpp
        pitch_uv = 0
    elif src_fmt == "rgba1010102":
        fmt = "rgba1010102"
        has_uv = False
        bpp = 4
        tile_w = 16
        tile_h = 4
        stored_width_eff = stored_width if stored_width is not None else align(width, 64)
        stored_y = stored_height if stored_height is not None else align(height, 16)
        stored_uv = 0
        pitch_y = stored_width_eff * bpp
        pitch_uv = 0
    elif src_fmt == "yuv420_nv12":
        fmt = "nv12"
        has_uv = True
        bpp = 1
        tile_w = 32
        tile_h = 8
        stored_width_eff = stored_width if stored_width is not None else align(width, 128)
        stored_y = stored_height if stored_height is not None else align(height, 64)
        stored_uv = align((height + 1) // 2, 32)
        pitch_y = stored_width_eff * bpp
        pitch_uv = pitch_y
    elif src_fmt == "yuv420_p010":
        fmt = "p010"
        has_uv = True
        bpp = 2
        tile_w = 32
        tile_h = 4
        stored_width_eff = stored_width if stored_width is not None else align(width, 128)
        stored_y = stored_height if stored_height is not None else align(height, 32)
        stored_uv = align((height + 1) // 2, 16)
        pitch_y = stored_width_eff * bpp
        pitch_uv = pitch_y
    else:
        raise ValueError(f"Unsupported source format: {src_fmt}")

    tile_cols = align((stored_width_eff + tile_w - 1) // tile_w, 1)
    tile_rows_y = stored_y // tile_h
    tile_rows_uv = stored_uv // tile_h if has_uv else 0
    meta_pitch_y = align(tile_cols, 64)
    meta_pitch_uv = meta_pitch_y if has_uv else 0
    meta_lines_y = align(tile_rows_y, 16)
    meta_lines_uv = align(tile_rows_uv, 16) if has_uv else 0

    meta_size_y = align(meta_pitch_y * meta_lines_y, 4096)
    tile_size_y = pitch_y * stored_y
    meta_size_uv = align(meta_pitch_uv * meta_lines_uv, 4096) if has_uv else 0
    tile_size_uv = pitch_uv * stored_uv if has_uv else 0
    if explicit_stored_size:
        source_tile_size_y = tile_size_y
    elif fmt == "nv12":
        source_tile_size_y = pitch_y * align(height, 32)
    elif fmt == "p010":
        source_tile_size_y = pitch_y * align(height, 16)
    else:
        source_tile_size_y = tile_size_y

    meta_base_y = base_addr
    tile_base_y = meta_base_y + meta_size_y
    meta_base_uv = tile_base_y + tile_size_y if has_uv else 0
    tile_base_uv = meta_base_uv + meta_size_uv if has_uv else 0

    linear_size_y = width * height * bpp
    linear_size_uv = width * ((height + 1) // 2) * bpp if has_uv else 0

    return Layout(
        src_fmt=src_fmt,
        fmt=fmt,
        source_tag=source_tag,
        source_note=source_note,
        base_addr=base_addr,
        width=width,
        height=height,
        stored_width=stored_width_eff,
        explicit_stored_size=explicit_stored_size,
        has_uv=has_uv,
        bpp=bpp,
        tile_w=tile_w,
        tile_h=tile_h,
        stored_y=stored_y,
        stored_uv=stored_uv,
        pitch_y=pitch_y,
        pitch_uv=pitch_uv,
        meta_pitch_y=meta_pitch_y,
        meta_pitch_uv=meta_pitch_uv,
        meta_lines_y=meta_lines_y,
        meta_lines_uv=meta_lines_uv,
        meta_size_y=meta_size_y,
        meta_size_uv=meta_size_uv,
        tile_size_y=tile_size_y,
        tile_size_uv=tile_size_uv,
        source_tile_size_y=source_tile_size_y,
        meta_base_y=meta_base_y,
        tile_base_y=tile_base_y,
        meta_base_uv=meta_base_uv,
        tile_base_uv=tile_base_uv,
        linear_size_y=linear_size_y,
        linear_size_uv=linear_size_uv,
    )


def hex_name(layout: Layout, suffix: str) -> str:
    return f"{layout.prefix}_{suffix}.txt"


def write_hex64(path: Path, base: int, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as fout:
        fout.write(f"@{base:016x}\n")
        for index in range(0, len(data), 8):
            chunk = data[index:index + 8]
            if len(chunk) < 8:
                chunk = chunk + bytes(8 - len(chunk))
            # The regression text format stores a 64-bit memory word as the
            # Verilog numeric value.  Therefore byte address +0 lives in the
            # least-significant byte, which is printed at the right side of
            # the 16-digit hex word.
            fout.write(f"{chunk[::-1].hex()}\n")


def meta_byte_offset(tile_x: int, tile_y: int, meta_pitch: int) -> int:
    return ((tile_y >> 4) * meta_pitch * 16) + \
           ((tile_x >> 4) << 8) + \
           (((tile_y >> 3) & 1) << 7) + \
           (((tile_x >> 3) & 1) << 6) + \
           ((tile_y & 7) << 3) + \
           (tile_x & 7)


def clear_inactive_meta_rows(
    data: bytes,
    tile_cols: int,
    active_tile_rows: int,
    stored_tile_rows: int,
    meta_pitch: int,
) -> bytes:
    patched = bytearray(data)
    for tile_y in range(active_tile_rows, stored_tile_rows):
        for tile_x in range(tile_cols):
            offset = meta_byte_offset(tile_x, tile_y, meta_pitch)
            if offset < len(patched):
                patched[offset] = 0
    return bytes(patched)


def macro_tile_slot(tile_x_mod8: int, tile_y_mod8: int) -> int:
    table = [
        [0, 6, 3, 5, 4, 2, 7, 1],
        [7, 1, 4, 2, 3, 5, 0, 6],
        [10, 12, 9, 15, 14, 8, 13, 11],
        [13, 11, 14, 8, 9, 15, 10, 12],
        [4, 2, 7, 1, 0, 6, 3, 5],
        [3, 5, 0, 6, 7, 1, 4, 2],
        [14, 8, 13, 11, 10, 12, 9, 15],
        [9, 15, 10, 12, 13, 11, 14, 8],
    ]
    return table[tile_x_mod8 & 7][tile_y_mod8 & 7]


def rgba_tile_base_byte(tile_x: int, tile_y: int, pitch_bytes: int) -> int:
    macro_tile_x = tile_x // 4
    macro_tile_y = tile_y // 4
    temp_tile_x = tile_x % 8
    temp_tile_y = tile_y % 8
    addr = (pitch_bytes * (macro_tile_y * 4) * 4) + \
           (macro_tile_x * 4096) + \
           (macro_tile_slot(temp_tile_x, temp_tile_y) * 256)

    if (16 * pitch_bytes) % (1 << 16) == 0:
        tile_row_pixels = tile_y * 4
        bit_val = ((addr >> 15) & 1) ^ ((tile_row_pixels >> 4) & 1)
        addr = (addr | (1 << 15)) if bit_val else (addr & ~(1 << 15))

    if (16 * pitch_bytes) % (1 << 17) == 0:
        tile_row_pixels = tile_y * 4
        bit_val = ((addr >> 16) & 1) ^ ((tile_row_pixels >> 5) & 1)
        addr = (addr | (1 << 16)) if bit_val else (addr & ~(1 << 16))

    return addr


def plane_tile_base_byte(
    tile_x: int,
    tile_y: int,
    tile_width: int,
    tile_height: int,
    pitch_bytes: int,
    bpp: int,
) -> int:
    macro_tile_x = tile_x // 4
    macro_tile_y = tile_y // 4
    temp_tile_x = tile_x % 8
    temp_tile_y = tile_y % 8
    addr = (pitch_bytes * (macro_tile_y * 4) * tile_height) + \
           (macro_tile_x * 4096) + \
           (macro_tile_slot(temp_tile_x, temp_tile_y) * 256)

    if (16 * pitch_bytes) % (1 << 16) == 0:
        if ((bpp == 1) and (tile_width == 32) and (tile_height == 8)) or \
           ((bpp == 2) and (tile_width == 16) and (tile_height == 8)):
            tile_row_pixels = (tile_y * tile_height) >> 5
        else:
            tile_row_pixels = (tile_y * tile_height) >> 4
        bit_val = ((addr >> 15) & 1) ^ (tile_row_pixels & 1)
        addr = (addr | (1 << 15)) if bit_val else (addr & ~(1 << 15))

    if (16 * pitch_bytes) % (1 << 17) == 0:
        if ((bpp == 1) and (tile_width == 32) and (tile_height == 8)) or \
           ((bpp == 2) and (tile_width == 16) and (tile_height == 8)):
            tile_row_pixels = (tile_y * tile_height) >> 6
        else:
            tile_row_pixels = (tile_y * tile_height) >> 5
        bit_val = ((addr >> 16) & 1) ^ (tile_row_pixels & 1)
        addr = (addr | (1 << 16)) if bit_val else (addr & ~(1 << 16))

    return addr


def tiled_uncompressed_from_linear(linear: bytes, layout: Layout, plane: str) -> bytes:
    if plane == "rgba":
        active_height = layout.height
        active_stride = layout.width * layout.bpp
        tile_cols = (layout.stored_width + 15) // 16
        active_tile_rows = (layout.height + 3) // 4
        tile_width_bytes = 16 * layout.bpp
        tile_height = 4
        out = bytearray(layout.tile_size_y)
        for tile_y in range(active_tile_rows):
            for tile_x in range(tile_cols):
                base = rgba_tile_base_byte(tile_x, tile_y, layout.pitch_y)
                for row in range(tile_height):
                    src_y = tile_y * tile_height + row
                    if src_y >= active_height:
                        continue
                    src_x = tile_x * tile_width_bytes
                    copy_len = min(tile_width_bytes, max(0, active_stride - src_x))
                    if copy_len <= 0:
                        continue
                    src = src_y * active_stride + src_x
                    dst = base + row * tile_width_bytes
                    out[dst:dst + copy_len] = linear[src:src + copy_len]
        return bytes(out)

    if plane == "y":
        active_height = layout.height
        active_stride = layout.width * layout.bpp
        tile_cols = (layout.stored_width + layout.tile_w - 1) // layout.tile_w
        active_tile_rows = (active_height + layout.tile_h - 1) // layout.tile_h
        tile_width = 32
        tile_height = layout.tile_h
        tile_width_bytes = tile_width * layout.bpp
        out = bytearray(layout.tile_size_y)
        for tile_y in range(active_tile_rows):
            for tile_x in range(tile_cols):
                base = plane_tile_base_byte(tile_x, tile_y, tile_width, tile_height,
                                            layout.pitch_y, layout.bpp)
                for row in range(tile_height):
                    src_y = tile_y * tile_height + row
                    if src_y >= active_height:
                        continue
                    src_x = tile_x * tile_width_bytes
                    copy_len = min(tile_width_bytes, max(0, active_stride - src_x))
                    if copy_len <= 0:
                        continue
                    src = src_y * active_stride + src_x
                    dst = base + row * tile_width_bytes
                    out[dst:dst + copy_len] = linear[src:src + copy_len]
        return bytes(out)

    active_height = (layout.height + 1) // 2
    active_stride = layout.width * layout.bpp
    tile_cols = (layout.stored_width + layout.tile_w - 1) // layout.tile_w
    active_tile_rows = (active_height + layout.tile_h - 1) // layout.tile_h
    if layout.fmt == "nv12":
        addr_tile_width = 16
        addr_bpp = 2
        tile_width_bytes = 32
        tile_height = 8
    else:
        addr_tile_width = 32
        addr_bpp = 2
        tile_width_bytes = 64
        tile_height = 4
    out = bytearray(layout.tile_size_uv)
    for tile_y in range(active_tile_rows):
        for tile_x in range(tile_cols):
            base = plane_tile_base_byte(tile_x, tile_y, addr_tile_width, tile_height,
                                        layout.pitch_uv, addr_bpp)
            for row in range(tile_height):
                src_y = tile_y * tile_height + row
                if src_y >= active_height:
                    continue
                src_x = tile_x * tile_width_bytes
                copy_len = min(tile_width_bytes, max(0, active_stride - src_x))
                if copy_len <= 0:
                    continue
                src = src_y * active_stride + src_x
                dst = base + row * tile_width_bytes
                out[dst:dst + copy_len] = linear[src:src + copy_len]
    return bytes(out)


def require_size(path: Path, actual: int, expected: int, label: str) -> None:
    if actual != expected:
        raise ValueError(f"{path}: {label} size {actual} != expected {expected}")


def crop_plane(data: bytes, stored_pitch_bytes: int, active_pitch_bytes: int, active_height: int) -> bytes:
    rows = []
    for row in range(active_height):
        start = row * stored_pitch_bytes
        rows.append(data[start:start + active_pitch_bytes])
    return b"".join(rows)


def split_raw(raw_path: Path, layout: Layout) -> tuple[bytes, bytes]:
    raw = raw_path.read_bytes()
    if layout.explicit_stored_size:
        raw_stored_y_size = layout.pitch_y * layout.stored_y
        raw_stored_uv_size = layout.pitch_uv * layout.stored_uv if layout.has_uv else 0
        expected = raw_stored_y_size + raw_stored_uv_size
    else:
        expected = layout.linear_size_y + layout.linear_size_uv
    require_size(raw_path, len(raw), expected, "raw")

    if not layout.explicit_stored_size:
        y = raw[:layout.linear_size_y]
        uv = raw[layout.linear_size_y:] if layout.has_uv else b""
        return y, uv

    y_stored = raw[:layout.pitch_y * layout.stored_y]
    y = crop_plane(y_stored, layout.pitch_y, layout.width * layout.bpp, layout.height)
    if not layout.has_uv:
        return y, b""

    uv_stored = raw[layout.pitch_y * layout.stored_y:]
    active_uv_height = (layout.height + 1) // 2
    uv = crop_plane(uv_stored, layout.pitch_uv, layout.width * layout.bpp, active_uv_height)
    return y, uv


def split_ubwc(ubwc_path: Path, layout: Layout) -> tuple[bytes, bytes, bytes, bytes]:
    ubwc = ubwc_path.read_bytes()
    expected = layout.meta_size_y + layout.source_tile_size_y + layout.meta_size_uv + layout.tile_size_uv
    require_size(ubwc_path, len(ubwc), expected, "raw.ubwc")
    pos = 0
    meta_y = ubwc[pos:pos + layout.meta_size_y]
    pos += layout.meta_size_y
    tile_y = ubwc[pos:pos + layout.source_tile_size_y]
    pos += layout.source_tile_size_y
    if len(tile_y) < layout.tile_size_y:
        tile_y = tile_y + bytes(layout.tile_size_y - len(tile_y))
    if not layout.has_uv:
        return meta_y, tile_y, b"", b""
    meta_uv = ubwc[pos:pos + layout.meta_size_uv]
    pos += layout.meta_size_uv
    tile_uv = ubwc[pos:pos + layout.tile_size_uv]
    return meta_y, tile_y, meta_uv, tile_uv


def make_readme(layout: Layout, files: dict[str, str]) -> str:
    lines: list[str] = []
    if layout.has_uv:
        lines.extend([
            f"Metadata RGB/Y-plane                    : {files['meta_y']}",
            f"Metadata UV-plane                       : {files['meta_uv']}",
            f"Tiled Compressed Image RGB/Y-plane      : {files['tile_y']}",
            f"Tiled Compressed Image UV-plane         : {files['tile_uv']}",
            f"Tiled Uncompressed Image RGB/Y-plane    : {files['tile_uncomp_y']}",
            f"Tiled Uncompressed Image UV-plane       : {files['tile_uncomp_uv']}",
            f"Linear Image Y-plane                    : {files['linear_y']}",
            f"Linear Image UV-plane                   : {files['linear_uv']}",
            f"Image format                            : {layout.format_readme}",
            f"Actual Image size(Pixels)               : {layout.width}x{layout.height}  WxH in (pixels/line x lines)  (Actual image size without padding)",
            f"Aligned Height for Pixel Data P0        : {layout.stored_y}       Single plane mode or dual plane mode Y plane height in lines",
            f"Aligned Height for Pixel Data P1        : {layout.stored_uv}       Dual plane mode UV plane height in lines",
            f"Pitch for Pixel Data P0                 : {layout.pitch_y}      Single plane mode or dual plane mode Y plane pitch in bytes",
            f"Pitch for Pixel Data P1                 : {layout.pitch_uv}      Dual plane mode UV plane pitch in bytes",
            f"Pitch for Meta Data P0                  : {layout.meta_pitch_y}       Single plane mode or dual plane mode Y metadata plane pitch in bytes",
            f"Height for Meta Data P0                 : {layout.meta_lines_y}       Single plane mode or dual plane mode Y metadata plane pitch in lines",
            f"Pitch for Meta Data P1                  : {layout.meta_pitch_uv}       Dual plane mode UV meta plane pitch in bytes",
            f"Height for Meta Data P1                 : {layout.meta_lines_uv}       Dual plane mode UV meta plane pitch in lines",
            f"Base Address Meta RGB/Y-plane              : 0x{layout.meta_base_y:016x}",
            f"Base Address Tile RGB/Y-plane              : 0x{layout.tile_base_y:016x}",
            f"Base Address Meta UV-plane               : 0x{layout.meta_base_uv:016x}",
            f"Base Address Tile UV-plane               : 0x{layout.tile_base_uv:016x}",
        ])
    else:
        lines.extend([
            f"Metadata RGB/Y-plane                    : {files['meta_y']}",
            "Metadata UV-plane                       :",
            f"Tiled Compressed Image RGB/Y-plane      : {files['tile_y']}",
            "Tiled Compressed Image UV-plane         :",
            f"Tiled Uncompressed Image RGB/Y-plane    : {files['tile_uncomp_y']}",
            "Tiled Uncompressed Image UV-plane       :",
            f"Linear Image                            : {files['linear_y']}",
            f"Image format                            : {layout.format_readme}",
            f"Actual Image size(Pixels)               : {layout.width}x{layout.height}   WxH in (pixels/line x lines)  (Actual image size without padding)",
            f"Aligned Height for Pixel Data P0        : {layout.stored_y}        Single plane mode or dual plane mode Y plane height in lines",
            f"Pitch for Pixel Data P0                 : {layout.pitch_y}      Single plane mode or dual plane mode Y plane pitch in bytes",
            f"Pitch for Meta Data P0                  : {layout.meta_pitch_y}        Single plane mode or dual plane mode Y metadata plane pitch in bytes",
            f"Height for Meta Data P0                 : {layout.meta_lines_y}        Single plane mode or dual plane mode Y metadata plane pitch in lines",
            f"Base Address Meta RGB/Y-plane              : 0x{layout.meta_base_y:016x}",
            f"Base Address Tile RGB/Y-plane              : 0x{layout.tile_base_y:016x}",
        ])

    lines.extend([
        "Highest bank bit                        : 16",
        "Mal size                                : 32",
        "Level1 bank swizzle bit                 : 0",
        "Level2 bank swizzle bit                 : 1",
        "Level3 bank swizzle bit                 : 1",
        "Bank spread                             : 1",
        "AMSBC                                   : 7 (UBWC7.1)",
        "LOSSY                                   : 0",
        "DDR mem channel                         : 8",
        f"Source                                  : {layout.source_note}",
        "Note                                    : Text files are 64-bit memory words with an @base address line; low-address byte is the rightmost byte in each word. The last linear active word is zero padded when the plane byte count is not 8-byte aligned.",
        "Note                                    : Metadata bytes for tile rows fully outside the active image are cleared; active rows keep aligned-width padding tile metadata.",
    ])
    if layout.has_uv:
        lines.append("Note                                    : Linear/tiled-uncompressed files keep active payload only; compressed/meta files follow aligned UBWC storage layout.")
    return "\n".join(lines) + "\n"


def convert_one(raw_path: Path, dst_root: Path, source_tag: str, source_note: str, base_addr: int, force: bool) -> Path:
    parsed = parse_source_name(raw_path)
    if parsed is None:
        raise ValueError(f"Unexpected source filename: {raw_path.name}")
    width, height, stored_width, stored_height, src_fmt = parsed
    layout = make_layout(width, height, stored_width, stored_height, src_fmt, source_tag, source_note, base_addr)
    ubwc_path = raw_path.with_suffix(raw_path.suffix + ".ubwc")
    if not ubwc_path.exists() and raw_path.name.endswith(".raw"):
        ubwc_path = raw_path.with_name(raw_path.name[:-4] + ".ubwc")
    if not ubwc_path.exists():
        raise FileNotFoundError(f"Missing paired UBWC file: {ubwc_path}")

    out_dir = dst_root / layout.out_dir_name
    if out_dir.exists():
        if not force:
            raise FileExistsError(f"{out_dir} exists; use --force to overwrite")
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    linear_y, linear_uv = split_raw(raw_path, layout)
    meta_y, tile_y, meta_uv, tile_uv = split_ubwc(ubwc_path, layout)
    tile_uncomp_y = tiled_uncompressed_from_linear(
        linear_y,
        layout,
        "rgba" if layout.fmt.startswith("rgba") else "y",
    )
    tile_cols = (layout.stored_width + layout.tile_w - 1) // layout.tile_w
    active_y_tile_rows = (layout.height + layout.tile_h - 1) // layout.tile_h
    stored_y_tile_rows = layout.stored_y // layout.tile_h
    meta_y = clear_inactive_meta_rows(meta_y,
                                      tile_cols,
                                      active_y_tile_rows,
                                      stored_y_tile_rows,
                                      layout.meta_pitch_y)

    files = {
        "meta_y": hex_name(layout, "ubwc_enc_out2"),
        "tile_y": hex_name(layout, "ubwc_enc_out0"),
        "linear_y": hex_name(layout, "pack10_out0"),
        "tile_uncomp_y": hex_name(layout, "ubwc_enc_in0"),
    }

    write_hex64(out_dir / files["meta_y"], layout.meta_base_y, meta_y)
    write_hex64(out_dir / files["tile_y"], layout.tile_base_y, tile_y)
    write_hex64(out_dir / files["linear_y"], layout.tile_base_y, linear_y)
    write_hex64(out_dir / files["tile_uncomp_y"], layout.tile_base_y, tile_uncomp_y)

    if layout.has_uv:
        tile_uncomp_uv = tiled_uncompressed_from_linear(linear_uv, layout, "uv")
        active_uv_height = (layout.height + 1) // 2
        active_uv_tile_rows = (active_uv_height + layout.tile_h - 1) // layout.tile_h
        stored_uv_tile_rows = layout.stored_uv // layout.tile_h
        meta_uv = clear_inactive_meta_rows(meta_uv,
                                           tile_cols,
                                           active_uv_tile_rows,
                                           stored_uv_tile_rows,
                                           layout.meta_pitch_uv)
        files.update({
            "meta_uv": hex_name(layout, "ubwc_enc_out3"),
            "tile_uv": hex_name(layout, "ubwc_enc_out1"),
            "linear_uv": hex_name(layout, "pack10_out1"),
            "tile_uncomp_uv": hex_name(layout, "ubwc_enc_in1"),
        })
        write_hex64(out_dir / files["meta_uv"], layout.meta_base_uv, meta_uv)
        write_hex64(out_dir / files["tile_uv"], layout.tile_base_uv, tile_uv)
        write_hex64(out_dir / files["linear_uv"], layout.tile_base_uv, linear_uv)
        write_hex64(out_dir / files["tile_uncomp_uv"], layout.tile_base_uv, tile_uncomp_uv)
    else:
        files["meta_uv"] = ""
        files["tile_uv"] = ""
        files["linear_uv"] = ""
        files["tile_uncomp_uv"] = ""

    # Keep both pack10_out* and ubwc_enc_in* on disk even though the current
    # R7130 source vectors use identical active-payload contents for them.
    (out_dir / "Readme.txt").write_text(make_readme(layout, files), encoding="ascii")

    return out_dir


def iter_sources(source: Path) -> list[Path]:
    paths = []
    for raw_path in sorted(source.rglob("*.raw")):
        if raw_path.name.endswith(".raw.ubwc"):
            continue
        if parse_source_name(raw_path) is not None:
            paths.append(raw_path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert raw/UBWC vectors to enc_from_<source-tag>_pattern_* directories.")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="Source directory containing .raw and .raw.ubwc files.")
    parser.add_argument("--source-tag", default=DEFAULT_SOURCE_TAG, help="Tag used in output directory and file names, e.g. r7130 or customer_a.")
    parser.add_argument("--source-note", default=None, help="Source text written to Readme.txt. Defaults to the source directory name.")
    parser.add_argument("--base-addr", default=f"0x{DEFAULT_BASE_ADDR:016x}", help="Base address for generated UBWC layout.")
    parser.add_argument("--dst-root", type=Path, default=VECTOR_ROOT, help="Destination vector root.")
    parser.add_argument("--case", action="append", default=[], help="Only convert cases containing this token, e.g. 720x1548 or nv12.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing destination directories.")
    args = parser.parse_args()

    if not args.source.is_dir():
        parser.error(f"source directory does not exist: {args.source}")
    source_tag = args.source_tag.strip().lower()
    if not re.fullmatch(r"[a-z0-9_]+", source_tag):
        parser.error("--source-tag may only contain lowercase letters, digits, and underscore")
    source_note = args.source_note if args.source_note is not None else args.source.name
    try:
        base_addr = int(str(args.base_addr), 0)
    except ValueError:
        parser.error(f"invalid --base-addr: {args.base_addr}")

    sources = iter_sources(args.source)
    if args.case:
        selected = []
        for path in sources:
            parsed = parse_source_name(path)
            if parsed is None:
                continue
            width, height, stored_width, stored_height, src_fmt = parsed
            layout = make_layout(width, height, stored_width, stored_height, src_fmt, source_tag, source_note, base_addr)
            haystack = f"{path.name} {layout.case_name} {layout.out_dir_name}"
            if any(token in haystack for token in args.case):
                selected.append(path)
        sources = selected
    if not sources:
        parser.error("no matching source vectors found")

    for raw_path in sources:
        out_dir = convert_one(raw_path, args.dst_root, source_tag, source_note, base_addr, args.force)
        print(f"[OK] {raw_path.name} -> {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
