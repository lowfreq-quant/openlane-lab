#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
echo "===== make all ====="
make all 2>&1 | tail -50
echo "===== make verify ====="
make verify 2>&1 | tail -30
echo "===== make finish ====="
make finish 2>&1 | tail -50
echo "===== DONE ====="
