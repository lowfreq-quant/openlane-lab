#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
ls -la /nix/store/26dacd43g53bs9qvszqxa3z12gb9y7ys-openroad-26Q2/share/openroad 2>/dev/null | head
find /nix/store/26dacd43g53bs9qvszqxa3z12gb9y7ys-openroad-26Q2 -iname '*density*' -o -iname '*fill*' 2>/dev/null | head -20
openroad -no_init -exit <<'EOF'
# 看无 rules 时的报错
catch {density_fill} e
puts "no-rules: $e"
catch {density_fill -rules /tmp/nope.rules} e2
puts "bad-rules: $e2"
# 查子命令
puts [info commands *density*]
puts [info commands *fill*]
EOF
