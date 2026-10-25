source /mnt/c/Users/ty/Downloads/asic/openlane-lab/scripts/common.tcl
read_db /mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/05_route/route.odb
read_sdc /mnt/c/Users/ty/Downloads/asic/openlane-lab/constraints/counter_complex.sdc
# 粗粒度 RC 缩放：按 sky130 典型量级 × scale（教学近似）
# 覆盖 extract 用的层电阻；via 沿用 5Ω 假设
foreach lay {li1 met1 met2 met3 met4 met5} {
  set r0 0.125
  set c0 0.0002
  catch {set_layer_rc -layer $lay -resistance [expr {$r0 * 0.7}] -capacitance [expr {$c0 * 0.7}]}
}
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via $v -resistance [expr {5.0 * 0.7}]}
}
# OpenRCX 提取（会读 rcx_rules；层 RC 命令作补充）
extract_parasitics -ext_model_file /home/ty/.volare/sky130A/libs.tech/openlane/rcx_rules.info
write_spef /mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/19_rc_corners/rc_cmin.spef
read_spef /mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/19_rc_corners/rc_cmin.spef
report_wns
report_wns -min
puts "SCENARIO rc_cmin cap=0.7 res=0.7"
