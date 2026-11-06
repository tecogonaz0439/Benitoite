"""再開2の停止根拠、候補の保存、ソースの復元、ビルドと公理監査を照合する。"""
import argparse
import json
from pathlib import Path
import re
import time
from run_checks import HERE, ROOT, digest, snapshot
from run_resume2_checks import audited_source
from verify_resume1 import audit
from candidate_sources import reconstruct


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tick = time.monotonic()
    checks = json.loads((HERE / "resume2-checks.json").read_text())
    before_path = args.tmp / "sources-resume2-final-before.json"
    initial_path = args.tmp.parent / "sources-before.json"
    before = json.loads(before_path.read_text())
    assert checks["source_snapshot"] == digest(before_path)
    assert json.loads(initial_path.read_text()) == before == snapshot()
    assert checks["production_modules_added"] == [] and checks["production_declarations_added"] == 0
    sources = reconstruct()
    manifest = json.loads((HERE / "resume2-candidate.json").read_text())
    assert len(manifest["files"]) == len(sources) == 81
    assert sum(r["before"] is None for r in manifest["files"]) == 5
    assert sum(r["patch_bytes"] for r in manifest["files"]) == 241118
    assert set(checks["checks"]) == {"build", "canonical-resume-trial", "axioms"}
    required = {"canonical-resume-trial": [
        "Benitoite.Release.Refinement.CanonicalResumeTrial." + n for n in [
            "nonempty_ref_excludes_old_shape", "canonical_obstruction", "concrete_obstruction",
            "old_canonical_statement_false"]],
        "axioms": ["Benitoite.Release.Refinement.HasTypeVQ.canonical_function"]}
    audits = {}
    for label, row in checks["checks"].items():
        assert row["exit"] == 0
        raw = args.tmp / (label + ".log")
        assert row["raw"] == digest(raw)
        text = raw.read_text()
        assert not re.search(r"\berror:", text)
        if label == "canonical-resume-trial":
            inp = args.tmp / (label + "-audit.lean")
            assert inp.read_text() == audited_source(label)
            assert row["input"] == digest(inp)
            assert row["saved_input"] == digest(HERE / (label + ".lean"))
            assert "warning:" not in text
        if label == "axioms":
            assert row["input"] == digest(HERE / "axioms.lean")
        if label in required:
            result, names = audit(text, required[label])
            listing = args.tmp / (label + "-targets.txt")
            listing.write_text("\n".join(names) + "\n")
            result["target_list"] = digest(listing)
            if label == "axioms":
                modules = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", text, re.M)
                assert sum(int(n) for _, n in modules) == result["targets"]
                result["modules"] = len(modules)
            audits[label] = result
    old_signature = ROOT / "docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l40/g/signatures-definitions.md"
    sig = old_signature.read_text()
    assert "(∃ f ts es, v = Benitoite.Release.Refinement.Val.fnRef f ts es)" in sig
    trial = (HERE / "canonical-resume-trial.lean").read_text()
    original = (HERE / "range-resume-trial.lean").read_text().replace("RangeResumeTrial", "CanonicalResumeTrial")
    assert trial.startswith("import Benitoite.Release.Refinement.InversionCore\n" + original)
    assert not re.search(r"\b(?:sorry|axiom)\b", trial)
    definitions = (HERE / "resume2-definition-candidates.md").read_text()
    for module in ["RangeCode", "RangeTyping"]:
        assert sources["formal/Benitoite/Release/Refinement/" + module + ".lean"] in definitions
    for path in HERE.rglob("*"):
        if not path.is_file() or "__pycache__" in path.parts:
            continue
        assert path.stat().st_size <= 100000, path
        text = path.read_text()
        assert str(ROOT) not in text and not re.search(r"\]\([^)]*docs/todo", text)
    result = {"restored_sources": len(before), "production_modules_added": [],
              "production_declarations_added": 0, "production_readers_adopted": 0,
              "candidate_modules": 81, "candidate_existing_modules": 76, "candidate_new_modules": 5,
              "candidate_patch_bytes": 241118, "saved_signature": digest(old_signature),
              "audits": audits, "seconds": round(time.monotonic() - tick, 3),
              "verification": "成功。開始状態の復元と停止の証拠の照合であり、K.2〜K.5の完了ではない"}
    (HERE / "resume2-audit-summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
