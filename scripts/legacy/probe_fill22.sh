#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 猜测单位是 DBU（0.001 um）：0.14um = 140
cat > "$OUT/r30.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 140,
      "space_to_feature": 140,
      "space_to_fill": 140,
      "space_to_non_fill": 140,
      "halo": 140,
      "min_density": 0.05,
      "max_density": 0.9,
      "window_size": 20000,
      "non-opc": { "datatype": 20, "width": 200, "height": 200, "spacing": 200,
                   "space_to_fill": 140, "space_to_non_fill": 140, "halo": 140 },
      "opc":     { "datatype": 20, "width": 200, "height": 200, "spacing": 200,
                   "space_to_fill": 140, "space_to_non_fill": 140, "halo": 140 }
    }
  ]
}
R

# micron 版：大块 fill
cat > "$OUT/r31.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 0.2,
      "space_to_feature": 0.2,
      "space_to_fill": 0.2,
      "space_to_non_fill": 0.2,
      "halo": 0.2,
      "min_density": 0.05,
      "max_density": 0.9,
      "window_size": 10.0,
      "non-opc": { "datatype": 20, "width": 1.0, "height": 1.0, "spacing": 0.2,
                   "space_to_fill": 0.2, "space_to_non_fill": 0.2, "halo": 0.2 },
      "opc":     { "datatype": 20, "width": 1.0, "height": 1.0, "spacing": 0.2,
                   "space_to_fill": 0.2, "space_to_non_fill": 0.2, "halo": 0.2 }
    }
  ]
}
R

for r in r30 r31; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | grep -E 'Total fills|Filling|RESULT|ERROR'
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
