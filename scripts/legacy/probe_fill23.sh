#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 极简：几乎无间距，大块 fill，看能否落入
cat > "$OUT/r32.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 0.0,
      "space_to_feature": 0.0,
      "space_to_fill": 0.0,
      "space_to_non_fill": 0.0,
      "halo": 0.0,
      "min_density": 0.01,
      "max_density": 1.0,
      "window_size": 5.0,
      "non-opc": { "datatype": 20, "width": 0.14, "height": 0.14, "spacing": 0.0,
                   "space_to_fill": 0.0, "space_to_non_fill": 0.0, "halo": 0.0 },
      "opc":     { "datatype": 20, "width": 0.14, "height": 0.14, "spacing": 0.0,
                   "space_to_fill": 0.0, "space_to_non_fill": 0.0, "halo": 0.0 }
    }
  ]
}
R

openroad -no_init -exit <<EOF 2>&1 | tail -15
source $SCRIPTS_DIR/common.tcl
read_db $OD
density_fill -rules $OUT/r32.rules
puts DONE
EOF
