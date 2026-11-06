"""最終の入力、既定 import、全宣言の公理監査、関係と規則の写しを照合する。"""
import ast
import json
from pathlib import Path
import re
import time
from run_check import BASE, HERE, ROOT, digest, fingerprint, inputs, scope, write

EXAMPLES = [
    "integer_projection", "character_projection", "float64_projection", "float32_projection",
    "decimal_projection", "boolean_projection", "string_projection", "unit_projection",
    "stringBytes_projection", "stringCharacters_projection", "listLength_projection",
    "bytesLength_projection", "mapSize_projection", "setSize_projection", "characterCode_projection",
    "data_projection", "data_inventory_lookup", "material_inventory",
    "character_result_rejects_integer", "measurement_sort_mismatch", "unit_result_rejects_constructor",
    "partial_map_measure", "target_result",
    "decimal_order_projection", "float64_order_projection", "float32_order_projection",
    "character_order_projection", "charactersIn_projection",
    "decimal_representation_not_preserved", "string_member_not_preserved",
    "unlisted_constructor_not_preserved", "data_field_content_not_preserved",
]


def closure(module):
    seen = set()
    pending = [module]
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        path = ROOT / "formal" / (name.replace(".", "/") + ".lean")
        if path.exists():
            for names in re.findall(r"^import (.+)$", path.read_text(), re.M):
                pending.extend(n for n in names.split() if n.startswith("Benitoite"))
    return seen


def normalize(text):
    return "\n".join(line.rstrip() for line in text.strip().splitlines())


def main():
    begin = time.monotonic()
    build = json.loads((HERE / "build-summary.json").read_text())
    audit = json.loads((HERE / "audit-summary.json").read_text())
    recorded_scope = json.loads((HERE / "scope-summary.json").read_text())
    assert build["exit_code"] == audit["exit_code"] == 0
    assert build["base"] == audit["base"] == BASE
    assert build["fingerprint"] == audit["fingerprint"] == fingerprint(inputs())
    assert build["scope"] == audit["scope"] == digest(HERE / "scope-summary.json")
    assert scope() == recorded_scope
    for name, recorded in audit["audit_inputs"].items():
        assert digest(HERE / name) == recorded, name
    certificates = json.loads((HERE / "certificate-summary.json").read_text())
    assert digest(HERE / "generate_certificates.lean") == certificates["generator"]
    assert digest(HERE / certificates["raw_output"]["file"]) == {
        k: v for k, v in certificates["raw_output"].items() if k != "file"}
    assert certificates["shared_float_widths"] and certificates["shared_collection_measures"]
    assert max(certificates["nodes"].values()) == 349
    for name, recorded in audit["declarations"].items():
        assert digest(HERE / name) == recorded, name
    # 型の写しの全体は <tmp> に置き、改造には件数・指紋と例・対照・反例の名前だけを残す。
    declarations = json.loads((HERE / "declarations-summary.json").read_text())
    assert declarations["signature_count"] == audit["signature_count"]
    imported = closure("Benitoite")
    expected_new = {"Benitoite.Release.Refinement.FieldRelations",
                    "Benitoite.Release.Refinement.Surface.FieldProjectionExamples",
                    "Benitoite.Release.Refinement.FieldRelationSyntax",
                    "Benitoite.Release.Refinement.FieldAtomSound",
                    "Benitoite.Release.Refinement.Surface.FieldCheckerExamples"}
    assert set(audit["new_production_modules"]) == expected_new == set(recorded_scope["added"])
    assert expected_new <= imported
    assert set(audit["module_records"]) == set(recorded_scope["changed"] + recorded_scope["added"])
    assert set(audit["module_records"]) <= imported
    assert all(r["declarations"] >= 0 for r in audit["module_records"].values())
    assert audit["project_modules"] == len(imported)
    proof_imports = re.findall(r"^import (\S+)$", (HERE / "counterexamples.lean").read_text(), re.M)
    assert all(m in imported for m in proof_imports)
    prefix = "Benitoite.Release.Refinement.Surface.FieldProjectionExamples."
    example_names = {prefix + n for n in EXAMPLES}
    checker = (ROOT / "formal/Benitoite/Release/Refinement/Surface/FieldCheckerExamples.lean").read_text()
    checker_examples = {"Benitoite.Release.Refinement.Surface.FieldCheckerExamples." + name
                        for name in re.findall(r"^theorem (\w+)", checker, re.M)}
    assert len(checker_examples) == 15
    example_names |= checker_examples
    signature_names = set(declarations["example_names"])
    assert example_names <= signature_names
    obstruction = {"Benitoite.Release.Refinement.K2Obstruction." + n for n in
                   re.findall(r"^theorem (\w+)", (HERE / "counterexamples.lean").read_text(), re.M)}
    assert len(obstruction) == 8 and obstruction <= set(audit["local_declarations"])
    assert audit["new_axioms"] == audit["sorryAx"] == 0

    # 今回変えた関係と規則の写しを、実際の本文で照合する。
    spec = normalize((ROOT / "docs/design/01-spec/01-12-core-calculus.md").read_text())
    field = (ROOT / "formal/Benitoite/Release/Refinement/FieldFacts.lean").read_text()
    relation = (ROOT / "formal/Benitoite/Release/Refinement/FieldRelationSyntax.lean").read_text()
    snippets = [
        field[field.index("structure FieldLink where"):field.index("def LinksValid")],
        field[field.index("def FieldLink.predicate"):field.index("@[simp] theorem routeTerm_bind")],
        relation[relation.index("/-- 二つの二値"):relation.index("instance (s :")],
    ]
    logic = (ROOT / "formal/Benitoite/Release/Refinement/Logic.lean").read_text()
    a = logic.index("  | measured")
    b = logic.index("\n\n", a)
    snippets.append(logic[a:b])
    a = logic.index("  | fieldAtom")
    b = logic.index("\n\n", a)
    snippets.append(logic[a:b])
    snippets.append(relation[relation.index("/-- 数値又は値の等号"):relation.index("/-- 原子の組の構文")])
    schema = (ROOT / "formal/Benitoite/Release/Refinement/BuiltinSchema.lean").read_text()
    snippets += [schema[schema.index("/-- 関係の下で二つ"):schema.index("mutual\n  private def observationEq")],
                 schema[schema.index("/-- 閉じた両項の成功"):schema.index("/-- 同じ成功した観測")],
                 schema[schema.index("/-- 測度の部分評価が不能でも"):schema.index("/-- 引数は実際の項")]]
    assert all(normalize(snippet) in spec for snippet in snippets)
    quality = (ROOT / "docs/design/07-quality/07-04-formal-semantics.md").read_text()
    assert all(name in quality for name in ("FieldRelations", "Surface.FieldProjectionExamples",
                                            "FieldRelationSyntax", "FieldAtomSound", "Surface.FieldCheckerExamples"))
    assert "Entails21構成子" in quality
    assert "登録済み14種類" in quality
    assert "| fieldAtom s cs |" in spec and "| measured |" in spec

    # 既存の import と主な定理のモジュールを除外していない。
    saved = json.loads((HERE / "scope-input.json").read_text())
    baseline_imports = set(saved["baseline_imports"])
    current_imports = set(re.findall(r"^import (.+)$", (ROOT / "formal/Benitoite.lean").read_text(), re.M))
    assert baseline_imports <= current_imports
    assert saved["baseline_root_import_count"] == 994
    changed = set(recorded_scope["files"])
    assert all(p == "formal/Benitoite.lean" or p.startswith("formal/Benitoite/Release/Refinement/")
               for p in changed)
    assert not any("/Exchange/" in p or "/Interval/" in p for p in changed)
    # 新しいモジュールの宣言を成功条件から外していない。
    for module in expected_new:
        text = (ROOT / "formal" / (module.replace(".", "/") + ".lean")).read_text()
        assert not re.search(r"\bsorry\b|\baxiom\b|#eval|set_option max(?:Heartbeats|RecDepth)", text)
    assert "formal/Benitoite/Release/Refinement/Syntax.lean" not in changed
    assert "accessorView" not in (ROOT / "formal/Benitoite/Release/Refinement/Surface/Basic.lean").read_text()
    assert not re.search(r"Entails.{0,100}(?:19|20)構成子", spec)
    assert "List の長さ" in quality
    for name in ("run_check.py", "verify.py"):
        ast.parse((HERE / name).read_text())
    assert all(p.stat().st_size <= 100000 for p in HERE.iterdir() if p.is_file())
    summary = {
        "status": "再開3の入力・既定import・公理監査・関係と規則の写しを照合",
        "exit_code": 0, "fingerprint": build["fingerprint"],
        "production_modules_added": len(expected_new),
        "production_modules_changed": len(audit["changed_production_modules"]),
        "changed_and_added_modules_full_audit": audit["module_records"],
        "new_module_default_import_checked": True, "default_closure_modules": len(imported),
        "existing_root_imports_retained": len(baseline_imports),
        "example_declarations": sorted(example_names), "counterexample_declarations": len(obstruction),
        "signature_count": audit["signature_count"], "rule_copy_snippets": len(snippets),
        "build_summary": digest(HERE / "build-summary.json"),
        "audit_summary": digest(HERE / "audit-summary.json"),
        "script": digest(Path(__file__)), "seconds": time.monotonic() - begin,
    }
    write(HERE / "verify-summary.json", summary)
    print(json.dumps({k: v for k, v in summary.items() if k != "changed_and_added_modules_full_audit"},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
