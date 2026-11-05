# -*- coding: utf-8 -*-
"""群 U（公開形の写し・旧 API の静的拒否の旧構成子への変更・公開名の対応）の記録と本番の対応を照合する群末の台本。

1. B_WORK からの変更の範囲。変えたのは Refinement のモジュール・根の import・01-12・07-04 だけで、旧 Release・処理系・
   計画と前段の記録を変えない。未追跡は足したモジュールと本ディレクトリだけ。
2. 足した四モジュールが根の既定 import に一度ずつ現れる。監査の対象のモジュール（足したものと変えたもの）を差分から
   作り直して照合する。
3. 既定ビルドの生の出力（終了0、エラーなし、足したモジュールと変えたモジュールの警告なし、ジョブ数）。
4. 公理監査の生の出力（sorryAx と未知の公理なし、対象の数と重複なし、モジュールごとの件数、必須の名前）。
5. 足したモジュールと足した行に sorry・#eval・#check・maxHeartbeats・maxRecDepth・工程の ID がない。
6. 記録の大きさ（各 100 KB 以下）、手元の絶対パスと docs/todo へのリンクがない。
結果を audit-summary.json に書く（生の出力は大きさと SHA-256 だけを残す）。
使い方: python3 verify.py --tmp <一時領域>（build0.log・build.log・axioms.log を置く）"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
B_WORK = "657b3ae713040e78826d2f19cd7b8ac9f415a6d6"
PREFIX = "Benitoite.Release.Refinement."
NEW = ["ScopePublic", "ScopePublicValues", "ScopePublicTyping", "PublicNames"]
DESIGN = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]
ALLOWED_AXIOMS = {"propext", "Quot.sound", "Classical.choice"}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], check=True, capture_output=True, text=True).stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def module_path(m):
    return "formal/Benitoite/Release/Refinement/" + m + ".lean"


# 1. 変更の範囲。
changed = sorted(set(git("diff", "--name-only", "-z", B_WORK, "--").split("\0")) - {""})
REF = "formal/Benitoite/Release/Refinement/"
assert all(p in DESIGN or p == "formal/Benitoite.lean" or (p.startswith(REF) and p.endswith(".lean")
                                                          and "/" not in p[len(REF):]) for p in changed), changed
EDITED = sorted(Path(p).stem for p in changed if p.startswith(REF))
own = str(HERE.relative_to(ROOT))
untracked = sorted(set(git("ls-files", "--others", "--exclude-standard", "-z").split("\0")) - {""})
assert all(p.startswith(own + "/") or p in [module_path(m) for m in NEW] for p in untracked), untracked
assert all(module_path(m) in untracked for m in NEW), untracked

# 2. 根の import と監査の対象。
root = (ROOT / "formal/Benitoite.lean").read_text()
base_root = git("show", f"{B_WORK}:formal/Benitoite.lean")
assert root == base_root + "".join(f"import {PREFIX}{m}\n" for m in NEW)
for m in NEW:
    assert root.count(f"import {PREFIX}{m}\n") == 1
added_lean = [p for p in untracked if p.startswith("formal/") and p.endswith(".lean")]
edited_lean = [p for p in changed if p.startswith("formal/Benitoite/Release/Refinement/")]
expected_modules = sorted(PREFIX + Path(p).stem for p in added_lean + edited_lean)
modules = json.loads((HERE / "audit-modules.json").read_text())
assert sorted(modules) == expected_modules, (modules, expected_modules)
required = json.loads((HERE / "required-names.json").read_text())

# AtPrepare は補題の追加だけで、既存の行を消さない。
prep = git("diff", "-U0", B_WORK, "--", module_path("AtPrepare"))
assert not [l for l in prep.splitlines() if l.startswith("-") and not l.startswith("---")], "AtPrepare の行を消した"
added_names = re.findall(r"^\+(?:private )?theorem (\S+)", prep, re.M)
assert added_names == ["finishPreparation_public", "prepareCore_public", "AtPrepare.no_outsideScope"], added_names
diff = git("diff", "-U0", B_WORK, "--", *[module_path(m) for m in EDITED])

# 3. 既定ビルド。
build = args.tmp / "build.log"
text = build.read_text()
assert text.rstrip().endswith("exit=0"), "既定ビルドが失敗した"
assert "error:" not in text
jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", text)[1])
def warnings(log, m):
    return collections.Counter(re.sub(r"^warning: [^:]*:\d+:\d+: ", "", w) for w in re.findall(
        rf"^warning: Benitoite/Release/Refinement/{m}\.lean:\d+:\d+: .*$", log, re.M))
# 変えたモジュールの警告は、B_WORK の状態の既定ビルド（build0.log）にあった警告に限る。
start = (args.tmp / "build0.log").read_text()
warned = [m for m in NEW if warnings(text, m)] + [m for m in EDITED if warnings(text, m) - warnings(start, m)]
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
for name in [PREFIX + "AtPrepare.no_outsideScope", PREFIX + "finishPreparation_public", PREFIX + "prepareCore_public"]:
    assert any(t == name or (t.startswith("_private.") and t.endswith("." + name.split(".")[-1])) for t in targets), name
kinds = collections.Counter((m, k) for m, k, _, _ in decls)
private = sum(1 for _, _, _, n in decls if n.startswith("_private."))

# 5. 本番のソースの禁止の形。
for m in NEW:
    src = (ROOT / module_path(m)).read_text()
    assert not re.search(r"\bsorry\b|#eval|#check|#print|maxHeartbeats|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b", src), m
added_src = "\n".join(l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++"))
assert not re.search(r"\bsorry\b|#eval|maxHeartbeats|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d", added_src)
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
               "private": private, "sets": {",".join(k) or "(none)": v for k, v in sorted(sets.items())},
               "modules": per_module,
               "kinds": {f"{m} {k}": v for (m, k), v in sorted(kinds.items())}},
    "required": len(required),
    "sources": {m: digest(ROOT / module_path(m)) for m in NEW + EDITED},
}
(HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
print(json.dumps(summary, ensure_ascii=False, indent=1))
