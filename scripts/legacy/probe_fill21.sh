#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 极低 min_density 强制出 fill，验证几何是否写入
cat > "$OUT/r29.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 0.14,
      "space_to_feature": 0.14,
      "space_to_fill": 0.14,
      "space_to_non_fill": 0.14,
      "halo": 0.14,
      "min_density": 0.01,
      "max_density": 0.9,
      "window_size": 20.0,
      "non-opc": { "datatype": 20, "width": 0.14, "height": 0.14, "spacing": 0.14,
                   "space_to_fill": 0.14, "space_to_non_fill": 0.14, "halo": 0.14 },
      "opc":     { "datatype": 20, "width": 0.14, "height": 0.14, "spacing": 0.14,
                   "space_to_fill": 0.14, "space_to_non_fill": 0.14, "halo": 0.14 }
    }
  ]
}
R

openroad -no_init -exit <<EOF 2>&1 | tail -25
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {set_density_fill_debug_cmd 1} e0
puts "debugcmd: \$e0"
density_fill -rules $OUT/r29.rules
# 查 dbFill
puts "==== dbFill ===="
catch {
  set fills [get_db fills]
  puts "nfills [llength \$fills]"
} e1
puts "get_db fills: \$e1"
# 用 odb Tcl
catch {
  set n 0
  foreach f [::odb::dbFills] { incr n }
  puts "odbFills \$n"
} e2
puts "odb: \$e2"
EOF
