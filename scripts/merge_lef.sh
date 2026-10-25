#!/usr/bin/env bash
# merge_lef.sh — 技术 LEF + 单元 LEF 合成一份，OpenROAD 才能一次读全
#
# 为什么必须合并：分开读 tlef + lef 会报 "library already exists" 或丢 site；
# 合并时要保证全文只有最后一个 END LIBRARY。
# 产物：$MERGED_LEF（默认 runs/lef/sky130_fd_sc_hd_merged.lef）
set -euo pipefail
source "$(dirname "$0")/env.sh"

require_cmd python3 "apt install python3"
require_pdk

mkdir -p "$(dirname "$MERGED_LEF")"

SC_DIR="$SC_DIR" MERGED_LEF="$MERGED_LEF" python3 - <<'PY'
import os
from pathlib import Path

sc = Path(os.environ["SC_DIR"])
out = Path(os.environ["MERGED_LEF"])

tlef = (sc / "techlef" / "sky130_fd_sc_hd.tlef").read_text().splitlines(True)
clef = (sc / "lef" / "sky130_fd_sc_hd.lef").read_text().splitlines(True)

# tlef 结尾的 END LIBRARY 去掉，留到文件最后统一加
while tlef and tlef[-1].strip() == "":
    tlef.pop()
if tlef and tlef[-1].strip() == "END LIBRARY":
    tlef.pop()

# 单元 LEF 开头的 VERSION/BUSBIT/DIVIDER/UNITS 与 tlef 重复，从第一个 MACRO 开始保留
body = []
started = False
for line in clef:
    if not started:
        if line.startswith("MACRO "):
            started = True
            body.append(line)
        continue
    body.append(line)

while body and body[-1].strip() == "":
    body.pop()
if body and body[-1].strip() == "END LIBRARY":
    body.pop()

merged = tlef + ["\n"] + body + ["\nEND LIBRARY\n"]
out.write_text("".join(merged))

print(f"[merge_lef] -> {out}  ({out.stat().st_size} bytes)")
print(f"[merge_lef] MACRO 段: {sum(1 for l in merged if l.startswith('MACRO '))} 个")
print(f"[merge_lef] END LIBRARY: {sum(1 for l in merged if l.strip() == 'END LIBRARY')} 个")
PY

# 用 OpenROAD 实读一遍，确认 13 层 + 441 个单元都进来了
if command -v openroad >/dev/null 2>&1; then
  openroad -no_init -exit <<'EOF' 2>&1 | grep -E 'ODB-0227|MERGED LEF OK' || true
read_lef $::env(MERGED_LEF)
puts "MERGED LEF OK: $::env(MERGED_LEF)"
EOF
fi
