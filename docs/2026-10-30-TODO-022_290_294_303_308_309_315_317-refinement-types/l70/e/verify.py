# -*- coding: utf-8 -*-
"""追加モジュール・既定ビルド・全環境の公理監査・記録の対応を照合する。Git は呼ばない。"""
import argparse
import collections
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode = True
from inventory import HERE, ROOT, DESIGN, B_WORK, baseline, digest, inspect, path_of
from branch_inventory import check as check_branches


def write_inventory(tmp, rows):
    path = tmp / "declarations.json"
    assert not path.exists(), "群末の宣言一覧を上書きしない"
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n")
    return {"file": path.name, "count": len(rows), "bytes": path.stat().st_size, "sha256": digest(path)}


def verify(tmp):
    assert check_branches() == 72
    found = inspect(tmp)
    modules = found["modules"]
    assert json.loads((HERE / "audit-modules.json").read_text()) == modules
    root_before = (tmp / "baseline-root.txt").read_text()
    root_after = (ROOT / "formal/Benitoite.lean").read_text()
    assert root_after.startswith(root_before), "根の既存 import を変えた"
    suffix = root_after[len(root_before):].splitlines()
    added_modules = [p.removeprefix("formal/").removesuffix(".lean").replace("/", ".") for p in found["added"]]
    assert sorted(suffix) == sorted("import " + m for m in added_modules)
    assert all(root_after.splitlines().count("import " + m) == 1 for m in modules)
    assert digest(tmp / "baseline-root.txt") == baseline(tmp)["formal/Benitoite.lean"]

    edits = json.loads((HERE / "design-edits.json").read_text())
    assert set(edits) <= DESIGN
    for path, replacements in edits.items():
        text = (ROOT / path).read_text()
        for item in reversed(replacements):
            assert text.count(item["after"]) == 1, path
            assert not re.search(r"\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|docs/todo|改造", item["after"])
            text = text.replace(item["after"], item["before"], 1)
        import hashlib
        assert hashlib.sha256(text.encode()).hexdigest() == baseline(tmp)[path], path

    forbidden = r"\bsorry\b|#eval|#check|#print|maxRecDepth|maxHeartbeats|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b"
    for path in [path_of(m) for m in modules]:
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
    # 匿名exampleは環境に残らないが、同じ既定ビルドがその証明を検査する。
    example_readers = collections.Counter()
    for item in json.loads((HERE / "example-readers.json").read_text()):
        assert item["source"] in {path_of(m) for m in modules}
        text = (ROOT / item["source"]).read_text()
        tops = list(re.finditer(r"(?m)^(?:example\b|(?:private )?(?:def|theorem|abbrev)\b|end\b)", text))
        blocks = [text[m.start():tops[i+1].start() if i+1 < len(tops) else len(text)]
                  for i, m in enumerate(tops) if m.group().startswith("example")]
        import hashlib
        matches = [block for block in blocks if hashlib.sha256(block.encode()).hexdigest() == item["example_sha256"]]
        assert len(matches) == 1
        for name, reference in item["entries"].items():
            assert name in public_entries
            assert re.search(r"(?<![A-Za-z0-9_.])" + re.escape(reference) + r"\b", matches[0]), name
            example_readers[name] += 1
    assert all(readers[name] or example_readers[name] for name in public_entries), [
        name for name in public_entries if not readers[name] and not example_readers[name]]
    # 写しの対応表は全所有モジュールを明記する。
    correspondence = (ROOT / "docs/design/07-quality/07-04-formal-semantics.md").read_text()
    correspondence = correspondence[correspondence.index("篩を含む形式化の対応は次表"):]
    correspondence = correspondence[:correspondence.index("以下の既存の表は")]
    listed = set(re.findall(r"(?<![A-Za-z.])(?:Surface\.[A-Za-z]+|Coverage[A-Za-z]*)", correspondence))
    assert all(m.removeprefix("Benitoite.Release.Refinement.") in listed for m in modules)
    # ビルドと監査の間でソースを替えていない。
    import hashlib
    source_hashes = {path_of(m): digest(ROOT / path_of(m)) for m in modules}
    source_hashes["formal/Benitoite.lean"] = digest(ROOT / "formal/Benitoite.lean")
    source_sha = hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest()
    for phase in ["build", "axioms"]:
        timing = json.loads((tmp / (phase + "-time.json")).read_text())
        assert timing["rc"] == 0 and timing["source_sha256"] == source_sha, phase
    assert not list(HERE.glob("baseline-[0-9]*.json")) and not list(HERE.glob("declarations-*.json"))
    declarations_file = write_inventory(tmp, declarations)
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
    assert total < 250_000, total
    summary = {
        "b_work": B_WORK,
        "baseline_files": len(baseline(tmp)), "changed": found["changed"], "new_modules": len(found["added"]), "owned_modules": len(modules),
        "build": {"jobs": jobs, "bytes": build_path.stat().st_size, "sha256": digest(build_path)},
        "audit": {"targets": len(targets), "own_declarations": len(declarations),
                  "private": sum(n.startswith("_private.") for _, _, _, n in declarations),
                  "sets": {','.join(k) or '(none)': v for k, v in sorted(sets.items())},
                  "bytes": audit_path.stat().st_size, "sha256": digest(audit_path),
                  "environment_modules": len(environment), "own_modules": own,
                  "declarations": declarations_file},
        "source_snapshot": {"files": len(source_hashes), "sha256": source_sha},
        "public_entries": {n: {"environment": len(readers[n]), "examples": example_readers[n]} for n in public_entries},
        "record_bytes": total,
    }
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps({"ok": True, "modules": len(modules), "declarations": len(declarations),
                      "environment_declarations": len(targets), "build_jobs": jobs, "record_bytes": total}, indent=1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    verify(parser.parse_args().tmp)
