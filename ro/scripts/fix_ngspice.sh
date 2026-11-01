#!/bin/bash
# 修复 sky130A PDK 缺失的 ngspice corners/r+c 模型层
set -e
PDK=$HOME/.volare/sky130A
PDKNG=$PDK/libs.tech/ngspice
DEVSPICE=$PDK/libs.ref/sky130_fd_pr/spice
REPO=https://github.com/google/skywater-pdk-libs-sky130_fd_pr
WORK=/tmp/fdpr_fix
rm -rf "$WORK"; mkdir -p "$WORK"
cd "$WORK"

echo "=== 1. sparse clone fd_pr models ==="
git clone --depth 1 --filter=blob:none --sparse "$REPO" fdpr 2>&1 | tail -1
cd fdpr
git sparse-checkout set models
echo "models .spice 文件数: $(find models -type f -name '*.spice' | wc -l)"

echo
echo "=== 2. 版本一致性抽查 ==="
git sparse-checkout add cells/nfet_01v8
if diff -q cells/nfet_01v8/sky130_fd_pr__nfet_01v8__tt.pm3.spice \
   "$DEVSPICE/sky130_fd_pr__nfet_01v8__tt.pm3.spice" >/dev/null 2>&1; then
  echo "[OK] main 分支器件模型与本地一致"
else
  echo "[!] 注意: nfet_01v8 tt.pm3 与本地存在版本差异"
fi

echo
echo "=== 3. 安装 models 树到 PDK (不覆盖已有文件) ==="
for f in models/*; do
  base=$(basename "$f")
  case "$base" in
    sky130.lib.spice|spinit|sky130_fd_pr__model__*) continue;;
  esac
  if [ -e "$PDKNG/$base" ]; then echo "已存在跳过: $base"; continue; fi
  cp -r "$f" "$PDKNG/"
  echo "安装: $base"
done

echo
echo "=== 4. 校验 corners 引用的器件文件 ==="
: > missing.txt
while read -r ref; do
  fname=$(basename "$ref")
  [ -f "$DEVSPICE/$fname" ] || echo "$ref" >> missing.txt
done < <(grep -rhoE '\.\./\.\./cells/[A-Za-z0-9_.+-]+/[A-Za-z0-9_.+-]+\.spice' models/corners models/r+c | sort -u)
echo "本地缺失器件模型: $(wc -l < missing.txt) 个"
while read -r ref; do
  git sparse-checkout add "cells/$(dirname "${ref#../../cells/}")" >/dev/null 2>&1 || true
done < missing.txt
while read -r ref; do
  src="cells/${ref#../../cells/}"
  if [ -f "$src" ]; then
    cp "$src" "$DEVSPICE/$(basename "$ref")"; echo "补齐: $(basename "$ref")"
  else
    echo "!! 仓库也没有: $ref"
  fi
done < missing.txt

echo
echo "=== 5. .include 相对路径 -> 绝对路径 ==="
python3 - <<'PYEOF'
import os, re
PDK = os.path.expanduser('~/.volare/sky130A')
PDKNG = PDK + '/libs.tech/ngspice'
DEVSPICE = PDK + '/libs.ref/sky130_fd_pr/spice'
inc_re = re.compile(r'^(\s*(?:\.include|\.inc|\.lib)\s+)"([^"]+)"(.*)$')
changed_total = 0
unresolved = []
for root, dirs, files in os.walk(PDKNG):
    for fn in files:
        if not fn.endswith('.spice'): continue
        if fn in ('sky130.lib.spice', 'spinit') or fn.startswith('sky130_fd_pr__model__'):
            continue
        p = os.path.join(root, fn)
        lines = open(p, errors='replace').readlines()
        out, changed = [], False
        for L in lines:
            m = inc_re.match(L)
            if not m:
                out.append(L); continue
            inc = m.group(2)
            if inc.startswith('/'):
                out.append(L); continue
            cand = os.path.normpath(os.path.join(root, inc))
            if os.path.exists(cand):
                out.append(m.group(1) + cand + m.group(3).rstrip('\n') + '\n')
                changed = True; continue
            mm = re.match(r'(?:\.\./)+cells/[^/]+/(.+)', inc)
            if mm and os.path.exists(os.path.join(DEVSPICE, mm.group(1))):
                out.append(m.group(1) + os.path.join(DEVSPICE, mm.group(1)) + m.group(3).rstrip('\n') + '\n')
                changed = True; continue
            unresolved.append((p, inc)); out.append(L)
        if changed:
            open(p, 'w').writelines(out); changed_total += 1
print(f'重写文件数: {changed_total}')
print(f'未解析引用: {len(unresolved)}')
for p, inc in unresolved: print('  UNRESOLVED:', p, '->', inc)
PYEOF
echo
echo "=== 6. 结果 ==="
ls "$PDKNG"
echo "corners: $(ls $PDKNG/corners | tr '\n' ' ')"
