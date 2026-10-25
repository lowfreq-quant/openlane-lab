# 数字后端流程笔记（对照脚本用）

## 你要建立的直觉

综合「把代码变成门」；后端「把门摆好、连起来、把时钟对齐」。
每个工具只做一件事；OpenLane 只是把这些串起来的编排器。

## 阶段对照

### 01 综合 (yosys)
- 输入：`counter.v` + liberty（单元延迟/功耗模型）
- 输出：门级网表 `counter_synth.v`
- 关键命令：`dfflibmap`（触发器映射）、`abc`（组合逻辑映射）
- 检查：`stat` 里的单元数、触发器数、面积

### 02 Floorplan
- 决定 die/core 大小、IO 位置、布线轨道、阱接触和电源网格
- 利用率（utilization）通常 30%–70%，太高难布线，太低浪费面积
- 看：`report_design_area`、DEF 里的 `DIEAREA`
- **tap cell**：`tapcell -distance 13 -tapcell_master ...` 插阱接触（防闩锁），本设计 93 个
- **PDN 也在这一步**：`add_global_connection` → `set_voltage_domain` → `define_pdn_grid`
  → `add_pdn_stripe`（met1 followpin + met4/met5 主干）→ `pdngen`
- 顺序：place_pins → tapcell → global_connect → pdngen（tap 必须在 PDN 前，否则电源脚接不上）
- 看：DEF 里有没有 `SPECIALNETS`；跑 `check_power_grid` 看电源网是否全连通
- IR drop 用 `analyze_power_grid`，但要先给 via 灌电阻（`set_layer_rc`），本 lab 按 5 Ω 假设

### 03 Place
- `global_placement`：解析解，可能重叠
- `detailed_placement`：合法化，挪到行上、不重叠
- 看：密度图、拥塞、WNS 是否变差、HPWL

### 04 CTS
- 插 buffer，让时钟同时到达各触发器
- 看：`report_clock_skew`、时钟缓冲数量、面积增量（本设计 23 → 26 cells）

### 05 Route
- 全局布线规划轨道 → 详细布线金属线
- 看：`Number of violations = 0`、线长、via 数
- **天线检查**：`check_antennas -verbose`，长线在等离子刻蚀时会积累电荷，必须 0 违例
- **填充**：`filler_placement` 把空 site 用 fill cell 填满（本设计 730 个），插完要
  再 `global_connect` 一次
- 本 lab 用 `estimate_parasitics -global_routing` 估算寄生，**不是**真实 RC 提取

### 06 Signoff
- STA：setup/hold、WNS/TNS
- PDN 连通性：`check_power_grid -net VPWR/VGND`，应报 `All shapes ... are connected`
- IR drop：`analyze_power_grid`（先给 via 灌电阻，见 README 局限）
- SDF：`write_sdf`，给后仿用
- 注意：GDS / DRC / LVS 不在这一步，走 `run_gds_drc.sh` 和 LVS 三连（见 README §2）

### 07–10 GDS / DRC / LVS / 后仿
- GDS 由 KLayout 合成（OpenROAD 26Q2 没有 `write_gds`），注意 DEF 层名要映射到 GDS 层号
- LVS 三连：post-CTS 网表（金标准）→ Magic 提取 → netgen 比对；阱按 tap 约定归一
- 后仿：布线后网表 + SDF，iverilog 要加 `-gspecify` 才会标注延迟

### 11 多 corner STA
- `run_corner_sta.sh`：tt/ff/ss 各用对应 liberty 重读 route.odb
- 10 MHz 下看 setup+hold（真实 SDC）；再跑 1 ns 压力只看 setup
- 经验：ss 先挂 setup、ff 先收紧 hold——只跑 tt 看不出来

## 常见坑

1. **PDK 路径不对**：工具能跑但单元库是空的 → 检查 `PDK_ROOT`，跑 `scripts/check_env.sh`
2. **时钟没约束**：STA 全是假路径 → 确认 SDC 里 `create_clock`，且脚本确实 `read_sdc`
3. **利用率过高**：place 后拥塞、route 失败 → 放大 die 或降密度
4. **Windows 直接跑**：Magic/OpenROAD 动态库问题多 → 用 WSL
5. **`report_checks -fields nets`**：OpenROAD 26Q2 不认 `nets` 字段，会打印
   `unknown field nets` 但报告照出 → 用 `-fields {slew capacitance}` 更干净
6. **合并 LEF 放 /tmp**：多个 checkout 会互相覆盖 → 本项目放 `runs/lef/`
7. **PDN 顺序错**：没先 `add_global_connection` 就 `pdngen`，网格是空壳；
   `define_pdn_grid` 不加 `-pins` 就没有顶层电源端子，`check_power_grid` 会报 PSM-0025
8. **IR drop 直接跑会失败**：LEF 没电阻参数 → `PSM-0021`，要先用 `set_layer_rc` 灌 RC
9. **读完 route.odb 不重估寄生**：插过 fill 之后 db 里的寄生失效，STA 会退回理想连线，
   数字偏乐观（1 ns 显示 −0.13，重估后 −0.27）→ 一定要再 `estimate_parasitics -global_routing`

## 和 OpenLane 对照

以后跑 OpenLane 时，在 `runs/<设计>/logs` 里找同名阶段日志，
你会看到同样的 `yosys`、`OpenROAD`、`magic` 命令被拼在一起。
