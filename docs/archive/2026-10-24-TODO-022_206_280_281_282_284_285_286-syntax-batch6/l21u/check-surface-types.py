#!/usr/bin/env python3
"""実交換の型と構成子を同定し、Lean の照合入力を生成する。Lean の実行は別に記録する。"""
import hashlib
import json
from pathlib import Path
import sys

directory = Path(__file__).resolve().parent
source = directory.parent / "a18a" / "surface-export"
corpus = json.loads((source / "corpus.json").read_text())["inputs"][0]
stdlib = json.loads((source / "stdlib.json").read_text())["inputs"][0]
builtins = json.loads((source / "builtins.json").read_text())["inputs"][0]
definitions = {
    d["name"].split(" (")[0]: d["scope"]["inScope"]["surface"]
    for d in corpus["definitions"]
}
declarations = {d["name"]: d["header"] for d in stdlib["functions"]}
integer = {"base": {"name": "Integer"}}

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

# 所有元は標準呼び出しの型から取得し、型名・構成子の表示名から推測しない。
result_actual = check_header["ret"]["data"]
owner = result_actual["args"][0]
error = result_actual["args"][1]
owner_name = owner["data"]["name"]
assert owner["data"]["args"] == [] and error["data"]["args"] == []
by_owner = {decl["name"]: decl for decl in builtins["dataDecls"]}
checked_decl = by_owner[owner_name]
assert checked_decl["isRecord"] and checked_decl["ntys"] == 0
assert not checked_decl["extensible"] and len(checked_decl["ctors"]) == 1
checked_ctor = checked_decl["ctors"][0]
assert checked_ctor["fields"] == ["minimum", "maximum", "value"]
assert checked_ctor["args"] == [integer] * 3
result_decl = by_owner[result_actual["name"]]
assert result_decl["builtin"] == "result" and result_decl["ntys"] == 2
ok, = [c for c in result_decl["ctors"] if c["args"] == [{"tvar": {"index": 0}}]]
err, = [c for c in result_decl["ctors"] if c["args"] == [{"tvar": {"index": 1}}]]
error_decl = by_owner[error["data"]["name"]]
invalid, = [c for c in error_decl["ctors"] if c["args"] == [integer] * 2]
outside, = [c for c in error_decl["ctors"] if c["args"] == [integer] * 3]
names = {"owner": owner_name, "checkedConstructor": checked_ctor["name"],
         "result": result_decl["name"], "error": error_decl["name"],
         "ok": ok["name"], "err": err["name"],
         "invalidBounds": invalid["name"], "outOfRange": outside["name"]}
result = {"data": {"name": names["result"], "args": [owner, error]}}

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
    "expectation": "formal/Benitoite/Interval/Eval.lean StandardRule.argumentType/resultType",
    "decoder": "formal/Benitoite/Exchange/Syntax.lean:71-72 (data と opaque を別々に読む)",
    "rangeNames": names,
    "checkedIntegerDeclaration": checked_decl,
    "checkedConstructor": checked_ctor["name"],
    "constructorFieldsEqual": True,
    "comparisons": comparisons,
    "allEqual": all(c["equal"] for c in comparisons),
    "leanDefinitionSourceSha256": hashlib.sha256(
        (directory.parents[2] / "formal/Benitoite/Interval/Eval.lean").read_bytes()).hexdigest(),
}
(directory / "surface-types.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n")
for c in comparisons:
    print(f'{c["function"]}.{c["field"]}: {"一致" if c["equal"] else "不一致"}')
# この入力で StandardRule と実際の構成子値を照合する。具体実行は #guard に限る。
quote = lambda value: json.dumps(value, ensure_ascii=False)
lean_names = ", ".join(quote(names[k]) for k in
    ["owner", "checkedConstructor", "result", "error", "ok", "err", "invalidBounds", "outOfRange"])
owner_q, ctor_q, result_q, error_q, ok_q = map(quote,
    [names["owner"], names["checkedConstructor"], names["result"], names["error"], names["ok"]])
lean = f'''import Benitoite.Interval.Range
import Benitoite.Interval.EvalClosed

-- 名前は保存した実交換の宣言と関数の型から取得した。同定番号を推測しない。
open Benitoite.Interval Benitoite.Release
private def names : RangeNames := ⟨{lean_names}⟩
private def key : OperationKey := ⟨"L21U.surface", 0⟩

example : (StandardRule.rangeValue names.record).argumentType = .data {owner_q} [] := rfl
example : (StandardRule.rangeCheck names).resultType =
    .data {result_q} [.data {owner_q} [], .data {error_q} []] := rfl
example : rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ =
    .con {owner_q} [] {ctor_q}
      [.integer ⟨0, by decide⟩, .integer ⟨10, by decide⟩, .integer ⟨5, by decide⟩] := rfl

#guard
  match rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ with
  | .normal (.con owner [] constructor [.integer lo, .integer hi, .integer value]) =>
      owner == {owner_q} && constructor == {ctor_q} &&
      (lo.toInt, hi.toInt, value.toInt) == (0, 10, 5)
  | _ => false
#guard
  let payload := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
  match ClosedEval.standard (.rangeValue names.record) key [payload] with
  | some ⟨.normal (.integer value), _⟩ => value.toInt == 5
  | _ => false
#guard
  match (StandardRule.rangeCheck names).finish
      (rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩) with
  | .normal (.con owner [.data checked [], .data error []] constructor
      [.con stored [] tag [.integer lo, .integer hi, .integer value]]) =>
      owner == {result_q} && checked == {owner_q} && error == {error_q} && constructor == {ok_q} &&
      stored == {owner_q} && tag == {ctor_q} && (lo.toInt, hi.toInt, value.toInt) == (0, 10, 5)
  | _ => false
'''
(directory / "surface-check.lean").write_text(lean)
report["generatedLeanInputSha256"] = hashlib.sha256(lean.encode()).hexdigest()
report["inputSha256"] = {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                         for name in ["corpus.json", "stdlib.json", "builtins.json"]}
(directory / "surface-types.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print("レコードの所有元・構成子・三欄:", names["owner"], names["checkedConstructor"], checked_ctor["fields"])
sys.exit(0 if report["allEqual"] else 1)
