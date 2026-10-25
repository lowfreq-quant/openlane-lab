source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
read_sdc $::env(SDC)
# 用布线后的估算寄生（没有 OpenRCX 模型，做不了 3D 提取，见 README）
estimate_parasitics -global_routing
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_checks -path_delay min
report_clock_skew
report_wns
report_tns
report_design_area
# 后仿要用的 SDF（含单元/连线延迟）
write_sdf $::env(OUT)/counter.sdf
