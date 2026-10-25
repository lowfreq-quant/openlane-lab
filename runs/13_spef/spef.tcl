source /path/to/openlane-lab/scripts/common.tcl
read_db /path/to/openlane-lab/runs/05_route/route.odb
read_sdc /path/to/openlane-lab/constraints/counter.sdc

puts "======== 1) estimate_parasitics (baseline) ========"
estimate_parasitics -global_routing
puts "WNS_EST [report_wns]"
puts "TNS_EST [report_tns]"
report_checks -path_delay max -digits 3

puts "======== 2) extract_parasitics (OpenRCX) ========"
if {[catch {extract_parasitics -ext_model_file /home/user/.volare/sky130A/libs.tech/openlane/rcx_rules.info} err]} {
  puts "EXTRACT_FAILED: $err"
  exit 1
}
puts "EXTRACT_OK"

write_spef /path/to/openlane-lab/runs/13_spef/counter.spef
puts "SPEF_WRITTEN"

puts "======== 3) STA with SPEF ========"
if {[catch {read_spef /path/to/openlane-lab/runs/13_spef/counter.spef} err]} {
  puts "READ_SPEF_FAILED: $err"
  exit 1
}
puts "SPEF_LOADED"
puts "WNS_SPEF [report_wns]"
puts "TNS_SPEF [report_tns]"
report_checks -path_delay max -digits 3
report_checks -path_delay min -digits 3
report_parasitic_annotation -report_unannotated
