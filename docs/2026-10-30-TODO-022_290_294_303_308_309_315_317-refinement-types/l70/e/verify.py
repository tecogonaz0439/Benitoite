# -*- coding: utf-8 -*-
"""追加モジュール・既定ビルド・全環境の公理監査・記録の対応を照合する。Git は呼ばない。"""
import argparse
import collections
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode = True
from inventory import HERE, ROOT, DESIGN, baseline, digest, inspect
from branch_inventory import check as check_branches


def write_chunks(stem, rows):
    chunks, chunk = [], []
    for row in rows:
        trial = json.dumps(chunk + [row], ensure_ascii=False, indent=1) + "\n"
        if len(trial.encode()) > 90_000:
            chunks.append(chunk)
            chunk = []
        chunk.append(row)
    if chunk:
        chunks.append(chunk)
    for old in HERE.glob(stem + "-*.json"):
        old.unlink()
    result = []
    for index, items in enumerate(chunks):
        path = HERE / f"{stem}-{index:02}.json"
        path.write_text(json.dumps(items, ensure_ascii=False, indent=1) + "\n")
        result.append({"file": path.name, "bytes": path.stat().st_size, "sha256": digest(path)})
    return result


def verify(tmp):
    assert check_branches() == 72
    found = inspect()
    modules = found["modules"]
    assert json.loads((HERE / "audit-modules.json").read_text()) == modules
    root_before = (HERE / "baseline-root.txt").read_text()
    root_after = (ROOT / "formal/Benitoite.lean").read_text()
    assert root_after.startswith(root_before), "根の既存 import を変えた"
    suffix = root_after[len(root_before):].splitlines()
    assert sorted(suffix) == sorted("import " + m for m in modules)
    assert all(root_after.splitlines().count("import " + m) == 1 for m in modules)
    assert digest(HERE / "baseline-root.txt") == baseline()["formal/Benitoite.lean"]

    edits = json.loads((HERE / "design-edits.json").read_text())
    assert set(edits) <= DESIGN
    for path, replacements in edits.items():
        text = (ROOT / path).read_text()
        for item in reversed(replacements):
            assert text.count(item["after"]) == 1, path
            assert not re.search(r"\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|docs/todo|改造", item["after"])
            text = text.replace(item["after"], item["before"], 1)
        import hashlib
        assert hashlib.sha256(text.encode()).hexdigest() == baseline()[path], path

    forbidden = r"\bsorry\b|#eval|#check|#print|maxRecDepth|maxHeartbeats|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b"
    for path in found["added"]:
        src = (ROOT / path).read_text()
        assert not re.search(forbidden, src), path
    build_path, audit_path = tmp / "build.log", tmp / "axioms.log"
    build, audit = build_path.read_text(), audit_path.read_text()
    assert re.search(r"^rc=0$", build, re.M), "既定ビルドの終了値"
    assert "error:" not in build
    jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", build)[1])
    for module in modules:
        assert not re.search(rf"warning: {re.escape(module.replace('.', '/'))}\.lean:", build), module
    assert re.search(r"^rc=0$", audit, re.M), "公理監査の終了値"
    assert not re.search(r"error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", audit)
    targets = re.findall(r"^AUDIT_TARGET (.+)$", audit, re.M)
    assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", audit, re.M)[1])
    printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
    assert collections.Counter(n for n, _ in printed) == collections.Counter(targets)
    sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(',') if x.strip())) for _, ax in printed)
    assert all(set(ax) <= {"propext", "Quot.sound", "Classical.choice"} for ax in sets), sets
    environment = dict((m, int(n)) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", audit, re.M))
    assert sum(environment.values()) == len(targets)
    own = dict((m, int(n)) for m, n in re.findall(r"^OWN_MODULE (\S+) (\d+)$", audit, re.M))
    assert sorted(own) == sorted(modules)
    declarations = re.findall(r"^OWN_DECL (\S+) (\S+) (\d+) (.+)$", audit, re.M)
    assert sum(own.values()) == len(declarations)
    assert len(set(n for _, _, _, n in declarations)) == len(declarations)
    required = json.loads((HERE / "required-names.json").read_text())
    assert required and set(required) <= set(targets)
    assert set(required) == set(re.findall(r"^SIGNATURE_END (.+)$", audit, re.M))
    dependencies = re.findall(r"^OWN_DEP (\S+) (\S+)$", audit, re.M)
    readers = collections.defaultdict(set)
    for source, target in dependencies:
        if source != target:
            readers[target].add(source)
    public_entries = json.loads((HERE / "public-entries.json").read_text())
    assert set(public_entries) <= set(targets)
    assert all(readers[name] for name in public_entries), [name for name in public_entries if not readers[name]]
    declarations_files = write_chunks("declarations", declarations)
    cases = json.loads((HERE / "cases.json").read_text())
    assert sum(cases["surface_rules"].values()) == 95
    assert sum(cases["interpolation_rules"].values()) == 14
    assert len(cases["old_theorems"]) == 17
    assert all(item["new"] in targets for item in cases["old_theorems"])

    for path in HERE.iterdir():
        if path.is_file():
            assert path.stat().st_size <= 100_000, path.name
            text = path.read_text()
            assert "/Us" + "ers/" not in text and "/priv" + "ate/tmp" not in text, path.name
            assert not re.search(r"\]\([^)]*docs/todo", text), path.name
    total = sum(p.stat().st_size for p in HERE.iterdir() if p.is_file())
    assert total < 5_000_000
    summary = {
        "b_work": "aab9025f1f366d6d190298869add18181af7eeb6",
        "baseline_files": len(baseline()), "changed": found["changed"], "new_modules": len(modules),
        "build": {"jobs": jobs, "bytes": build_path.stat().st_size, "sha256": digest(build_path)},
        "audit": {"targets": len(targets), "own_declarations": len(declarations),
                  "private": sum(n.startswith("_private.") for _, _, _, n in declarations),
                  "sets": {','.join(k) or '(none)': v for k, v in sorted(sets.items())},
                  "bytes": audit_path.stat().st_size, "sha256": digest(audit_path),
                  "environment_modules": len(environment), "own_modules": own,
                  "declarations": declarations_files},
        "sources": {p: digest(ROOT / p) for p in found["added"]},
        "public_entries": {n: len(readers[n]) for n in public_entries},
        "record_bytes": total,
    }
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps({"ok": True, "modules": len(modules), "declarations": len(declarations),
                      "environment_declarations": len(targets), "build_jobs": jobs, "record_bytes": total}, indent=1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    verify(parser.parse_args().tmp)
