#!/usr/bin/env bash
# 02 布图规划 Floorplan：die/core、IO 位置、布线轨道、电源网络（PDN）
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

# OpenROAD Tcl 故意写成显式脚本，方便你改 die 尺寸 / PDN 参数
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

# ---- PDN：把单元的 VPWR/VGND 接成真正的电源网络 ----
# 1) 把每个实例的电源脚按名字连到全局网
add_global_connection -net VPWR -pin_pattern {^VPWR$} -power
add_global_connection -net VGND -pin_pattern {^VGND$} -ground
global_connect

# 2) 电源域 + 网格（-pins met5 会生成顶层电源端子，后面 check_power_grid 才能用）
set_voltage_domain -name CORE -power VPWR -ground VGND
define_pdn_grid -name stdcell -starts_with POWER -voltage_domains CORE -pins {met5}

# 3) met1 沿标准单元行铺电源轨（followpin），met4/met5 做主干
add_pdn_stripe -grid stdcell -layer met1 -width 0.48 -followpins
add_pdn_stripe -grid stdcell -layer met4 -width 1.6 -spacing 1.6 -pitch 28.0 -offset 4.0
add_pdn_stripe -grid stdcell -layer met5 -width 1.6 -spacing 1.6 -pitch 28.0 -offset 4.0

# 4) 层间连接（pdngen 自动打 via 阵列）
add_pdn_connect -grid stdcell -layers {met1 met4}
add_pdn_connect -grid stdcell -layers {met4 met5}

pdngen

write_db $::env(OUT)/floorplan.odb
write_def $::env(OUT)/floorplan.def
report_design_area
EOF

SCRIPTS_DIR="$ROOT/scripts" NETLIST="$NETLIST" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/floorplan.tcl" 2>&1 | tee "$OUT/openroad.log"

# PDN 必须真的生成：DEF 里没有 SPECIALNETS 就是没插上
if ! grep -q '^SPECIALNETS' "$OUT/floorplan.def"; then
  echo "[ERROR] floorplan.def 里没有 SPECIALNETS，PDN 没生成" >&2
  exit 1
fi
nets=$(grep -m1 '^SPECIALNETS' "$OUT/floorplan.def" | awk '{print $2}')
echo "[DONE] DEF: $OUT/floorplan.def   SPECIALNETS=${nets:-?}（VPWR/VGND）"
echo "       下一步: 03_place.sh"
