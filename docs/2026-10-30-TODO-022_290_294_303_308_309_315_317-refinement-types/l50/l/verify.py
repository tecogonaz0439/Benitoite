"""担当分の全証拠・保存上限・保護対象・完了条件を最後に照合する。"""
from pathlib import Path
import argparse
import hashlib
import json
import re
from inventory import HERE, STAGE, CHANGE, ROOT, closure, digest, write


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    initial = json.loads((args.tmp / "resume-initial.json").read_text())
    from resume2_check import check
    audited_versions = check(args.tmp)
    resume2 = json.loads((args.tmp / "resume2-initial.json").read_text())
    allowed = {"docs/design/01-spec/01-12-core-calculus.md",
        "docs/design/07-quality/07-04-formal-semantics.md",
        "formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean"}
    review = str((CHANGE / "reviews/RV-L50.l.md").relative_to(ROOT))
    changed = []
    for filename, old in initial.items():
        path = ROOT / filename
        assert path.exists(), filename
        if digest(path)["sha256"] != old:
            changed.append(filename)
    assert set(changed) == allowed | {review}, sorted(set(changed) ^ allowed)
    # 再レビューの取りまとめによる追記を引き継ぎ、再開2では変更しない。
    assert digest(ROOT / review)["sha256"] == resume2[review]
    restored = json.loads((HERE / "resume2-restoration.json").read_text())
    resume2_changed = allowed - {"formal/Benitoite/Release/Refinement/ScopeLegacyContracts.lean"}
    resume2_changed |= {r["file"] for r in restored["comments"]}
    assert {f for f, h in resume2.items() if digest(ROOT / f)["sha256"] != h} == resume2_changed

    def audit_input_matches(row):
        expected = {k: row[k] for k in ["bytes", "sha256"]}
        return digest(ROOT / row["file"]) == expected or audited_versions.get(row["file"]) == expected
    # 旧Releaseの変更、既定importからの削除、保護された記録の上書きを拒む。
    sources, imported = closure()
    modules = json.loads((HERE / "modules.json").read_text())
    assert sorted(imported) == modules["default_closure"]
    assert all(audit_input_matches(r) for r in modules["sources"])
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["new_axioms"] == audit["sorryAx"] == 0
    assert audit["targets"] == sum(audit["axiom_sets"].values()) == 80672
    assert audit["input"] == digest(STAGE / "axioms.lean")
    assert audit["script"] == digest(HERE / "audit.py")
    for key in ["declaration_parts", "signature_parts", "module_parts", "formal_input_parts"]:
        for r in audit[key]:
            assert digest(HERE / r["file"]) == {k: r[k] for k in ["bytes", "sha256"]}, r["file"]
    assert audit["definitions"] == digest(HERE / "definitions.md")
    audited_inputs = [r for part in audit["formal_input_parts"] for r in json.loads((HERE / part["file"]).read_text())]
    for r in audited_inputs:
        assert audit_input_matches(r)
    required = set(json.loads((HERE / "required-names.json").read_text()))
    signatures = json.loads((args.tmp / "stage-signatures.json").read_text())
    assert required <= {r[1] for r in signatures}
    families = json.loads((HERE / "families.json").read_text())
    assert list(families) == [f"F{i:02}" for i in range(1, 11)]
    rec = json.loads((HERE / "reconciliation.json").read_text())
    assert [rec[k] for k in ["obligations", "handoffs", "conditions", "l60_remaining_fields", "apis",
                            "whole_obligations_closed"]] == [33, 31, 75, 12, 13, 0]
    assert rec["technical_independent_unresolved"]["count"] == 0
    assert rec["technical_independent_unresolved"]["source"]["sha256"] == digest(HERE / "coverage-judgments.json")["sha256"]
    assert rec["partially_read_rows"] == 33
    # 保存済みの原契約と同じ25欄を各モデルに一度ずつ持つ。
    fields = ["sat_rename", "admits_rename", "sat_values", "admits_values", "sat_renameTypes",
        "admits_renameTypes", "sat_subst", "admits_subst", "delta_typed", "io_typed", "io_kind", "io_exists",
        "sig_scoped", "sat_unconstrained", "admits_sat", "pathBases_shape", "io_op", "opEff_io", "effect_ops",
        "state_effect", "ref_get", "ref_set", "store_shape", "store_admits", "io_target"]
    conditions = json.loads((STAGE / "j/conditions.json").read_text())
    contracts = (STAGE / "j/contracts.lean").read_text()
    for model in ["Model.builtins", "ModelTargets.builtins", "ModelHttp.builtins"]:
        assert [r["field"] for r in conditions if r["model"] == model] == fields
    assert all(re.search(r"theorem\s+" + re.escape(r["contract"].split(".")[-1]) + r"\b", contracts) for r in conditions)
    for label in ["resume2-build-check", "resume1-audit-check"]:
        r = json.loads((HERE / (label + ".json")).read_text())
        assert r["exit"] == 0 and r["raw"] == digest(args.tmp / (label + ".log"))
    vacuity = json.loads((HERE / "vacuity-check.json").read_text())
    assert vacuity["exit"] == 0 and vacuity["rows"] == 75
    assert vacuity["judgments"] == digest(HERE / "condition-judgments.json")
    assert vacuity["probe"] == digest(HERE / "premise-probe.lean")
    judgments = json.loads((HERE / "condition-judgments.json").read_text())
    assert len(judgments) == 75 and sum(r["premises_prove_false"] for r in judgments) == 6
    assert set(json.loads((HERE / "handoff-names.json").read_text())) <= {r[1] for r in signatures}
    stage = (STAGE / "stage-results.md").read_text()
    for pattern, count in [(r"^\| O\d{3} \|", 33), (r"^\| H\d{2} \|", 31), (r"^\| \d+ \|", 75)]:
        assert len(re.findall(pattern, stage, re.M)) == count, pattern
    assert "未実施" in stage and "受け入れは未実施" in stage and "RV-L50.l" in stage
    assert all(f"### F{i:02}" in stage for i in range(1, 11))
    files = [p for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    files += [STAGE / "axioms.lean", STAGE / "stage-results.md"]
    links = 0
    for file in files:
        assert file.stat().st_size <= 100000, (file.name, file.stat().st_size)
        text = file.read_text()
        # 台本の拒否パターン自体を禁止の参照と誤認しない。
        if file.suffix in [".md", ".json", ".lean"]:
            assert not re.search(r"/(?:Users|private/tmp|tmp)/", text), file.name
            assert not re.search(r"\]\([^)]*docs/todo", text), file.name
        if file.suffix == ".md":
            assert text.count("```") % 2 == 0, file.name
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if target.startswith(("https:", "http:", "#")):
                    continue
                assert (file.parent / target.split("#", 1)[0]).exists(), (file.name, target)
                links += 1
    assert sum(f.stat().st_size for f in files) < 4000000
    # 本番コメントの訂正だけであり、工程IDや未確定語を追加していない。
    for path in sorted(allowed):
        if path.endswith(".lean"):
            assert not re.search(r"L50\.|L60|L70|U02|暫定|/Users/", (ROOT / path).read_text()), path
    record = {"status": "担当分の自己照合成功", "b_work": "70d726b70b6cb4cbf5abace21d377f6ae155b512",
        "initial_input_manifest": digest(args.tmp / "resume-initial.json"),
        "scripts": {p.name: digest(p) for p in sorted(HERE.glob("*.py"))},
        "changed_inputs_from_resume1": changed, "restored_inputs_this_resume": sorted(resume2_changed),
        "protected_initial_inputs": len(resume2) - len(resume2_changed),
        "source_comparison": digest(HERE / "resume2-source-check.json"),
        "audit_reused_with_comment_equivalence": True,
        "default_closure": len(imported), "audit_targets": audit["targets"], "new_modules": len(modules["new"]),
        "signatures": audit["signatures"], "obligations": 33, "handoffs": 31, "conditions": 75,
        "remaining_l60_fields": 12, "apis": 13, "technical_independent_unresolved": rec["technical_independent_unresolved"],
        "whole_obligations_closed": 0, "work_executions_this_resume": 0, "historical_work_executions": 1, "links_checked": links,
        "record_bytes_excluding_this_summary": sum(f.stat().st_size for f in files if f.name != "verification.json"),
        "stage_results": digest(STAGE / "stage-results.md"), "final_rss": "未取得・取りまとめの正式採取を待つ",
        "independent_review": "RV-L50.l再確認を受け、再開2で軽1の処置を指摘の三箇所へ限定。再確認・受け入れは取りまとめへ", "acceptance": "設計者が判定する"}
    write(HERE / "verification.json", record)
    print(json.dumps(record, ensure_ascii=False))


if __name__ == "__main__":
    main()
