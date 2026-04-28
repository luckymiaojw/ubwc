#!/usr/bin/env python3
import argparse
from pathlib import Path


def clean_line(line):
    line = line.split("//", 1)[0]
    line = line.split("#", 1)[0]
    return line.strip()


def unique_paths(paths):
    return sorted(dict.fromkeys(str(path) for path in paths))


def parse_flist(flist, seen=None):
    flist = Path(flist).resolve()
    if seen is None:
        seen = set()
    if flist in seen:
        return [], []
    seen.add(flist)
    base = flist.parent
    sources = []
    incdirs = []

    for raw_line in flist.read_text().splitlines():
        line = clean_line(raw_line)
        if not line:
            continue

        if line.startswith("+incdir+"):
            incdir = line[len("+incdir+") :]
            incdirs.append((base / incdir).resolve() if not Path(incdir).is_absolute() else Path(incdir))
        elif line.startswith("-f "):
            nested = line[3:].strip()
            nested_path = Path(nested)
            nested_sources, nested_incdirs = parse_flist(
                (base / nested_path).resolve() if not nested_path.is_absolute() else nested_path,
                seen,
            )
            sources.extend(nested_sources)
            incdirs.extend(nested_incdirs)
        elif line.startswith("+") or line.startswith("-"):
            continue
        else:
            source = Path(line)
            sources.append((base / source).resolve() if not source.is_absolute() else source)

    return sources, incdirs


def include_files(incdirs):
    includes = []
    for incdir in incdirs:
        for pattern in ("*.vh", "*.svh", "*.svi"):
            includes.extend(incdir.glob(pattern))
    return includes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("flist")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--sources", action="store_true")
    mode.add_argument("--incdirs", action="store_true")
    mode.add_argument("--includes", action="store_true")
    args = parser.parse_args()

    sources, incdirs = parse_flist(args.flist)
    if args.sources:
        paths = sources
    elif args.incdirs:
        paths = incdirs
    else:
        paths = include_files(incdirs)

    for path in unique_paths(paths):
        print(path)


if __name__ == "__main__":
    main()
