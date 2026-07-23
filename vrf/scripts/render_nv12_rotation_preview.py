#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
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


def crop_nv12_planes(case: reg_flow.VectorCase) -> tuple[bytearray, bytearray]:
    y_words = reg_flow.active_linear_words(case, 0)
    uv_words = reg_flow.active_linear_words(case, 1)
    y_plane = otf_tool.words_to_linear_bytes(y_words, case.width * case.height)
    uv_plane = otf_tool.words_to_linear_bytes(uv_words, case.width * case.active_uv_height)
    return y_plane, uv_plane


def write_rgb_png(out_path: Path, width: int, height: int, rgb: bytes) -> Path:
    ppm_path = out_path.with_suffix(".ppm")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    otf_tool.write_ppm(ppm_path, width, height, rgb)
    png_path = otf_tool.ppm_to_png(ppm_path)
    return png_path or ppm_path


def render_png(out_path: Path, width: int, height: int, y_plane: bytes, uv_plane: bytes) -> Path:
    rgb = otf_tool.nv12_to_rgb(y_plane, uv_plane, width, height)
    return write_rgb_png(out_path, width, height, rgb)


def parse_views(text: str) -> list[str]:
    if text == "all":
        return ["rgb", "y", "uv", "u", "v"]
    views: list[str] = []
    for item in text.split(","):
        item = item.strip().lower()
        if item:
            views.append(item)
    bad = [view for view in views if view not in ("rgb", "y", "uv", "u", "v")]
    if bad:
        raise ValueError(f"unsupported view: {','.join(bad)}")
    return views


def view_path(base_path: Path, view: str, multi_view: bool) -> Path:
    if not multi_view:
        return base_path
    return base_path.with_name(f"{base_path.stem}_{view}{base_path.suffix}")


def render_view_set(out_path: Path, width: int, height: int,
                    y_plane: bytes, uv_plane: bytes,
                    views: list[str]) -> list[Path]:
    rendered: list[Path] = []
    multi_view = len(views) > 1
    uv_height = (height + 1) // 2

    for view in views:
        cur_path = view_path(out_path, view, multi_view)
        if view == "rgb":
            rgb = otf_tool.nv12_to_rgb(y_plane, uv_plane, width, height)
            rendered.append(write_rgb_png(cur_path, width, height, rgb))
        elif view == "y":
            rgb = otf_tool.y_plane_to_rgb(y_plane[:width * height], width, height)
            rendered.append(write_rgb_png(cur_path, width, height, rgb))
        elif view == "uv":
            rgb = otf_tool.uv_plane_to_rgb(uv_plane[:width * uv_height], width, uv_height)
            rendered.append(write_rgb_png(cur_path, width // 2, uv_height, rgb))
        elif view == "u":
            comp = otf_tool.extract_uv_component(uv_plane, width, uv_height, 0)
            rgb = otf_tool.gray_plane_to_rgb(comp, width // 2, uv_height)
            rendered.append(write_rgb_png(cur_path, width // 2, uv_height, rgb))
        elif view == "v":
            comp = otf_tool.extract_uv_component(uv_plane, width, uv_height, 1)
            rgb = otf_tool.gray_plane_to_rgb(comp, width // 2, uv_height)
            rendered.append(write_rgb_png(cur_path, width // 2, uv_height, rgb))

    return rendered


def read_words64_bytes(path: Path, total_bytes: int) -> bytearray:
    words = reg_flow.load_words64(path)
    return otf_tool.words_to_linear_bytes(words, total_bytes)


def render_linear_files(y_path: Path, uv_path: Path, out_path: Path,
                        width: int, height: int, views: list[str]) -> list[Path]:
    y_plane = read_words64_bytes(y_path, width * height)
    uv_plane = read_words64_bytes(uv_path, width * ((height + 1) // 2))
    rendered = render_view_set(out_path, width, height, y_plane, uv_plane, views)
    print(f"linear Y  : {y_path}")
    print(f"linear UV : {uv_path}")
    print(f"size      : {width}x{height}")
    for path in rendered:
        print(f"rendered  : {path}")
    return rendered


def render_case(case_dir: Path, rotations: list[int], out_dir: Path) -> list[Path]:
    case = reg_flow.load_case(case_dir)
    if case.fmt != "nv12":
        raise ValueError(f"{case_dir} is {case.fmt}; this preview script supports NV12 only")
    if case.width % 2 or case.height % 2:
        raise ValueError(f"{case_dir} has odd NV12 size {case.width}x{case.height}")

    y_plane, uv_plane = crop_nv12_planes(case)
    rendered: list[Path] = []

    for rotation in rotations:
        if rotation == 0:
            out_width = case.width
            out_height = case.height
            out_y = y_plane
            out_uv = uv_plane
        elif rotation in (90, 270):
            out_width = case.height
            out_height = case.width
            out_y = rot_flow.rotate_u8_plane(y_plane, case.width, case.height, rotation)
            out_uv = rot_flow.rotate_nv12_uv_plane(uv_plane, case.width, case.height, rotation)
        else:
            raise ValueError(f"unsupported rotation: {rotation}")

        out_path = out_dir / f"{case_dir.name}_rot{rotation}_rgb.png"
        rendered.append(render_png(out_path, out_width, out_height, out_y, out_uv))

    return rendered


def parse_rotations(text: str) -> list[int]:
    if text == "all":
        return [0, 90, 270]
    if text == "both":
        return [90, 270]
    rotations: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        rotations.append(int(item, 10))
    return rotations


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render NV12 vector images before/after 90/270 rotation.",
    )
    parser.add_argument("linear_y", nargs="?", type=Path,
                        help="Optional linear Y memh input.")
    parser.add_argument("linear_uv", nargs="?", type=Path,
                        help="Optional linear UV memh input.")
    parser.add_argument("output", nargs="?", type=Path,
                        help="Optional PNG/PPM output path.")
    parser.add_argument("--cnum", help="Case number from vrf/vector/vector_db.csv.")
    parser.add_argument("--case-dir", type=Path, help="Canonical vector case directory.")
    parser.add_argument("--vector-db", type=Path, default=VECTOR_DB)
    parser.add_argument("--rotation", default="all", help="0, 90, 270, both, all, or comma list.")
    parser.add_argument("--out-dir", type=Path, help="Output directory. Default: <case>/preview.")
    parser.add_argument("--width", type=int, help="Image width for linear-file mode.")
    parser.add_argument("--height", type=int, help="Image height for linear-file mode.")
    parser.add_argument("--view", default="rgb",
                        help="Render view: rgb, y, uv, u, v, all, or comma list.")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    if args.linear_y or args.linear_uv or args.output:
        if not (args.linear_y and args.linear_uv and args.output):
            raise SystemExit("linear-file mode requires: linear_y linear_uv output")
        if args.cnum or args.case_dir or args.out_dir:
            raise SystemExit("linear-file mode cannot combine with --cnum/--case-dir/--out-dir")
        if args.width is None or args.height is None:
            raise SystemExit("linear-file mode requires --width and --height")

        render_linear_files(args.linear_y.resolve(), args.linear_uv.resolve(),
                            args.output.resolve(), args.width, args.height,
                            parse_views(args.view))
        return 0

    if bool(args.cnum) == bool(args.case_dir):
        raise SystemExit("Use exactly one of --cnum or --case-dir")

    case_dir = resolve_case_dir(args.cnum, args.vector_db) if args.cnum else args.case_dir
    case_dir = case_dir.resolve()
    out_dir = args.out_dir.resolve() if args.out_dir else case_dir / "preview"
    rendered = render_case(case_dir, parse_rotations(args.rotation), out_dir)

    print(f"case      : {case_dir}")
    print(f"out_dir   : {out_dir}")
    for path in rendered:
        print(f"rendered  : {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
