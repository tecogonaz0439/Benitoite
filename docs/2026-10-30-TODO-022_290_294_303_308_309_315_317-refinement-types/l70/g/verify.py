#!/usr/bin/env python3
"""群Gの入力保護・全新規モジュール・宣言差・公理監査を作り直して照合する。"""
import argparse
import difflib
import json
import re
import zipfile
from records import HERE, ROOT, B_WORK, ENTRIES, audit, closure, digest, fingerprint, inputs, module_graph, read_graph, write


def no_imports(text):
    return [line for line in text.splitlines(keepends=True) if not re.match(r"^\s*import\s+", line)]


def legacy_body(path, text):
    lines = no_imports(text)
    if path.endswith("/ModelHttp.lean"):
        for index, line in enumerate(lines):
            if re.match(r"^open Benitoite\.Release\.ModelTargets\s+\(", line):
                tokens = re.findall(r"\w+|[^\w\s]", line)
                lines[index] = " ".join(t for t in tokens if t not in {"ref_scoped_get", "ref_scoped_set"}) + "\n"
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=__import__("pathlib").Path, required=True)
    args = parser.parse_args()
    base_file = args.tmp / "baseline-inputs.json"
    base_record = json.loads((HERE / "baseline.json").read_text())
    assert digest(base_file) == base_record["manifest"]
    before, after = json.loads(base_file.read_text()), inputs()
    added, removed = sorted(set(after) - set(before)), sorted(set(before) - set(after))
    changed = sorted(p for p in before.keys() & after.keys() if before[p] != after[p])
    # 読み取り専用の計画・他群の記録・本体のRustには触れない。
    allowed = ("formal/", "crates/benitoite/tests/", "docs/design/01-spec/01-12-core-calculus.md",
               "docs/design/07-quality/07-04-formal-semantics.md")
    assert all(p.startswith(allowed) for p in added + removed + changed), added + removed + changed
    assert not any(p.startswith("crates/benitoite/src/") for p in added + removed + changed)
    # 群Dの既存モジュールと、並行する再開の表層の主定理の本文を保護する。
    protected_d = json.loads((HERE.parent / "d/audit-modules.json").read_text())
    protected_d += ["Benitoite.Release.Refinement.SurfaceLibrary",
                    "Benitoite.Release.Refinement.SurfaceCheckedMainExamples"]
    protected_paths = sorted({"formal/" + n.replace(".", "/") + ".lean" for n in protected_d})
    assert all(p in before and after.get(p) == before[p] for p in protected_paths), [
        p for p in protected_paths if p not in before or after.get(p) != before.get(p)]
    with zipfile.ZipFile(args.tmp / "baseline-sources.zip") as originals:
        for p in changed:
            if p.startswith("formal/Benitoite/Release/") and not p.startswith("formal/Benitoite/Release/Refinement/"):
                old = legacy_body(p, originals.read(p).decode())
                new = legacy_body(p, (ROOT / p).read_text())
                # 旧Releaseの本文は削除だけを許し、内容の書き換えは拒否する。
                diff = difflib.SequenceMatcher(a=old, b=new, autojunk=False)
                assert all(tag in ["equal", "delete"] for tag, *_ in diff.get_opcodes()), p
    graph = module_graph()
    default = closure(graph, ["Benitoite"])
    modules = [p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
               for p in added if p.startswith("formal/Benitoite/") and p.endswith(".lean")]
    assert set(modules) <= default, sorted(set(modules) - default)
    for name, imports in graph.items():
        for dep in imports:
            if dep.startswith("Benitoite"):
                assert dep in graph, (name, dep, "missing import")
    old = read_graph(args.tmp / "baseline-graph.log")
    new = read_graph(args.tmp / "final-graph.log")
    delta = {"added": sorted(set(new) - set(old)), "removed": sorted(set(old) - set(new))}
    data = (json.dumps(delta, ensure_ascii=False, sort_keys=True) + "\n").encode()
    listing = args.tmp / "declaration-delta.json"
    listing.write_bytes(data)
    audit_summary = audit(args.tmp / "audit.log")
    for p in [ROOT / n for n in added + changed if n.startswith("formal/") and n.endswith(".lean")]:
        source = p.read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\s", source, re.M), str(p.relative_to(ROOT))
    record = {"base": B_WORK, "added_files": added, "removed_files": removed, "changed_files": changed,
              "new_modules": modules, "default_modules": len(default),
              "input_count": len(after), "input_sha256": fingerprint(after),
              "protected_d_modules": len(protected_paths),
              "declarations": {k: len(v) for k, v in delta.items()},
              "declaration_delta": digest(listing), "axioms": audit_summary,
              "graph": {"before": digest(args.tmp / "baseline-graph.log"),
                        "after": digest(args.tmp / "final-graph.log")}}
    write(HERE / "verification.json", record)
    print(json.dumps({"inputs": len(after), "modules": len(modules), "declarations": record["declarations"],
                      "audit_targets": audit_summary["targets"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
