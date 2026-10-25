source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
foreach n {VPWR VGND} {
  if {[catch {check_power_grid -net $n} err]} {
    puts "PDN_CHECK_FAIL $n: $err"
  }
}
puts "PDN_CHECK_DONE"
