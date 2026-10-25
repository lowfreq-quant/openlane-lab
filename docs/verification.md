# 怎么确认这个设计靠谱

## 这是什么设计

`rtl/counter.v`：**8-bit 自由跑计数器**
- 输入：`clk`（100 ns 周期）、`rst_n`（低有效异步复位）
- 输出：`q[7:0]` 计数值、`tick`（q==0xFF 时为 1）
- 规模：8 个触发器 + 少量组合逻辑 → 综合后 23 个 sky130 单元、299 µm²

注意：文件头注释写「同步复位」，代码实际是**异步复位**（`posedge clk or negedge rst_n`）。以代码为准。

## 证据链（从软到硬）

| # | 层级 | 问什么 | 状态 | 证据 |
|---|------|--------|------|------|
| 1 | RTL 功能仿真 | 行为对不对 | **PASS**（256 步自检） | `sim/out/rtl_sim.log` |
| 2 | 门级仿真 | 综合有没有改坏功能 | **PASS**（同一 testbench） | `sim/out/gate_sim.log` |
| 3 | 形式等价 | RTL ≡ 网表能否证明 | **9/9 proven** | `runs/07_equiv/equiv.log` |
| 4 | 变异测试 | testbench 是否真能抓 bug | **3/3 抓到 + 对照通过** | `sim/out/mutation_summary.txt` |
| 5 | 静态时序 STA | 目标频率下能不能工作 | **MET @10 MHz**；1 ns 起违例 | `runs/06_signoff/sta.log`、`runs/08_timing_sweep/` |
| 6 | 布线 DRC | 布出来的线有没有短路/间距问题 | **0 violations** | `runs/05_route/openroad.log` |
| 7 | 天线 | 长线会不会在刻蚀时积累电荷 | **0 net / 0 pin 违例** | `runs/05_route/openroad.log` |
| 8 | 填充 | 空 site 有没有 fill | **730 个 fill cell** | `runs/05_route/route.def` |
| 9 | 版图 DRC | GDS 能不能制造 | **0 违例 / 166 类规则** | `runs/09_gds/drc.lyrdb` |
| 10 | LVS | 版图连接 = 网表连接吗 | **match uniquely**（26 dev / 30 nets） | `runs/10_lvs/lvs.out` |
| 11 | 阱连接 | tap 有没有把阱接到电源 | **93 tapcells，阱并入 VPWR/VGND** | `runs/02_floorplan/floorplan.def` |
| 12 | PDN 连通 | 电源网格连到每个电源脚了吗 | **2/2 网全部连通** | `runs/06_signoff/pdn_check.log` |
| 13 | IR drop | 压降够不够 | **15.5 mV / 0.86%**（via 电阻 5 Ω 假设） | `runs/06_signoff/pdn_check.log` |
| 14 | SDF 后仿 | 带延迟的布线后网表还对吗 | **PASS**（估算寄生） | `runs/12_postsim/postsim.log` |
| 15 | EM | 电流密度够不够 | **未做**（PSM 的 EM 选项没开） | — |

前 14 层都跑通了。这说明：

- 规格自洽（每拍 +1，满一圈 tick）
- 综合映射到 sky130 后功能一致（仿真 + 形式证明 + 变异测试三重）
- 物理实现可制造（0 DRC）、连接与网表一致（LVS）、电源网是通的且压降很小
- 布线后网表带延迟也能跑（SDF 后仿）

## 各层怎么复现

```bash
bash scripts/run_sim.sh          # 1 + 2
bash scripts/run_equiv.sh        # 3
bash scripts/run_mutation.sh     # 4
bash scripts/06_signoff.sh       # 5（同时出 SDF）
bash scripts/run_timing_sweep.sh # 5 的压力版
bash scripts/run_gds_drc.sh      # 9
bash scripts/dump_cts_netlist.sh && bash scripts/lvs_extract.sh && bash scripts/run_lvs.sh  # 10
bash scripts/dump_route_netlist.sh && bash scripts/run_postsim.sh   # 14
```

天线（7）和填充（8）在 `bash scripts/05_route.sh` 里，看 `runs/05_route/openroad.log`。

## 关键认知（做这些验证时踩到的）

1. **形式等价的异步复位**：`$adff` 在 SAT 里证不动，必须先 `async2sync`。
2. **LVS 金标准必须是 post-CTS 网表**：CTS 插了 3 个 clock buffer，拿综合网表比会误报。
3. **总线端口要对齐**：版图侧是 `q[0]..q[7]`，金标准如果把 `q` 当单端口，netgen 会
   "altered to match" 糊过去——看着通过，其实端口没对上。`make_golden.py` 现在会展开总线，
   输出 `Cell pin lists are equivalent`。
4. **电源脚要显式短接**：Magic 提取出来的是 `_28_/VPWR` 这种，LVS 前必须合并。
5. **DRC 的输入必须完整**：KLayout 读 DEF 时会给层自己编号（met1→5/0），
   不按层名映射回 `68/20`，GDS 里就只有单元图形、没有绕线，DRC 会安静地报 0 违例。
   修好后做了敏感性自测：往 GDS 里塞一条 0.01 µm 宽的 met2，DRC 立刻报 `m2.1` + `m2.6`，
   说明绕线层确实在检查范围里。
6. **SDF 后仿需要 specify 块**：iverilog 默认丢掉 specify，`$sdf_annotate` 直接不执行；
   模型要写 specify + 编译加 `-gspecify`，延迟才真的生效（用 5 ns 的 SDF 单独验证过）。
7. **fill 插完要再 `global_connect`**，否则新实例的电源脚是浮的。

## 为什么还不能称「流片级」

1. **IR drop 是估计值**：`check_power_grid` 证明两个电源网全连通，`analyze_power_grid` 也能跑，
   但 LEF 只带层电阻、没有 via 电阻，脚本按 **5 Ω/via** 假设灌进去；15.5 mV / 0.86% 只能看数量级。
2. **LVS 是 LEF 抽象级**：Magic 用 LEF abstract 提取，比的是实例+连接，不是版图器件。
   netgen 日志里每个 cell 都是 `contains no devices` / `N disconnected pins`，正是这个原因。
   阱（VPB/VNB）按 tap 约定并进 VPWR/VGND，所以不逐阱检查。
3. **没有 SPEF / 3D 提取**：`extract_parasitics` 需要 OpenRCX 模型（sky130A 里没有），
   所以 STA 和 SDF 都用 `estimate_parasitics -global_routing` 的估算。
4. **后仿不是签核级**：SDF 的连线延迟是估算的，单元延迟来自 liberty；模型里的 specify
   弧是手写占位（被 SDF 覆盖），不是从 liberty 自动生成。
5. **约束很简单**：只有一个时钟，没有多周期/假路径/复杂 IO 时序。
6. **单元模型手写**：门级仿真用的 `sim/sky130_hd_min.v` 只覆盖 11 个 cell，
   证明逻辑映射对，不等于与 foundry 模型 bit-exact。
7. **10 MHz / 7% 利用率**：数字没有工程意义，只证明流程通。
8. **没有 decap / 金属填充**：fill cell 有了；decap 和 `density_fill` 没做（IR 0.86%，暂无需求）。

## 建议的下一步

1. 用真实 RC（而不是假设的 via 电阻）重算 IR / EM。
2. 提取 SPEF 做真 STA，再跑门级 + SDF 后仿。
3. 插 decap / filler，再看密度和 DRC。
4. 换 UART/SPI 这类有真实 IO 的设计。
5. 缩 die（30×30 附近）看拥塞和 slack 怎么退化。
