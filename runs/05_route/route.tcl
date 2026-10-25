source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(CTS)/cts.odb
read_sdc $::env(SDC)

set_thread_count 4
global_route -congestion_iterations 50
detailed_route -output_drc "$::env(OUT)/route_drc.rpt" \
               -output_maze "$::env(OUT)/maze.log"

# 用全局布线的估算寄生做时序，不是真实 RC 提取（见 README「已知局限」）
estimate_parasitics -global_routing
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_design_area

write_db $::env(OUT)/route.odb
write_def $::env(OUT)/route.def
