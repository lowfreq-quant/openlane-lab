#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

cat > "$OUT/r26.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "space_to_non_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "datatype": 20,
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      },
      "opc": {
        "datatype": 20,
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

# layers 用 map，datatype 在最内
cat > "$OUT/r27.rules" <<'R'
{
  "layers": {
    "met1/20": {
      "name": "met1",
      "datatype": 20,
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "space_to_non_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "datatype": 20,
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5
      }
    }
  }
}
R

for r in r26 r27; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
