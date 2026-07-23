#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = PROJECT_ROOT / "vrf" / "scripts"
CASE_ROOT = PROJECT_ROOT / "vrf" / "vector" / "cases"
VECTOR_DB = PROJECT_ROOT / "vrf" / "vector" / "vector_db.csv"

sys.path.insert(0, str(SCRIPT_DIR))
import otf_case_tool as otf_tool  # noqa: E402
import ubwc_vector_regression as reg_flow  # noqa: E402


def rotate_u8_plane(src: bytes, width: int, height: int, rotation: int) -> bytearray:
    out_width = height
    out_height = width
    dst = bytearray(out_width * out_height)

    for out_y in range(out_height):
        for out_x in range(out_width):
            if rotation == 90:
                src_x = out_y
                src_y = height - 1 - out_x
            else:
                src_x = width - 1 - out_y
                src_y = out_x
            dst[out_y * out_width + out_x] = src[src_y * width + src_x]

    return dst


def rotate_nv12_uv_plane(src: bytes, width: int, height: int, rotation: int) -> bytearray:
    chroma_width = width // 2
    chroma_height = height // 2
    out_chroma_width = chroma_height
    out_chroma_height = chroma_width
    dst = bytearray(out_chroma_width * out_chroma_height * 2)

    for out_y in range(out_chroma_height):
        for out_x in range(out_chroma_width):
            if rotation == 90:
                src_x = out_y
                src_y = chroma_height - 1 - out_x
            else:
                src_x = chroma_width - 1 - out_y
                src_y = out_x
            src_idx = (src_y * chroma_width + src_x) * 2
            dst_idx = (out_y * out_chroma_width + out_x) * 2
            dst[dst_idx + 0] = src[src_idx + 0]
            dst[dst_idx + 1] = src[src_idx + 1]

    return dst


def nv12_active_planes(case: reg_flow.VectorCase) -> tuple[bytearray, bytearray]:
    y_words = reg_flow.active_linear_words(case, 0)
    uv_words = reg_flow.active_linear_words(case, 1)
    y_plane = otf_tool.words_to_linear_bytes(y_words, case.width * case.height)
    uv_plane = otf_tool.words_to_linear_bytes(uv_words, case.width * case.active_uv_height)
    return y_plane, uv_plane


def eligible(case: reg_flow.VectorCase) -> tuple[bool, str]:
    if case.fmt != "nv12":
        return False, "only NV12 rotation is supported"
    if case.width % 2 or case.height % 2:
        return False, "NV12 rotation requires even width and height"
    if case.height % 4:
        return False, "rotated OTF width must be a multiple of 4 beats"
    if case.height == 0 or case.width == 0:
        return False, "empty image"
    return True, ""


def generate_one(case_dir: Path, rotation: int, out_path: Path) -> int:
    case = reg_flow.load_case(case_dir)
    ok, reason = eligible(case)
    if not ok:
        print(f"[SKIP] {case_dir.name}: {reason}")
        return 2

    y_plane, uv_plane = nv12_active_planes(case)
    out_width = case.height
    out_height = case.width
    out_uv_height = out_height // 2
    rot_y = rotate_u8_plane(y_plane, case.width, case.height, rotation)
    rot_uv = rotate_nv12_uv_plane(uv_plane, case.width, case.height, rotation)
    beats = otf_tool.nv12_expected_beats(rot_y, rot_uv, out_width, out_height, "even")
    otf_tool.write_otf_stream(out_path, beats, out_width)

    print(f"[GEN] {case_dir.name} rot{rotation}: {out_path}")
    print(f"      input  {case.width}x{case.height} -> output {out_width}x{out_height}")
    print(f"      uv     {out_width}x{out_uv_height}, beats={len(beats)}")
    return 0


def discover_cases(root: Path) -> list[Path]:
    out: list[Path] = []
    for readme in sorted(root.glob("*/Readme.txt")):
        out.append(readme.parent)
    for readme in sorted(root.glob("*/ReadMe.txt")):
        if readme.parent not in out:
            out.append(readme.parent)
    return out


def discover_cases_from_db(db_path: Path) -> list[Path]:
    out: list[Path] = []
    if not db_path.exists():
        return out
    with db_path.open(newline="") as f:
        for row in csv.DictReader(f):
            fmt = (row.get("format") or "").strip().lower()
            modes = (row.get("modes") or "").strip().lower()
            case_dir = (row.get("case_dir") or "").strip()
            if fmt != "nv12" or "dec" not in modes or not case_dir:
                continue
            path = Path(case_dir)
            if not path.is_absolute():
                path = PROJECT_ROOT / path
            if path not in out:
                out.append(path)
    return out


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate 90/270 degree NV12 OTF golden streams for dec_rotation.",
    )
    parser.add_argument("--case-dir", type=Path, help="One canonical vector case directory.")
    parser.add_argument("--case-root", type=Path, default=CASE_ROOT, help="Case root to scan.")
    parser.add_argument("--vector-db", type=Path, default=VECTOR_DB, help="Vector DB to scan by default.")
    parser.add_argument("--no-vector-db", action="store_true", help="Scan --case-root instead of vector_db.csv.")
    parser.add_argument("--rotation", choices=["90", "270", "both"], default="both")
    parser.add_argument("--out-dir", type=Path, help="Optional output directory. Default writes into each case.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing generated streams.")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    rotations = [90, 270] if args.rotation == "both" else [int(args.rotation)]
    if args.case_dir:
        case_dirs = [args.case_dir]
    elif args.no_vector_db:
        case_dirs = discover_cases(args.case_root)
    else:
        case_dirs = discover_cases_from_db(args.vector_db)
    if not case_dirs:
        raise SystemExit("No case directories found")

    failed = 0
    generated = 0
    for case_dir in case_dirs:
        case_dir = case_dir.resolve()
        for rotation in rotations:
            if args.out_dir:
                out_path = args.out_dir / case_dir.name / f"expected_otf_stream_rot{rotation}.txt"
            else:
                out_path = case_dir / f"expected_otf_stream_rot{rotation}.txt"
            if out_path.exists() and not args.force:
                print(f"[KEEP] {out_path}")
                continue
            rc = generate_one(case_dir, rotation, out_path)
            if rc == 0:
                generated += 1
            elif rc != 2:
                failed += 1

    print(f"generated={generated} failed={failed}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
