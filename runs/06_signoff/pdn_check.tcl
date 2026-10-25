source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
foreach n {VPWR VGND} {
  if {[catch {check_power_grid -net $n} err]} {
    puts "PDN_CHECK_FAIL $n: $err"
  }
}

# LEF 里层电阻有、via 电阻没有；PSM 遇到 0 电阻会报 PSM-0021。
# 这里按 5 ohm/个 假设（见 README「已知局限」），只为让 PSM 能算出压降。
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via $v -resistance 5.0}
}
foreach n {VPWR VGND} {
  if {[catch {analyze_power_grid -net $n} err]} {
    puts "IR_FAIL $n: $err"
  }
}
puts "PDN_CHECK_DONE"
