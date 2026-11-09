"""formal_interval.range_counts が分類の外の拒否と件数の不足を断ることを、壊した写しで確かめる。"""
import json, runpy, shutil, sys
from pathlib import Path
repo, work = Path(sys.argv[1]), Path(sys.argv[2])
F = runpy.run_path(str(repo / "scripts/check/formal_interval.py"))
D = repo / "target/desugar-diff/run-23827"
def copy_inputs():
    if work.exists(): shutil.rmtree(work)
    for name in ("range-source-comparison/summary.json", "range-known-differences/summary.json"):
        (work / name).parent.mkdir(parents=True, exist_ok=True); shutil.copy2(D / name, work / name)
    shutil.copytree(D / "range-budget-comparison", work / "range-budget-comparison")
def summary(): return json.loads((work / "range-budget-comparison/summary.json").read_text())
def save(s): (work / "range-budget-comparison/summary.json").write_text(json.dumps(s))
rows = []
def trial(label, mutate):
    copy_inputs(); mutate()
    try:
        out = F["range_counts"](work)
    except AssertionError as e:
        rows.append((label, "rejected", str(e))); return
    rows.append((label, "accepted", json.dumps(out["rangeBudgetPreparationRejected"])))
trial("control", lambda: None)
def log_outside():
    p = work / "range-budget-comparison/last-run-exceeded/surfaceCheck.log"
    p.write_text("surfaceCheck: builtin signature disagrees with the standard table: [Foo.bar]\n")
trial("log: cause outside the table", log_outside)
def log_other():
    p = work / "range-budget-comparison/last-run-exceeded/surfaceCheck.log"
    p.write_text("surfaceCheck: stdlib declaration is ill-formed\n")
trial("log: rejection of another kind", log_other)
def summary_disagrees():
    s = summary(); c = next(c for c in s["cases"] if c["name"] == "last-run-exceeded")
    c["reports"][0]["preparationRejected"]["causes"] = ["refined result"]; save(s)
trial("summary causes differ from the log", summary_disagrees)
def short():
    s = summary(); c = next(c for c in s["cases"] if c["name"] == "last-run-exceeded")
    c["lean"] = "skipped"; s["leanPreparationRejectedCases"] = 1; save(s)
trial("one Lean case neither compared nor classified", short)
def count_lie():
    s = summary(); s["leanPreparationRejectedCases"] = 1; save(s)
trial("summary count disagrees with the cases", count_lie)
def moved_to_compared():
    s = summary(); c = next(c for c in s["cases"] if c["name"] == "last-run-exceeded")
    c["lean"] = "compared"; s["leanComparedCases"] = s["requiredReasonComparisons"] = 1
    s["leanPreparationRejectedCases"] = 1; save(s)
trial("expected rejected case reported as compared", moved_to_compared)
def other_classified_cause():
    log = "surfaceCheck: builtin signature disagrees with the standard table: [Http.sendIn]\n"
    (work / "range-budget-comparison/last-run-exceeded/surfaceCheck.log").write_text(log)
    s = summary(); c = next(c for c in s["cases"] if c["name"] == "last-run-exceeded")
    c["reports"][0]["preparationRejected"] = {"names": ["Http.sendIn"], "causes": ["Http.sendIn"]}; save(s)
trial("rejection with another classified cause", other_classified_cause)
for r in rows: print(" | ".join(r))
shutil.rmtree(work)
sys.exit(0 if rows[0][1] == "accepted" and all(r[1] == "rejected" for r in rows[1:]) else 1)
