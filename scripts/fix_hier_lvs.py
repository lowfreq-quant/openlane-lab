#!/usr/bin/env python3
"""层次提取网表电源归一 + 生成 CDL golden"""
from pathlib import Path
import re

out = Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/17_lvs_device")
src = (out / "counter_hier_ext.spice").read_text()

def fix(n: str) -> str:
    n = n.strip()
    if n in ("VPWR", "VPB") or n.endswith("/VPWR") or n.endswith("/VPB"):
        return "VPWR"
    if n in ("VGND", "VNB", "SUB") or n.endswith("/VGND") or n.endswith("/VNB"):
        return "VGND"
    return n

# 合并 continuation
lines = src.splitlines()
blocks, buf = [], []
for line in lines:
    if line.startswith("+"):
        buf.append(line[1:].strip())
        continue
    if buf:
        blocks[-1] += " " + " ".join(buf)
        buf = []
    blocks.append(line)
if buf:
    blocks[-1] += " " + " ".join(buf)

fixed = []
for b in blocks:
    b = b.strip()
    if not b:
        continue
    if b.lower().startswith(".subckt"):
        toks = b.split()
        name = toks[1]
        # 端口个数必须与实例参数一致，禁止去重
        ports = [fix(p) for p in toks[2:]]
        fixed.append(f".subckt {name} " + " ".join(ports))
    elif b[0] in "XxMm":
        toks = b.split()
        cell = toks[-1]
        nets = [fix(t) for t in toks[1:-1]]
        fixed.append(toks[0] + " " + " ".join(nets) + " " + cell)
    else:
        fixed.append(b)

(out / "counter_hier_ext_fix.spice").write_text("\n".join(fixed) + "\n")
print("fixed extract:", len(fixed), "lines")

# golden
for cand in [
    Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/10_lvs/counter_cts.v"),
    Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/01_synth/counter_synth.v"),
]:
    if cand.exists():
        v = cand.read_text()
        vpath = cand
        break
else:
    raise SystemExit("no netlist")

cdl = Path("/home/ty/.volare/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl").read_text()
subckts = {}
for m in re.finditer(r"\.SUBCKT\s+(\S+)\s+(.+)", cdl, re.I):
    subckts[m.group(1)] = m.group(2).split()

inst_re = re.compile(r"(sky130_fd_sc_hd__[a-z0-9_]+)\s+(\S+)\s*\((.*?)\);", re.S)
pin_re = re.compile(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)")
insts = []
for cell, name, conns in inst_re.findall(v):
    pinmap = {a: b.replace(" ", "") for a, b in pin_re.findall(conns)}
    insts.append((cell, name, pinmap))

m = re.search(r"module\s+counter\s*\((.*?)\);", v, re.S)
ports = [p.strip() for p in m.group(1).replace("\n", " ").split(",") if p.strip()]

lines = ["* hier LVS golden", cdl, ".subckt counter " + " ".join(ports)]
for cell, name, pinmap in insts:
    pins = subckts.get(cell)
    if not pins:
        print("skip", cell)
        continue
    conns = []
    for p in pins:
        if p in ("VPWR", "VPB"):
            conns.append("VPWR")
        elif p in ("VGND", "VNB", "SUB"):
            conns.append("VGND")
        else:
            val = pinmap.get(p) or pinmap.get(p.lower()) or pinmap.get(p.upper())
            conns.append(val if val else f"UNCONN_{p}")
    lines.append(f"X{name} " + " ".join(conns) + f" {cell}")
lines.append(".ends counter")
(out / "counter_hier_golden.spice").write_text("\n".join(lines) + "\n")
print("golden insts", len(insts), "from", vpath)
