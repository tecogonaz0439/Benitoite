# -*- coding: utf-8 -*-
"""合成表の台帳（StandardModelSignatures）の行を出典の表ごとに分け、数値の純粋な行と演算子の行の
分類・各行の族の引数・件数を求める。--emit を付けると、分類の定義と全場合の証明の各行を
Leanの字面として標準出力へ出す（本番のモジュールへの貼り付けに使う）。"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SRC = (ROOT / "formal/Benitoite/Release/Refinement/StandardModelSignatures.lean").read_text()
NAMES = dict(re.findall(r'\| \.(p\d{3}) => "([^"]+)"', SRC))
PROVIDERS = dict(re.findall(r'\| \.(p\d{3}) => (source\d+)\n', SRC))
INT = {"Integer": "integer64", "Integer8": "integer8", "Integer16": "integer16", "Integer32": "integer32",
       "UnsignedInteger16": "unsignedInteger16", "UnsignedInteger32": "unsignedInteger32",
       "UnsignedInteger64": "unsignedInteger64"}
ORDER = dict(INT, Byte="byte", Character="character", Float32="float32", Float="float64", Decimal="decimal")
COMPARE = {"less": "lt", "lessOrEqual": "le", "greater": "gt", "greaterOrEqual": "ge"}
NUMERIC_MODULES = ["Byte", "Character", "Float", "Float32", "Decimal"] + list(INT)
SCALAR = {"Byte.fromInteger": "byteFrom", "Byte.toInteger": "byteTo", "Byte.bitwiseAnd": "byteAnd",
          "Byte.bitwiseOr": "byteOr", "Byte.bitwiseExclusiveOr": "byteXor", "Byte.bitwiseNot": "byteNot",
          "Byte.shiftLeft": "byteLeft", "Byte.shiftRight": "byteRight", "Character.fromInteger": "characterFrom",
          "Character.toInteger": "characterTo", "Float.isNaN": "floatNaN", "Float32.isNaN": "float32NaN",
          "Float32.isInfinite": "float32Infinite"}
DECIMAL = {"Decimal.round": "round", "Decimal.absolute": "absolute", "Decimal.fromInteger": "fromInteger",
           "UnsignedInteger64.toDecimal": "toDecimal", "Decimal.truncate": "truncate",
           "UnsignedInteger64.fromDecimal": "fromDecimal"}


def split(name):
    module, _, op = name.lstrip("%").partition(".")
    return module, op


def family(p):
    """行を (分類, 族, Leanの引数の字面) へ写す。分類は operator・numeric・other。"""
    name, source = NAMES[p], PROVIDERS[p]
    module, op = split(name)
    if source == "source18":
        if module in INT:
            return "operator", "operator", "(.integer .%s %s)" % (INT[module], "true" if op == "mod" else "false")
        if module in ("Float", "Float32"):
            return "operator", "operator", "(.floating %s .%s)" % ("true" if module == "Float32" else "false", op)
        if module == "Decimal":
            return "operator", "operator", "(.decimal .%s)" % op
        assert module == "String", name
        return "operator", "operator", "(.string .%s)" % op
    if source == "source14":
        return "operator", "arithmetic", ".%s .%s" % (INT[module], op)
    if source == "source19":
        return "operator", "order", ".%s .%s" % (ORDER[module], COMPARE[op])
    if source == "source20":
        return "operator", "structural", {"%eq": "true", "%ne": "false"}[name]
    if source == "source2":
        return "numeric", "scalar", "." + SCALAR[name]
    if source == "source3":
        return "numeric", "byteString", ""
    if source == "source4":
        return "numeric", "character", "." + op
    if source == "source10":
        return "numeric", "numericRemaining", ".%s_%s" % (module, op)
    if source == "source11":
        return "numeric", "integerAPI", ".%s .%s" % (INT[module], op)
    if source == "source12":
        return "numeric", "integerText", ".%s .%s" % (INT[module], op)
    if source == "source13":
        return "numeric", "conversion", ".%s %s" % (INT[module], "true" if op == "fromInteger" else "false")
    if source == "source15":
        return "numeric", "decimal", "." + DECIMAL[name]
    if source == "source16":
        return "numeric", "floatMath", "%s .%s" % ("true" if module == "Float32" else "false", op)
    if source == "source17":
        return "numeric", "minMax", ".%s %s" % (INT[module], "true" if op == "maximum" else "false")
    return "other", None, None


# 族の補題が利用可能性・比較の種類の前提を取る族。前提は具体の引数で定義を開いて decide で閉じる。
DECIDED = {"arithmetic": " (by unfold StandardArithmeticResponse.API.available; decide)",
           "order": " (by unfold StandardOrderResponse.Ordered; decide)",
           "integerAPI": " (by unfold StandardIntegerAPI.API.available; decide)",
           "conversion": " (by decide)"}
rows = sorted(NAMES)
table = {p: family(p) for p in rows}
# 分類と名前の基準の一致：演算子は%で始まり%Map.replaceValuesでない行、数値は数値の公開モジュールの行。
for p in rows:
    name = NAMES[p]
    module, _ = split(name)
    operator = name.startswith("%") and name != "%Map.replaceValues"
    numeric = not name.startswith("%") and module in NUMERIC_MODULES
    assert (table[p][0] == "operator") == operator, name
    assert (table[p][0] == "numeric") == numeric, name
counts = {}
for p in rows:
    counts.setdefault(table[p][0], {}).setdefault(table[p][1] or "-", 0)
    counts[table[p][0]][table[p][1] or "-"] += 1
summary = {"rows": len(rows), "operator": sum(v[0] == "operator" for v in table.values()),
           "numeric": sum(v[0] == "numeric" for v in table.values()), "families": counts}
FIRST = ["p067", "p072", "p047", "p052", "p057", "p062", "p037", "p042", "p083", "p088", "p092", "p097",
         "p101", "p106", "p018", "p026"]
assert all(table[p][1] == "operator" for p in FIRST)
if "--json" in sys.argv:
    print(json.dumps({"summary": summary, "rows": [
        {"row": p, "name": NAMES[p], "kind": table[p][0], "family": table[p][1], "arguments": table[p][2],
         "first_sixteen": p in FIRST} for p in rows if table[p][0] != "other"]}, ensure_ascii=False))
elif "--emit" in sys.argv:
    for kind in ("operator", "numeric"):
        print("-- %s" % kind)
        members = [p for p in rows if table[p][0] == kind]
        print("  | " + " | ".join("." + p for p in members) + " => true")
        for p in members:
            _, fam, args = table[p]
            side = DECIDED.get(fam, "")
            print("  case %s => exact PureRow.%s .%s %s%s rfl rfl rfl" % (p, fam, p, args, side) if args else
                  "  case %s => exact PureRow.%s .%s rfl rfl rfl" % (p, fam, p))
else:
    print(json.dumps(summary, ensure_ascii=False))
