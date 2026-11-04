"""全実名分類と同じ応答の証拠、旧本文の保持を局所照合する。"""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import argparse
import ast
import hashlib
import json
import re
import runpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def read(name):
    return json.loads((HERE / name).read_text())


def evidence_names(sources, operators):
    index = sources["columns"].index("evidence")
    names = {name for row in sources["rows"] for name in row[index]}
    names.update(name for row in operators["rows"] for name in row["evidence"])
    for key in ("full_equality", "internal_list_patterns"):
        names.update(operators[key]["evidence"])
    return sorted(name if name.startswith("Benitoite.") else
                  "Benitoite.Release.Refinement." + name for name in names)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true")
    args = parser.parse_args()
    sources, operators = read("sources-r1-u28.json"), read("operators-r1-u28.json")
    names = evidence_names(sources, operators)
    checker = "import Benitoite\n\n-- 表の全証拠名を実際の既定環境で解決する。\n" + "".join(
        "#check " + name + "\n" for name in names)
    if args.prepare:
        (HERE / "evidence-check-u28.lean").write_text(checker)
        print(json.dumps({"evidence_declarations": len(names)}))
        return
    assert (HERE / "evidence-check-u28.lean").read_text() == checker
    initial = read("baseline-r1-u28.json")
    captured = {}
    for part in initial["files_parts"]:
        data = (HERE / part["file"]).read_bytes()
        assert digest(data) == {k: part[k] for k in ("bytes", "sha256")}
        body = json.loads(data)
        assert body["start"] == initial["start_utc"]
        for item in body["sources"]:
            assert item["path"] not in captured
            captured[item["path"]] = {k: item[k] for k in ("bytes", "sha256")}
    assert len(captured) == initial["lean_sources"] == 741
    for relative, expected in captured.items():
        data = (ROOT / relative).read_bytes()
        if relative == "formal/Benitoite.lean":
            data = data[:expected["bytes"]]
        assert digest(data) == expected, relative
    modules = read("modules-r1.json")
    assert modules[:20] == initial["old_modules"] and len(modules) == 32
    new = modules[20:]
    paths = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    assert len(paths) == 753
    root = (ROOT / "formal/Benitoite.lean").read_bytes()
    assert root[captured["formal/Benitoite.lean"]["bytes"]:] == "".join(
        f"import Benitoite.Release.Refinement.{m}\n" for m in new).encode()
    progress = read("unit28-progress.json")
    guarded = [c for name in ("checks-r1-u28.json", "checks-r1-u28-relation.json", "checks-r1-u28-operators.json")
               for c in read(name)]
    latest_default = max((c for c in guarded if c["command"] == ["lake", "build"]), key=lambda c: c["start"])
    assert latest_default["exit"] == 0
    entries, module_sources = {}, {}
    for module in new:
        relative = f"formal/Benitoite/Release/Refinement/{module}.lean"
        path = ROOT / relative
        code = path.read_text()
        module_sources[module] = digest(path.read_bytes())
        assert path.stat().st_size <= 100000
        olean = ROOT / f"formal/.lake/build/lib/lean/Benitoite/Release/Refinement/{module}.olean"
        assert olean.exists(), module
        # 同じ本文を生成し直した場合、Lakeは内容hashにより既存oleanを再利用する。
        # mtimeだけではなく、収集した同じSHAと、生成後の対象なし既定ビルドを照合する。
        assert progress["sources"][module] == module_sources[module]["sha256"], module
        assert datetime.fromisoformat(latest_default["start"]).timestamp() >= path.stat().st_mtime, module
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", code)
        assert not re.search(r"\b(?:L\d{2}(?:\.\d+)?|O\d{3}|TODO-\d{3})\b|/Users/", code)
        public = []
        for match in re.finditer(r"(?m)^(private )?(?:def|theorem|structure) ([A-Za-z_][A-Za-z0-9_.]*)", code):
            if match[1]:
                continue
            name = match[2]
            # API.isBits は api.isBits のフィールド記法でも現れる。
            count = len(re.findall(r"\b" + re.escape(name.split(".")[-1]) + r"\b", code))
            assert count > 1, (module, name)
            public.append({"name": name, "textual_occurrences": count})
        entries[module] = public
        for doc in ("docs/design/01-spec/01-12-core-calculus.md",
                    "docs/design/07-quality/07-04-formal-semantics.md"):
            assert module in (ROOT / doc).read_text(), (module, doc)
    original = read("sources.json")
    for relative, expected_input in original["inputs"].items():
        assert digest((ROOT / relative).read_bytes()) == expected_input, relative
    columns = sources["columns"]
    rows = [dict(zip(columns, row)) for row in sources["rows"]]
    assert len(rows) == len({r["api"] for r in rows}) == 328
    assert {r["api"] for r in rows} == {r[0] for r in original["rows"]}
    expected = {"modules": 23, "apis": 328, "builtin": 244, "core": 84,
                "aliases": 51, "pure-local": 143, "core-local": 6, "open": 179}
    assert sources["counts"] == expected
    assert Counter(r["ordinary_F06"] for r in rows) == {
        "pure-local": 143, "core-local": 6, "open": 179}
    assert Counter(r["relation_status"] for r in rows) == sources["additional_relation_counts"]
    assert {r["api"] for r in rows if r["relation_status"] == "boundary-wait"} == {
        "List.map", "List.filter", "Map.map", "Map.filter", "Set.map", "Set.filter", "NonEmptyList.map"}
    assert sum(r["relation_status"] == "core-static-open" for r in rows) == 9
    assert all(r["relation_status"] == "core-open" for r in rows if r["api"] in {
        "NonEmptyList.fromList", "NonEmptyList.toList", "NonEmptyList.head", "NonEmptyList.tail"})
    signatures = (ROOT / "formal/Benitoite/Release/Refinement/StandardSignatureExamples.lean").read_text()
    proof_names = re.findall(r"(?m)^-- ([A-Za-z0-9_.]+): public function", signatures)
    assert len(proof_names) == len(set(proof_names)) == 143
    assert set(proof_names) == {r["api"] for r in rows if r["ordinary_F06"] == "pure-local"}
    assert len(operators["rows"]) == len({r["name"] for r in operators["rows"]}) == 107
    proved = {r["name"] for r in operators["rows"] if r["ordinary"] == "pure-leaf"}
    assert len(proved) == 73
    schema_names = []
    for module in ("StandardArithmeticResponse", "StandardOrderResponse"):
        code = (ROOT / f"formal/Benitoite/Release/Refinement/{module}.lean").read_text()
        schema_names += re.findall(r"(?m)^-- (%[A-Za-z0-9_.]+): registered", code)
    assert len(schema_names) == len(set(schema_names)) == 73 and set(schema_names) == proved
    eq = operators["full_equality"]
    assert eq["tparams"] == [{"kind": "value", "constraints": {"equality": True, "key": False}}]
    assert eq["params"] == ["T", "T"] and eq["names"] == ["%eq", "%ne"]
    relations = read("relations-r1-u28.json")
    assert len(relations["rows"]) == relations["count"] == 36
    assert {r["id"] for r in relations["rows"]} == {f"S{i:02}" for i in range(1, 37)}
    assert relations["whole_S_closed"] == sources["whole_api_contracts_closed"] == sources["whole_obligations_closed"] == 0
    # 中断後はコードを固定し、原ソース・分類・保存済み証拠の識別だけを照合する。
    interruption = read("unit28-interruption.json")
    assert interruption["unit_started"] == initial["start_utc"]
    for relative, expected_input in interruption["files"].items():
        if relative.startswith("formal/"):
            assert digest((ROOT / relative).read_bytes()) == expected_input, relative
    source_evidence = read("source-evidence-u28.json")
    for name, expected_input in source_evidence["original_records"].items():
        assert digest((HERE / name).read_bytes()) == expected_input, name
    assert source_evidence["new_modules"] == module_sources
    for item in source_evidence["actual_source_excerpts"]:
        path = ROOT / item["path"]
        assert digest(path.read_bytes()) == {k: item[k] for k in ("bytes", "sha256")}
        lines = path.read_text().splitlines()
        for excerpt in item["excerpts"]:
            assert "\n".join(lines[excerpt["start"]-1:excerpt["end"]]) == excerpt["text"]
    assert digest((ROOT / operators["source"]["path"]).read_bytes()) == {
        k: operators["source"][k] for k in ("bytes", "sha256")}
    operator_text = (ROOT / operators["source"]["path"]).read_text()
    block = operator_text.split("pub const OPERATORS:", 1)[1].split("];", 1)[0]
    registered = re.findall(r'OperatorKind::(\w+),\s*BuiltinTypeId::(\w+),\s*"([^\"]+)"', block)
    assert registered == [(r["operator"], r["rust_operand"], r["name"]) for r in operators["rows"]]
    actual = {r["module"] + "." + r["name"]: r for name in ("api-numeric.json", "api-collections.json") for r in read(name)}
    assert len(actual) == 328
    for row in read("api-connections-r1-u28.json")["rows"]:
        src = actual[row[0]]
        assert [row[i] for i in (9, 10, 11, 4, 12)] == [src[k] for k in ("line", "generics", "parameters", "result", "effect")]
    for row in rows:
        src = actual[row["api"]]
        assert row["actual_builtin"] == src["builtin"] and row["actual_core_calls"] == src["calls"]
    obligation_text = (HERE / "obligations.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", obligation_text, re.M)
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", (HERE.parent / "detail.md").read_text(), re.M))
    assert ".28未着手" not in obligation_text
    validate = runpy.run_path(str(HERE / "run-r1.py"))["validate_command"]
    checks = []
    for name in ("checks-r1-u28.json", "checks-r1-u28-relation.json", "checks-r1-u28-operators.json"):
        part = read(name)
        for check in part:
            validate(check["command"], check["cwd"] == "formal/")
        checks.extend(part)
    defaults = [c for c in checks if c["command"] == ["lake", "build"]]
    assert defaults and max(defaults, key=lambda c: c["start"])["exit"] == 0
    declaration_checks = [c for c in checks if c["label"].startswith("r1-u28-evidence-names")]
    assert declaration_checks and max(declaration_checks, key=lambda c: c["start"])["exit"] == 0
    deviations = read("command-deviations-r1.json")
    targeted = []
    for p in HERE.glob("checks-r1*.json"):
        for c in json.loads(p.read_text()):
            if c["command"][:2] == ["lake", "build"] and c["command"] != ["lake", "build"]:
                targeted.append((p.name, c["label"], c["start"], c["command"], c["exit"]))
    old = [(deviations["record"], c["label"], c["start"], c["command"], c["exit"])
           for c in deviations["executions"]]
    assert sorted(targeted) == sorted(old) and len(old) == 23
    for p in HERE.iterdir():
        if not p.is_file():
            continue
        assert p.stat().st_size <= 100000, p.name
        text = p.read_text()
        assert str(ROOT) not in text and not re.search(r"\]\([^)]*docs/todo", text), p.name
        if p.suffix == ".py":
            ast.parse(text, filename=p.name)
        if p.suffix == ".md":
            for link in re.findall(r"\]\(([^)]+)\)", text):
                target = link.split("#")[0]
                if target and "://" not in target:
                    assert (p.parent / target).exists(), (p.name, target)
    evidence = {"observed_utc": datetime.now(timezone.utc).isoformat(), "exit": 0,
        "scope": "局所照合。全公理監査・全モデル充足・Rust/Lean実行全比較・独立レビュー・受け入れは含まない。",
        "retained_lean_sources": 741, "current_lean_sources": 753,
        "modules": new, "module_sources": module_sources, "public_entries": entries,
        "source_record": digest((HERE / "sources-r1-u28.json").read_bytes()),
        "ordinary_counts": expected, "relation_counts": sources["additional_relation_counts"],
        "source_signature_proofs": 143, "operator_signature_proofs": 73,
        "evidence_declarations": names, "obligations": 64, "S_rows": 36,
        "old_root_prefix": captured["formal/Benitoite.lean"],
        "default_build": max(defaults, key=lambda c: c["start"])["label"],
        "declarations_check": max(declaration_checks, key=lambda c: c["start"])["label"],
        "earlier_targeted_build_deviations": 23, "additional_targeted_build_deviations": 0,
        "records_under_100KB": True}
    (HERE / "local-verification-u28.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k not in ("public_entries", "module_sources", "evidence_declarations")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
