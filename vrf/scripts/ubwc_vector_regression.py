#!/usr/bin/env python3
"""Generic UBWC vector regression helper exports.

The implementation currently reuses the legacy regression helper.  Keep this
module name source-agnostic so the top-level clean flow does not depend on a
specific vector drop name.
"""

from run_r7130_vector_regression import *  # noqa: F401,F403
