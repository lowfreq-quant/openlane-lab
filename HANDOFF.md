# openlane-lab 交接文档

> SkyWater SKY130 数字后端全流程实验工程
> **状态：RTL→GDS→DRC(0)→LVS→PDN→IR→EM→SPEF→OCV→后仿→密度填充→decap→P7 工程化 die/频率**
> 更新：2026-10-25（P6 拓扑结论 + P7 缩 die/提频）

---

## 0. 进展纪要（做过什么）

按时间顺序，每一轮都留了 commit 和可核对的产物：

| 轮次 | 做了什么 | 关键结果 |
|------|----------|----------|
| 1 | 建仓：RTL→综合→布图→布局→CTS→布线→STA，GDS/DRC/LVS 脚本化 | 23 cells / 299 µm²，DRC 0/166，LVS match |
| 2 | 工程化：去硬编码路径、`.gitignore` / `.gitattributes` / `LICENSE` / CI、日志脱敏 | clone 到任意目录可跑；CI 4 次全绿 |
| 3 | **PDN**：`add_global_connection` → `pdngen`，met1 跟随轨 + met4/met5 主干 | `SPECIALNETS=2`，2/2 电源网连通 |
| 4 | **tap cell** + **IR drop**：93 个 tap、`analyze_power_grid` | 面积 415 µm²（7%）；IR 15.5 mV / 0.86% |
| 5 | **天线检查** + **填充单元** + **SDF 后仿** | 天线 0/0；730 fill；后仿 PASS |
| 6 | **多 corner STA**（tt/ff/ss） + 修正 STA 寄生重估 | 10 MHz 三角全 MET；ss 先挂 setup、ff 先挂 hold |
| 7 | **OpenRCX 真寄生 → SPEF**：`rcx_rules.info` + `extract_parasitics` + `write_spef` | 434 根线 100% 提取；0 unannotated；1 ns 压力 WNS 估算 -0.27 vs SPEF **-0.34** |
| 8 | **EM 分析**：`analyze_power_grid -enable_em` + 边电流汇总 | VPWR Imax=3.9 µA / VGND 2.7 µA；约典型 Jmax 的 **2.8%**（宽 0.14 µm 粗算） |
| 9 | **P1 收尾**：corners / signoff / postsim 全面 `read_spef` | 1 ns tt WNS 估算 -0.27 → SPEF **-0.34**；SDF 后仿 PASS |
| 10 | **金属密度填充**：官方 `fill.json` schema + `density_fill` | **22085** 个 fill（met1–met5）；rules 见 `scripts/sky130_density_fill.json` |
| 11 | **decap**：`filler_placement` 加入 decap_3/4/6/8/12 | **451 decap + 56 fill** = 507 filler；利用率 99% |
| 12 | **OCV + 8 corner**：`set_timing_derate` + 8 套 liberty | tt/ss × 电压温度全 **MET**（10 MHz） |
| 13 | **晶体管级 LVS**：GDS→Magic 提取 vs CDL | 器件 **346=346**、网络 **177=177**；拓扑残差见 `docs/p6-topology.md` |
| 14 | **P7 缩 die / 提频** + 全流程重跑 | die **40×40**，利用率 **27%**（逻辑）/99%（含 decap）；SDC **8 ns (125 MHz)**；tt 极限 **667 MHz**；ss 在 5 ns 会挂（−0.55），6 ns 起 MET |

当前 HEAD 的完整验证链见 §6，未完成项与原因见 §10，下一步见 §11。

---

## 1. 这是什么

在 **WSL2 Ubuntu（无 Docker、无 OpenLane）** 上，用开源 EDA 手动走完：

```
RTL → 综合 → Floorplan(+tap+PDN) → Place → CTS → Route(+天线+填充)
    → STA(多 corner) → GDS → DRC → LVS → SDF 后仿
    ↘ 功能仿真 / 门级仿真 / 形式等价 / 变异测试 / 时钟扫描 / IR drop
```

目标不是"一键流片"，而是**每一步命令可见、结果可解释、判据可核对**。

公开仓库：https://github.com/lowfreq-quant/openlane-lab

---

## 2. 环境与工具

### 2.1 系统

| 项 | 值 |
|----|-----|
| 宿主 | Windows 10/11 + WSL2 Ubuntu 24.04 |
| 工程路径 | 任意；脚本用 `$(dirname "$0")/..` 推导根目录 |
| PDK 路径 | `~/.volare/sky130A`（可用 `PDK_ROOT` 覆盖） |

### 2.2 版本（实测）

| 工具 | 版本 | 来源 | 用途 |
|------|------|------|------|
| yosys | 0.33 | apt | 综合、形式等价 |
| iverilog | 12.0 | apt | RTL / 门级 / SDF 后仿 |
| openroad | 26Q2 | Nix `nixpkgs.openroad` | 布图/布局/CTS/布线/STA/PDN/PSM |
| magic | 8.3.681 | Nix `nixpkgs.magic-vlsi` | DEF+LEF 提取（LVS 版图侧） |
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
# 单元库：sky130_fd_sc_hd（tt/ff/ss 三套 liberty 都在）
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

所有命令在仓库根目录执行：

```bash
bash scripts/merge_lef.sh          # 0. 合并 LEF（每个 checkout 一次）
bash scripts/01_synth.sh           # 1. 综合
bash scripts/02_floorplan.sh       # 2. 布图 + tap + PDN
bash scripts/03_place.sh           # 3. 布局
bash scripts/04_cts.sh             # 4. 时钟树
bash scripts/05_route.sh           # 5. 布线 + 天线 + 填充
bash scripts/06_signoff.sh         # 6. STA(tt) + PDN + IR + SDF
bash scripts/run_gds_drc.sh        # 7+8. GDS 合成 + DRC
bash scripts/dump_cts_netlist.sh   # 9a. post-CTS 网表（LVS 金标准）
bash scripts/lvs_extract.sh        # 9b. Magic 提取版图网表
bash scripts/run_lvs.sh            # 9c. netgen 比对
bash scripts/dump_route_netlist.sh # 10a. 布线后网表（后仿用）
bash scripts/run_postsim.sh        # 10b. SDF 时序后仿
bash scripts/run_corner_sta.sh     # 11. 多 corner STA（tt/ff/ss）
```

| 步骤 | 输入 | 输出 | 判据（脚本会自己检查） |
|------|------|------|------------------------|
| 0 合并 LEF | tlef + lef | `runs/lef/*.lef` | 13 layers + 441 cells |
| 1 综合 | `rtl/counter.v` | `runs/01_synth/counter_synth.v` | 23 cells，面积 299 µm² |
| 2 布图 + tap + PDN | 网表 + SDC | `runs/02_floorplan/floorplan.def` | die 100×100，93 tapcells，`SPECIALNETS=2`，否则退出 1 |
| 3 布局 | floorplan.odb | `runs/03_place/place.def` | 0 重叠，HPWL 514.9 µm |
| 4 CTS | place.odb | `runs/04_cts/cts.def` | 插入 clkbuf，skew 0.25 ns |
| 5 布线 + 填充 | cts.odb | `runs/05_route/route.def` | violations = 0、天线 0，否则退出 1；730 fill |
| 6 签核 | route.odb | `runs/06_signoff/sta.log`、`pdn_check.log`、`counter.sdf` | WNS/TNS = 0；2/2 网连通；IR 0.86% → 否则退出 1 |
| 7 GDS | route.def | `runs/09_gds/counter.gds` | 单 top `counter`，层映射无 WARN |
| 8 DRC | GDS | `runs/09_gds/drc.lyrdb` | `<item>` = 0 → 否则脚本退出 1 |
| 9 LVS | ext + golden | `runs/10_lvs/lvs.out` | `Netlists match uniquely` → 否则退出 1 |
| 10 后仿 | route 网表 + SDF | `runs/12_postsim/postsim.log` | `PASS` |
| 11 多 corner | route.odb + 3 套 liberty | `runs/13_corners/sta_<corner>_<period>.log` | 10 MHz 下三角 setup+hold 全 MET |
| 12 SPEF | route.odb + rcx_rules.info | `runs/13_spef/counter.spef` | OpenRCX 提取 + 0 unannotated |

`make all` = 1–6；`make finish` = 7–12（gds + lvs + postsim + corners + spef）；
`make verify` = 仿真/等价/变异；`make sanitize` = 提交前脱敏日志。

---

## 4. 脚本手册

### 4.1 后端主流程

| 脚本 | 说明 |
|------|------|
| `scripts/env.sh` | **唯一环境入口**：ROOT、PATH、PDK 路径、MERGED_LEF；被所有脚本 source |
| `scripts/merge_lef.sh` | tlef + lef 合成一份；去掉重复 `END LIBRARY`，从第一个 `MACRO` 起保留单元段 |
| `scripts/01_synth.sh` | yosys：`techmap → dfflibmap → abc`；没 PDK 时退化 generic |
| `scripts/02_floorplan.sh` | `initialize_floorplan` + `make_tracks` + `place_pins` + **tapcell**（93 个，间距 13 µm）+ **PDN**（`add_global_connection` → `pdngen`：met1 跟随轨 + met4/met5 主干，`-pins met5`） |
| `scripts/03_place.sh` | `global_placement -density 0.55` + `detailed_placement` |
| `scripts/04_cts.sh` | `clock_tree_synthesis -buf_list {buf_1 buf_2}` + 重新合法化 |
| `scripts/05_route.sh` | `global_route` + `detailed_route` + `check_antennas` + `filler_placement`（730 fill）+ `global_connect`；末尾检查 violations=0、天线=0 |
| `scripts/06_signoff.sh` | STA(tt，setup/hold/wns/tns/area) + `check_power_grid` + `analyze_power_grid`（via 按 5 Ω 假设）+ `write_sdf` |
| `scripts/common.tcl` | OpenROAD 公共初始化：读合并 LEF + liberty |

### 4.2 验证（不需要 PDK）

| 脚本 | 说明 | 期望 |
|------|------|------|
| `scripts/run_sim.sh` | RTL + 门级仿真 | 两行 `PASS` |
| `scripts/run_equiv.sh` | yosys 等价（`async2sync` + `equiv_*`） | `Equivalence successfully proven!` |
| `scripts/run_mutation.sh` | 3 个注入 bug + 对照 | 3 抓到 + 1 通过，否则退出 1 |
| `scripts/run_timing_sweep.sh` | 周期 100→0.5 ns 扫 STA（每次重估寄生） | ≥2 ns MET；1 ns −0.27；0.5 ns −0.77 |

支撑文件：`sim/counter_tb.v`（自检 testbench，支持 `+SDF`）、`sim/counter_bug.v`（`BUG_RESET`/`BUG_STEP`/`BUG_TICK`）、`sim/sky130_hd_min.v`（11 个单元模型，带 specify 块）、`sim/sky130_physical_stubs.v`（fill/tap/decap 空模块）。

### 4.3 GDS / DRC / LVS

| 脚本 | 作用 |
|------|------|
| `scripts/run_gds_drc.sh` | KLayout 合成 GDS + 跑 `sky130A.lydrc`，检查 marker 数 |
| `scripts/make_gds.py` | DEF + 单元 GDS → flatten 成单 top GDS（含层名映射） |
| `scripts/dump_cts_netlist.sh` | cts.odb → `counter_cts.v`（金标准） |
| `scripts/lvs_extract.sh` | Magic 读 DEF+LEF 做单元级提取 → `counter_ext_cell.spice` |
| `scripts/make_golden.py` | post-CTS 网表 + CDL 引脚顺序 → `counter_golden.spice`（总线展开、阱并入电源） |
| `scripts/fix_ext_power.py` | 把 `_28_/VPWR` 这类零散电源脚并成全局网；VPB→VPWR、VNB→VGND |
| `scripts/run_lvs.sh` | 串起 golden → fix power → netgen，判定 match uniquely |
| `scripts/lvs_extra.tcl` | netgen 附加规则：VPWR/VGND 全局、忽略 fill/tap/decap |

顺序不能换：`dump_cts_netlist.sh` → `lvs_extract.sh` → `run_lvs.sh`。

### 4.4 后仿（SDF）

| 脚本 | 说明 |
|------|------|
| `scripts/dump_route_netlist.sh` | route.odb → `counter_route.v`（849 实例，含 CTS buffer、tap、fill） |
| `scripts/run_postsim.sh` | 编译 `-gspecify` + `+SDF=` 做时序后仿，要求 `PASS` |
| `sim/sky130_physical_stubs.v` | fill/tap 的空模块，只为让后仿网表编译通过 |

前提：`06_signoff.sh` 生成 `runs/06_signoff/counter.sdf`（`write_sdf`）。
SDF 的连线延迟来自**估算寄生**，单元延迟来自 liberty；模型里的 specify 弧是手写占位（被 SDF 覆盖）。见 §10。

### 4.5 多 corner STA

| 脚本 | 说明 |
|------|------|
| `scripts/run_corner_sta.sh` | tt/ff/ss 各跑一次真实 SDC（10 MHz，setup+hold）+ 一次 1 ns 压力（只看 setup），输出两张表并判定 |

- corner：`tt_025C_1v80` / `ff_n40C_1v95` / `ss_100C_1v40`
- 判据：10 MHz 下三角 setup/hold WNS 必须 ≥ 0，否则退出 1
- 报告：`runs/13_corners/sta_<corner>_nominal.log`、`sta_<corner>_1ns.log`

### 4.6 版图可视化

| 脚本 | 说明 |
|------|------|
| `scripts/dump_shapes.py` | KLayout 导出 `shapes.json`（逐层多边形） |
| `scripts/render_from_json.py` | PIL 分 15 组画 PNG → `runs/11_layout_png/`（含 PDN 视图） |

### 4.7 环境 / PDK

| 脚本 | 说明 |
|------|------|
| `scripts/fetch_pdk.sh` | volare 拉 sky130（可传版本号） |
| `scripts/install_openroad_nix.sh` | 装 Nix + OpenROAD |
| `scripts/check_env.sh` | 自检 |
| `scripts/sanitize_repo.sh` | 提交前把日志里的本机路径换成占位符 |

### 4.8 legacy/

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

综合：8×`dfrtp_1` + 组合门 = 23 cells / 299 µm²。
CTS 后 26 cells（+3 clock buffer）/ 427 µm²，利用率 7%（427/6277）。

约束见 `constraints/counter.sdc`。

---

## 6. 验证结论（2026-10-25 全量重跑）

| 层级 | 结果 | 证据 |
|------|------|------|
| RTL 功能仿真 | PASS（256 步） | `sim/out/rtl_sim.log` |
| 门级仿真 | PASS | `sim/out/gate_sim.log` |
| 形式等价 | 9/9 proven | `runs/07_equiv/equiv.log` |
| 变异测试 | 3/3 抓到 + 对照 OK | `sim/out/mutation_summary.txt` |
| STA @10 MHz (tt) | WNS/TNS = 0；setup slack 96.69，hold 0.23 | `runs/06_signoff/sta.log` |
| **多 corner @10 MHz** | **tt/ff/ss 全部 MET**（见下表） | `runs/13_corners/` |
| 时钟扫描 (tt) | 2 ns MET；1 ns −0.27；0.5 ns −0.77 | `runs/08_timing_sweep/sta_*.log` |
| 布图 | 93 tapcells；`SPECIALNETS=2`，met1 轨 30 条 + met4/met5 主干各 6 条 | `runs/02_floorplan/floorplan.def` |
| 布线 | violations = 0，天线 0，信号线长 622 µm，via 187 | `runs/05_route/openroad.log` |
| 填充 | 730 个 fill cell（fill_8 519 / fill_4 83 / fill_2 64 / fill_1 64） | `runs/05_route/route.def` |
| 电源 | **2/2 电源网连通**；IR drop 15.5 mV / 0.86%（VGND 14.5 mV / 0.80%） | `runs/06_signoff/pdn_check.log` |
| GDS | 单 top `counter`，约 1.9 MB（含 fill，met1–met5 + via） | `runs/09_gds/klayout_gds.log` |
| DRC | **0 违例**（166 类规则） | `runs/09_gds/drc.lyrdb` |
| LVS | **match uniquely**（26 devices / 30 nets，阱并进电源） | `runs/10_lvs/lvs.out` |
| 后仿 | 布线后网表 + SDF，**PASS** | `runs/12_postsim/postsim.log` |

### 多 corner 明细（10 MHz，真实 SDC）

| corner | setup slack | hold slack | WNS/TNS | 结论 |
|--------|-------------|------------|---------|------|
| tt | 96.69 ns | 0.23 ns | 0.00 / 0.00 | MET |
| ff | 97.09 ns | **0.05 ns** | 0.00 / 0.00 | MET（hold 最紧） |
| ss | **94.61 ns** | 0.84 ns | 0.00 / 0.00 | MET（setup 最紧） |

### 频率压力（1 ns，只看 setup）

| corner | setup WNS | 结论 |
|--------|-----------|------|
| tt | −0.27 | 违例 |
| ff | +0.19 | MET（快的 corner 还能撑） |
| ss | −2.88 | 违例（慢的 corner 最先挂） |

**结论**：这颗 8-bit 计数器在 10 MHz 下三 corner 全过，真正的边界是 ss 的 setup；
往上压频率时 **ss 先挂、ff 的 hold 先收紧**——这就是多 corner 的意义。

---

## 7. 踩过的坑（必读）

1. **合并 LEF**：OpenROAD 分开读 tlef+lef 会 `library already exists` 或丢 site；必须合成一份，且全文只有一个 `END LIBRARY`。
2. **`initialize_floorplan -site unithd`**：sky130_fd_sc_hd 的行高 site 叫 `unithd`；要先 `make_tracks` 才能 `place_pins`。
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
12. **路径不要写死**：早期脚本 `cd /path/to<你>/...`，换机器就废；现在统一 `source env.sh`。
13. **`/tmp` 放合并 LEF 会和别的 checkout 抢**；现在放 `runs/lef/`。
14. **PowerShell 调 WSL 管道/引号极易踩坑**；长脚本写进 `.sh` 再执行。
15. **KLayout 读 DEF 时层号是它自己编的**：LEF 里没有 GDS 层号，met1 会落到 `5/0`、met2 落到 `7/0`……跟 sky130 的 `68/20`、`69/20` 对不上。结果 GDS 里**单元图形是对的、绕线全在假层上**，DRC 扫不到线，会安静地报"0 违例"。`make_gds.py` 现在按层名映射（`LAYER_MAP`），`run_gds_drc.sh` 一看到 `WARN` 就失败。
16. **PDN 顺序不能错**：先 `add_global_connection` + `global_connect`，再 `define_pdn_grid` / `pdngen`；否则单元电源脚没连上，网格是空壳。`define_pdn_grid` 加 `-pins {met5}` 才会生成顶层电源端子，没有端子 `check_power_grid` 会报 `PSM-0025`。
17. **IR drop 默认算不了**：sky130 的 LEF 只有层电阻（`RESISTANCE RPERSQ`），**没有 via 电阻**，`analyze_power_grid` 直接报 `PSM-0021`。先 `set_layer_rc -via via -resistance 5.0`（每个 via 类型都要设）就能跑；本 lab 的压降数字建立在这个 5 Ω 假设上。
18. **插了 tap cell，LVS 会多出一条孤立 VPB 网**：tap 把 nwell 短到 VPWR、pwell 短到 VGND，版图侧阱被并走，而金标准还把 VPB/VNB 当独立网 → `Netlists do not match`。做法是两侧都按 tap 约定归一（`make_golden.py` / `fix_ext_power.py` 里 VPB→VPWR、VNB→VGND），并在 `lvs_extra.tcl` 里只声明 VPWR/VGND 为全局网。
19. **tap cell 要在 PDN 之前插**，且 `add_global_connection` 要放在 tapcell 之后，否则新插的 tap 电源脚接不上网格。
20. **fill cell 插完要再 `global_connect` 一次**，否则新实例的电源脚是浮的，`check_power_grid` 会报不连通。
21. **`write_verilog -noattr` 是 yosys 的参数，不是 OpenROAD 的**：OpenROAD 会照打 `ROUTE_NETLIST_OK` 但文件根本没写出来。去掉 `-noattr`。
22. **iverilog 默认丢掉 specify 块**，于是 `$sdf_annotate` 直接不执行（"specify blocks are being omitted"）。要真做 SDF 后仿：模型里写 `specify` 块 + 编译加 `-gspecify`。
23. **PowerShell 写文件别用 `Set-Content -Encoding UTF8`**：PS 5.1 会加 BOM，脚本第一行变 `﻿#!/usr/bin/env ...`，bash 直接报 "No such file or directory"。
24. **`route.odb` 里存的寄生在插 fill 之后会失效**：STA 读回来如果不再 `estimate_parasitics`，会退化成理想连线，数字偏乐观（1 ns 显示 −0.13，实际 −0.27）。现在 06 / 时钟扫描 / 多 corner 三处都统一重估。

---

## 8. 目录结构

```
openlane-lab/
├── README.md              对外说明（含来源与局限）
├── HANDOFF.md             本文件（交接总览）
├── LICENSE                MIT（代码）；GDS 按 Apache-2.0
├── Makefile               all / verify / gds / lvs / postsim / corners / finish / png / check / sanitize / clean
├── .github/workflows/     smoke CI（RTL 仿真 + 等价 + 变异）
├── rtl/counter.v
├── constraints/counter.sdc
├── sim/                   testbench（支持 SDF）/ 变异版本 / 单元模型（带 specify）/ 物理单元桩
├── scripts/
│   ├── env.sh             唯一环境入口（ROOT、PATH、PDK、MERGED_LEF）
│   ├── 01..06_*.sh        后端主流程（06 出 SDF）
│   ├── run_{sim,equiv,mutation,timing_sweep}.sh
│   ├── run_gds_drc.sh / make_gds.py
│   ├── dump_cts_netlist.sh / lvs_extract.sh / run_lvs.sh / make_golden.py / fix_ext_power.py
│   ├── dump_route_netlist.sh / run_postsim.sh     SDF 后仿
│   ├── run_corner_sta.sh                          多 corner STA
│   ├── dump_shapes.py / render_from_json.py
│   ├── check_env.sh / fetch_pdk.sh / install_openroad_nix.sh / sanitize_repo.sh
│   └── legacy/            没走通的路径（留作踩坑记录）
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
    ├── 11_layout_png/     分层渲染（不入库，精选图在 docs/img）
    ├── 12_postsim/        后仿日志（只提交 postsim.log）
    └── 13_corners/        多 corner STA 报告
```

---

## 9. 快速复现

```bash
git clone <repo> && cd openlane-lab

bash scripts/check_env.sh          # 缺什么一目了然
bash scripts/fetch_pdk.sh          # 首次
bash scripts/merge_lef.sh
make all                           # 01–06
make finish                        # GDS+DRC / LVS / 后仿 / 多 corner / SPEF
make spef                          # 仅 OpenRCX 真寄生对比
make verify                        # 仿真 + 等价 + 变异
bash scripts/run_timing_sweep.sh   # 时钟扫描（可选）
```

成功标志：`PASS` ×4、`Equivalence successfully proven!`、`[PASS] DRC 0 违例`、
`[PASS] LVS: Netlists match uniquely`、`[PASS] 10 MHz 下 tt/ff/ss ... 全部 MET`。

---

## 10. 已知局限

1. **IR drop 是估计值**：PDN 真实存在、连通性已验证；`analyze_power_grid` 能跑，
   但 via 电阻是按 5 Ω 假设灌进去的（LEF 只带层电阻），所以 15.5 mV / 0.86% 只能看数量级。
2. **LVS 两级**：签核判据是 **cell-level**（`make lvs`，match uniquely）。
   晶体管级（`make lvs_dev`）已能对齐器件数 346=346、网络数 177=177，
   但扁平 GDS 提取 vs CDL 的内部节点拓扑仍有残差（见 §11 P6）。
3. **SPEF 已接入 STA/后仿**：`make spef` 产出 `runs/13_spef/counter.spef`；
   corners / signoff SDF / postsim 在 SPEF 存在时用 `read_spef`。
4. **后仿不是签核级**：单元延迟来自 liberty；模型 specify 弧是手写占位（被 SDF 覆盖）。
5. **OCV 为 8 个典型电压温度角 + 全局 derate**：无 RC corner、无逐角 derate 表。
6. **约束很简单**：只有一个时钟，没有多周期/假路径/复杂 IO 时序；频率也只到 10 MHz。
7. **单元模型手写**：`sim/sky130_hd_min.v` 只覆盖用到的 11 个 cell。
8. **decap / 密度填充已做**：451 decap + 56 fill；金属 fill 22085（`make density`）。

---

## 11. 下一步计划（按优先级）

| 优先级 | 任务 | 为什么 | 阻塞 / 做法 |
|--------|------|--------|-------------|
| P0 | 把当前多 corner 改动提交并推送 | 保持仓库与本地一致 | 已完成 / 待推 |
| P1 | ~~OpenRCX → SPEF~~ **已完成**（`make spef`）；corners/postsim **已切换 read_spef** | 真寄生才站得住 | `runs/13_spef/`；signoff SDF 含 SPEF 连线延迟 |
| P2 | ~~EM 分析~~ **已完成**（`make em`） | 电源签核另一半 | `runs/14_em/`；Imax≈3.9 µA ≈ 典型限值 2.8% |
| P3 | ~~金属密度填充~~ **已完成**（`make density`） | CMP/密度 | `runs/15_density/`；**22085 fills**；schema 关键：`width`/`height` 必须是**数组** |
| P4 | ~~decap~~ **已完成**（改 `05_route.sh`） | 电源完整性 | 451 decap + 56 fill |
| P5 | ~~OCV / 更多 corner~~ **已完成**（`make ocv`） | 时序签核 | `runs/16_ocv/`；8 corner 全 MET |
| P6 | ~~晶体管级 LVS~~ **结论明确**（`make lvs_dev` + `docs/p6-topology.md`） | 换掉 LEF 抽象级 | 器件/网数对齐；残差=对称 XOR/AOI 内部网配对，非功能错误 |
| P7 | ~~缩 die / 提频~~ **已完成** | 工程数字 | 40×40 / 27% util；SDC 125 MHz（全角 MET）；tt 极限 667 MHz |

**明确不做**：换 UART/SPI 等新设计（按你的要求）。

---

## 12. 来源

* 本仓库从零编写，**不是 fork**。
* PDK：`google/skywater-pdk`（Apache-2.0），经 `efabless/volare` 安装预编译版。
  当时下载的 PDK 源码快照（`skywater-pdk-main.zip`）**没有进仓库**。
* 工具链：OpenROAD / Magic / Yosys / KLayout / Netgen / Icarus，均为系统安装，仓库不含二进制。
* 概念参考：`efabless/openlane`（Apache-2.0），未复用代码。

---

## 13. 交接清单

- [x] 环境：WSL + Nix OpenROAD/Magic + volare sky130
- [x] 主流程 01–06 可重复执行，脚本自带判据
- [x] 验证：仿真 / 门级 / 等价 / 变异 / STA / 时钟扫描
- [x] GDS + DRC(0) + LVS(match uniquely)
- [x] PDN：met1 跟随轨 + met4/met5 主干，`check_power_grid` 2/2 连通
- [x] tap cell：93 个，间距 13 µm，阱按 tap 约定并进电源
- [x] IR drop：15.5 mV / 0.86%（via 电阻 5 Ω 假设）
- [x] 天线检查：0 违例
- [x] 填充：730 个 fill cell，插完重新 `global_connect`
- [x] 后仿：布线后网表 + SDF（`-gspecify`），PASS
- [x] 多 corner：tt/ff/ss @10 MHz 全 MET；1 ns 时 ss 先挂
- [x] 路径去硬编码，clone 到任意目录可跑
- [x] 仓库整理：`.gitignore` / `.gitattributes` / `LICENSE` / legacy 归档 / CI / 日志脱敏
- [x] 文档：README / HANDOFF / tools / flow-notes / verification / first-run-report
- [x] OpenRCX 模型 → SPEF / 真提取（P1）— `make spef`，`runs/13_spef/counter.spef`
- [x] corners / postsim 切换 `read_spef`（P1 收尾）— 1 ns tt WNS -0.34；后仿 PASS
- [x] EM（P2）— `make em`，`runs/14_em/`，Imax≈3.9 µA ≈ 典型限值 2.8%
- [x] 金属密度填充（P3）— `make density`，22085 fills
- [x] decap（P4）— 451 个 decap 实例
- [x] OCV / 更多 corner（P5）— `make ocv`，8 角全 MET
- [x] 晶体管级 LVS（P6）— 器件/网数对齐；见 `docs/p6-topology.md`
- [x] P7 缩 die/提频 — 40×40、27% util、SDC 200 MHz、667 MHz 边界

有问题先查 §7 坑列表；脚本细节见 §4；验证结论见 §6；下一步见 §11。
