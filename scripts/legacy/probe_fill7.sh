#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 逐步补 JSON 节点，直到 density_fill 收下
cat > "$OUT/r7.rules" <<'R'
{
  "space_to_outline": 1.0,
  "space_to_outline_unit": "um",
  "layers": [
    {
      "name": "met1",
      "min_density": 0.30,
      "max_density": 0.70,
      "window_size": 100.0
    },
    {
      "name": "met2",
      "min_density": 0.30,
      "max_density": 0.70,
      "window_size": 100.0
    }
  ]
}
R

openroad -no_init -exit <<EOF 2>&1 | tail -15
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/r7.rules} e
puts "RESULT r7: \$e"
EOF
