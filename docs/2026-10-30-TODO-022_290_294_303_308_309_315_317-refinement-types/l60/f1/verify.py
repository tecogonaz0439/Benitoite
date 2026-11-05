# -*- coding: utf-8 -*-
"""群F1の変更範囲・既定import・監査・読者・行の件数・台帳の差分と保存記録を照合する。

使い方: python3 verify.py --tmp <一時領域> --baseline <開始時の全ファイルのハッシュ>"""
import argparse
import ast
import collections
import hashlib
import json
import os
from pathlib import Path
import platform
import re
from support import CHANGE, CHANGED, EDITED, HERE, MODULES, PREFIX, ROOT, closure, digest, module_path, write
import design_copies

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--baseline", type=Path, required=True)
args = parser.parse_args()


def read(file):
    return json.loads((HERE / file).read_text())


# 1. 開始時の全ファイルのハッシュと比べ、変更の範囲を限る。
baseline = json.loads(args.baseline.read_text())
own_dir = str(HERE.relative_to(ROOT))
new_lean = {str(module_path(m).relative_to(ROOT)) for m in MODULES}
edited_lean = {str(module_path(m).relative_to(ROOT)) for m in EDITED}
current = {}
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "target", "__pycache__")]
    for name in filenames:
        path = Path(dirpath) / name
        # worktreeの根の .git はファイルであり、開始時の一覧にも含めていない。
        if not path.is_symlink() and not (name == ".git" and Path(dirpath) == ROOT):
            current[str(path.relative_to(ROOT))] = path
assert set(baseline) <= set(current), set(baseline) - set(current)
added = sorted(set(current) - set(baseline))
review = str((CHANGE / "reviews/RV-L60.f1.md").relative_to(ROOT))
assert all(p.startswith(own_dir + "/") or p in new_lean or p == review for p in added), added
assert new_lean <= set(added)
changed = sorted(rel for rel, old in baseline.items()
                 if hashlib.sha256(current[rel].read_bytes()).hexdigest() != old)
# 再開1（RV-L60.f1 の情報1）で群Eの二つの記録を追随させた。資源の記録は消した名前の置き換えだけ、
# 結果の記録は末尾の一行の追加だけであることを、開始時のハッシュへ戻して確かめる。
group_e = {str((CHANGE / "l60/e/resources.json").relative_to(ROOT)), str((CHANGE / "l60/e/results.md").relative_to(ROOT))}
assert set(changed) == set(CHANGED) | edited_lean | group_e, changed
resources_rel, results_rel = sorted(group_e)
text = (ROOT / resources_rel).read_text()
assert "no_store_transitions" not in text
assert hashlib.sha256(text.replace("StandardModel.store_transitions", "StandardModel.no_store_transitions")
                      .encode()).hexdigest() == baseline[resources_rel]
line = "\n群 F1 で `no_store_transitions` を `store_transitions` へ置き換えた（参照と明示遅延の三行を合成表へ加えたため）。\n"
text = (ROOT / results_rel).read_text()
assert text.endswith(line)
assert hashlib.sha256(text[:-len(line)].encode()).hexdigest() == baseline[results_rel]
# 既定importへは新しいモジュールの行だけを足す。
text = (ROOT / CHANGED[0]).read_text()
for module in MODULES:
    assert text.count("import " + module + "\n") == 1, module
    text = text.replace("import " + module + "\n", "")
assert hashlib.sha256(text.encode()).hexdigest() == baseline[CHANGED[0]]
# 写しは置換の組の箇所だけを変え、組を戻すと開始時の内容に一致する。
for rel in CHANGED[1:]:
    text = (ROOT / rel).read_text()
    for path, old, new in reversed(design_copies.PAIRS):
        if path == rel:
            assert text.count(new) == 1, (rel, new[:40])
            text = text.replace(new, old)
    assert hashlib.sha256(text.encode()).hexdigest() == baseline[rel], (rel, "置換の組以外に差分")

# 2. 既定importと監査の範囲・公理。
modules = closure()
requested = read("requested-modules.json")
assert set(MODULES) <= set(modules) and set(MODULES) <= set(requested)
summary = read("audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
assert set(summary["new_modules"]) == set(requested)
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "none"}
           for k in summary["axiom_sets"])
assert digest(args.tmp / "axioms.log") == summary["raw"]
assert digest(args.tmp / "targets.txt") == summary["target_list"]
targets = set((args.tmp / "targets.txt").read_text().split())
rows = []
for part in summary["parts"]:
    assert digest(HERE / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
    rows.extend(read(part["file"]))
assert len(rows) == len({r["name"] for r in rows}) == summary["declarations"]
for row in rows:
    if row["type"] is not None:
        assert hashlib.sha256(row["type"].encode()).hexdigest() == row["type_sha256"]
        assert "⋯" not in row["type"] and "..." not in row["type"]
by_name = {r["name"]: r for r in rows}
# 群Eの記録から結論の変わった宣言と取り除いた宣言は、合成表へ加えた三行に伴うものに限る。
assert sorted(summary["inherited_type_changed"]) == sorted(
    PREFIX + "StandardModel." + n for n in ["Primitive.store_rows", "store_lookup", "reference_rows"])
assert summary["inherited_removed"] == [PREFIX + "StandardModel.no_store_transitions"]
# 既存のモジュールに足した宣言が監査の対象にある。
for name in ["StandardModel.refNewSig", "StandardModel.refUpdateSig", "StandardModel.forceSig",
             "StandardModel.Primitive.p374", "StandardModel.Primitive.p375", "StandardModel.Primitive.p376",
             "StandardModel.roundingMode", "StandardDecimalResponse.Declarations",
             "StandardDecimalResponse.program_declarations", "StandardDecimalResponse.response_of"]:
    assert PREFIX + name in targets, name

# 3. 新しいモジュールの公開した名前の読者（名前付きの宣言の依存、又は既定ビルドの適用例の本文）。
incoming = collections.defaultdict(set)
for row in rows:
    for dep in row["dependencies"]:
        if dep != row["name"]:
            incoming[dep].add(row["name"])
examples = ""
public = []
for module in MODULES:
    source = module_path(module).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|#reduce|set_option|L[0-9]{2}|R[0-9]{2}\b", source), module
    for block in re.findall(r"^example[\s\S]*?(?=^(?:/--|theorem|def|private|example|end)\b)", source, re.M):
        examples += block
    for short in re.findall(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", source, re.M):
        full = PREFIX + "StandardModel." + short
        assert full in by_name, full
        readers = sorted(r for r in incoming[full] if not r.startswith(full + "."))
        direct = re.search(r"(?<![\w.])" + re.escape(short.split(".")[-1]) + r"(?![\w])", examples) is not None
        assert readers or direct, full
        public.append({"name": full, "named_readers": readers[:5], "named_reader_count": len(readers),
                       "compiled_example": direct})
write(HERE / "readers.json", public)

# 4. 行の件数：演算子109（107と構造の等号2）、数値166、最初の十六行、証人の形。
import subprocess
import sys
rows_json = json.loads(subprocess.run([sys.executable, str(HERE / "rows.py"), "--json"], capture_output=True,
                                      text=True, check=True).stdout)
assert rows_json["summary"]["operator"] == 109 and rows_json["summary"]["numeric"] == 166
assert rows_json["summary"]["rows"] == 376
assert sum(r["first_sixteen"] for r in rows_json["rows"]) == 16
families = rows_json["summary"]["families"]
assert families["operator"] == {"order": 48, "operator": 34, "arithmetic": 25, "structural": 2}
inputs = read("inputs.json")
assert inputs["rows"] == 275 and sum(inputs["shapes"].values()) == 275
operator_source = module_path("Benitoite.Release.Refinement.StandardModelOperatorRows").read_text()
numeric_source = module_path("Benitoite.Release.Refinement.StandardModelNumericRows").read_text()
inputs_source = module_path("Benitoite.Release.Refinement.StandardModelPureInputs").read_text()
operator_rows = {r["row"] for r in rows_json["rows"] if r["kind"] == "operator"}
numeric_rows = {r["row"] for r in rows_json["rows"] if r["kind"] == "numeric"}
assert set(re.findall(r"^  case (p\d{3}) =>", operator_source.split("theorem operator_rows", 1)[1], re.M)) == operator_rows
assert set(re.findall(r"^  case (p\d{3}) =>", numeric_source.split("theorem numeric_rows", 1)[1], re.M)) == numeric_rows
assert set(re.findall(r"^  case (p\d{3}) =>", inputs_source.split("theorem operator_inputs", 1)[1].split(
    "theorem numeric_inputs", 1)[0], re.M)) == operator_rows
assert set(re.findall(r"^  case (p\d{3}) =>", inputs_source.split("theorem numeric_inputs", 1)[1], re.M)) == numeric_rows
first = [r["row"] for r in rows_json["rows"] if r["first_sixteen"]]
assert all("case %s => exact first_sixteen" % p in operator_source for p in first)
pure_source = module_path("Benitoite.Release.Refinement.StandardModelPureRows").read_text()
# 部分表の table_response を合成表の証拠に使わない。
assert not re.search(r"\w\.table_response\b", operator_source + numeric_source + inputs_source + pure_source)
ledger = read("ledger-diff.json")
assert ledger["summary"]["connected_rows"] == 275
assert ledger["summary"]["connected_by_unit"] == {"L60.23": 16, "L60.24": 166, "L60.25": 93}
assert ledger["summary"]["moved_to_composition"] == 3 and ledger["summary"]["assumption_reason_corrected"] == 1
store = read("store-signatures.json")
assert len(store["rows"]) == 3 and all(all(r["checks"].values()) for r in store["rows"])
names = set()
for row in ledger["moved"]:
    names.update(row["evidence"])
names.update(PREFIX + r["family"] for r in ledger["connected"])
for row in ledger["connected"]:
    names.update(PREFIX + c for c in row["cover"].split("・"))
missing = sorted(n for n in names if n not in targets)
assert not missing, missing

# 5. 記録の大きさ、手元の絶対パス、docs/todoへのリンク、相対リンク。
for f in HERE.glob("*.py"):
    ast.parse(f.read_text())
files = [f for f in HERE.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
assert all(f.stat().st_size <= 100000 for f in files)
assert sum(f.stat().st_size for f in files) < 3000000
for f in files:
    text = f.read_text()
    assert "/" + "Users" + "/" not in text and "/private/" + "tmp" not in text, f.name
    assert not re.search(r"\]\([^)]*docs/todo", text), f.name
    if f.suffix == ".md":
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if not re.match(r"https?://|#", target):
                assert (f.parent / target.split("#")[0]).exists(), (f.name, target)

# 6. 既定ビルドと監査の記録。
for name in ["default-build", "axioms"]:
    record = read(name + ".json")
    assert record["exit"] == 0 and record["raw"] == digest(args.tmp / (name + ".log"))
raw = (args.tmp / "default-build.log").read_text()
assert "Build completed successfully" in raw
for module in MODULES + EDITED:
    assert not re.search(r"warning: " + re.escape(module.replace(".", "/")) + r"\.lean", raw), module

previous_tools = read("../e/tools.json")
inputs_digest = {rel: digest(ROOT / rel) for rel in
                 ["formal/lean-toolchain", "formal/lakefile.toml", "formal/lake-manifest.json"] + CHANGED +
                 sorted(new_lean) + sorted(edited_lean) +
                 sorted(str(f.relative_to(ROOT)) for f in HERE.glob("*.py")) +
                 [str((HERE / "axioms.lean").relative_to(ROOT))]}
assert inputs_digest["formal/lean-toolchain"] == previous_tools["inputs"]["formal/lean-toolchain"]
write(HERE / "tools.json", {"platform": {"system": platform.system(), "machine": platform.machine(),
                                         "release": platform.release()},
                            "lean": previous_tools["lean"], "memory_mib": 12288,
                            "configuration": "既定ターゲット・既定import・固定Lean。単独Leanも-M 12288。RSSは計画上の非採取",
                            "baseline": {"files": len(baseline), **digest(args.baseline)},
                            "inputs": inputs_digest})
output = {"modules": len(modules), "new_modules": MODULES, "edited_modules": EDITED,
          "baseline_files": len(baseline), "added_files": len(added), "modified_existing": changed,
          "declarations": len(rows), "public_entries": len(public),
          "named_readers": sum(bool(r["named_readers"]) for r in public),
          "compiled_examples": sum(r["compiled_example"] for r in public),
          "rows": rows_json["summary"], "inputs": inputs["shapes"], "ledger": ledger["summary"],
          "evidence_names": len(names), "axiom_targets": summary["targets"], "files": len(files),
          "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files)}
write(HERE / "verification.json", output)
print(json.dumps(output, ensure_ascii=False))
