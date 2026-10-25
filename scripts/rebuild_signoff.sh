#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
echo "===== spef（新布线后必须先提） ====="
make spef 2>&1 | tail -15
echo "===== signoff ====="
make signoff 2>&1 | tail -15
echo "===== corners ====="
make corners 2>&1 | tail -20
echo "===== ocv ====="
make ocv 2>&1 | tail -20
echo "===== em+density ====="
make em 2>&1 | tail -12
make density 2>&1 | tail -12
echo "===== DONE ====="
