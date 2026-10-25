# openlane-lab — 分阶段跑通 RTL→GDS
#
#   make all      综合 → 布图 → 布局 → CTS → 布线 → STA
#   make verify   仿真 / 等价 / 变异（不需要 PDK）
#   make gds      GDS + DRC
#   make lvs      post-CTS 网表 → 提取 → netgen
#   make png      版图分层渲染
#   make check    环境自检
#   make clean    删掉可再生成的产物（.odb / lef / sim 可执行文件）

SHELL := /bin/bash
ROOT  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
S     := $(ROOT)/scripts

.PHONY: all synth floorplan place cts route signoff verify gds lvs png check clean tree help

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

png:
	klayout -b -r $(S)/dump_shapes.py
	python3 $(S)/render_from_json.py

check:
	bash $(S)/check_env.sh

clean:
	rm -rf $(ROOT)/runs/lef $(ROOT)/sim/out
	find $(ROOT)/runs -name '*.odb' -delete
	find $(ROOT)/runs -name 'shapes.json' -delete

tree:
	@find $(ROOT) -maxdepth 3 -not -path '*/.git*' -not -path '*/runs/*' | sort | head -80

help:
	@sed -n '2,10p' $(firstword $(MAKEFILE_LIST)) | sed 's/^# \{0,1\}//'
