#!/usr/bin/env bash
# Link the whole Windows library into a DLL with lld-link and the MSVC CRT that
# xwin downloads, like a cargo-xwin build. A newer MSVC STL on the build
# machine can need symbols that this older CRT does not have.
# Usage: verify-xwin.sh <lib_path>
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$1")" && pwd)"
LIB_NAME="$(basename "$1")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XWIN_VERSION=0.10.0

docker run --rm -v "$LIB_DIR:/lib-in:ro" -v "$SCRIPT_DIR:/scripts:ro" ubuntu:24.04 bash -euc '
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends ca-certificates curl clang lld >/dev/null
  curl -fsSL "https://github.com/Jake-Shadle/xwin/releases/download/$1/xwin-$1-$(uname -m)-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin
  xwin --accept-license --log-level warn splat --output /xwin
  LLVM=$(ls -d /usr/lib/llvm-*/bin | tail -1)

  echo "int pdfium_test_entry(void) { return 0; }" > /tmp/test.c
  "$LLVM/clang" --driver-mode=cl --target=x86_64-pc-windows-msvc /MD /c /Fo/tmp/test.obj /tmp/test.c \
    /imsvc/xwin/crt/include /imsvc/xwin/sdk/include/ucrt
  "$LLVM/lld-link" /dll /out:/tmp/test.dll /machine:x64 /tmp/test.obj \
    "/wholearchive:/lib-in/$2" /defaultlib:msvcrt /nodefaultlib:libcmt \
    /libpath:/xwin/crt/lib/x86_64 /libpath:/xwin/sdk/lib/um/x86_64 /libpath:/xwin/sdk/lib/ucrt/x86_64 \
    kernel32.lib user32.lib gdi32.lib advapi32.lib
  echo "xwin DLL link test passed"
' _ "$XWIN_VERSION" "$LIB_NAME"
