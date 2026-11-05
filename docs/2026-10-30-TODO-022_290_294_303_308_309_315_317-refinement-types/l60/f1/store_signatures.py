# -*- coding: utf-8 -*-
"""合成表へ加えたReference.new・Reference.update・Lazy.forceの署名を、Rustの登録・標準ソースの宣言・
LeanのStoreShapeと照合し、Process.exitが同じ扱い（δ・IO応答を持たない専用の遷移）に当たるかを調べる。"""
import json
import re
from support import CHANGE, HERE, LEAN, ROOT, write

SRC = ROOT / "crates/benitoite/src"

# Rustの登録: 名前と呼出しの区分と引数の個数（群Eの照合と同じ読み方）。
registered = {}
for file in ["builtins/funcs/reference.rs", "builtins/funcs/lazy.rs"]:
    text = (SRC / file).read_text()
    for name, mode, args in re.findall(r'name = "([\w.]+)",\s*(state|pure) fn \w+\(ctx(?:, ([^)]*))?\)', text):
        registered[name] = {"mode": mode, "arity": len([a for a in args.split(",") if a.strip()]) if args else 0}
declared = {}
for file in ["prelude/stdlib/Reference.bnt", "prelude/stdlib/Lazy.bnt"]:
    text = (SRC / file).read_text()
    for name, tps, params, ret, uses in re.findall(
            r'@builtin\("([\w.]+)"\)\npublic function \w+\[(\w+)\]\((.*)\) -> (\S+)(?: uses (\w+))?\n', text):
        pairs = [p.split(": ", 1) for p in re.split(r", (?=\w+: )", params)]
        declared[name] = {"tparams": [tps], "names": [n for n, _ in pairs], "params": [t for _, t in pairs],
                          "ret": ret, "uses": uses or ""}
TYPES = {"T": ".tvar 0", "Unit": ".base .unit", "Reference[T]": ".reference (.tvar 0)",
         "Lazy[T]": ".lazy (.tvar 0)", "function(value: T) -> T": '.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty'}

signatures = (LEAN / "StandardModelSignatures.lean").read_text()
names = dict(re.findall(r'\| \.(p\d{3}) => "([^"]+)"', signatures))
rows_of = {n: p for p, n in names.items()}
added = {"Reference.new": ("refNewSig", "refNew"), "Reference.update": ("refUpdateSig", "refUpdate"),
         "Lazy.force": ("forceSig", "force")}
previous = json.loads((CHANGE / "l60/e/reference-signatures.json").read_text())
expected_shape = {r["name"]: r["store_shape"] for r in previous["rows"]}
rows = []
for name, (definition, kind) in added.items():
    body = signatures.split("def %s : PrimSig :=" % definition, 1)[1].split("\n/--", 1)[0].split("\ninductive", 1)[0]
    flat = " ".join(body.split())
    fields = re.match(r"⟨\[TypeCtx\.valueParam\],0,(\[[^]]*\]),\s?\[(.*)\],\s?(.*?),(Eff\.\w+(?: stateEff)?),"
                      r"\s?\(fun _ ts => ts\.length = 1\),\.(\w+),none,\[\],\.untargeted⟩$", flat)
    assert fields, (name, flat)
    lean = {"names": json.loads(fields[1]), "params": fields[2].replace(",.", ", ."), "ret": fields[3],
            "eff": fields[4], "kind": fields[5]}
    d = declared[name]
    shape = expected_shape[name]
    row = rows_of[name]
    checks = {
        "合成表の行": "| .%s => %s\n" % (row, definition) in signatures and
                     "| .%s => source23\n" % row in signatures,
        "種類": lean["kind"] == kind,
        "名前の列とStoreShape": lean["names"] == shape["names"] == d["names"],
        "引数の型とStoreShape": lean["params"] == shape["params"] == ", ".join(TYPES[t] for t in d["params"]),
        "結果の型とStoreShape": lean["ret"] == shape["ret"] == TYPES[d["ret"]],
        "効果とStoreShape": lean["eff"] == shape["eff"] and
                          (lean["eff"] == "Eff.single stateEff") == (d["uses"] == "State"),
        "型引数1個（種類value）": len(d["tparams"]) == 1,
        "Rustの登録と引数の個数": registered[name]["arity"] == len(d["params"]),
        "Rustの呼出し区分": registered[name]["mode"] == ("state" if d["uses"] == "State" else "pure"),
        "δ・IO応答を定義しない": "%s" % definition not in
            (LEAN / "StandardModelResponse.lean").read_text(),
    }
    assert all(checks.values()), (name, checks)
    rows.append({"name": name, "row": "StandardModel.Primitive." + row,
                 "lean_definition": "StandardModel." + definition, "lean": lean, "rust": registered[name],
                 "source": d, "checks": checks})

# Process.exit: Rustはioの登録で、範囲外の終了コードを実行時の誤りにする。Leanのexitの種類はE_Exit・
# E_IOErrで同じ表のioResponseを読み、δ・IO応答のない専用の遷移ではない。
process = (SRC / "builtins/funcs/process.rs").read_text()
exit_body = process.split('name = "Benitoite.IO.Process.exit",', 1)[1].split("builtin!", 1)[0]
semantics = (ROOT / "formal/Benitoite/Release/Refinement/Semantics.lean").read_text()
step = semantics.split("inductive Step ", 1)[1]
exit_rules = [b.split()[0] for b in re.split(r"^  \| ", step, flags=re.M)[1:] if "s.kind = .exit" in b]
store_rules = {k: [b.split()[0] for b in re.split(r"^  \| ", step, flags=re.M)[1:] if "s.kind = .%s" % k in b]
               for k in ["refNew", "refUpdate", "force"]}
targets = (LEAN / "ModelTargets.lean").read_text()
ledger = []
for part in sorted((CHANGE / "l60/a").glob("ledger-[0-9][0-9].json")):
    ledger.extend(json.loads(part.read_text()))
process_row = [r for r in ledger if r["lean_name"] == "Process.exit"]
exit_row = [r for r in ledger if r["lean_name"] == "exit"]
assert len(process_row) == 1 and len(exit_row) == 1
process_exit = {
    "rust_io": "io fn exit(ctx, code: i64)" in exit_body,
    "rust_range_error": "u8::try_from(code)" in exit_body and "ArgumentOutOfDomain" in exit_body,
    "rust_exit_reply": "IoReply::Exit" in exit_body,
    "lean_exit_rules_read_ioResponse": sorted(exit_rules),
    # ハンドラのない呼出しはioResponseを読み、ハンドラのある呼出し（E_OpPrim）は節へ移る。
    "unhandled_exit_rules_read_ioResponse": all("B.ioResponse" in b for b in re.split(r"^  \| ", step, flags=re.M)[1:]
                                                if "s.kind = .exit" in b and "NoHandler" in b),
    "store_rules_without_response": {k: v for k, v in store_rules.items()},
    "store_rules_read_no_response": all(
        "ioResponse" not in b and "B.delta" not in b for b in re.split(r"^  \| ", step, flags=re.M)[1:]
        if any("s.kind = .%s" % k in b for k in store_rules)),
    "model_exit_code_total": "| [.const (.integer n)] => n.toInt" in targets and
        '(b = "exit" ∧ out = .exit (exitCode ws) ∧ obs = [])' in targets,
    "ledger_process_exit": {"id": process_row[0]["id"], "classification": process_row[0]["classification"],
                            "rust_names": process_row[0]["rust_names"]},
    "ledger_model_exit": {"id": exit_row[0]["id"], "classification": exit_row[0]["classification"],
                          "rust_names": exit_row[0]["rust_names"]},
}
assert process_exit["rust_io"] and process_exit["rust_range_error"] and process_exit["rust_exit_reply"]
assert process_exit["unhandled_exit_rules_read_ioResponse"] and sorted(exit_rules) == ["E_Exit", "E_IOErr", "E_OpPrim"]
assert process_exit["store_rules_read_no_response"]
assert all(store_rules[k] for k in store_rules)
assert process_exit["model_exit_code_total"]
judgement = ("同じ扱いに当たらない。Process.exitの種類exitの実行は、ハンドラのない呼出しではE_Exit・E_IOErrが"
             "同じ表のioResponseを読み（ハンドラのある呼出しはE_OpPrimで節へ移る）、δ・IO応答のない専用の遷移ではない。"
             "署名だけを合成表へ置くと、io_existsの欄が全ての型付き引数に応答を求めるので、新しいIO応答の意味を"
             "定義しない限り閉じない。合成表の既存のexit（ModelTargetsのモデル）は全ての整数を終了コードにし、"
             "処理系の範囲外の誤り（0〜255の外）を写さないので、Process.exitの証拠として流用しない。"
             "台帳の仮定側の行は残し、理由を「専用の遷移」からIO応答の仮定へ改める")
write(HERE / "store-signatures.json", {"rows": rows, "process_exit": process_exit,
                                        "process_exit_judgement": judgement})
print(json.dumps({"checked": len(rows), "all": all(all(r["checks"].values()) for r in rows),
                  "exit_rules": exit_rules, "store_rules": store_rules}, ensure_ascii=False))
