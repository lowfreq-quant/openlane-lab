source /path/to/openlane-lab/scripts/common.tcl
read_db /path/to/openlane-lab/runs/05_route/route.odb

# via 电阻假设（LEF 无 via R）
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via $v -resistance 5.0}
}

set vsrc_args {}

foreach n {VPWR VGND} {
  puts "======== EM net=$n ========"
  set emfile "/path/to/openlane-lab/runs/14_em/em_$n.rpt"
  set errfile "/path/to/openlane-lab/runs/14_em/em_$n.err"
  if {[catch {analyze_power_grid -net $n -enable_em -em_outfile $emfile -error_file $errfile {*}$vsrc_args} err]} {
    puts "EM_FAIL $n: $err"
  } else {
    puts "EM_OK $n -> $emfile"
  }
}
puts "EM_DONE"
