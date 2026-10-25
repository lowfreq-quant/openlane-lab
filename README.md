# openlane-lab — 用开源工具链把 RTL 走到 GDS

[![smoke](https://github.com/lowfreq-quant/openlane-lab/actions/workflows/smoke.yml/badge.svg)](https://github.com/lowfreq-quant/openlane-lab/actions/workflows/smoke.yml)

**不用 Docker，不用 OpenLane 黑盒。** 8-bit 计数器，SkyWater SKY130（`sky130_fd_sc_hd`），
在 WSL2 里一步步跑完综合 → 布图（含 PDN）→ 布局 → CTS → 布线 → STA → GDS → DRC → LVS，
每一步的命令、输入、输出、日志都留在仓库里。

![版图渲染](docs/img/layout_overview.png)

| 指标 | 结果 |
|------|------|
| 工艺 / 单元库 | SKY130A / `sky130_fd_sc_hd`（volare 预编译版） |
| 综合面积 | 23 cells，299 µm²（8× `dfrtp_1`） |
| 布图 / 布局 | **die 40×40**，逻辑 317 µm²，利用率 27%（含 decap 后 1146 µm² / 99%） |
| 布线 | 0 违例，**天线 0 违例**，线长 575 µm，via 182 |
| 填充 | **68 decap + 7 fill**；金属密度填充另出 `runs/15_density/route_filled.def`（4900 个 fill 矩形） |
| 电源 | PDN 2/2 网连通；IR drop VPWR **28 mV（1.6%）** / VGND **74 mV（4.1%）**（via 电阻按 5 Ω 假设） |
| 真寄生 | OpenRCX `extract_parasitics` → SPEF，**0 unannotated** |
| STA @125 MHz | WNS/TNS = 0（tt 极限约 667 MHz） |
| 多工艺角 | tt/ff/ss @125 MHz setup+hold **全 MET**（ss setup 最紧 2.57 ns，ff hold 最紧 0.05 ns）；1 ns 压力 ss −2.99、tt −0.31、ff 仍 MET |
| OCV | 8 个电压温度角 + 全局 derate，**全 MET** |
| RC corner | 5 种 SPEF（min/nom/max…）+ 复杂 SDC，**全 MET** |
| EM | 最坏边电流约典型 Jmax 的 **8.6%**（教学量级，非 foundry 签核） |
| 后仿 | SPEF SDF，tt/ff/ss 三角 **PASS** |
| GDS | 单 top cell `counter`，约 558 KB |
| DRC | **0 违例**（sky130A.lydrc，166 类规则） |
| LVS | cell 级 **match uniquely**（26 devices / 30 nets）；器件级 346=346 / 177=177，拓扑残差见 `docs/p6-topology.md` |
| 形式等价 | 9/9 proven |
| 变异测试 | 3/3 注入 bug 被 testbench 抓到 |

| 器件层（nwell/diff/poly/implant） | 绕线层（met1/met2/met3 + via） | 电源网络（met1 轨 + met4/met5 主干） |
|---|---|---|
| ![器件层](docs/img/layer_device.png) | ![绕线层](docs/img/layer_routing.png) | ![电源网络](docs/img/layer_pdn.png) |

## 1. 这个 lab 想解决什么

跑 OpenLane 很容易：一条命令，几十分钟，出一个 GDS。但中间发生了什么、哪一步错了，
全在 `runs/<design>/logs/` 的几万行里。

这里把 OpenLane 内部**拆成 12 个手写阶段**（再加 6 个扩展签核项），每阶段一个脚本、一份产物、一条可核对的判据：

| # | 阶段 | 脚本 | 产物 | 判据 |
|---|------|------|------|------|
| 0 | 合并 LEF | `scripts/merge_lef.sh` | `runs/lef/*.lef` | 13 层 + 441 cells 能读入 |
| 1 | 综合 | `scripts/01_synth.sh` | `runs/01_synth/counter_synth.v` | 23 cells / 299 µm² |
| 2 | 布图 + tap + PDN | `scripts/02_floorplan.sh` | `runs/02_floorplan/floorplan.def` | die 40×40，14 tapcells，`SPECIALNETS=2` |
| 3 | 布局 | `scripts/03_place.sh` | `runs/03_place/place.def` | 0 重叠，逻辑 317 µm² / 27% |
| 4 | CTS | `scripts/04_cts.sh` | `runs/04_cts/cts.def` | 插入 clock buffer，skew 可报告 |
| 5 | 布线 + 天线 + 填充 | `scripts/05_route.sh` | `runs/05_route/route.def` | violations = 0，天线 0，68 decap + 7 fill |
| 6 | 签核（STA + PDN + IR + SDF） | `scripts/06_signoff.sh` | `runs/06_signoff/sta.log`、`pdn_check.log`、`counter.sdf` | WNS/TNS = 0；2/2 网连通；IR 1.6%/4.1% |
| 7 | GDS | `scripts/run_gds_drc.sh` | `runs/09_gds/counter.gds` | 单 top cell |
| 8 | DRC | 同上 | `runs/09_gds/drc.lyrdb` | `<item>` 数量 = 0 |
| 9 | LVS | `dump_cts_netlist.sh` + `lvs_extract.sh` + `run_lvs.sh` | `runs/10_lvs/lvs.out` | match uniquely |
| 10 | 后仿 | `dump_route_netlist.sh` + `run_postsim.sh` | `runs/12_postsim/postsim.log` | `PASS` |
| 11 | 多 corner STA | `scripts/run_corner_sta.sh` | `runs/13_corners/sta_<corner>_*.log` | 125 MHz 下 tt/ff/ss 全 MET |

扩展签核（`make finish` 会一起跑）：

| 项 | 脚本 | 产物 | 结果 |
|----|------|------|------|
| OpenRCX SPEF | `run_spef.sh` | `runs/13_spef/counter.spef` | 0 unannotated；1 ns 估算 −0.27 vs SPEF −0.34 |
| EM | `run_em.sh` + `analyze_em.py` | `runs/14_em/em.log` | 最坏 ≈ 8.6% 典型 Jmax |
| 金属密度填充 | `run_density_fill.sh` | `runs/15_density/route_filled.def` | 4900 个 fill 矩形（未进最终 GDS） |
| OCV | `run_ocv_sta.sh` | `runs/16_ocv/` | 8 角全 MET |
| 晶体管级 LVS | `run_lvs_device.sh` | `runs/17_lvs_device/lvs_dev.out` | 346=346 / 177=177，拓扑残差 |
| RC corner | `run_rc_corners.sh` | `runs/19_rc_corners/` | 5 情景全 MET |
| 签核后仿 | `run_postsim_signoff.sh` | `runs/20_postsim_signoff/` | SPEF SDF 三角 PASS |

## 2. 5 分钟复现

前置：WSL2 Ubuntu 24.04，工具按 [`docs/tools.md`](docs/tools.md) 装好。本机实测版本见那张表。

```bash
git clone <repo-url> && cd openlane-lab

# 0) 环境自检（缺什么会逐条告诉你）
bash scripts/check_env.sh

# 1) PDK（首次）
bash scripts/fetch_pdk.sh

# 2) 合并 LEF（每个 checkout 只需一次）
bash scripts/merge_lef.sh

# 3) 后端主流程：综合 → 布图(+tap+PDN) → 布局 → CTS → 布线(+天线+填充) → 签核
make all

# 4) 收尾：GDS+DRC、LVS、后仿、多 corner、SPEF、EM、密度填充、OCV
make finish

#    或者分开跑：
#    make gds            # GDS + DRC
#    make lvs            # cell 级 LVS
#    make postsim        # SDF 后仿
#    make corners        # tt/ff/ss 多工艺角
#    make spef           # OpenRCX SPEF + 估算对比
#    make em             # EM 分析
#    make density        # 金属密度填充
#    make ocv            # OCV 8 角
#    make psign          # 签核后仿（SPEF SDF）
#    make report         # 一键打印验证矩阵
```

跑完检查：`runs/09_gds/drc.lyrdb` 里 `<item>` 为 0；`runs/10_lvs/lvs.out` 里有
`Netlists match uniquely.`；`runs/12_postsim/postsim.log` 里有 `PASS`；
`runs/13_spef/spef.log` 里 `Found 0 unannotated drivers.`

> `runs/` 里提交的是当时的真实日志。重跑会改动它们（日志里有绝对路径、GDS 头里有时间戳），
> 所以 `git status` 出现若干 `runs/` 变更是正常的，不是你没跑对。
>
> 另外：提交进仓库的日志做过**路径脱敏**——本机路径被替换成 `/path/to/openlane-lab`
> 和 `/home/user`，跑出来的数字、时序、违例数都是原样。重跑时自然会出现你自己的路径，
> **提交前跑一次 `make sanitize`** 就能把本机路径再换回占位符。

## 3. 验证（前面几项不需要 PDK）

```bash
bash scripts/run_sim.sh            # RTL 仿真 + 门级仿真，各 256+ 步
bash scripts/run_equiv.sh          # yosys 形式等价 RTL ≡ 网表
bash scripts/run_mutation.sh       # 注入 3 个 bug，testbench 必须抓到
bash scripts/run_timing_sweep.sh   # 时钟 100ns → 0.5ns 扫 WNS
```

前三个在 CI 里也跑（见 [`.github/workflows/smoke.yml`](.github/workflows/smoke.yml)），
所以 clone 下来不装 PDK 也能确认「仿真和等价是对的」。

后仿、多 corner、SPEF/OCV 需要先跑完布线（`make all`），然后：

```bash
make postsim                       # 布线后网表 + SDF → 时序后仿
make corners                       # tt/ff/ss 三工艺角（125 MHz setup+hold，外加 1 ns 压力）
make spef                          # OpenRCX 真寄生 → SPEF
make ocv                           # 8 个电压温度角
make finish                        # 上面全部 + GDS/DRC + LVS 一起跑
make report                        # 只读产物，打印验证矩阵
```

## 4. 目录

```
.
├── rtl/counter.v              设计：8-bit 自由跑计数器（异步复位）
├── constraints/counter.sdc    125 MHz（8 ns）约束
├── sim/                       testbench / 变异版本 / 单元模型（带 specify）/ 物理单元桩
├── scripts/
│   ├── env.sh                 唯一的环境入口（PDK 路径、PATH、合并 LEF）
│   ├── 01..06_*.sh            后端主流程（06 出 SDF）
│   ├── run_sim/equiv/mutation/timing_sweep.sh
│   ├── run_gds_drc.sh         GDS + DRC
│   ├── dump_cts_netlist.sh / lvs_extract.sh / run_lvs.sh
│   ├── dump_route_netlist.sh / run_postsim.sh   SDF 后仿
│   ├── run_corner_sta.sh      多 corner STA
│   ├── run_spef.sh / run_em.sh / analyze_em.py  SPEF / EM
│   ├── run_density_fill.sh    金属密度填充
│   ├── run_ocv_sta.sh / run_rc_corners.sh       OCV / RC corner
│   ├── run_lvs_device.sh / run_postsim_signoff.sh
│   ├── make_report.sh         验证矩阵
│   ├── make_gds.py / make_golden.py / fix_ext_power.py
│   ├── dump_shapes.py / render_from_json.py
│   └── legacy/                没走通的路径（留作踩坑记录）
├── docs/                      流程笔记、验证证据链、工具安装、版图截图
├── runs/                      各阶段产物（.odb / .spice / 后仿临时文件不入库）
├── Makefile
└── HANDOFF.md                 完整交接文档（方法流 / 脚本手册 / 踩坑清单）
```

## 5. 已知局限（先声明，别当它是可流片设计）

1. **IR drop 是估计值，不是签核值。** PDN 是真的（met1 跟随轨 + met4/met5 主干），
   `check_power_grid` 确认两个网全部连通；`analyze_power_grid` 也能跑，但 sky130 的 LEF
   **只有层电阻、没有 via 电阻**，所以脚本里按 **5 Ω/个 via** 假设（`set_layer_rc`）。
   压降 VPWR 28 mV/1.6%、VGND 74 mV/4.1%，数量级可信，但不能当签核数字。
2. **LVS 有两级，签核判据取 cell 级。** `make lvs` 是 LEF 抽象级（实例+连接），
   match uniquely；`make lvs_dev` 的晶体管级能对齐器件数 **346=346**、网络数 **177=177**，
   但扁平 GDS 提取与 CDL 的内部节点拓扑仍有残差（见 [`docs/p6-topology.md`](docs/p6-topology.md)）。
   阱（VPB/VNB）按 tap 约定并进 VPWR/VGND，所以**不逐阱检查**。
3. **SPEF 只有一套 RCX 模型。** `make spef` 用 PDK 的 `rcx_rules.info` 做 OpenRCX 提取
   （0 unannotated），但 RC corner 是在同一模型上缩放出来的，不是多套真实 RCX 模型。
4. **后仿的单元模型是手写的。** SDF 的单元延迟来自 liberty、连线延迟来自 SPEF；
   `sim/sky130_hd_min.v` 里的 specify 弧是按端口手写的占位值（会被 SDF 覆盖），
   不是从 liberty 自动生成。
5. **OCV 是全局 derate。** 8 个电压温度角 + 一组 early/late derate，没有逐角 derate 表。
6. **金属密度填充没进最终 GDS。** `make density` 产出 `runs/15_density/route_filled.def`
   （4900 个 fill 矩形），但 GDS/DRC 仍用 `runs/05_route/route.def`——
   即填充做了、但没参与版图签核。
7. **约束仍然简单。** 只有一个时钟；`counter_complex.sdc` 有假路径/IO 预算，但主流程没用多周期路径。
8. **die 只有 40×40，目标 125 MHz。** 数字规模小，tt 极限约 667 MHz，ss 在 5 ns 会挂。
9. **单元功能模型手写**（11 个 cell），证明逻辑映射正确，但不等于与 foundry 模型 bit-exact。

## 6. 来源与致谢

**这个仓库不是 fork，是从零写的**（设计、脚本、文档都在本仓库演进）。
它站在下面这些东西上：

| 来源 | 用途 | 许可证 |
|------|------|--------|
| [google/skywater-pdk](https://github.com/google/skywater-pdk) | SKY130 工艺定义与单元库 | Apache-2.0 |
| [efabless/volare](https://github.com/efabless/volare) | 拉预编译 PDK（锁版本 hash） | Apache-2.0 |
| [The-OpenROAD-Project/OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) | 布图/布局/CTS/布线/STA | Apache-2.0 |
| [RTimothyEdwards/magic](http://opencircuitdesign.com/magic/) | 版图提取（LVS 版图侧） | MIT 风格 |
| [YosysHQ/yosys](https://github.com/YosysHQ/yosys) | 综合、形式等价 | ISC |
| [KLayout](https://www.klayout.de/) | GDS 合成、DRC、几何导出 | GPL-3.0 |
| [netgen](http://opencircuitdesign.com/netgen/) | LVS 比对 | GPL-2.0 |
| [steveicarus/iverilog](https://github.com/steveicarus/iverilog) | RTL / 门级仿真 | GPL-2.0 |
| [efabless/openlane](https://github.com/efabless/openlane) | **仅流程概念参考**，未复用代码 | Apache-2.0 |

关于「从哪里来的」说清楚（本仓库没有别的上游）：

* `openlane-lab/` 是**从零建的**：接手时目录里没有 `.git`、没有上游 README/LICENSE/提交历史，
  设计、脚本、文档都是在这里写出来的 → 不是 fork，没有归属争议，本仓库的提交历史就是全部历史。
* 唯一"下载来的"东西是当时放在父目录的 `skywater-pdk-main.zip`——[google/skywater-pdk](https://github.com/google/skywater-pdk)
  `main` 分支的源码快照（Apache-2.0），本来想直接读 PDK 源码。它只有元数据和 `.gitmodules`，
  **没有进本仓库**；实际用的是 volare 装的预编译 PDK（`7519dfb04400f224f140749cda44ee7de6f5e095`）。
* 工具全部是系统安装（apt / Nix / pip），仓库里不含第三方二进制，也不需要 submodule。

## 7. 许可证

代码与文档：MIT（见 [`LICENSE`](LICENSE)）。
`runs/09_gds/counter.gds` 由 SKY130 标准单元（Apache-2.0）生成，按 Apache-2.0 分发。

---

**这是个学习工程，不是产品。** 拿它对照 OpenLane 的日志、理解每一步的输入输出，
比自己啃文档快得多。
