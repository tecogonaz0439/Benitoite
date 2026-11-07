# -*- coding: utf-8 -*-
"""段（L70）の記録と本番の対応を照合する段末の台本。前の群の verify.py は群末の記録として残し、再実行しない。

照合は三つの区間について行う。群 H は群 H の開始版 B_WORK から群 H のコミット B_H（h2/changes.json の base）まで、
群 H2 は B_H から群 H2 のコミット B_H2 まで、群 H3 は B_H2 から今の作業木まで（未追跡のファイルを含む）である。
段の最終の記録は h3/ にあり、h/ と h2/ の記録はそれぞれ B_H・B_H2 の時点のもの（書き換えない）である。

1. 変更の範囲。群 H の Lean の変更はコメントと、要らないと確かめた heartbeat の設定一つの除去だけ。群 H2 の変更は
   h2/changes.json の一覧と一致し、変えた Lean のファイルは B_H の行を消さずに足しただけ。群 H3 の変更は formal/、
   段の記録のディレクトリ、レビューの記録、01-12・07-04・formal/README.md の中だけ。h/・h2/ の記録（台本を除く）は
   B_H・B_H2 の時点から変わっていない。
2. 段・群 H2・群 H3 で足した全モジュールが既定 import（又は7入口の根）の閉包にある。根の import を外していない。
3. 段の公理監査・宣言の比較・信頼条件の比較・義務と申し送り・四分類・heartbeat・コメントの工程 ID の記録（h3/）を、生の出力と今の
   import の表から一時の場所に作り直し、記録を書き直さずに内容の SHA-256 で比べる。群 H2 の公理監査の記録も、
   h2/audit.py の analyze の書き込みを一時の値に差し替えて作り直し、比べる。
4. 主定理と主な言明（formal/README.md の一覧・07-04「証明する性質」・01-12「確かめる性質」の名前）と、群 H2・H3 の
   必須の名前が最終版の環境にある。
5. 群 H2・H3 で足した・変えた Lean のファイルのコメントの工程 ID・heartbeat の設定（h3/heartbeats.json の検査の外の
   増加）・sorry・#eval がない。
6. stage-results.md の件数を表の行の形で記録と照らす。記録の大きさ・手元の絶対パス・docs/todo へのリンク・相対リンク。
使い方: python3 verify.py --tmp <群 H3 の一時領域> --h2-tmp <群 H2 の一時領域>
（--tmp は stage.py が置いた final-*.log・base-*.log と base/formal、--h2-tmp は h2/audit.py が置いた生の出力）"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "h"))
from support import B_STAGE, B_WORK, DESIGN, ENTRIES, ROOT, closure, digest, git, module_graph  # noqa: E402
import stage  # noqa: E402
import comments  # noqa: E402

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--h2-tmp", type=Path, required=True)
args = parser.parse_args()
H, H2, H3 = HERE / "h", HERE / "h2", HERE / "h3"
CHANGES = json.loads((H2 / "changes.json").read_text())
B_H = CHANGES["base"]
B_H2 = "e447e3d6b653f1123a20665abc3348a71f4ac84c"
own = str(HERE.relative_to(ROOT))
REVIEWS = str((HERE.parent / "reviews").relative_to(ROOT))
COMMENT = re.compile(r"/-.*?-/|--[^\n]*", re.S)
OPTION = re.compile(r"^\s*set_option (maxHeartbeats|maxRecDepth) (\d+)( in)?\s*$", re.M)


def read(path):
    return json.loads(path.read_text())


def code(text):
    lines = [line.rstrip() for line in COMMENT.sub("", text).splitlines()]
    return [line for line in lines if line.strip()]


def is_subsequence(small, large):
    it = iter(large)
    return all(any(x == y for y in it) for x in small)


def sha(data):
    return hashlib.sha256(data if isinstance(data, bytes) else data.encode()).hexdigest()


# 1. 変更の範囲（群 H）。
changed = sorted(p for p in git("diff", "--name-only", B_WORK, B_H, "--").splitlines() if p)
lean_changed = [p for p in changed if p.startswith("formal/")]
comment_files = sorted(read(H / "comments.json")["before"]["by_file"])
algebra = "formal/Benitoite/Release/Refinement/Surface/PredicateSimulationAlgebra.lean"
assert lean_changed == sorted(set(comment_files) | {algebra}), lean_changed
assert all(p.startswith(own + "/") for p in changed if not p.startswith("formal/")), changed
for path in lean_changed:
    old, new = code(git("show", f"{B_WORK}:{path}")), code(git("show", f"{B_H}:{path}"))
    if path == algebra:
        assert old.count("set_option maxHeartbeats 400000 in") == new.count("set_option maxHeartbeats 400000 in") + 1
        i = old.index("set_option maxHeartbeats 400000 in")
        old = old[:i] + old[i + 1:]
    assert old == new, path

# 1. 変更の範囲（群 H2）。B_H から B_H2 までの差。
h2_changed = {p for p in git("diff", "--name-only", B_H, B_H2, "--").splitlines() if p}
records = CHANGES["added_records_dir"]
expected = set(CHANGES["modified"]) | set(CHANGES["added_lean"])
assert {p for p in h2_changed if not p.startswith(records)} == expected, \
    sorted({p for p in h2_changed if not p.startswith(records)} ^ expected)
for path in CHANGES["modified"]:
    if path.endswith(".lean"):
        before = git("show", f"{B_H}:{path}").splitlines()
        after = git("show", f"{B_H2}:{path}").splitlines()
        assert is_subsequence(before, after), ("B_H の行を消した", path)

# 1. 変更の範囲（群 H3）。B_H2 から作業木までの差と未追跡のファイル。
h3_changed = {p for p in git("diff", "--name-only", B_H2, "--").splitlines() if p}
untracked = {p for p in git("ls-files", "--others", "--exclude-standard").splitlines() if p}
h3_changed |= untracked
allowed = [own + "/", REVIEWS + "/", "formal/", *DESIGN]
assert all(any(p == a or p.startswith(a) for a in allowed) for p in h3_changed), \
    sorted(p for p in h3_changed if not any(p == a or p.startswith(a) for a in allowed))
assert all(p.startswith(REVIEWS + "/RV-L70.h") for p in h3_changed if p.startswith(REVIEWS + "/")), h3_changed
existed_h2 = set(git("ls-tree", "-r", "--name-only", B_H2, "formal/").split())
h3_lean = sorted(p for p in h3_changed if p.startswith("formal/") and p.endswith(".lean") and (ROOT / p).exists())
h3_added = [p for p in h3_lean if p not in existed_h2]
h3_modified = [p for p in h3_lean if p in existed_h2]
# 群 H・H2 の記録（台本を除く）は、それぞれの群のコミットの時点のまま。
for commit, directory in [(B_H, H), (B_H2, H2)]:
    rel = str(directory.relative_to(ROOT))
    for p in git("ls-tree", "-r", "--name-only", commit, rel + "/").split():
        if directory == H and p.endswith(".py"):
            continue
        assert (ROOT / p).read_bytes() == subprocess.run(["git", "-C", str(ROOT), "show", f"{commit}:{p}"],
                                                         capture_output=True, check=True).stdout, ("記録を変えた", p)

# 2. 既定 import。
graph = module_graph(ROOT / "formal")
default = closure(graph, ["Benitoite"])
entries = closure(graph, list(ENTRIES.values()))
modules = read(H3 / "modules.json")
added = ["Benitoite." + m if not m.split(".")[0] in stage.ENTRY_PREFIXES else m for m in modules["added"]]
assert all(m in default or m in entries for m in added), [m for m in added if m not in default and m not in entries]
assert all(m in default for m in added if m.startswith("Benitoite.")), [m for m in added if m not in default]
assert all(m in default for m in CHANGES["new_modules"] + CHANGES["changed_modules"])
h3_modules = [".".join(Path(p).relative_to("formal").with_suffix("").parts) for p in h3_lean]
assert all(m in default for m in h3_modules if m.startswith("Benitoite")), [m for m in h3_modules if m not in default]
root = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
removed = set(modules["removed"])
for line in git("show", f"{B_STAGE}:formal/Benitoite.lean").splitlines():
    if line.startswith("import ") and line.split()[1].removeprefix("Benitoite.") not in removed:
        assert line in root, ("根の import を外した", line)
for commit in [B_H, B_H2]:
    for line in git("show", f"{commit}:formal/Benitoite.lean").splitlines():
        if line.startswith("import "):
            assert line in root, ("根の import を外した", line)

# 3. 記録の作り直し（一時の場所へ書き、記録を書き直さずに比べる）。
required = read(H3 / "required-names.json")
scratch = Path(tempfile.mkdtemp(prefix="verify-", dir=args.tmp))
runs = [["stage.py", "analyze", "--tmp", str(args.tmp)], ["trust.py", "--tmp", str(args.tmp)],
        ["obligations.py", "--tmp", str(args.tmp)], ["four.py"], ["heartbeats.py", "--tmp", str(args.tmp)],
        ["comments.py"]]
for run in runs:
    extra = ["--out", str(scratch)] + (["--scratch", str(scratch)] if run[0] in ("stage.py", "trust.py",
                                                                              "obligations.py") else [])
    subprocess.run([sys.executable, "-B", str(H / run[0]), *run[1:], *extra], check=True, capture_output=True,
                   cwd=H)
compared = {}
for name in ["declarations.json", "audit-summary.json", *[f"required-{g}.json" for g in ["main", *required["extra"]]],
             "modules.json", "required.md", "trust.json", "trust.md",
             "obligations.json", "obligations.md", "four.json", "heartbeats.json", "comments.json"]:
    stored, again = (H3 / name).read_bytes(), (scratch / name).read_bytes()
    assert sha(stored) == sha(again), (name, "記録と再計算が一致しない")
    compared[name] = sha(stored)
summary, audit = read(H3 / "declarations.json"), read(H3 / "audit-summary.json")
assert audit["sorryAx"] == audit["new_axioms"] == audit["axiom_declarations"] == 0
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice", "なし"} for k in audit["axiom_sets"])
assert not audit["shared_contents"], audit["shared_contents"]
trust = read(H3 / "trust.json")
assert not trust["new_conditions"], trust["new_conditions"]
# 群 H2 の公理監査: h2/audit.py の analyze を、書き込みを一時の値に差し替えて呼ぶ。
spec = importlib.util.spec_from_file_location("h2audit", H2 / "audit.py")
h2audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h2audit)
captured = {}
h2audit.write = lambda path, obj: captured.update({Path(path).name: obj})
h2audit.analyze(args.h2_tmp)
h2_stored = read(H2 / "audit.json")
again = captured["audit.json"]
# 監査の入力の axioms.lean は群 H3 で本体のハッシュの欄を足したので、記録の値は B_H2 の写しの値と照らす。
old_axioms = subprocess.run(["git", "-C", str(ROOT), "show", f"{B_H2}:{own}/axioms.lean"], capture_output=True,
                            check=True).stdout
assert h2_stored["inputs"]["axioms.lean"] == {"bytes": len(old_axioms), "sha256": sha(old_axioms)}
again["inputs"]["axioms.lean"] = h2_stored["inputs"]["axioms.lean"]
assert json.dumps(again, ensure_ascii=False, indent=1) + "\n" == (H2 / "audit.json").read_text(), "h2/audit.json"
compared["h2/audit.json"] = sha((H2 / "audit.json").read_bytes())
assert h2_stored["sorryAx"] == h2_stored["new_axioms"] == h2_stored["axiom_declarations"] == 0

# 4. 主定理と主な言明の名前。
_, final = stage.merged(args.tmp, "final")
required = read(H3 / "required-names.json")
names_all = set(required["main"]) | {n for g in required["extra"].values() for n in g}
required_hashes = {}
for group in ["main", *required["extra"]]:
    required_hashes.update(read(H3 / f"required-{group}.json"))
assert set(required_hashes) == names_all and set(audit["required"]) == set(required["main"])
readme = (ROOT / "formal/README.md").read_text()
main_list = readme[readme.index("cat > /tmp/axioms.lean"):readme.index("主定理の一覧とは別に")]
listed = re.findall(r"^#print axioms (\S+)$", main_list, re.M)
assert listed and set(listed) <= names_all, sorted(set(listed) - names_all)
spec_text = (ROOT / DESIGN[1]).read_text()
section = spec_text[spec_text.index("### 証明する性質"):spec_text.index("### 篩を含む形式化の範囲")]
names = set(re.findall(r"`((?:Refinement\.)?(?:Surface\.)?[A-Za-z_]+(?:\.[A-Za-z_]+)*)`", section))
theorem_like = {n for n in names if re.search(r"(sound|typed|progress|preservation|_main|guarantees|soundness|desugar)", n)}
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
# 群 H2 の必須の名前は全て文書が名指す。群 H3 の Lean の担当の名前は補助と例を含むので、文書が名指さない名前を
# 一覧にして出力に残す（照合の失敗にしない）。
undocumented = []
for group, group_names in required["extra"].items():
    for n in group_names:
        assert n in final, n
        short = n.split(".")[-1]
        documented = short in core or short in spec_text or short in readme
        assert documented or group != "H2", ("文書にない", n)
        if not documented:
            undocumented.append(n.removeprefix("Benitoite.Release.Refinement."))

# 5. 群 H2・H3 で足した・変えた Lean のファイル。
heartbeats = read(H3 / "heartbeats.json")
assert not heartbeats["inherited"]["changed_files"]["untested"], heartbeats["inherited"]["changed_files"]["untested"]
tests = read(H3 / "heartbeats-tests.json") if (H3 / "heartbeats-tests.json").exists() else []
needed_by_file = {}
for t in tests:
    if t["judgement"].startswith("要る"):
        needed_by_file[t["file"]] = needed_by_file.get(t["file"], 0) + 1
for base_commit, after_commit, paths in [(B_H, B_H2, [p for p in CHANGES["modified"] + CHANGES["added_lean"]]),
                                         (B_H2, None, h3_lean)]:
    for path in [p for p in paths if p.endswith(".lean")]:
        text = (ROOT / path).read_text() if after_commit is None else git("show", f"{after_commit}:{path}")
        exists = path in set(git("ls-tree", "-r", "--name-only", base_commit, "formal/").split())
        old = git("show", f"{base_commit}:{path}") if exists else ""
        assert len(comments.hits(text)) <= len(comments.hits(old)), ("コメントの工程 ID", path)
        added_options = len(OPTION.findall(text)) - len(OPTION.findall(old))
        if added_options > 0:
            # 足した設定は、外した写しの検査で要ると確かめたものに限る。
            assert after_commit is None and needed_by_file.get(path.removeprefix("formal/"), 0) >= added_options, \
                ("heartbeat の設定", path)
        assert "sorry" not in COMMENT.sub("", text), path
        assert not re.search(r"^\s*#eval", text, re.M), path

# 6. stage-results.md の件数（表の行の形）と記録。
text = (HERE / "stage-results.md").read_text()
obligations, four = read(H3 / "obligations.json"), read(H3 / "four.json")
states = summary["states"]
for state in ["足した", "削除した", "型が変わった", "本体が変わった", "同じ"]:
    assert f"| {state} | {states[state]:,} |" in text, state
for n in [summary["final_declarations"], summary["base_declarations"], summary["modules"]["added"],
          summary["modules"]["removed"], audit["targets"], audit["macro_scoped"]]:
    assert f"{n:,}" in text or str(n) in text, n
for n in required["main"]:
    h = audit["required"][n]
    assert h["type_sha256"] in text and (h["value_sha256"] or h["unfolded_sha256"]) in text, n
for key, title in [("handoffs", "申し送り78行"), ("obligations", "義務59行")]:
    c = obligations["counts"]
    verdicts = c[key]
    four_counts = c["four_" + key]
    row = (f"| {title} | {verdicts.get('完了（L70 の分）', 0)} | {verdicts.get('完了（L70 の分。読者を要しない）', 0)} | "
           f"{verdicts.get('完了（L70 の分。記録）', 0)} | {verdicts.get('他段', 0)} |")
    assert row in text, row
    row = (f"| {title} | {four_counts.get('実質', 0)} | {four_counts.get('自明', 0)} | {four_counts.get('空疎', 0)} | "
           f"{four_counts.get('不成立', 0)} | {four_counts.get('未確認（行ごとの証人なし）', 0)} | "
           f"{four_counts.get('対象外（定義が判定の対象）', 0)} | {four_counts.get('対象外（Lean の証拠なし）', 0)} |")
    assert row in text, row
files = [p for d in (H, H2, H3, HERE / "h4") for p in d.iterdir() if p.is_file()] + \
    [HERE / "stage-results.md", HERE / "axioms.lean", Path(__file__)]
for p in files:
    data = p.read_text()
    assert p.stat().st_size <= 100000, p.name
    # 照合の文字列そのものが本書に現れないよう、分けて組み立てる。
    assert not re.search("/" + "Users/|/" + "private/tmp|/" + "home/", data), p.name
    assert ("docs/" + "todo/") not in data, p.name
for doc in [HERE / "stage-results.md", H3 / "obligations.md", H3 / "trust.md", H3 / "required.md"]:
    for link in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", doc.read_text()):
        if not link.startswith("http"):
            assert (doc.parent / link).exists(), (doc.name, link)
print(json.dumps({"h_changed": len(changed), "h2_changed": len(h2_changed), "h3_changed": len(h3_changed),
                  "h3_lean_added": len(h3_added), "h3_lean_modified": len(h3_modified),
                  "added_modules": len(added), "declarations": summary["final_declarations"],
                  "audit_targets": audit["targets"], "required": len(names_all), "undocumented_h3": undocumented,
                  "compared": compared,
                  "verified": True}, ensure_ascii=False))
