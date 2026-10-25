#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
python3 scripts/fix_hier_lvs.py
/usr/bin/netgen-lvs -batch lvs \
  "runs/17_lvs_device/counter_hier_ext_fix.spice counter" \
  "runs/17_lvs_device/counter_hier_golden.spice counter" \
  runs/17_lvs_device/lvs_hier_setup.tcl \
  runs/17_lvs_device/lvs_hier.out 2>&1 | tail -40
echo "==== RESULT ===="
grep -E 'Result|match uniquely|contains|MISMATCH|Netlists' runs/17_lvs_device/lvs_hier.out 2>/dev/null | tail -20 || true
