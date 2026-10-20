#!/usr/bin/env bash
# Link the whole Linux library into a test program and a shared object on
# Ubuntu 18.04, then check that both need no glibc above 2.27 and no libstdc++
# above 3.4.22, and that the shared object exports no C++ runtime symbols.
# Usage: verify-glibc.sh <lib_path>
# Run from the pdfium source root (pdfium-src/pdfium/).
set -euo pipefail

LIB_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

docker run --rm -v "$PWD:/src" -v "$SCRIPT_DIR:/scripts" -w /src ubuntu:18.04 bash -euc '
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends gcc libc6-dev binutils >/dev/null
  # --whole-archive links every object, not only the ones the test calls.
  LIB="-Wl,--whole-archive $0 -Wl,--no-whole-archive -lpthread -lm -ldl"
  gcc -o /tmp/test_pdfium /scripts/test_pdfium.c -I. $LIB
  /tmp/test_pdfium
  echo "Ubuntu 18.04 link and run test passed"

  # Like a Rust cdylib, export a single symbol through a version script.
  echo "{ global: main; local: *; };" > /tmp/exports.map
  gcc -shared -o /tmp/libtest_pdfium.so /scripts/test_pdfium.c -I. \
    -Wl,--version-script=/tmp/exports.map $LIB
  echo "Ubuntu 18.04 shared link test passed"

  too_new() { [ -n "$1" ] && [ "$(printf "%s\n%s\n" "$1" "$2" | sort -V | tail -1)" != "$2" ]; }
  for bin in /tmp/test_pdfium /tmp/libtest_pdfium.so; do
    objdump -T "$bin" > /tmp/dynsyms
    max() { grep -oP "\($1\K[0-9.]+" /tmp/dynsyms | sort -uV | tail -1; }
    glibc=$(max GLIBC_); glibcxx=$(max GLIBCXX_)
    echo "$bin: highest GLIBC_ ${glibc:-none}, highest GLIBCXX_ ${glibcxx:-none}"
    if too_new "$glibc" 2.27; then
      echo "ERROR: needs glibc above 2.27:"; grep -P "GLIBC_2\.(2[89]|[3-9]\d)" /tmp/dynsyms; exit 1
    fi
    if too_new "$glibcxx" 3.4.22; then
      echo "ERROR: needs libstdc++ above 3.4.22"; grep GLIBCXX_ /tmp/dynsyms; exit 1
    fi
  done

  exported=$(grep -v "\*UND\*" /tmp/dynsyms | grep -P "\s(__cxa_|__gxx_|_Zn[wa]|_Zd[la]|_ZT[ISV])" || true)
  if [ -n "$exported" ]; then
    echo "ERROR: the shared object exports C++ runtime symbols:"; echo "$exported"; exit 1
  fi
  echo "glibc and libstdc++ versions OK, no C++ runtime symbol exported"
' "$LIB_PATH"
