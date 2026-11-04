"""再開4の証拠名・API名・docstringだけの変更・全宣言監査を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import hashlib
import json
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8"
NEW = "StandardListGetPrecisionGap"


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def verify_evidence(tmp, declarations, sources):
    """全証拠名の存在と、証拠の名前空間ごとのAPI名を独立に照合する。

    名前だけを評価し、δや大きな値を評価しない。この検査は定理の適用や
    引数の割当ての正しさを証明するものではない。
    """
    prefix = "Benitoite.Release.Refinement."
    all_names = {n for names in declarations.values() for n in names}

    def private(namespace, suffix):
        found = [n for n in all_names if n.startswith("_private.")
                 and n.endswith("." + namespace + "." + suffix)]
        assert len(found) == 1, (namespace, suffix, found)
        # private名の数値成分を文字列の識別子へ変換しない。監査で存在を
        # 確認した宣言の列挙本体をそのまま読み、公開の名前関数を評価する。
        source = (ROOT / "formal/Benitoite/Release/Refinement" / (namespace + ".lean")).read_text()
        pattern = (r"private def " + re.escape(suffix) +
                   r"(?P<param> \(k : IntKind\))? : List (?P<element>API|IntKind) :=\s*"
                   r"(?P<body>[\s\S]*?)(?=\n(?:private |def |theorem ))")
        matches = list(re.finditer(pattern, source))
        assert len(matches) == 1, (namespace, suffix)
        match = matches[0]
        body = re.sub(r"--[^\n]*", "", match["body"]).strip()
        assert re.fullmatch(r"\[\s*(?:\.[A-Za-z0-9]+\s*,?\s*)+\]"
                            r"(?: \+\+ if k.min < 0 then \[.shiftRightUnsigned\] else \[\])?", body), body
        element = namespace + ".API" if match["element"] == "API" else "IntKind"
        value = f"({body} : List {element})"
        return f"(fun (k : IntKind) => {value})" if match["param"] else value

    def api_names(namespace, collection="apis"):
        values = private(namespace, collection)
        return f"({values}).map {namespace}.API.name"

    expressions = {}
    for ns in ("StandardCharacterResponse", "StandardNumericRemainingResponse",
               "StandardStringOrdinaryResponse", "StandardBytesOrdinaryResponse",
               "StandardAliasBodies"):
        expressions[ns] = f"{ns}.API.all.map {ns}.API.name"
    for ns in ("StandardScalarResponse", "StandardDecimalResponse",
               "StandardBytesResponse", "StandardListResponse", "StandardListRemainingResponse"):
        expressions[ns] = api_names(ns)
    for ns in ("StandardIntegerTextResponse", "StandardIntegerAPI"):
        kinds = private(ns, "kinds")
        apis = private(ns, "apis")
        collection = f"{apis} k" if ns == "StandardIntegerAPI" else apis
        expressions[ns] = f"({kinds}).flatMap (fun k => ({collection}).map ({ns}." + (
            "API.name" if ns == "StandardIntegerAPI" else "name") + " k))"
    expressions["StandardFloatMathResponse"] = (
        "[false,true].flatMap (fun single => (" + private("StandardFloatMathResponse", "apis")
        + ").map (StandardFloatMathResponse.name single))")
    expressions["StandardOrdinaryCoreProgram"] = (
        "StandardOrdinaryCoreProgram.PublicAPI.all.map StandardOrdinaryCoreProgram.PublicAPI.name")
    kinds = private("StandardIntegerResponse", "canonicalKinds")
    expressions["StandardIntegerResponse"] = (
        f"({kinds}).flatMap (fun k => [false,true].map (StandardIntegerResponse.minMaxName k))")
    kinds = private("StandardConversionResponse", "kinds")
    expressions["StandardConversionResponse"] = (
        f"({kinds}).flatMap (fun k => [false,true].map (StandardConversionResponse.name k))")
    collections = ("(StandardCollectionModel.mapAPIs.map StandardCollections.MapAPI.name) ++ "
                   "(StandardCollectionModel.setAPIs.map StandardCollections.SetAPI.name)")
    higher = ("[false,true].flatMap (fun m => [false,true].map "
              "(fun f => (StandardBodies.collectionHigherRow m f).name))")
    expressions["StandardCollections"] = collections
    expressions["StandardCollectionModel"] = f"({collections}) ++ ({higher})"
    expressions["StandardActualListBodies"] = (
        "[false,true].map (fun f => (StandardBodies.listHigherRow f).name)")

    # 単一名は、表又はBuiltinArgsの宣言に直接書かれた文字列から取る。
    literals = [
        ("StandardByteStringResponse", "StandardByteStringResponse", r'if b=("[^"]+") then'),
        ("StandardListRemainingResponse", "StandardListRemainingResponse", r'if b=("[^"]+") then'),
        ("StandardDecimalResponse", "StandardDecimalResponse",
         r'theorem fromFloat_exit[\s\S]*?BuiltinArgs program B Ψ ("[^"]+")'),
    ]
    for ns, module, pattern in literals:
        source = (ROOT / "formal/Benitoite/Release/Refinement" / (module + ".lean")).read_text()
        found = re.findall(pattern, source)
        assert len(set(found)) == 1, (module, found)
        literal = found[0]
        expressions[ns] = f"({expressions[ns]}) ++ [{literal}]" if ns in expressions else f"[{literal}]"

    # 小さな名前の列だけをLeanの定義から出力する。既定importには加えない。
    lean = tmp / "api-names-r4.lean"
    lines = ["import Benitoite", "open Benitoite.Release.Refinement Benitoite.Interval"]
    for ns, expr in sorted(expressions.items()):
        lines.append('#eval IO.println ((Lean.toJson (' + json.dumps(ns) +
                     ', (' + expr + ' : List String))).compress)')
    lean.write_text("\n".join(lines) + "\n")
    raw = tmp / "api-names-r4.log"
    command = ["lake", "env", "lean", "-M", "12288", str(lean.resolve())]
    started = datetime.now(timezone.utc).isoformat()
    before = time.monotonic()
    with raw.open("wb") as out:
        result = subprocess.run(command, cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
    assert result.returncode == 0, raw.read_text()[-6000:]
    tables = {}
    for line in raw.read_text().splitlines():
        ns, values = json.loads(line)
        assert ns not in tables and all(isinstance(v, str) for v in values)
        tables[ns] = set(values)
    assert set(tables) == set(expressions)
    (HERE / "api-names-r4.json").write_text(json.dumps({
        "scope": "Leanの名前定義だけの評価。定理の適用又は全δの交換とは区別する",
        "command": command[:5] + ["<tmp>/api-names-r4.lean"],
        "exit": 0, "start": started, "end": datetime.now(timezone.utc).isoformat(),
        "seconds": time.monotonic() - before, "input": digest(lean), "raw": digest(raw),
        "expressions": expressions, "tables": {k: sorted(v) for k, v in tables.items()},
    }, ensure_ascii=False, indent=2) + "\n")

    def check(api, evidence):
        assert evidence, api
        for theorem in evidence:
            assert prefix + theorem in all_names, (api, "証拠名が宣言記録にない", theorem)
            ns = theorem.split(".")[0]
            assert ns in tables and api in tables[ns], (api, "証拠の名前の表にない", theorem)

    ordinary = json.loads((HERE / "ordinary-closed-r4.json").read_text())
    assert ordinary["closed"] == len(ordinary["rows"]) == 179 and ordinary["remaining"] == 0
    original_sources = json.loads((HERE / "sources-r2-u28.json").read_text())
    original_ordinary = json.loads((HERE / "ordinary-closed-r2.json").read_text())
    for old_rows, new_rows, dictionary in [(original_sources["rows"], sources["rows"], False),
                                            (original_ordinary["rows"], ordinary["rows"], True)]:
        assert len(old_rows) == len(new_rows)
        for old, new in zip(old_rows, new_rows):
            if dictionary:
                assert {k: v for k, v in old.items() if k != "evidence"} == {
                    k: v for k, v in new.items() if k != "evidence"}
                previous, current = old["evidence"], new["evidence"]
            else:
                assert old[:5] + old[6:] == new[:5] + new[6:]
                previous, current = old[5], new[5]
            assert current[:len(previous)] == previous
            assert all(e.endswith((".response", ".range_response")) for e in current[len(previous):])
    indexed = {row[0]: row for row in sources["rows"]}
    assert len(indexed) == 328
    for row in sources["rows"]:
        check(row[0], row[5])
    assert len({r["api"] for r in ordinary["rows"]}) == 179
    added_responses = 0
    for row in ordinary["rows"]:
        api, evidence = row["api"], row["evidence"]
        check(api, evidence)
        assert row["ordinary"] == indexed[api][4]
        assert set(evidence) <= set(indexed[api][5])
        if row["ordinary"] == "pure-local":
            response = ("StandardListRemainingResponse.range_response" if api == "List.range"
                        else evidence[0].rsplit(".", 1)[0] + ".response")
            assert response in evidence and response in indexed[api][5], api
            added_responses += 1
    assert added_responses == 101
    # 拒否側も同じ照合を使い、存在しない名前と別モジュールのAPIを検出する。
    for api, evidence in [("Byte.toString", ["StandardByteStringResponse.absent_response"]),
                          ("Character.toString", ["StandardByteStringResponse.response"])]:
        try:
            check(api, evidence)
        except AssertionError:
            pass
        else:
            raise AssertionError(("誤った証拠を拒否しなかった", api, evidence))
    return {"source_rows": 328, "ordinary_rows": 179,
            "unique_evidence_names": len({e for r in sources["rows"] for e in r[5]}),
            "response_rows_added": added_responses, "name_tables": len(tables),
            "negative_checks": 2, "names_record": digest(HERE / "api-names-r4.json")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--tag", default="r4-final")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    started = datetime.now(timezone.utc).isoformat()
    baseline = {}
    for path in sorted(HERE.glob("inputs-r4-part-*.json")):
        baseline.update(json.loads(path.read_text()))
    assert baseline
    retained = 0
    prefix = baseline["formal/Benitoite.lean"]
    doc = json.loads((HERE / "floatmath-docstring-r4.json").read_text())
    changed = "formal/Benitoite/Release/Refinement/StandardFloatMathResponse.lean"
    for name, expected in baseline.items():
        path = ROOT / name
        if name == changed:
            text = path.read_text()
            addition = doc["added_docstring"]
            assert text.count(addition) == 1
            data = text.replace(addition, "", 1).encode()
            assert {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} == expected
            assert expected == doc["source_before"]
        else:
            assert digest(path) == expected, name
            retained += name.endswith(".lean")
    modules = json.loads((HERE / "modules-r3.json").read_text())
    old_modules = json.loads((HERE / "modules-r1.json").read_text())
    assert len(modules) == len(set(modules)) == len(old_modules) + 1
    assert set(modules) - set(old_modules) == {NEW}
    default = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
    for name in modules:
        assert "import Benitoite.Release.Refinement." + name in default, name
    audit = json.loads((HERE / f"audit-summary-{args.tag}.json").read_text())
    assert audit["exit"] == audit["new_axioms"] == audit["local_records"] == 0
    assert audit["private_and_generated_included"] and not audit["inventory_only"]
    assert set(audit["new_modules"]) == set(modules)
    previous_audit = json.loads((HERE / "audit-summary-r3-final.json").read_text())
    assert audit["new_modules"] == previous_audit["new_modules"]
    assert audit["targets"] == previous_audit["targets"]
    assert sum(audit["axiom_sets"].values()) == audit["targets"]
    module_record = audit["module_record"]
    assert digest(HERE / module_record["file"]) == {k: module_record[k] for k in ("bytes", "sha256")}
    assert all(set(s.split(" + ")) <= {"none", "propext", "Quot.sound", "Classical.choice"}
               for s in audit["axiom_sets"])
    for part in audit["source_inputs_parts"]:
        path = HERE / part["file"]
        assert digest(path) == {k: part[k] for k in ("bytes", "sha256")}
        for name, expected in json.loads(path.read_text()).items():
            assert digest(ROOT / name) == expected, name
    declarations = {}
    for name in modules:
        source = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
        text = source.read_text()
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", text), name
        assert not re.search(r"\b(?:L\d{2}(?:\.\d+[a-z]?)?|TODO-\d{3}|O\d{3})\b|/Users/", text), name
        record = json.loads((HERE / f"declarations-{args.tag}-{name}.json").read_text())
        assert record["module"] == "Benitoite.Release.Refinement." + name
        names = record.get("names", [])
        if "names_parts" in record:
            for part in record["names_parts"]:
                path = HERE / part["file"]
                assert digest(path) == {k: part[k] for k in ("bytes", "sha256")}
                chunk = json.loads(path.read_text())
                assert len(chunk) == part["count"]
                names += chunk
        assert len(names) == len(set(names)) == record["count"] == audit["new_modules"][name]
        declarations[name] = names
        olean = ROOT / "formal/.lake/build/lib/lean/Benitoite/Release/Refinement" / (name + ".olean")
        assert olean.exists(), name
        # 既存ソースは開始時の内容を上で固定する。Lakeのキャッシュは内容で検査し、
        # 同じ内容のファイルの更新時刻だけでは無効としない。
        if name == "StandardFloatMathResponse":
            assert olean.stat().st_mtime >= source.stat().st_mtime, name
    sources = json.loads((HERE / "sources-r4-u28.json").read_text())
    assert len(sources["rows"]) == sources["counts"]["apis"] == 328
    assert sources["counts"]["pure-local"] == 244 and sources["counts"]["core-local"] == 84
    assert sources["counts"]["open"] == 0
    assert sources["resumed_ordinary"] == {"closed": 179, "remaining": 0}
    for record in ("sources.json", "sources-r3.json"):
        for name, expected in json.loads((HERE / record).read_text())["inputs"].items():
            assert digest(ROOT / name) == expected, name
    obligation = (HERE / "obligations.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", obligation, re.M)
    detail = (HERE.parent / "detail.md").read_text()
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", detail, re.M))
    assert "設計者の判断待ち" in obligation and "再開3" in obligation
    evidence = verify_evidence(args.tmp, declarations, sources)
    checks = json.loads((HERE / "checks-r4.json").read_text())
    assert len({c["label"] for c in checks}) == len(checks)
    for c in checks:
        cmd = c["command"]
        if cmd[:2] == ["lake", "build"]:
            assert cmd == ["lake", "build"] and c["cwd"] == "formal/", c
        if cmd[:3] == ["lake", "env", "lean"]:
            assert cmd[3:5] == ["-M", "12288"] and c["cwd"] == "formal/", c
    final_builds = [c for c in checks if c["command"] == ["lake", "build"]]
    assert len(final_builds) == 1 and final_builds[0]["exit"] == 0
    workcmd = ["scripts/check.sh", "--level", "work", "--base", BASE]
    works = [c for c in checks if c["command"] == workcmd]
    assert not works, "再開4ではworkを実行しない"
    axioms = [c for c in checks if c["label"] == "r4-final-axioms"]
    assert len(axioms) == 1 and axioms[0]["exit"] == 0
    paths = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
    old_paths = {name for name in baseline if name.endswith(".lean")}
    assert {str(p.relative_to(ROOT)) for p in paths} == old_paths
    manifest = args.tmp / "source-manifest-r4.txt"
    manifest.write_text("".join(digest(p)["sha256"] + "  " + str(p.relative_to(ROOT)) + "\n" for p in paths))
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        text = path.read_text()
        assert str(ROOT) not in text, path.name
        if path.suffix == ".py":
            ast.parse(text, filename=path.name)
        if path.suffix == ".md":
            assert not re.search(r"\]\([^)]*docs/todo", text), path.name
            for link in re.findall(r"\]\(([^)]+)\)", text):
                target = link.split("#")[0]
                if "://" not in link and target:
                    assert (path.parent / target).exists(), (path.name, link)
    brief = {
        "exit": 0, "start": started, "end": datetime.now(timezone.utc).isoformat(),
        "seconds": time.monotonic() - start, "base": BASE,
        "modules": len(modules), "audited_modules": audit["module_count"],
        "audited_declarations": audit["targets"], "new_axioms": 0,
        "new_modules": 0, "new_declarations": 0,
        "baseline_lean_unchanged": retained, "docstring_only_lean_changes": 1, "root_retained_prefix_bytes": prefix["bytes"],
        "lean_sources": len(paths), "source_manifest": digest(manifest),
        "apis": 328, "ordinary_counts": sources["counts"], "obligations": 64,
        "closed_normal_refinement_rows": 0, "remaining_normal_refinement_rows": 7,
        "precise_getters_awaiting_designer": 9, "public_signature_changes": 0,
        "work": "設計者の指示により未実行。判断後の群末で一度行う",
        "lean_command_deviations": 0,
        "verification_attempts": 1 + sum(c["label"].startswith("r4-final-verify") for c in checks),
        "new_command_deviations": sum(c["label"].startswith("r4-final-verify") and c["exit"] != 0
                                      for c in checks),
        "cache_validation": "default_lake_build_and_source_sha256",
        "evidence_and_api_names": evidence,

    }
    (HERE / "verification-r4.json").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(brief, ensure_ascii=False))


if __name__ == "__main__":
    main()
