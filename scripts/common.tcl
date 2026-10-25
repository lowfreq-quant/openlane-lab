# common.tcl — OpenROAD 脚本共用初始化
# 由 0x_*.sh 通过 `source $::env(SCRIPTS_DIR)/common.tcl` 载入
# 期望环境变量：PDK_ROOT / PDK / MERGED_LEF（由 scripts/env.sh 统一导出）

proc require_env {name} {
  if {![info exists ::env($name)] || $::env($name) eq ""} {
    error "缺少环境变量 $name（先 source scripts/env.sh）"
  }
  return $::env($name)
}

set pdk_root [expr {[info exists ::env(PDK_ROOT)] ? $::env(PDK_ROOT) : "$::env(HOME)/.volare"}]
set pdk      [expr {[info exists ::env(PDK)] ? $::env(PDK) : "sky130A"}]
set pdk_path "$pdk_root/$pdk"

# 合并 LEF 由 merge_lef.sh 生成：tech 层/site + 单元 MACRO 一次载入
set merged_lef [expr {[info exists ::env(MERGED_LEF)] ? $::env(MERGED_LEF) : "$::env(ROOT)/runs/lef/sky130_fd_sc_hd_merged.lef"}]
set sc_lib     "$pdk_path/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

if {![file exists $merged_lef]} {
  puts "ERROR: 合并 LEF 不存在: $merged_lef"
  puts "       请先运行 scripts/merge_lef.sh"
  error "missing merged LEF"
}
read_lef $merged_lef
if {[file exists $sc_lib]} {
  read_liberty $sc_lib
} else {
  puts "WARNING: SC LIB not found: $sc_lib"
}

puts "PDK loaded from $pdk_path  (merged LEF: $merged_lef)"
