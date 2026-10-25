source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
read_sdc $::env(SDC)
# 优先真寄生 SPEF；没有再退回估算
if {[file exists $::env(SPEF)]} {
  read_spef $::env(SPEF)
  puts "PARASITICS: SPEF $::env(SPEF)"
} else {
  estimate_parasitics -global_routing
  puts "PARASITICS: estimate_parasitics (no SPEF)"
}
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_checks -path_delay min
report_clock_skew
report_wns
report_tns
report_design_area
# 后仿要用的 SDF（含单元/连线延迟）
write_sdf $::env(OUT)/counter.sdf
