source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(PL)/place.odb

if {[info exists ::env(SDC)] && [file exists $::env(SDC)]} {
  read_sdc $::env(SDC)
}

# 时钟树：OpenROAD 内置 CTS
clock_tree_synthesis \
  -buf_list {sky130_fd_sc_hd__buf_1 sky130_fd_sc_hd__buf_2} \
  -sink_clustering_enable \
  -balance_levels

# 插完 buffer 要重新合法化
detailed_placement
estimate_parasitics -placement
report_checks -path_delay max -fields {slew capacitance input_pins nets} -format full_clock_expanded
report_clock_skew

write_db $::env(OUT)/cts.odb
write_def $::env(OUT)/cts.def
