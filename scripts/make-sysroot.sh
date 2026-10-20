#!/usr/bin/env bash
# Build a glibc 2.27 sysroot from Ubuntu 18.04, so the Linux library runs on
# Ubuntu 18.04 and RHEL 8 hosts.
# Usage: make-sysroot.sh <output_dir>
set -euo pipefail

OUT="$1"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

docker run --rm -v "$OUT:/out" ubuntu:18.04 bash -euc '
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends libc6-dev linux-libc-dev libgcc-7-dev >/dev/null
  mkdir -p /out/usr/lib /out/lib
  cp -a /usr/include /out/usr/
  cp -a /usr/lib/x86_64-linux-gnu /usr/lib/gcc /out/usr/lib/
  cp -a /lib/x86_64-linux-gnu /out/lib/
'
echo "Sysroot ready in $OUT (glibc $(grep -m1 -oP "__GLIBC_MINOR__\s+\K\d+" "$OUT/usr/include/features.h" | sed "s/^/2./"))"
