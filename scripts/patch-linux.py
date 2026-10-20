#!/usr/bin/env python3
"""Patch PDFium source tree for the Linux static build.

Run from the pdfium source root (pdfium-src/pdfium/).
"""

import pathlib
import sys


def patch(path, old, new):
    p = pathlib.Path(path)
    src = p.read_text()
    if old not in src:
        print(f"ERROR: pattern not found in {path}")
        sys.exit(1)
    p.write_text(src.replace(old, new, 1))
    print(f"Patched: {path}")


# Chromium emits CREL relocations, which GNU ld before 2.45 cannot read. Users
# link this library with the old ld of Ubuntu 18.04 or manylinux images.
patch(
    "build/config/compiler/BUILD.gn",
    'cflags += [ "-Wa,--crel,--allow-experimental-crel" ]',
    "",
)
