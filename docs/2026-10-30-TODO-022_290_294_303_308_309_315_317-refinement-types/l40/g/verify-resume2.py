"""再開2の入力・監査・原署名・義務・申し送り・workを最終照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import collections
import json
import re
from reconcile import HERE, STAGE, ROOT, digest, save, rows

MODULES = {"StandardOperatorArguments", "StandardFloatOperatorResponse",
           "StandardDecimalOperatorResponse", "StandardStringOperatorResponse",
           "StandardIntegerOperatorResponse", "StandardOperatorResponse",
           "StandardStructuralEqualityResponse", "StandardDecodeConnection"}
OIDS = {"O022", "O034", "O062", "O065", "O135", "O144"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--resume3", action="store_true", help="再開3の開始入力と検査記録を照合する")
    options = parser.parse_args()
    tmp = options.tmp
    protected = json.loads((tmp / "protected.json").read_text())
    assert all(digest(ROOT / f) == value for f, value in protected.items())
    before = json.loads((tmp / "formal-start.json").read_text())
    now = {str(p.relative_to(ROOT)): digest(p) for p in (ROOT / "formal").rglob("*")
           if p.is_file() and ".lake" not in p.parts and (not options.resume3 or p.suffix == ".lean")}
    prefix = "formal/Benitoite/Release/Refinement/"
    added = {prefix + m + ".lean" for m in MODULES}
    changed = {"formal/Benitoite.lean", prefix + "StandardDecodeBodies.lean",
               prefix + "StandardEqualityResponse.lean"}
    if options.resume3:
        assert now == before, "再開3では本番Leanを変更しない"
    else:
        assert set(now) - set(before) == added and not set(before) - set(now)
        assert {f for f in before if before[f] != now[f]} == changed
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["exit"] == 0 and audit["new_axioms"] == 0
    assert audit["private_and_generated_included"] and audit["closure_rounds"] >= 2
    assert audit["input"] == digest(STAGE / "axioms.lean")
    assert audit["script"] == digest(STAGE / "audit.py")
    assert audit["raw"] == digest(tmp / "stage-audit.log")
    assert audit["target_list"] == digest(tmp / "stage-targets.txt")
    environment = set((tmp / "stage-targets.txt").read_text().splitlines())
    assert len(environment) == audit["targets"] == sum(audit["axiom_sets"].values())
    for names in audit["axiom_sets"]:
        assert names == "none" or set(names.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice"}
    assert not re.search(r"\bsorryAx\b|error:|declaration uses .sorry.", (tmp / "stage-audit.log").read_text())
    names = []
    counts = collections.Counter()
    for part in audit["declaration_parts"]:
        assert digest(HERE / part["file"]) == {k: part[k] for k in ("bytes", "sha256")}
        for group in json.loads((HERE / part["file"]).read_text()):
            assert (ROOT / group["source"]).is_file()
            names.extend(n for n, _, _ in group["declarations"])
            counts[group["module"]] += len(group["declarations"])
    assert len(names) == len(set(names)) == audit["changed_module_declarations"]
    assert set(names) <= environment
    assert all(counts["Benitoite.Release.Refinement." + m] for m in MODULES)
    for part in audit["formal_input_parts"]:
        for entry in json.loads((HERE / part["file"]).read_text()):
            assert digest(ROOT / entry["file"]) == {k: entry[k] for k in ("bytes", "sha256")}
    units = json.loads((HERE / "unit-evidence.json").read_text())
    cases = json.loads((HERE / "case-evidence.json").read_text())
    assert len(cases) == 59
    for entries in list(units.values()) + [c["evidence"] for c in cases]:
        for entry in entries:
            assert entry["full_name"] in environment
            assert entry["name_as_written"] in (ROOT / entry["source"]).read_text().splitlines()[entry["line"] - 1]
    obligations = [r for r in rows((HERE / "obligations.md").read_text()) if re.fullmatch(r"O\d{3}", r[0])]
    assert len(obligations) == len({r[0] for r in obligations}) == 64
    assert all("担当分の局所証拠を照合" in r[2] and "一部" not in r[2] for r in obligations if r[0] in OIDS)
    handoffs = [r for r in rows((HERE / "handoffs.md").read_text()) if re.fullmatch(r"H\d{2}", r[0])]
    assert len(handoffs) == 33
    assert collections.Counter(r[2] for r in handoffs) == {"今回": 25, "継承": 3, "他段": 5}
    operators = json.loads((HERE / "resume2-operators.json").read_text())
    original = {r["name"]: r for r in json.loads((STAGE / "e/operators-r1-u28.json").read_text())["rows"]}
    assert len(operators["operators"]) == len({r["name"] for r in operators["operators"]}) == 34
    for row in operators["operators"]:
        for key in ("name", "tparams", "row_count", "range_count", "names", "params", "result", "effect"):
            assert row[key] == original[row["name"]][key], (row["name"], key)
        assert row["response"] in environment
    for entry in operators["source_inputs"]:
        assert digest(ROOT / entry["file"]) == {k: entry[k] for k in ("bytes", "sha256")}
    assert json.loads((HERE / "additional-unresolved.json").read_text())["resume2"]["closed"] == 3
    work = json.loads((HERE / ("resume3-work-check.json" if options.resume3 else "resume2-work-check.json")).read_text())
    assert work["exit"] == 0 and work["work_runs"] == 1
    assert work["command"] == ["scripts/check.sh", "--level", "work", "--base", "fcde6fe216d35c3c74fcaa8d28164df063b6aa8b"]
    assert work["raw"] == digest(tmp / "work.log") and work["selection"] == digest(tmp / "selection.log")
    output = (tmp / "work.log").read_text()
    assert "7 passed; 0 failed; 0 ignored" in output
    assert "== formal_build" in output and "selected checks passed" in output
    assert "formal_build" in (tmp / "selection.log").read_text()
    if options.resume3:
        for filename, raw in [("resume3-build-check.json", "build.log"),
                              ("resume3-trial-check.json", "trial.log"),
                              ("resume3-contrast-check.json", "contrast.log")]:
            record = json.loads((HERE / filename).read_text())
            assert record["exit"] == 0 and record["raw"] == digest(tmp / raw)
            if "source_file" in record:
                assert record["source"] == digest(HERE / record["source_file"])
        assert not (HERE / "resume1-obstruction.lean").exists()
        assert (HERE / "resume2-contrast.lean").is_file()
        stage = (STAGE / "stage-results.md").read_text()
        assert "算術 δ の追加（plan 2026-11-04、群 G 再開2）" in stage
        assert "StandardDecodeConnection.decodeThen_normal" not in stage
        assert "StandardDecodeBodies.postprocess_all" not in stage
        for token in ["0x7ff8000000000001", "0xfff8000000000001", "0x7ff8000000000000",
                      "0x7fc00001", "0xffc00001", "0x7fc00000", "roundMagnitude", "decoded", "保存の定理"]:
            assert token in stage, token
        for r in obligations:
            if r[0] in OIDS:
                assert "table_response" not in r[2]
                assert ("StandardDecode.decodeThen_normal" in r[2]) == (r[0] in {"O022", "O034", "O135", "O144"})
                assert ("StandardOperatorResponse.response" in r[2]) == (r[0] != "O135")
                assert ("StandardStructuralEqualityResponse.response" in r[2]) == (r[0] != "O135")
        for path in [STAGE / "stage-results.md", ROOT / "docs/design/01-spec/01-12-core-calculus.md",
                     ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]:
            assert "Boolean を結論するのは正常の枝だけ" in path.read_text()
        response = (HERE / "review-response.md").read_text()
        assert all(label in response for label in ["request", "report", "response", "handling"])
        assert all(label in response for label in ["中1", "中2", "軽1", "軽2", "軽3", "軽4", "情報1", "情報2", "情報3", "情報4"])
    for path in [STAGE / "audit.py"] + list(HERE.glob("*.py")):
        ast.parse(path.read_text(), filename=path.name)
    links = 0
    for path in [STAGE / "stage-results.md"] + list(HERE.glob("*.md")):
        for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", path.read_text()):
            if link.startswith(("http:", "https:", "#")):
                continue
            assert not link.startswith("/") and (path.parent / link.split("#", 1)[0]).exists(), (path.name, link)
            links += 1
    files = [p for p in HERE.iterdir() if p.is_file()]
    assert all(p.stat().st_size <= 100000 for p in files)
    assert (STAGE / "stage-results.md").stat().st_size <= 100000
    assert sum(p.stat().st_size for p in files) < 4000000
    forbidden = re.compile(re.escape("/" + "Users/") + "|" + re.escape("/" + "private/tmp/") + r"|\]\([^)]*docs/todo")
    for path in files + [STAGE / "stage-results.md", STAGE / "axioms.lean", STAGE / "audit.py"]:
        assert not forbidden.search(path.read_text()), path.name
    result = {"exit": 0, "end_utc": datetime.now(timezone.utc).isoformat(),
              "protected_files_unchanged": len(protected), "formal_added": [] if options.resume3 else sorted(added),
              "formal_modified": [] if options.resume3 else sorted(changed),
              "audited_declarations": audit["targets"], "new_axioms": 0, "actual_signatures": audit["signatures"],
              "new_module_declarations": sum(counts["Benitoite.Release.Refinement." + m] for m in MODULES),
              "obligations": 64, "technical_local_checked": 50, "independent_unresolved": 0,
              "whole_obligation_closure": 0, "handoffs": 33, "operators_closed": 34,
              "full_equality_response_contract": True, "full_equality_no_internal_failure": False,
              "decoder_connection_closed": True, "relative_links": links,
              "record_bytes": sum(p.stat().st_size for p in files), "work_runs": 1,
              "default_build_runs": 2 if options.resume3 else 1, "formal_comparison_runs": 0,
              "script": digest(Path(__file__))}
    save("resume3-verification.json" if options.resume3 else "resume2-verification.json", result)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
