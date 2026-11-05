"""全場合・既定import・監査・保護範囲・記録を読み取りで照合する。"""
import argparse
import collections
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
from inventory import inventory
from support import HERE, ROOT, CHANGE, MODULES, closure, digest, write


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    current = inventory()
    assert current.pop("transform_candidates") == json.loads((HERE / "transform-candidates.json").read_text())
    saved = json.loads((HERE / "inventory.json").read_text())
    assert current == saved
    imports = closure()
    assert len(imports) == len(set(imports)) and set(MODULES) <= set(imports)
    baseline_file = args.tmp / "baseline.json"
    baseline_record = json.loads((HERE / "baseline.json").read_text())
    assert digest(baseline_file) == {k: baseline_record[k] for k in ["bytes", "sha256"]}
    baseline = json.loads(baseline_file.read_text())
    allowed = {"formal/Benitoite.lean", "docs/design/01-spec/01-12-core-calculus.md",
               "docs/design/07-quality/07-04-formal-semantics.md"}
    # 取りまとめが群の途中でも更新する二記録は、担当の保護対象に含めない。
    excluded = {
        str(CHANGE.relative_to(ROOT) / "plan.md"),
        str(CHANGE.relative_to(ROOT) / "effort-ledger.md")}
    assert excluded <= set(baseline)
    changed = []
    for name, sha in baseline.items():
        path = ROOT / name
        assert path.exists(), name
        if name in excluded:
            continue
        if digest(path)["sha256"] != sha:
            assert name in allowed, name
            changed.append(name)
    assert set(changed) == allowed
    new_formal = {str(p.relative_to(ROOT)) for p in (ROOT / "formal/Benitoite").rglob("*.lean")
                  if str(p.relative_to(ROOT)) not in baseline}
    assert new_formal == {"formal/" + m.replace(".", "/") + ".lean" for m in MODULES}
    # 既存三ファイルの追加箇所を取り除き、開始時の内容と一致することも確かめる。
    for name in changed:
        text = (ROOT / name).read_text()
        if name == "formal/Benitoite.lean":
            for module in MODULES:
                assert text.count("import " + module + "\n") == 1
                text = text.replace("import " + module + "\n", "")
        elif "01-12" in name:
            starts = ["`ExternalNominal.table_wf_iff`", "`ExternalUseAt.mode`",
                      "`ExternalSignatureLeaves.handle_typed_iff`"]
            for start in starts:
                text, count = re.subn(r"^" + re.escape(start) + r"[^\n]+\n\n", "", text, flags=re.M)
                assert count == 1
        else:
            for start in ["`ExternalNominal` は、全有限表", "外部の偽造に対する内側の境界は、"]:
                text, count = re.subn(r"^" + re.escape(start) + r"[^\n]+\n\n", "", text, flags=re.M)
                assert count == 1
            text, count = re.subn(r"^\| External(?:Nominal|SignatureLeaves) \|[^\n]+\n", "", text, flags=re.M)
            assert count == 2
        assert hashlib.sha256(text.encode()).hexdigest() == baseline[name], name
    build = json.loads((HERE / "default-build.json").read_text())
    audited = json.loads((HERE / "axioms.json").read_text())
    assert build["exit"] == audited["exit"] == 0
    assert build["cwd"] == "formal" and build["command"] == ["lake", "build"]
    assert build["raw"] == digest(args.tmp / "default-build.log")
    assert audited["raw"] == digest(args.tmp / "axioms.log")
    tools = json.loads((HERE / "tools.json").read_text())
    assert tools["lean_toolchain"] == (ROOT / "formal/lean-toolchain").read_text().strip()
    assert tools["lakefile"] == digest(ROOT / "formal/lakefile.toml")
    assert "-M 12288" == tools["memory_limit"]
    for name, expected in tools["new_sources"].items():
        assert digest(ROOT / name) == expected, name
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["raw"] == audited["raw"] and audit["modules"] == len(imports)
    assert audit["new_axioms"] == audit["sorryAx"] == 0
    for name, expected in audit["inputs"].items():
        assert digest(HERE / name) == expected, name
    declarations = []
    for part in audit["parts"]:
        assert digest(HERE / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
        declarations += json.loads((HERE / part["file"]).read_text())
    assert len(declarations) == audit["declarations"]
    edges = {r["name"]: r["dependencies"] for r in declarations}
    prefix = "Benitoite.Release.Refinement."
    required_edges = [
        ("ExternalNominal.bind", "Ty.bind_external"),
        ("ExternalNominal.closeTy", "ExternalNominal.substTyValues"),
        ("ExternalNominal.closeTyAt", "ExternalNominal.substTyValues"),
        ("ExternalSignatureLeaves.handle_call_typed", "ExternalSurface.call_typed"),
        ("ExternalSignatureLeaves.non_binding_pattern_rejected", "ExternalSignatureLeaves.pattern_observation_not_external"),
        ("ExternalNominal.handle_declaration", "HasTypeVQ.inv_externalHandle"),
        ("ExternalSignatureLeaves.declared_use", "ExternalUseAt.mode"),
        ("ExternalSignatureLeaves.declared_use", "ExternalSignature.WF.shape"),
        ("ExternalSignatureLeaves.collected_contract", "Program.ExternalWF.function_lookup"),
        ("ExternalSignatureLeaves.handle_arguments", "ExternalSignatureLeaves.handle_typed_iff"),
        ("ExternalSignatureLeaves.constructor_value_rejected", "HasTypeVQ.canonical_external")]
    paths = []
    for start, end in required_edges:
        queue = collections.deque([[prefix + start]])
        seen = set()
        while queue:
            path = queue.popleft()
            node = path[-1]
            if node == prefix + end or (node.startswith("_private.") and node.endswith("." + end)):
                paths.append(path)
                break
            if node in seen:
                continue
            seen.add(node)
            queue.extend(path + [n] for n in edges.get(node, []))
        else:
            raise AssertionError((start, end))
    source_text = "\n".join((ROOT / "formal" / (m.replace(".", "/") + ".lean")).read_text() for m in MODULES)
    assert not re.search(r"\b(sorry|axiom|unsafe|native_decide)\b|#eval|set_option (?:maxHeartbeats|maxRecDepth)|L60|L50", source_text)
    assert "ExternalSurface.call_typed" in source_text
    assert source_text.count("example ") >= 20
    # 公開入口の読者は名前付きの型/値依存又は既定ビルドの適用例である。
    explicit = set()
    private_names = set()
    for module in MODULES:
        namespaces = []
        text = (ROOT / "formal" / (module.replace(".", "/") + ".lean")).read_text()
        for line in text.splitlines():
            if line.startswith("namespace "):
                namespaces.append(line.split()[1])
            elif line.startswith("end "):
                namespaces.pop()
            else:
                match = re.match(r"(private )?(?:def|theorem) ([\w.]+)", line)
                if match:
                    if match[1]:
                        private_names.add(match[2])
                    else:
                        explicit.add(".".join(namespaces + [match[2]]))
    assert explicit <= set(edges)
    named = explicit | {n for n in edges if n.startswith("_private.") and n.split(".")[-1] in private_names}
    readers = []
    for row in declarations:
        if row["name"] not in explicit:
            continue
        used_by = sorted(n for n, deps in edges.items() if row["name"] in deps and n != row["name"] and n in named)
        short = row["name"].replace(prefix, "")
        examples = source_text.split("\nexample ")[1:]
        matches = [i + 1 for i, example in enumerate(examples)
                   if re.search(r"\b" + re.escape(short.split(".")[-1]) + r"\b", example.split("\ntheorem ")[0])]
        assert used_by or matches, row["name"]
        readers.append({"name": row["name"], "named_readers": used_by,
                        "default_examples": matches, "future_readers": "L70/R50はhandoffs.md参照"})
    write(HERE / "readers.json", {"paths": paths, "readers": readers})
    results = (HERE / "results.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", results, re.M)
    expected = re.findall(r"^\| (O\d{3}) \|", (CHANGE / "l60/detail.md").read_text(), re.M)
    assert len(ids) == len(set(ids)) == 27 and set(ids) == set(expected)
    assert all(x in results for x in ["B_WORK", "L60.06", "L60.07", "L60.08", "L60.09", "四分類"])
    for path in HERE.glob("*.md"):
        text = path.read_text()
        assert "/Users/" not in text and "docs/todo/" not in text
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if "://" not in link and not link.startswith("#"):
                assert (path.parent / link.split("#")[0]).exists(), (path.name, link)
    files = [p for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    assert all(p.stat().st_size <= 100000 for p in files)
    total = sum(p.stat().st_size for p in files)
    assert total < 3000000
    write(HERE / "verification.json", {"protected": len(baseline) - len(allowed) - len(excluded),
          "changed_existing": sorted(changed),
          "excluded_from_protection": sorted(excluded), "new_formal": sorted(new_formal),
          "imports": len(imports), "declarations": len(declarations), "dependency_paths": len(paths),
          "public_readers": len(readers), "ty": 21, "transforms": len(current["transforms"]),
          "public_ty_transform_candidates": 49, "private_ty_transform_candidates": 4,
          "rules": [6, 3, 2], "wf_fields": 8, "obligations": 27,
          "files": len(files), "bytes": total, "largest": max(p.stat().st_size for p in files),
          "input_hashes": [{"file": str(p.relative_to(ROOT)), **digest(p)} for p in
                            [ROOT / "formal" / (m.replace(".", "/") + ".lean") for m in MODULES]
                            + [HERE / "axioms.lean", HERE / "inventory.py", HERE / "verify.py"]],
          "verified_at": datetime.now().astimezone().isoformat(timespec="seconds")})
    print(json.dumps({"imports": len(imports), "declarations": len(declarations), "protected": len(baseline) - len(allowed) - len(excluded),
                      "obligations": 27, "bytes": total}))


if __name__ == "__main__":
    main()
