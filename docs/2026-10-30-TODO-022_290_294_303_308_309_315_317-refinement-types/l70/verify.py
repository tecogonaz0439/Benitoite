# -*- coding: utf-8 -*-
"""段（L70）の記録と本番の対応を照合する段末の台本。前の群の verify.py は群末の記録として残し、再実行しない。

群 H の照合は群 H のコミット（h2/changes.json の base。以下 B_H）の状態について行い、群 H2 の照合は B_H から今の作業木
までの変更について行う。

1. 群 H の開始版 B_WORK から B_H までの変更の範囲。Lean の変更はコメントと、要らないと確かめた heartbeat の設定一つの
   除去だけで、ほかは段の記録のディレクトリの中だけ。群 H2 の変更は h2/changes.json の一覧と一致し、変えた Lean の
   ファイルは B_H の行を消さずに足しただけである。
2. 段と群 H2 で足した全モジュールが既定 import（又は7入口の根）の閉包にある。根の import を外していない。
3. 段の公理監査・宣言の比較の記録を、B_H の formal の import の表と生の出力から作り直して一致を確かめる
   （h/stage.py analyze の再計算）。群 H2 の公理監査の記録を生の出力から作り直して一致を確かめる（h2/audit.py analyze）。
4. 主定理と主な言明（formal/README.md の一覧・07-04「証明する性質」・01-12「確かめる性質」の名前）が本番にある。
5. 義務と申し送り・旧の性質の照合・四分類の記録の再現。コメントの工程 ID と heartbeat の記録は、群 H の記録を
   B_H の作業木で作ったので再現の対象にせず、群 H2 で足した・変えたファイルのコメントの工程 ID と heartbeat の設定が
   0件であることを確かめる。
6. stage-results.md の件数が記録と一致する。記録の大きさ・手元の絶対パス・docs/todo へのリンク。
使い方: python3 verify.py --tmp <群 H の一時領域> --h2-tmp <群 H2 の一時領域>
（--tmp は stage.py が置いた final-*.log・base-*.log と base/formal、--h2-tmp は h2/audit.py が置いた生の出力）"""
import argparse
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "h"))
from support import B_STAGE, B_WORK, DESIGN, ENTRIES, ROOT, closure, git, module_graph  # noqa: E402
import stage  # noqa: E402
import comments  # noqa: E402

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--h2-tmp", type=Path, required=True)
args = parser.parse_args()
H = HERE / "h"
H2 = HERE / "h2"
CHANGES = json.loads((H2 / "changes.json").read_text())
B_H = CHANGES["base"]


def read(name):
    return json.loads((H / name).read_text())


# 1. 変更の範囲（群 H）。
own = str(HERE.relative_to(ROOT))
changed = sorted(p for p in git("diff", "--name-only", B_WORK, B_H, "--").splitlines() if p)
lean_changed = [p for p in changed if p.startswith("formal/")]
comment_files = sorted(read("comments.json")["before"]["by_file"])
algebra = "formal/Benitoite/Release/Refinement/Surface/PredicateSimulationAlgebra.lean"
assert lean_changed == sorted(set(comment_files) | {algebra}), lean_changed
assert all(p.startswith(own + "/") for p in changed if not p.startswith("formal/")), changed
COMMENT = re.compile(r"/-.*?-/|--[^\n]*", re.S)


def code(text):
    lines = [line.rstrip() for line in COMMENT.sub("", text).splitlines()]
    return [line for line in lines if line.strip()]


for path in lean_changed:
    old, new = code(git("show", f"{B_WORK}:{path}")), code(git("show", f"{B_H}:{path}"))
    if path == algebra:
        assert old.count("set_option maxHeartbeats 400000 in") == new.count("set_option maxHeartbeats 400000 in") + 1
        i = old.index("set_option maxHeartbeats 400000 in")
        old = old[:i] + old[i + 1:]
    assert old == new, path

# 1. 変更の範囲（群 H2）。コミットの前後のどちらでも、B_H から作業木までの差と未追跡のファイルを合わせて数える。
h2_changed = {p for p in git("diff", "--name-only", B_H, "--").splitlines() if p}
h2_changed |= {p for p in git("ls-files", "--others", "--exclude-standard").splitlines() if p}
records = CHANGES["added_records_dir"]
expected = set(CHANGES["modified"]) | set(CHANGES["added_lean"])
assert {p for p in h2_changed if not p.startswith(records)} == expected, \
    sorted({p for p in h2_changed if not p.startswith(records)} ^ expected)


def is_subsequence(small, large):
    it = iter(large)
    return all(any(x == y for y in it) for x in small)


for path in CHANGES["modified"]:
    if path.endswith(".lean"):
        before = git("show", f"{B_H}:{path}").splitlines()
        after = (ROOT / path).read_text().splitlines()
        assert is_subsequence(before, after), ("B_H の行を消した", path)

# 2. 既定 import。
graph = module_graph(ROOT / "formal")
default = closure(graph, ["Benitoite"])
modules = read("modules.json")
added = ["Benitoite." + m if not m.split(".")[0] in stage.ENTRY_PREFIXES else m for m in modules["added"]]
entries = closure(graph, list(ENTRIES.values()))
assert all(m in default or m in entries for m in added), [m for m in added if m not in default and m not in entries]
benitoite_added = [m for m in added if m.startswith("Benitoite.")]
assert all(m in default for m in benitoite_added), [m for m in benitoite_added if m not in default]
assert all(m in default for m in CHANGES["new_modules"] + CHANGES["changed_modules"]), \
    [m for m in CHANGES["new_modules"] + CHANGES["changed_modules"] if m not in default]
root = (ROOT / "formal/Benitoite.lean").read_text()
base_root = git("show", f"{B_STAGE}:formal/Benitoite.lean")
removed = set(modules["removed"])
for line in base_root.splitlines():
    if line.startswith("import ") and line.split()[1].removeprefix("Benitoite.") not in removed:
        assert line in root.splitlines(), ("根の import を外した", line)
for line in git("show", f"{B_H}:formal/Benitoite.lean").splitlines():
    if line.startswith("import "):
        assert line in root.splitlines(), ("根の import を外した", line)

# 3. 公理監査と宣言の比較の再計算（群 H は B_H の formal の import の表で行う）。
h_root = args.h2_tmp / "h-root"
if not (h_root / "formal").exists():
    data = subprocess.run(["git", "-C", str(ROOT), "archive", B_H, "formal"], capture_output=True, check=True).stdout
    h_root.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        archive.extractall(h_root)
saved = {name: (H / name).read_text() for name in ["declarations.json", "audit-summary.json", "modules.json"]}
current_root = stage.ROOT
stage.ROOT = h_root
try:
    stage.analyze(args.tmp)
finally:
    stage.ROOT = current_root
for name, text in saved.items():
    assert (H / name).read_text() == text, (name, "記録と再計算が一致しない")
summary, audit = read("declarations.json"), read("audit-summary.json")
assert audit["sorryAx"] == audit["new_axioms"] == audit["axiom_declarations"] == 0
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "なし"} for k in audit["axiom_sets"])
h2_saved = (H2 / "audit.json").read_text()
subprocess.run([sys.executable, str(H2 / "audit.py"), "analyze", "--tmp", str(args.h2_tmp)], check=True,
               capture_output=True)
assert (H2 / "audit.json").read_text() == h2_saved, ("h2/audit.json", "記録と再計算が一致しない")
h2_audit = json.loads(h2_saved)
assert h2_audit["sorryAx"] == h2_audit["new_axioms"] == h2_audit["axiom_declarations"] == 0
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "なし"} for k in h2_audit["axiom_sets"])
h2_part = stage.load(args.h2_tmp / "h2-audit.log")
h2_names = set(h2_part["nodes"])

# 4. 主定理と主な言明の名前。
required = set(read("required-names.json")) | set(CHANGES["required"])
readme = (ROOT / "formal/README.md").read_text()
main_list = readme[readme.index("cat > /tmp/axioms.lean"):readme.index("主定理の一覧とは別に")]
listed = re.findall(r"^#print axioms (\S+)$", main_list, re.M)
assert listed and set(listed) <= required, sorted(set(listed) - required)
spec = (ROOT / DESIGN[1]).read_text()
section = spec[spec.index("### 証明する性質"):spec.index("### 篩を含む形式化の範囲")]
names = set(re.findall(r"`((?:Refinement\.)?(?:Surface\.)?[A-Za-z_]+(?:\.[A-Za-z_]+)*)`", section))
theorem_like = {n for n in names if re.search(r"(sound|typed|progress|preservation|_main|guarantees|soundness|desugar)", n)}
final_parts, final = stage.merged(args.tmp, "final")
known = set(final) | h2_names
unresolved = []
for n in sorted(theorem_like):
    short = n.removeprefix("Refinement.")
    hits = [k for k in ["Benitoite.Release.Refinement." + short, "Benitoite.Release.Refinement.Surface." + short,
                        "Benitoite.Release.Refinement.Coverage." + short] if k in known]
    if not hits:
        # 07-04 は同じ名前空間の並びで前の名前の接頭辞を省くことがある（`StateTyE.builder_new`・`builder_progress`）。
        hits = [k for k in known if k.startswith("Benitoite.Release.Refinement.") and k.endswith("." + short)]
    if not hits:
        unresolved.append(n)
assert not unresolved, unresolved
core = (ROOT / DESIGN[0]).read_text()
properties = core[core.index("### 確かめる性質"):]
for n in ["Surface.desugar_typed", "Surface.surface_effect_soundness", "Surface.checkProgramAccepted_main",
          "Surface.linked_main", "StandardModel.included_guarantees", "Surface.surface_guarantees",
          "Surface.CheckedMainExamples.main_guarantees", "StartCondition.of_typed_noLamNames"]:
    assert n.split(".")[-1] in properties and "Benitoite.Release.Refinement." + n in final, n
assert "TargetReachExamples.main_reach" in properties
for n in CHANGES["required"]:
    assert n in h2_names, n
    short = n.split(".")[-1]
    assert short in core or short in spec or short in readme, ("文書にない", n)

# 5. 義務・旧の性質・四分類の記録の再現。群 H2 のコメントの工程 ID と heartbeat の設定。
for script in ["obligations.py", "legacy.py"]:
    name = script.replace(".py", ".json")
    before = (H / name).read_text()
    subprocess.run([sys.executable, str(H / script), "--tmp", str(args.tmp)], check=True, capture_output=True)
    assert (H / name).read_text() == before, (name, "再現しない")
before = (H / "four.json").read_text()
subprocess.run([sys.executable, str(H / "four.py")], check=True, capture_output=True)
assert (H / "four.json").read_text() == before, ("four.json", "再現しない")
OPTION = re.compile(r"^\s*set_option (maxHeartbeats|maxRecDepth) (\d+)( in)?\s*$", re.M)
for path in [p for p in CHANGES["modified"] + CHANGES["added_lean"] if p.endswith(".lean")]:
    text = (ROOT / path).read_text()
    old = git("show", f"{B_H}:{path}") if path in CHANGES["modified"] else ""
    assert len(comments.hits(text)) == len(comments.hits(old)), ("コメントの工程 ID", path)
    assert len(OPTION.findall(text)) == len(OPTION.findall(old)), ("heartbeat の設定", path)
    assert "sorry" not in COMMENT.sub("", text), path
    assert not re.search(r"^\s*#eval", text, re.M), path

# 6. stage-results.md の件数と記録。
text = (HERE / "stage-results.md").read_text()
obligations, legacy = read("obligations.json"), read("legacy.json")
numbers = [summary["final_declarations"], summary["base_declarations"], summary["states"]["足した"],
           summary["states"]["削除した"], summary["states"]["型が変わった"], summary["states"]["同じ"],
           summary["modules"]["added"], summary["modules"]["removed"], audit["targets"], audit["macro_scoped"],
           legacy["verdicts"]["導ける"], legacy["verdicts"]["別の形"], legacy["verdicts"]["失った"],
           h2_audit["declarations"], len(CHANGES["new_modules"])]
for n in numbers:
    assert f"{n:,}" in text or str(n) in text, n
for n in audit["required"].values():
    assert n["type_sha256"] in text, n
files = [p for p in H.iterdir() if p.is_file()] + [p for p in H2.iterdir() if p.is_file()] + \
    [HERE / "stage-results.md", HERE / "axioms.lean", Path(__file__)]
for p in files:
    data = p.read_text()
    assert p.stat().st_size <= 100000, p.name
    # 照合の文字列そのものが本書に現れないよう、分けて組み立てる。
    assert not re.search("/" + "Users/|/" + "private/tmp|/" + "home/", data), p.name
    assert ("docs/" + "todo/") not in data, p.name
for link in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", text):
    if not link.startswith("http"):
        assert (HERE / link).exists(), link
print(json.dumps({"changed": len(changed), "h2_changed": len(h2_changed), "added_modules": len(added),
                  "h2_modules": len(CHANGES["new_modules"]), "declarations": summary["final_declarations"],
                  "h2_declarations": h2_audit["declarations"], "audit_targets": audit["targets"],
                  "required": len(required), "verified": True}, ensure_ascii=False))
