#!/usr/bin/env python3
"""Patch PDFium source tree for the Windows static build.

Run from the pdfium source root (pdfium-src/pdfium/).

Fork note: every patch is best-effort. Older chromium branches do not contain
the newer patterns, and a missing pattern must not abort the build.
"""

import pathlib
import re
import sys


def patch(path, old, new, required=False):
    p = pathlib.Path(path)
    if not p.exists():
        if required:
            print(f"ERROR: missing file {path}")
            sys.exit(1)
        print(f"Skip (no file): {path}")
        return
    src = p.read_text()
    if old not in src:
        if required:
            print(f"ERROR: pattern not found in {path}")
            sys.exit(1)
        print(f"Skip (no match): {path}")
        return
    p.write_text(src.replace(old, new, 1))
    print(f"Patched: {path}")


# Since chromium/7934, cfx_renderdevice.h declares CreateForWindowsDC(HDC, ...)
# without including <windows.h>. Upstream gets HDC transitively through
# partition_alloc's headers, which we don't build (pdf_use_partition_alloc =
# false), so add the include explicitly.
patch(
    "core/fxge/cfx_renderdevice.h",
    '#include "build/build_config.h"\n',
    '#include "build/build_config.h"\n'
    "\n"
    "#if BUILDFLAG(IS_WIN)\n"
    "#include <windows.h>\n"
    "#endif\n"
    "\n",
)


# Newer branches ask for a Windows SDK the GitHub runners do not install
# headers for. Fall back to the newest SDK whose headers are present.
sdk_include = pathlib.Path(r"C:\Program Files (x86)\Windows Kits\10\Include")
if sdk_include.is_dir():
    sdk_version = max(
        (d.name for d in sdk_include.iterdir() if (d / "um").is_dir()),
        key=lambda v: tuple(int(x) for x in v.split(".")),
    )
    for path in ("build/vs_toolchain.py", "build/toolchain/win/setup_toolchain.py"):
        p = pathlib.Path(path)
        if not p.exists():
            continue
        src, n = re.subn(
            r"^SDK_VERSION = '[^']+'$",
            f"SDK_VERSION = '{sdk_version}'",
            p.read_text(),
            flags=re.M,
        )
        if n:
            p.write_text(src)
            print(f"Patched: {path} (SDK {sdk_version})")
        else:
            print(f"Skip (no SDK_VERSION): {path}")

# NTDDI_WIN11_BR only exists in SDK 28000. NTDDI_WIN11_GE is the newest value
# SDK 26100 knows. Older branches already use GE, so this is a no-op there.
# The runner's MSVC STL calls vectorised helpers (__std_rotate, ...) that older
# CRTs do not have. Turn them off.
patch(
    "build/config/win/BUILD.gn",
    '"NTDDI_VERSION=NTDDI_WIN11_BR",',
    '"NTDDI_VERSION=NTDDI_WIN11_GE",\n    "_USE_STD_VECTOR_ALGORITHMS=0",',
)
