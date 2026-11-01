v {xschem version=3.0.0 file_version=1.2
* sky130 7-stage ring oscillator
}
G {}
K {}
V {}
S {}
E {}
T {sky130 7-stage ring oscillator} -200 -300 0 0 0.5 0.5 {layer=4}
N 40 0 160 0 { lab=n1}
N 240 0 360 0 { lab=n2}
N 440 0 560 0 { lab=n3}
N 640 0 760 0 { lab=n4}
N 840 0 960 0 { lab=n5}
N 1040 0 1160 0 { lab=n6}
N 1240 0 1240 120 { lab=out}
N 1240 120 -40 120 { lab=out}
N -40 120 -40 0 { lab=out}
C {devices/lab_pin.sym} 100 0 0 0 {name=p1 lab=n1}
C {devices/lab_pin.sym} 300 0 0 0 {name=p2 lab=n2}
C {devices/lab_pin.sym} 500 0 0 0 {name=p3 lab=n3}
C {devices/lab_pin.sym} 700 0 0 0 {name=p4 lab=n4}
C {devices/lab_pin.sym} 900 0 0 0 {name=p5 lab=n5}
C {devices/lab_pin.sym} 1100 0 0 0 {name=p6 lab=n6}
C {devices/lab_pin.sym} 600 120 0 0 {name=p7 lab=out}
C {sky130_tests/not.sym} 0 0 0 0 {name=x1 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 200 0 0 0 {name=x2 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 400 0 0 0 {name=x3 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 600 0 0 0 {name=x4 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 800 0 0 0 {name=x5 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 1000 0 0 0 {name=x6 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not.sym} 1200 0 0 0 {name=x7 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {devices/code_shown.sym} 0 -400 0 0 {name=TT only_toplevel=true
value=".lib /home/user/.volare/sky130A/libs.tech/ngspice/sky130.lib.spice tt"}
C {devices/code_shown.sym} 0 -300 0 0 {name=NGSPICE
only_toplevel=true
value="
vvss VSS 0 dc 0
vvcc VCC 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8

.control
save all
tran 0.05n 200n
meas tran t1 when v(out)=0.9 rise=4
meas tran t2 when v(out)=0.9 rise=10
write ro_pre.raw
.endc
"}
