#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

cat > "$OUT/r23.rules" <<'R'
{
  "space_to_fill": 1.0,
  "space_to_non_fill": 1.0,
  "layers": [
    {
      "name": "met1",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "space_to_non_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      },
      "opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      }
    }
  ]
}
R

openroad -no_init -exit <<EOF 2>&1 | tail -10
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/r23.rules} e
puts "RESULT r23: \$e"
EOF
