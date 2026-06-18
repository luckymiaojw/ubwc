#!/usr/bin/env python3
"""Scan UBWC metadata bytes for fast-clear and solid-color markers.

Classification follows the DEC VIVO metadata interpretation:

    SC = |md[7:6]
    FC = !SC && !md[4]

The primary result is the tile-valid region: bytes reached by real tile
coordinates through the UBWC metadata address swizzle. Rectangular Readme
height and the full file are reported only as diagnostics because padding or
metadata-layout holes can look like fast-clear metadata.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
VECTOR_ROOT = PROJECT_ROOT / "vrf" / "vector"
CASE_ROOT = VECTOR_ROOT / "cases"
VECTOR_DB = VECTOR_ROOT / "vector_db.csv"


@dataclass(frozen=True)
class MetadataFile:
    case_name: str
    plane: str
    path: Path
    pitch: int
    stored_rows: int
    effective_rows: int
    tile_cols: int
    tile_rows: int


@dataclass(frozen=True)
class MetadataByte:
    value: int
    byte_offset: int
    line_no: int
    byte_lsb_index: int
    word_text: str
    base_addr: int | None


@dataclass
class RegionStats:
    total: int = 0
    fc: int = 0
    sc: int = 0
    normal: int = 0
    hi3_nonzero: int = 0
    first_fc: MetadataByte | None = None
    first_sc: MetadataByte | None = None
    first_hi3: MetadataByte | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cnum",
        default="",
        help="Comma separated case numbers, for example 0061,0062. "
             "When omitted, --path must be used.",
    )
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        help="Vector/case directory to scan. Can be used multiple times.",
    )
    parser.add_argument(
        "--show-first",
        type=int,
        default=1,
        help="Reserved for future detailed dumps; summary always prints first hit.",
    )
    return parser.parse_args()


def die(msg: str) -> None:
    raise SystemExit(f"ERROR: {msg}")


def load_case_db() -> dict[str, Path]:
    if not VECTOR_DB.exists():
        return {}
    out: dict[str, Path] = {}
    with VECTOR_DB.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            out[row["cnum"]] = PROJECT_ROOT / row["case_dir"]
    return out


def parse_first_int(text: str) -> int:
    match = re.search(r"\d+", text)
    return int(match.group(0)) if match else 0


def parse_meta_height(text: str) -> tuple[int, int]:
    stored = parse_first_int(text)
    need_match = re.search(r"\bneed\s+(\d+)", text, flags=re.IGNORECASE)
    effective = int(need_match.group(1)) if need_match else stored
    return stored, effective


def read_readme(case_dir: Path) -> dict[str, str]:
    readme = case_dir / "Readme.txt"
    if not readme.exists():
        readme = case_dir / "ReadMe.txt"
    if not readme.exists():
        return {}
    fields: dict[str, str] = {}
    for line in readme.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    return fields


def field_file(case_dir: Path, fields: dict[str, str], key: str) -> Path | None:
    value = fields.get(key, "").split()[0] if fields.get(key, "").strip() else ""
    if not value:
        return None
    path = case_dir / value
    return path if path.exists() else None


def ceil_div(value: int, divisor: int) -> int:
    return (value + divisor - 1) // divisor


def parse_format(fields: dict[str, str]) -> str:
    raw = fields.get("Image format", "").strip().split()[0].lower()
    if raw in ("ubwc_nv_12", "nv12"):
        return "nv12"
    if raw in ("p010", "g016"):
        return "p010"
    if "1010102" in raw:
        return "rgba1010102"
    if "rgba8888" in raw or "r8g8b8a8" in raw:
        return "rgba8888"
    return raw


def parse_size(fields: dict[str, str]) -> tuple[int, int]:
    text = fields.get("Actual Image size(Pixels)", "")
    match = re.search(r"(\d+)\s*x\s*(\d+)", text, flags=re.IGNORECASE)
    if not match:
        return 0, 0
    return int(match.group(1)), int(match.group(2))


def tile_shape(fmt: str) -> tuple[int, int]:
    if fmt == "nv12":
        return 32, 8
    if fmt == "p010":
        return 32, 4
    return 16, 4


def metadata_tile_counts(fields: dict[str, str], plane: str) -> tuple[int, int]:
    fmt = parse_format(fields)
    width, height = parse_size(fields)
    tile_w, tile_h = tile_shape(fmt)
    tile_cols = ceil_div(width, tile_w) if width else 0
    if plane == "UV":
        active_height = ceil_div(height, 2) if height else 0
    else:
        active_height = height
    tile_rows = ceil_div(active_height, tile_h) if active_height else 0
    return tile_cols, tile_rows


def metadata_files_from_readme(case_dir: Path) -> list[MetadataFile]:
    fields = read_readme(case_dir)
    if not fields:
        return []

    y_path = field_file(case_dir, fields, "Metadata RGB/Y-plane")
    uv_path = field_file(case_dir, fields, "Metadata UV-plane")
    out: list[MetadataFile] = []

    if y_path is not None:
        stored_rows, effective_rows = parse_meta_height(fields.get("Height for Meta Data P0", "0"))
        tile_cols, tile_rows = metadata_tile_counts(fields, "Y/RGBA")
        out.append(MetadataFile(
            case_name=case_dir.name,
            plane="Y/RGBA",
            path=y_path,
            pitch=parse_first_int(fields.get("Pitch for Meta Data P0", "0")),
            stored_rows=stored_rows,
            effective_rows=effective_rows,
            tile_cols=tile_cols,
            tile_rows=tile_rows,
        ))

    if uv_path is not None:
        stored_rows, effective_rows = parse_meta_height(fields.get("Height for Meta Data P1", "0"))
        tile_cols, tile_rows = metadata_tile_counts(fields, "UV")
        out.append(MetadataFile(
            case_name=case_dir.name,
            plane="UV",
            path=uv_path,
            pitch=parse_first_int(fields.get("Pitch for Meta Data P1", "0")),
            stored_rows=stored_rows,
            effective_rows=effective_rows,
            tile_cols=tile_cols,
            tile_rows=tile_rows,
        ))

    return out


def metadata_files_fallback(case_dir: Path) -> list[MetadataFile]:
    names = [
        ("Y/RGBA", "metadata.txt"),
        ("Y/RGBA", "y_metadata.txt"),
        ("UV", "uv_metadata.txt"),
    ]
    out: list[MetadataFile] = []
    for plane, name in names:
        path = case_dir / name
        if path.exists():
            out.append(MetadataFile(case_dir.name, plane, path, 0, 0, 0, 0, 0))
    return out


def find_metadata_files(case_dir: Path) -> list[MetadataFile]:
    files = metadata_files_from_readme(case_dir)
    if files:
        return files
    return metadata_files_fallback(case_dir)


def iter_metadata_bytes(path: Path) -> list[MetadataByte]:
    out: list[MetadataByte] = []
    base_addr: int | None = None
    byte_offset = 0

    for line_no, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        text = line.strip()
        if not text or text.startswith("#") or text.startswith("//"):
            continue
        if text.startswith("@"):
            addr_text = re.sub(r"[^0-9a-fA-F]", "", text[1:])
            base_addr = int(addr_text, 16) if addr_text else None
            continue

        word_text = text.split()[0].replace("_", "")
        if not re.fullmatch(r"[0-9a-fA-F]+", word_text):
            continue
        if len(word_text) & 1:
            word_text = "0" + word_text

        byte_count = len(word_text) // 2
        for byte_lsb_index in range(byte_count):
            start = len(word_text) - (byte_lsb_index + 1) * 2
            value = int(word_text[start:start + 2], 16)
            out.append(MetadataByte(
                value=value,
                byte_offset=byte_offset,
                line_no=line_no,
                byte_lsb_index=byte_lsb_index,
                word_text=word_text,
                base_addr=base_addr,
            ))
            byte_offset += 1

    return out


def update_stats(stats: RegionStats, item: MetadataByte) -> None:
    md = item.value
    is_sc = (md & 0xC0) != 0
    is_fc = (not is_sc) and ((md & 0x10) == 0)
    hi3 = (md & 0xE0) != 0

    stats.total += 1
    if is_fc:
        stats.fc += 1
        if stats.first_fc is None:
            stats.first_fc = item
    elif is_sc:
        stats.sc += 1
        if stats.first_sc is None:
            stats.first_sc = item
    else:
        stats.normal += 1

    if hi3:
        stats.hi3_nonzero += 1
        if stats.first_hi3 is None:
            stats.first_hi3 = item


def summarize(items: list[MetadataByte], limit: int) -> tuple[RegionStats, RegionStats]:
    effective = RegionStats()
    full = RegionStats()
    for item in items:
        update_stats(full, item)
        if limit <= 0 or item.byte_offset < limit:
            update_stats(effective, item)
    return effective, full


def meta_byte_offset(tile_x: int, tile_y: int, pitch: int) -> int:
    return ((tile_y >> 4) * pitch * 16) + \
        ((tile_x >> 4) << 8) + \
        (((tile_y >> 3) & 1) << 7) + \
        (((tile_x >> 3) & 1) << 6) + \
        ((tile_y & 7) << 3) + \
        (tile_x & 7)


def tile_valid_offsets(meta: MetadataFile) -> set[int]:
    if meta.pitch <= 0 or meta.tile_cols <= 0 or meta.tile_rows <= 0:
        return set()
    return {
        meta_byte_offset(tile_x, tile_y, meta.pitch)
        for tile_y in range(meta.tile_rows)
        for tile_x in range(meta.tile_cols)
    }


def summarize_tile_valid(items: list[MetadataByte], offsets: set[int]) -> RegionStats:
    stats = RegionStats()
    by_offset = {item.byte_offset: item for item in items}
    for offset in sorted(offsets):
        item = by_offset.get(offset)
        if item is None:
            item = MetadataByte(
                value=0,
                byte_offset=offset,
                line_no=-1,
                byte_lsb_index=-1,
                word_text="",
                base_addr=None,
            )
        update_stats(stats, item)
    return stats


def loc_text(item: MetadataByte | None, pitch: int) -> str:
    if item is None:
        return "-"
    row_col = ""
    if pitch > 0:
        row_col = f" row={item.byte_offset // pitch} col={item.byte_offset % pitch}"
    addr_text = ""
    if item.base_addr is not None:
        addr_text = f" addr=0x{item.base_addr + item.byte_offset:x}"
    return (f"md=0x{item.value:02x} off={item.byte_offset}{row_col}"
            f" line={item.line_no} byte_lsb={item.byte_lsb_index}{addr_text}")


def print_summary(meta: MetadataFile,
                  tile_valid: RegionStats,
                  effective: RegionStats,
                  full: RegionStats) -> None:
    limit = meta.pitch * meta.effective_rows if meta.pitch and meta.effective_rows else 0
    print(f"\n[{meta.case_name}] {meta.plane} {meta.path.name}")
    if meta.pitch:
        print(f"  layout       : pitch={meta.pitch} stored_rows={meta.stored_rows} "
              f"effective_rows={meta.effective_rows} effective_bytes={limit}")
    else:
        print("  layout       : no Readme layout found; effective == full")
    if meta.tile_cols and meta.tile_rows:
        print(f"  tile_valid   : tile_cols={meta.tile_cols} tile_rows={meta.tile_rows} "
              f"bytes={tile_valid.total} FC={tile_valid.fc} SC={tile_valid.sc} "
              f"normal={tile_valid.normal} hi3_nonzero={tile_valid.hi3_nonzero}")
    else:
        print("  tile_valid   : no tile layout found")
    print(f"  rect_effect  : bytes={effective.total} FC={effective.fc} "
          f"SC={effective.sc} normal={effective.normal} hi3_nonzero={effective.hi3_nonzero}")
    print(f"  full_file    : bytes={full.total} FC={full.fc} "
          f"SC={full.sc} normal={full.normal} hi3_nonzero={full.hi3_nonzero}")
    print(f"  first FC     : {loc_text(tile_valid.first_fc, meta.pitch)}")
    print(f"  first SC     : {loc_text(tile_valid.first_sc, meta.pitch)}")
    print(f"  first hi3    : {loc_text(tile_valid.first_hi3, meta.pitch)}")


def main() -> None:
    args = parse_args()
    case_dirs: list[Path] = []

    db = load_case_db()
    if args.cnum:
        for cnum in [x.strip() for x in args.cnum.split(",") if x.strip()]:
            if cnum not in db:
                die(f"CNUM {cnum} not found in {VECTOR_DB}")
            case_dirs.append(db[cnum])

    for path_text in args.path:
        path = Path(path_text)
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        case_dirs.append(path.resolve())

    if not case_dirs:
        die("Use --cnum or --path")

    any_fc = False
    for case_dir in case_dirs:
        if not case_dir.exists():
            die(f"Case path does not exist: {case_dir}")
        meta_files = find_metadata_files(case_dir)
        if not meta_files:
            print(f"\n[{case_dir.name}] no metadata files found")
            continue
        for meta in meta_files:
            items = iter_metadata_bytes(meta.path)
            limit = meta.pitch * meta.effective_rows if meta.pitch and meta.effective_rows else 0
            effective, full = summarize(items, limit)
            tile_valid = summarize_tile_valid(items, tile_valid_offsets(meta))
            any_fc = any_fc or (tile_valid.fc > 0)
            print_summary(meta, tile_valid, effective, full)

    print("\nRESULT:", "FAST_CLEAR_FOUND" if any_fc else "NO_FAST_CLEAR_IN_TILE_VALID_REGION")


if __name__ == "__main__":
    main()
