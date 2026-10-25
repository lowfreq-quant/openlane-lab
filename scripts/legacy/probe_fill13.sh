#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 每层都带 space_to_outline / space_to_feature
cat > "$OUT/r17.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0
    },
    {
      "name": "met2",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0
    }
  ]
}
R

# layers 为 map，每个 value 是 layer config
cat > "$OUT/r18.rules" <<'R'
{
  "layers": {
    "met1": {
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "shape": "square",
      "width": 1.0,
      "height": 1.0
    }
  }
}
R

for r in r17 r18; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
