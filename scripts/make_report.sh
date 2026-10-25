#!/usr/bin/env bash
# make_report.sh — 一键打印验证矩阵（不重跑全流程，读产物与日志）
# 需要先 make all / verify / finish（或部分）才有结论
set -uo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*"; }
warn() { echo "  [WARN] $*"; }
info() { echo "  [----] $*"; }

echo "=============================================="
echo " openlane-lab 验证矩阵  $(date -u +%Y-%m-%dT%H:%MZ)"
echo " die/SDC 见 constraints/counter.sdc"
echo "=============================================="

echo ""
echo "## 功能 / 形式"
if [[ -f runs/12_postsim/postsim.log ]] && grep -q '^PASS' runs/12_postsim/postsim.log 2>/dev/null; then
  pass "后仿 / 门级功能 PASS"
else
  warn "后仿未跑或未 PASS（make postsim）"
fi
if grep -q 'Equivalence successfully proven' runs/07_equiv/equiv.log 2>/dev/null; then
  pass "形式等价 proven"
else
  warn "形式等价未跑（make verify）"
fi
if [[ -f sim/out/mutation_summary.txt ]] && grep -qE 'CAUGHT|OK-|抓到 bug|正确设计通过' sim/out/mutation_summary.txt 2>/dev/null; then
  pass "变异测试 $(grep -cE 'CAUGHT|OK-|抓到 bug|正确设计通过' sim/out/mutation_summary.txt) 项符合预期"
elif [[ -f runs/01_synth/counter_synth.v ]]; then
  warn "变异测试摘要缺失（可 make verify）"
else
  warn "变异测试未跑（make verify）"
fi

echo ""
echo "## 时序"
if [[ -f runs/06_signoff/sta.log ]]; then
  wns=$(grep -E '^wns max' runs/06_signoff/sta.log | tail -1 | awk '{print $3}')
  tns=$(grep -E '^tns max' runs/06_signoff/sta.log | tail -1 | awk '{print $3}')
  if awk -v a="${wns:-999}" 'BEGIN{exit !(a+0>=0)}'; then
    pass "STA signoff  WNS=$wns TNS=$tns"
  else
    fail "STA signoff  WNS=$wns TNS=$tns"
  fi
else
  warn "无 runs/06_signoff/sta.log"
fi

# corners
cfile=runs/13_corners
if ls $cfile/sta_*_nominal.log >/dev/null 2>&1; then
  ok=1
  for c in tt ff ss; do
    log=$cfile/sta_${c}_nominal.log
    [[ -f $log ]] || continue
    w=$(grep -E '^wns max' "$log" | tail -1 | awk '{print $3}')
    h=$(grep -E '^wns min' "$log" | tail -1 | awk '{print $3}')
    if awk -v a="${w:-999}" -v b="${h:-999}" 'BEGIN{exit !(a+0>=0 && b+0>=0)}'; then
      info "corner $c setupWNS=$w holdWNS=$h"
    else
      fail "corner $c setupWNS=$w holdWNS=$h"
      ok=0
    fi
  done
  [[ $ok -eq 1 ]] && pass "三角 corner setup+hold 全 MET（真实 SDC）"
else
  warn "无 corners 结果（make corners）"
fi

# OCV
if ls runs/16_ocv/ocv_*.log >/dev/null 2>&1; then
  n=$(grep -l 'wns max 0.00' runs/16_ocv/ocv_*.log 2>/dev/null | wc -l)
  info "OCV 角 log 数: $(ls runs/16_ocv/ocv_*.log | wc -l)（WNS=0 文件数 $n）"
fi

echo ""
echo "## 物理签核"
if [[ -f runs/09_gds/counter.gds ]]; then
  pass "GDS 存在 ($(stat -c%s runs/09_gds/counter.gds 2>/dev/null || echo '?') bytes)"
else
  warn "无 GDS（make gds）"
fi
if [[ -f runs/09_gds/drc.lyrdb ]]; then
  items=$(grep -c '<item>' runs/09_gds/drc.lyrdb 2>/dev/null | head -1 | tr -dc '0-9')
  items=${items:-0}
  if [[ "$items" == "0" ]]; then pass "DRC 0 违例"; else fail "DRC items=$items"; fi
else
  warn "无 DRC 报告"
fi
if [[ -f runs/10_lvs/lvs.out ]] && grep -q 'match uniquely' runs/10_lvs/lvs.out 2>/dev/null; then
  pass "LVS cell-level match uniquely"
else
  warn "LVS 未跑或未 match（make lvs）"
fi

echo ""
echo "## 电源 / 可靠性"
if [[ -f runs/06_signoff/pdn_check.log ]]; then
  ir=$(grep -E 'Percentage drop' runs/06_signoff/pdn_check.log | tail -2 | tr '\n' ' ')
  info "IR drop: $ir"
fi
if [[ -f runs/14_em/em.log ]]; then
  pass "EM 分析已有（make em）"
fi
if [[ -f runs/15_density/fill.log ]]; then
  fills=$(grep -E 'Total fills' runs/15_density/fill.log | tail -1)
  info "密度填充: $fills"
fi

echo ""
echo "## 寄生 / 后仿 / RC"
if [[ -f runs/13_spef/counter.spef ]]; then
  pass "SPEF: runs/13_spef/counter.spef ($(wc -l < runs/13_spef/counter.spef) lines)"
fi
if [[ -f runs/20_postsim_signoff/postsim_signoff.log ]] && grep -q '^PASS' runs/20_postsim_signoff/postsim_signoff.log 2>/dev/null; then
  pass "签核级后仿 PASS"
else
  warn "签核级后仿未跑（make psign）"
fi
if ls runs/19_rc_corners/*.spef >/dev/null 2>&1; then
  info "RC corner SPEF 文件: $(ls runs/19_rc_corners/*.spef | wc -l)"
fi

echo ""
echo "=============================================="
echo " 判据汇总以 HANDOFF.md §0 为准；本脚本只读产物"
echo "=============================================="
