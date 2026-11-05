"""群Cの全欄・署名・読者・既定importと、保護対象・保存記録を照合する。"""
import argparse
import ast
import collections
import hashlib
import json
from pathlib import Path
import re
from support import HERE, ROOT, CHANGE, MODULES, closure, digest, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()

def read(file):
    return json.loads((HERE / file).read_text())

baseline = read("baseline.json")
protected = {}
for part in baseline["parts"]:
    f = HERE / part["file"]
    assert digest(f) == {k: part[k] for k in ["bytes", "sha256"]}
    protected.update(json.loads(f.read_text()))
assert len(protected) == baseline["files"]
root_import = "formal/Benitoite.lean"
transport = "formal/Benitoite/Release/Refinement/ExternalModelTransport.lean"
spec = "docs/design/01-spec/01-12-core-calculus.md"
quality = "docs/design/07-quality/07-04-formal-semantics.md"
changed = {root_import, transport, spec, quality}
for rel, old in protected.items():
    f = ROOT / rel
    assert f.is_file(), rel
    if rel not in changed:
        assert digest(f)["sha256"] == old, rel
        continue
    s = f.read_text()
    if rel == root_import:
        for name in MODULES[1:]:
            line = f"import {name}\n"
            assert s.count(line) == 1
            s = s.replace(line, "")
    elif rel == transport:
        s = s.replace("import Benitoite.Release.Refinement.ExternalConnection\n", "")
        start = s.index("\n/-- 同じ宣言の具体化")
        end = s.index("end ExternalModel", start)
        s = s[:start] + s[end:]
    else:
        marker = "`ExternalModel.response_value` は" if rel == spec else "`ExternalModelTransport` は"
        last = ("Modelのpure・IO・exit署名を要する条件は `model_no_response_kind` により、`io_kind` の応答の前提は空のIO応答関係により矛盾する。"
                if rel == spec else "ゲストの変換・所有権の実装や、Rustとの応答の一致はこの証人に含めない。")
        start = s.index("\n\n" + marker)
        end = s.index(last, start) + len(last)
        s = s[:start] + s[end:]
        if rel == quality:
            s = "\n".join(line for line in s.split("\n")
                          if not line.startswith("| ExternalModelExamples |")
                          and not line.startswith("| ExternalModels |"))
    assert hashlib.sha256(s.encode()).hexdigest() == old, (rel, "追加箇所以外に差分")

modules = closure()
assert set(MODULES) <= set(modules)
write(HERE / "modules.json", modules)
summary = read("audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
rows = []
for part in summary["parts"]:
    assert digest(HERE / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
    rows.extend(read(part["file"]))
assert len(rows) == len({r["name"] for r in rows}) == summary["declarations"]
for row in rows:
    assert hashlib.sha256(row["type"].encode()).hexdigest() == row["type_sha256"]
    assert "⋯" not in row["type"] and "..." not in row["type"]
by_name = {r["name"]: r for r in rows}
inherited = set(read("inherited-declarations.json"))
assert inherited <= set(by_name)
assert {r["name"] for r in read("added-declarations.json")} == set(by_name) - inherited
assert len(set(by_name) - inherited) == summary["added_declarations"]
assert digest(args.tmp / "axioms.log") == summary["raw"]

# 名前付きの定理の型と値の依存。無名の適用例は別の欄へ記す。
incoming = collections.defaultdict(list)
for row in rows:
    for dep in row["dependencies"]:
        if dep != row["name"]:
            incoming[dep].append(row["name"])
public = []
for module in MODULES:
    source = ROOT / "formal" / (module.replace(".", "/") + ".lean")
    source_text = source.read_text()
    if module == MODULES[0]:
        names = ["ExternalModel." + n for n in
                 ["response_value", "receive_value", "receive_reject", "receive_error_no_exit"]]
        prefix = "Benitoite.Release.Refinement."
    else:
        names = re.findall(r"^(?:noncomputable )?(?:def|theorem|inductive) ([A-Za-z][\w.]*)", source_text, re.M)
        prefix = module + "."
    for short in names:
        name = prefix + short
        assert name in by_name, name
        readers = sorted(incoming[name])
        # 既定環境の中で型検査した具体の適用例の本文だけを調べる。
        examples = re.split(r"^example\b", source_text, flags=re.M)[1:]
        tail = short.split(".")[-1]
        direct = bool(not readers and any(re.search(r"(?<![\w])" + re.escape(tail) + r"(?![\w])", ex) for ex in examples))
        assert readers or direct, name
        public.append({"name": name, "named_readers": readers,
                       "compiled_example": direct,
                       "note": "shape_inputs/handle_inputsをconditionsへ渡す読者は宣言条件の射影を読む。生応答の全前提は既定の適用例とreceive_pair/handle_receive_pairでも照合する"})
write(HERE / "readers.json", public)

conditions = read("conditions.json")
old = json.loads((CHANGE / "l50/l/condition-judgments.json").read_text())
model_map = {"Model.builtins": "model", "ModelTargets.builtins": "targets", "ModelHttp.builtins": "http"}
fields = {r["field"] for r in old}
assert len(old) == 75 and len(fields) == 25
assert len(conditions) == len({(r["model"],r["field"]) for r in conditions}) == 87
for r in old:
    match = next(x for x in conditions if (x["model"], x["field"]) == (model_map[r["model"]],r["field"]))
    assert match["judgment"] == ("空疎" if r["premises_prove_false"] else "実質")
for model in model_map.values():
    own = [r for r in conditions if r["model"] == model]
    assert {r["field"] for r in own} == fields | {"external_typed", "external_exists", "external_no_targets", "release_exists"}
    for r in own:
        expected = ("自明" if r["field"] == "external_exists" else
                    "空疎" if r["field"] == "release_exists" and model != "targets" else "実質")
        if r["field"] not in fields:
            assert r["judgment"] == expected
counts = dict(collections.Counter(r["judgment"] for r in conditions))
assert counts == {"実質": 76, "空疎": 8, "自明": 3}

# 二十五欄の母集団を本番の四構造体から独立に再抽出する。
def source_fields(file, structure):
    text = (ROOT / "formal/Benitoite/Release/Refinement" / file).read_text()
    section = re.split(r"^(?:structure|theorem|def|namespace|end) ", text.split("structure " + structure, 1)[1], maxsplit=1, flags=re.M)[0]
    return set(re.findall(r"^  (\w+) :", section, re.M))
flat = source_fields("SubstitutionContracts.lean", "Builtins.ValueAssumptions")
flat |= source_fields("SubstitutionContracts.lean", "Builtins.TypeAssumptions")
flat |= source_fields("BuiltinResponse.lean", "Builtins.ResponseAssumptions")
flat |= source_fields("BuiltinResponse.lean", "Builtins.TargetAgreement")
flat |= source_fields("TargetModelConditions.lean", "ModelScopeConditions")
assert flat == fields, (flat - fields, fields - flat)

# 技術的な全称の証明はLeanの帰納と三表のcasesで検査済み。ここでは入口と記録を照合する。
for module in MODULES:
    f = ROOT / "formal" / (module.replace(".", "/") + ".lean")
    text = f.read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|set_option max(?:Heartbeats|RecDepth)|L60\.", text)
for f in HERE.glob("*.py"):
    ast.parse(f.read_text())
files = [f for f in HERE.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
assert all(f.stat().st_size <= 100000 for f in files)
assert sum(f.stat().st_size for f in files) < 3000000
for f in files:
    if f.suffix in [".md", ".json", ".py", ".lean", ".patch"]:
        text = f.read_text()
        assert "/" + "Users" + "/" not in text and not re.search(r"\]\([^)]*docs/todo", text), f.name
        if f.suffix == ".md":
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if not re.match(r"https?://|#", target):
                    assert (f.parent / target.split("#")[0]).exists(), (f.name,target)
for rel, expected in read("tools.json")["inputs"].items():
    assert digest(ROOT / rel) == expected, (rel, "最終入力が変更された")
new_lean = {str(f.relative_to(ROOT)) for f in (ROOT / "formal").rglob("*.lean")
            if ".lake" not in f.parts and str(f.relative_to(ROOT)) not in protected}
assert new_lean == {"formal/" + m.replace(".", "/") + ".lean" for m in MODULES[1:]}, new_lean
for name in ["default-build", "axioms"]:
    record = read(name + ".json")
    assert record["exit"] == 0
    assert record["raw"] == digest(args.tmp / (name + ".log"))
    if name == "default-build":
        assert record["cwd"] == "formal" and record["command"] == ["lake", "build"]
        raw = (args.tmp / (name + ".log")).read_text()
        assert "Build completed successfully" in raw
        for module in MODULES:
            assert not re.search(r"warning: " + re.escape(module.replace(".","/")), raw)

output = {"modules":len(modules), "requested_modules": MODULES, "protected_files":len(protected),
          "modified_existing": sorted(changed), "conditions": len(conditions), "classification":counts,
          "public_entries": len(public), "named_readers":sum(bool(r["named_readers"]) for r in public),
          "compiled_examples":sum(r["compiled_example"] for r in public), "files":len(files),
          "record_bytes":sum(f.stat().st_size for f in files), "largest_bytes":max(f.stat().st_size for f in files),
          "axiom_targets":summary["targets"], "added_declarations":summary["added_declarations"],
          "pending":0, "not_proved":0}
write(HERE / "verification.json", output)
print(json.dumps(output,ensure_ascii=False))
