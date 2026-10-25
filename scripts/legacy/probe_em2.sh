#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
openroad -no_init -exit <<'EOF'
foreach cmd {set_em_constraints set_layer_em get_layer_em report_em set_layer_rc} {
  puts "==== $cmd ===="
  catch {help $cmd} e
  puts $e
}
EOF
