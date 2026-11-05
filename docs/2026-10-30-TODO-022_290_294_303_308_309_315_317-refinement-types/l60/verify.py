# -*- coding: utf-8 -*-
"""段（L60）の記録と本番の対応を照合する段末の台本。前の群の verify.py は群末の記録として残し、再実行しない。

1. 群Hの開始版 B_WORK からの変更の範囲と、段の開始版からの本番の変更の範囲（旧Releaseを変えない）。
2. 段で足した37モジュールと変えた既存の5モジュールが既定importの閉包にあり、根のimportに一度ずつ現れる。
3. 段の公理監査・既定ビルドの記録と生の出力、公理の組、必須の名前。
4. 段の全公開入口の読者（名前付きの宣言の依存、又は段のモジュールの既定ビルドの適用例）。
5. 群Gの義務・申し送り・四分類・除外の境界・関数値の台本を段の最終状態の依存の書き出しで照合の形で再実行する。
6. 群A〜Gの記録の宣言が本番にあること（段で消した名前を除く）、各群の監査の公理と sorryAx。
7. 写しの照合（h/copies.py）と段末の一覧（h/stage.py）の再現、記録の大きさ・手元の絶対パス・docs/todoへのリンク・相対リンク。
使い方: python3 verify.py --tmp <一時領域>（default-build.log・axioms.log・targets.txt・graph.log を置く）"""
import argparse
import ast
import collections
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "h"))
from support import (B_WORK, DESIGN, EDITED, GROUPS, L60_BASE, MODULES, NEW, PREFIX, ROOT, closure, digest, git,
                     module_path, show, write)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
H = HERE / "h"
graph = args.tmp / "graph.log"


def read(rel):
    return json.loads((HERE / rel).read_text())


# 1. 変更の範囲。
DECLARATIONS = "formal/Benitoite/Release/Refinement/StandardModelDeclarations.lean"
changed = sorted(set(git("diff", "--name-only", "-z", B_WORK, "--").split("\0")) - {""})
assert changed == sorted([DESIGN[0], DECLARATIONS, "formal/Benitoite.lean"]), changed
# 群Aが根から直接importしていなかった6モジュール（閉包には入っていた）を根のimportに加えた。
ROOT_ADDED = ["FunctionNameMap", "StandardModelDeclarations", "StandardModelSignatures", "StandardModelPrimitiveLookup",
              "BuiltinResponseTransport", "ExternalModelTransport"]
anchor = "import Benitoite.Release.Refinement.StandardModelResponse\n"
assert show(B_WORK, "formal/Benitoite.lean").replace(anchor, anchor + "".join(
    f"import {PREFIX}{m}\n" for m in ROOT_ADDED), 1) == (ROOT / "formal/Benitoite.lean").read_text()
removed_line = "def definitions : List (String × Def) := Body.all.map (fun body => (body.key,body.definition))\n"
assert show(B_WORK, DECLARATIONS).replace(removed_line, "", 1) == (ROOT / DECLARATIONS).read_text()
assert show(B_WORK, DESIGN[0]).replace("`constructor_pattern_rejected` はwildcard", "`non_binding_pattern_rejected` はwildcard",
                                       1) == (ROOT / DESIGN[0]).read_text()
untracked = git("ls-files", "--others", "--exclude-standard", "-z").split("\0")
own = str(HERE.relative_to(ROOT))
# 取りまとめが置いた段末の独立レビューの記録は、担当の変更に数えない。
review = str((HERE.parent / "reviews/RV-L60.h.md").relative_to(ROOT))
allowed = {own + "/axioms.lean", own + "/verify.py", own + "/stage-results.md", review}
assert all(p.startswith(own + "/h/") or p in allowed for p in untracked if p), \
    [p for p in untracked if p and not (p.startswith(own + "/h/") or p in allowed)]
status = dict(line.split("\t")[::-1] for line in git("diff", "--name-status", L60_BASE, "--", "formal").splitlines())
added = sorted(p for p, s in status.items() if s == "A")
modified = sorted(p for p, s in status.items() if s == "M")
assert added == sorted(str(module_path(m).relative_to(ROOT)) for m in NEW), added
assert modified == sorted(["formal/Benitoite.lean"] + [str(module_path(m).relative_to(ROOT)) for m in EDITED]), modified
assert set(status.values()) <= {"A", "M"}

# 2. 既定import。
modules = closure()
assert set(MODULES) <= set(modules)
root = (ROOT / "formal/Benitoite.lean").read_text()
for module in NEW:
    assert root.count("import " + module + "\n") == 1, module
base_root = show(L60_BASE, "formal/Benitoite.lean")
assert all(line in root.splitlines() for line in base_root.splitlines() if line.startswith("import ")), "根のimportを外した"

# 3. 監査と既定ビルド。
summary = read("h/audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
assert set(summary["stage_modules"]) == {m.removeprefix(PREFIX) for m in MODULES}
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "none"} for k in summary["axiom_sets"])
assert digest(args.tmp / "axioms.log") == summary["raw"] and digest(args.tmp / "targets.txt") == summary["target_list"]
targets = set((args.tmp / "targets.txt").read_text().split())
assert set(read("h/required-names.json")) <= targets
assert summary["inputs"]["axioms.lean"] == digest(HERE / "axioms.lean")
for name in ["default-build", "axioms"]:
    record = read(f"h/{name}.json")
    assert record["exit"] == 0 and record["raw"] == digest(args.tmp / (name + ".log")), name
raw = (args.tmp / "default-build.log").read_text()
assert "Build completed successfully" in raw
for module in MODULES:
    assert not re.search(r"warning: " + re.escape(module.replace(".", "/")) + r"\.lean", raw), module
short_rows = []
for part in summary["parts"]:
    assert digest(H / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
    for module, entries in json.loads((H / part["file"]).read_text()).items():
        short_rows.extend(entries)

# 段の依存の書き出し。
deps, owner, kinds = {}, {}, {}
for line in graph.read_text().splitlines():
    i = line.find("NODE ")
    if i >= 0:
        name, mod, kind, _, tdeps, vdeps = json.loads(line[i + 5:])
        deps[name], owner[name], kinds[name] = set(tdeps) | set(vdeps), mod, kind
assert set(deps) == targets, "依存の書き出しと監査の対象が違う"
# 記録の名前は接頭辞を除いてある。接頭辞のない名前（名前空間の外の生成宣言など）はそのまま引く。
rows = {}
for entry in short_rows:
    name = PREFIX + entry[0] if PREFIX + entry[0] in deps else entry[0]
    assert name in deps, entry[0]
    rows[name] = entry
assert len(rows) == len(short_rows) == summary["stage_declarations"]
assert set(rows) == {n for n, m in owner.items() if m in set(NEW)} | {
    n for n in rows if owner[n] in set(EDITED)}

# 4. 段の全公開入口の読者。
incoming = collections.defaultdict(set)
for n, ds in deps.items():
    for d in ds:
        if d != n:
            incoming[d].add(n)
EXAMPLE = r"^example[\s\S]*?(?=^(?:/--|theorem|def|private|example|end|set_option|noncomputable|abbrev|structure|" \
          r"inductive|namespace|open|section)\b)"
examples = "".join("".join(re.findall(EXAMPLE, module_path(m).read_text(), re.M)) for m in MODULES)
edited_added = {c["final_name"] for c in read("h/edited.json")["changes"] if c["state"] == "新規"}
public, unread, limits = [], [], []
for module in MODULES:
    source = module_path(module).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|#reduce|\bL[0-9]{2}\.[0-9]|\bR[0-9]{2}[ab]?\b", source), module
    # 上限の設定は各群（と段の前の既存のモジュール）が置いたものを一覧にする。段末に足したものはない。
    limits.extend({"module": module.removeprefix(PREFIX), "line": source.count("\n", 0, x.start()) + 1,
                   "option": x[0].strip()} for x in re.finditer(r"set_option (maxHeartbeats|maxRecDepth) \d+", source))
    stack = []
    for line in source.split("\n"):
        m = re.match(r"^namespace ([\w.]+)$", line)
        if m:
            stack.append(m[1])
            continue
        if re.match(r"^end [\w.]+$", line) and stack:
            stack.pop()
            continue
        m = re.match(r"^(?:noncomputable )?(?:theorem|structure|def|inductive|abbrev) ([A-Za-z][\w.]*)", line)
        if not m:
            continue
        space = ".".join(stack[-1:] + [m[1]])
        full = space if space.startswith("Benitoite.") else PREFIX + space
        if module in EDITED and full not in edited_added:
            continue
        assert full in deps, full
        readers = sorted(r for r in incoming[full] if not r.startswith(full + "."))
        direct = re.search(r"(?<![\w])" + re.escape(m[1].split(".")[-1]) + r"(?![\w])", examples) is not None
        if not (readers or direct):
            unread.append(full)
        public.append({"name": full.removeprefix(PREFIX), "named_readers": len(readers), "compiled_example": direct})
assert not unread, unread
write(H / "readers.json", {"entries": len(public), "named_readers": sum(r["named_readers"] > 0 for r in public),
                           "examples_only": sum(r["named_readers"] == 0 for r in public), "rows": public})

# 5. 群Gの台本を照合の形で再実行する。
G = HERE / "g"
runs = {}
for script, extra in [("records.py", ["--tmp", str(args.tmp / "g-records")]), ("conditions.py", []),
                      ("boundary.py", []), ("function_values.py", None)]:
    command = [sys.executable, str(G / script)] + (["--verify"] if extra is None else extra + ["--log", str(graph), "--verify"])
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 0, (script, result.stdout[-2000:], result.stderr[-2000:])
    runs[script] = result.stdout.strip().splitlines()[-1][:200]
# 群Gの記録の書き出しと段の最終状態の書き出しのハッシュ（段末に一つの定義を除いたので異なる）。
graphs = {"group_g": read("g/obligations.json")["source"]["sha256"], "stage": digest(graph)["sha256"]}

# 6. 群A〜Gの記録の宣言と各群の監査。
recorded = set()
for group in GROUPS:
    for part in sorted((HERE / group).glob("declarations-[0-9][0-9].json")):
        recorded.update(r["name"] for r in json.loads(part.read_text()))
    if group != "a":
        audit = read(f"{group}/audit-summary.json")
        assert audit["sorryAx"] == 0 and audit["new_axioms"] == 0, group
        assert set(read(f"{group}/requested-modules.json")) <= set(modules), group
a_audit = read("a/resume4-audit-summary.json")
assert a_audit["sorryAx"] == 0 and a_audit["new_axioms"] == 0
gone = sorted(n.removeprefix(PREFIX) for n in recorded - set(deps))
EXPLAINED = {"StandardModel.definitions": "段末に除いた（読者なし）",
             "StandardOrdinaryCoreBodies.getter_reference": "群F2が getter_reference_of へ置き換えた",
             "StandardModel.no_store_transitions": "群F1が store_transitions へ置き換えた"}
assert set(gone) <= set(EXPLAINED), [n for n in gone if n not in EXPLAINED][:10]

# 7. 写し・段末の一覧の再現と記録の形。
result = subprocess.run([sys.executable, str(H / "edited.py"), "--tmp", str(args.tmp), "--verify"], capture_output=True, text=True)
assert result.returncode == 0, ("edited.py", result.stdout[-2000:], result.stderr[-2000:])
runs["edited.py"] = result.stdout.strip().splitlines()[-1][:200]
for script in ["copies.py", "stage.py"]:
    result = subprocess.run([sys.executable, str(H / script), "--log", str(graph), "--verify"], capture_output=True, text=True)
    assert result.returncode == 0, (script, result.stdout[-2000:], result.stderr[-2000:])
    runs[script] = result.stdout.strip().splitlines()[-1][:200]
for f in list(H.glob("*.py")) + [Path(__file__)]:
    ast.parse(f.read_text())
files = [f for f in H.rglob("*") if f.is_file() and "__pycache__" not in f.parts] + \
    [HERE / "axioms.lean", HERE / "verify.py", HERE / "stage-results.md"]
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

previous_tools = read("g/tools.json")
inputs = {rel: digest(ROOT / rel) for rel in
          ["formal/lean-toolchain", "formal/lakefile.toml", "formal/lake-manifest.json", "formal/Benitoite.lean", DECLARATIONS]
          + DESIGN + sorted(str(f.relative_to(ROOT)) for f in H.glob("*.py")) + [own + "/axioms.lean", own + "/verify.py"]}
assert inputs["formal/lean-toolchain"] == previous_tools["inputs"]["formal/lean-toolchain"]
write(H / "tools.json", {"platform": {"system": platform.system(), "machine": platform.machine(), "release": platform.release()},
                         "lean": previous_tools["lean"], "memory_mib": 12288,
                         "configuration": "既定ターゲット・既定import・固定Lean。単独Leanも-M 12288。RSSは計画上の非採取",
                         "base": B_WORK, "stage_base": L60_BASE, "inputs": inputs, "graph": digest(graph)})
output = {"changed_from_base": changed, "stage_new_modules": len(NEW), "stage_edited_modules": len(EDITED),
          "modules": len(modules), "axiom_targets": summary["targets"], "stage_declarations": summary["stage_declarations"],
          "public_entries": len(public), "limit_options": limits, "group_records_gone": gone, "graphs": graphs, "reruns": runs,
          "files": len(files), "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files)}
write(H / "verification.json", output)
print(json.dumps(output, ensure_ascii=False)[:3000])
