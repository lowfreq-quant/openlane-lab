#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
export PATH="$HOME/.nix-profile/bin:$PATH"
for per in 6 7 8 10; do
  cat > /tmp/s.sdc <<EOF
create_clock -name clk -period $per [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.2 -clock clk [get_ports rst_n]
set_output_delay 0.2 -clock clk [get_ports q*]
set_output_delay 0.2 -clock clk [get_ports tick]
EOF
  openroad -no_init -exit > /tmp/ss.log 2>&1 <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ROOT/runs/05_route/route.odb
read_liberty $SC_DIR/lib/sky130_fd_sc_hd__ss_100C_1v40.lib
read_sdc /tmp/s.sdc
read_spef $ROOT/runs/13_spef/counter.spef
report_wns
EOF
  wns=$(grep 'wns max' /tmp/ss.log | tail -1 | awk '{print $3}')
  echo "per=${per}ns  ss_wns=$wns"
done
