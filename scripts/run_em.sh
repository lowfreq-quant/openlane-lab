#!/usr/bin/env bash
# run_em.sh — P2: 电迁移（EM）分析
#
# 为什么：IR drop 只看压降；EM 看金属/via 电流密度有没有超限。
# 依赖 via 电阻假设（LEF 无 via R，见 HANDOFF §10）。
#
# 产物：runs/14_em/em_<net>.log / em_<net>.rpt
set -euo pipefail
source "$(dirname "$0")/env.sh"

require_cmd openroad "见 docs/tools.md"
require_pdk

OUT="$ROOT/runs/14_em"
mkdir -p "$OUT"

ODB="$ROOT/runs/05_route/route.odb"
if [[ -f "$ROOT/runs/05_route/route_filled.odb" ]]; then
  ODB="$ROOT/runs/05_route/route_filled.odb"
fi
[[ -f "$ODB" ]] || { echo "[ERROR] 缺少 $ODB，先 make all" >&2; exit 1; }

VSRC=""
for cand in \
  "$ROOT/runs/02_floorplan/vsrc.txt" \
  "$ROOT/runs/05_route/vsrc.txt" \
  "$ROOT/runs/06_signoff/vsrc.txt"
do
  [[ -f "$cand" ]] && VSRC="$cand" && break
done

# Tcl 脚本用 quoted heredoc，避免 bash 展开 $n/$v
if [[ -n "$VSRC" ]]; then
  VSRC_TCL="set vsrc_args [list -vsrc $VSRC -source_type FULL]"
else
  VSRC_TCL='set vsrc_args {}'
fi

cat > "$OUT/em.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB

# via 电阻假设（LEF 无 via R）
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via \$v -resistance 5.0}
}

$VSRC_TCL

foreach n {VPWR VGND} {
  puts "======== EM net=\$n ========"
  set emfile "$OUT/em_\$n.rpt"
  set errfile "$OUT/em_\$n.err"
  if {[catch {analyze_power_grid -net \$n -enable_em -em_outfile \$emfile -error_file \$errfile {*}\$vsrc_args} err]} {
    puts "EM_FAIL \$n: \$err"
  } else {
    puts "EM_OK \$n -> \$emfile"
  }
}
puts "EM_DONE"
EOF

echo "[info] ODB=$ODB"
echo "[info] VSRC=${VSRC:-（无，由 strap/pin 推断电源源）}"
openroad -no_init -exit "$OUT/em.tcl" 2>&1 | tee "$OUT/em.log"

echo ""
echo "======== EM 摘要 ========"
grep -E 'EM_|Worstcase|IR drop|Percentage|current|Current|jmax|limit|Exceed|exceed|WARNING|ERROR|Net +:' "$OUT/em.log" | tail -60

echo ""
echo "======== 产物 ========"
ls -la "$OUT"
for f in "$OUT"/em_*.rpt "$OUT"/em_*.err; do
  [[ -f "$f" ]] || continue
  echo "--- $(basename "$f") ($(wc -l < "$f") lines) ---"
  head -40 "$f"
done
