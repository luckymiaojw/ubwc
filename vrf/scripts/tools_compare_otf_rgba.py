#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def parse_pack10_words(path: Path) -> list[int]:
    words: list[int] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("@"):
            continue
        words.append(int(line, 16))
    return words


def parse_otf_beats(path: Path) -> list[int]:
    beats: list[int] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split()
        beats.append(int(parts[-1], 16))
    return beats


def rgba32_to_rgb(pixel: int) -> tuple[int, int, int]:
    r = pixel & 0xFF
    g = (pixel >> 8) & 0xFF
    b = (pixel >> 16) & 0xFF
    return r, g, b


def expected_beats_from_words(words64: list[int], width: int, stored_height: int) -> list[int]:
    words_per_line = width // 2
    beats: list[int] = []
    for y in range(stored_height):
        base = y * words_per_line
        for x in range(0, words_per_line, 2):
            lo = words64[base + x]
            hi = words64[base + x + 1]
            beats.append((hi << 64) | lo)
    return beats


def pixels_from_expected_words(words64: list[int], width: int, height: int) -> bytearray:
    words_per_line = width // 2
    pixels = bytearray()
    for y in range(height):
        base = y * words_per_line
        for xw in range(words_per_line):
            word = words64[base + xw]
            for shift in (0, 32):
                pixels.extend(rgba32_to_rgb((word >> shift) & 0xFFFFFFFF))
    return pixels


def pixels_from_otf_beats(beats128: list[int], width: int, height: int) -> bytearray:
    beats_per_line = width // 4
    pixels = bytearray()
    needed = beats_per_line * height
    for idx in range(min(needed, len(beats128))):
        beat = beats128[idx]
        for shift in (0, 32, 64, 96):
            pixels.extend(rgba32_to_rgb((beat >> shift) & 0xFFFFFFFF))
    return pixels


def diff_pixels(exp_pixels: bytes, act_pixels: bytes) -> bytearray:
    diff = bytearray()
    triplets = min(len(exp_pixels), len(act_pixels)) // 3
    for idx in range(triplets):
        e0 = exp_pixels[idx * 3 + 0]
        e1 = exp_pixels[idx * 3 + 1]
        e2 = exp_pixels[idx * 3 + 2]
        a0 = act_pixels[idx * 3 + 0]
        a1 = act_pixels[idx * 3 + 1]
        a2 = act_pixels[idx * 3 + 2]
        if (e0, e1, e2) == (a0, a1, a2):
            diff.extend((0, 0, 0))
        else:
            diff.extend((255, abs(e1 - a1), abs(e2 - a2)))
    return diff


def write_ppm(path: Path, width: int, height: int, rgb: bytes) -> None:
    header = f"P6\n{width} {height}\n255\n".encode("ascii")
    path.write_bytes(header + rgb)


def ppm_to_png(ppm_path: Path) -> Path | None:
    png_path = ppm_path.with_suffix(".png")
    try:
        subprocess.run(
            ["/usr/bin/sips", "-s", "format", "png", str(ppm_path), "--out", str(png_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return png_path
    except Exception:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--expected", required=True)
    ap.add_argument("--actual", required=True)
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--active-height", type=int, required=True)
    ap.add_argument("--stored-height", type=int, required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    expected_path = Path(args.expected)
    actual_path = Path(args.actual)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    words64 = parse_pack10_words(expected_path)
    actual_beats = parse_otf_beats(actual_path)
    expected_beats = expected_beats_from_words(words64, args.width, args.stored_height)

    compare_count = min(len(expected_beats), len(actual_beats))
    mismatch_count = 0
    first_mismatch = None
    for idx in range(compare_count):
        if expected_beats[idx] != actual_beats[idx]:
            mismatch_count += 1
            if first_mismatch is None:
                y = idx // (args.width // 4)
                x = (idx % (args.width // 4)) * 4
                first_mismatch = (idx, x, y, expected_beats[idx], actual_beats[idx])

    exp_pixels = pixels_from_expected_words(words64, args.width, args.active_height)
    act_pixels = pixels_from_otf_beats(actual_beats, args.width, args.active_height)
    diff = diff_pixels(exp_pixels, act_pixels)

    exp_ppm = out_dir / "expected_active.ppm"
    act_ppm = out_dir / "actual_active.ppm"
    diff_ppm = out_dir / "diff_active.ppm"
    write_ppm(exp_ppm, args.width, args.active_height, exp_pixels)
    write_ppm(act_ppm, args.width, args.active_height, act_pixels)
    write_ppm(diff_ppm, args.width, args.active_height, diff)

    exp_png = ppm_to_png(exp_ppm)
    act_png = ppm_to_png(act_ppm)
    diff_png = ppm_to_png(diff_ppm)

    print("OTF compare summary:")
    print(f"  expected beats : {len(expected_beats)}")
    print(f"  actual beats   : {len(actual_beats)}")
    print(f"  compared beats : {compare_count}")
    print(f"  mismatch beats : {mismatch_count}")
    if first_mismatch is None:
        print("  first mismatch : none")
    else:
        idx, x, y, exp_word, act_word = first_mismatch
        print(f"  first mismatch : beat={idx} x={x} y={y}")
        print(f"    expected     : {exp_word:032x}")
        print(f"    actual       : {act_word:032x}")

    print(f"  expected image : {exp_png or exp_ppm}")
    print(f"  actual image   : {act_png or act_ppm}")
    print(f"  diff image     : {diff_png or diff_ppm}")
    return 0 if mismatch_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
