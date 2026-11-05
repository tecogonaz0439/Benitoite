# -*- coding: utf-8 -*-
"""処理系のReference四署名とLazy.forceを、Rustの登録・標準ソース・LeanのStoreShape・合成表の行と照合する。"""
import json
import re
from support import HERE, ROOT, write

SRC = ROOT / "crates/benitoite/src"
LEAN = ROOT / "formal/Benitoite/Release/Refinement"

# Rustの登録: 名前と呼出しの区分（state/pure）と引数の個数。
registered = {}
for file in ["builtins/funcs/reference.rs", "builtins/funcs/lazy.rs"]:
    text = (SRC / file).read_text()
    for name, mode, args in re.findall(r'name = "([\w.]+)",\s*(state|pure) fn \w+\(ctx(?:, ([^)]*))?\)', text):
        registered[name] = {"mode": mode, "arity": len([a for a in args.split(",") if a.strip()]) if args else 0}
intrinsics = dict(re.findall(r'\("([\w.]+)", Intrinsic::(\w+)\)', (SRC / "types/builtin.rs").read_text()))

# 標準ソースの型付きの宣言。
declared = {}
for file in ["prelude/stdlib/Reference.bnt", "prelude/stdlib/Lazy.bnt"]:
    text = (SRC / file).read_text()
    for name, tps, params, ret, uses in re.findall(
            r'@builtin\("([\w.]+)"\)\npublic function \w+\[(\w+)\]\((.*)\) -> (\S+)(?: uses (\w+))?\n', text):
        pairs = [p.split(": ", 1) for p in re.split(r", (?=\w+: )", params)]
        declared[name] = {"tparams": [tps], "names": [n for n, _ in pairs], "params": [t for _, t in pairs],
                          "ret": ret, "uses": uses or ""}

# 標準ソースの型をLeanのStoreShapeの型の書き方へ写す（型引数Tは.tvar 0）。
def lean_type(t):
    table = {"T": ".tvar 0", "Unit": ".base .unit", "Reference[T]": ".reference (.tvar 0)",
             "Lazy[T]": ".lazy (.tvar 0)", "function(value: T) -> T": '.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty'}
    return table[t]

shape = (LEAN / "ConstraintAssumptions.lean").read_text().split("def PrimSig.StoreShape", 1)[1].split("\n\n", 1)[0]
kinds = {"Reference.new": "refNew", "Reference.get": "refGet", "Reference.set": "refSet",
         "Reference.update": "refUpdate", "Lazy.force": "force"}
scope = (LEAN / "ScopeSignatures.lean").read_text()
composed = {"Reference.get": "refGet", "Reference.set": "refSet"}
rows = []
for name, kind in kinds.items():
    d = declared[name]
    branch = shape.split("| ." + kind + " =>", 1)[1].split("\n  | .", 1)[0]
    names = json.loads(re.search(r"s\.names = (\[[^]]*\])", branch)[1])
    params = re.search(r"s\.params = \[(.*?)\] ∧", " ".join(branch.split()))[1]
    ret = re.search(r"s\.ret = (.*?) ∧", " ".join(branch.split()))[1]
    eff = re.search(r"s\.eff = ([\w.]+(?: stateEff)?)", branch)[1]
    expected_params = ", ".join(lean_type(t) for t in d["params"])
    checks = {
        "Rustの登録": name in registered,
        "引数の個数": registered.get(name, {}).get("arity") == len(d["params"]),
        "名前の列": names == d["names"],
        "引数の型": params == expected_params,
        "結果の型": ret == lean_type(d["ret"]),
        "効果": (eff == "Eff.single stateEff") == (d["uses"] == "State") and
                (eff == "Eff.empty") == (d["uses"] == ""),
        "Rustの呼出し区分": registered[name]["mode"] == ("state" if d["uses"] == "State" else "pure"),
        "型引数1個": len(d["tparams"]) == 1 and "s.tparams.length = 1" in branch,
    }
    row = {"name": name, "kind": kind, "rust": registered[name], "intrinsic": intrinsics.get(name),
           "source": d, "store_shape": {"names": names, "params": params, "ret": ret, "eff": eff},
           "checks": checks}
    if name in composed:
        definition = scope.split("def " + composed[name] + " : PrimSig :=", 1)[1].split("\n\n", 1)[0]
        flat = " ".join(definition.split())
        row["composed"] = {"lean_definition": "ScopeSignatures." + composed[name],
                           "names": json.loads(re.search(r'(\["[^]]*\])', flat)[1]),
                           "kind_matches": "." + kind + "," in flat,
                           "params_match": ("[" + params.replace(", ", ",") + "]") in flat.replace(", ", ","),
                           "ret_matches": ("," + ret + ",") in flat.replace(" ,", ",").replace(", ", ","),
                           "effect_state": "Eff.single stateEff" in flat}
        row["composed"]["names_match"] = row["composed"]["names"] == d["names"]
        row["remaining"] = "なし"
    else:
        row["composed"] = None
        row["remaining"] = "合成表に行がない。L60.23で合成表へ加える行の署名とこの照合を.23/.29で行う"
    rows.append(row)
for row in rows:
    assert all(row["checks"].values()), (row["name"], row["checks"])
    if row["composed"]:
        assert all(v for k, v in row["composed"].items() if k not in ["lean_definition", "names"]), row
summary = {"rust_registrations": len(registered), "checked": len(rows), "composed_rows": len(composed),
           "remaining_to_23_29": [r["name"] for r in rows if r["composed"] is None]}
write(HERE / "reference-signatures.json", {"summary": summary, "rows": rows})
print(json.dumps(summary, ensure_ascii=False))
