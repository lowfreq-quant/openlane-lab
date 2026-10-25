#!/usr/bin/env bash
# fetch_pdk.sh — 用 volare 拉预编译 sky130A（不用自己 build open_pdks）
#
# 本 lab 锁定的版本：7519dfb04400f224f140749cda44ee7de6f5e095
# 想换版本：bash scripts/fetch_pdk.sh <其他 volare hash>
set -euo pipefail
source "$(dirname "$0")/env.sh"

VER="${1:-7519dfb04400f224f140749cda44ee7de6f5e095}"
require_cmd volare "pip install volare（建议放 venv：python3 -m venv ~/.venv-asic）"

echo "=== volare enable sky130 $VER ==="
volare enable --pdk sky130 "$VER"

echo ""
echo "PDK_ROOT=$PDK_ROOT"
volare ls --pdk sky130 2>/dev/null | head -10 || true

if [[ -f "$SC_LIB" ]]; then
  echo "[OK] $SC_LIB"
else
  echo "[ERROR] PDK 装好了但找不到 liberty，检查 PDK_ROOT/PDK" >&2
  exit 1
fi
