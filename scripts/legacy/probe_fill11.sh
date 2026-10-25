#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# boost property_tree INFO 格式
cat > "$OUT/r15.rules" <<'R'
space_to_outline 1.0
space_to_feature 1.0
layers
{
    met1
    {
        min_density 0.30
        max_density 0.70
        window_size 100.0
    }
    met2
    {
        min_density 0.30
        max_density 0.70
        window_size 100.0
    }
}
R

# 也可能是无引号 JSON / relaxed
cat > "$OUT/r16.rules" <<'R'
space_to_outline = 1.0
space_to_feature = 1.0
[met1]
min_density = 0.30
max_density = 0.70
window_size = 100.0
R

for r in r15 r16; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
