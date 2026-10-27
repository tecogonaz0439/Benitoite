"""実交換と独立期待値をX02・X03b用に保存する。Lean/VMの比較は実行しない。"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from surface_keys import numbered

DIRECTORY = Path(__file__).resolve().parent


def prepare(source):
    corpus = json.loads((source / "corpus.json").read_text())
    metadata = json.loads((source / "range-bindings.json").read_text())
    bindings = {i["name"]: i for i in metadata["inputs"]}
    definitions = {}
    for entry in corpus["inputs"]:
        binding = bindings[entry["name"]]
        for definition in entry["definitions"]:
            name = definition["name"].split(" (")[0]
            surface = definition["scope"]["inScope"]["surface"]
            nodes = list(numbered(surface))
            calls, operations = [], []
            for key, expr in nodes:
                if not isinstance(expr, dict):
                    continue
                if "call" in expr:
                    call = expr["call"]
                    callee = call["callee"].get("funName", {}).get("name")
                    operation = {"key": str(key), "kind": "call", "callee": callee,
                                 "positions": call["positions"], "labels": call["labels"]}
                    operations.append(operation)
                    if callee in [binding["checkDeclaration"], binding["valueDeclaration"]]:
                        calls.append([str(key), callee])
                elif "binary" in expr:
                    operations.append({"key": str(key), "kind": expr["binary"]["op"]})
            definitions[(entry["name"], name)] = {
                "input": entry["name"], "name": name, "exchangeName": definition["name"],
                "expressionCount": str(len(nodes)), "operationsInPreorder": operations,
                "rangeNames": binding["rangeNames"],
                "standards": ([{"declaration": binding["checkDeclaration"], "rangeCheck": binding["rangeNames"]},
                               {"declaration": binding["valueDeclaration"], "rangeValue": {
                                   "owner": binding["rangeNames"]["owner"],
                                   "constructor": binding["rangeNames"]["checkedConstructor"]}}] if calls else []),
                "apiAt": calls,
                "matches": [str(key) for key, expr in nodes if isinstance(expr, dict) and "matchE" in expr],
            }
    expected = json.loads((DIRECTORY / "range-expectations.json").read_text())
    for case in expected["cases"]:
        binding = bindings[case["input"]]
        case["definitions"] = {}
        for role in ["raw", "projection", "onlyOk", "fields", "caller"]:
            if role not in case:
                continue
            definition = definitions[(case["input"], case[role])]
            events = definition["operationsInPreorder"]
            check = [op["key"] for op in events if op.get("callee") == binding["checkDeclaration"]]
            value = [op["key"] for op in events if op.get("callee") == binding["valueDeclaration"]]
            add = [op["key"] for op in events if op["kind"] == "add"]
            if role == "raw":
                trace = check
            elif role in ["projection", "onlyOk"] and case["id"] != "fake-identity":
                rejected = "Error" in case.get("result", {})
                trace = check + ([] if rejected else value + add)
            else:
                trace = None
            case["definitions"][role] = {"name": case[role], "expectedTrace": trace}
            if role == "onlyOk":
                case["definitions"][role]["intervalObservation"] = {
                    "key": definition["matches"][0], "component": "normal", "excludeReturned": True}
                # Errorのreturnは関数のreturned成分には残る。成功側のnormalとは区別する。
    return {"version": 1, "profile": "range", "surfaceVersion": 14, "traversalVersion": 1,
            "status": "A18aの比較入力。X01のinterval-corpusへの接続・X02の全比較・X03bのVM比較は未実施",
            "sourceHashes": {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(source.glob("*.bnt"))},
            "definitions": list(definitions.values()), "cases": expected["cases"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--save-dir", type=Path)
    args = parser.parse_args()
    report = prepare(args.export_dir)
    output = args.save_dir or args.export_dir
    output.mkdir(parents=True, exist_ok=True)
    if output.resolve() != args.export_dir.resolve():
        for source in args.export_dir.iterdir():
            if source.suffix in {".bnt", ".json"}:
                shutil.copyfile(source, output / source.name)
    (output / "range-inputs.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f'{len(report["cases"])}例・{len(report["definitions"])}定義の元Surfaceと番号対応を保存。VM比較は未実施。')


if __name__ == "__main__":
    main()
