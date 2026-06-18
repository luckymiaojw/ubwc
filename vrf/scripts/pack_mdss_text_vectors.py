#!/usr/bin/env python3
"""Pack legacy MDSS text vectors into .raw and .raw.ubwc binaries.

The legacy vector directories store each plane as text files:

    @0000000080000000
    1414141414141210
    ...

Each data line is a 64-bit Verilog-style memory word.  The byte at the
lowest address is the rightmost byte in the hex word, so this script reverses
each 64-bit word when packing binary bytes.

Output follows the R7130 raw-vector package style:

    pattern_w4096_h600_yuv420_nv12.raw
    pattern_w4096_h600_yuv420_nv12.raw.ubwc

The .raw file contains active linear payload only:

    Y/RGBA active plane [ + UV active plane ]

The .raw.ubwc file contains aligned UBWC storage payload:

    Metadata Y/RGBA
    Tiled Compressed Y/RGBA
    Metadata UV
    Tiled Compressed UV
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
VECTOR_ROOT = PROJECT_ROOT / "vrf" / "vector"

DEFAULT_VECTOR_DIRS = [
    VECTOR_ROOT / "enc_from_mdss_01000007_k_outdoor61_4096x600_g016",
    VECTOR_ROOT / "enc_from_mdss_zp_TajMahal_4096x600_nv12",
    VECTOR_ROOT / "enc_from_mdss_zp_TajMahal_4096x600_rgba8888",
    VECTOR_ROOT / "enc_from_mdss_zp_TajMahal_4096x600_rgba1010102",
]

FORMAT_NAME = {
    "G016": "yuv420_p010",
    "P010": "yuv420_p010",
    "NV12": "yuv420_nv12",
    "RGBA8888": "rgba8888",
    "RGBA1010102": "rgba1010102",
}


@dataclass(frozen=True)
class MdssLayout:
    fmt_raw: str
    fmt_out: str
    width: int
    height: int
    has_uv: bool
    bytes_per_pixel: int
    pitch_y: int
    pitch_uv: int
    stored_y: int
    stored_uv: int
    meta_pitch_y: int
    meta_pitch_uv: int
    meta_height_y: int
    meta_height_uv: int

    @property
    def raw_name(self) -> str:
        return f"pattern_w{self.width}_h{self.height}_{self.fmt_out}.raw"

    @property
    def ubwc_name(self) -> str:
        return f"{self.raw_name}.ubwc"

    @property
    def active_uv_height(self) -> int:
        return (self.height + 1) // 2 if self.has_uv else 0

    @property
    def active_row_bytes_y(self) -> int:
        return self.width * self.bytes_per_pixel

    @property
    def active_row_bytes_uv(self) -> int:
        return self.width * self.bytes_per_pixel if self.has_uv else 0


def normalize_key(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip())


def parse_int_from_line(value: str) -> int:
    match = re.search(r"([0-9]+)", value)
    if not match:
        raise ValueError(f"Cannot parse integer from: {value!r}")
    return int(match.group(1))


def parse_readme(vector_dir: Path) -> tuple[dict[str, str], MdssLayout]:
    readme = vector_dir / "Readme.txt"
    fields: dict[str, str] = {}
    for raw_line in readme.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in raw_line:
            continue
        key, value = raw_line.split(":", 1)
        fields[normalize_key(key)] = value.strip()

    fmt_raw = fields["Image format"].strip().split()[0].upper()
    if fmt_raw not in FORMAT_NAME:
        raise ValueError(f"{readme}: unsupported Image format {fmt_raw!r}")

    size_match = re.search(r"([0-9]+)\s*x\s*([0-9]+)", fields["Actual Image size(Pixels)"])
    if not size_match:
        raise ValueError(f"{readme}: cannot parse actual image size")
    width = int(size_match.group(1))
    height = int(size_match.group(2))
    has_uv = fmt_raw in {"G016", "P010", "NV12"}
    bytes_per_pixel = 1 if fmt_raw == "NV12" else 4
    if fmt_raw in {"G016", "P010"}:
        bytes_per_pixel = 2

    pitch_uv = 0
    stored_uv = 0
    meta_pitch_uv = 0
    meta_height_uv = 0
    if has_uv:
        pitch_uv = parse_int_from_line(fields["Pitch for Pixel Data P1"])
        stored_uv = parse_int_from_line(fields["Aligned Height for Pixel Data P1"])
        meta_pitch_uv = parse_int_from_line(fields["Pitch for Meta Data P1"])
        meta_height_uv = parse_int_from_line(fields["Height for Meta Data P1"])

    layout = MdssLayout(
        fmt_raw=fmt_raw,
        fmt_out=FORMAT_NAME[fmt_raw],
        width=width,
        height=height,
        has_uv=has_uv,
        bytes_per_pixel=bytes_per_pixel,
        pitch_y=parse_int_from_line(fields["Pitch for Pixel Data P0"]),
        pitch_uv=pitch_uv,
        stored_y=parse_int_from_line(fields["Aligned Height for Pixel Data P0"]),
        stored_uv=stored_uv,
        meta_pitch_y=parse_int_from_line(fields["Pitch for Meta Data P0"]),
        meta_pitch_uv=meta_pitch_uv,
        meta_height_y=parse_int_from_line(fields["Height for Meta Data P0"]),
        meta_height_uv=meta_height_uv,
    )
    return fields, layout


def require_file(vector_dir: Path, file_name: str, label: str) -> Path:
    if not file_name:
        raise ValueError(f"{vector_dir}: missing file for {label}")
    path = vector_dir / file_name
    if not path.is_file():
        raise FileNotFoundError(f"{vector_dir}: {label} file not found: {path}")
    return path


def read_hex64_text(path: Path) -> bytes:
    data = bytearray()
    for line_no, raw_line in enumerate(path.read_text(encoding="ascii", errors="ignore").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("@"):
            continue
        if not re.fullmatch(r"[0-9a-fA-F_]+", line):
            raise ValueError(f"{path}:{line_no}: invalid hex64 word {line!r}")
        word_hex = line.replace("_", "")
        if len(word_hex) > 16:
            raise ValueError(f"{path}:{line_no}: hex word wider than 64 bits: {line!r}")
        word_bytes = bytes.fromhex(word_hex.zfill(16))
        data.extend(word_bytes[::-1])
    return bytes(data)


def crop_active_rows(data: bytes, pitch: int, active_row_bytes: int, active_height: int, label: str) -> bytes:
    required = pitch * active_height
    if len(data) < required:
        raise ValueError(f"{label}: data size {len(data)} is smaller than required active span {required}")
    rows = []
    for row in range(active_height):
        start = row * pitch
        rows.append(data[start:start + active_row_bytes])
    return b"".join(rows)


def pack_one(vector_dir: Path, force: bool) -> tuple[Path, Path]:
    fields, layout = parse_readme(vector_dir)

    linear_y_path = require_file(
        vector_dir,
        fields.get("Linear Image Y-plane") or fields.get("Linear Image") or "",
        "linear Y/RGBA",
    )
    linear_y = crop_active_rows(
        read_hex64_text(linear_y_path),
        layout.pitch_y,
        layout.active_row_bytes_y,
        layout.height,
        str(linear_y_path),
    )
    raw_parts = [linear_y]

    if layout.has_uv:
        linear_uv_path = require_file(vector_dir, fields.get("Linear Image UV-plane", ""), "linear UV")
        linear_uv = crop_active_rows(
            read_hex64_text(linear_uv_path),
            layout.pitch_uv,
            layout.active_row_bytes_uv,
            layout.active_uv_height,
            str(linear_uv_path),
        )
        raw_parts.append(linear_uv)

    meta_y = read_hex64_text(require_file(vector_dir, fields["Metadata RGB/Y-plane"], "metadata Y/RGBA"))
    tile_y = read_hex64_text(require_file(vector_dir, fields["Tiled Compressed Image RGB/Y-plane"], "compressed tile Y/RGBA"))
    ubwc_parts = [meta_y, tile_y]

    if layout.has_uv:
        meta_uv = read_hex64_text(require_file(vector_dir, fields.get("Metadata UV-plane", ""), "metadata UV"))
        tile_uv = read_hex64_text(require_file(vector_dir, fields.get("Tiled Compressed Image UV-plane", ""), "compressed tile UV"))
        ubwc_parts.extend([meta_uv, tile_uv])

    raw_path = vector_dir / layout.raw_name
    ubwc_path = vector_dir / layout.ubwc_name
    if not force:
        for path in (raw_path, ubwc_path):
            if path.exists():
                raise FileExistsError(f"{path} exists; use --force to overwrite")

    raw_path.write_bytes(b"".join(raw_parts))
    ubwc_path.write_bytes(b"".join(ubwc_parts))
    return raw_path, ubwc_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Pack MDSS text vectors into R7130-style .raw/.raw.ubwc binaries.")
    parser.add_argument("vector_dirs", nargs="*", type=Path, help="MDSS vector directories. Defaults to the four 4096x600 baseline dirs.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing .raw/.raw.ubwc outputs.")
    args = parser.parse_args()

    vector_dirs = args.vector_dirs or DEFAULT_VECTOR_DIRS
    for vector_dir in vector_dirs:
        if not vector_dir.is_dir():
            raise FileNotFoundError(f"Vector directory not found: {vector_dir}")
        raw_path, ubwc_path = pack_one(vector_dir, args.force)
        print(f"[OK] {vector_dir}")
        print(f"     raw      {raw_path.name} {raw_path.stat().st_size} bytes")
        print(f"     raw.ubwc {ubwc_path.name} {ubwc_path.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
