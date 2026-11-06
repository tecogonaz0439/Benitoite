"""再開3の復元・保存候補・反例と二つの監査の記録を照合する。"""
import argparse
import collections
import json
from pathlib import Path
import re
import time
from run_checks import HERE, ROOT, digest, snapshot
from replay_resume3 import reconstruct, baseline_files, audit_source


def audit(raw, required=()):
    assert not re.search(r"\berror:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)", raw)
    names = re.findall(r"^AUDIT_TARGET (.+)$", raw, re.M)
    counts = [int(n) for n in re.findall(r"^AUDIT_COUNT (\d+)$", raw, re.M)]
    assert len(names) == len(set(names)) == sum(counts) > 0
    printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", raw, re.M | re.S)
    assert collections.Counter(n for n, _ in printed) == collections.Counter(names)
    assert set(required) <= set(names), set(required) - set(names)
    sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(",") if x.strip())) for _, ax in printed)
    assert all(set(s) <= {"propext", "Quot.sound", "Classical.choice"} for s in sets)
    modules = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", raw, re.M)
    assert sum(int(n) for _, n in modules) == counts[0]
    summary = {"targets": len(names), "counts": counts,
               "private_targets": sum(n.startswith("_private.") for n in names),
               "modules": len(modules), "rounds": [int(n) for n in re.findall(r"^AUDIT_ROUNDS (\d+)$", raw, re.M)],
               "axiom_sets": {" + ".join(s) or "none": n for s,n in sorted(sets.items())},
               "unapproved_axioms": 0}
    return summary, names, {m for m,_ in modules}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--replay", type=Path, required=True)
    args = parser.parse_args()
    tick = time.monotonic()
    baseline = baseline_files()
    for name, ha in baseline.items():
        assert digest(ROOT/name)["sha256"] == ha, name
    before = json.loads((args.tmp/"sources-before.json").read_text())
    assert before == snapshot()
    checks = json.loads((HERE/"resume3-checks.json").read_text())
    assert checks["source_snapshot"] == digest(args.tmp/"sources-before.json")
    assert set(checks["checks"]) == {"build", "axioms"}
    for label,row in checks["checks"].items():
        assert row["exit"] == 0 and row["raw"] == digest(args.tmp/(label+".log"))
    assert "Build completed successfully" in (args.tmp/"build.log").read_text()
    full,names,_ = audit((args.tmp/"axioms.log").read_text(),
                          ["Benitoite.Release.Refinement.Def.WellTyped.inputs"])
    targets = args.tmp/"audit-targets.txt";targets.write_text("\n".join(names)+"\n")
    full["target_list"] = digest(targets)
    sources = reconstruct()
    manifest = json.loads((HERE/"resume3-candidate.json").read_text())["files"]
    assert len(manifest) == len(sources) == 92
    assert all("/Surface/" not in r["file"] for r in manifest)
    assert all(not r["file"].startswith("formal/Benitoite/Release/") or
               r["file"].startswith("formal/Benitoite/Release/Refinement/") for r in manifest)
    new = {r["file"][7:-5].replace("/", ".") for r in manifest if r["before"] is None}
    assert len(new) == 5 and not (set(snapshot())-set(before))
    seen = set()
    def walk(module):
        if module in seen:
            return
        seen.add(module)
        name = "formal/"+module.replace(".", "/")+".lean"
        path = ROOT/name
        text = sources.get(name, path.read_text() if path.exists() else "")
        for dep in re.findall(r"^import\s+([A-Za-z0-9_.]+)", text, re.M):
            walk(dep)
    walk("Benitoite")
    assert new <= seen
    replay = json.loads((args.replay/"replay.json").read_text())
    assert replay["audit"]["exit"] == 0
    assert replay["audit"]["raw"] == digest(args.replay/"candidate-audit.log")
    assert replay["audit"]["input"] == digest(args.replay/"candidate-audit.lean")
    assert (args.replay/"candidate-audit.lean").read_text() == audit_source()
    for row in replay["commands"]:
        assert row["exit"] == 0
        assert row["raw"] == digest(args.replay/(row["module"]+".log"))
        assert row["input"] == digest(args.replay/"src"/(row["module"].replace(".", "/")+".lean"))
    assert new <= {row["module"] for row in replay["commands"]}
    required = ["Benitoite.Release.Refinement.DefinitionInputsResumeTrial."+n for n in
                ["OldInputsStatement", "not_reader_regular", "reader_obstruction", "old_inputs_statement_false",
                 "range_context_inhabited", "concrete_call"]]
    candidate,cnames,modules = audit((args.replay/"candidate-audit.log").read_text(), required)
    assert new <= modules
    targets = args.replay/"candidate-targets.txt";targets.write_text("\n".join(cnames)+"\n")
    candidate["target_list"] = digest(targets)
    for p in HERE.rglob("*"):
        if not p.is_file() or "__pycache__" in p.parts:
            continue
        assert p.stat().st_size <= 100000, p
        assert str(ROOT) not in p.read_text(), p
    for name in new:
        assert not re.search(r"\b(?:sorry|axiom)\b", sources["formal/"+name.replace(".", "/")+".lean"])
    output = {"sources_restored": len(baseline), "final_snapshot_count": len(before),
              "candidate_files": len(manifest), "candidate_new_modules": sorted(new),
              "candidate_compiled_modules": len(replay["commands"]), "production_modules_added": [],
              "candidate_default_imports": "五つすべて既定importから到達する",
              "production_declarations_added": 0, "full_audit": full, "candidate_closure_audit": candidate,
              "trial_declarations": required, "replay_seconds": replay["seconds"],
              "seconds": round(time.monotonic()-tick,3),
              "verification": "成功。K.2〜K.5の完成ではなく、停止点と保存・復元・監査の照合"}
    (HERE/"resume3-audit-summary.json").write_text(json.dumps(output, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
