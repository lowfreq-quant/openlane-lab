# ro/ — 模拟支线：7 级环形振荡器（手工版图 → PEX → 优化）

这是 `openlane-lab` 的数字主线之外的一条**模拟支线**：不用综合、不用 APR，纯手工画一个
7 级反相器环振，走完 **原理图 → 前仿 → 版图 → 提取寄生 → 后仿 → LVS → 迭代优化**。

| 项 | 值 |
|---|---|
| 工艺 | SKY130A（`sky130_fd_pr`，1.8 V 器件） |
| 器件 | `nfet_01v8` W=1 µm / `pfet_01v8` W=2 µm，L=0.15 µm |
| 拓扑 | 7 级反相器闭环，输出 `out` |
| 工具 | xschem（原理图）、ngspice（仿真）、magic（版图/提取/DRC）、netgen（LVS）、KLayout（渲染） |

## 1. 流程

```
ro.sch ──xschem──► ro.spice ──ngspice──► 前仿 2.700 GHz
                                    │
                    手工版图（magic，逐层矩形）──► DRC
                                    │
                              extract all ──► 带寄生 SPICE
                                    │
                       ngspice 后仿 ──► 频率 / 损耗
                                    │
                     netgen LVS（对照 ro_schem.spice）──► match uniquely
```

## 2. 四版优化与结果

| 版本 | 改动 | 布局尺寸 | 后仿频率* | 寄生损耗 |
|------|------|----------|-----------|----------|
| v5 初版 | 单排 7 级 | 25.4 × 6.0 µm | 1.671 GHz | 38.10% |
| R1 | 布线宽度/间距收紧 | 18.7 × 6.7 µm | 1.764 GHz | 34.67% |
| R2 | 源漏结面积最小化 | 18.7 × 6.7 µm | 1.822 GHz | 32.54% |
| **R3** | **两排蛇形 floorplan** | **11.1 × 11.5 µm** | **1.905 GHz** | **29.47%** |

\* 频率口径见 §4。前仿（无寄生）为 **2.700 GHz**。

累计：**+14% 频率，损耗压低 8.6 个百分点**；每一版都过 DRC（0 错误）与 LVS（14 器件 / 9 网络，`match uniquely`）。

### 蛇形版做了什么

- 下排 cell0–3 正常朝向，上排 cell4–6 **旋转 180°**，管脚全部朝向中间布线通道；
- 反馈网（cell6 → cell0）从 ~25 µm 缩到 **4.4 µm**；
- 电源轨用 met2 竖带在右侧跨行缝合（VPWR/VGND 各一条）；
- 版图从 25.4×6.0 的长条变成 11.1×11.5 的方形，级间布线长度减半。

## 3. 签核结果

- **DRC**：`magic3.log` → `Total DRC errors found: 0`
- **LVS**：`ro_serp_lvs.log` → `Circuits match uniquely`（14 devices / 9 nets）
- **提取**：`ro_serp.spice` 含 14 个器件 + 26 个寄生电容
- **后仿**：稳态周期 **525.0 ps**（相邻上升沿实测，3 个窗口一致）

## 4. 测量口径（重要）

原始脚本用 `f = 3/(t2-t1)`，其中 `t1`/`t2` 是 `rise=4` 和 `rise=10` ——
这中间是 **6 个周期**而不是 3 个，所以脚本打印的频率（835.7/882.0/910.8/952.2 MHz）
都只有真实值的一半。

用相邻上升沿（`rise=4→5`）复核得到稳态周期 525.0 ps → **1.905 GHz**，
与上表一致。**损耗是比值，不受这个系数影响**，所以四版的 38.10% / 34.67% / 32.54% / 29.47% 仍然有效。

要改脚本口径：把 `3/(...)` 换成 `6/(...)`，或直接量相邻沿。

## 5. 目录

```
ro/
├── README.md
├── netlist/    ro.sch（xschem）、ro.spice（前仿网表）、ro_schem.spice（LVS 金标准）、
│               ro_*.spice（各版提取网表）
├── gds/        ro_layout / ro_opt / ro_serp 的 GDS 与渲染 PNG
├── logs/       presim / postsim / postsim2 / postsim3、ro*_lvs.log、magic*.log
└── scripts/    当时的驱动脚本（见下）
```

| 脚本 | 作用 |
|------|------|
| `ro_frontend.sh` | 由 xschem 导出 `ro.sch` → `ro.spice`，跑前仿 |
| `ro_layout.sh` | v5 手工版图（单排） |
| `ro_opt.sh` | R1/R2 优化版（布线收紧 + 结面积） |
| `ro_serp.sh` | **R3 蛇形版**：180° 旋转变换 + 跨排走线 + 电源缝合 |
| `ro_lvs.sh` | netgen LVS |
| `fix_ngspice.sh` | 修补 PDK 缺失的 ngspice corner/模型（首次跑 ngspice 前用） |
| `ro_stage.sh` / `ro_backend.sh` / `ro_env.sh` / `ro_finale.sh` | 环境与早期实验脚本（参考用） |

## 6. 已知局限

1. **脚本是当时环境原样**：默认在 WSL `~/asic_ro` 下运行，PDK 路径 `~/.volare`；
   入库时做了路径脱敏（`/path/to`、`/home/user`），复用时按本机路径改。
2. **手工单元，不是 stdcell**：每个反相器是逐层矩形拼出来的，没有标准单元库的
   pin/密度/天线规则。
3. **单 corner PEX**：提取只跑了 nominal，没有 RC corner / MC / 温度扫描。
4. **频率绝对值依赖测量口径**（见 §4），损耗比更可信。
5. 没有做功耗/抖动/相位噪声分析——环振作为延迟标尺，关注的是周期。
