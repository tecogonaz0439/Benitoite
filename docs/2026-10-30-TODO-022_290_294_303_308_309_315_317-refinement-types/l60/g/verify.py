# -*- coding: utf-8 -*-
"""群Gの変更範囲・既定import・監査・読者・入力の定理の場合の網羅・四分類・義務と受け口・境界・記録を照合する。

開始版 B_WORK との比較は、読み取りだけのgitの照会（ls-tree・show・diff・check-ignore）で行う。
使い方: python3 verify.py --tmp <一時領域>（default-build.log・axioms.log・targets.txt・graph.log を置く）"""
import argparse
import ast
import collections
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
from support import (B_WORK, CHANGED, EDITED, HERE, MODULES, PREFIX, ROOT, base_files, base_text, closure,
                     digest, module_path, write)
import design_copies

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()


def read(file):
    return json.loads((HERE / file).read_text())


# 1. 開始版と比べ、変更の範囲を限る。
base = base_files()
own_dir = str(HERE.relative_to(ROOT))
new_lean = {str(module_path(m).relative_to(ROOT)) for m in MODULES}
current = set()
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "target", "__pycache__")]
    for name in filenames:
        path = Path(dirpath) / name
        if not path.is_symlink() and not (name == ".git" and Path(dirpath) == ROOT):
            current.add(str(path.relative_to(ROOT)))
assert not sorted(p for p in base if p not in current and not (ROOT / p).is_symlink())
ignored = subprocess.run(["git", "-C", str(ROOT), "check-ignore", "--stdin"], input="\n".join(sorted(current - base)),
                         capture_output=True, text=True).stdout.split()
added = sorted(current - base - set(ignored))
# 取りまとめが置いた群Gの独立レビューの記録は、担当の変更に数えない。
review = str((HERE.parents[1] / "reviews/RV-L60.g.md").relative_to(ROOT))
assert all(p.startswith(own_dir + "/") or p in new_lean or p == review for p in added), \
    [p for p in added if not (p.startswith(own_dir + "/") or p in new_lean or p == review)]
assert new_lean <= set(added)
diff = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", "-z", B_WORK, "--"], capture_output=True,
                      text=True, check=True).stdout
changed = sorted(set(diff.split("\0")) - {""})
# L50の段末の記録には、末尾に訂正の注記の節を一つだけ足す（設計者の決定）。表の行は変えない。
stage = str((HERE.parents[1] / "l50/stage-results.md").relative_to(ROOT))
assert set(changed) == set(CHANGED) | {stage}, changed
stage_now, stage_base = (ROOT / stage).read_text(), base_text(stage).decode()
assert stage_now.startswith(stage_base)
note = stage_now[len(stage_base):]
assert note.startswith("\n## 訂正の注記（2026-11-05）\n") and note.count("\n## ") == 1, note[:80]
text = (ROOT / CHANGED[0]).read_text()
for module in MODULES:
    assert text.count("import " + module + "\n") == 1, module
    text = text.replace("import " + module + "\n", "")
assert text.encode() == base_text(CHANGED[0])
for rel in CHANGED[1:]:
    text = (ROOT / rel).read_text()
    for path, old, new in reversed(design_copies.PAIRS):
        if path == rel:
            assert text.count(new) == 1, (rel, new[:40])
            text = text.replace(new, old)
    assert text.encode() == base_text(rel), (rel, "置換の組以外に差分")

# 2. 既定importと監査の範囲・公理。
modules = closure()
requested = read("requested-modules.json")
assert set(MODULES) <= set(modules) and MODULES == requested
summary = read("audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
assert set(summary["new_modules"]) == set(requested)
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "none"} for k in summary["axiom_sets"])
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
by_name = {r["name"]: r for r in rows}
assert not [n for n in read("required-names.json") if n not in targets]

# 3. 公開した名前の読者（名前付きの宣言の依存、又は既定ビルドの適用例の本文）。
incoming = collections.defaultdict(set)
for row in rows:
    for dep in row["dependencies"] or []:
        if dep != row["name"]:
            incoming[dep].add(row["name"])
public, unread = [], []
examples = "".join("".join(re.findall(r"^example[\s\S]*?(?=^(?:/--|theorem|def|private|example|end|set_option)\b)",
                                      module_path(module).read_text(), re.M)) for module in MODULES)
for module in MODULES:
    source = module_path(module).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|#reduce|maxHeartbeats|maxRecDepth|L[0-9]{2}\.|R[0-9]{2}\b",
                         source), module
    stack = []
    for line in source.split("\n"):
        m = re.match(r"^namespace ([\w.]+)$", line)
        if m:
            stack.append(m[1])
            continue
        if re.match(r"^end [\w.]+$", line):
            stack.pop()
            continue
        m = re.match(r"^(?:theorem|structure|def|inductive) ([A-Za-z][\w.]*)", line)
        if not m:
            continue
        full = stack[-1] + "." + m[1]
        assert full in by_name, full
        readers = sorted(r for r in incoming[full] if not r.startswith(full + "."))
        direct = re.search(r"(?<![\w.])" + re.escape(m[1].split(".")[-1]) + r"(?![\w])", examples) is not None
        if not (readers or direct):
            unread.append(full)
        public.append({"name": full, "named_readers": readers[:5], "named_reader_count": len(readers),
                       "compiled_example": direct})
assert not unread, unread
write(HERE / "readers.json", public)

# 4. 入力の定理の場合の網羅、四分類・義務・受け口・境界の記録の再現。
lean = {m.split(".")[-1]: module_path(m).read_text() for m in MODULES}
collection = re.findall(r"^  case (p\d{3}) =>", lean["StandardModelCollectionInputs"].split("theorem collection_inputs", 1)[1], re.M)
f2_rows = module_path(PREFIX + "StandardModelCollectionRows").read_text()
assert collection == re.findall(r"^  case (p\d{3}) =>", f2_rows.split("theorem collection_rows", 1)[1], re.M)
io = lean["StandardModelIOInputs"]
assert len(re.findall(r"^  case (p\d{3}) =>", io.split("theorem scope_inputs", 1)[1].split("theorem io_inputs", 1)[0], re.M)) == 7
assert len(re.findall(r"^  case (p\d{3}) =>", io.split("theorem io_inputs", 1)[1], re.M)) == 10
graph = args.tmp / "graph.log"
subprocess.run([sys.executable, str(HERE / "function_values.py"), "--verify"], check=True, capture_output=True)
for script in ["records.py", "conditions.py", "boundary.py"]:
    command = [sys.executable, str(HERE / script), "--log", str(graph), "--verify"]
    if script == "records.py":
        command[2:2] = ["--tmp", str(args.tmp)]
    subprocess.run(command, check=True, capture_output=True)
conditions = read("conditions.json")
assert conditions["summary"]["composite29"] == {"実質": 24, "自明": 5}
assert conditions["summary"]["models87"]["合計87"] == {"実質": 64, "自明": 15, "空疎": 8}
assert conditions["summary"]["rows96"] == {"実質": 96}
obligations = read("obligations.json")
handoffs = read("handoffs.json")
assert obligations["source"]["sha256"] == handoffs["source"]["sha256"] == digest(graph)["sha256"]
o144 = [r for r in obligations["rows"] if r["id"] == "O144"]
assert len(o144) == 1 and o144[0]["judgment"].startswith("他段") and not o144[0]["evidence"]

# 5. 記録の大きさ、手元の絶対パス、docs/todoへのリンク、相対リンク。
for f in HERE.glob("*.py"):
    ast.parse(f.read_text())
files = [f for f in HERE.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
assert all(f.stat().st_size <= 100000 for f in files), [f.name for f in files if f.stat().st_size > 100000]
assert sum(f.stat().st_size for f in files) < 4000000
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

previous_tools = read("../f2/tools.json")
inputs_digest = {rel: digest(ROOT / rel) for rel in
                 ["formal/lean-toolchain", "formal/lakefile.toml", "formal/lake-manifest.json"] + CHANGED +
                 sorted(new_lean) + sorted(str(f.relative_to(ROOT)) for f in HERE.glob("*.py")) +
                 [str((HERE / f).relative_to(ROOT)) for f in ["axioms.lean", "graph.lean"]]}
assert inputs_digest["formal/lean-toolchain"] == previous_tools["inputs"]["formal/lean-toolchain"]
write(HERE / "tools.json", {"platform": {"system": platform.system(), "machine": platform.machine(),
                                         "release": platform.release()},
                            "lean": previous_tools["lean"], "memory_mib": 12288,
                            "configuration": "既定ターゲット・既定import・固定Lean。単独Leanも-M 12288。RSSは計画上の非採取",
                            "base": B_WORK, "inputs": inputs_digest, "graph": digest(graph)})
output = {"modules": len(modules), "new_modules": MODULES, "added_files": len(added), "modified_existing": changed, "models87": conditions["summary"]["models87"],
          "declarations": len(rows), "public_entries": len(public),
          "named_readers": sum(bool(r["named_readers"]) for r in public),
          "compiled_examples": sum(r["compiled_example"] for r in public),
          "collection_inputs": len(collection), "scope_inputs": 7, "io_inputs": 10,
          "conditions": conditions["summary"]["composite29"], "rows": conditions["summary"]["rows96"],
          "obligations": len(obligations["rows"]), "handoffs": len(handoffs["rows"]),
          "axiom_targets": summary["targets"], "files": len(files),
          "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files)}
write(HERE / "verification.json", output)
print(json.dumps(output, ensure_ascii=False)[:3000])
