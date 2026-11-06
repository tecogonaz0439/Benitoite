"""再開3の完了条件、許可範囲、既存の停止の証拠、既定ビルドと全公理監査の記録を照合する。"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess

from run_check import HERE, ROOT, EVIDENCE, audit_input_text, digest, inputs, fingerprint

B_WORK = "a5a3f7d8993c6f96d8ab90285ddee274347f3862"
PREFIXES = ("Benitoite.Release.Refinement.F2Resume2Evidence.", "Benitoite.Release.Refinement.BooleanResultTrial.")
HISTORICAL = {'counterexamples.lean': '7f80813a88f060e9581e5aebccaebe807edb34574f0951826dade8110a8ce0c2', 'resume1-counterexamples.lean': '172b1f6345ccc3579fc9749254be943ec6f3ec3aa6466fbdd8b61ebedc640232'}
ALLOWED_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def ledger_check():
    base = ROOT / "formal/Benitoite/Release/Refinement"
    signatures = (base / "StandardModelSignatures.lean").read_text()
    section = signatures.split("def Primitive.name", 1)[1].split("def Primitive.provider", 1)[0]
    pairs = re.findall(r'  \| \.(p\d+) => "([^"\n]+)"', section)
    assert len(pairs) == 392 and len(dict(pairs)) == 392 and len({n for _, n in pairs}) == 392
    expected = [("p378", "Scope.pathMatches"), ("p379", "Scope.hostMatches"), ("p380", "String.charactersIn")]
    for width, prefix in [("binary64", "Float"), ("binary32", "Float32")]:
        for name in ["isFinite", "isInfinite", "isPositiveInfinity", "isNegativeInfinity", "isPositiveZero", "isNegativeZero"]:
            if width == "binary32" and name == "isInfinite":
                continue
            expected.append((f"p{378+len(expected):03}", prefix + "." + name))
    expected.append(("p392", "Refinement.check"))
    assert all(dict(pairs)[k] == name for k, name in expected)
    lookups = (base / "StandardModelPrimitiveLookup.lean").read_text()
    providers = signatures.split("def Primitive.provider", 1)[1].split("def Primitive.signature", 1)[0]
    sigs = signatures.split("def Primitive.signature", 1)[1].split("private inductive", 1)[0]
    inputs = (base / "StandardModelPredicateInputs.lean").read_text()
    for key, name in expected:
        assert f'lookup_{key} : primitive "{name}" = some Primitive.{key}' in lookups
        assert f"| {key} => exact lookup_{key}" in lookups
        assert f"| .{key} =>" in providers and f"| .{key} =>" in sigs
        if key != "p392":
            assert f"composed_sample externals .{key}" in inputs
    names = (base / "StandardModelNameLists.lean").read_text()
    groups = {}
    for key in ["delta", "io", "state", "outside", "resource"]:
        match = re.search(r"def " + key + r"Names : List String :=\s*\[(.*?)\]", names, re.S)
        groups[key] = re.findall(r'"([^"\n]+)"', match[1])
    assert [len(groups[k]) for k in ["delta", "io", "state", "outside", "resource"]] == [80, 47, 16, 7, 4]
    assert not ({n for _, n in pairs} & set(sum((groups[k] for k in ["delta", "io", "state", "outside"]), [])))
    completion = (base / "StandardModelCompletion.lean").read_text()
    assert "composed := StandardModel.Primitive.all.map StandardModel.Primitive.name" in completion
    assert "composedEffects := stateEff :: StandardModel.Primitive.all.filterMap (fun row => row.signature.opEff)" in completion
    # New pure signatures have opEff = none, so the effect entries retain the previous ordering.
    io_ids = ["p156", "p157", "p158", "p159", "p160", "p161", "p162", "p163", "p187", "p372", "p373"]
    labels = {"p156": "Process.Environment", "p157": "File.Write", "p158": "File.Write",
        "p159": "File.Read", "p160": "File.Read", "p161": "File.Read", "p162": "File.Write",
        "p163": "File.Write", "p187": "Http.Connect", "p372": "Process.Exit", "p373": "Console.Write"}
    effects = ["State"] + [labels[k] for k, n in sorted(pairs, key=lambda x: x[1]) if k in io_ids]
    assert len(effects) == 12 and len(set(effects)) == 7
    assert "none,[],.untargeted" in (base / "PredicateResponse.lean").read_text()
    assert "none,[],.untargeted" in (base / "RefinementCheck.lean").read_text()
    payload = {"composed_count": len(pairs), "composed_sha256": hashlib.sha256(
        ("\n".join(n for _, n in sorted(pairs, key=lambda x: x[1])) + "\n").encode()).hexdigest(),
        "new_rows": dict(expected), "assumed_counts": {k: len(v) for k,v in groups.items()},
        "composed_effects": effects, "distinct_effects": sorted(set(effects))}
    (HERE / "name-lists.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    return payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    assert git("rev-parse", "HEAD").strip() == B_WORK
    assert git("branch", "--show-current").strip() == "m014/l70.f2"
    changed = git("diff", "--name-only", B_WORK).splitlines()
    allowed = {
        "docs/design/01-spec/01-12-core-calculus.md",
        "docs/design/07-quality/07-04-formal-semantics.md", "formal/Benitoite.lean",
        *["formal/Benitoite/Release/Refinement/" + n + ".lean" for n in [
            "AtInput", "Basic", "ClosedEvaluation", "Context", "MembershipTargets",
            "ModelTargetsApplications", "ObservationOrder", "ObservationSubstitution",
            "PathFacts", "ScopeDelta", "ScopeLegacyContracts",
            "StandardModelCompletion", "StandardModelComposedRows", "StandardModelCore",
            "StandardModelCoreRows", "StandardModelDeclarations", "StandardModelGeneral",
            "StandardModelIORows", "StandardModelIOInputs", "StandardModelPrimitiveLookup", "StandardModelScoped",
            "StandardModelSignatures", "StandardModelSubstitution", "StandardModelWellFormed"]],
    }
    assert set(changed) <= allowed, changed
    untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
    own = str(HERE.relative_to(ROOT)) + "/"
    expected_modules = ["formal/Benitoite/Release/Refinement/" + n + ".lean" for n in [
        "TargetText", "StringMembership", "BooleanResult", "PredicateResponse", "RefinementCheck",
        "RefinementCheckResponse", "CheckAdmissibility", "StandardModelPredicateInputs",
        "StandardModelCheckInputs", "MembershipInferenceBoundary"]]
    assert all(p.startswith(own) or "/reviews/" in p or p in expected_modules for p in untracked), untracked

    # 本番の新モジュールは既定 import に到達することを要求する。全ての追加を根の import と全環境の監査で照合する。
    new_modules = [p for p in untracked if p.startswith("formal/") and p.endswith(".lean")]
    root_imports = (ROOT / "formal/Benitoite.lean").read_text()
    for path in new_modules:
        module = path[len("formal/"):-len(".lean")].replace("/", ".")
        assert root_imports.count("import " + module + "\n") == 1, module
    assert set(new_modules) == set(expected_modules)

    assert all(digest(HERE / n) == sha for n, sha in HISTORICAL.items())
    current_inputs = inputs()
    records = {mode: json.loads((HERE / (mode + ".json")).read_text()) for mode in ["build", "audit"]}
    for mode, record in records.items():
        log = args.tmp / (mode + ".log")
        assert record["exit"] == 0 and record["unchanged"]
        assert record["input_count"] == len(current_inputs)
        assert record["input_sha256"] == fingerprint(current_inputs)
        assert record["log_bytes"] == log.stat().st_size and record["log_sha256"] == digest(log)
        assert log.read_text().rstrip().endswith("exit=0")
        assert "error:" not in log.read_text()
    assert records["build"]["command_inside_lock"] == ["lake", "build"]
    jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", (args.tmp / "build.log").read_text())[1])

    audit = (args.tmp / "audit.log").read_text()
    assert not re.search(r"sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)", audit)
    targets = re.findall(r"^AUDIT_TARGET (.+)$", audit, re.M)
    assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", audit, re.M)[1])
    axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
    assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
    sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(",") if x.strip())) for _, ax in axioms)
    assert all(set(s) <= ALLOWED_AXIOMS for s in sets)
    per_module = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", audit, re.M)}
    local = re.findall(r"^AUDIT_LOCAL (.+)$", audit, re.M)
    assert sum(per_module.values()) + len(local) == len(targets)
    required = {"Benitoite.Release.Refinement." + n for n in [
        "StandardModel.nameLists_wf", "StandardModel.composed_rows", "StandardModel.completion_core",
        "StandardModel.included_guarantees", "Pred.evalClosed_stringMember", "string_path_cases",
        "Pred.evalClosed_sound", "Pred.evalClosed_complete", "Pred.sorted_bind",
        "HasTypeVQ.target_member_interpret", "Pred.member_mono", "BooleanResult.typed",
        "PredicateResponse.response", "PredicateResponse.matches_evalClosed", "PredicateResponse.float64_eval",
        "PredicateResponse.float32_eval", "PredicateResponse.characters_eval", "PredicateResponse.composed_inputs",
        "RefinementCheck.accepted_typed", "RefinementCheck.response", "RefinementCheck.run_ok",
        "RefinementCheck.run_refined_rejected", "RefinementCheck.integer_inputs", "RefinementCheck.OptionField.undecided",
        "string_length_not_member",
        "string_length_certificate_rejected",
        "predicate_no_targets"]}
    assert required <= set(targets), sorted(required - set(targets))
    sources = [(HERE / name).read_text() for name in EVIDENCE]
    explicit = [prefix + n for prefix, source in zip(PREFIXES, sources)
                for n in re.findall(r"^(?:abbrev|def|theorem) (\S+)", source, re.M)]
    source = "\n".join(sources)
    assert set(explicit) <= set(local)
    for name in local:
        # 読み込んだ定義の等式補題が simp によって遅延生成される場合も、全件を監査する。
        generated = re.fullmatch(r"(.+)\.eq_\d+", name)
        imported_equation = generated is not None and generated[1] in targets
        assert name.startswith(PREFIXES) or name.startswith("_private.") or imported_equation, name
    added_sources = "\n".join((ROOT / p).read_text() for p in expected_modules)
    assert not re.search(r"\bsorry\b|\baxiom\b|#eval|maxHeartbeats|maxRecDepth", source + added_sources)
    for path in expected_modules:
        module = path[len("formal/"):-len(".lean")].replace("/", ".")
        assert per_module[module] > 0, module
    for filename, sha in records["audit"]["evidence_sources"].items():
        assert digest(HERE / filename) == sha
    # 試行は既定ビルドの入力ではなく、その後に完成し監査で検査する。
    assert records["build"]["evidence_sources"]["resume2-counterexamples.lean"] == digest(HERE / "resume2-counterexamples.lean")
    assert (args.tmp / "AuditInput.lean").read_text() == audit_input_text()

    # 反例の宣言だけを一度分保存する。全環境の大きい一覧は件数・SHA-256を残す。
    names = "\n".join(sorted(targets)) + "\n"
    local_names = "\n".join(sorted(local)) + "\n"
    for path in HERE.iterdir():
        if path.is_file():
            assert path.stat().st_size <= 100_000, path.name
            body = path.read_text()
            assert "/Us" + "ers/" not in body and "/priv" + "ate/tmp" not in body, path.name
            assert not re.search(r"\]\([^)]*docs/todo", body), path.name
    type_diff = json.loads((HERE / "type-diff.json").read_text())
    assert type_diff["baseline"] == B_WORK and type_diff["exit"] == 0
    assert type_diff["raw_log_sha256"] == digest(args.tmp / "type-diff.log")
    assert type_diff["raw_log_bytes"] == (args.tmp / "type-diff.log").stat().st_size
    assert type_diff["input_sha256"] == digest(args.tmp / "F2Types.lean")
    assert all(d["before_type_sha256"] != d["after_type_sha256"] for d in type_diff["changed"])
    assert all(r["type_source_identical"] for r in type_diff["historical_readers"].values())
    ledger = ledger_check()
    summary = {
        "ledger": ledger,
        "status": "resume3_l70_37_38_complete", "b_work": B_WORK, "tracked_changes": changed,
        "new_production_modules": new_modules,
        "new_module_declaration_counts": {p: per_module[p[len("formal/"):-len(".lean")].replace("/", ".")] for p in new_modules}, "default_import_check": "all new modules checked",
        "jobs": jobs, "input_count": len(current_inputs), "input_sha256": fingerprint(current_inputs),
        "audit_count": len(targets), "audit_modules": len(per_module), "local_count": len(local),
        "historical_evidence_sha256": HISTORICAL, "required_declarations": sorted(required),
        "explicit_local_count": len(explicit), "local_declarations": sorted(local),
        "declarations_sha256": hashlib.sha256(names.encode()).hexdigest(),
        "local_declarations_sha256": hashlib.sha256(local_names.encode()).hexdigest(),
        "axiom_sets": {",".join(k) or "(none)": v for k, v in sorted(sets.items())},
        "sources": {p.name: digest(p) for p in HERE.iterdir() if p.is_file() and p.suffix in {".lean", ".py"}},
        "rss": "未取得（計画上の非採取）",
    }
    production = changed + new_modules
    manifest = {"b_work": B_WORK,
        "files": {p: {"bytes": (ROOT / p).stat().st_size, "sha256": digest(ROOT / p)} for p in production},
        "unchanged_history": HISTORICAL}
    (HERE / "source-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (HERE / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
