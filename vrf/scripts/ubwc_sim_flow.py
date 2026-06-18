#!/usr/bin/env python3
"""Clean UBWC vector/simulation flow.

User-visible make commands are intentionally small:

    make bvector
    make comp_enc
    make comp_dec
    make comp_loop
    make run MODE=enc  CNUM=0001
    make run MODE=dec  CNUM=0001
    make run MODE=loop CNUM=0001

The implementation reuses the existing vector conversion and wrapper
regression helpers, but keeps old target names out of the top-level flow.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = PROJECT_ROOT / "vrf" / "scripts"
SIM_DIR = PROJECT_ROOT / "vrf" / "sim"
VECTOR_ROOT = PROJECT_ROOT / "vrf" / "vector"
CASE_ROOT = VECTOR_ROOT / "cases"
VECTOR_DB = VECTOR_ROOT / "vector_db.csv"
ENV_SCRIPT = PROJECT_ROOT / "prj_setup.env"

ENC_TOP = "tb_ubwc_enc_wrapper_top_tajmahal_cases"
DEC_TOP = "tb_ubwc_dec_wrapper_top_tajmahal_cases"
LOOP_TOP = "tb_ubwc_dec_to_enc_loop_tajmahal_cases"

MAX_FRAME_NUM = 100

sys.path.insert(0, str(SCRIPT_DIR))
import convert_ubwc_raw_vectors as raw_conv  # noqa: E402
import ubwc_vector_regression as reg_flow  # noqa: E402


@dataclass(frozen=True)
class DbCase:
    cnum: str
    label: str
    fmt: str
    width: int
    height: int
    stored_y: int
    stored_uv: int
    source: str
    case_dir: Path
    modes: tuple[str, ...] = ("enc", "dec", "loop")

    @property
    def name(self) -> str:
        return f"{self.width}x{self.height}_{self.fmt}"


def die(msg: str) -> None:
    raise SystemExit(f"ERROR: {msg}")


def run_cmd(cmd: list[str], log_file: Path | None = None) -> int:
    print("+", " ".join(shlex.quote(x) for x in cmd), flush=True)
    if log_file is None:
        return subprocess.run(cmd).returncode
    log_file.parent.mkdir(parents=True, exist_ok=True)
    with log_file.open("a", encoding="utf-8", errors="ignore") as fh:
        return subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT).returncode


def run_sim_make(target: str,
                 top: str,
                 build_root: Path,
                 flags: str,
                 run_args: str,
                 log: Path | None = None) -> int:
    cmd = (
        f"source {shlex.quote(str(ENV_SCRIPT))}; "
        f"make -C {shlex.quote(str(SIM_DIR))} "
        f"TOP={shlex.quote(top)} "
        f"BUILD_ROOT={shlex.quote(str(build_root))} "
        f'TB_PARAM_FLAGS="{flags}" '
        f'RUN_ARGS="{run_args}" '
        f"{target}"
    )
    return run_cmd(["tcsh", "-c", cmd], log)


def parse_int(value: str) -> int:
    text = value.strip()
    return int(text, 0)


def normalize_bool(value: str | int | bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    return value.strip().lower() in ("1", "true", "yes", "y", "on")


def case_label(cnum: str, case: reg_flow.VectorCase) -> str:
    return f"{cnum}_{case.fmt}_{case.width}x{case.height}"


def clean_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def link_case_dir(src_dir: Path, dst_dir: Path, force: bool) -> None:
    if dst_dir.exists() or dst_dir.is_symlink():
        if not force:
            return
        clean_path(dst_dir)
    dst_dir.parent.mkdir(parents=True, exist_ok=True)
    rel_src = os.path.relpath(src_dir.resolve(), dst_dir.parent.resolve())
    dst_dir.symlink_to(rel_src, target_is_directory=True)


def load_db() -> list[DbCase]:
    if not VECTOR_DB.exists():
        return []
    rows: list[DbCase] = []
    with VECTOR_DB.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            rows.append(DbCase(
                cnum=row["cnum"],
                label=row["label"],
                fmt=row["format"],
                width=int(row["width"]),
                height=int(row["height"]),
                stored_y=int(row["stored_y"]),
                stored_uv=int(row["stored_uv"]),
                source=row["source"],
                case_dir=(PROJECT_ROOT / row["case_dir"]).absolute(),
                modes=tuple(item.strip() for item in row.get("modes", "enc,dec,loop").split(",")
                            if item.strip()),
            ))
    return rows


def write_db(rows: list[DbCase]) -> None:
    VECTOR_DB.parent.mkdir(parents=True, exist_ok=True)
    with VECTOR_DB.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=[
            "cnum", "label", "format", "width", "height",
            "stored_y", "stored_uv", "source", "case_dir", "modes",
        ])
        writer.writeheader()
        for row in sorted(rows, key=lambda item: item.cnum):
            writer.writerow({
                "cnum": row.cnum,
                "label": row.label,
                "format": row.fmt,
                "width": row.width,
                "height": row.height,
                "stored_y": row.stored_y,
                "stored_uv": row.stored_uv,
                "source": row.source,
                "case_dir": row.case_dir.relative_to(PROJECT_ROOT),
                "modes": ",".join(row.modes),
            })


def next_cnum(rows: list[DbCase]) -> int:
    if not rows:
        return 1
    return max(int(row.cnum) for row in rows) + 1


def db_from_case(cnum: str,
                 src_dir: Path,
                 case: reg_flow.VectorCase,
                 source: str,
                 force_link: bool) -> DbCase:
    label = case_label(cnum, case)
    dst_dir = CASE_ROOT / label
    if src_dir.resolve() != dst_dir.resolve():
        link_case_dir(src_dir, dst_dir, force_link)
        case_dir = dst_dir
    else:
        case_dir = src_dir
    return DbCase(
        cnum=cnum,
        label=label,
        fmt=case.fmt,
        width=case.width,
        height=case.height,
        stored_y=case.stored_y,
        stored_uv=case.stored_uv,
        source=source,
        case_dir=case_dir,
    )


def case_supports_mode(row: DbCase, mode: str) -> bool:
    return mode in row.modes


def manual_cnum(path: Path) -> str | None:
    match = re.match(r"^(?:case[_-]?)?([0-9]{4})(?:[_-]|$)", path.name)
    return match.group(1) if match else None


def load_case_if_valid(path: Path) -> reg_flow.VectorCase | None:
    if not path.is_dir() or not (path / "Readme.txt").is_file():
        return None
    try:
        return reg_flow.load_case(path)
    except Exception as exc:
        print(f"[SKIP] {path}: {exc}", file=sys.stderr)
        return None


def discover_case_dirs() -> list[tuple[Path, reg_flow.VectorCase]]:
    found: list[tuple[Path, reg_flow.VectorCase]] = []
    seen: set[Path] = set()
    roots = [VECTOR_ROOT, CASE_ROOT]

    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(item for item in root.iterdir() if item.is_dir()):
            if path.name.startswith("."):
                continue
            if path in (CASE_ROOT,):
                continue
            case = load_case_if_valid(path)
            if case is None:
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            found.append((path, case))
    return found


def discover_existing_cases(force_link: bool, preserve_existing: bool) -> list[DbCase]:
    old_rows = load_db() if preserve_existing else []
    old_by_path = {row.case_dir.resolve(): row for row in old_rows}
    old_by_cnum = {row.cnum: row for row in old_rows}
    used_cnums: set[str] = set()
    rows: list[DbCase] = []
    pending: list[tuple[Path, reg_flow.VectorCase]] = []

    for path, case in discover_case_dirs():
        old = old_by_path.get(path.resolve())
        if old is not None:
            rows.append(DbCase(
                cnum=old.cnum,
                label=old.label,
                fmt=case.fmt,
                width=case.width,
                height=case.height,
                stored_y=case.stored_y,
                stored_uv=case.stored_uv,
                source=old.source,
                case_dir=old.case_dir,
                modes=old.modes,
            ))
            used_cnums.add(old.cnum)
        else:
            pending.append((path, case))

    for path, case in pending:
        cnum = manual_cnum(path)
        if cnum is None:
            continue
        old = old_by_cnum.get(cnum)
        if old is not None:
            rows.append(DbCase(
                cnum=old.cnum,
                label=old.label,
                fmt=case.fmt,
                width=case.width,
                height=case.height,
                stored_y=case.stored_y,
                stored_uv=case.stored_uv,
                source=old.source,
                case_dir=old.case_dir,
                modes=old.modes,
            ))
            used_cnums.add(cnum)
            continue
        if cnum in used_cnums:
            die(f"duplicate vector CNUM {cnum}: {path}")
        rows.append(db_from_case(cnum, path, case, path.name, force_link))
        used_cnums.add(cnum)

    next_id = 1
    for path, case in pending:
        if manual_cnum(path) is not None:
            continue
        while f"{next_id:04d}" in used_cnums:
            next_id += 1
        cnum = f"{next_id:04d}"
        rows.append(db_from_case(cnum, path, case, path.name, force_link))
        used_cnums.add(cnum)

    write_db(rows)
    return rows


def convert_raw_vectors(src: Path,
                        source_tag: str,
                        base_addr: int,
                        force: bool,
                        append: bool) -> list[DbCase]:
    if not src.is_dir():
        die(f"SRC does not exist: {src}")
    rows = load_db() if append else []
    start = next_cnum(rows)
    tmp_root = VECTOR_ROOT / ".bvector_tmp"
    clean_path(tmp_root)
    tmp_root.mkdir(parents=True)

    raw_paths = raw_conv.iter_sources(src)
    if not raw_paths:
        die(f"no raw vector files found under {src}")

    new_rows: list[DbCase] = []
    for offset, raw_path in enumerate(raw_paths):
        cnum = f"{start + offset:04d}"
        out_dir = raw_conv.convert_one(
            raw_path=raw_path,
            dst_root=tmp_root,
            source_tag=source_tag,
            source_note=src.name,
            base_addr=base_addr,
            force=True,
        )
        case = reg_flow.load_case(out_dir)
        label = case_label(cnum, case)
        dst_dir = CASE_ROOT / label
        if dst_dir.exists() or dst_dir.is_symlink():
            if not force:
                die(f"{dst_dir} exists; use FORCE=1 to overwrite")
            clean_path(dst_dir)
        dst_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(out_dir), str(dst_dir))
        new_rows.append(db_from_case(cnum, dst_dir, reg_flow.load_case(dst_dir), src.name, True))

    clean_path(tmp_root)
    rows.extend(new_rows)
    write_db(rows)
    return new_rows


def ensure_db() -> list[DbCase]:
    rows = load_db()
    if rows:
        return rows
    return discover_existing_cases(force_link=False)


def select_cases(cnum: str, mode: str | None = None) -> list[DbCase]:
    rows = ensure_db()
    token = (cnum or "all").strip().lower()
    if token in ("", "all"):
        if mode is not None:
            return [row for row in rows if case_supports_mode(row, mode)]
        return rows
    wanted = {item.strip().zfill(4) for item in token.split(",") if item.strip()}
    selected = [row for row in rows if row.cnum in wanted]
    missing = wanted - {row.cnum for row in selected}
    if missing:
        die(f"unknown CNUM: {', '.join(sorted(missing))}; run make bvector first")
    if mode is not None:
        blocked = [row for row in selected if not case_supports_mode(row, mode)]
        if blocked:
            detail = ", ".join(f"{row.cnum}({','.join(row.modes)})" for row in blocked)
            die(f"CNUM does not support MODE={mode}: {detail}")
    return selected


def build_run_args(mode: str,
                   frame_num: int,
                   rand_otf: bool,
                   rand_axi: bool,
                   bank_dly: int,
                   seed: int,
                   axi_read_delay: int) -> str:
    if frame_num < 1 or frame_num > MAX_FRAME_NUM:
        die(f"FRAME_NUM must be 1..{MAX_FRAME_NUM}, got {frame_num}")
    if bank_dly < 1 or bank_dly > 4:
        die(f"BANK_DLY must be 1..4, got {bank_dly}")

    args = [
        f"+tb_frame_repeat={frame_num}",
        "+tb_timeout_cycles=80000000",
        "+tb_idle_gap_cycles=12000000",
        f"+tb_bank_dly={bank_dly}",
    ]

    if mode == "enc":
        if rand_otf:
            args.extend([
                "+tb_otf_random=1",
                f"+tb_otf_gap_seed={seed}",
                "+tb_otf_hblank_gap_max=32",
            ])
        if rand_axi:
            args.extend([
                "+tb_axi_random=1",
                f"+tb_axi_seed={seed ^ 0x5eed0d1a}",
                "+tb_axi_aw_stall_pct=20",
                "+tb_axi_w_stall_pct=20",
            ])
    elif mode == "dec":
        if rand_otf:
            args.extend([
                "+tb_otf_ready_random=1",
                f"+tb_otf_ready_seed={seed}",
                "+tb_otf_ready_stall_pct=5",
            ])
        if rand_axi:
            args.extend([
                "+tb_axi_random=1",
                f"+tb_axi_seed={seed ^ 0x5eed0d1a}",
                "+tb_axi_ar_stall_pct=20",
                "+tb_axi_rvalid_stall_pct=20",
            ])
        if axi_read_delay:
            args.append(f"+tb_axi_read_delay_cycles={axi_read_delay}")
    elif mode == "loop":
        if rand_axi:
            args.extend([
                "+tb_axi_random=1",
                f"+tb_axi_seed={seed ^ 0x5eed0d1a}",
                "+tb_axi_ar_stall_pct=20",
                "+tb_axi_rvalid_stall_pct=20",
            ])
        if axi_read_delay:
            args.append(f"+tb_axi_read_delay_cycles={axi_read_delay}")
    return " ".join(args)


def sim_paths(mode: str, row: DbCase) -> tuple[str, Path, Path, Path]:
    if mode == "enc":
        top = ENC_TOP
    elif mode == "dec":
        top = DEC_TOP
    else:
        top = LOOP_TOP
    build_root = SIM_DIR / "build" / "clean_flow" / mode / row.cnum
    build_dir = build_root / f"{top}_fake"
    log = build_root / "flow.log"
    return top, build_root, build_dir, log


def prepare_case(mode: str, row: DbCase, build_dir: Path) -> reg_flow.VectorCase:
    case = reg_flow.load_case(row.case_dir)
    if mode == "enc":
        reg_flow.prepare_enc_files(case, build_dir)
    elif mode == "dec":
        reg_flow.prepare_dec_files(case, build_dir)
    else:
        reg_flow.prepare_dec_files(case, build_dir)
        reg_flow.prepare_enc_files(case, build_dir)
    return case


def comp_one(mode: str, row: DbCase) -> bool:
    top, build_root, build_dir, log = sim_paths(mode, row)
    case = prepare_case(mode, row, build_dir)
    flags = reg_flow.make_param_flags(top, case, dec=(mode != "enc"))
    if log.exists():
        log.unlink()
    rc = run_sim_make("comp", top, build_root, flags, "", log)
    return rc == 0


def run_one(mode: str,
            row: DbCase,
            frame_num: int,
            rand_otf: bool,
            rand_axi: bool,
            bank_dly: int,
            seed: int,
            axi_read_delay: int) -> bool:
    if mode == "loop":
        return run_loop(row, frame_num, rand_otf, rand_axi, bank_dly, seed, axi_read_delay)
    top, build_root, build_dir, log = sim_paths(mode, row)
    run_args = build_run_args(mode, frame_num, rand_otf, rand_axi, bank_dly, seed, axi_read_delay)
    case = prepare_case(mode, row, build_dir)
    flags = reg_flow.make_param_flags(top, case, dec=(mode == "dec"))
    if log.exists():
        log.unlink()
    if not (build_dir / "simv").exists():
        rc = run_sim_make("comp", top, build_root, flags, run_args, log)
        if rc != 0:
            return False
    rc = run_sim_make("run", top, build_root, flags, run_args, log)
    run_log = build_dir / "run.log"
    passed = rc == 0 and not reg_flow.log_has_failure(log) and not reg_flow.log_has_failure(run_log)
    print(f"[{'PASS' if passed else 'FAIL'}] {mode} CNUM={row.cnum} {row.name}", flush=True)
    return passed


def comp_loop() -> bool:
    build_root = SIM_DIR / "build" / "clean_flow" / "loop" / "tajmahal_4096x600_nv12"
    log = build_root / "flow.log"
    if log.exists():
        log.unlink()
    rc = run_sim_make("comp", LOOP_TOP, build_root, "", "", log)
    return rc == 0


def run_loop(row: DbCase,
             frame_num: int,
             rand_otf: bool,
             rand_axi: bool,
             bank_dly: int,
             seed: int,
             axi_read_delay: int) -> bool:
    top, build_root, build_dir, log = sim_paths("loop", row)
    run_args = build_run_args("loop", frame_num, rand_otf, rand_axi, bank_dly, seed, axi_read_delay)
    case = prepare_case("loop", row, build_dir)
    flags = reg_flow.make_param_flags(top, case, dec=True)
    print(f"[LOOP] CNUM={row.cnum} {row.name}: DEC OTF feeds ENC OTF", flush=True)
    if log.exists():
        log.unlink()
    if not (build_dir / "simv").exists():
        rc = run_sim_make("comp", top, build_root, flags, run_args, log)
        if rc != 0:
            print(f"[FAIL] loop CNUM={row.cnum} {row.name} compile failed", flush=True)
            return False
    rc = run_sim_make("run", top, build_root, flags, run_args, log)
    run_log = build_dir / "run.log"
    passed = rc == 0 and not reg_flow.log_has_failure(log) and not reg_flow.log_has_failure(run_log)
    print(f"[{'PASS' if passed else 'FAIL'}] loop CNUM={row.cnum} {row.name}", flush=True)
    return passed


def submit_bsub(mode: str,
                row: DbCase,
                frame_num: int,
                rand_otf: str,
                rand_axi: str,
                bank_dly: int,
                seed: int,
                axi_read_delay: int) -> bool:
    log_dir = SIM_DIR / "build" / "clean_flow" / "bsub_logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log = log_dir / f"{mode}_{row.cnum}.log"
    cmd = (
        f"make run MODE={mode} CNUM={row.cnum} FRAME_NUM={frame_num} "
        f"RAND_OTF={rand_otf} RAND_AXI={rand_axi} BANK_DLY={bank_dly} "
        f"SEED={seed} AXI_READ_DELAY={axi_read_delay} SUBMIT=local"
    )
    job = f"ubwc_{mode}_{row.cnum}"
    rc = run_cmd(["bsub", "-J", job, "-oo", str(log), cmd])
    return rc == 0


def cmd_bvector(args: argparse.Namespace) -> int:
    if args.src:
        src = Path(args.src).expanduser().resolve()
        rows = convert_raw_vectors(
            src=src,
            source_tag=args.source_tag,
            base_addr=parse_int(args.base_addr),
            force=args.force,
            append=not args.reset,
        )
    else:
        rows = discover_existing_cases(force_link=args.force, preserve_existing=not args.reset)
    print(f"VECTOR_DB={VECTOR_DB}")
    for row in rows:
        print(f"{row.cnum} {row.fmt} {row.width}x{row.height} "
              f"modes={','.join(row.modes)} {row.case_dir}")
    return 0


def cmd_comp(args: argparse.Namespace) -> int:
    mode = args.mode
    if mode not in ("enc", "dec", "loop"):
        die("MODE must be enc, dec, or loop")
    cases = select_cases(args.cnum or "all", mode)
    failed: list[str] = []
    for row in cases:
        if not comp_one(mode, row):
            failed.append(row.cnum)
    if failed:
        print(f"FAIL_COMPILE={','.join(failed)}")
    return 0 if not failed else 1


def cmd_run(args: argparse.Namespace) -> int:
    mode = args.mode
    if mode not in ("enc", "dec", "loop"):
        die("MODE must be enc, dec, or loop")
    frame_num = parse_int(args.frame_num)
    bank_dly = parse_int(args.bank_dly)
    seed = parse_int(args.seed)
    axi_read_delay = parse_int(args.axi_read_delay)
    cases = select_cases(args.cnum, mode)
    submit = args.submit.lower()
    failed: list[str] = []
    rand_otf = normalize_bool(args.rand_otf)
    rand_axi = normalize_bool(args.rand_axi)

    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    summary = SIM_DIR / "build" / "clean_flow" / f"summary_{mode}_{stamp}.txt"
    summary.parent.mkdir(parents=True, exist_ok=True)

    for row in cases:
        if submit == "bsub":
            ok = submit_bsub(mode, row, frame_num, str(int(rand_otf)), str(int(rand_axi)),
                             bank_dly, seed, axi_read_delay)
        elif submit == "local":
            ok = run_one(mode, row, frame_num, rand_otf, rand_axi, bank_dly, seed, axi_read_delay)
        else:
            die("SUBMIT must be local or bsub")
        if not ok:
            failed.append(row.cnum)

    summary.write_text(
        f"mode={mode}\n"
        f"cases={','.join(row.cnum for row in cases)}\n"
        f"frame_num={frame_num}\n"
        f"rand_otf={int(rand_otf)}\n"
        f"rand_axi={int(rand_axi)}\n"
        f"bank_dly={bank_dly}\n"
        f"submit={submit}\n"
        f"fail={','.join(failed)}\n",
        encoding="utf-8",
    )
    print(f"SUMMARY_FILE={summary}")
    return 0 if not failed else 1


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="UBWC clean simulation flow")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_bvector = sub.add_parser("bvector", help="Build vector DB and canonical case directories")
    p_bvector.add_argument("--src", default="", help="Raw vector source directory. Empty means index existing vectors.")
    p_bvector.add_argument("--source-tag", default="ubwc", help="Tag used when converting raw vectors.")
    p_bvector.add_argument("--base-addr", default="0x0000000080000000")
    p_bvector.add_argument("--force", action="store_true")
    p_bvector.add_argument("--reset", action="store_true", help="Do not append to existing vector DB.")
    p_bvector.set_defaults(func=cmd_bvector)

    p_comp = sub.add_parser("comp", help="Compile enc/dec/loop")
    p_comp.add_argument("--mode", required=True)
    p_comp.add_argument("--cnum", default="all")
    p_comp.set_defaults(func=cmd_comp)

    p_run = sub.add_parser("run", help="Run enc/dec/loop")
    p_run.add_argument("--mode", required=True)
    p_run.add_argument("--cnum", required=True)
    p_run.add_argument("--frame-num", default="1")
    p_run.add_argument("--rand-otf", default="0")
    p_run.add_argument("--rand-axi", default="0")
    p_run.add_argument("--bank-dly", default="1")
    p_run.add_argument("--seed", default="1")
    p_run.add_argument("--axi-read-delay", default="0")
    p_run.add_argument("--submit", default="local")
    p_run.set_defaults(func=cmd_run)

    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
