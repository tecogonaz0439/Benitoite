# -*- coding: utf-8 -*-
"""群 D（篩付きの型の表層の型付け・脱糖・性質1・別名の展開・欄の依存・判定の関数）の記録と本番の対応を照合する
群末の台本。

1. B_WORK からの変更の範囲。変えたのは Surface の骨格（`Syntax.lean` の行の追加だけ）・根の import・01-12・07-04 だけで、
   核・旧 Release・旧 Surface・処理系・計画と前段の記録を変えない。未追跡は足した Surface のモジュールと本ディレクトリだけ。
2. 根の import の差分は import の行の追加だけで、足したモジュールが一度ずつ現れる。監査の対象のモジュール
   （足したものと変えたもの）を差分から作り直して `audit-modules.json` と照合する（`--write-modules` で書き出す）。
3. 既定ビルドの生の出力（終了0、エラーなし、足したモジュールと変えたモジュールの警告なし、ジョブ数）。
4. 公理監査の生の出力（sorryAx と未知の公理なし、対象の数と重複なし、モジュールごとの件数、必須の名前）。
5. 足したモジュールと足した行に sorry・#eval・#check・#print・maxRecDepth・工程の ID がない。
   maxHeartbeats は相互帰納の性質1と有効範囲の二つの定理の `set_option maxHeartbeats 400000 in` だけである。
6. 記録の大きさ（各 100 KB 以下）、手元の絶対パスと docs/todo へのリンクがない。
結果を audit-summary.json に書く（生の出力は大きさと SHA-256 だけを残す）。
使い方: python3 verify.py --tmp <一時領域>（build.log・axioms.log を置く）"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
B_WORK = "49f17471442229baf668e7b1f7b6dac8151c6dcf"
DESIGN = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]
ALLOWED_AXIOMS = {"propext", "Quot.sound", "Classical.choice"}
SURFACE = "formal/Benitoite/Release/Refinement/Surface/"
EDITABLE_EXISTING = [SURFACE + "Syntax.lean"]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--write-modules", action="store_true")
args = parser.parse_args()


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], check=True, capture_output=True, text=True).stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def module_of(path):
    return path[len("formal/"):-len(".lean")].replace("/", ".")


# 1. 変更の範囲。
changed = sorted(set(git("diff", "--name-only", "-z", B_WORK, "--").split("\0")) - {""})
assert all(p in DESIGN or p == "formal/Benitoite.lean" or p in EDITABLE_EXISTING for p in changed), changed
own = str(HERE.relative_to(ROOT))
untracked = sorted(set(git("ls-files", "--others", "--exclude-standard", "-z").split("\0")) - {""})
added_lean = [p for p in untracked if p.startswith(SURFACE) and p.endswith(".lean")]
# 群の独立レビューの記録（取りまとめが置く）は照合の対象の外とする。
REVIEW = str((HERE.parents[1] / "reviews/RV-L70.d.md").relative_to(ROOT))
assert all(p.startswith(own + "/") or p in added_lean or p == REVIEW for p in untracked), untracked
NEW = sorted(module_of(p) for p in added_lean)
EDITED = sorted(module_of(p) for p in changed if p in EDITABLE_EXISTING)

# 骨格の変更は行の追加だけである。
skeleton = git("diff", "-U0", B_WORK, "--", *EDITABLE_EXISTING)
assert not [l for l in skeleton.splitlines() if l.startswith("-") and not l.startswith("---")]

# 2. 根の import と監査の対象。
root_diff = git("diff", "-U0", B_WORK, "--", "formal/Benitoite.lean")
assert not [l for l in root_diff.splitlines() if l.startswith("-") and not l.startswith("---")]
added_root = [l[1:] for l in root_diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
assert all(re.fullmatch(r"import \S+", l) for l in added_root), added_root
appended = [l.split()[1] for l in added_root]
assert sorted(appended) == NEW and len(appended) == len(set(appended)), (appended, NEW)
root = (ROOT / "formal/Benitoite.lean").read_text()
assert all(len(re.findall(rf"^import {re.escape(m)}$", root, re.M)) == 1 for m in NEW)
modules_path = HERE / "audit-modules.json"
if args.write_modules:
    modules_path.write_text(json.dumps(sorted(NEW + EDITED), ensure_ascii=False, indent=1) + "\n")
modules = json.loads(modules_path.read_text())
assert sorted(modules) == sorted(NEW + EDITED), (modules, NEW + EDITED)
required = json.loads((HERE / "required-names.json").read_text())

# 3. 既定ビルド。
build = args.tmp / "build.log"
text = build.read_text()
assert re.search(r"^rc=0$", text, re.M), "既定ビルドが失敗した"
assert "error:" not in text
jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", text)[1])
warned = [m for m in NEW + EDITED
          if re.search(rf"warning: {re.escape(m.replace('.', '/'))}\.lean:\d+:\d+:", text)]
assert not warned, warned

# 4. 公理監査。
log = args.tmp / "axioms.log"
audit = log.read_text()
assert not re.search(r"error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", audit)
targets = re.findall(r"^AUDIT_TARGET (.+)$", audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", audit, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(",") if x.strip())) for _, ax in axioms)
assert all(set(s) <= ALLOWED_AXIOMS for s in sets), sets
per_module = {m: int(c) for m, c in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", audit, re.M)}
assert sorted(per_module) == sorted(modules) and sum(per_module.values()) == len(targets)
decls = re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", audit, re.M)
assert len(decls) == len(targets)
assert set(required) <= set(targets)
kinds = collections.Counter((m, k) for m, k, _, _ in decls)
private = sum(1 for _, _, _, n in decls if n.startswith("_private."))
new_count = sum(per_module[m] for m in NEW)

# 5. 本番のソースの禁止の形。
FORBIDDEN = r"\bsorry\b|#eval|#check|#print|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b"
heartbeats = []
for p in added_lean:
    src = (ROOT / p).read_text()
    assert not re.search(FORBIDDEN, src), p
    for line in re.findall(r"^.*maxHeartbeats.*$", src, re.M):
        assert line == "set_option maxHeartbeats 400000 in", (p, line)
        heartbeats.append(module_of(p))
assert sorted(heartbeats) == ["Benitoite.Release.Refinement.Surface.Property1",
                              "Benitoite.Release.Refinement.Surface.ScopedProof"], heartbeats
added_src = "\n".join(l[1:] for l in skeleton.splitlines() if l.startswith("+") and not l.startswith("+++"))
assert not re.search(FORBIDDEN + r"|maxHeartbeats", added_src)
design_diff = git("diff", "-U0", B_WORK, "--", *DESIGN)
assert not re.search(r"\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|docs/todo|改造", "\n".join(
    l for l in design_diff.splitlines() if l.startswith("+")))

# 6. 記録。
for p in sorted(HERE.iterdir()):
    if p.is_file():
        assert p.stat().st_size <= 100_000, p
        body = p.read_text()
        assert "/Us" + "ers/" not in body and "/priv" + "ate/tmp" not in body, p
        assert not re.search(r"\]\([^)]*docs/todo", body), p

summary = {
    "b_work": B_WORK,
    "head": git("rev-parse", "HEAD").strip(),
    "changed": changed,
    "untracked": untracked,
    "build": {"jobs": jobs, "bytes": build.stat().st_size, "sha256": digest(build)},
    "axioms": {"bytes": log.stat().st_size, "sha256": digest(log), "targets": len(targets),
               "new_module_declarations": new_count, "private": private,
               "sets": {",".join(k) or "(none)": v for k, v in sorted(sets.items())},
               "modules": per_module,
               "kinds": {f"{m} {k}": v for (m, k), v in sorted(kinds.items())}},
    "required": len(required),
    "heartbeats": heartbeats,
    "sources": {m: digest(ROOT / ("formal/" + m.replace(".", "/") + ".lean")) for m in NEW + EDITED},
}
(HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
print(json.dumps({k: v for k, v in summary.items() if k != "sources"}, ensure_ascii=False, indent=1))
