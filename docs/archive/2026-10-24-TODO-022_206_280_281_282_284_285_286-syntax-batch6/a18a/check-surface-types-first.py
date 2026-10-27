#!/usr/bin/env python3
"""保存した実交換の型と StandardRule の型を照合する。Lean は実行しない。"""
import json
from pathlib import Path
import sys

directory = Path(__file__).resolve().parent
source = directory / "surface-export"
corpus = json.loads((source / "corpus.json").read_text())["inputs"][0]
stdlib = json.loads((source / "stdlib.json").read_text())["inputs"][0]
builtins = json.loads((source / "builtins.json").read_text())["inputs"][0]
definitions = {
    d["name"].split(" (")[0]: d["scope"]["inScope"]["surface"]
    for d in corpus["definitions"]
}
declarations = {d["name"]: d["header"] for d in stdlib["functions"]}
names = {d["typeName"]: d["name"] for d in builtins["dataDecls"]}
integer = {"base": {"name": "Integer"}}
owner = {"opaque": {"name": names["CheckedInteger"]}}
result = {"data": {"name": names["Result"], "args": [
    owner, {"data": {"name": names["RangeError"], "args": []}}
]}}

# 関数の戻り値の文脈と標準宣言を両方読み、数値の BindingId を固定しない。
check_source = definitions["upperEndpoint"]
check = check_source["body"]["last"]["expr"]["returnE"]["inner"]["call"]
check_header = declarations[check["callee"]["funName"]["name"]]
recheck = definitions["recheck"]
value = recheck["body"]["last"]["expr"]["returnE"]["inner"]["call"]["args"][2]["call"]
value_header = declarations[value["callee"]["funName"]["name"]]
assert check["positions"] == [0, 1, 2]
assert check["callee"]["funName"]["tys"] == []
assert value["callee"]["funName"]["tys"] == []
assert check_source["header"]["ret"] == check_header["ret"]
assert value["args"] == [{"local": {"index": 0}}]
assert recheck["header"]["params"] == value_header["params"]

comparisons = []
for function, field, actual, expected in [
    ("Range.checkInteger", "resultType", check_header["ret"], result),
    ("Range.checkInteger", "argumentType", check_header["params"], [integer] * 3),
    ("Range.value", "resultType", value_header["ret"], integer),
    ("Range.value", "argumentType", value_header["params"], [owner]),
]:
    comparisons.append({"function": function, "field": field,
                        "actual": actual, "expected": expected,
                        "equal": actual == expected})

report = {
    "source": "crates/benitoite/tests/desugar_export/batch3/range.bnt",
    "expectation": "formal/Benitoite/Interval/Eval.lean:380-388 StandardRule.argumentType/resultType",
    "decoder": "formal/Benitoite/Exchange/Syntax.lean:71-72 (data と opaque を別々に読む)",
    "rangeNames": names,
    "checkedIntegerDeclaration": next(d for d in builtins["dataDecls"]
                                      if d["typeName"] == "CheckedInteger"),
    "comparisons": comparisons,
    "allEqual": all(c["equal"] for c in comparisons),
}
(directory / "surface-types.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n")
for c in comparisons:
    print(f'{c["function"]}.{c["field"]}: {"一致" if c["equal"] else "不一致"}')
sys.exit(0 if report["allEqual"] else 1)
