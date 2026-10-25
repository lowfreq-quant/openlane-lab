#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 递进补齐 JSON 节点：non-opc 及其可能字段
cat > "$OUT/r19.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "width": 1.0,
        "height": 1.0,
        "spacing": 1.0
      },
      "opc": {
        "width": 1.0,
        "height": 1.0,
        "spacing": 1.0
      }
    }
  ]
}
R

cat > "$OUT/r20.rules" <<'R'
{
  "layers": [
    {
      "name": "met1",
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": true,
      "opc": false
    }
  ]
}
R

for r in r19 r20; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
