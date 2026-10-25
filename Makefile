# openlane-lab — 分阶段跑通 RTL→GDS
#
#   make all      综合 → 布图(+tap+PDN) → 布局 → CTS → 布线(+天线+填充) → 签核
#   make verify   仿真 / 等价 / 变异（不需要 PDK）
#   make gds      GDS + DRC
#   make lvs      post-CTS 网表 → 提取 → netgen
#   make postsim  布线后网表 + SDF 时序后仿
#   make corners  多工艺角 STA（tt/ff/ss）
#   make spef     OpenRCX 真寄生 → SPEF（替代估算）+ 1ns 压力对比
#   make em       电迁移分析（analyze_power_grid -enable_em）
#   make density  金属密度填充（density_fill）
#   make ocv      OCV derate + 8 电压/温度 corner STA
#   make lvs_dev  晶体管级 LVS（GDS 提取 vs CDL）
#   make rc       多 RC corner SPEF + 复杂 SDC STA
#   make psign    签核级后仿（SPEF SDF）
#   make report   打印验证矩阵（只读产物，不重跑）
#   make finish   gds + lvs + postsim + corners + spef + em + density
#   make png      版图分层渲染
#   make check    环境自检
#   make sanitize 把 runs/ 日志里的本机路径换成占位符（提交前跑）
#   make clean    删掉可再生成的产物（.odb / lef / sim 可执行文件）

SHELL := /bin/bash
ROOT  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
S     := $(ROOT)/scripts

.PHONY: all synth floorplan place cts route signoff verify gds lvs postsim corners spef em density ocv lvs_dev rc psign report finish png check sanitize clean tree help

all: synth floorplan place cts route signoff

synth:      ; bash $(S)/01_synth.sh
floorplan:  ; bash $(S)/02_floorplan.sh
place:      ; bash $(S)/03_place.sh
cts:        ; bash $(S)/04_cts.sh
route:      ; bash $(S)/05_route.sh
signoff:    ; bash $(S)/06_signoff.sh

verify:
	bash $(S)/run_sim.sh
	bash $(S)/run_equiv.sh
	bash $(S)/run_mutation.sh

gds:
	bash $(S)/run_gds_drc.sh

lvs:
	bash $(S)/dump_cts_netlist.sh
	bash $(S)/lvs_extract.sh
	bash $(S)/run_lvs.sh

postsim:
	bash $(S)/dump_route_netlist.sh
	bash $(S)/run_postsim.sh

corners:
	bash $(S)/run_corner_sta.sh

spef:
	bash $(S)/run_spef.sh

em:
	bash $(S)/run_em.sh
	python3 $(S)/analyze_em.py

density:
	bash $(S)/run_density_fill.sh

ocv:
	bash $(S)/run_ocv_sta.sh

lvs_dev:
	bash $(S)/run_lvs_device.sh

rc:
	bash $(S)/run_rc_corners.sh

psign:
	bash $(S)/run_postsim_signoff.sh

report:
	bash $(S)/make_report.sh

finish: gds lvs postsim corners spef em density ocv

png:
	klayout -b -r $(S)/dump_shapes.py
	python3 $(S)/render_from_json.py

check:
	bash $(S)/check_env.sh

sanitize:
	bash $(S)/sanitize_repo.sh

clean:
	rm -rf $(ROOT)/runs/lef $(ROOT)/sim/out $(ROOT)/runs/12_postsim
	find $(ROOT)/runs -name '*.odb' -delete
	find $(ROOT)/runs -name 'shapes.json' -delete

tree:
	@find $(ROOT) -maxdepth 3 -not -path '*/.git*' -not -path '*/runs/*' | sort | head -80

help:
	@sed -n '2,13p' $(firstword $(MAKEFILE_LIST)) | sed 's/^# \{0,1\}//'
