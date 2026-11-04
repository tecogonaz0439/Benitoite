"""保存済みの前段入力と現行ソースから、段末監査の母集団を再生成する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
CHANGE = STAGE.parent
ROOT = CHANGE.parents[1]
PREFIX = "Benitoite.Release.Refinement."


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, value):
    data = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()
    assert len(data) <= 100000, (path.name, len(data))
    path.write_bytes(data)


def closure():
    """ローカルの import を根から辿る。標準ライブラリはローカル表に含めない。"""
    sources = {str(f.relative_to(ROOT / "formal")).removesuffix(".lean").replace("/", "."): f
               for f in (ROOT / "formal").rglob("*.lean") if ".lake" not in f.parts}
    seen, pending = set(), ["Benitoite"]
    while pending:
        name = pending.pop()
        if name in seen or name not in sources:
            continue
        seen.add(name)
        pending.extend(re.findall(r"^import\s+([\w.]+)", sources[name].read_text(), re.M))
    return sources, seen


def main():
    baseline = {r["file"]: r for f in sorted((CHANGE / "l40/g").glob("audit-inputs-part-*.json"))
                for r in json.loads(f.read_text())}
    assert baseline
    sources, imported = closure()
    changed, new = [], []
    for name, path in sorted(sources.items()):
        rel = str(path.relative_to(ROOT))
        if digest(path)["sha256"] != baseline.get(rel, {}).get("sha256"):
            changed.append(name)
            if rel not in baseline:
                new.append(name)
    assert set(changed) <= imported, sorted(set(changed) - imported)
    assert not [f for f in baseline if f.startswith("formal/") and not (ROOT / f).exists()]
    assert all(n == "Benitoite" or n.startswith(PREFIX) for n in changed)
    write(HERE / "modules.json", {"baseline": "l40/g/audit-inputs-part-*.json",
        "changed": changed, "new": new, "default_closure": sorted(imported),
        "sources": [{"module": m, "file": str(sources[m].relative_to(ROOT)), **digest(sources[m])}
                    for m in changed]})
    write(HERE / "changed-modules.json", changed)
    names = set()
    for group in "abcdefghijk":
        for file in (STAGE / group).glob("*.md"):
            names.update(re.findall(r"Benitoite\.Release\.Refinement(?:\.[A-Za-z_][A-Za-z_0-9?]*)+", file.read_text()))
    # 群 K の private 名は文字列から Name を再構成せず環境で正確に検索する。
    for file in [STAGE / "k/trace.json", STAGE / "k/connections.json"]:
        for row in json.loads(file.read_text()):
            names.update(row.get("proofs", []))
            names.update(row.get("readers", []))
    write(HERE / "referenced-names.json", sorted(names))
    # F は族であり、一つの架空の定理へまとめない。
    families = {
        "F01": ["PathPattern.covers_atBase", "RangeExpr.Covers.mem", "SnapshotMem.mono"],
        "F02": ["Eff.Allows", "Eff.Covers.allows"],
        "F03": ["HasTypeVQ.target_member", "HasTypeVQ.request_target"],
        "F04": ["Builtins.ShapeOk.single_target", "PrimSig.Scoped.namesWF"],
        "F05": ["Builtins.TargetAgreement.obs_allowed"],
        "F06": ["PathEnv.Ready.resolve_required", "AtPrepared.current", "StateTyE.at_step",
                 "InitialPrepared.source_state_of_source"],
        "F07": ["ScopeResponse.delta_typed", "ScopeResponse.outcome_typed", "ScopedIOResponse.response",
                 "ScopedIOResponse.io_exists", "ScopeResponse.adequate_externalRef",
                 "ScopeResponse.adequate_externalHandle", "ScopeResponse.adequate_scopePattern",
                 "AtTargets.adequate_atError"],
        "F08": ["ScopedCallContracts.single_inputs", "ScopedCallContracts.request_inputs",
                 "ScopedTargetExamples.single_io", "ScopedTargetExamples.request_io"],
        "F09": ["ModelScopeConditions", "ModelScopeConditions.core", "Model.scopeConditions",
                 "ModelTargets.scopeConditions", "ModelHttp.scopeConditions", "ScopeModels.conditions"],
        "F10": ["Detail", "AtError.save_exact", "AtPrepare.error_saved", "AtError.fromCheck",
                 "Detail.originals_unobserved", "AtErrorReaders.observed"]}
    # 入口は各群の実署名を使い、detail の予約名と異なる場合もここで照合する。
    families = {k: [PREFIX + n for n in v] for k, v in families.items()}
    write(HERE / "families.json", families)
    required = {PREFIX + n for n in ["ScopedTargetInputs.response_inputs", "ScopedTargetInputs.pure_steps",
        "ScopedTargetInputs.io_steps", "ScopedTargetInputs.handled_step", "ScopedTargetInputs.at_prepare",
        "ScopedTargetInputs.at_error", "ScopedTargetInputs.at_ok", "ScopedTargetInputs.at_steps",
        "ScopedTargetInputs.path_bases_apply", "ScopedTargetInputs.issue", "TelClosure.apply",
        "BuiltinArgs", "Builtins.ExternalAssumptions", "Builtins.ExternalAssumptions.external_typed",
        "Builtins.ExternalAssumptions.external_exists", "Builtins.ExternalAssumptions.external_no_targets",
        "Builtins.CoreAssumptions.release_exists", "Val.Source", "Comp.Source", "Val.Adequate",
        "RangeExpr.Covers", "Step", "TargetTable.valKind"]}
    required.update(n for ns in families.values() for n in ns)
    required.update("Benitoite.Release." + n for n in ["progress", "preservation", "step_sound",
        "effect_soundness", "effect_soundness_noLamNames", "Model.assumptions",
        "ModelTargets.assumptions", "ModelHttp.assumptions"])
    required.update(json.loads((HERE / "handoff-names.json").read_text()))
    write(HERE / "required-names.json", sorted(required))
    print(json.dumps({"changed_modules": len(changed), "new_modules": len(new),
        "default_closure": len(imported), "references": len(names), "required": len(required)}))


if __name__ == "__main__":
    main()
