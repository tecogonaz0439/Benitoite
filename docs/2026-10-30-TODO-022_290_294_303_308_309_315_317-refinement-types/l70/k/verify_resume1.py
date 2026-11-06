"""再開1の入力、14判断の写し、全宣言の公理依存と記録を照合する。"""
import argparse
import collections
import json
from pathlib import Path
import re
import time
from run_checks import HERE, ROOT, digest, snapshot
from run_resume_checks import audited_source
from inventory import inventory


def audit(text, required):
    assert not re.search(r"\berror:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)", text)
    names = re.findall(r"^AUDIT_TARGET (.+)$", text, re.M)
    count = int(re.search(r"^AUDIT_COUNT (\d+)$", text, re.M)[1])
    assert len(names) == len(set(names)) == count > 0
    printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
    assert collections.Counter(n for n, _ in printed) == collections.Counter(names)
    assert set(required) <= set(names), set(required) - set(names)
    allowed = {"propext", "Quot.sound", "Classical.choice"}
    sets = collections.Counter(tuple(sorted(a.strip() for a in ax.split(",") if a.strip())) for _, ax in printed)
    assert all(set(s) <= allowed for s in sets)
    return {"targets": count, "private_targets": sum(n.startswith("_private.") for n in names),
            "rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", text, re.M)[1]),
            "axiom_sets": {" + ".join(s) or "none": n for s, n in sorted(sets.items())},
            "allowed_axioms": sorted(allowed), "unapproved_axioms": 0}, names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tick = time.monotonic()
    checks = json.loads((HERE / "resume1-checks.json").read_text())
    baseline = args.tmp / "sources-resume-before.json"
    assert checks["source_snapshot"] == digest(baseline)
    before = json.loads(baseline.read_text())
    after = snapshot()
    assert before == after
    assert json.loads((HERE / "readers.json").read_text()) == inventory()
    new_modules = sorted(p[7:-5].replace("/", ".") for p in set(after) - set(before) if p.endswith(".lean"))
    assert new_modules == checks["production_modules_added"] == []
    imports = (ROOT / "formal/Benitoite.lean").read_text()
    for module in new_modules:
        assert re.search(r"^import " + re.escape(module) + "$", imports, re.M)

    # 全14判断の写しには、C_Handle以外の規則の変更を混ぜない。
    original = (ROOT / "formal/Benitoite/Release/Refinement/Typing.lean").read_text()
    mutual = original[original.index("mutual\n  /-- 値の型付け"):original.index("/-- 本体の局所参照")].rstrip()
    expected = mutual.replace("(handled P B h)", "(Benitoite.Release.Refinement.LegacyResumeTrial.handledD P B h)")
    saved = (HERE / "legacy-resume-trial.lean").read_text()
    marker = "namespace Benitoite.Release.Refinement.LegacyResumeTrial.DTyping\nvariable {P : Program}\n"
    start = saved.index(marker) + len(marker)
    end = saved.index("\nend Benitoite.Release.Refinement.LegacyResumeTrial.DTyping", start)
    assert saved[start:end] == expected
    judgments = re.findall(r"^  inductive (\S+)", expected, re.M)
    assert len(judgments) == 14
    assert mutual.count("(handled P B h)") == 1
    results = {}
    required = {
        "range-resume-trial": ["Benitoite.Release.Refinement.RangeResumeTrial." + n for n in
                               ["HasTypeVQ.V_Fun", "HasTypeVQ.V_Prim", "closed_read_body", "reader_specializes"]],
        "legacy-resume-trial": ["Benitoite.Release.Refinement.LegacyResumeTrial." + n for n in
                                ["tables", "handler_input", "old_handler_typed", "d_handler_rejected",
                                 "embedding_obstruction", "selected_eq_d", "selected_repairs_inclusion"]],
        "axioms": ["Benitoite.Release.Refinement.embedHasTypeCQ"]}
    assert set(checks["checks"]) == set(required) | {"build"}, "全検査の終了前の記録を受け入れない"
    for label, row in checks["checks"].items():
        assert row["exit"] == 0
        raw = args.tmp / (label + ".log")
        assert row["raw"] == digest(raw)
        text = raw.read_text()
        if label.endswith("trial"):
            source = args.tmp / (label + "-audit.lean")
            assert source.read_text() == audited_source(label)
            assert row["input"] == digest(source)
            assert row["saved_input"] == digest(HERE / (label + ".lean"))
            assert "warning:" not in text
        if label == "axioms":
            assert row["input"] == digest(HERE / "axioms.lean")
        if label in required:
            summary, names = audit(text, required[label])
            names_file = args.tmp / (label + "-targets.txt")
            names_file.write_text("\n".join(names) + "\n")
            summary["target_list"] = digest(names_file)
            if label == "axioms":
                module_counts = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", text, re.M)
                assert sum(int(n) for _, n in module_counts) == summary["targets"]
                summary["modules"] = len(module_counts)
            results[label] = summary
        else:
            assert not re.search(r"\berror:", text)
    for name in ["range-resume-trial.lean", "legacy-resume-trial.lean"]:
        assert not re.search(r"\b(?:sorry|axiom)\b", (HERE / name).read_text())
    for path in HERE.iterdir():
        if path.is_file():
            assert path.stat().st_size <= 100000, path.name
            text = path.read_text()
            assert str(ROOT) not in text and not re.search(r"\]\([^)]*docs/todo", text)
    summary = {"sources_unchanged_since_final_checks_started": len(before),
               "production_modules_added": new_modules, "production_declarations_added": 0,
               "default_import_check": "本番の追加0。追加がある場合は根のimportを照合する",
               "copied_judgments": judgments, "changed_rules_in_trial": ["C_Handle: handledをhandledDに替える"],
               "audits": results, "seconds": round(time.monotonic() - tick, 3),
               "verification": "成功。K.2〜K.5と範囲の保存の完了を意味しない"}
    (HERE / "resume1-audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
