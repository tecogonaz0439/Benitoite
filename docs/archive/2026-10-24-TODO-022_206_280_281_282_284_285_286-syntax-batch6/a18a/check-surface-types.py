#!/usr/bin/env python3
"""実交換の全Range入力の式・引数・標準署名を現行StandardRuleの型と照合する。"""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location("surface_keys", ROOT / "crates/benitoite/tests/desugar_export/interval/surface_keys.py")
keys = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keys)


def check(source):
    corpus = json.loads((source / "corpus.json").read_text())
    stdlib = json.loads((source / "stdlib-decls.json").read_text())
    metadata = json.loads((source / "range-bindings.json").read_text())
    assert corpus["version"] == 14 and metadata["version"] == 1
    inputs = {i["name"]: i for i in corpus["inputs"]}
    declarations = {i["name"]: {f["name"]: f["header"] for f in i["functions"]} for i in stdlib["inputs"]}
    rows = []
    for entry in metadata["inputs"]:
        name = entry["name"]
        names = entry["rangeNames"]
        integer = {"base": {"name": "Integer"}}
        owner = {"data": {"name": names["owner"], "args": []}}
        result = {"data": {"name": names["result"], "args": [owner, {"data": {"name": names["error"], "args": []}}]}}
        expected = {entry["checkDeclaration"]: (result, [integer] * 3),
                    entry["valueDeclaration"]: (integer, [owner])}
        calls = []
        for definition in inputs[name]["definitions"]:
            surface = definition["scope"]["inScope"]["surface"]
            for number, expr in keys.numbered(surface):
                if not isinstance(expr, dict) or "call" not in expr:
                    continue
                call = expr["call"]
                callee = call["callee"].get("funName", {})
                if callee.get("name") not in expected:
                    continue
                assert callee["tys"] == [] and callee["effs"] == []
                calls.append((definition["name"].split(" (")[0], number, call))
        assert len(calls) == len(entry["typedCalls"]), name
        for (definition, number, call), actual in zip(calls, entry["typedCalls"]):
            callee = call["callee"]["funName"]["name"]
            assert actual["definition"] == definition and actual["callee"] == callee
            ret, args = expected[callee]
            source_args = [args[position] for position in call["positions"]]
            header = declarations[name][callee]
            comparisons = {"expressionResult": actual["resultType"] == ret,
                           "expressionArguments": actual["argumentTypes"] == source_args,
                           "declarationResult": header["ret"] == ret,
                           "declarationArguments": header["params"] == args}
            rows.append({"input": name, "definition": definition, "surfacePreorder": str(number),
                         "callee": callee, "positions": call["positions"],
                         "actual": actual, "expectedResult": ret, "expectedArguments": source_args,
                         "comparisons": comparisons})
    return {"expectation": "formal/Benitoite/Interval/Eval.lean StandardRule.argumentType/resultType（L21U以後）",
            "inputs": len(inputs), "calls": len(rows), "comparisons": len(rows) * 4,
            "allEqual": all(all(row["comparisons"].values()) for row in rows), "rows": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export-dir", type=Path, default=HERE / "resume-surface-export")
    parser.add_argument("--output", type=Path, default=HERE / "resume-surface-types.json")
    args = parser.parse_args()
    report = check(args.export_dir)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f'{report["inputs"]}入力・{report["calls"]}呼び出し・{report["comparisons"]}照合: {"一致" if report["allEqual"] else "不一致"}')
    raise SystemExit(0 if report["allEqual"] else 1)


if __name__ == "__main__":
    main()
