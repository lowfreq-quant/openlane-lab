#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
BIN=$(command -v openroad)
echo "openroad=$BIN"
# 在二进制/共享库里找 density_fill 相关字符串
find /home/user/.nix-profile/lib /nix/store -name '*openroad*' -type d 2>/dev/null | head -5
find /nix/store -name 'density*.tcl' -o -name '*fill*rule*' 2>/dev/null | head -15
# strings
find /nix/store -name 'openroad' -type f 2>/dev/null | head -3 | while read p; do
  echo "== $p =="
  strings "$p" | grep -iE 'density_fill|minDensity|maxDensity|windowSize|DensityFill' | sort -u | head -30
done
