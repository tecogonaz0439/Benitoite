"""再開1の停止の証拠と本番入力の不変を照合する。閉鎖のverifyではない。"""
from pathlib import Path
import argparse
import hashlib
import json
import re


def digest(path):
    return {"bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    root = here.parents[3]
    before = json.loads((args.tmp / "formal-start.json").read_text())
    after = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (root / "formal").rglob("*")
             if p.is_file() and ".lake" not in p.parts}
    assert before == after, "本番のformal入力を変更した"
    proof = json.loads((here / "resume1-obstruction-check.json").read_text())
    assert proof["exit"] == 0
    assert proof["source"] == proof["historical_source"]  # 旧反例の入力。現行の対照とは異なる。
    assert (here / "resume2-contrast.lean").is_file()
    assert proof["raw"] == digest(args.tmp / "obstruction.log")
    log = (args.tmp / "obstruction.log").read_text()
    assert "sorryAx" not in log and "error:" not in log
    assert log.count("depends on axioms:") + log.count("does not depend on any axioms") == 7
    sets = re.findall(r"depends on axioms:\s*\[([^]]*)\]", log)
    assert all(set(re.findall(r"[\w.]+", s)) <=
               {"propext", "Classical.choice", "Quot.sound"} for s in sets)
    work = json.loads((here / "resume1-work-check.json").read_text())
    assert work["exit"] == 0 and work["work_runs"] == 1
    assert work["command"] == ["scripts/check.sh", "--level", "work", "--base",
                               "fcde6fe216d35c3c74fcaa8d28164df063b6aa8b"]
    assert work["raw"] == digest(args.tmp / "work.log")
    assert work["selection"] == digest(args.tmp / "selection.log")
    assert "7 passed; 0 failed; 0 ignored" in (args.tmp / "work.log").read_text()
    obligations = (here / "obligations.md").read_text()
    rows = re.findall(r"^\| (O\d{3}) \|", obligations, re.M)
    assert len(rows) == len(set(rows)) == 64
    assert len(re.findall(r"^\| H\d{2} \|", (here / "handoffs.md").read_text(), re.M)) == 33
    unresolved = json.loads((here / "additional-unresolved.json").read_text())
    assert len(unresolved["operators"]) == 34
    assert unresolved["resume1"]["closed"] == 0
    records = list(here.glob("resume1-*")) + [Path(__file__), here / "results.md",
                                             here.parent / "stage-results.md"]
    assert all(p.stat().st_size <= 100000 for p in records)
    summary = {"exit": 0, "scope": "停止記録の照合。三件の閉鎖は0",
               "production_inputs_unchanged": len(after), "proof_declarations": 7,
               "new_production_modules": 0, "new_axioms": 0,
               "obligations": 64, "handoffs": 33, "operators_unresolved": 34,
               "work_runs": 1, "stage_audit_rerun": False,
               "script": digest(Path(__file__))}
    (here / "resume1-verification.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
