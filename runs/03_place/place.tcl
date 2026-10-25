source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(FP)/floorplan.odb

if {[info exists ::env(SDC)] && [file exists $::env(SDC)]} {
  read_sdc $::env(SDC)
}

# 全局布局 → 详细布局
global_placement -density 0.55
estimate_parasitics -placement
report_checks -path_delay max -fields {slew capacitance input_pins nets} -format full_clock_expanded

detailed_placement
check_placement -verbose

write_db $::env(OUT)/place.odb
write_def $::env(OUT)/place.def
report_design_area
