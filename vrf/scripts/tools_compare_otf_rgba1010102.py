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
        beats.append(int(line.split()[-1], 16))
    return beats


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


def to_u8_10b(value: int) -> int:
    return (value * 255 + 511) // 1023


def rgba1010102_to_rgba(pixel: int) -> tuple[int, int, int, int]:
    r = to_u8_10b(pixel & 0x3FF)
    g = to_u8_10b((pixel >> 10) & 0x3FF)
    b = to_u8_10b((pixel >> 20) & 0x3FF)
    a = ((pixel >> 30) & 0x3) * 85
    return r, g, b, a


def pixels_from_expected_words(words64: list[int], width: int, height: int) -> tuple[bytearray, bytearray]:
    words_per_line = width // 2
    rgb = bytearray()
    alpha = bytearray()
    for y in range(height):
        base = y * words_per_line
        for xw in range(words_per_line):
            word = words64[base + xw]
            for shift in (0, 32):
                r, g, b, a = rgba1010102_to_rgba((word >> shift) & 0xFFFFFFFF)
                rgb.extend((r, g, b))
                alpha.extend((a, a, a))
    return rgb, alpha


def pixels_from_otf_beats(beats128: list[int], width: int, height: int) -> tuple[bytearray, bytearray]:
    beats_per_line = width // 4
    rgb = bytearray()
    alpha = bytearray()
    needed = beats_per_line * height
    for idx in range(min(needed, len(beats128))):
        beat = beats128[idx]
        for shift in (0, 32, 64, 96):
            r, g, b, a = rgba1010102_to_rgba((beat >> shift) & 0xFFFFFFFF)
            rgb.extend((r, g, b))
            alpha.extend((a, a, a))
    return rgb, alpha


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

    exp_rgb, exp_alpha = pixels_from_expected_words(words64, args.width, args.active_height)
    act_rgb, act_alpha = pixels_from_otf_beats(actual_beats, args.width, args.active_height)
    diff_rgb = diff_pixels(exp_rgb, act_rgb)
    diff_alpha = diff_pixels(exp_alpha, act_alpha)

    outputs = [
        ("expected_active", exp_rgb),
        ("actual_active", act_rgb),
        ("diff_active", diff_rgb),
        ("expected_alpha", exp_alpha),
        ("actual_alpha", act_alpha),
        ("diff_alpha", diff_alpha),
    ]

    rendered_paths: list[tuple[str, Path]] = []
    for name, rgb in outputs:
        ppm_path = out_dir / f"{name}.ppm"
        write_ppm(ppm_path, args.width, args.active_height, rgb)
        rendered_paths.append((name, ppm_to_png(ppm_path) or ppm_path))

    print("OTF RGBA1010102 compare summary:")
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

    for name, path in rendered_paths:
        print(f"  {name:15s}: {path}")

    return 0 if mismatch_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
