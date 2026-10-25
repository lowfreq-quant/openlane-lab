# 首跑记录：counter → GDS（2026-09-28）

> 这是一份**历史记录**：当时只跑到 GDS，DRC/LVS 是后来补的。
> 当前状态与最新数字见 [README](../README.md) 和 [HANDOFF](../HANDOFF.md) §6。

设计：`rtl/counter.v`（8-bit 计数器，异步复位）
工艺：SkyWater SKY130 / `sky130_fd_sc_hd`
工具：Yosys 0.33 + OpenROAD 26Q2（Nix，无 Docker）+ Magic + KLayout

## 各阶段结果（首跑）

| 阶段 | 结果 |
|------|------|
| 综合 | 23 个 sky130 单元（8× `dfrtp_1`），面积 **299 µm²** |
| 布图 | Die 100×100 µm，Core ≈80×80 µm，29 行 × 173 site |
| 布局 | 23/23 合法化，利用率 **5%**，HPWL 492.6 µm |
| CTS | 插入 clkbuf，setup skew 0.25 ns，单元 23 → 26，面积 310 µm² |
| 布线 | 线长 **609 µm**，via **179**，0 违例 |
| 签核 | setup/hold slack MET，WNS/TNS = 0 |

## 关键路径（setup）

数据到达约 2 ns 量级，8 ns 时钟下裕量极大（教具性质）。
真正紧的是 **hold**（min path）：0.19 ns slack MET。

## 学习检查点对照

1. **综合后**：8 个触发器（`dfrtp_1`），组合门 and4/nand/xor/xnor/a31oi 等，共 23 个
2. **布图后**：die 100 µm；利用率 5% → 明显过松（教学用；真芯片会缩 die）
3. **布局后**：无重叠；时序已可算（MET）
4. **CTS 后**：时钟经 `buf_1` 缓冲，skew 0.25 ns（含 uncertainty）
5. **布线后**：li1/met1/met2/met3 有走线；via 179；0 违例
6. **签核后**：WNS/TNS = 0；GDS 由 KLayout 合成（单 top `counter`），DRC 0 违例，
   LVS match uniquely（这两项是后续补跑的）

## 产物位置

```
runs/01_synth/counter_synth.v     # 门级网表
runs/02_floorplan/floorplan.def
runs/03_place/place.def
runs/04_cts/cts.def
runs/05_route/route.def
runs/06_signoff/sta.log
runs/09_gds/counter.gds
runs/10_lvs/lvs.out
```

## 当时写下的"下一步"（现在完成了两项）

1. ~~用 magic 出 GDS 后跑 DRC / LVS~~ → 已完成：KLayout 出 GDS + DRC 0；Magic 提取 + netgen LVS
2. ~~时钟收到 100 MHz 看 slack 何时违例~~ → 已完成：扫到 1 ns 违例（`runs/08_timing_sweep/`）
3. 缩 die 到 30×30 µm，观察拥塞 → 未做
4. 对照 OpenLane 日志，验证读懂了每阶段 → 未做
