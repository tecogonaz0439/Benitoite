"""全環境の公理監査の生出力を検査し、唯一の宣言・実署名の写しを保存する。"""
import argparse
import collections
import json
import re
from inventory import HERE, STAGE, ROOT, digest, write

ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def pages(stem, entries, limit=85000):
    files, page = [], []
    for row in entries:
        if len(json.dumps(page + [row], ensure_ascii=False, indent=2).encode()) > limit and page:
            path = HERE / f"{stem}-part-{len(files)+1:02}.json"
            write(path, page)
            files.append({"file": path.name, **digest(path)})
            page = []
        page.append(row)
    if page:
        path = HERE / f"{stem}-part-{len(files)+1:02}.json"
        write(path, page)
        files.append({"file": path.name, **digest(path)})
    return files


def signature_pages(signatures):
    for path in HERE.glob("signatures-part-*.md"):
        path.unlink()
    files, page = [], "# 段末の実署名\n\n既定環境の完全な型を印字した。証明本体の評価ではない。\n\n"
    for module, name, line, typ in signatures:
        line = int(line)
        source = "formal/" + module.replace(".", "/") + ".lean"
        item = f"## {name}\n\n所在: `{source}`、行: {line or '生成宣言のため個別位置なし'}。\n\n```lean\n{typ.strip()}\n```\n\n"
        if len((page + item).encode()) > 85000:
            path = HERE / f"signatures-part-{len(files)+1:02}.md"
            path.write_text(page)
            files.append({"file": path.name, **digest(path)})
            page = "# 段末の実署名（続き）\n\n"
        page += item
    if page:
        path = HERE / f"signatures-part-{len(files)+1:02}.md"
        path.write_text(page)
        files.append({"file": path.name, **digest(path)})
    assert all(x["bytes"] <= 100000 for x in files)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=__import__("pathlib").Path, required=True)
    ap.add_argument("--record", required=True)
    args = ap.parse_args()
    execution = json.loads((HERE / (args.record + ".json")).read_text())
    raw = args.tmp / (args.record + ".log")
    assert execution["exit"] == 0 and execution["raw"] == digest(raw)
    output = raw.read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", output)
    names = re.findall(r"^AUDIT_TARGET (.+)$", output, re.M)
    assert len(names) == len(set(names)) == int(re.search(r"^AUDIT_COUNT (\d+)$", output, re.M)[1])
    deps = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", output, re.M | re.S)
    assert collections.Counter(n for n, _ in deps) == collections.Counter(names)
    axiom_sets = collections.Counter(tuple(sorted(x.strip() for x in d.split(",") if x.strip())) for _, d in deps)
    assert all(set(a) <= ALLOWED for a in axiom_sets), axiom_sets
    modules = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", output, re.M)}
    assert sum(modules.values()) == len(names)
    inventory = json.loads((HERE / "modules.json").read_text())
    assert set(inventory["default_closure"]) == set(modules)
    decls = [{"module": m, "kind": k, "line": int(l) or None, "name": n}
             for m, k, l, n in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", output, re.M)]
    assert len({r["name"] for r in decls}) == len(decls)
    assert len(decls) == sum(modules[m] for m in inventory["changed"])
    # 所属と全名の写しはこの一回分だけにまとめ、全対象の大きい生一覧は保存しない。
    catalogue = []
    for m in inventory["changed"]:
        rows = [r for r in decls if r["module"] == m]
        for offset in range(0, len(rows), 80):
            catalogue.append({"module": m, "source": "formal/" + m.replace(".", "/") + ".lean",
                "columns": ["name", "kind", "line"],
                "declarations": [[r["name"], r["kind"], r["line"]] for r in rows[offset:offset+80]]})
    parts = pages("declarations", catalogue)
    printed = re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$", output, re.M | re.S)
    # 生成された再帰原理は全名の公理監査・宣言表に残す。実署名の本文は使用する
    # 定義と入口を対象とし、巨大な生成 recursor の型の重複保存をしない。
    generated = {"rec", "recOn", "casesOn", "brecOn", "below", "ibelow"}
    signatures = [s for s in printed if s[1].split(".")[-1] not in generated]
    required = set(json.loads((HERE / "required-names.json").read_text()))
    assert required <= {s[1] for s in signatures}
    assert len({s[1] for s in signatures}) == len(signatures)
    assert not any("⋯" in s[3] or "..." in s[3] for s in signatures), "実署名の省略"
    signature_parts = signature_pages(signatures)
    definitions = re.findall(r"^DEFINITION_BEGIN (\S+)\n(.*?)^DEFINITION_END \1$", output, re.M | re.S)
    text = "# 使用する定義の本体と欄\n\n具体値を評価せず、既定環境の定義を印字した。\n\n"
    for name, body in definitions:
        text += f"## {name}\n\n```lean\n{body.strip()}\n```\n\n"
    assert len(text.encode()) <= 100000
    (HERE / "definitions.md").write_text(text)
    target = args.tmp / "stage-targets.txt"
    target.write_text("\n".join(names) + "\n")
    (args.tmp / "stage-signatures.json").write_text(json.dumps(signatures, ensure_ascii=False) + "\n")
    references = re.findall(r"^REFERENCE_FOUND (.+)$", output, re.M)
    nondeclarations = re.findall(r"^REFERENCE_NONDECLARATION (.+)$", output, re.M)
    write(HERE / "reference-check.json", {"found": references, "nondeclarations": nondeclarations})
    module_parts = pages("audit-modules", [{"module": m, "count": n} for m, n in sorted(modules.items())])
    inputs = [{"file": str(p.relative_to(ROOT)), **digest(p)}
              for p in sorted((ROOT / "formal").rglob("*.lean")) if ".lake" not in p.parts]
    input_parts = pages("audit-inputs", inputs)
    summary = {**execution, "input": digest(STAGE / "axioms.lean"), "targets": len(names),
        "target_list": digest(target), "project_modules": len(modules),
        "closure_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
        "changed_modules": len(inventory["changed"]), "new_modules": len(inventory["new"]),
        "changed_module_declarations": len(decls),
        "new_module_declarations": sum(modules[m] for m in inventory["new"]),
        "private_changed_declarations": sum(r["name"].startswith("_private.") for r in decls),
        "generated_without_source_line": sum(r["line"] is None for r in decls),
        "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(axiom_sets.items())},
        "new_axioms": 0, "sorryAx": 0, "signatures": len(signatures),
        "printed_signatures": len(printed), "generated_recursors_kept_in_axiom_audit": len(printed)-len(signatures),
        "declaration_parts": parts, "signature_parts": signature_parts,
        "module_parts": module_parts, "formal_input_parts": input_parts,
        "definitions": digest(HERE / "definitions.md"), "script": digest(__import__("pathlib").Path(__file__))}
    write(HERE / "audit-summary.json", summary)
    print(json.dumps({k: summary[k] for k in ["targets", "project_modules", "closure_rounds",
        "changed_module_declarations", "new_module_declarations", "signatures", "axiom_sets"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
