#!/usr/bin/env bash
# 02 布图规划 Floorplan：确定 die/core、IO 位置、布线轨道
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/02_floorplan"
mkdir -p "$OUT"

NETLIST="$ROOT/runs/01_synth/counter_synth.v"
SDC="$ROOT/constraints/counter.sdc"

if [[ ! -f "$NETLIST" ]]; then
  echo "[ERROR] 缺少网表 $NETLIST，请先跑 01_synth.sh" >&2
  exit 1
fi
require_cmd openroad "安装方式见 docs/tools.md（Nix: nixpkgs.openroad）"
require_pdk

# OpenROAD Tcl 故意写成显式脚本，方便你改 die 尺寸 / 利用率
cat > "$OUT/floorplan.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl

read_verilog $::env(NETLIST)
link_design counter
read_sdc $::env(SDC)

# 裸 die：site=unithd（sky130_fd_sc_hd 的行高）
initialize_floorplan \
  -site unithd \
  -die_area {0 0 100 100} \
  -core_area {10 10 90 90}

# 必须先有轨道，place_pins 才有地方放
make_tracks

# IO 摆放（sky130：水平 met3 / 垂直 met2）
place_pins -hor_layers met3 -ver_layers met2

# 注意：本 lab 不做 PDN（见 README「已知局限」）
write_db $::env(OUT)/floorplan.odb
write_def $::env(OUT)/floorplan.def
report_design_area
EOF

SCRIPTS_DIR="$ROOT/scripts" NETLIST="$NETLIST" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/floorplan.tcl" 2>&1 | tee "$OUT/openroad.log"

echo "[DONE] DEF: $OUT/floorplan.def"
echo "       下一步: 03_place.sh"
