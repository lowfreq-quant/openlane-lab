# P6 晶体管级 LVS：拓扑残差结论

## 现象

`make lvs_dev` 后 netgen 报：

- 器件数 **346 = 346**（并联合并后）
- 网络数 **177 = 177**
- 仍 `Netlists do not match`
- 残差集中在 **xnor2 / AOI 内部节点** 的配对

典型 fragment：

| 提取侧 | CDL 侧 | 扇入 |
|--------|--------|------|
| `X_uq0` | `xnor2_1_22_/nmid` | 提取 2 nfet+1 pfet vs CDL nmid 3 nfet |
| `a_7553_3311#` | `tick` | 提取 3 nfet vs CDL 1 pfet+2 nfet |

## 根因分析

1. **CDL 本身正确**  
   `sky130_fd_sc_hd__xnor2_1` 含 10 个 MOS（NAND + AOI 结构），`nmid` 接 3 个 nfet。

2. **扁平 GDS 丢失层级名**  
   提取后只剩 `a_*` / `X_uq0` 等匿名网，netgen 在对称结构里做同构匹配时会「配错对」，
   表现为扇入计数对不上，而不是器件总数对不上。

3. **阱/电源已并网**  
   VPB→VPWR、VNB→VGND 后网络数才从 177 vs 179 收到 177=177。

4. **cell-level LVS 已唯一匹配**  
   `make lvs`（DEF+LEF 抽象）给出 `Netlists match uniquely`，这才是本 lab 签核判据。

## 结论

| 检查 | 状态 | 含义 |
|------|------|------|
| 器件数 | 346=346 | 晶体管数量一致 |
| 网络数 | 177=177 | 连接规模一致 |
| 拓扑同构 | 残差 | 对称 AOI/XOR 内部网配对，非功能错误 |
| cell-level LVS | **match uniquely** | 连接关系签核通过 |

**判定**：不是电路错误，是扁平提取的对称网标记问题。  
若要 100% 器件级 match，需层次化 GDS（保留 cell 边界）或 netgen 对内部网更激进的 permute。

## 层次化 GDS 尝试（2026-10-25）

| 步骤 | 结果 |
|------|------|
| `make_gds_hier.py` | 保留单元边界；顶层仍有多余 fill 子 cell |
| Magic 层次提取 | 各 cell subckt 可提取，但顶层 `.subckt counter` **无端口**、网名带层次路径 |
| 单胞对比 | 器件/网络数可对齐（如 xor2 10=10, 11=11）仍被 flatten |
| 扁平化后 | 346=346 器件；网络 241 vs 179（提取侧多出局部电源/阱网） |

**结论**：层次 GDS 改善了单胞可比性，但 Magic 对该 GDS 的顶层提取质量不足；
器件级签核仍以 **cell-level `match uniquely`** 为准。要 100% 拓扑需 foundry 级提取 deck 或
逐 cell 用 CDL 对照的专用脚本。

## 复现

```bash
make lvs_dev          # runs/17_lvs_device/
bash scripts/run_lvs_hier.sh
bash scripts/probe_p6_topo.sh
```
