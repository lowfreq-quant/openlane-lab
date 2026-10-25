#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# layers 为 map，数值为字符串（boost ptree 更稳）
cat > "$OUT/r10.rules" <<'R'
{
  "space_to_outline": "1.0",
  "layers": {
    "met1": {
      "min_density": "0.30",
      "max_density": "0.70",
      "window_size": "100.0"
    },
    "met2": {
      "min_density": "0.30",
      "max_density": "0.70",
      "window_size": "100.0"
    }
  }
}
R

# 键名变体
cat > "$OUT/r11.rules" <<'R'
{
  "space-to-outline": 1.0,
  "spaceToOutline": 1.0,
  "space_to_outline": 1,
  "layers": {
    "met1": {"min_density": 0.3, "max_density": 0.7, "window_size": 100}
  }
}
R

for r in r10 r11; do
  echo "===== $r ====="
  cat "$OUT/$r.rules"
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
