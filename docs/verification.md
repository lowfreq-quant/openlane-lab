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
| 7 | 版图 DRC | GDS 能不能制造 | **0 违例 / 166 类规则** | `runs/09_gds/drc.lyrdb` |
| 8 | LVS | 版图连接 = 网表连接吗 | **match uniquely**（26 dev / 32 nets） | `runs/10_lvs/lvs.out` |
| 9 | PDN 连通 | 电源网格连到每个电源脚了吗 | **2/2 网全部连通** | `runs/06_signoff/pdn_check.log` |
| 10 | IR drop / EM | 压降、电迁移够不够 | **未做**（PDK 无 RC 参数） | — |
| 11 | 后仿 / 提取 | 带真实寄生还对吗 | **未做** | — |

前 9 层都跑通了。这说明：

- 规格自洽（每拍 +1，满一圈 tick）
- 综合映射到 sky130 后功能一致（仿真 + 形式证明 + 变异测试三重）
- 物理实现可制造（0 DRC）、连接与网表一致（LVS）、电源网是通的（PDN check）

## 各层怎么复现

```bash
bash scripts/run_sim.sh          # 1 + 2
bash scripts/run_equiv.sh        # 3
bash scripts/run_mutation.sh     # 4
bash scripts/06_signoff.sh       # 5
bash scripts/run_timing_sweep.sh # 5 的压力版
bash scripts/run_gds_drc.sh      # 6（布线 DRC 在 05 的日志里）+ 7
bash scripts/dump_cts_netlist.sh && bash scripts/lvs_extract.sh && bash scripts/run_lvs.sh  # 8
```

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

## 为什么还不能称「流片级」

1. **有 PDN，但没有 IR drop / EM**：`check_power_grid` 证明两个电源网全连通，
   但 PDK 的 LEF 不带电阻参数，`analyze_power_grid` 报 `PSM-0021`，压降算不出来。
2. **LVS 是 LEF 抽象级**：Magic 用 LEF abstract 提取，比的是实例+连接，不是版图器件。
   netgen 日志里每个 cell 都是 `contains no devices` / `N disconnected pins`，正是这个原因。
   另外 LVS 的电源还是按名字短接**假定**的，不是从电源轨追出来的。
3. **没有真实寄生**：只有布线估算，没有 SPEF，也没有后仿。
4. **约束很简单**：只有一个时钟，没有多周期/假路径/复杂 IO 时序。
5. **单元模型手写**：门级仿真用的 `sim/sky130_hd_min.v` 只覆盖 10 个 cell，
   证明逻辑映射对，不等于与 foundry 模型 bit-exact。
6. **10 MHz / 5% 利用率**：数字没有工程意义，只证明流程通。
7. **没有 tap cell / decap**：防闩锁的 well tap 没插。

## 建议的下一步

1. 用 `set_layer_rc` 灌 RC，再跑 `analyze_power_grid` 出 IR drop / EM。
2. 提取 SPEF 做真 STA，再跑门级 + SDF 后仿。
3. 插 tap cell / decap（`tapcell` + `decap`），再看面积和 DRC。
4. 换 UART/SPI 这类有真实 IO 的设计。
5. 缩 die（30×30 附近）看拥塞和 slack 怎么退化。
