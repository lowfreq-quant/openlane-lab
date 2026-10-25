#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
openroad -no_init -exit <<'EOF'
puts "==== density_fill ===="
help density_fill
puts "==== filler_placement ===="
catch {help filler_placement} e
puts $e
EOF
