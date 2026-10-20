#!/usr/bin/env bash
# Link the whole Linux library into a test program on Ubuntu 18.04, then check
# that the program needs no glibc above 2.27 and no libstdc++ above 3.4.22.
# Usage: verify-glibc.sh <lib_path>
# Run from the pdfium source root (pdfium-src/pdfium/).
set -euo pipefail

LIB_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

docker run --rm -v "$PWD:/src" -v "$SCRIPT_DIR:/scripts" -w /src ubuntu:18.04 bash -euc '
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends gcc libc6-dev binutils >/dev/null
  # --whole-archive links every object, not only the ones the test calls.
  gcc -o /tmp/test_pdfium /scripts/test_pdfium.c -I. \
    -Wl,--whole-archive "$0" -Wl,--no-whole-archive -lpthread -lm -ldl
  /tmp/test_pdfium
  echo "Ubuntu 18.04 link and run test passed"

  objdump -T /tmp/test_pdfium > /tmp/dynsyms
  max() { grep -oP "\($1\K[0-9.]+" /tmp/dynsyms | sort -uV | tail -1; }
  glibc=$(max GLIBC_); glibcxx=$(max GLIBCXX_)
  echo "Highest GLIBC_ version: ${glibc:-none}"
  echo "Highest GLIBCXX_ version: ${glibcxx:-none}"
  too_new() { [ -n "$1" ] && [ "$(printf "%s\n%s\n" "$1" "$2" | sort -V | tail -1)" != "$2" ]; }
  if too_new "$glibc" 2.27; then
    echo "ERROR: needs glibc above 2.27:"; grep -P "GLIBC_2\.(2[89]|[3-9]\d)" /tmp/dynsyms; exit 1
  fi
  if too_new "$glibcxx" 3.4.22; then
    echo "ERROR: needs libstdc++ above 3.4.22"; grep GLIBCXX_ /tmp/dynsyms; exit 1
  fi
  echo "glibc and libstdc++ versions OK"
' "$LIB_PATH"
