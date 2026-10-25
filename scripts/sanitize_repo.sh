#!/usr/bin/env bash
# sanitize_repo.sh — 把仓库文本文件里的本机绝对路径换成占位符
#
# 为什么需要：runs/ 里提交的是真实日志，工具会把本机路径写进去。
# 每次重新跑完流程、提交前跑一下（或 make sanitize），避免把
# Windows/WSL 用户名和目录结构带到公开仓库。
#
# 只处理文本文件（grep -I 跳过二进制），不碰 GDS/PNG。
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"

files=$(grep -rlI --exclude-dir=.git --exclude=sanitize_repo.sh \
  -e '/mnt/c/Users/' -e '/home/' -e 'C:\\Users\\' -e '/path/to/Downloads/' . 2>/dev/null || true)

if [[ -z "$files" ]]; then
  echo "[sanitize] 没有发现本机路径"
  exit 0
fi

echo "$files" | while IFS= read -r f; do
  sed -i \
    -e 's#/path/to/Downloads/asic/openlane-lab#/path/to/openlane-lab#g' \
    -e 's#/mnt/c/Users/[A-Za-z0-9_.-]*/Downloads/asic/openlane-lab#/path/to/openlane-lab#g' \
    -e 's#/mnt/c/Users/[A-Za-z0-9_.-]*#/path/to#g' \
    -e 's#/home/[A-Za-z0-9_.-]*/#/home/user/#g' \
    -e 's#C:\\\\Users\\\\[A-Za-z0-9_.-]*#C:\\\\Users\\\\user#g' \
    "$f"
done

n=$(echo "$files" | wc -l)
echo "[sanitize] 已处理 $n 个文件"
left=$(grep -rlI --exclude-dir=.git --exclude=sanitize_repo.sh -e '/mnt/c/Users/' -e '/home/[a-z]' . 2>/dev/null | wc -l)
echo "[sanitize] 剩余疑似本机路径文件: $left"
