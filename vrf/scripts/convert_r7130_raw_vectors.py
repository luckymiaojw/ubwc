#!/usr/bin/env python3
"""Compatibility entry for the generic UBWC raw-vector converter."""

from __future__ import annotations

import runpy
import sys
from pathlib import Path


if __name__ == "__main__":
    target = Path(__file__).with_name("convert_ubwc_raw_vectors.py")
    sys.argv[0] = str(target)
    runpy.run_path(str(target), run_name="__main__")
