# -*- coding: utf-8 -*-
"""段（L70）の記録と本番の対応を照合する段末の台本。前の群の verify.py は群末の記録として残し、再実行しない。

1. 群 H の開始版 B_WORK からの変更の範囲。Lean の変更はコメントと、要らないと確かめた heartbeat の設定一つの除去だけ。
2. 段で足した全モジュールが既定 import（又は7入口の根）の閉包にある。根の import を外していない。
3. 段の公理監査・宣言の比較の記録を生の出力から作り直して一致を確かめる（h/stage.py analyze の再計算）。
4. 主定理と主な言明（formal/README.md の一覧・07-04「証明する性質」・01-12「確かめる性質」の名前）が本番にある。
5. 義務と申し送り・旧の性質の照合・コメントの工程 ID・heartbeat の記録の再現。
6. stage-results.md の件数が記録と一致する。記録の大きさ・手元の絶対パス・docs/todo へのリンク。
使い方: python3 verify.py --tmp <一時領域>（stage.py が置いた final-*.log・base-*.log と base/formal を使う）"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "h"))
from support import B_STAGE, B_WORK, DESIGN, ENTRIES, ROOT, closure, git, module_graph  # noqa: E402
import stage  # noqa: E402

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
H = HERE / "h"


def read(name):
    return json.loads((H / name).read_text())


# 1. 変更の範囲。
changed = sorted(p for p in git("diff", "--name-only", B_WORK, "--").splitlines() if p)
comment_files = sorted(read("comments.json")["before"]["by_file"])
algebra = "formal/Benitoite/Release/Refinement/Surface/PredicateSimulationAlgebra.lean"
assert changed == sorted(set(comment_files) | {algebra}), changed
COMMENT = re.compile(r"/-.*?-/|--[^\n]*", re.S)


def code(text):
    lines = [line.rstrip() for line in COMMENT.sub("", text).splitlines()]
    return [line for line in lines if line.strip()]


for path in changed:
    old, new = code(git("show", f"{B_WORK}:{path}")), code((ROOT / path).read_text())
    if path == algebra:
        assert old.count("set_option maxHeartbeats 400000 in") == new.count("set_option maxHeartbeats 400000 in") + 1
        i = old.index("set_option maxHeartbeats 400000 in")
        old = old[:i] + old[i + 1:]
    assert old == new, path
untracked = [p for p in git("ls-files", "--others", "--exclude-standard").splitlines() if p]
own = str(HERE.relative_to(ROOT))
allowed = {own + "/axioms.lean", own + "/verify.py", own + "/stage-results.md"}
assert all(p.startswith(own + "/h/") or p in allowed for p in untracked), \
    [p for p in untracked if not (p.startswith(own + "/h/") or p in allowed)]

# 2. 既定 import。
graph = module_graph(ROOT / "formal")
default = closure(graph, ["Benitoite"])
modules = read("modules.json")
added = ["Benitoite." + m if not m.split(".")[0] in stage.ENTRY_PREFIXES else m for m in modules["added"]]
entries = closure(graph, list(ENTRIES.values()))
assert all(m in default or m in entries for m in added), [m for m in added if m not in default and m not in entries]
benitoite_added = [m for m in added if m.startswith("Benitoite.")]
assert all(m in default for m in benitoite_added), [m for m in benitoite_added if m not in default]
root = (ROOT / "formal/Benitoite.lean").read_text()
base_root = git("show", f"{B_STAGE}:formal/Benitoite.lean")
removed = set(modules["removed"])
for line in base_root.splitlines():
    if line.startswith("import ") and line.split()[1].removeprefix("Benitoite.") not in removed:
        assert line in root.splitlines(), ("根の import を外した", line)

# 3. 公理監査と宣言の比較の再計算。
saved = {name: (H / name).read_text() for name in ["declarations.json", "audit-summary.json", "modules.json"]}
stage.analyze(args.tmp)
for name, text in saved.items():
    assert (H / name).read_text() == text, (name, "記録と再計算が一致しない")
summary, audit = read("declarations.json"), read("audit-summary.json")
assert audit["sorryAx"] == audit["new_axioms"] == audit["axiom_declarations"] == 0
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "なし"} for k in audit["axiom_sets"])

# 4. 主定理と主な言明の名前。
required = set(read("required-names.json"))
readme = (ROOT / "formal/README.md").read_text()
main_list = readme[readme.index("cat > /tmp/axioms.lean"):readme.index("主定理の一覧とは別に")]
listed = re.findall(r"^#print axioms (\S+)$", main_list, re.M)
assert listed and set(listed) <= required, sorted(set(listed) - required)
spec = (ROOT / DESIGN[1]).read_text()
section = spec[spec.index("### 証明する性質"):spec.index("### 篩を含む形式化の範囲")]
names = set(re.findall(r"`((?:Refinement\.)?(?:Surface\.)?[A-Za-z_]+(?:\.[A-Za-z_]+)*)`", section))
theorem_like = {n for n in names if re.search(r"(sound|typed|progress|preservation|_main|guarantees|soundness|desugar)", n)}
final_parts, final = stage.merged(args.tmp, "final")
unresolved = []
for n in sorted(theorem_like):
    short = n.removeprefix("Refinement.")
    hits = [k for k in ["Benitoite.Release.Refinement." + short, "Benitoite.Release.Refinement.Surface." + short,
                        "Benitoite.Release.Refinement.Coverage." + short] if k in final]
    if not hits:
        # 07-04 は同じ名前空間の並びで前の名前の接頭辞を省くことがある（`StateTyE.builder_new`・`builder_progress`）。
        hits = [k for k in final if k.startswith("Benitoite.Release.Refinement.") and k.endswith("." + short)]
    if not hits:
        unresolved.append(n)
assert not unresolved, unresolved
core = (ROOT / DESIGN[0]).read_text()
properties = core[core.index("### 確かめる性質"):]
for n in ["Surface.desugar_typed", "Surface.surface_effect_soundness", "Surface.checkProgramAccepted_main",
          "Surface.linked_main", "StandardModel.included_guarantees", "Surface.surface_guarantees",
          "Surface.CheckedMainExamples.main_guarantees", "StartCondition.of_typed_noLamNames"]:
    assert n.split(".")[-1] in properties and "Benitoite.Release.Refinement." + n in final, n

# 5. 義務・旧の性質・コメント・heartbeat の記録の再現。
for script in ["obligations.py", "legacy.py"]:
    name = script.replace(".py", ".json")
    before = (H / name).read_text()
    subprocess.run([sys.executable, str(H / script), "--tmp", str(args.tmp)], check=True, capture_output=True)
    assert (H / name).read_text() == before, (name, "再現しない")
for script in ["comments.py", "four.py"]:
    name = script.replace(".py", ".json")
    before = (H / name).read_text()
    subprocess.run([sys.executable, str(H / script)], check=True, capture_output=True)
    assert (H / name).read_text() == before, (name, "再現しない")
before = (H / "heartbeats.json").read_text()
subprocess.run([sys.executable, str(H / "heartbeats.py"), "--tmp", str(args.tmp)], check=True, capture_output=True)
assert (H / "heartbeats.json").read_text() == before

# 6. stage-results.md の件数と記録。
text = (HERE / "stage-results.md").read_text()
obligations, legacy = read("obligations.json"), read("legacy.json")
numbers = [summary["final_declarations"], summary["base_declarations"], summary["states"]["足した"],
           summary["states"]["削除した"], summary["states"]["型が変わった"], summary["states"]["同じ"],
           summary["modules"]["added"], summary["modules"]["removed"], audit["targets"], audit["macro_scoped"],
           legacy["verdicts"]["導ける"], legacy["verdicts"]["別の形"], legacy["verdicts"]["失った"]]
for n in numbers:
    assert f"{n:,}" in text or str(n) in text, n
for n in audit["required"].values():
    assert n["type_sha256"] in text, n
files = [p for p in H.iterdir() if p.is_file()] + [HERE / "stage-results.md", HERE / "axioms.lean", Path(__file__)]
for p in files:
    data = p.read_text()
    assert p.stat().st_size <= 100000, p.name
    # 照合の文字列そのものが本書に現れないよう、分けて組み立てる。
    assert not re.search("/" + "Users/|/" + "private/tmp|/" + "home/", data), p.name
    assert ("docs/" + "todo/") not in data, p.name
for link in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", text):
    if not link.startswith("http"):
        assert (HERE / link).exists(), link
print(json.dumps({"changed": len(changed), "added_modules": len(added), "declarations": summary["final_declarations"],
                  "audit_targets": audit["targets"], "required": len(required), "verified": True}, ensure_ascii=False))
