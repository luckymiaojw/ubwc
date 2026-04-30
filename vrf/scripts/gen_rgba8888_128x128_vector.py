#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


WIDTH = 128
HEIGHT = 128
TILE_W = 16
TILE_H = 4
WORDS64_PER_LINE = WIDTH // 2
WORDS64_PER_TILE = (TILE_W * TILE_H * 4) // 8
SURFACE_PITCH_BYTES = WIDTH * 4
META_PITCH_BYTES = 64
META_LINES = 32


def macro_tile_slot(tile_x_mod8: int, tile_y_mod8: int) -> int:
    table = (
        (0, 6, 3, 5, 4, 2, 7, 1),
        (7, 1, 4, 2, 3, 5, 0, 6),
        (10, 12, 9, 15, 14, 8, 13, 11),
        (13, 11, 14, 8, 9, 15, 10, 12),
        (4, 2, 7, 1, 0, 6, 3, 5),
        (3, 5, 0, 6, 7, 1, 4, 2),
        (14, 8, 13, 11, 10, 12, 9, 15),
        (9, 15, 10, 12, 13, 11, 14, 8),
    )
    return table[tile_x_mod8][tile_y_mod8]


def rgba_pixel(x: int, y: int) -> int:
    r = ((x * 3) + (y * 5)) & 0xFF
    g = ((x * 7) + (y * 11)) & 0xFF
    b = ((x * 13) ^ (y * 17)) & 0xFF
    a = 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r


def linear_word64(x_pair: int, y: int) -> int:
    x0 = x_pair * 2
    p0 = rgba_pixel(x0, y)
    p1 = rgba_pixel(x0 + 1, y)
    return (p1 << 32) | p0


def build_linear_words() -> list[int]:
    words: list[int] = []
    for y in range(HEIGHT):
        for x_pair in range(WORDS64_PER_LINE):
            words.append(linear_word64(x_pair, y))
    return words


def build_compact_tiled_words(linear_words: list[int]) -> list[int]:
    words: list[int] = []
    tile_x_count = WIDTH // TILE_W
    tile_y_count = HEIGHT // TILE_H
    for tile_y in range(tile_y_count):
        for tile_x in range(tile_x_count):
            base_y = tile_y * TILE_H
            base_x_word = tile_x * (TILE_W // 2)
            for local_word in range(WORDS64_PER_TILE):
                local_y = local_word // (TILE_W // 2)
                local_x_word = local_word % (TILE_W // 2)
                linear_idx = (base_y + local_y) * WORDS64_PER_LINE + base_x_word + local_x_word
                words.append(linear_words[linear_idx])
    return words


def rgba_tile_base_word(tile_x: int, tile_y: int) -> int:
    macro_tile_x = tile_x // 4
    macro_tile_y = tile_y // 4
    temp_tile_x = tile_x % 8
    temp_tile_y = tile_y % 8
    addr_bytes = (
        SURFACE_PITCH_BYTES * (macro_tile_y * 4) * TILE_H
        + macro_tile_x * 4096
        + macro_tile_slot(temp_tile_x, temp_tile_y) * 256
    )
    return addr_bytes >> 3


def build_mapped_tiled_words(linear_words: list[int]) -> list[int]:
    words = [0] * ((SURFACE_PITCH_BYTES * HEIGHT) // 8)
    tile_x_count = WIDTH // TILE_W
    tile_y_count = HEIGHT // TILE_H
    for tile_y in range(tile_y_count):
        for tile_x in range(tile_x_count):
            dst_base = rgba_tile_base_word(tile_x, tile_y)
            src_base_y = tile_y * TILE_H
            src_base_x_word = tile_x * (TILE_W // 2)
            for local_word in range(WORDS64_PER_TILE):
                local_y = local_word // (TILE_W // 2)
                local_x_word = local_word % (TILE_W // 2)
                src_idx = (src_base_y + local_y) * WORDS64_PER_LINE + src_base_x_word + local_x_word
                words[dst_base + local_word] = linear_words[src_idx]
    return words


def build_otf_beats(linear_words: list[int]) -> list[int]:
    beats: list[int] = []
    for y in range(HEIGHT):
        line_base = y * WORDS64_PER_LINE
        for x_word in range(0, WORDS64_PER_LINE, 2):
            lo = linear_words[line_base + x_word]
            hi = linear_words[line_base + x_word + 1]
            beats.append((hi << 64) | lo)
    return beats


def write_words(path: Path, words: list[int], width: int) -> None:
    path.write_text("".join(f"{word:0{width}x}\n" for word in words))


def main() -> int:
    out_dir = Path(__file__).resolve().parents[1] / "vector" / "rgba8888_128x128"
    out_dir.mkdir(parents=True, exist_ok=True)

    linear_words = build_linear_words()
    tiled_words = build_compact_tiled_words(linear_words)
    mapped_tiled_words = build_mapped_tiled_words(linear_words)
    otf_beats = build_otf_beats(linear_words)
    meta_words = [0] * ((META_PITCH_BYTES * META_LINES) // 8)

    write_words(out_dir / "rgba8888_128x128_linear.memh", linear_words, 16)
    write_words(out_dir / "rgba8888_128x128_tiled.memh", tiled_words, 16)
    write_words(out_dir / "rgba8888_128x128_tiled_mapped.memh", mapped_tiled_words, 16)
    write_words(out_dir / "rgba8888_128x128_meta_dummy.memh", meta_words, 16)
    write_words(out_dir / "rgba8888_128x128_expected_otf_stream.txt", otf_beats, 32)

    (out_dir / "Readme.txt").write_text(
        "RGBA8888 128x128 generated vector\n"
        "\n"
        "Format:\n"
        "  - rgba8888_128x128_linear.memh: 64-bit words, raster scan, two pixels per word\n"
        "  - rgba8888_128x128_tiled.memh: 64-bit words, compact 16x4 tile scan\n"
        "  - rgba8888_128x128_tiled_mapped.memh: 64-bit words in UBWC tile-address layout\n"
        "  - rgba8888_128x128_meta_dummy.memh: dummy metadata for FORCE_FULL_PAYLOAD decoder wrapper runs\n"
        "  - rgba8888_128x128_expected_otf_stream.txt: 128-bit OTF beats, four pixels per beat\n"
        "\n"
        "Pixel pattern:\n"
        "  r = x * 3 + y * 5\n"
        "  g = x * 7 + y * 11\n"
        "  b = x * 13 xor y * 17\n"
        "  a = 0xff\n"
    )

    print(f"Generated {out_dir}")
    print(f"  linear words : {len(linear_words)}")
    print(f"  tiled words  : {len(tiled_words)}")
    print(f"  mapped words : {len(mapped_tiled_words)}")
    print(f"  meta words   : {len(meta_words)}")
    print(f"  otf beats    : {len(otf_beats)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
