# legacy/ — 历史脚本（不保证可跑，仅作踩坑记录）

这些脚本是当时没走通的路径，留在这里是因为它们的失败原因值得记住：

| 脚本 | 当时想干什么 | 为什么放弃 |
|------|--------------|------------|
| `run_gds.sh` | 用 OpenROAD 直接 `write_gds` 出 GDS | OpenROAD 26Q2 **没有** `write_gds` 命令，直接报 `invalid command name`；而且 `read_gds` 也没有 → 单元几何进不来 |
| `run_gds_magic.sh` | 用 Magic 读 4 MB 单元库 GDS 再写 GDS | 读整库时 Magic 段错误退出（8.3.681 也扛不住） |

现行做法：

* GDS 合成 → `scripts/run_gds_drc.sh`（KLayout：DEF + 单元 GDS 合并后 flatten）
* 版图可视化 → `dump_shapes.py` + `render_from_json.py`

保留这两个文件只是因为「为什么不那样做」比「怎么做」更难查。
