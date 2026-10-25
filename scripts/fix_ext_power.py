#!/usr/bin/env python3
"""把 Magic 提取网表里的零散电源脚并成全局网 VPWR/VGND/VPB/VNB

Magic 从 LEF 抽象提取时，每个实例的电源脚是独立的路径名（如 _28_/VPWR），
不会自动短接到全局电源网；LVS 前必须合并，否则会报一堆多余网。
"""
import os
import sys
from pathlib import Path

ROOT = Path(os.environ.get("ROOT") or Path(__file__).resolve().parents[1])
LVS_DIR = ROOT / "runs" / "10_lvs"


def main() -> int:
    src = Path(os.environ.get("EXT_IN", LVS_DIR / "counter_ext_cell.spice"))
    dst = Path(os.environ.get("EXT_OUT", LVS_DIR / "counter_ext_fix.spice"))

    if not src.is_file():
        print(f"[ERROR] 找不到提取网表 {src}", file=sys.stderr)
        print("        先跑 bash scripts/run_lvs_cell.sh", file=sys.stderr)
        return 1

    power_map = {"VPWR": "VPWR", "VGND": "VGND", "VPB": "VPB", "VNB": "VNB", "SUB": "VNB"}

    def fix_net(n: str) -> str:
        n = n.strip()
        if n in power_map:
            return power_map[n]
        if n.endswith("/VPWR"):
            return "VPWR"
        if n.endswith("/VGND"):
            return "VGND"
        if n.endswith("/VPB"):
            return "VPB"
        if n.endswith("/VNB"):
            return "VNB"
        return n

    # 以 '+' 续行的语句先拼成一条
    blocks, buf = [], []
    for line in src.read_text().splitlines():
        if line.startswith("+"):
            buf.append(line)
            continue
        if buf:
            blocks.append("\n".join(buf))
            buf = []
        buf.append(line)
    if buf:
        blocks.append("\n".join(buf))

    fixed = []
    for block in blocks:
        if block.startswith(".subckt counter"):
            parts = block.split()
            # parts = ['.subckt', 'counter', port1, port2, ...]
            ports = [fix_net(p) for p in parts[2:]]
            seen, uniq = set(), []
            for p in ports:
                if p not in seen:
                    seen.add(p)
                    uniq.append(p)
            fixed.append(".subckt counter " + " ".join(uniq))
        elif block[:1] in ("X", "x"):
            toks = block.replace("\n+", " ").replace("\n", " ").split()
            cell, nets = toks[-1], [fix_net(t) for t in toks[1:-1]]
            fixed.append(toks[0] + " " + " ".join(nets) + " " + cell)
        else:
            fixed.append(block.replace("\n+", " +"))

    dst.write_text("\n".join(fixed) + "\n")
    xs = [b for b in fixed if b[:1] in ("X", "x")]
    print(f"[fix_ext_power] {src.name} -> {dst.name}：{len(fixed)} 条语句，{len(xs)} 个实例")
    return 0


if __name__ == "__main__":
    sys.exit(main())
