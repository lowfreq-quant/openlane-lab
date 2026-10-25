#!/usr/bin/env python3
"""对齐文档中的过时数字（40um die / 125 MHz 签核结果）"""
from pathlib import Path

ROOT = Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab")

REPLACEMENTS = [
    # 频率 / 周期
    ("STA @10 MHz", "STA @125 MHz"),
    ("10 MHz 下 setup+hold", "125 MHz（SDC 8 ns）下 setup+hold"),
    ("10 MHz 下 tt/ff/ss 全 MET", "125 MHz 下 tt/ff/ss 全 MET"),
    ("MET @10 MHz", "MET @125 MHz"),
    ("## 多 corner 结果（10 MHz，真实 SDC）", "## 多 corner 结果（125 MHz，真实 SDC）"),
    ("constraints/counter.sdc    10 MHz 约束", "constraints/counter.sdc    125 MHz（8 ns）约束"),
    ("（100 ns 周期）", "（8 ns / 125 MHz）"),
    ("100 ns 时钟下", "8 ns 时钟下"),
    ("- 10 MHz 下看 setup+hold", "- 125 MHz 下看 setup+hold"),
    ("**10 MHz / 7% 利用率**", "**125 MHz / 27% 逻辑利用率**"),
    ("6. **die 100×100，利用率 7%。** 靠 93 个 tap 和 730 个 fill 撑着，面积数字不代表真实设计。",
     "6. **die 40×40，逻辑利用率 27%**（含 decap 后 site 铺满）；decap 451 + fill。"),
    # IR
    ("IR drop 最差 **15.5 mV（0.86%）**", "IR drop VPWR **28 mV（1.6%）** / VGND **74 mV（4.1%）**"),
    ("IR 0.86%", "IR 约 1.6%/4.1%"),
    ("最差压降 15.5 mV / 0.86%", "压降 VPWR 28 mV/1.6%、VGND 74 mV/4.1%"),
    ("15.5 mV / 0.86%", "VPWR 28 mV/1.6%、VGND 74 mV/4.1%"),
    ("**15.5 mV / 0.86%**（via 电阻 5 Ω 假设）", "**VPWR 28 mV/1.6%、VGND 74 mV/4.1%**（via 电阻 5 Ω 假设）"),
    # density / decap
    ("`density_fill`（金属密度）没做——5% 利用率下 IR 只有 0.86%，没有 decap 需求。",
     "decap 与 `density_fill` **已做**（见 make density / 05_route.sh）。"),
    ("8. **没有 decap / 金属填充**：fill cell 有了；decap 和 `density_fill` 没做（IR 0.86%，暂无需求）。",
     "8. **decap / 密度填充已做**；金属 fill 约 4900（小 die）。"),
    ("ss 的 setup 最紧（94.61 ns slack）、ff 的 hold 最紧（0.05 ns）；拉到 1 ns 时 ss −2.88、tt −0.27，ff 仍 MET",
     "ss setup 最紧（slack≈2.6 ns）；1 ns 压力 ss −3.0、tt −0.3，ff 仍 MET"),
    ("（~1 GHz 开始违例）", "（tt 极限约 667 MHz）"),
]

FILES = ["README.md", "docs/verification.md", "docs/flow-notes.md", "docs/first-run-report.md"]

for rel in FILES:
    p = ROOT / rel
    if not p.exists():
        print("skip", rel)
        continue
    text = p.read_text()
    orig = text
    for a, b in REPLACEMENTS:
        text = text.replace(a, b)
    if text != orig:
        p.write_text(text)
        print("updated", rel)
    else:
        print("no change", rel)
