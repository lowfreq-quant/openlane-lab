#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

cat > "$OUT/r21.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5
      },
      "opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5
      }
    },
    {
      "name": "met2",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5
      },
      "opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5
      }
    }
  ]
}
R

openroad -no_init -exit <<EOF 2>&1 | tail -12
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/r21.rules} e
puts "RESULT r21: \$e"
EOF
