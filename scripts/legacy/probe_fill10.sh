#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# space_to_outline 放在 layers 里 / 每层里
cat > "$OUT/r12.rules" <<'R'
{
  "layers": {
    "space_to_outline": "1.0",
    "space_to_feature": "1.0",
    "met1": {
      "name": "met1",
      "min_density": "0.30",
      "max_density": "0.70",
      "window_size": "100.0",
      "space_to_outline": "1.0"
    }
  }
}
R

cat > "$OUT/r13.rules" <<'R'
{
  "space_to_outline": 1.0,
  "space_to_feature": 1.0,
  "layers": [
    {
      "layer": "met1",
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0
    }
  ]
}
R

# 扁平顶层键
cat > "$OUT/r14.rules" <<'R'
{
  "space_to_outline": 1.0,
  "space_to_feature": 1.0,
  "min_density": 0.3,
  "max_density": 0.7,
  "window_size": 100.0,
  "layer": "met1",
  "layers": {"met1": {"min_density": 0.3, "max_density": 0.7}}
}
R

for r in r12 r13 r14; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -6
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
