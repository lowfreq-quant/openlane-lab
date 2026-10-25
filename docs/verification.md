# 怎么确认这个设计靠谱

## 这是什么设计

`rtl/counter.v`：**8-bit 自由跑计数器**
- 输入：`clk`（8 ns / 125 MHz）、`rst_n`（低有效异步复位）
- 输出：`q[7:0]` 计数值、`tick`（q==0xFF 时为 1）
- 规模：8 个触发器 + 少量组合逻辑 → 综合后 23 个 sky130 单元、299 µm²
- 版图：die **40×40**，逻辑 317 µm² / 27%，填满 decap 后 99%

注意：文件头注释写「同步复位」，代码实际是**异步复位**（`posedge clk or negedge rst_n`）。以代码为准。

## 证据链（从软到硬）

| # | 层级 | 问什么 | 状态 | 证据 |
|---|------|--------|------|------|
| 1 | RTL 功能仿真 | 行为对不对 | **PASS**（256 步自检） | `sim/out/rtl_sim.log` |
| 2 | 门级仿真 | 综合有没有改坏功能 | **PASS**（同一 testbench） | `sim/out/gate_sim.log` |
| 3 | 形式等价 | RTL ≡ 网表能否证明 | **9/9 proven** | `runs/07_equiv/equiv.log` |
| 4 | 变异测试 | testbench 是否真能抓 bug | **3/3 抓到 + 对照通过** | `sim/out/mutation_summary.txt` |
| 5 | 静态时序 STA | 目标频率下能不能工作 | **MET @125 MHz**（tt setup 4.68 / hold 0.23） | `runs/06_signoff/sta.log` |
| 6 | 多工艺角 | tt/ff/ss 都行吗 | **125 MHz 下三角全 MET**（ss setup 2.57、ff hold 0.05） | `runs/13_corners/` |
| 7 | OCV | 电压温度角 + derate | **8 角全 MET** | `runs/16_ocv/` |
| 8 | 频率边界 | 最快能跑多少 | tt **1.5 ns / 667 MHz MET**；1.2 ns −0.17 | `runs/18_p7/` |
| 9 | 真寄生 | SPEF 提取对不对 | **0 unannotated**；1 ns −0.34（估算 −0.27） | `runs/13_spef/` |
| 10 | RC corner | 不同 RC 下还稳吗 | **5 情景全 MET** | `runs/19_rc_corners/` |
| 11 | 布线 DRC | 布出来的线有没有短路/间距问题 | **0 violations** | `runs/05_route/openroad.log` |
| 12 | 天线 | 长线会不会在刻蚀时积累电荷 | **0 net / 0 pin 违例** | `runs/05_route/openroad.log` |
| 13 | 填充 / decap | 空 site 有没有填满 | **68 decap + 7 fill**；金属 fill 4900（独立 DEF） | `runs/05_route/route.def`、`runs/15_density/` |
| 14 | 版图 DRC | GDS 能不能制造 | **0 违例 / 166 类规则** | `runs/09_gds/drc.lyrdb` |
| 15 | LVS（cell） | 版图连接 = 网表连接吗 | **match uniquely**（26 dev / 30 nets） | `runs/10_lvs/lvs.out` |
| 16 | LVS（device） | 晶体管级对不对 | **346=346 / 177=177**，拓扑残差 | `runs/17_lvs_device/lvs_dev.out` |
| 17 | 阱连接 | tap 有没有把阱接到电源 | **14 tapcells，阱并入 VPWR/VGND** | `runs/02_floorplan/floorplan.def` |
| 18 | PDN 连通 | 电源网格连到每个电源脚了吗 | **2/2 网全部连通** | `runs/06_signoff/pdn_check.log` |
| 19 | IR drop | 压降够不够 | **VPWR 28 mV/1.6%、VGND 74 mV/4.1%**（via 电阻 5 Ω 假设） | `runs/06_signoff/pdn_check.log` |
| 20 | EM | 电流密度够不够 | **最坏 ≈ 8.6% 典型 Jmax** | `runs/14_em/` |
| 21 | SDF 后仿 | 带延迟的布线后网表还对吗 | **PASS**（SPEF SDF，tt/ff/ss） | `runs/20_postsim_signoff/` |

前 21 层都跑通了。这说明：

- 规格自洽（每拍 +1，满一圈 tick）
- 综合映射到 sky130 后功能一致（仿真 + 形式证明 + 变异测试三重）
- 物理实现可制造（0 DRC）、连接与网表一致（cell 级 LVS）
- 电源网连通、压降/EM 在合理量级
- 布线后网表带 SPEF 延迟在三工艺角下都能跑

## 各层怎么复现

```bash
make all                                  # 1–6（综合到签核，出 SDF）
make verify                               # 1–4
make gds                                  # 11, 14
make lvs                                  # 15
make postsim                              # 21（估/SPEF SDF）
make spef                                 # 9
make em                                   # 20
make density                              # 13（金属 fill）
make ocv                                  # 7
make corners                              # 6
make rc                                   # 10
make lvs_dev                              # 16
make psign                                # 21（SPEF SDF 三角）
bash scripts/run_timing_sweep.sh          # 8（旧 100→0.5 ns 扫描）
bash scripts/run_p7_sweep.sh              # 8（缩 die 后的 0.8–20 ns 扫描）
```

天线（12）和 decap/fill（13）在 `bash scripts/05_route.sh` 里。

## 关键认知（做这些验证时踩到的）

1. **形式等价的异步复位**：`$adff` 在 SAT 里证不动，必须先 `async2sync`。
2. **LVS 金标准必须是 post-CTS 网表**：CTS 插了 3 个 clock buffer，拿综合网表比会误报。
3. **总线端口要对齐**：版图侧是 `q[0]..q[7]`，金标准如果把 `q` 当单端口，netgen 会
   "altered to match" 糊过去——看着通过，其实端口没对上。`make_golden.py` 会展开总线。
4. **电源脚要显式短接**：Magic 提取出来的是 `_28_/VPWR` 这种，LVS 前必须合并。
5. **DRC 的输入必须完整**：KLayout 读 DEF 时会给层自己编号（met1→5/0），
   不按层名映射回 `68/20`，GDS 里就只有单元图形、没有绕线，DRC 会安静地报 0 违例。
   用 0.01 µm 宽的 met2 做过敏感性自测，DRC 立刻报 `m2.1` + `m2.6`。
6. **SDF 后仿需要 specify 块**：iverilog 默认丢掉 specify，`$sdf_annotate` 直接不执行；
   模型要写 specify + 编译加 `-gspecify`。
7. **fill 插完要再 `global_connect`**，否则新实例的电源脚是浮的。
8. **`route.odb` 里的寄生在插 fill 后失效**：STA 读回来必须重新估算或 `read_spef`，
   否则退化成理想连线（1 ns 显示 −0.13，实际 −0.27 / SPEF −0.34）。
9. **OpenRCX 规则在 PDK 里**：`libs.tech/openlane/rcx_rules.info`，有了它才能
   `extract_parasitics` + `write_spef`（不是所有 PDK 都带）。
10. **EM 需要 RC 参数**：`analyze_power_grid -enable_em` 同样依赖 `set_layer_rc` 灌的 RC。

## 多 corner 结果（125 MHz，真实 SDC）

| corner | setup slack | hold slack | 结论 |
|--------|-------------|------------|------|
| tt | 4.68 ns | 0.23 ns | MET |
| ff | 5.09 ns | **0.05 ns** | MET（hold 最紧） |
| ss | **2.57 ns** | 0.84 ns | MET（setup 最紧） |

1 ns 压力（只看 setup）：tt −0.31、**ff +0.17（快角仍过）**、ss −2.99。

说明这颗设计的边界是 **ss 的 setup**；往上压频率时 ss 先挂，而 hold 在 ff 最紧——
只跑 tt 是看不出这两个方向的。

## 为什么还不能称「流片级」

1. **IR / EM 的数字建立在 5 Ω/via 假设上**：LEF 只带层电阻，脚本用 `set_layer_rc`
   补了 via 电阻；数量级可信，不是 foundry 签核值。
2. **LVS 的签核判据是 cell 级**：晶体管级已对齐器件/网数（346/177），
   但扁平 GDS 提取与 CDL 的内部节点拓扑还有残差（见 `docs/p6-topology.md`）。
3. **SPEF 单模型 + 缩放做 RC corner**：不是多套真实 RCX 模型。
4. **后仿的单元 specify 是手写的**：占位值会被 SDF 覆盖，但不是从 liberty 自动生成。
5. **OCV 是全局 derate**：没有逐角 derate 表。
6. **金属填充没进最终 GDS/DRC**：`make density` 的 route_filled.def 尚未接入 gds 流程。
7. **约束简单**：单时钟，没有多周期/假路径（复杂 SDC 只用于 RC corner 实验）。
8. **规模小**：40×40、125 MHz，数字不代表真实芯片。

## 建议的下一步

1. 晶体管 LVS 拓扑 100%（层次化提取 deck）。
2. 把金属填充并入 GDS/DRC，跑带填充的 DRC。
3. 真 RCX 多模型 + 逐角 derate 表。
4. 多周期/假路径进主 SDC。
