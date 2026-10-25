#!/usr/bin/env python3
"""汇总 EM 报告：按层最大边电流，并对照 sky130 典型 Jmax 数量级"""
import csv, sys
from collections import defaultdict
from pathlib import Path

OUT = Path("/path/to/openlane-lab/runs/14_em")

# sky130 典型最大电流密度（数量级参考，非签核用官方表）
# 来源：公开技术文档常见量级 A/um @ 110C 附近；仅作“是否离谱”判断
JMAX_TYP = {
    "li1": 1.5e-3,
    "met1": 1.0e-3,
    "met2": 1.0e-3,
    "met3": 1.0e-3,
    "met4": 1.0e-3,
    "met5": 1.0e-3,
}

def analyze(path: Path):
    by_layer = defaultdict(float)  # max |I| on that layer edge
    count = 0
    with path.open() as f:
        r = csv.DictReader(f)
        # header: Node0 Layer,...,Current
        for row in r:
            try:
                i = abs(float(row["Current"]))
            except Exception:
                continue
            count += 1
            for k in ("Node0 Layer", "Node1 Layer"):
                lay = row[k]
                if i > by_layer[lay]:
                    by_layer[lay] = i
    return count, by_layer

def main():
    print(f"{'net':6} {'edges':>6} {'layer':6} {'Imax(A)':>12} {'Jtyp(A/um)':>12} {'Imax/I_typ_per_um*0.14':>22}")
    worst_ratio = 0.0
    for net in ("VPWR", "VGND"):
        p = OUT / f"em_{net}.rpt"
        if not p.exists():
            print(f"{net}: missing {p}")
            continue
        n, by_layer = analyze(p)
        for lay, imax in sorted(by_layer.items(), key=lambda x: -x[1]):
            jtyp = JMAX_TYP.get(lay, 1.0e-3)
            # 粗算：假设最小宽 0.14 um，则 I_limit ≈ Jtyp * 0.14
            i_lim = jtyp * 0.14
            ratio = imax / i_lim if i_lim else 0
            worst_ratio = max(worst_ratio, ratio)
            print(f"{net:6} {n:6} {lay:6} {imax:12.3e} {jtyp:12.3e} {ratio:22.3e}")
    print()
    print(f"最坏边电流 / 典型限值(宽0.14um) ≈ {worst_ratio:.3e}")
    if worst_ratio < 0.1:
        print("结论: 远低于典型 EM 限值数量级（教学小电路；非 foundry 签核）")
    elif worst_ratio < 1.0:
        print("结论: 接近但低于典型限值，需对照工艺正式规则")
    else:
        print("结论: 可能超限，需检查电源网/电流假设", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
