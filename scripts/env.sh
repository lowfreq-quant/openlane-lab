#!/usr/bin/env bash
# env.sh — 所有脚本的唯一环境入口（被 source，不要直接执行）
#
# 这里不写死任何绝对路径：
#   * 仓库根目录由本文件位置推导 → clone 到哪儿都能跑
#   * PDK 位置遵循 volare 约定（$HOME/.volare），可用 PDK_ROOT 覆盖
#   * 工具路径只在 PATH 前面追加，已有的优先

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

# Nix 装的 OpenROAD / Magic，以及 volare 的 venv
export PATH="$HOME/.nix-profile/bin:$HOME/.venv-asic/bin:$PATH"

# --- PDK ---
export PDK_ROOT="${PDK_ROOT:-$HOME/.volare}"
export PDK="${PDK:-sky130A}"
export PDK_PATH="$PDK_ROOT/$PDK"

export SC_DIR="$PDK_PATH/libs.ref/sky130_fd_sc_hd"
export SC_LIB="$SC_DIR/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
export SC_CDL="$SC_DIR/cdl/sky130_fd_sc_hd.cdl"

# 合并 LEF 放在仓库内，避免多个 checkout 抢 /tmp 里的同名文件
export MERGED_LEF="${MERGED_LEF:-$ROOT/runs/lef/sky130_fd_sc_hd_merged.lef}"

# OpenROAD Tcl 侧要用到
export SCRIPTS_DIR="$ROOT/scripts"

require_pdk() {
  if [[ ! -f "$SC_LIB" ]]; then
    echo "[ERROR] 找不到 sky130 liberty：$SC_LIB" >&2
    echo "        先跑：bash scripts/fetch_pdk.sh   （或设置 PDK_ROOT）" >&2
    return 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] 缺少命令：$1" >&2
    echo "        $2" >&2
    return 1
  fi
}
