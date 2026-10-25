#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT=/tmp/fill_probe
mkdir -p "$OUT"
OD=$ROOT/runs/05_route/route.odb

# 补 datatype；sky130 金属 drawing 通常 datatype=20
make_layer() {
  local name=$1 dt=$2
  cat <<EOF
    {
      "name": "$name",
      "datatype": $dt,
      "space_to_outline": 1.0,
      "space_to_feature": 1.0,
      "space_to_fill": 1.0,
      "space_to_non_fill": 1.0,
      "min_density": 0.3,
      "max_density": 0.7,
      "window_size": 100.0,
      "non-opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      },
      "opc": {
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      }
    }
EOF
}

{
  echo '{'
  echo '  "space_to_fill": 1.0,'
  echo '  "space_to_non_fill": 1.0,'
  echo '  "layers": ['
  make_layer met1 20 | sed 's/^/  /'
  echo '  ,'
  make_layer met2 20 | sed 's/^/  /'
  echo '  ]'
  echo '}'
} > "$OUT/r24.rules"

# 简洁版只留一层试 schema
cat > "$OUT/r25.rules" <<'R'
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
        "width": 0.5,
        "height": 0.5,
        "spacing": 0.5,
        "space_to_fill": 1.0,
        "space_to_non_fill": 1.0
      },
      "opc": {
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

for r in r25; do
  echo "===== $r ====="
  openroad -no_init -exit <<EOF 2>&1 | tail -10
source $SCRIPTS_DIR/common.tcl
read_db $OD
catch {density_fill -rules $OUT/$r.rules} e
puts "RESULT $r: \$e"
EOF
done
