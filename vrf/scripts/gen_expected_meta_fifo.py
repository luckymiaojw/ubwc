#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


META_FMT_RGBA8888 = 0b00000
META_FMT_RGBA1010102 = 0b00001
META_FMT_NV12_Y = 0b01000
META_FMT_NV12_UV = 0b01001


def align_up(value: int, alignment: int) -> int:
    if alignment <= 0:
        raise ValueError("alignment must be positive")
    return ((value + alignment - 1) // alignment) * alignment


def parse_meta_vector(path: Path) -> tuple[int, list[int]]:
    base_addr: int | None = None
    words: list[int] = []

    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("@"):
            base_addr = int(line[1:], 16)
            continue
        words.append(int(line, 16))

    if base_addr is None:
        raise ValueError(f"Missing @base address line in {path}")

    return base_addr, words


def read_word(words: list[int], base_addr: int, addr: int) -> int:
    offset = addr - base_addr
    if offset < 0 or (offset % 8) != 0:
        raise ValueError(f"Invalid aligned 64-bit address 0x{addr:08x} for base 0x{base_addr:08x}")

    index = offset // 8
    if index >= len(words):
        raise IndexError(
            f"Address 0x{addr:08x} exceeds vector range 0x{base_addr:08x}-0x{base_addr + len(words) * 8:08x}"
        )
    return words[index]


def pack_fifo_wdata(meta_byte: int, meta_format: int, x_byte: int, y_row: int, eol: int, last: int) -> int:
    err = 0
    return (
        ((err & 0x1) << 37)
        | ((eol & 0x1) << 36)
        | ((last & 0x1) << 35)
        | ((meta_byte & 0xFF) << 27)
        | ((meta_format & 0x1F) << 22)
        | ((x_byte & 0xFFF) << 10)
        | (y_row & 0x3FF)
    )


def meta_cmd_addr(base_addr: int, x_cmd: int, y_block: int, pitch_bytes: int) -> int:
    meta_tile_row = y_block // 2
    meta_tile_col = x_cmd // 2
    return (
        base_addr
        + (meta_tile_row * pitch_bytes * 16)
        + (meta_tile_col * 256)
        + ((y_block & 1) * 128)
        + ((x_cmd & 1) * 64)
    )


def generate_expected_fifo_stream_nv12(
    y_words: list[int],
    uv_words: list[int],
    y_base_addr: int,
    uv_base_addr: int,
    tile_x_numbers: int,
    tile_y_numbers: int,
) -> list[tuple[int, int, int, int]]:
    if tile_x_numbers <= 0 or tile_y_numbers <= 0:
        raise ValueError("tile_x_numbers and tile_y_numbers must be positive")

    expected: list[tuple[int, int, int, int]] = []
    pitch_bytes = align_up(tile_x_numbers, 64)
    x_cmd_count = (tile_x_numbers + 7) // 8
    group_count = (tile_y_numbers + 15) // 16
    uv_tile_y_numbers = (tile_y_numbers + 1) // 2

    for group_idx in range(group_count):
        luma_rows_remaining = tile_y_numbers - group_idx * 16
        chroma_rows_remaining = uv_tile_y_numbers - group_idx * 8

        for slice_idx in range(8):
            y_row0_in_group = slice_idx * 2
            y_row1_in_group = y_row0_in_group + 1

            if y_row0_in_group < luma_rows_remaining:
                y_block = group_idx * 2 + (y_row0_in_group >> 3)
                row_phase = y_row0_in_group & 0x7
                y_row = group_idx * 16 + y_row0_in_group
                for x_cmd in range(x_cmd_count):
                    cmd_addr = meta_cmd_addr(y_base_addr, x_cmd, y_block, pitch_bytes)
                    is_eol = 1 if x_cmd == (x_cmd_count - 1) else 0
                    word = read_word(y_words, y_base_addr, cmd_addr + row_phase * 8)
                    for byte_idx in range(8):
                        x_byte = x_cmd * 8 + byte_idx
                        meta_byte = (word >> (byte_idx * 8)) & 0xFF
                        fifo_wdata = pack_fifo_wdata(meta_byte, META_FMT_NV12_Y, x_byte, y_row, is_eol, 0)
                        expected.append((len(expected), 1, 1, fifo_wdata))

            if y_row1_in_group < luma_rows_remaining:
                y_block = group_idx * 2 + (y_row1_in_group >> 3)
                row_phase = y_row1_in_group & 0x7
                y_row = group_idx * 16 + y_row1_in_group
                for x_cmd in range(x_cmd_count):
                    cmd_addr = meta_cmd_addr(y_base_addr, x_cmd, y_block, pitch_bytes)
                    is_eol = 1 if x_cmd == (x_cmd_count - 1) else 0
                    word = read_word(y_words, y_base_addr, cmd_addr + row_phase * 8)
                    for byte_idx in range(8):
                        x_byte = x_cmd * 8 + byte_idx
                        meta_byte = (word >> (byte_idx * 8)) & 0xFF
                        fifo_wdata = pack_fifo_wdata(meta_byte, META_FMT_NV12_Y, x_byte, y_row, is_eol, 0)
                        expected.append((len(expected), 1, 1, fifo_wdata))

            if slice_idx < chroma_rows_remaining:
                y_row = group_idx * 8 + slice_idx
                for x_cmd in range(x_cmd_count):
                    cmd_addr = meta_cmd_addr(uv_base_addr, x_cmd, group_idx, pitch_bytes)
                    is_eol = 1 if x_cmd == (x_cmd_count - 1) else 0
                    word = read_word(uv_words, uv_base_addr, cmd_addr + slice_idx * 8)
                    for byte_idx in range(8):
                        x_byte = x_cmd * 8 + byte_idx
                        meta_byte = (word >> (byte_idx * 8)) & 0xFF
                        fifo_wdata = pack_fifo_wdata(meta_byte, META_FMT_NV12_UV, x_byte, y_row, is_eol, 1)
                        expected.append((len(expected), 1, 1, fifo_wdata))

    return expected

def generate_expected_fifo_stream_rgba(
    words: list[int],
    base_addr: int,
    tile_x_numbers: int,
    tile_y_numbers: int,
    meta_format: int,
) -> list[tuple[int, int, int, int]]:
    if tile_x_numbers <= 0 or tile_y_numbers <= 0:
        raise ValueError("tile_x_numbers and tile_y_numbers must be positive")

    expected: list[tuple[int, int, int, int]] = []
    pitch_bytes = align_up(tile_x_numbers, 64)
    x_cmd_count = (tile_x_numbers + 7) // 8
    group_count = (tile_y_numbers + 15) // 16

    for group_idx in range(group_count):
        rows_remaining = tile_y_numbers - group_idx * 16
        pass_count = 2 if rows_remaining > 8 else 1

        for pass_idx in range(pass_count):
            is_last = 1 if pass_idx == (pass_count - 1) else 0
            y_block = group_idx * 2 + pass_idx
            y_row_base = group_idx * 16 + pass_idx * 8

            for row_phase in range(8):
                y_row = y_row_base + row_phase
                for x_cmd in range(x_cmd_count):
                    cmd_addr = meta_cmd_addr(base_addr, x_cmd, y_block, pitch_bytes)
                    is_eol = 1 if x_cmd == (x_cmd_count - 1) else 0
                    word = read_word(words, base_addr, cmd_addr + row_phase * 8)

                    for byte_idx in range(8):
                        x_byte = x_cmd * 8 + byte_idx
                        meta_byte = (word >> (byte_idx * 8)) & 0xFF
                        fifo_wdata = pack_fifo_wdata(meta_byte, meta_format, x_byte, y_row, is_eol, is_last)
                        expected.append((len(expected), 1, 1, fifo_wdata))

    return expected


def write_expected_stream(path: Path, samples: list[tuple[int, int, int, int]]) -> None:
    lines: list[str] = []
    for index, fifo_vld, fifo_rdy, fifo_wdata in samples:
        lines.append(f"{index:06d} {fifo_vld:d} {fifo_rdy:d} {fifo_wdata:010x}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate expected fifo_wdata/fifo_vld/fifo_rdy stream for ubwc_dec_meta_data_gen testbenches."
    )
    ap.add_argument("--format", choices=("rgba8888", "rgba1010102", "nv12"), help="Metadata case format")
    ap.add_argument("--plane0-vector", help="Plane0 metadata vector txt")
    ap.add_argument("--plane1-vector", help="Plane1 metadata vector txt (required for nv12)")
    ap.add_argument("--y-vector", dest="y_vector", help=argparse.SUPPRESS)
    ap.add_argument("--uv-vector", dest="uv_vector", help=argparse.SUPPRESS)
    ap.add_argument("--tile-x-numbers", type=int, required=True, help="tile_x_numbers used by the testbench")
    ap.add_argument("--tile-y-numbers", type=int, required=True, help="tile_y_numbers used by the testbench")
    ap.add_argument("--out", required=True, help="Output expected fifo stream txt")
    args = ap.parse_args()

    fmt = args.format
    plane0_arg = args.plane0_vector
    plane1_arg = args.plane1_vector

    if plane0_arg is None and args.y_vector is not None:
        plane0_arg = args.y_vector
    if plane1_arg is None and args.uv_vector is not None:
        plane1_arg = args.uv_vector
    if fmt is None and args.y_vector is not None:
        fmt = "nv12"

    if fmt is None:
        ap.error("--format is required")
    if plane0_arg is None:
        ap.error("--plane0-vector is required")
    if fmt == "nv12" and plane1_arg is None:
        ap.error("--plane1-vector is required for nv12")

    plane0_base_addr, plane0_words = parse_meta_vector(Path(plane0_arg))

    if fmt == "nv12":
        assert plane1_arg is not None
        plane1_base_addr, plane1_words = parse_meta_vector(Path(plane1_arg))
        expected = generate_expected_fifo_stream_nv12(
            y_words=plane0_words,
            uv_words=plane1_words,
            y_base_addr=plane0_base_addr,
            uv_base_addr=plane1_base_addr,
            tile_x_numbers=args.tile_x_numbers,
            tile_y_numbers=args.tile_y_numbers,
        )
    else:
        meta_format = META_FMT_RGBA1010102 if fmt == "rgba1010102" else META_FMT_RGBA8888
        expected = generate_expected_fifo_stream_rgba(
            words=plane0_words,
            base_addr=plane0_base_addr,
            tile_x_numbers=args.tile_x_numbers,
            tile_y_numbers=args.tile_y_numbers,
            meta_format=meta_format,
        )

    out_path = Path(args.out)
    write_expected_stream(out_path, expected)

    print("Generated expected metadata FIFO stream:")
    print(f"  format           : {fmt}")
    print(f"  plane0 vector    : {plane0_arg}")
    print(f"  plane0 base addr : 0x{plane0_base_addr:08x}")
    if fmt == "nv12":
        assert plane1_arg is not None
        print(f"  plane1 vector    : {plane1_arg}")
        print(f"  plane1 base addr : 0x{plane1_base_addr:08x}")
    print(f"  tile_x_numbers   : {args.tile_x_numbers}")
    print(f"  tile_y_numbers   : {args.tile_y_numbers}")
    print(f"  expected samples : {len(expected)}")
    print(f"  output           : {out_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
