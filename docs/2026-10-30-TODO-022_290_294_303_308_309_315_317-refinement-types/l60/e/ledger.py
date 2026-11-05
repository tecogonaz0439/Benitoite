# -*- coding: utf-8 -*-
"""通常資源・外部型・参照と明示遅延の行の台帳を、Rustの実物と群Aの台帳から作り直す。"""
import json
import re
from support import CHANGE, HERE, PREFIX, ROOT, write

rust_mod = (ROOT / "crates/benitoite/src/runtime/mod.rs").read_text()
enum = re.search(r"pub enum ResourceKind \{(.*?)\}", rust_mod, re.S)[1]
kinds = re.findall(r"^\s*(\w+),", enum, re.M)
assert kinds == ["FileReader", "FileWriter", "HttpListener", "HttpExchange", "TaskGroup"], kinds
report = (ROOT / "crates/benitoite/src/runtime/report.rs").read_text()
constant = {"FileReader": "RESOURCE_FILE_READER", "FileWriter": "RESOURCE_FILE_WRITER",
            "HttpListener": "RESOURCE_HTTP_LISTENER", "HttpExchange": "RESOURCE_HTTP_EXCHANGE",
            "TaskGroup": "RESOURCE_TASK_GROUP"}
display = {}
for kind in kinds:
    assert re.search(r"ResourceKind::%s => text::%s" % (kind, constant[kind]), report), kind
    display[kind] = re.search(r'pub const %s: &str = "([^"]+)";' % constant[kind], report)[1]

previous = json.loads((CHANGE / "l60/a/resources.json").read_text())
assert [r["rust_name"] for r in previous] == ["runtime::ResourceKind::" + k for k in kinds]
assert all(r["classification"] == "仮定" and not r["evidence"] for r in previous)
ledger = []
for part in sorted((CHANGE / "l60/a").glob("ledger-[0-9][0-9].json")):
    ledger.extend(json.loads(part.read_text()))
by_name = {}
for row in ledger:
    by_name.setdefault(row["lean_name"], []).append(row)

def ledger_row(name, classification):
    rows = by_name[name]
    assert len(rows) == 1 and rows[0]["classification"] == classification, (name, rows)
    return rows[0]

lean_names = [r["lean_name"] for r in ledger if "File" in r["lean_name"] and "Handle" in r["lean_name"]]
assert lean_names == ["File.Handle"], lean_names

rows = []
for kind, old in zip(kinds, previous):
    rows.append({"group": "Rustの通常資源", "rust_name": "runtime::ResourceKind::" + kind,
                 "rust_type": display[kind], "lean_name": "該当なし", "classification": "仮定",
                 "evidence": [],
                 "reason": old["reason"] + "。Leanの合成表の資源名に同名の型はなく、開閉状態・中断・失敗理由の算法の証拠もない",
                 "receivers": ["R30", "R50"]})
handle = ledger_row("File.Handle", "合成")
rows.append({"group": "Leanの通常資源", "rust_name": "該当なし（Rustの組込み登録なし）",
             "rust_type": "該当なし", "lean_name": "File.Handle", "classification": "合成",
             "ledger_id": handle["id"],
             "evidence": [PREFIX + n for n in [
                 "StandardModel.resource_iff", "StandardModel.resource_table",
                 "StandardModel.resource_input", "StandardModel.release_all",
                 "ExternalModels.ModelCase.resource_iff", "ExternalModels.ModelCase.resource_table",
                 "ExternalModels.targets_resource_input", "ResourceRelease.Table.release_all",
                 "ResourceRelease.Table.release_value"]],
             "reason": "既存の型付きopaque値と分類の証拠を持つ抽象モデルの資源名。成功と全ての失敗を許す関係を合成表で読む。Rustの五種のどれの実署名でもない",
             "receivers": ["L60.29", "L70", "R30", "R50"]})
rows.append({"group": "外部型", "rust_name": "外部ハンドル（WIT resource）", "rust_type": "Ty.external",
             "lean_name": "Val.externalHandle", "classification": "通常資源に含めない",
             "evidence": [PREFIX + n for n in [
                 "ExternalSignatureLeaves.handle_not_release", "ContTy.release_not_external"]],
             "reason": "解放の関係はopaque定数だけを許し、型付きの解放の枠は外部ハンドルを持たない。受信拒否したownハンドルの解放は既存の担当（L70/R50）に残す",
             "receivers": ["L70", "R50"]})
for name, classification in [("Reference.get", "合成"), ("Reference.set", "合成"),
                             ("Reference.new", "仮定"), ("Reference.update", "仮定"),
                             ("Lazy.force", "仮定")]:
    old = ledger_row(name, classification)
    evidence = ([PREFIX + n for n in ["StandardModel.store_lookup", "StandardModel.reference_rows",
                                      "StandardModel.store_shape",
                                      "StandardModel.ref_get" if name.endswith("get") else "StandardModel.ref_set"]]
                if classification == "合成" else
                [PREFIX + "StandardModel.no_store_transitions"])
    rows.append({"group": "参照と明示遅延", "rust_name": name, "rust_type": "該当なし",
                 "lean_name": name, "classification": classification, "ledger_id": old["id"],
                 "evidence": evidence,
                 "reason": ("ModelTargetsの同じ署名を合成表へ置く。種類[value]・元の依存列の行・操作の効果なしを示す"
                            if classification == "合成" else
                            old["reason"] + "。合成表はこの種類の行を持たないことを全lookupで示す"),
                 "receivers": old.get("receivers", [])})
summary = {"rust_resource_kinds": len(kinds), "rust_assumption": sum(r["group"] == "Rustの通常資源" for r in rows),
           "lean_composed_resources": 1, "external_not_resource": 1,
           "reference_composed": 2, "reference_assumption": 3, "rows": len(rows)}
write(HERE / "resources.json", {"summary": summary, "rows": rows})
print(json.dumps(summary, ensure_ascii=False))
