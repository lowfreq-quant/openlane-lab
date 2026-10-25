# openlane-lab 交接文档

> SkyWater SKY130 数字后端全流程实验工程
> **状态：RTL → GDS + DRC + LVS + 形式等价 全部通过，仓库已整理为可公开状态**
> 更新：2026-10-25

---

## 1. 这是什么

在 **WSL2 Ubuntu（无 Docker）** 上，用开源 EDA 手动走完：

```
RTL → 综合 → Floorplan → Place → CTS → Route → STA → GDS → DRC → LVS
     ↘ 功能仿真 / 门级仿真 / 形式等价 / 变异测试 / 时钟扫描
```

目标不是"一键流片"，而是**每一步命令可见、结果可解释、判据可核对**。

公开仓库 https://github.com/<你的账号>/openlane-lab（推送后替换）。

---

## 2. 环境与工具

### 2.1 系统

| 项 | 值 |
|----|-----|
| 宿主 | Windows 10/11 |
| 发行版 | WSL2 Ubuntu 24.04 |
| 工程路径 | 任意；脚本用 `$(dirname "$0")/..` 推导根目录，**不再写死** |
| PDK 路径 | `~/.volare/sky130A`（可用 `PDK_ROOT` 覆盖） |

### 2.2 版本（实测）

| 工具 | 版本 | 来源 | 用途 |
|------|------|------|------|
| yosys | 0.33 | apt | 综合、形式等价 |
| iverilog | 12.0 | apt | RTL / 门级仿真 |
| openroad | 26Q2 | Nix `nixpkgs.openroad` | 布图/布局/CTS/布线/STA |
| magic | 8.3.681 | Nix `nixpkgs.magic-vlsi` | DEF+LEF 提取（apex apt 版 8.3.105 太旧） |
| klayout | 0.28.16 | apt | GDS 合成 / DRC / 几何导出 |
| netgen-lvs | 1.5.133 | apt `netgen-lvs` | LVS 比对 |
| volare | 0.20.6 | pip venv | PDK 管理 |
| python | 3.12 | apt | 辅助脚本 + PIL 渲染 |

安装细节见 [`docs/tools.md`](docs/tools.md)。

### 2.3 PDK

```bash
export PDK_ROOT=$HOME/.volare
export PDK=sky130A
# volare 版本（open_pdks 构建）：7519dfb04400f224f140749cda44ee7de6f5e095
# 单元库：sky130_fd_sc_hd
```

关键路径（`scripts/env.sh` 已统一导出）：

```
$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef
$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl
$PDK_ROOT/sky130A/libs.tech/klayout/sky130A.lydrc
$PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl
```

### 2.4 自检

```bash
bash scripts/check_env.sh    # 工具 / PDK 七个文件 / 工程产物，逐条 OK 或 MISS
```

---

## 3. 方法流（逐步）

所有命令在仓库根目录执行（不再需要 `cd /mnt/c/...`）：

```bash
bash scripts/merge_lef.sh          # 0. 合并 LEF（每个 checkout 一次）
bash scripts/01_synth.sh           # 1. 综合
bash scripts/02_floorplan.sh       # 2. 布图
bash scripts/03_place.sh           # 3. 布局
bash scripts/04_cts.sh             # 4. 时钟树
bash scripts/05_route.sh           # 5. 布线
bash scripts/06_signoff.sh         # 6. STA
bash scripts/run_gds_drc.sh        # 7+8. GDS 合成 + DRC
bash scripts/dump_cts_netlist.sh   # 9a. post-CTS 网表（LVS 金标准）
bash scripts/lvs_extract.sh        # 9b. Magic 提取版图网表
bash scripts/run_lvs.sh            # 9c. netgen 比对
```

| 步骤 | 输入 | 输出 | 判据（脚本会自己检查） |
|------|------|------|------------------------|
| 0 合并 LEF | tlef + lef | `runs/lef/*.lef` | 13 layers + 441 cells |
| 1 综合 | `rtl/counter.v` | `runs/01_synth/counter_synth.v` | 23 cells，面积 299 µm² |
| 2 布图 + tap + PDN | 网表 + SDC | `runs/02_floorplan/floorplan.def` | die 100×100，93 tapcells，`SPECIALNETS=2`，否则退出 1 |
| 3 布局 | floorplan.odb | `runs/03_place/place.def` | 0 重叠，HPWL 514.9 µm |
| 4 CTS | place.odb | `runs/04_cts/cts.def` | 插入 clkbuf，skew 0.25 ns |
| 5 布线 | cts.odb | `runs/05_route/route.def` | violations = 0 → 否则脚本退出 1 |
| 6 签核 | route.odb | `runs/06_signoff/sta.log`、`pdn_check.log` | WNS/TNS = 0；2/2 网连通；IR 0.56% → 否则退出 1 |
| 7 GDS | route.def | `runs/09_gds/counter.gds` | 单 top `counter` |
| 8 DRC | GDS | `runs/09_gds/drc.lyrdb` | `<item>` = 0 → 否则脚本退出 1 |
| 9 LVS | ext + golden | `runs/10_lvs/lvs.out` | `Netlists match uniquely` → 否则退出 1 |

`make all` = 1–6。

---

## 4. 脚本手册

### 4.1 后端主流程

| 脚本 | 说明 |
|------|------|
| `scripts/env.sh` | **唯一环境入口**：ROOT、PATH、PDK 路径、MERGED_LEF；被所有脚本 source |
| `scripts/merge_lef.sh` | tlef + lef 合成一份；去掉重复 `END LIBRARY`，从第一个 `MACRO` 起保留单元段 |
| `scripts/01_synth.sh` | yosys：`techmap → dfflibmap → abc`；没 PDK 时退化 generic |
| `scripts/02_floorplan.sh` | `initialize_floorplan` + `make_tracks` + `place_pins` + **tapcell**（93 个，间距 13 µm）+ **PDN**（`add_global_connection` → `pdngen`：met1 跟随轨 + met4/met5 主干） |
| `scripts/03_place.sh` | `global_placement -density 0.55` + `detailed_placement` |
| `scripts/04_cts.sh` | `clock_tree_synthesis -buf_list {buf_1 buf_2}` + 重新合法化 |
| `scripts/05_route.sh` | `global_route` + `detailed_route`，末尾检查 violations=0 |
| `scripts/06_signoff.sh` | STA（setup/hold/wns/tns/area）+ PDN 连通性（`check_power_grid`）+ IR drop（`analyze_power_grid`，via 电阻按 5 Ω 假设） |
| `scripts/common.tcl` | OpenROAD 公共初始化：读合并 LEF + liberty |

### 4.2 验证（不需要 PDK）

| 脚本 | 说明 | 期望 |
|------|------|------|
| `scripts/run_sim.sh` | RTL + 门级仿真 | 两行 `PASS` |
| `scripts/run_equiv.sh` | yosys 等价（`async2sync` + `equiv_*`） | `Equivalence successfully proven!` |
| `scripts/run_mutation.sh` | 3 个注入 bug + 对照 | 3 抓到 + 1 通过，否则退出 1 |
| `scripts/run_timing_sweep.sh` | 周期 100→0.5 ns 扫 STA | ≥2 ns MET；1 ns 起违例 |

支撑文件：`sim/counter_tb.v`（自检 testbench）、`sim/counter_bug.v`（`BUG_RESET`/`BUG_STEP`/`BUG_TICK`）、`sim/sky130_hd_min.v`（10 个单元功能模型）。

### 4.3 GDS / DRC / LVS

| 脚本 | 作用 |
|------|------|
| `scripts/run_gds_drc.sh` | KLayout 合成 GDS + 跑 `sky130A.lydrc`，检查 marker 数 |
| `scripts/make_gds.py` | DEF + 单元 GDS → flatten 成单 top GDS |
| `scripts/dump_cts_netlist.sh` | cts.odb → `counter_cts.v`（金标准） |
| `scripts/lvs_extract.sh` | Magic 读 DEF+LEF 做单元级提取 → `counter_ext_cell.spice` |
| `scripts/make_golden.py` | post-CTS 网表 + CDL 引脚顺序 → `counter_golden.spice`（总线自动展开） |
| `scripts/fix_ext_power.py` | 把 `_28_/VPWR` 这类零散电源脚并成全局网 |
| `scripts/run_lvs.sh` | 串起 golden → fix power → netgen，判定 match uniquely |
| `scripts/lvs_extra.tcl` | netgen 附加规则：电源全局、忽略 fill/tap |

顺序不能换：`dump_cts_netlist.sh` → `lvs_extract.sh` → `run_lvs.sh`。

### 4.4 版图可视化

| 脚本 | 说明 |
|------|------|
| `scripts/dump_shapes.py` | KLayout 导出 `shapes.json`（逐层多边形） |
| `scripts/render_from_json.py` | PIL 分 14 组画 PNG → `runs/11_layout_png/` |

### 4.5 环境 / PDK

| 脚本 | 说明 |
|------|------|
| `scripts/fetch_pdk.sh` | volare 拉 sky130（可传版本号） |
| `scripts/install_openroad_nix.sh` | 装 Nix + OpenROAD |
| `scripts/check_env.sh` | 自检 |

### 4.6 legacy/

`scripts/legacy/` 只放**没走通的路径**，附 `README.md` 说明为什么放弃：

* `run_gds.sh` — OpenROAD 26Q2 没有 `write_gds`（`invalid command name`）
* `run_gds_magic.sh` — Magic 读 4 MB 单元库 GDS 段错误

---

## 5. 设计说明

**`rtl/counter.v`**：8-bit 自由跑计数器

| 端口 | 方向 | 说明 |
|------|------|------|
| `clk` | in | 时钟（SDC：100 ns = 10 MHz） |
| `rst_n` | in | 低有效**异步**复位（文件头注释写"同步"，以代码为准） |
| `q[7:0]` | out | 计数值 |
| `tick` | out | `q==0xFF` 时为 1 |

综合结果：8×`dfrtp_1` + 组合门 = 23 cells，299 µm²。CTS 后 26 cells（+3 clock buffer），面积 310 µm²。

约束见 `constraints/counter.sdc`。

---

## 6. 验证结论（2026-10-25 重跑）

| 层级 | 结果 | 证据 |
|------|------|------|
| RTL 功能仿真 | PASS（256 步） | `sim/out/rtl_sim.log` |
| 门级仿真 | PASS | `sim/out/gate_sim.log` |
| 形式等价 | 9/9 proven | `runs/07_equiv/equiv.log` |
| 变异测试 | 3/3 抓到 + 对照 OK | `sim/out/mutation_summary.txt` |
| STA @10 MHz | WNS/TNS = 0 | `runs/06_signoff/sta.log` |
| 时钟扫描 | 2 ns MET；1 ns WNS=-0.13；0.5 ns -0.63 | `runs/08_timing_sweep/sta_*.log` |
| 布图 | 93 tapcells；`SPECIALNETS=2`，met1 轨 30 条 + met4/met5 主干各 6 条 | `runs/02_floorplan/floorplan.def` |
| 布线 | violations = 0，信号线长 622 µm，via 187 | `runs/05_route/openroad.log` |
| 电源 | **2/2 电源网连通**；IR drop 最差 10.1 mV / 0.56% | `runs/06_signoff/pdn_check.log` |
| GDS | 单 top `counter`，约 520 KB（met1–met5 + via） | `runs/09_gds/klayout_gds.log` |
| DRC | **0 违例**（166 类规则） | `runs/09_gds/drc.lyrdb` |
| LVS | **match uniquely**（26 devices / 30 nets，阱并进电源） | `runs/10_lvs/lvs.out` |

---

## 7. 踩过的坑（必读）

1. **合并 LEF**：OpenROAD 分开读 tlef+lef 会 `library already exists` 或丢 site；必须合成一份，
   且全文只有一个 `END LIBRARY`。
2. **`initialize_floorplan -site unithd`**：sky130_fd_sc_hd 的行高 site 叫 `unithd`；
   要先 `make_tracks` 才能 `place_pins`。
3. **Yosys 0.33 没有 `write_liberty`**；综合前必须 `techmap`，否则 `$add`/`$adff` 映射不到单元。
4. **门级仿真**：整库 sky130 verilog 与 Icarus 预处理器不兼容 → 用 `sim/sky130_hd_min.v`。
   `lpflow_isobufsrc_1` 在 `SLEEP=1` 时输出 0，模型要照实写。
5. **形式等价**：异步 FF 要 `async2sync`，否则 SAT 证不动。
6. **LVS 金标准是 post-CTS 网表**，不是综合网表（CTS 插了 3 个 buffer）。
7. **Magic 提取后电源脚是散的**（`_28_/VPWR`），必须 `fix_ext_power.py` 合并，否则报一堆多余网。
8. **`netgen` 是 3D 网格生成器**；LVS 用 `netgen-lvs`。
9. **Magic 版本**：sky130 techfile 要求 ≥8.3.260；apt 只有 8.3.105 → Nix `magic-vlsi` 8.3.681。
10. **KLayout `LayoutView.save_image`** 在 batch 下常出空图 → `dump_shapes.py` + PIL 自己画。
11. **OpenROAD 26Q2 没有 `write_gds`**；`legalize_placement` 已并入 `detailed_placement`；
    `report_checks -fields nets` 会报 `unknown field`（用 `{slew capacitance}` 就好）。
12. **路径不要写死**：早期脚本 `cd /path/to/...`，换机器就废；现在统一 `source env.sh`。
13. **`/tmp` 放合并 LEF 会和别的 checkout 抢**；现在放 `runs/lef/`。
14. **PowerShell 调 WSL 管道/引号极易踩坑**；长脚本写进 `.sh` 再执行。
15. **KLayout 读 DEF 时层号是它自己编的**：LEF 里没有 GDS 层号，met1 会落到 `5/0`、
    met2 落到 `7/0`……跟 sky130 的 `68/20`、`69/20` 对不上。结果 GDS 里**单元图形是对的、
    绕线全在假层上**，DRC 扫不到线，会安静地报"0 违例"。`make_gds.py` 现在按层名映射
    （`LAYER_MAP`），`run_gds_drc.sh` 一看到 `WARN` 就失败，避免再悄悄产出半个 GDS。
16. **PDN 顺序不能错**：先 `add_global_connection` + `global_connect`，再 `define_pdn_grid` / `pdngen`；
    否则单元电源脚没连上，网格是空壳。`define_pdn_grid` 加 `-pins {met5}` 才会生成顶层电源端子，
    没有端子 `check_power_grid` 会报 `PSM-0025 does not contain any terminals`。
17. **IR drop 默认算不了**：sky130 的 LEF 只有层电阻（`RESISTANCE RPERSQ`），**没有 via 电阻**，
    `analyze_power_grid` 直接报 `PSM-0021 Resistance map contains invalid values`。
    先 `set_layer_rc -via via -resistance 5.0`（每个 via 类型都要设）就能跑；本 lab 的压降数字
    建立在这个 5 Ω 假设上，只能看数量级。
18. **插了 tap cell，LVS 会多出一条孤立 VPB 网**：tap 把 nwell 短到 VPWR、pwell 短到 VGND，
    版图侧阱被并走，而金标准还把 VPB/VNB 当独立网 → `Netlists do not match`。
    做法是两侧都按 tap 约定归一（`make_golden.py` / `fix_ext_power.py` 里 VPB→VPWR、VNB→VGND），
    并在 `lvs_extra.tcl` 里只声明 VPWR/VGND 为全局网。
19. **tap cell 要在 PDN 之前插**，且 `add_global_connection` 要放在 tapcell 之后，
    否则新插的 tap 电源脚接不上网格。

---

## 8. 目录结构

```
openlane-lab/
├── README.md              对外说明（含来源与局限）
├── HANDOFF.md             本文件（交接总览）
├── LICENSE                MIT（代码）；GDS 按 Apache-2.0
├── Makefile               all / verify / gds / lvs / png / check / clean
├── .github/workflows/     smoke CI（RTL 仿真 + 等价 + 变异）
├── rtl/counter.v
├── constraints/counter.sdc
├── sim/                   testbench / 变异版本 / 单元功能模型
├── scripts/
│   ├── env.sh             唯一环境入口
│   ├── 01..06_*.sh        后端主流程
│   ├── run_{sim,equiv,mutation,timing_sweep}.sh
│   ├── run_gds_drc.sh / make_gds.py
│   ├── dump_cts_netlist.sh / lvs_extract.sh / run_lvs.sh / make_golden.py / fix_ext_power.py
│   ├── dump_shapes.py / render_from_json.py
│   ├── check_env.sh / fetch_pdk.sh / install_openroad_nix.sh
│   └── legacy/            历史失败路径
├── docs/
│   ├── tools.md           工具安装与版本
│   ├── flow-notes.md      每阶段的直觉与检查点
│   ├── verification.md    验证证据链
│   ├── first-run-report.md 首跑记录
│   └── img/               版图截图（README 用）
└── runs/
    ├── lef/               合并 LEF（不入库）
    ├── 01_synth … 06_signoff
    ├── 07_equiv/ 08_timing_sweep/
    ├── 09_gds/            counter.gds + drc.lyrdb
    ├── 10_lvs/            ext / golden / lvs.out
    └── 11_layout_png/     分层渲染（不入库，精选图在 docs/img）
```

---

## 9. 快速复现

```bash
git clone <repo> && cd openlane-lab

bash scripts/check_env.sh          # 缺什么一目了然
bash scripts/fetch_pdk.sh          # 首次
bash scripts/merge_lef.sh
make all                           # 01–06
bash scripts/run_gds_drc.sh        # GDS + DRC
bash scripts/dump_cts_netlist.sh && bash scripts/lvs_extract.sh && bash scripts/run_lvs.sh
bash scripts/run_sim.sh && bash scripts/run_equiv.sh && bash scripts/run_mutation.sh
```

成功标志：`PASS` ×4、`Equivalence successfully proven!`、`[PASS] DRC 0 违例`、
`[PASS] LVS: Netlists match uniquely`。

---

## 10. 已知局限

1. **IR drop 是估计值**：PDN 真实存在、连通性已验证；`analyze_power_grid` 能跑，
   但 via 电阻是按 5 Ω 假设灌进去的（LEF 只带层电阻），所以 10.1 mV / 0.56% 只能看数量级。
2. **LVS 是 LEF 抽象级**：Magic 用 LEF abstract 提取，比的是实例+连接，不是晶体管级版图；
   阱（VPB/VNB）按 tap 约定并进电源，不逐阱检查。
3. **没有真实寄生**：只有 `estimate_parasitics -global_routing`，无 SPEF、无后仿。
4. **10 MHz + 7% 利用率**：时序与面积数字没有工程意义，只是跑通流程。
5. **单元功能模型手写**：`sim/sky130_hd_min.v` 只覆盖用到的 10 个 cell。
6. **没有 decap / filler**：tap 有了，去耦电容和填充单元没插。

要往"真设计"走，按这个顺序补：decap/filler → SPEF/后仿 → 用真实 RC 出 IR → 换 UART/SPI → 缩 die 提频率。

---

## 11. 来源

* 本仓库从零编写，**不是 fork**。
* PDK：`google/skywater-pdk`（Apache-2.0），经 `efabless/volare` 安装预编译版。
  当时下载的 PDK 源码快照（`skywater-pdk-main.zip`）**没有进仓库**。
* 工具链：OpenROAD / Magic / Yosys / KLayout / Netgen / Icarus，均为系统安装，仓库不含二进制。
* 概念参考：`efabless/openlane`（Apache-2.0），未复用代码。

---

## 12. 交接清单

- [x] 环境：WSL + Nix OpenROAD/Magic + volare sky130
- [x] 主流程 01–06 可重复执行，脚本自带判据
- [x] 验证：仿真 / 门级 / 等价 / 变异 / STA / 时钟扫描
- [x] GDS + DRC(0) + LVS(match uniquely)
- [x] PDN：met1 跟随轨 + met4/met5 主干，`check_power_grid` 2/2 连通
- [x] tap cell：93 个，间距 13 µm，阱按 tap 约定并进电源
- [x] IR drop：最差 10.1 mV / 0.56%（via 电阻 5 Ω 假设）
- [x] 路径去硬编码，clone 到任意目录可跑
- [x] 仓库整理：`.gitignore` / `LICENSE` / legacy 归档 / CI
- [x] 文档：README / HANDOFF / tools / flow-notes / verification / first-run-report
- [ ] 用真实 RC（而非假设的 via 电阻）重算 IR / EM
- [ ] 后仿 / SPEF（未做）
- [ ] decap / filler（未做）
- [ ] 更大设计 UART/SPI（未做）

有问题先查 §7 坑列表；脚本细节见 §4；验证结论见 §6。
