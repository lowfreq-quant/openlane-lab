#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OR_BIN=$(command -v openroad)
echo "bin=$OR_BIN"
strings "$OR_BIN" | grep -iE 'space_to|to_outline|to_feature|min_density|max_density|window_size|DensityFill|density_fill|fill rules|No such node' | sort -u
# 也搜 so
find /nix/store/26dacd43g53bs9qvszqxa3z12gb9y7ys-openroad-26Q2 -name '*.so*' | head | while read s; do
  echo "-- $s"
  strings "$s" | grep -iE 'space_to_outline|min_density' | sort -u | head
done
