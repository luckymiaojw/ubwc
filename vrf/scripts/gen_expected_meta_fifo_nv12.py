#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


BASE_FMT_NV12_Y = 0b01000
BASE_FMT_NV12_UV = 0b01001


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


def meta_format_for_pass(pass_idx: int) -> int:
    return BASE_FMT_NV12_UV if pass_idx == 2 else BASE_FMT_NV12_Y


def y_coord_for_pass(tile_y: int, pass_idx: int, row_phase: int) -> int:
    if pass_idx == 0:
        return tile_y * 16 + row_phase
    if pass_idx == 1:
        return tile_y * 16 + 8 + row_phase
    return tile_y * 8 + row_phase


def cmd_addr_for_pass(row_base_y: int, row_base_uv: int, tile_x: int, pass_idx: int) -> int:
    if pass_idx == 0:
        return row_base_y + tile_x * 256
    if pass_idx == 1:
        return row_base_y + 128 + tile_x * 256
    return row_base_uv + tile_x * 256


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


def generate_expected_fifo_stream(
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
    stride = tile_x_numbers << 8

    row_base_y = y_base_addr
    row_base_uv = uv_base_addr

    for tile_y in range(tile_y_numbers):
        for pass_idx in range(3):
            meta_format = meta_format_for_pass(pass_idx)
            is_last = 1 if pass_idx == 2 else 0
            plane_words = uv_words if pass_idx == 2 else y_words
            plane_base = uv_base_addr if pass_idx == 2 else y_base_addr

            # ubwc_dec_meta_data_from_sram serializes one row_phase across all tiles
            # first, then advances to the next row_phase.
            for row_phase in range(8):
                for tile_x in range(tile_x_numbers):
                    cmd_addr = cmd_addr_for_pass(row_base_y, row_base_uv, tile_x, pass_idx)
                    is_eol = 1 if tile_x == (tile_x_numbers - 1) else 0
                    word = read_word(plane_words, plane_base, cmd_addr + row_phase * 8)
                    y_row = y_coord_for_pass(tile_y, pass_idx, row_phase)
                    for byte_idx in range(8):
                        x_byte = tile_x * 8 + byte_idx
                        meta_byte = (word >> (byte_idx * 8)) & 0xFF
                        fifo_wdata = pack_fifo_wdata(meta_byte, meta_format, x_byte, y_row, is_eol, is_last)
                        expected.append((len(expected), 1, 1, fifo_wdata))

        row_base_y += stride
        row_base_uv += stride

    return expected


def write_expected_stream(path: Path, samples: list[tuple[int, int, int, int]]) -> None:
    lines: list[str] = []
    for index, fifo_vld, fifo_rdy, fifo_wdata in samples:
        lines.append(f"{index:06d} {fifo_vld:d} {fifo_rdy:d} {fifo_wdata:010x}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate expected fifo_wdata/fifo_vld/fifo_rdy stream for ubwc_dec_meta_data_gen NV12 metadata testbenches."
    )
    ap.add_argument("--y-vector", required=True, help="NV12 Y-plane metadata vector txt")
    ap.add_argument("--uv-vector", required=True, help="NV12 UV-plane metadata vector txt")
    ap.add_argument("--tile-x-numbers", type=int, required=True, help="tile_x_numbers used by the testbench")
    ap.add_argument("--tile-y-numbers", type=int, required=True, help="tile_y_numbers used by the testbench")
    ap.add_argument("--out", required=True, help="Output expected fifo stream txt")
    args = ap.parse_args()

    y_base_addr, y_words = parse_meta_vector(Path(args.y_vector))
    uv_base_addr, uv_words = parse_meta_vector(Path(args.uv_vector))

    expected = generate_expected_fifo_stream(
        y_words=y_words,
        uv_words=uv_words,
        y_base_addr=y_base_addr,
        uv_base_addr=uv_base_addr,
        tile_x_numbers=args.tile_x_numbers,
        tile_y_numbers=args.tile_y_numbers,
    )
    out_path = Path(args.out)
    write_expected_stream(out_path, expected)

    print("Generated expected NV12 metadata FIFO stream:")
    print(f"  Y vector         : {args.y_vector}")
    print(f"  UV vector        : {args.uv_vector}")
    print(f"  Y base addr      : 0x{y_base_addr:08x}")
    print(f"  UV base addr     : 0x{uv_base_addr:08x}")
    print(f"  tile_x_numbers   : {args.tile_x_numbers}")
    print(f"  tile_y_numbers   : {args.tile_y_numbers}")
    print(f"  expected samples : {len(expected)}")
    print(f"  output           : {out_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
