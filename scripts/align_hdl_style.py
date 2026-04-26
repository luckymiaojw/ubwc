#!/usr/bin/env python3
"""Align Verilog/SystemVerilog declarations and instance connections.

This is a lightweight formatter for this repository's HDL style.  It is not a
full Verilog parser; it only touches simple one-line declarations, parameters,
and module instance parameter/port connection lists.
"""

from __future__ import annotations

import argparse
import difflib
import os
from pathlib import Path
import re
import subprocess
import sys
from dataclasses import dataclass

HDL_SUFFIXES = {".v", ".sv", ".vh", ".svh"}

PARAM_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"(?P<kind>parameter|localparam)\s+"
    r"(?:(?P<qual>(?:integer|signed|unsigned|\[[^\]]+\])(?:\s+(?:integer|signed|unsigned|\[[^\]]+\]))*)\s+)?"
    r"(?P<name>[A-Za-z_][\w$]*)"
    r"(?P<rhs>\s*=\s*.*?)?"
    r"\s*(?P<term>[;,]?)"
    r"(?P<trail>\s*//.*)?$"
)

DECL_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"(?P<head>input|output|inout|wire|reg|logic)\b"
    r"(?:\s+(?P<kind>wire|reg|logic))?"
    r"(?:\s+(?P<sign>signed|unsigned))?"
    r"(?:\s+(?P<range>\[[^\]]+\]))?"
    r"\s+(?P<name>[A-Za-z_][\w$]*)"
    r"(?P<rhs>\s*=\s*.*?)?"
    r"\s*(?P<term>[;,]?)"
    r"(?P<trail>\s*//.*)?$"
)

CONN_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"\.(?P<name>[A-Za-z_][\w$]*)\s*"
    r"\((?P<expr>.*)\)"
    r"(?P<term>\s*,?)"
    r"(?P<trail>\s*//.*)?$"
)


@dataclass
class ParamLine:
    indent: str
    kind: str
    qual: str
    name: str
    rhs: str
    term: str
    trail: str


@dataclass
class DeclLine:
    indent: str
    head: str
    kind: str
    sign: str
    range_: str
    name: str
    rhs: str
    term: str
    trail: str


@dataclass
class ConnLine:
    indent: str
    name: str
    expr: str
    term: str
    trail: str


def split_rhs(rhs: str) -> str:
    if not rhs:
        return ""
    rhs = rhs.strip()
    if rhs.startswith("="):
        rhs = rhs[1:].strip()
    return rhs


def parse_param(line: str) -> ParamLine | None:
    match = PARAM_RE.match(line.rstrip("\n"))
    if not match:
        return None
    return ParamLine(
        indent=match.group("indent"),
        kind=match.group("kind"),
        qual=(match.group("qual") or "").strip(),
        name=match.group("name"),
        rhs=split_rhs(match.group("rhs") or ""),
        term=match.group("term"),
        trail=match.group("trail") or "",
    )


def parse_decl(line: str) -> DeclLine | None:
    raw = line.rstrip("\n")
    match = DECL_RE.match(raw)
    if not match:
        return None
    # Skip multiple declarations and procedural assignments; this script keeps
    # intentionally conservative boundaries.
    if "," in match.group("name"):
        return None
    return DeclLine(
        indent=match.group("indent"),
        head=match.group("head"),
        kind=(match.group("kind") or "").strip(),
        sign=(match.group("sign") or "").strip(),
        range_=(match.group("range") or "").strip(),
        name=match.group("name"),
        rhs=split_rhs(match.group("rhs") or ""),
        term=match.group("term"),
        trail=match.group("trail") or "",
    )


def parse_conn(line: str) -> ConnLine | None:
    match = CONN_RE.match(line.rstrip("\n"))
    if not match:
        return None
    expr = match.group("expr").strip()
    # Skip likely multiline expressions collapsed into a single line with nested
    # unmatched delimiters.  Simple concatenations/slices are still fine.
    if "/*" in expr or "*/" in expr:
        return None
    return ConnLine(
        indent=match.group("indent"),
        name=match.group("name"),
        expr=expr,
        term=match.group("term").strip(),
        trail=match.group("trail") or "",
    )


def pad(value: str, width: int) -> str:
    return value + " " * max(0, width - len(value))


def format_param_group(items: list[ParamLine]) -> list[str]:
    kind_w = 11 if all(item.kind == "localparam" for item in items) else 12
    qual_w = max([len(item.qual) for item in items] + [0])
    qual_slot_w = 25 if qual_w else 0
    min_name_w = 28 if qual_w else 16
    name_w = max(max(len(item.name) for item in items) + 4, min_name_w)
    rhs_w = max([len(item.rhs) for item in items] + [0])
    out: list[str] = []
    for item in items:
        line = item.indent + pad(item.kind, kind_w)
        if qual_w:
            line += pad(item.qual, qual_slot_w)
        line += pad(item.name, name_w)
        if item.rhs:
            line += "= "
            line += pad(item.rhs, rhs_w + 3) if item.term or item.trail else item.rhs
        line += item.term + item.trail
        out.append(line)
    return out


def format_decl_group(items: list[DeclLine]) -> list[str]:
    head_w = max(max(len(item.head) for item in items), len("output"))
    kind_w = max([len(item.kind) for item in items] + [0])
    sign_w = max([len(item.sign) for item in items] + [0])
    range_w = max(max([len(item.range_) for item in items] + [0]), 28)
    indent_w = len(items[0].indent.expandtabs(4))
    min_name_w = 20 if indent_w >= 8 else 28
    name_w = max(max(len(item.name) for item in items) + 2, min_name_w)
    rhs_w = max([len(item.rhs) for item in items] + [0])
    out: list[str] = []
    for item in items:
        line = item.indent + pad(item.head, head_w + 2)
        if kind_w:
            line += pad(item.kind, kind_w + 4)
        if sign_w:
            line += pad(item.sign, sign_w + 4)
        line += pad(item.range_, range_w)
        if item.term or item.rhs or item.trail:
            line += pad(item.name, name_w + 2)
        else:
            line += item.name
        if item.rhs:
            line += "= " + pad(item.rhs, rhs_w + 1)
        line += item.term + item.trail
        out.append(line)
    return out


def format_conn_group(items: list[ConnLine]) -> list[str]:
    name_w = max(max(len(item.name) for item in items) + 4, 27)
    expr_w = max(max([len(item.expr) for item in items] + [0]) + 1, 30)
    out: list[str] = []
    for item in items:
        line = item.indent + "." + pad(item.name, name_w)
        if item.expr:
            line += "( " + pad(item.expr, expr_w) + ")"
        else:
            line += "( " + " " * expr_w + ")"
        if item.term:
            line += item.term
        line += item.trail
        out.append(line)
    return out


def line_kind(line: str) -> str | None:
    if parse_conn(line):
        return "conn"
    if parse_param(line):
        return "param"
    if parse_decl(line):
        return "decl"
    return None


def flush(kind: str | None, group: list[str], out: list[str]) -> None:
    if not group:
        return
    if kind == "conn":
        out.extend(format_conn_group([parse_conn(line) for line in group if parse_conn(line)]))
    elif kind == "param":
        out.extend(format_param_group([parse_param(line) for line in group if parse_param(line)]))
    elif kind == "decl":
        out.extend(format_decl_group([parse_decl(line) for line in group if parse_decl(line)]))
    else:
        out.extend(group)


def align_text(text: str) -> str:
    lines = text.splitlines()
    trailing_newline = text.endswith("\n")
    out: list[str] = []
    group: list[str] = []
    kind: str | None = None
    indent: str | None = None

    for line in lines:
        current_kind = line_kind(line)
        current_indent = line[: len(line) - len(line.lstrip())]
        if (
            current_kind
            and kind == current_kind
            and indent == current_indent
            and group
        ):
            group.append(line)
            continue

        flush(kind, group, out)
        group = []
        kind = None
        indent = None

        if current_kind:
            group = [line]
            kind = current_kind
            indent = current_indent
        else:
            out.append(line)

    flush(kind, group, out)
    result = "\n".join(out)
    if trailing_newline:
        result += "\n"
    return result


def git_changed_files(root: Path) -> list[Path]:
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain", "--", "*.v", "*.sv", "*.vh", "*.svh"],
            cwd=root,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    files: list[Path] = []
    for raw in proc.stdout.splitlines():
        if not raw:
            continue
        path_text = raw[3:]
        if " -> " in path_text:
            path_text = path_text.split(" -> ", 1)[1]
        path = root / path_text
        if path.suffix in HDL_SUFFIXES and path.exists():
            files.append(path)
    return files


def collect_paths(paths: list[str], root: Path, all_src: bool) -> list[Path]:
    collected: list[Path] = []
    if all_src:
        paths = ["src", "vrf/src"]
    if not paths:
        return git_changed_files(root)
    for item in paths:
        path = (root / item).resolve() if not os.path.isabs(item) else Path(item)
        if path.is_dir():
            collected.extend(sorted(p for p in path.rglob("*") if p.suffix in HDL_SUFFIXES))
        elif path.suffix in HDL_SUFFIXES and path.exists():
            collected.append(path)
    return sorted(dict.fromkeys(collected))


def main() -> int:
    parser = argparse.ArgumentParser(description="Align HDL style for simple declarations and module instances.")
    parser.add_argument("paths", nargs="*", help="Files or directories to format. Defaults to changed HDL files.")
    parser.add_argument("--all-src", action="store_true", help="Format all HDL files under src and vrf/src.")
    parser.add_argument("--check", action="store_true", help="Do not write files; fail if any file would change.")
    parser.add_argument("--diff", action="store_true", help="Print unified diffs for changed files.")
    args = parser.parse_args()

    root = Path.cwd()
    files = collect_paths(args.paths, root, args.all_src)
    if not files:
        print("No HDL files selected.")
        return 0

    changed = 0
    for path in files:
        original = path.read_text()
        aligned = align_text(original)
        if aligned == original:
            continue
        changed += 1
        rel = path.relative_to(root) if path.is_relative_to(root) else path
        if args.diff or args.check:
            diff = difflib.unified_diff(
                original.splitlines(keepends=True),
                aligned.splitlines(keepends=True),
                fromfile=str(rel),
                tofile=str(rel),
            )
            sys.stdout.writelines(diff)
        if not args.check:
            path.write_text(aligned)
            print(f"aligned {rel}")

    if args.check and changed:
        print(f"{changed} file(s) need alignment.", file=sys.stderr)
        return 1
    if not args.check:
        print(f"Aligned {changed} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
