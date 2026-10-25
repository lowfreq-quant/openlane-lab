# 工具安装（WSL2 Ubuntu，不用 Docker）

> 目标：把 OpenROAD / Magic / Yosys / KLayout / Netgen 装成**本机命令**，
> 这样每一步都能在命令行里看见，而不是塞进一个容器黑盒。

## 0. 宿主环境

Windows 10/11 + WSL2 + Ubuntu 24.04：

```powershell
wsl --install -d Ubuntu-24.04
```

装完从开始菜单打开 Ubuntu，设好用户名密码。工程放在 Windows 盘也行
（`/mnt/c/...`），但 I/O 会比放在 WSL 内部慢，出 GDS 时能感觉到。

## 1. apt 包

```bash
sudo apt update && sudo apt install -y \
  build-essential git python3 python3-pip python3-venv \
  tcl-dev swig libreadline-dev zlib1g-dev \
  libx11-dev libcairo2-dev libglu1-mesa-dev \
  pkg-config flex bison wget curl unzip \
  yosys iverilog klayout netgen-lvs
```

注意 `netgen-lvs`：Ubuntu 里还有个 `netgen`，那是 **3D 网格生成器**，不是 LVS。

## 2. OpenROAD 与 Magic：走 Nix

Ubuntu 24.04 的 apt 没有 OpenROAD；Magic 的 apt 版本（8.3.105）又太旧，
sky130 techfile 要求 ≥ 8.3.260。用 Nix 拿新版本最省事：

```bash
bash scripts/install_openroad_nix.sh        # 装 Nix + OpenROAD
```

Magic 用同一套 Nix：

```bash
nix-env -iA nixpkgs.magic-vlsi
```

装完确认（`~/.nix-profile/bin` 由 `scripts/env.sh` 自动加进 PATH）：

```bash
openroad -version     # 26Q2
magic -dnull -noconsole -rcfile /dev/null <<< 'puts [version]; quit -noprompt'
```

## 3. PDK：走 volare

```bash
python3 -m venv ~/.venv-asic
~/.venv-asic/bin/pip install volare
bash scripts/fetch_pdk.sh
```

默认版本 `7519dfb04400f224f140749cda44ee7de6f5e095`（open_pdks 构建），
装到 `~/.volare/sky130A`。`scripts/env.sh` 认这个位置；想换路径就 `export PDK_ROOT=...`。

## 4. 自检

```bash
bash scripts/check_env.sh
```

它会把工具、PDK 七个关键文件、工程产物逐条列 OK/MISS。

## 5. 本工程实际使用的版本

| 工具 | 版本 | 来源 | 用途 |
|------|------|------|------|
| Yosys | 0.33 | apt | 综合、形式等价 |
| Icarus Verilog | 12.0 | apt | RTL / 门级仿真 |
| OpenROAD | 26Q2 | Nix `nixpkgs.openroad` | 布图/布局/CTS/布线/STA |
| Magic | 8.3.681 | Nix `nixpkgs.magic-vlsi` | DEF+LEF 提取（LVS 版图侧） |
| KLayout | 0.28.16 | apt | GDS 合成、DRC、几何导出 |
| Netgen | 1.5.133 | apt `netgen-lvs` | LVS 比对 |
| volare | 0.20.6 | pip | PDK 管理 |
| Python | 3.12 | apt | 辅助脚本、PIL 渲染 |

## 6. 常见问题

| 现象 | 原因 | 处理 |
|------|------|------|
| `openroad: command not found` | `~/.nix-profile/bin` 不在 PATH | `source scripts/env.sh`，或重开 shell |
| Magic 报 techfile 版本不够 | 用了 apt 的 8.3.105 | 换 Nix 的 `magic-vlsi` |
| `library already exists` / 丢 site | tlef 和 lef 分开读 | 先跑 `scripts/merge_lef.sh` |
| `write_gds: invalid command name` | OpenROAD 26Q2 没这个命令 | 用 KLayout 合成（`run_gds_drc.sh`） |
| KLayout 出图是空的 | batch 下 `save_image` 不可靠 | 用 `dump_shapes.py` + `render_from_json.py` |
| `netgen` 跑起来像网格工具 | 名字撞了 | 用 `netgen-lvs` |
