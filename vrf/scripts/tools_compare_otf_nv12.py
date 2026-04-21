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


def words_to_plane(words64: list[int], width_bytes: int, height: int) -> bytearray:
    words_per_line = width_bytes // 8
    plane = bytearray(width_bytes * height)
    for y in range(height):
        line_base = y * words_per_line
        out_base = y * width_bytes
        for word_idx in range(words_per_line):
            word = words64[line_base + word_idx]
            for byte_lane in range(8):
                plane[out_base + word_idx * 8 + byte_lane] = (word >> (byte_lane * 8)) & 0xFF
    return plane


def expected_beats_from_planes(y_plane: bytes, uv_plane: bytes, width: int, y_height: int) -> list[int]:
    beats: list[int] = []
    for y in range(y_height):
        y_base = y * width
        uv_base = (y >> 1) * width
        for x in range(0, width, 4):
            y0 = y_plane[y_base + x + 0]
            y1 = y_plane[y_base + x + 1]
            y2 = y_plane[y_base + x + 2]
            y3 = y_plane[y_base + x + 3]

            beat = 0
            beat |= y0 << 8
            beat |= y1 << 40
            beat |= y2 << 72
            beat |= y3 << 104

            if y & 1:
                u0 = uv_plane[uv_base + x + 0]
                v0 = uv_plane[uv_base + x + 1]
                u1 = uv_plane[uv_base + x + 2]
                v1 = uv_plane[uv_base + x + 3]
                beat |= v0 << 0
                beat |= u0 << 16
                beat |= v1 << 64
                beat |= u1 << 80

            beats.append(beat)
    return beats


def nv12_planes_from_otf(beats128: list[int], width: int, y_height: int) -> tuple[bytearray, bytearray]:
    beats_per_line = width // 4
    y_plane = bytearray(width * y_height)
    uv_plane = bytearray(width * (y_height // 2))

    for idx in range(min(len(beats128), beats_per_line * y_height)):
        beat = beats128[idx]
        y = idx // beats_per_line
        x = (idx % beats_per_line) * 4
        y_base = y * width

        y_plane[y_base + x + 0] = (beat >> 8) & 0xFF
        y_plane[y_base + x + 1] = (beat >> 40) & 0xFF
        y_plane[y_base + x + 2] = (beat >> 72) & 0xFF
        y_plane[y_base + x + 3] = (beat >> 104) & 0xFF

        if y & 1:
            uv_base = (y >> 1) * width
            uv_plane[uv_base + x + 0] = (beat >> 16) & 0xFF
            uv_plane[uv_base + x + 1] = (beat >> 0) & 0xFF
            uv_plane[uv_base + x + 2] = (beat >> 80) & 0xFF
            uv_plane[uv_base + x + 3] = (beat >> 64) & 0xFF

    return y_plane, uv_plane


def y_plane_to_rgb(y_plane: bytes, width: int, height: int) -> bytearray:
    rgb = bytearray()
    for y in range(height):
        base = y * width
        for x in range(width):
            yv = y_plane[base + x]
            rgb.extend((yv, yv, yv))
    return rgb


def uv_plane_to_rgb(uv_plane: bytes, width: int, uv_height: int) -> bytearray:
    rgb = bytearray()
    for y in range(uv_height):
        base = y * width
        for x in range(0, width, 2):
            u = uv_plane[base + x + 0]
            v = uv_plane[base + x + 1]
            # One displayed pixel per UV pair. Map V/U into visible colors.
            rgb.extend((v, 128, u))
    return rgb


def extract_uv_component(uv_plane: bytes, width: int, uv_height: int, offset: int) -> bytearray:
    comp = bytearray((width // 2) * uv_height)
    for y in range(uv_height):
        base = y * width
        out_base = y * (width // 2)
        for x in range(width // 2):
            comp[out_base + x] = uv_plane[base + x * 2 + offset]
    return comp


def gray_plane_to_rgb(gray_plane: bytes, width: int, height: int) -> bytearray:
    rgb = bytearray()
    for y in range(height):
        base = y * width
        for x in range(width):
            val = gray_plane[base + x]
            rgb.extend((val, val, val))
    return rgb


def clip_u8(value: float) -> int:
    if value < 0.0:
        return 0
    if value > 255.0:
        return 255
    return int(value + 0.5)


def nv12_to_rgb(y_plane: bytes, uv_plane: bytes, width: int, active_height: int) -> bytearray:
    rgb = bytearray()
    for y in range(active_height):
        y_base = y * width
        uv_base = (y >> 1) * width
        for x in range(0, width, 2):
            u = uv_plane[uv_base + x + 0] - 128.0
            v = uv_plane[uv_base + x + 1] - 128.0
            for pixel in range(2):
                yy = float(y_plane[y_base + x + pixel])
                r = clip_u8(yy + 1.402 * v)
                g = clip_u8(yy - 0.344136 * u - 0.714136 * v)
                b = clip_u8(yy + 1.772 * u)
                rgb.extend((r, g, b))
    return rgb


def diff_rgb(exp_rgb: bytes, act_rgb: bytes) -> bytearray:
    diff = bytearray()
    triplets = min(len(exp_rgb), len(act_rgb)) // 3
    for idx in range(triplets):
        e0 = exp_rgb[idx * 3 + 0]
        e1 = exp_rgb[idx * 3 + 1]
        e2 = exp_rgb[idx * 3 + 2]
        a0 = act_rgb[idx * 3 + 0]
        a1 = act_rgb[idx * 3 + 1]
        a2 = act_rgb[idx * 3 + 2]
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
    ap.add_argument("--expected-y", required=True)
    ap.add_argument("--expected-uv", required=True)
    ap.add_argument("--actual", required=True)
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--active-height", type=int, required=True)
    ap.add_argument("--stored-y-height", type=int, required=True)
    ap.add_argument("--stored-uv-height", type=int, required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    expected_y_words = parse_pack10_words(Path(args.expected_y))
    expected_uv_words = parse_pack10_words(Path(args.expected_uv))
    actual_beats = parse_otf_beats(Path(args.actual))

    expected_y_plane = words_to_plane(expected_y_words, args.width, args.stored_y_height)
    expected_uv_plane = words_to_plane(expected_uv_words, args.width, args.stored_uv_height)
    expected_beats = expected_beats_from_planes(
        expected_y_plane, expected_uv_plane, args.width, args.stored_y_height
    )
    actual_y_plane, actual_uv_plane = nv12_planes_from_otf(
        actual_beats, args.width, args.stored_y_height
    )

    compare_count = min(len(expected_beats), len(actual_beats))
    mismatch_count = 0
    first_mismatch = None
    beats_per_line = args.width // 4

    for idx in range(compare_count):
        if expected_beats[idx] != actual_beats[idx]:
            mismatch_count += 1
            if first_mismatch is None:
                y = idx // beats_per_line
                x = (idx % beats_per_line) * 4
                first_mismatch = (idx, x, y, expected_beats[idx], actual_beats[idx])

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    exp_y_rgb = y_plane_to_rgb(expected_y_plane[: args.width * args.active_height], args.width, args.active_height)
    act_y_rgb = y_plane_to_rgb(actual_y_plane[: args.width * args.active_height], args.width, args.active_height)
    diff_y_rgb = diff_rgb(exp_y_rgb, act_y_rgb)

    active_uv_height = args.active_height // 2
    exp_uv_rgb = uv_plane_to_rgb(expected_uv_plane[: args.width * active_uv_height], args.width, active_uv_height)
    act_uv_rgb = uv_plane_to_rgb(actual_uv_plane[: args.width * active_uv_height], args.width, active_uv_height)
    diff_uv_rgb = diff_rgb(exp_uv_rgb, act_uv_rgb)

    exp_u_plane = extract_uv_component(expected_uv_plane, args.width, active_uv_height, 0)
    exp_v_plane = extract_uv_component(expected_uv_plane, args.width, active_uv_height, 1)
    act_u_plane = extract_uv_component(actual_uv_plane, args.width, active_uv_height, 0)
    act_v_plane = extract_uv_component(actual_uv_plane, args.width, active_uv_height, 1)

    exp_u_rgb = gray_plane_to_rgb(exp_u_plane, args.width // 2, active_uv_height)
    act_u_rgb = gray_plane_to_rgb(act_u_plane, args.width // 2, active_uv_height)
    diff_u_rgb = diff_rgb(exp_u_rgb, act_u_rgb)

    exp_v_rgb = gray_plane_to_rgb(exp_v_plane, args.width // 2, active_uv_height)
    act_v_rgb = gray_plane_to_rgb(act_v_plane, args.width // 2, active_uv_height)
    diff_v_rgb = diff_rgb(exp_v_rgb, act_v_rgb)

    exp_rgb = nv12_to_rgb(expected_y_plane, expected_uv_plane, args.width, args.active_height)
    act_rgb = nv12_to_rgb(actual_y_plane, actual_uv_plane, args.width, args.active_height)
    diff_rgb_img = diff_rgb(exp_rgb, act_rgb)

    outputs = [
        ("expected_y_active", exp_y_rgb),
        ("actual_y_active", act_y_rgb),
        ("diff_y_active", diff_y_rgb),
        ("expected_uv_active", exp_uv_rgb),
        ("actual_uv_active", act_uv_rgb),
        ("diff_uv_active", diff_uv_rgb),
        ("expected_u_active", exp_u_rgb),
        ("actual_u_active", act_u_rgb),
        ("diff_u_active", diff_u_rgb),
        ("expected_v_active", exp_v_rgb),
        ("actual_v_active", act_v_rgb),
        ("diff_v_active", diff_v_rgb),
        ("expected_rgb_active", exp_rgb),
        ("actual_rgb_active", act_rgb),
        ("diff_rgb_active", diff_rgb_img),
    ]

    rendered_paths: list[tuple[str, Path]] = []
    for name, rgb in outputs:
        ppm_path = out_dir / f"{name}.ppm"
        if "_u_" in name or "_v_" in name:
            write_ppm(ppm_path, args.width // 2, active_uv_height, rgb)
        elif "_uv_" in name:
            write_ppm(ppm_path, args.width // 2, active_uv_height, rgb)
        else:
            write_ppm(ppm_path, args.width, args.active_height, rgb)
        rendered_paths.append((name, ppm_to_png(ppm_path) or ppm_path))

    print("OTF NV12 compare summary:")
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
        print(f"  {name:18s}: {path}")

    return 0 if mismatch_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
