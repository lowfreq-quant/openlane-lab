#!/usr/bin/env python3
"""make_golden.py — 生成 LVS 金标准 SPICE

来源：post-CTS 网表（OpenROAD write_verilog）+ sky130 CDL 单元库。
把每个单元的 Verilog 连接按 CDL 的引脚顺序展开，电源脚统一成全局网
VPWR / VGND / VPB / VNB，再交给 netgen 与版图提取网表比对。

用法：
    python3 scripts/make_golden.py            # 默认读 runs/10_lvs/counter_cts.v
    python3 scripts/make_golden.py SRC.v OUT.spice
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ.get("ROOT") or Path(__file__).resolve().parents[1])
LVS_DIR = ROOT / "runs" / "10_lvs"
POWER = ("VGND", "VNB", "VPB", "VPWR")


def cdl_path() -> Path:
    sc = os.environ.get("SC_DIR")
    if sc:
        return Path(sc) / "cdl" / "sky130_fd_sc_hd.cdl"
    return Path(os.environ.get("PDK_ROOT", Path.home() / ".volare")) / "sky130A" / \
        "libs.ref" / "sky130_fd_sc_hd" / "cdl" / "sky130_fd_sc_hd.cdl"


def expand_ports(verilog: str) -> list[str]:
    """module counter (clk, rst_n, q, tick) → 把总线 q 展开成 q[7]..q[0]"""
    head = re.search(r"module\s+counter\s*\((.*?)\)\s*;", verilog, re.S)
    if not head:
        raise SystemExit("找不到 module counter (...) 端口表")
    names = [p.strip() for p in head.group(1).replace("\n", " ").split(",") if p.strip()]

    ranges = {}
    for m in re.finditer(r"\b(?:input|output|inout)\b[^;]*?\[\s*(\d+)\s*:\s*(\d+)\s*\]\s*([A-Za-z_]\w*)", verilog):
        msb, lsb, name = int(m.group(1)), int(m.group(2)), m.group(3)
        ranges[name] = (max(msb, lsb), min(msb, lsb))

    ports = []
    for n in names:
        if n in ranges:
            hi, lo = ranges[n]
            ports.extend(f"{n}[{i}]" for i in range(hi, lo - 1, -1))
        else:
            ports.append(n)
    return ports


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else LVS_DIR / "counter_cts.v"
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else LVS_DIR / "counter_golden.spice"

    if not src.is_file():
        print(f"[ERROR] 找不到 post-CTS 网表 {src}", file=sys.stderr)
        print("        先跑 bash scripts/dump_cts_netlist.sh", file=sys.stderr)
        return 1
    cdl = cdl_path()
    if not cdl.is_file():
        print(f"[ERROR] 找不到 CDL {cdl}", file=sys.stderr)
        return 1

    verilog = src.read_text()
    cdl_text = cdl.read_text()

    # CDL 里每个单元的引脚顺序
    subckts = {}
    for m in re.finditer(r"\.SUBCKT\s+(\S+)\s+(.+)", cdl_text, re.I):
        subckts[m.group(1)] = m.group(2).split()

    # Verilog 实例：sky130_fd_sc_hd__xxx _id_ ( .PIN(net), ... );
    inst_re = re.compile(r"(sky130_fd_sc_hd__[a-z0-9_]+)\s+(\S+)\s*\((.*?)\);", re.S)
    pin_re = re.compile(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)")
    insts = []
    for cell, name, conns in inst_re.findall(verilog):
        pinmap = {a: b.replace(" ", "") for a, b in pin_re.findall(conns)}
        insts.append((cell, name, pinmap))

    ports = expand_ports(verilog)
    lines = ["* LVS golden: post-CTS netlist + sky130 CDL", cdl_text,
             ".subckt counter " + " ".join(ports)]

    missing = 0
    for cell, name, pinmap in insts:
        pins = subckts.get(cell)
        if not pins:
            print(f"[WARN] CDL 里没有 {cell}", file=sys.stderr)
            missing += 1
            continue
        conns = []
        for p in pins:
            if p in POWER:
                conns.append(p)
            else:
                val = pinmap.get(p) or pinmap.get(p.lower()) or pinmap.get(p.upper())
                conns.append(val if val else f"UNCONN_{p}")
        lines.append(f"X{name} " + " ".join(conns) + f" {cell}")
    lines.append(".ends counter")

    dst.write_text("\n".join(lines) + "\n")
    print(f"[make_golden] {src.name} -> {dst.name}：{len(insts)} 个实例，"
          f"{len(ports)} 个顶层端口，缺 CDL 定义 {missing} 个")
    return 0


if __name__ == "__main__":
    sys.exit(main())
