#!/bin/bash
export PATH="$HOME/.nix-profile/bin:$PATH"
openroad -no_init -exit <<'EOF'
puts "=== extract_parasitics ==="
help extract_parasitics
puts "=== write_spef ==="
help write_spef
puts "=== define_rcx ==="
catch {help define_rcx_corners} err
puts $err
EOF
