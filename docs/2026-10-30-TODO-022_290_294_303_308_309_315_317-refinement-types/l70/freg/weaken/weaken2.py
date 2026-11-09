"""RV-L70.freg の中2・中3・軽1 の抜け道が塞がったことを確かめる（中2・中3 は小さい入力で Lean の入口を使う）。"""
import copy, json, runpy, shutil, sys
from pathlib import Path
repo, work = Path(sys.argv[1]), Path(sys.argv[2])
D = repo / "target/desugar-diff/run-23827"
rows = []
def trial(label, action, expect_reject=True):
    try:
        action()
    except (AssertionError, ValueError) as e:
        rows.append((label, "rejected", str(e)[:200])); return
    rows.append((label, "accepted", ""))
# 中2: batch3 の期待の拒否を変えた manifest の写しで k3・k4 を照合する。
def batch3_with(profile, change):
    B = runpy.run_path(str(repo / "crates/benitoite/tests/desugar_export/check_batch3.py"))
    original = B["check"].__globals__["BATCH3"]["rust_inputs"]
    def patched(directory, profile_name=None):
        data, expected = original(directory, profile_name)
        expected = copy.deepcopy(expected); change(expected)
        return data, expected
    B["check"].__globals__["BATCH3"] = {**B["check"].__globals__["BATCH3"], "rust_inputs": patched}
    def action():
        B["check"](D / "batch3" / profile, work / f"{profile}-results.json")
    return action
trial("batch3 control: k3 as recorded", batch3_with("k3", lambda e: None))
trial("batch3: k3 rejection removed from the expectation", batch3_with("k3", lambda e: e.pop("preparationRejected")))
trial("batch3: k3 rejection with another cause", batch3_with("k3", lambda e: e.update(preparationRejected={"scope": ["refined result"]})))
trial("batch3: k4 expected to be rejected", batch3_with("k4", lambda e: e.update(preparationRejected={"range": ["Scope.ScopeError.At"]})))
# 中3: restViolation の経路を変えた manifest の写しで照合する。
def failure_with(path):
    F = runpy.run_path(str(repo / "crates/benitoite/tests/desugar_export/check_failure.py"))
    m = json.loads((repo / "crates/benitoite/tests/desugar_export/exchange-manifest.json").read_text())
    if path is not None:
        m["batch2Failure"]["restViolationPath"] = path
    fake = work / "manifest-copy" / "check_failure.py"
    fake.parent.mkdir(parents=True, exist_ok=True)
    (fake.parent / "exchange-manifest.json").write_text(json.dumps(m))
    F["check"].__globals__["__file__"] = str(fake)
    return lambda: F["check"](repo / "target/formal-batch2-failure")
trial("restViolation control", failure_with(None))
trial("restViolation: another path", failure_with([0, 0, 1]))
# 軽1: 壊した入力が準備の段の拒否になった（run_surface が None を返す）とき。
N = runpy.run_path(str(repo / "crates/benitoite/tests/desugar_export/check_named.py"))
G = N["check_programs"].__globals__
G["run_surface"] = lambda *a, **k: None
corpus = G["read"](D / "named-programs-corpus.json")
tables = {}
for p in (D / "named-programs-builtins.json", D / "named-programs-stdlib.json"):
    t = G["read"](p); tables[p] = (t, G["keyed"](t["inputs"]))
trial("mutation: special rejection became a preparation rejection",
      lambda: G["check_special_rejections"](D, corpus, tables))
trial("mutation: program rejection became a preparation rejection",
      lambda: G["check_program_rejections"](D, corpus, tables, {"golden": {}, "random": {}}))
for r in rows: print(" | ".join(r))
shutil.rmtree(work, ignore_errors=True)
ok = all((r[1] == "accepted") == ("control" in r[0]) for r in rows)
sys.exit(0 if ok else 1)
