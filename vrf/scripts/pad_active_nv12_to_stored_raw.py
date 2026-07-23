#!/usr/bin/env python3
"""Pad an active NV12/YUV420 source into the stored raw layout.

This script prepares staging input for ``convert_ubwc_raw_vectors.py``.  It
does not parse or transform the paired UBWC binary; when ``--ubwc`` is given,
the UBWC file is copied beside the generated raw using the required
``.raw.ubwc`` suffix.

Example:

    python3 vrf/scripts/pad_active_nv12_to_stored_raw.py \
      vrf/vector/pd2366_ubwc4_nv12_160x144/smptebars_160x144_yuv420p.yuv \
      --width 160 --height 144 \
      --stored-width 256 --stored-y 256 --stored-uv 96 \
      --output /tmp/pd2366_stage/pattern_w160_h144_s256x256_yuv420_nv12.raw \
      --ubwc vrf/vector/pd2366_ubwc4_nv12_160x144/smptebars_VideoPlayer_w160h136_256x144.ubwc
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


def align(value: int, boundary: int) -> int:
    return ((value + boundary - 1) // boundary) * boundary


def positive_int(text: str) -> int:
    value = int(text, 0)
    if value <= 0:
        raise argparse.ArgumentTypeError(f"expected positive integer, got {text}")
    return value


def default_output_path(source: Path, width: int, height: int, stored_width: int, stored_y: int) -> Path:
    name = f"pattern_w{width}_h{height}_s{stored_width}x{stored_y}_yuv420_nv12.raw"
    return source.with_name(name)


def read_active_nv12(raw: bytes, width: int, height: int) -> tuple[bytes, bytes]:
    y_size = width * height
    uv_height = (height + 1) // 2
    uv_size = width * uv_height
    expected = y_size + uv_size
    if len(raw) != expected:
        raise ValueError(f"NV12 source size mismatch: got {len(raw)} bytes, expected {expected}")
    return raw[:y_size], raw[y_size:]


def read_active_i420(raw: bytes, width: int, height: int) -> tuple[bytes, bytes]:
    if (width & 1) or (height & 1):
        raise ValueError("I420 input requires even width and height")

    y_size = width * height
    chroma_width = width // 2
    chroma_height = height // 2
    chroma_size = chroma_width * chroma_height
    expected = y_size + chroma_size * 2
    if len(raw) != expected:
        raise ValueError(f"I420 source size mismatch: got {len(raw)} bytes, expected {expected}")

    y_plane = raw[:y_size]
    u_plane = raw[y_size:y_size + chroma_size]
    v_plane = raw[y_size + chroma_size:]
    uv_plane = bytearray(width * chroma_height)

    for row in range(chroma_height):
        u_base = row * chroma_width
        uv_base = row * width
        for col in range(chroma_width):
            uv_plane[uv_base + (col * 2)] = u_plane[u_base + col]
            uv_plane[uv_base + (col * 2) + 1] = v_plane[u_base + col]

    return y_plane, bytes(uv_plane)


def build_stored_nv12(
    y_plane: bytes,
    uv_plane: bytes,
    width: int,
    height: int,
    stored_width: int,
    stored_y: int,
    stored_uv: int,
) -> bytes:
    active_uv_height = (height + 1) // 2
    if stored_width < width:
        raise ValueError(f"stored width {stored_width} is smaller than active width {width}")
    if stored_y < height:
        raise ValueError(f"stored Y height {stored_y} is smaller than active height {height}")
    if stored_uv < active_uv_height:
        raise ValueError(f"stored UV height {stored_uv} is smaller than active UV height {active_uv_height}")

    out = bytearray(stored_width * stored_y + stored_width * stored_uv)

    for row in range(height):
        src_base = row * width
        dst_base = row * stored_width
        out[dst_base:dst_base + width] = y_plane[src_base:src_base + width]

    uv_dst_offset = stored_width * stored_y
    for row in range(active_uv_height):
        src_base = row * width
        dst_base = uv_dst_offset + (row * stored_width)
        out[dst_base:dst_base + width] = uv_plane[src_base:src_base + width]

    return bytes(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="Pad active NV12/YUV420 data to a stored raw layout.")
    parser.add_argument("source", type=Path, help="Active input .yuv file.")
    parser.add_argument("--width", type=positive_int, required=True, help="Active width in pixels.")
    parser.add_argument("--height", type=positive_int, required=True, help="Active height in pixels.")
    parser.add_argument("--stored-width", type=positive_int, default=None, help="Stored pitch in bytes for NV12.")
    parser.add_argument("--stored-y", type=positive_int, default=None, help="Stored Y height in lines.")
    parser.add_argument("--stored-uv", type=positive_int, default=None, help="Stored UV height in lines.")
    parser.add_argument("--input-layout", choices=("nv12", "i420", "yuv420p"), default="nv12",
                        help="Active input layout. yuv420p is treated as I420.")
    parser.add_argument("--output", type=Path, default=None, help="Generated stored .raw path.")
    parser.add_argument("--ubwc", type=Path, default=None, help="Optional paired UBWC binary to copy as <output>.ubwc.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output files.")
    args = parser.parse_args()

    if not args.source.is_file():
        parser.error(f"source file does not exist: {args.source}")
    if args.ubwc is not None and not args.ubwc.is_file():
        parser.error(f"UBWC file does not exist: {args.ubwc}")

    stored_width = args.stored_width if args.stored_width is not None else align(args.width, 128)
    stored_y = args.stored_y if args.stored_y is not None else align(args.height, 64)
    stored_uv = args.stored_uv if args.stored_uv is not None else align((args.height + 1) // 2, 32)
    output = args.output if args.output is not None else default_output_path(args.source, args.width, args.height, stored_width, stored_y)
    ubwc_output = Path(str(output) + ".ubwc")

    if output.exists() and not args.force:
        parser.error(f"output already exists, use --force: {output}")
    if args.ubwc is not None and ubwc_output.exists() and not args.force:
        parser.error(f"UBWC output already exists, use --force: {ubwc_output}")

    raw = args.source.read_bytes()
    if args.input_layout == "nv12":
        y_plane, uv_plane = read_active_nv12(raw, args.width, args.height)
    else:
        y_plane, uv_plane = read_active_i420(raw, args.width, args.height)

    stored = build_stored_nv12(y_plane, uv_plane, args.width, args.height, stored_width, stored_y, stored_uv)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(stored)

    if args.ubwc is not None:
        shutil.copyfile(args.ubwc, ubwc_output)

    print(f"[OK] wrote {output} ({len(stored)} bytes)")
    if args.ubwc is not None:
        print(f"[OK] copied {args.ubwc} -> {ubwc_output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
