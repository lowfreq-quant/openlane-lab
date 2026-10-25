#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

cat > "$OUT/r6.rules" <<'R'
{
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

openroad -no_init -exit <<EOF 2>&1 | tail -20
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/r6.rules} e
puts "RESULT r6: \$e"
EOF
