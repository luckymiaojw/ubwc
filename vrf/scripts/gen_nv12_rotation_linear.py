#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = PROJECT_ROOT / "vrf" / "scripts"
VECTOR_DB = PROJECT_ROOT / "vrf" / "vector" / "vector_db.csv"

sys.path.insert(0, str(SCRIPT_DIR))
import gen_dec_rotation_expected as rot_flow  # noqa: E402
import otf_case_tool as otf_tool  # noqa: E402
import ubwc_vector_regression as reg_flow  # noqa: E402


def resolve_case_dir(cnum: str, vector_db: Path) -> Path:
    if not vector_db.exists():
        raise FileNotFoundError(f"missing vector DB: {vector_db}")

    with vector_db.open(newline="") as fh:
        for row in csv.DictReader(fh):
            if (row.get("cnum") or "").strip() != cnum:
                continue

            case_dir_text = (row.get("case_dir") or "").strip()
            if not case_dir_text:
                raise ValueError(f"CNUM={cnum} has empty case_dir")

            case_dir = Path(case_dir_text)
            if not case_dir.is_absolute():
                case_dir = PROJECT_ROOT / case_dir
            return case_dir

    raise KeyError(f"CNUM={cnum} not found in {vector_db}")


def bytes_to_words64(data: bytes) -> list[int]:
    words: list[int] = []
    for base in range(0, len(data), 8):
        word = 0
        for byte_idx in range(8):
            src_idx = base + byte_idx
            if src_idx < len(data):
                word |= data[src_idx] << (byte_idx * 8)
        words.append(word)
    return words


def write_words64(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as fh:
        for word in bytes_to_words64(data):
            fh.write(f"{word:016x}\n")


def read_words64_bytes(path: Path, total_bytes: int) -> bytearray:
    words = reg_flow.load_words64(path)
    return otf_tool.words_to_linear_bytes(words, total_bytes)


def active_nv12_planes(case: reg_flow.VectorCase) -> tuple[bytearray, bytearray]:
    y_words = reg_flow.active_linear_words(case, 0)
    uv_words = reg_flow.active_linear_words(case, 1)
    y_plane = otf_tool.words_to_linear_bytes(y_words, case.width * case.height)
    uv_plane = otf_tool.words_to_linear_bytes(uv_words, case.width * case.active_uv_height)
    return y_plane, uv_plane


def infer_rotation(path: Path) -> int:
    match = re.search(r"(?:^|_)(90|270)(?:_|\.|$)", path.name)
    if not match:
        raise ValueError(f"cannot infer rotation from output name: {path}")
    return int(match.group(1), 10)


def infer_plane(src_path: Path, dst_path: Path) -> str:
    text = f"{src_path.name} {dst_path.name}".lower()
    if re.search(r"(?:^|_)uv(?:_|\.|$)", text):
        return "uv"
    if re.search(r"(?:^|_)y(?:_|\.|$)", text):
        return "y"
    raise ValueError("cannot infer plane; use --plane y or --plane uv")


def find_case_dir_for_path(path: Path) -> Path | None:
    cur = path.resolve().parent
    candidates = [cur, *cur.parents]
    for candidate in candidates:
        if (candidate / "Readme.txt").exists() or (candidate / "ReadMe.txt").exists():
            return candidate
    return None


def rotate_file(src_path: Path, dst_path: Path, width: int, height: int,
                plane: str, rotation: int) -> None:
    if plane == "y":
        src = read_words64_bytes(src_path, width * height)
        dst = rot_flow.rotate_u8_plane(src, width, height, rotation)
    elif plane == "uv":
        src = read_words64_bytes(src_path, width * ((height + 1) // 2))
        dst = rot_flow.rotate_nv12_uv_plane(src, width, height, rotation)
    else:
        raise ValueError("plane must be y or uv")

    write_words64(dst_path, dst)
    print(f"src       : {src_path}")
    print(f"dst       : {dst_path}")
    print(f"plane     : {plane}")
    print(f"rotation  : {rotation}")
    print(f"input     : {width}x{height}")
    print(f"output    : {height}x{width}")
    print(f"bytes     : {len(dst)}")
    print(f"words64   : {len(bytes_to_words64(dst))}")


def generate_case(case_dir: Path, rotations: list[int], out_dir: Path) -> list[Path]:
    case = reg_flow.load_case(case_dir)
    if case.fmt != "nv12":
        raise ValueError(f"{case_dir} is {case.fmt}; this script supports NV12 only")
    if case.width % 2 or case.height % 2:
        raise ValueError(f"{case_dir} has odd NV12 size {case.width}x{case.height}")

    y_plane, uv_plane = active_nv12_planes(case)
    old_y_path = out_dir / "old_linear_y.txt"
    old_uv_path = out_dir / "old_linear_uv.txt"
    write_words64(old_y_path, y_plane)
    write_words64(old_uv_path, uv_plane)

    rendered: list[Path] = [old_y_path, old_uv_path]

    print(f"case      : {case_dir}")
    print(f"input     : {case.width}x{case.height}")
    print(f"old Y     : {old_y_path}  bytes={len(y_plane)} words64={len(bytes_to_words64(y_plane))}")
    print(f"old UV    : {old_uv_path}  bytes={len(uv_plane)} words64={len(bytes_to_words64(uv_plane))}")

    for rotation in rotations:
        if rotation not in (90, 270):
            raise ValueError("rotation must be 90 or 270")

        rot_y = rot_flow.rotate_u8_plane(y_plane, case.width, case.height, rotation)
        rot_uv = rot_flow.rotate_nv12_uv_plane(uv_plane, case.width, case.height, rotation)
        y_path = out_dir / f"y_rotate_{rotation}.txt"
        uv_path = out_dir / f"uv_rotate_{rotation}.txt"
        write_words64(y_path, rot_y)
        write_words64(uv_path, rot_uv)
        rendered.extend([y_path, uv_path])

        out_width = case.height
        out_height = case.width
        print(f"rotation  : {rotation}")
        print(f"output    : {out_width}x{out_height}")
        print(f"rotate Y  : {y_path}  bytes={len(rot_y)} words64={len(bytes_to_words64(rot_y))}")
        print(f"rotate UV : {uv_path}  bytes={len(rot_uv)} words64={len(bytes_to_words64(rot_uv))}")

    return rendered


def parse_rotations(text: str) -> list[int]:
    if text == "both":
        return [90, 270]
    rotations: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if item:
            rotations.append(int(item, 10))
    return rotations


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate rotated expected linear Y/UV memh files for NV12 cases.",
    )
    parser.add_argument("src", nargs="?", type=Path,
                        help="Optional single-file input, e.g. old_linear_y.txt.")
    parser.add_argument("dst", nargs="?", type=Path,
                        help="Optional single-file output, e.g. y_rotate_90.txt.")
    parser.add_argument("--cnum", help="Case number from vrf/vector/vector_db.csv.")
    parser.add_argument("--case-dir", type=Path, help="Canonical vector case directory.")
    parser.add_argument("--vector-db", type=Path, default=VECTOR_DB)
    parser.add_argument("--rotation", default="both", help="90, 270, both, or comma list.")
    parser.add_argument("--out-dir", type=Path, help="Output directory. Default: <case>/expected_rotation.")
    parser.add_argument("--width", type=int, help="Input image width for single-file mode.")
    parser.add_argument("--height", type=int, help="Input image height for single-file mode.")
    parser.add_argument("--plane", choices=["y", "uv"], help="Input plane for single-file mode.")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    if args.src or args.dst:
        if not (args.src and args.dst):
            raise SystemExit("single-file mode requires both src and dst")
        if args.cnum or args.case_dir or args.out_dir:
            raise SystemExit("single-file mode cannot combine with --cnum/--case-dir/--out-dir")

        src_path = args.src.resolve()
        dst_path = args.dst.resolve()
        case_dir = find_case_dir_for_path(src_path)
        if case_dir:
            case = reg_flow.load_case(case_dir)
            if case.fmt != "nv12":
                raise SystemExit(f"single-file mode only supports NV12, got {case.fmt}")
            width = case.width
            height = case.height
        else:
            if args.width is None or args.height is None:
                raise SystemExit("cannot find case Readme.txt; use --width and --height")
            width = args.width
            height = args.height

        rotation = int(args.rotation, 10) if args.rotation != "both" else infer_rotation(dst_path)
        plane = args.plane or infer_plane(src_path, dst_path)
        rotate_file(src_path, dst_path, width, height, plane, rotation)
        return 0

    if bool(args.cnum) == bool(args.case_dir):
        raise SystemExit("Use exactly one of --cnum or --case-dir")

    case_dir = resolve_case_dir(args.cnum, args.vector_db) if args.cnum else args.case_dir
    case_dir = case_dir.resolve()
    out_dir = args.out_dir.resolve() if args.out_dir else case_dir / "expected_rotation"

    generate_case(case_dir, parse_rotations(args.rotation), out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
