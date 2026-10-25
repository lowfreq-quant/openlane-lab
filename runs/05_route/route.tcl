source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(CTS)/cts.odb
read_sdc $::env(SDC)

set_thread_count 4
global_route -congestion_iterations 50
detailed_route -output_drc "$::env(OUT)/route_drc.rpt" \
               -output_maze "$::env(OUT)/maze.log"

# 天线检查：长线在等离子刻蚀时积累电荷，必须没有天线违例
check_antennas -verbose

# 用全局布线的估算寄生做时序（没有 RCX 模型，做不了真实提取，见 README）
estimate_parasitics -global_routing
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded

# 填充单元：把空 site 用 fill cell 填满，保证密度/平坦化
# 填完重新 global_connect，否则新实例的电源脚不接网格
filler_placement -prefix FILLER_ {
  sky130_fd_sc_hd__fill_8
  sky130_fd_sc_hd__fill_4
  sky130_fd_sc_hd__fill_2
  sky130_fd_sc_hd__fill_1
}
global_connect

report_design_area
write_db $::env(OUT)/route.odb
write_def $::env(OUT)/route.def
