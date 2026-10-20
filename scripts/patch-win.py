#!/usr/bin/env python3
"""Patch PDFium source tree for the Windows static build.

Run from the pdfium source root (pdfium-src/pdfium/).
"""

import pathlib
import re
import sys


def patch(path, old, new):
    p = pathlib.Path(path)
    src = p.read_text()
    if old not in src:
        print(f"ERROR: pattern not found in {path}")
        sys.exit(1)
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


# Since chromium/8082, the build asks for Windows SDK 10.0.28000.0. GitHub
# runners only have its binaries, not its headers, so use the newest SDK whose
# headers are installed.
sdk_include = pathlib.Path(r"C:\Program Files (x86)\Windows Kits\10\Include")
sdk_version = max(
    (d.name for d in sdk_include.iterdir() if (d / "um").is_dir()),
    key=lambda v: tuple(int(x) for x in v.split(".")),
)
for path in ("build/vs_toolchain.py", "build/toolchain/win/setup_toolchain.py"):
    p = pathlib.Path(path)
    src, n = re.subn(
        r"^SDK_VERSION = '[^']+'$",
        f"SDK_VERSION = '{sdk_version}'",
        p.read_text(),
        flags=re.M,
    )
    if n != 1:
        print(f"ERROR: SDK_VERSION not found in {path}")
        sys.exit(1)
    p.write_text(src)
    print(f"Patched: {path} (SDK {sdk_version})")

# NTDDI_WIN11_BR only exists in SDK 28000. NTDDI_WIN11_GE is the newest value
# SDK 26100 knows.
patch(
    "build/config/win/BUILD.gn",
    '"NTDDI_VERSION=NTDDI_WIN11_BR"',
    '"NTDDI_VERSION=NTDDI_WIN11_GE"',
)
