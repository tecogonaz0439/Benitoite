"""開始版と B_WORK の共通ビルドと探査の機能検査。性能の比較や標本採取は行わない。"""
import json
from pathlib import Path
import sys

root = Path.cwd()
sys.path.insert(0, str(root / "tools/bench/compare"))
from build import build_all
from features import configure
from run import execute, materialize, probe_command, stage_values
from scenarios import corpus, select_tier

base = "f5821c672d22b32e097ca5980a6f20fa44583722"
start = "6124775788579e60530f55fb85570f26ef7fa900"
records = build_all({"before": start, "after": base})
for record in records.values():
    assert "probe" in record, record.get("probe_unavailable")
cases = [case for case in select_tier(corpus(True), "short", quick=True)
         if case.command == "probe"]
# short で欠けた指定の点も一度だけ機能検査する。
bridge = next(case for case in corpus(False) if case.id == "bridge-shared-8")
if all(case.id != bridge.id for case in cases):
    cases.append(bridge)
# 小さい機能検査では、測定時に候補側だけへ絞る nodes の点も両版で照合する。
for case in cases:
    case.state_requires = ()
configure(cases, {state: {"timing_probe": True} for state in records})
record_dir = Path(__file__).resolve().parent
_, entries = materialize(root / "target/bench/r10.8b-probe-inputs", cases)
results = []
for case in cases:
    for state, record in records.items():
        result = execute(probe_command(case, record, entries[case.id, state]), 30)
        stage_values(case, state, result)
        results.append(dict(case=case.id, state=state, result=result, validated=True))

def relative(value):
    if isinstance(value, str):
        return value.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
    if isinstance(value, dict):
        return {key: relative(item) for key, item in value.items()}
    if isinstance(value, list):
        return [relative(item) for item in value]
    return value

report = relative(dict(start=start, base=base, builds=records, results=results,
                       note="機能検査の一回実行。性能比較の標本ではない。"))
(record_dir / "r10.8b-probe-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(dict(base=base, probe_built=True, passed=[item["state"] + "/" + item["case"] for item in results]), indent=2))
