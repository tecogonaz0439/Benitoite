# -*- coding: utf-8 -*-
"""群F2の変更範囲・既定import・監査・読者・行と本体の件数・台帳の差分・四照合と保存記録を照合する。

開始版 B_WORK との比較は、読み取りだけのgitの照会（ls-tree・show）で行う。
使い方: python3 verify.py --tmp <一時領域>"""
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
edited_lean = {str(module_path(m).relative_to(ROOT)) for m in EDITED}
current = set()
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "target", "__pycache__")]
    for name in filenames:
        path = Path(dirpath) / name
        if not path.is_symlink() and not (name == ".git" and Path(dirpath) == ROOT):
            current.add(str(path.relative_to(ROOT)))
tracked_missing = sorted(p for p in base if p not in current and not (ROOT / p).is_symlink())
assert not tracked_missing, tracked_missing[:5]
ignored = subprocess.run(["git", "-C", str(ROOT), "check-ignore", "--stdin"], input="\n".join(sorted(current - base)),
                         capture_output=True, text=True).stdout.split()
added = sorted(current - base - set(ignored))
# 取りまとめが置いた群F2の独立レビューの記録は、担当の変更に数えない。
review = str((HERE.parents[1] / "reviews/RV-L60.f2.md").relative_to(ROOT))
assert all(p.startswith(own_dir + "/") or p in new_lean or p == review for p in added), \
    [p for p in added if not (p.startswith(own_dir + "/") or p in new_lean or p == review)]
assert new_lean <= set(added)
diff = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", "-z", B_WORK, "--"], capture_output=True,
                      text=True, check=True).stdout
changed = sorted(set(diff.split("\0")) - {""})
assert all(p in base for p in changed)
assert set(changed) == set(CHANGED) | edited_lean, changed
# 既定importへは新しいモジュールの行だけを足す。
text = (ROOT / CHANGED[0]).read_text()
for module in MODULES:
    assert text.count("import " + module + "\n") == 1, module
    text = text.replace("import " + module + "\n", "")
assert text.encode() == base_text(CHANGED[0])
# 写しは置換の組の箇所だけを変え、組を戻すと開始版の内容に一致する。
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
assert set(MODULES) <= set(modules) and set(MODULES) == set(requested)
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
required = read("required-names.json")
assert not [n for n in required if n not in targets]

# 3. 新しいモジュールの公開した名前の読者（名前付きの宣言の依存、又は既定ビルドの適用例の本文）。
incoming = collections.defaultdict(set)
for row in rows:
    for dep in row["dependencies"] or []:
        if dep != row["name"]:
            incoming[dep].add(row["name"])
public, unread = [], []
for module in MODULES:
    source = module_path(module).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|#reduce|L[0-9]{2}\.|R[0-9]{2}\b", source), module
    examples = "".join(re.findall(r"^example[\s\S]*?(?=^(?:/--|theorem|def|private|example|end|set_option)\b)",
                                  source, re.M))
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

# 4. 行と本体の件数、振り分けの網羅、台帳の差分、四照合、条件の記録。
lean = {m.split(".")[-1]: module_path(m).read_text() for m in MODULES}
program = lean["StandardModelProgram"]
wellformed = lean["StandardModelWellFormed"]
bodies = ["b%03d" % i for i in range(1, 131)]
assert re.findall(r"^  case (b\d{3}) =>", program.split("theorem body_typed", 1)[1].split("theorem definition_typed", 1)[0], re.M) == bodies
assert re.findall(r"^  case (b\d{3}) =>", wellformed.split("theorem body_scoped", 1)[1].split("theorem field_rows", 1)[0], re.M) == bodies
collection_cases = re.findall(r"^  case (p\d{3}) =>", lean["StandardModelCollectionRows"].split("theorem collection_rows", 1)[1], re.M)
assert len(collection_cases) == len(set(collection_cases)) == 79
io_text = lean["StandardModelIORows"]
assert len(re.findall(r"^  case (p\d{3}) =>", io_text.split("theorem io_rows", 1)[1].split("theorem PureRow.scope", 1)[0], re.M)) == 10
assert len(re.findall(r"^  case (p\d{3}) =>", io_text.split("theorem scope_rows", 1)[1], re.M)) == 7
# 部分表の table_response を合成表の証拠に使わない。仮定側へ移した名前を本文に置かない。
assert not any(re.search(r"\w\.table_response\b", t) for t in lean.values())
ledger = read("ledger-diff.json")
assert ledger["summary"]["moved_to_composition"] == 1
assert ledger["summary"]["connected_by_unit"] == {"L60.26": 79, "L60.27": 130, "L60.28": 24}
assert ledger["summary"]["composition_child_keys"]["after"] == 508
tables = read("tables-check.json")
assert tables["check1_evidence_to_composition"]["evidence_rows"] == 552
assert tables["check2_assumption_without_evidence"]["with_evidence"] == 0
assert tables["check3_composition_lookup"]["lookups_not_in_table"] == 0
assert tables["check4_rust_to_ledger"]["references"] == 523
fresh = json.loads(subprocess.run([sys.executable, str(HERE / "tables_check.py")], capture_output=True, text=True,
                                  check=True).stdout)
assert fresh == tables
conditions = read("conditions.json")
assert conditions["summary"]["fields"] == 29 and sum(conditions["summary"]["classes"].values()) == 29
names = set()
for row in ledger["moved"]:
    names.update(row["evidence"])
for row in ledger["connected"]:
    names.update(PREFIX + c for c in row["cover"].split("・"))
    if "family" in row:
        names.add(PREFIX + row["family"])
for row in conditions["fields"]:
    names.add(row["reader"])
missing = sorted(n for n in names if n not in targets)
assert not missing, missing

# 5. 記録の大きさ、手元の絶対パス、docs/todoへのリンク、相対リンク。
for f in HERE.glob("*.py"):
    ast.parse(f.read_text())
files = [f for f in HERE.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
assert all(f.stat().st_size <= 100000 for f in files)
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

previous_tools = read("../f1/tools.json")
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
                            "base": B_WORK, "inputs": inputs_digest})
output = {"modules": len(modules), "new_modules": MODULES, "edited_modules": EDITED,
          "added_files": len(added), "modified_existing": changed,
          "declarations": len(rows), "public_entries": len(public),
          "named_readers": sum(bool(r["named_readers"]) for r in public),
          "compiled_examples": sum(r["compiled_example"] for r in public),
          "bodies": len(bodies), "collection_rows": 79, "io_rows": 10, "scope_rows": 7,
          "ledger": ledger["summary"], "tables": tables, "conditions": conditions["summary"],
          "evidence_names": len(names), "axiom_targets": summary["targets"], "files": len(files),
          "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files)}
write(HERE / "verification.json", output)
print(json.dumps(output, ensure_ascii=False)[:3000])
