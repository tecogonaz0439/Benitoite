"""停止時の記録、全環境監査と本番の非変更を再照合する。gitは呼ばない。"""
import argparse
import collections
import json
from pathlib import Path
import re
import time
from run_checks import HERE, ROOT, digest, snapshot
from inventory import inventory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tick = time.monotonic()
    checks = json.loads((HERE / "checks.json").read_text())
    source = args.tmp / "sources-before.json"
    assert checks["source_snapshot"] == digest(source)
    before = json.loads(source.read_text())
    assert before == snapshot(), "検査開始時から本番か写しが変わった"
    assert json.loads((HERE / "readers.json").read_text()) == inventory()
    added = set(snapshot()) - set(before)
    new_modules = sorted(p[7:-5].replace("/", ".") for p in added if p.endswith(".lean"))
    assert new_modules == checks["production_modules_added"] == []
    # 本番を足した場合に、既定importから漏れているモジュールを受け入れない。
    imports = (ROOT / "formal/Benitoite.lean").read_text()
    for module in new_modules:
        assert re.search(r"^import " + re.escape(module) + "$", imports, re.M)
    local_names = []
    for label, row in checks["checks"].items():
        assert row["exit"] == 0, (label, row["exit"])
        raw = args.tmp / (label + ".log")
        assert digest(raw) == row["raw"]
        text = raw.read_text()
        assert not re.search(r"\berror:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)", text)
        if label.endswith("trial"):
            assert "warning:" not in text
            assert row["input"] == digest(HERE / (label + ".lean"))
            printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
            declarations = re.findall(r"^(?:def|theorem) (\S+)", (HERE / (label + ".lean")).read_text(), re.M)
            assert sorted(n.split(".")[-1] for n, _ in printed) == sorted(declarations)
            assert all(set(a.strip() for a in ax.split(",") if a.strip()) <=
                       {"propext", "Quot.sound", "Classical.choice"} for _, ax in printed)
            local_names.extend(n for n, _ in printed)
        if label == "axioms":
            assert row["input"] == digest(HERE / "axioms.lean")
    reference = json.loads((HERE / "reference-check.json").read_text())
    assert reference["exit"] == 0
    assert reference["input"] == digest(HERE.parent / "b/effect-counterexample.lean")
    assert reference["raw"] == digest(args.tmp / "reference-trial.log")
    audit = (args.tmp / "axioms.log").read_text()
    names = re.findall(r"^AUDIT_TARGET (.+)$", audit, re.M)
    count = int(re.search(r"^AUDIT_COUNT (\d+)$", audit, re.M)[1])
    assert len(names) == len(set(names)) == count
    dependencies = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
    assert collections.Counter(n for n, _ in dependencies) == collections.Counter(names)
    allowed = {"propext", "Quot.sound", "Classical.choice"}
    sets = collections.Counter(tuple(sorted(a.strip() for a in axioms.split(",") if a.strip())) for _, axioms in dependencies)
    assert all(set(axioms) <= allowed for axioms in sets)
    module_counts = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", audit, re.M)
    assert sum(int(n) for _, n in module_counts) == count
    target_file = args.tmp / "audit-targets.txt"
    target_file.write_text("\n".join(names) + "\n")
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        content = path.read_text()
        assert str(ROOT) not in content and not re.search(r"\]\([^)]*docs/todo", content)
    summary = {"base": checks["base"], "sources_unchanged_since_checks_started": len(before),
               "production_modules_added": new_modules, "production_declarations_added": 0,
               "default_import_check": "本番への追加0。追加がある場合は根のimportを照合する",
               "audit_targets": count, "private_targets": sum(n.startswith("_private.") for n in names),
               "audit_modules": len(module_counts), "audit_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", audit, re.M)[1]),
               "target_list": digest(target_file),
               "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
               "allowed_axioms": sorted(allowed), "unapproved_axioms": 0,
               "trial_declarations": local_names,
               "seconds": round(time.monotonic() - tick, 3),
               "verification": "成功。K.1(c)の停止を解消したことは意味しない"}
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
