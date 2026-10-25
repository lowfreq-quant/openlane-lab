#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# JSON 试验
cat > "$OUT/r4.rules" <<'R'
{
  "met1": {"min_density": 0.3, "max_density": 0.7, "window_size": 100},
  "met2": {"min_density": 0.3, "max_density": 0.7, "window_size": 100}
}
R

# key: value
cat > "$OUT/r5.rules" <<'R'
met1.min_density 0.3
met1.max_density 0.7
met1.window_size 100
R

# OpenROAD 查找字符串
OR_BIN=$(command -v openroad)
strings "$OR_BIN" | grep -iE 'density|min_density|max_density|window|FIN-|fill rule|expected value' | sort -u | head -40

for r in r4 r5; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -8
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
