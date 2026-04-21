#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def parse_memh_words(path: Path) -> list[int]:
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


def rgba_beats_from_words(words64: list[int], width: int, stored_height: int) -> list[int]:
    words_per_line = width // 2
    beats: list[int] = []
    for y in range(stored_height):
        base = y * words_per_line
        for x in range(0, words_per_line, 2):
            lo = words64[base + x]
            hi = words64[base + x + 1]
            beats.append((hi << 64) | lo)
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


def nv12_expected_beats(y_plane: bytes, uv_plane: bytes, width: int, y_height: int, uv_phase: str = "odd") -> list[int]:
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

            if ((uv_phase == "odd") and (y & 1)) or ((uv_phase == "even") and ((y & 1) == 0)):
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


def load_u16_sample_le(plane: bytes, sample_index: int) -> int:
    byte_index = sample_index * 2
    return plane[byte_index] | (plane[byte_index + 1] << 8)


def store_u16_sample_le(plane: bytearray, sample_index: int, value: int) -> None:
    byte_index = sample_index * 2
    plane[byte_index] = value & 0xFF
    plane[byte_index + 1] = (value >> 8) & 0xFF


def p010_expected_beats(y_plane: bytes, uv_plane: bytes, width: int, y_height: int, uv_phase: str = "even") -> list[int]:
    beats: list[int] = []
    for y in range(y_height):
        y_base = y * width
        uv_base = (y >> 1) * width
        for x in range(0, width, 4):
            y0 = load_u16_sample_le(y_plane, y_base + x + 0) >> 6
            y1 = load_u16_sample_le(y_plane, y_base + x + 1) >> 6
            y2 = load_u16_sample_le(y_plane, y_base + x + 2) >> 6
            y3 = load_u16_sample_le(y_plane, y_base + x + 3) >> 6

            beat = 0
            beat |= y0 << 10
            beat |= y1 << 42
            beat |= y2 << 74
            beat |= y3 << 106

            if ((uv_phase == "odd") and (y & 1)) or ((uv_phase == "even") and ((y & 1) == 0)):
                u0 = load_u16_sample_le(uv_plane, uv_base + x + 0) >> 6
                v0 = load_u16_sample_le(uv_plane, uv_base + x + 1) >> 6
                u1 = load_u16_sample_le(uv_plane, uv_base + x + 2) >> 6
                v1 = load_u16_sample_le(uv_plane, uv_base + x + 3) >> 6
                beat |= v0 << 0
                beat |= u0 << 20
                beat |= v1 << 64
                beat |= u1 << 84

            beats.append(beat)
    return beats


def p010_planes_from_otf(beats128: list[int], width: int, y_height: int, uv_phase: str = "even") -> tuple[bytearray, bytearray]:
    beats_per_line = width // 4
    y_plane = bytearray(width * y_height * 2)
    uv_plane = bytearray(width * (y_height // 2) * 2)

    for idx in range(min(len(beats128), beats_per_line * y_height)):
        beat = beats128[idx]
        y = idx // beats_per_line
        x = (idx % beats_per_line) * 4
        y_base = y * width

        store_u16_sample_le(y_plane, y_base + x + 0, ((beat >> 10) & 0x3FF) << 6)
        store_u16_sample_le(y_plane, y_base + x + 1, ((beat >> 42) & 0x3FF) << 6)
        store_u16_sample_le(y_plane, y_base + x + 2, ((beat >> 74) & 0x3FF) << 6)
        store_u16_sample_le(y_plane, y_base + x + 3, ((beat >> 106) & 0x3FF) << 6)

        if ((uv_phase == "odd") and (y & 1)) or ((uv_phase == "even") and ((y & 1) == 0)):
            uv_base = (y >> 1) * width
            store_u16_sample_le(uv_plane, uv_base + x + 0, ((beat >> 20) & 0x3FF) << 6)
            store_u16_sample_le(uv_plane, uv_base + x + 1, ((beat >> 0) & 0x3FF) << 6)
            store_u16_sample_le(uv_plane, uv_base + x + 2, ((beat >> 84) & 0x3FF) << 6)
            store_u16_sample_le(uv_plane, uv_base + x + 3, ((beat >> 64) & 0x3FF) << 6)

    return y_plane, uv_plane


def write_otf_stream(path: Path, beats: list[int], width: int) -> None:
    lines: list[str] = []
    for beat in beats:
        lines.append(f"{beat:032x}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def compare_beats(expected_beats: list[int], actual_beats: list[int], width: int) -> tuple[int, tuple[int, int, int, int, int] | None]:
    compare_count = min(len(expected_beats), len(actual_beats))
    mismatch_count = 0
    first_mismatch: tuple[int, int, int, int, int] | None = None
    beats_per_line = width // 4

    for idx in range(compare_count):
        if expected_beats[idx] != actual_beats[idx]:
            mismatch_count += 1
            if first_mismatch is None:
                y = idx // beats_per_line
                x = (idx % beats_per_line) * 4
                first_mismatch = (idx, x, y, expected_beats[idx], actual_beats[idx])

    if len(expected_beats) != len(actual_beats) and first_mismatch is None:
        mismatch_count += abs(len(expected_beats) - len(actual_beats))

    return mismatch_count, first_mismatch


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


def rgba32_to_rgb(pixel: int) -> tuple[int, int, int]:
    r = pixel & 0xFF
    g = (pixel >> 8) & 0xFF
    b = (pixel >> 16) & 0xFF
    return r, g, b


def rgba8888_pixels_from_words(words64: list[int], width: int, height: int) -> bytearray:
    words_per_line = width // 2
    pixels = bytearray()
    for y in range(height):
        base = y * words_per_line
        for xw in range(words_per_line):
            word = words64[base + xw]
            for shift in (0, 32):
                pixels.extend(rgba32_to_rgb((word >> shift) & 0xFFFFFFFF))
    return pixels


def rgba8888_pixels_from_beats(beats128: list[int], width: int, height: int) -> bytearray:
    pixels = bytearray()
    needed = (width // 4) * height
    for idx in range(min(needed, len(beats128))):
        beat = beats128[idx]
        for shift in (0, 32, 64, 96):
            pixels.extend(rgba32_to_rgb((beat >> shift) & 0xFFFFFFFF))
    return pixels


def to_u8_10b(value: int) -> int:
    return (value * 255 + 511) // 1023


def rgba1010102_to_rgba(pixel: int) -> tuple[int, int, int, int]:
    r = to_u8_10b(pixel & 0x3FF)
    g = to_u8_10b((pixel >> 10) & 0x3FF)
    b = to_u8_10b((pixel >> 20) & 0x3FF)
    a = ((pixel >> 30) & 0x3) * 85
    return r, g, b, a


def rgba1010102_pixels_from_words(words64: list[int], width: int, height: int) -> tuple[bytearray, bytearray]:
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


def rgba1010102_pixels_from_beats(beats128: list[int], width: int, height: int) -> tuple[bytearray, bytearray]:
    rgb = bytearray()
    alpha = bytearray()
    needed = (width // 4) * height
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
            value = gray_plane[base + x]
            rgb.extend((value, value, value))
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


def compare_rgba8888(expected_path: Path, actual_path: Path, width: int, active_height: int, stored_height: int, out_dir: Path) -> int:
    words64 = parse_memh_words(expected_path)
    expected_beats = rgba_beats_from_words(words64, width, stored_height)
    actual_beats = parse_otf_beats(actual_path)
    mismatch_count, first_mismatch = compare_beats(expected_beats, actual_beats, width)

    exp_pixels = rgba8888_pixels_from_words(words64, width, active_height)
    act_pixels = rgba8888_pixels_from_beats(actual_beats, width, active_height)
    diff = diff_pixels(exp_pixels, act_pixels)

    out_dir.mkdir(parents=True, exist_ok=True)
    outputs = [
        ("expected_active", exp_pixels),
        ("actual_active", act_pixels),
        ("diff_active", diff),
    ]
    rendered_paths: list[tuple[str, Path]] = []
    for name, rgb in outputs:
        ppm_path = out_dir / f"{name}.ppm"
        write_ppm(ppm_path, width, active_height, rgb)
        rendered_paths.append((name, ppm_to_png(ppm_path) or ppm_path))

    print("OTF RGBA8888 compare summary:")
    print(f"  expected beats : {len(expected_beats)}")
    print(f"  actual beats   : {len(actual_beats)}")
    print(f"  compared beats : {min(len(expected_beats), len(actual_beats))}")
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

    return 0 if mismatch_count == 0 and len(expected_beats) == len(actual_beats) else 1


def compare_rgba1010102(expected_path: Path, actual_path: Path, width: int, active_height: int, stored_height: int, out_dir: Path) -> int:
    words64 = parse_memh_words(expected_path)
    expected_beats = rgba_beats_from_words(words64, width, stored_height)
    actual_beats = parse_otf_beats(actual_path)
    mismatch_count, first_mismatch = compare_beats(expected_beats, actual_beats, width)

    exp_rgb, exp_alpha = rgba1010102_pixels_from_words(words64, width, active_height)
    act_rgb, act_alpha = rgba1010102_pixels_from_beats(actual_beats, width, active_height)
    diff_rgb = diff_pixels(exp_rgb, act_rgb)
    diff_alpha = diff_pixels(exp_alpha, act_alpha)

    out_dir.mkdir(parents=True, exist_ok=True)
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
        write_ppm(ppm_path, width, active_height, rgb)
        rendered_paths.append((name, ppm_to_png(ppm_path) or ppm_path))

    print("OTF RGBA1010102 compare summary:")
    print(f"  expected beats : {len(expected_beats)}")
    print(f"  actual beats   : {len(actual_beats)}")
    print(f"  compared beats : {min(len(expected_beats), len(actual_beats))}")
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

    return 0 if mismatch_count == 0 and len(expected_beats) == len(actual_beats) else 1


def compare_nv12(expected_y_path: Path, expected_uv_path: Path, actual_path: Path, width: int, active_height: int, stored_y_height: int, stored_uv_height: int, out_dir: Path) -> int:
    expected_y_words = parse_memh_words(expected_y_path)
    expected_uv_words = parse_memh_words(expected_uv_path)
    actual_beats = parse_otf_beats(actual_path)

    expected_y_plane = words_to_plane(expected_y_words, width, stored_y_height)
    expected_uv_plane = words_to_plane(expected_uv_words, width, stored_uv_height)
    expected_beats = nv12_expected_beats(expected_y_plane, expected_uv_plane, width, stored_y_height)
    actual_y_plane, actual_uv_plane = nv12_planes_from_otf(actual_beats, width, stored_y_height)

    mismatch_count, first_mismatch = compare_beats(expected_beats, actual_beats, width)

    out_dir.mkdir(parents=True, exist_ok=True)
    active_uv_height = active_height // 2
    outputs = [
        ("expected_y_active", y_plane_to_rgb(expected_y_plane[: width * active_height], width, active_height), width, active_height),
        ("actual_y_active", y_plane_to_rgb(actual_y_plane[: width * active_height], width, active_height), width, active_height),
        ("diff_y_active", diff_pixels(y_plane_to_rgb(expected_y_plane[: width * active_height], width, active_height),
                                      y_plane_to_rgb(actual_y_plane[: width * active_height], width, active_height)), width, active_height),
        ("expected_uv_active", uv_plane_to_rgb(expected_uv_plane[: width * active_uv_height], width, active_uv_height), width // 2, active_uv_height),
        ("actual_uv_active", uv_plane_to_rgb(actual_uv_plane[: width * active_uv_height], width, active_uv_height), width // 2, active_uv_height),
        ("diff_uv_active", diff_pixels(uv_plane_to_rgb(expected_uv_plane[: width * active_uv_height], width, active_uv_height),
                                       uv_plane_to_rgb(actual_uv_plane[: width * active_uv_height], width, active_uv_height)), width // 2, active_uv_height),
        ("expected_u_active", gray_plane_to_rgb(extract_uv_component(expected_uv_plane, width, active_uv_height, 0), width // 2, active_uv_height), width // 2, active_uv_height),
        ("actual_u_active", gray_plane_to_rgb(extract_uv_component(actual_uv_plane, width, active_uv_height, 0), width // 2, active_uv_height), width // 2, active_uv_height),
        ("diff_u_active", diff_pixels(gray_plane_to_rgb(extract_uv_component(expected_uv_plane, width, active_uv_height, 0), width // 2, active_uv_height),
                                      gray_plane_to_rgb(extract_uv_component(actual_uv_plane, width, active_uv_height, 0), width // 2, active_uv_height)), width // 2, active_uv_height),
        ("expected_v_active", gray_plane_to_rgb(extract_uv_component(expected_uv_plane, width, active_uv_height, 1), width // 2, active_uv_height), width // 2, active_uv_height),
        ("actual_v_active", gray_plane_to_rgb(extract_uv_component(actual_uv_plane, width, active_uv_height, 1), width // 2, active_uv_height), width // 2, active_uv_height),
        ("diff_v_active", diff_pixels(gray_plane_to_rgb(extract_uv_component(expected_uv_plane, width, active_uv_height, 1), width // 2, active_uv_height),
                                      gray_plane_to_rgb(extract_uv_component(actual_uv_plane, width, active_uv_height, 1), width // 2, active_uv_height)), width // 2, active_uv_height),
        ("expected_rgb_active", nv12_to_rgb(expected_y_plane, expected_uv_plane, width, active_height), width, active_height),
        ("actual_rgb_active", nv12_to_rgb(actual_y_plane, actual_uv_plane, width, active_height), width, active_height),
        ("diff_rgb_active", diff_pixels(nv12_to_rgb(expected_y_plane, expected_uv_plane, width, active_height),
                                        nv12_to_rgb(actual_y_plane, actual_uv_plane, width, active_height)), width, active_height),
    ]
    rendered_paths: list[tuple[str, Path]] = []
    for name, rgb, out_width, out_height in outputs:
        ppm_path = out_dir / f"{name}.ppm"
        write_ppm(ppm_path, out_width, out_height, rgb)
        rendered_paths.append((name, ppm_to_png(ppm_path) or ppm_path))

    print("OTF NV12 compare summary:")
    print(f"  expected beats : {len(expected_beats)}")
    print(f"  actual beats   : {len(actual_beats)}")
    print(f"  compared beats : {min(len(expected_beats), len(actual_beats))}")
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

    return 0 if mismatch_count == 0 and len(expected_beats) == len(actual_beats) else 1


def compare_p010(expected_y_path: Path, expected_uv_path: Path, actual_path: Path, width: int, active_height: int, stored_y_height: int, stored_uv_height: int, out_dir: Path) -> int:
    expected_y_words = parse_memh_words(expected_y_path)
    expected_uv_words = parse_memh_words(expected_uv_path)
    actual_beats = parse_otf_beats(actual_path)

    expected_y_plane = words_to_plane(expected_y_words, width * 2, stored_y_height)
    expected_uv_plane = words_to_plane(expected_uv_words, width * 2, stored_uv_height)
    expected_beats = p010_expected_beats(expected_y_plane, expected_uv_plane, width, stored_y_height, "even")
    actual_y_plane, actual_uv_plane = p010_planes_from_otf(actual_beats, width, stored_y_height, "even")

    mismatch_count, first_mismatch = compare_beats(expected_beats, actual_beats, width)

    out_dir.mkdir(parents=True, exist_ok=True)
    print("OTF P010 compare summary:")
    print(f"  expected beats : {len(expected_beats)}")
    print(f"  actual beats   : {len(actual_beats)}")
    print(f"  compared beats : {min(len(expected_beats), len(actual_beats))}")
    print(f"  mismatch beats : {mismatch_count}")
    if first_mismatch is None:
        print("  first mismatch : none")
    else:
        idx, x, y, exp_word, act_word = first_mismatch
        print(f"  first mismatch : beat={idx} x={x} y={y}")
        print(f"    expected     : {exp_word:032x}")
        print(f"    actual       : {act_word:032x}")

    return 0 if mismatch_count == 0 and len(expected_beats) == len(actual_beats) else 1


def build_arg_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description="Unified OTF golden-stream generation and compare tool.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    gen = sub.add_parser("gen-stream", help="Generate expected OTF stream text from golden linear memh.")
    gen.add_argument("--format", choices=["rgba8888", "rgba1010102", "nv12", "p010"], required=True)
    gen.add_argument("--expected")
    gen.add_argument("--expected-y")
    gen.add_argument("--expected-uv")
    gen.add_argument("--width", type=int, required=True)
    gen.add_argument("--stored-height", type=int)
    gen.add_argument("--stored-y-height", type=int)
    gen.add_argument("--stored-uv-height", type=int)
    gen.add_argument("--nv12-uv-phase", choices=["odd", "even"], default="odd")
    gen.add_argument("--p010-uv-phase", choices=["odd", "even"], default="even")
    gen.add_argument("--out", required=True)

    cmp_p = sub.add_parser("compare", help="Compare OTF output against golden data and generate images.")
    cmp_p.add_argument("--format", choices=["rgba8888", "rgba1010102", "nv12", "p010"], required=True)
    cmp_p.add_argument("--expected")
    cmp_p.add_argument("--expected-y")
    cmp_p.add_argument("--expected-uv")
    cmp_p.add_argument("--actual", required=True)
    cmp_p.add_argument("--width", type=int, required=True)
    cmp_p.add_argument("--active-height", type=int, required=True)
    cmp_p.add_argument("--stored-height", type=int)
    cmp_p.add_argument("--stored-y-height", type=int)
    cmp_p.add_argument("--stored-uv-height", type=int)
    cmp_p.add_argument("--p010-uv-phase", choices=["odd", "even"], default="even")
    cmp_p.add_argument("--out-dir", required=True)

    return ap


def main() -> int:
    ap = build_arg_parser()
    args = ap.parse_args()

    if args.cmd == "gen-stream":
        out_path = Path(args.out)
        if args.format in ("rgba8888", "rgba1010102"):
            if not args.expected or args.stored_height is None:
                raise SystemExit("--expected and --stored-height are required for RGBA formats")
            words64 = parse_memh_words(Path(args.expected))
            expected_beats = rgba_beats_from_words(words64, args.width, args.stored_height)
            write_otf_stream(out_path, expected_beats, args.width)
            print(f"Generated expected OTF stream: {out_path}")
            print(f"  format         : {args.format}")
            print(f"  expected beats : {len(expected_beats)}")
            return 0

        if not args.expected_y or not args.expected_uv or args.stored_y_height is None or args.stored_uv_height is None:
            raise SystemExit("--expected-y/--expected-uv and stored heights are required for NV12/P010")
        if args.format == "p010":
            expected_y_plane = words_to_plane(parse_memh_words(Path(args.expected_y)), args.width * 2, args.stored_y_height)
            expected_uv_plane = words_to_plane(parse_memh_words(Path(args.expected_uv)), args.width * 2, args.stored_uv_height)
            expected_beats = p010_expected_beats(expected_y_plane, expected_uv_plane, args.width, args.stored_y_height, args.p010_uv_phase)
        else:
            expected_y_plane = words_to_plane(parse_memh_words(Path(args.expected_y)), args.width, args.stored_y_height)
            expected_uv_plane = words_to_plane(parse_memh_words(Path(args.expected_uv)), args.width, args.stored_uv_height)
            expected_beats = nv12_expected_beats(expected_y_plane, expected_uv_plane, args.width, args.stored_y_height, args.nv12_uv_phase)
        write_otf_stream(out_path, expected_beats, args.width)
        print(f"Generated expected OTF stream: {out_path}")
        print(f"  format         : {args.format}")
        print(f"  expected beats : {len(expected_beats)}")
        return 0

    actual_path = Path(args.actual)
    out_dir = Path(args.out_dir)
    if args.format == "rgba8888":
        if not args.expected or args.stored_height is None:
            raise SystemExit("--expected and --stored-height are required for RGBA8888 compare")
        return compare_rgba8888(Path(args.expected), actual_path, args.width, args.active_height, args.stored_height, out_dir)

    if args.format == "rgba1010102":
        if not args.expected or args.stored_height is None:
            raise SystemExit("--expected and --stored-height are required for RGBA1010102 compare")
        return compare_rgba1010102(Path(args.expected), actual_path, args.width, args.active_height, args.stored_height, out_dir)

    if not args.expected_y or not args.expected_uv or args.stored_y_height is None or args.stored_uv_height is None:
        raise SystemExit("--expected-y/--expected-uv and stored heights are required for NV12/P010 compare")
    if args.format == "p010":
        expected_y_words = parse_memh_words(Path(args.expected_y))
        expected_uv_words = parse_memh_words(Path(args.expected_uv))
        actual_beats = parse_otf_beats(actual_path)

        expected_y_plane = words_to_plane(expected_y_words, args.width * 2, args.stored_y_height)
        expected_uv_plane = words_to_plane(expected_uv_words, args.width * 2, args.stored_uv_height)
        expected_beats = p010_expected_beats(expected_y_plane, expected_uv_plane, args.width, args.stored_y_height, args.p010_uv_phase)
        actual_y_plane, actual_uv_plane = p010_planes_from_otf(actual_beats, args.width, args.stored_y_height, args.p010_uv_phase)

        mismatch_count, first_mismatch = compare_beats(expected_beats, actual_beats, args.width)

        out_dir.mkdir(parents=True, exist_ok=True)
        print("OTF P010 compare summary:")
        print(f"  expected beats : {len(expected_beats)}")
        print(f"  actual beats   : {len(actual_beats)}")
        print(f"  compared beats : {min(len(expected_beats), len(actual_beats))}")
        print(f"  mismatch beats : {mismatch_count}")
        if first_mismatch is None:
            print("  first mismatch : none")
        else:
            idx, x, y, exp_word, act_word = first_mismatch
            print(f"  first mismatch : beat={idx} x={x} y={y}")
            print(f"    expected     : {exp_word:032x}")
            print(f"    actual       : {act_word:032x}")

        return 0 if mismatch_count == 0 and len(expected_beats) == len(actual_beats) else 1
    return compare_nv12(Path(args.expected_y), Path(args.expected_uv), actual_path, args.width, args.active_height, args.stored_y_height, args.stored_uv_height, out_dir)


if __name__ == "__main__":
    raise SystemExit(main())
