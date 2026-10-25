#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# boost property_tree 常见 XML
cat > "$OUT/r8.rules" <<'R'
<?xml version="1.0"?>
<fill>
  <space_to_outline>1.0</space_to_outline>
  <layers>
    <layer>
      <name>met1</name>
      <min_density>0.30</min_density>
      <max_density>0.70</max_density>
      <window_size>100.0</window_size>
    </layer>
    <layer>
      <name>met2</name>
      <min_density>0.30</min_density>
      <max_density>0.70</max_density>
      <window_size>100.0</window_size>
    </layer>
  </layers>
</fill>
R

# 也可能是 INI
cat > "$OUT/r9.rules" <<'R'
space_to_outline=1.0
[met1]
min_density=0.3
max_density=0.7
window_size=100
R

for r in r8 r9; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -10
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
