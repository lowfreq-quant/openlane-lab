#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb
[[ -f $OD ]] || OD=$ROOT/runs/02_floorplan/floorplan.odb

# 候选 rules 格式
cat > "$OUT/r1.rules" <<'R'
# window_size min_density max_density
met1 100 0.3 0.7
met2 100 0.3 0.7
met3 100 0.3 0.7
met4 100 0.3 0.7
met5 100 0.3 0.7
R

cat > "$OUT/r2.rules" <<'R'
set_layer_density met1 -window 100 -min 0.3 -max 0.7
set_layer_density met2 -window 100 -min 0.3 -max 0.7
R

cat > "$OUT/r3.rules" <<'R'
[met1]
min_density = 0.3
max_density = 0.7
window_size = 100
[met2]
min_density = 0.3
max_density = 0.7
window_size = 100
R

for r in r1 r2 r3; do
  echo "===== try $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -15
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
