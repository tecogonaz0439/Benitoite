# -*- coding: utf-8 -*-
"""群Eの変更範囲・既定import・監査・読者・八遷移・87欄・台帳と保存記録を照合する。"""
import argparse
import ast
import collections
import hashlib
import json
import os
from pathlib import Path
import platform
import re
from support import CHANGE, CHANGED, HERE, MODULES, PREFIX, ROOT, closure, digest, module_path, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--baseline", type=Path, required=True)
args = parser.parse_args()


def read(file):
    return json.loads((HERE / file).read_text())


# 1. 開始時の全ファイルのハッシュ（一時領域）と比べ、変更の範囲を限る。
baseline = json.loads(args.baseline.read_text())
own_dir = str(HERE.relative_to(ROOT))
new_lean = {str(module_path(m).relative_to(ROOT)) for m in MODULES}
current = {}
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "target", "__pycache__")]
    for name in filenames:
        path = Path(dirpath) / name
        if not path.is_symlink():
            current[str(path.relative_to(ROOT))] = path
assert set(baseline) <= set(current), set(baseline) - set(current)
added = sorted(set(current) - set(baseline))
# 独立レビューの記録は取りまとめが加えるので、変更の範囲から除く。
review = str((CHANGE / "reviews/RV-L60.e.md").relative_to(ROOT))
assert all(p.startswith(own_dir + "/") or p in new_lean or p == review for p in added), added
assert new_lean <= set(added)
inserted = {
    "formal/Benitoite.lean": ["import " + m + "\n" for m in MODULES],
}
spec_text = (ROOT / CHANGED[1]).read_text()
start = spec_text.index("\n`ResourceRelease.Table B` は、")
end = spec_text.index("ModelとHttpの解放の条件の前提の否定を示す。\n", start) + len("ModelとHttpの解放の条件の前提の否定を示す。\n")
inserted[CHANGED[1]] = [spec_text[start:end]]
quality_text = (ROOT / CHANGED[2]).read_text()
start = quality_text.index("\n`ResourceReleaseLeaves` は、")
end = quality_text.index("新しい条件の前提を満たす入力を読む。\n", start) + len("新しい条件の前提を満たす入力を読む。\n")
inserted[CHANGED[2]] = [quality_text[start:end]] + [
    line + "\n" for line in quality_text.split("\n")
    if line.startswith("| ResourceReleaseLeaves |") or line.startswith("| ExternalModelComposition |")]
changed = []
for rel, old in baseline.items():
    data = current[rel].read_bytes()
    if hashlib.sha256(data).hexdigest() == old:
        continue
    assert rel in inserted, rel
    text = data.decode()
    for piece in inserted[rel]:
        assert text.count(piece) == 1, (rel, piece[:40])
        text = text.replace(piece, "")
    assert hashlib.sha256(text.encode()).hexdigest() == old, (rel, "追加箇所以外に差分")
    changed.append(rel)
assert sorted(changed) == sorted(CHANGED), changed

# 2. 既定importと監査の範囲。
modules = closure()
assert set(MODULES) <= set(modules)
summary = read("audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
assert set(summary["new_modules"]) == set(MODULES)
assert digest(args.tmp / "axioms.log") == summary["raw"]
targets = set((args.tmp / "targets.txt").read_text().split())
assert digest(args.tmp / "targets.txt") == summary["target_list"]
rows = []
for part in summary["parts"]:
    assert digest(HERE / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
    rows.extend(read(part["file"]))
assert len(rows) == len({r["name"] for r in rows}) == summary["declarations"]
for row in rows:
    assert hashlib.sha256(row["type"].encode()).hexdigest() == row["type_sha256"]
    assert "⋯" not in row["type"] and "..." not in row["type"]
by_name = {r["name"]: r for r in rows}
assert {r["name"] for r in read("added-declarations.json")} == set(by_name)

# 3. 公開した名前の読者（名前付きの宣言の型・値の依存、又は既定ビルドの適用例）。
incoming = collections.defaultdict(set)
for row in rows:
    for dep in row["dependencies"]:
        if dep != row["name"]:
            incoming[dep].add(row["name"])
public = []
# 適用例の本文は、example から次のトップレベルの宣言・docstring・名前空間の区切りの前までとする。
# 各適用例は、その位置で開いている名前空間の列とともに保存する。
examples = []
for module in MODULES:
    stack, current = [], None
    for line in module_path(module).read_text().split("\n"):
        opened = re.match(r"^namespace ([\w.]+)$", line)
        if line.startswith("example"):
            current = {"space": ".".join(stack), "text": ""}
            examples.append(current)
        elif re.match(r"^(?:/--|private |theorem |def |structure |namespace |end\b)", line):
            current = None
        if opened:
            stack.append(opened[1])
        elif re.match(r"^end [\w.]+$", line) and stack:
            stack.pop()
        if current is not None:
            current["text"] += line + "\n"

# ドット記法の受け手。変数はその適用例の束縛の型の名前空間、括弧は `(… resource_table P)` の型。
RECEIVERS = {"m": "ExternalModels.ModelCase", "run": "StateTyE", "error": "StateTyE", "exit": "StateTyE",
             "h": "StateTyE", "frames": "ContTy", "standard": "ContTy"}
BINDERS = {"ExternalModels.ModelCase": ["ModelCase", "ExternalModels.ModelCase"], "StateTyE": ["StateTyE"],
           "ContTy": ["ContTy"]}


def resolved(example):
    """適用例の中の名前の出現を、名前空間・修飾・受け手の型から完全名へ解決する。"""
    names = set()
    spaces = [example["space"][:i].rstrip(".") for i in range(len(example["space"]) + 1)
              if i == len(example["space"]) or example["space"][i] == "."]
    for match in re.finditer(r"(?<![\w.])((?:[\w]+\.)*)([A-Za-z_][\w]*)(?![\w])|\)\.([a-z_][\w]*)",
                             example["text"]):
        if match.group(3):
            # 括弧の受け手で解決するのは `(… resource_table P)`（ResourceRelease.Table）だけとし、
            # 型を決めない他の括弧の受け手は数えない。
            before = example["text"][:match.start() + 1]
            if re.search(r"resource_table(?: \.\w+)? P\)$", before):
                names.add(PREFIX + "ResourceRelease.Table." + match.group(3))
            continue
        qualifier, tail = match.group(1).rstrip("."), match.group(2)
        head = qualifier.split(".")[0] if qualifier else ""
        if head in RECEIVERS:
            space = RECEIVERS[head]
            assert any(re.search(r"(?:\(|∀ )" + head + r"(?: \w+)* : " + re.escape(b) + r"\b", example["text"])
                       for b in BINDERS[space]), (head, example["text"][:80])
            names.add(PREFIX + space + "." + ".".join(qualifier.split(".")[1:] + [tail]))
            continue
        written = (qualifier + "." if qualifier else "") + tail
        for space in spaces:
            full = (space + "." if space else "") + written
            names.add(full if full.startswith("Benitoite.") else PREFIX + full)
    return names


applied = set()
for example in examples:
    applied |= resolved(example)
for module in MODULES:
    text = module_path(module).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|set_option|L60\.|L70|R50", text), module
    stack, scopes = [], []
    for line in text.split("\n"):
        opened = re.match(r"^namespace ([\w.]+)$", line)
        if opened:
            stack.append(opened[1])
        elif re.match(r"^end [\w.]+$", line) and stack:
            stack.pop()
        declared = re.match(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", line)
        if declared:
            space = ".".join(stack)
            full = (space + "." if space else "") + declared[1]
            if not full.startswith("Benitoite."):
                full = PREFIX + full
            scopes.append((declared[1], full))
    for short, full in scopes:
        assert full in by_name, full
        direct = full in applied
        readers = sorted(r for r in incoming[full] if not r.startswith(full + "."))
        assert readers or direct, full
        public.append({"name": full, "named_readers": readers, "compiled_example": direct})
write(HERE / "readers.json", public)

# 4. 八つの解放の遷移と、それを使う既存の葉・選択への接続。
semantics = (ROOT / "formal/Benitoite/Release/Refinement/Semantics.lean").read_text()
blocks = re.split(r"^  \| ", semantics.split("inductive Step ", 1)[1].split("\ninductive Steps", 1)[0], flags=re.M)[1:]
constructors = [b.split()[0] for b in blocks if "releaseResponse" in b]
drops = [b.split()[0] for b in blocks if "releases k'" in b]
leaf = {"E_Release": "return_release", "E_RelErr": "return_release_failure",
        "E_EscRel": "escape_release", "E_EscRelErr": "escape_release_failure",
        "E_ErrRel": "error_release", "E_ErrRelErr": "error_release_failure",
        "E_ExitRel": "exit_release", "E_ExitRelErr": "exit_release_failure"}
assert sorted(constructors) == sorted(leaf), constructors
handler = (ROOT / "formal/Benitoite/Release/Refinement/HandlerGeneral.lean").read_text()
for constructor, name in leaf.items():
    body = handler.split("theorem StateTyE." + name + " ", 1)[1].split("\ntheorem ", 1)[0]
    assert "." + constructor + " " in body, (constructor, name)
used = set()
for row in rows:
    used.update(row["dependencies"])
for name in leaf.values():
    assert PREFIX + "StateTyE." + name in used, name
for name in ["step_release_selected", "Builtins.selectRelease_response", "StateTyE.use_all",
             "ResourceRelease.canonical", "ResourceRelease.typed_response", "ExternalModels.model_core",
             "ExternalModels.targets_core", "ExternalModels.http_core", "ExternalModels.conditions",
             "ExternalModels.shape_inputs", "ExternalModels.model_no_response_kind",
             "ExternalModel.response_err", "StandardModel.builtins_lookup_iff", "ModelTargets.store_shape",
             "PrimSig.StoreShape.sourceTelRows"]:
    assert PREFIX + name in used, name
selections = {"StateTyE.release_selected_run": ["ret", "escape"], "StateTyE.release_selected_error": ["error"],
              "StateTyE.release_selected_exit": ["exit"]}
for name in selections:
    assert PREFIX + name in by_name

# 5. 87欄と台帳。Leanの証拠名は監査の全宣言に実在する。
conditions = read("conditions.json")
assert conditions["counts"] == {"既存75": {"実質": 69, "空疎": 6}, "新12": {"実質": 7, "自明": 3, "空疎": 2},
                                "合計87": {"実質": 76, "空疎": 8, "自明": 3}}
assert len(conditions["rows"]) == 87 and conditions["pending"] == 0
resources = read("resources.json")
assert resources["summary"]["rows"] == len(resources["rows"]) == 12
references = read("reference-signatures.json")
assert references["summary"]["checked"] == len(references["rows"]) == 5
assert all(all(r["checks"].values()) for r in references["rows"])
assert sorted(references["summary"]["remaining_to_23_29"]) == ["Lazy.force", "Reference.new", "Reference.update"]
names = set()
for row in conditions["rows"]:
    for key in ["premise_negation", "conclusion_trivial", "satisfiable_input", "reader"]:
        names.update(re.findall(r"Benitoite\.Release\.Refinement\.[\w.]+", row[key]))
for row in resources["rows"]:
    names.update(row["evidence"])
names = {n.rstrip(".") for n in names}
missing = sorted(n for n in names if n not in targets)
assert not missing, missing

# 6. 記録の大きさ、手元の絶対パス、docs/todoへのリンク、相対リンク。
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

# 7. 既定ビルドと監査の記録。
for name in ["default-build", "axioms"]:
    record = read(name + ".json")
    assert record["exit"] == 0 and record["raw"] == digest(args.tmp / (name + ".log"))
raw = (args.tmp / "default-build.log").read_text()
assert "Build completed successfully" in raw
for module in MODULES:
    assert not re.search(r"warning: " + re.escape(module.replace(".", "/")), raw)

# Leanの版は前回の記録から引き継ぐ（Lean・lakeを実行しない。toolchainのハッシュは下で照合する）。
previous_tools = read("tools.json")
assert digest(ROOT / "formal/lean-toolchain") == previous_tools["inputs"]["formal/lean-toolchain"]
inputs = {rel: digest(ROOT / rel) for rel in
          ["formal/lean-toolchain", "formal/lakefile.toml", "formal/lake-manifest.json"] + CHANGED +
          sorted(new_lean) + sorted(str(f.relative_to(ROOT)) for f in HERE.glob("*.py")) +
          [str((HERE / "axioms.lean").relative_to(ROOT))]}
write(HERE / "tools.json", {"platform": {"system": platform.system(), "machine": platform.machine(),
                                         "release": platform.release()},
                            "lean": previous_tools["lean"], "memory_mib": 12288,
                            "configuration": "既定ターゲット・既定import・固定Lean。単独Leanも-M 12288。RSSは計画上の非採取",
                            "baseline": {"files": len(baseline), **digest(args.baseline)},
                            "inputs": inputs})
output = {"modules": len(modules), "requested_modules": MODULES, "baseline_files": len(baseline),
          "added_files": len(added), "modified_existing": sorted(changed),
          "declarations": len(rows), "public_entries": len(public),
          "named_readers": sum(bool(r["named_readers"]) for r in public),
          "compiled_examples": sum(r["compiled_example"] for r in public),
          "release_constructors": len(constructors), "drop_release_constructors": sorted(drops), "conditions": conditions["counts"],
          "resources": resources["summary"], "reference_signatures": references["summary"], "evidence_names": len(names),
          "axiom_targets": summary["targets"], "files": len(files),
          "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files)}
write(HERE / "verification.json", output)
print(json.dumps(output, ensure_ascii=False))
