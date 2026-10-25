#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
openroad -no_init -exit <<'EOF'
puts "=== analyze_power_grid ==="
help analyze_power_grid
puts "=== check_power_grid ==="
help check_power_grid
puts "=== set_pdn_uvia / set_layer_rc ==="
catch {help set_layer_rc} e1; puts $e1
EOF
