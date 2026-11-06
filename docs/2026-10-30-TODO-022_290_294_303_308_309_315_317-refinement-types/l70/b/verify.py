# -*- coding: utf-8 -*-
"""群 B（主定理）の記録と本番の対応を照合する群末の台本。

1. B_WORK からの変更の範囲。変えたのは formal/Benitoite/Release/Refinement のモジュール・根の import・07-04 だけで、
   旧 Release・旧 Surface・Core・交換・処理系・計画と前段の記録を変えない。未追跡は足したモジュールと本ディレクトリだけ。
2. 既存のモジュールの変更は、名指しした宣言の `private` を外すことと、取りまとめが認めた `StepTargetStatement` の
   前提の追加だけである。
3. 足したモジュールが根の既定 import に一度ずつ現れ、根の既存の行を変えない。監査の対象のモジュール（足したものと
   変えたもの）を差分から作り直して照合する。
4. 既定ビルドの生の出力（終了0、エラーなし、足したモジュールの警告なし、変えたモジュールの警告は開始状態の記録
   （build0.log）にあったものに限る、ジョブ数）。変えたモジュールの警告は、そのモジュールを作り直したビルドの記録から読む。
5. 公理監査の生の出力（sorryAx と未知の公理なし、対象の数と重複なし、モジュールごとの件数、必須の名前）。
6. 足したモジュールと足した行に sorry・#eval・#check・maxHeartbeats・maxRecDepth・工程の ID がない。
7. 記録の大きさ（各 100 KB 以下）、手元の絶対パスと docs/todo へのリンクがない。
結果を audit-summary.json に書く（生の出力は大きさと SHA-256 だけを残す）。
使い方: python3 verify.py --tmp <一時領域>（build0.log・rebuild*.log・build.log・axioms.log・counterexample.log を置く）"""
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
DESIGN = ["docs/design/07-quality/07-04-formal-semantics.md"]
ALLOWED_AXIOMS = {"propext", "Quot.sound", "Classical.choice"}
EDITABLE = "formal/Benitoite/Release/Refinement/"
# 既存のモジュールで private を外した宣言。
UNPRIVATE = {
    "formal/Benitoite/Release/Refinement/Step.lean": {"def stepRun", "def stepMatch"},
    "formal/Benitoite/Release/Refinement/BuilderStateLeaves.lean": {
        "theorem builder_view_operation", "theorem builder_operation_inputs",
        "theorem builder_local_inv", "theorem builder_cell_convert"},
}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()


def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], check=True, capture_output=True, text=True).stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def module_of(path):
    return path[len("formal/"):-len(".lean")].replace("/", ".")


# 1. 変更の範囲。
changed = sorted(set(git("diff", "--name-only", "-z", B_WORK, "--").split("\0")) - {""})
# 取りまとめが認めた言明の変更（再開1）: StepTargetStatement に整形式と型付けの前提を加えた。
STATEMENTS = "formal/Benitoite/Release/Refinement/MainStatements.lean"
assert all(p in DESIGN or p == "formal/Benitoite.lean" or p in UNPRIVATE or p == STATEMENTS
           for p in changed), changed
statement_diff = git("diff", "-U0", B_WORK, "--", STATEMENTS)
statement_plus = [l[1:] for l in statement_diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
statement_minus = [l[1:] for l in statement_diff.splitlines() if l.startswith("-") and not l.startswith("---")]
assert statement_minus == ["σ の下で許す。 -/",
                           "  P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P → σ.Valid →"], statement_minus
assert statement_plus == ["σ の下で許す。事象の実引数の型付けを閉じた view から得るので、プログラムの整形式と型付けを前提に読む。 -/",
                          "  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P → σ.Valid →"], statement_plus
own = str(HERE.relative_to(ROOT))
untracked = sorted(set(git("ls-files", "--others", "--exclude-standard", "-z").split("\0")) - {""})
added_lean = [p for p in untracked if p.startswith("formal/") and p.endswith(".lean")]
REVIEW = str((HERE.parents[1] / "reviews/RV-L70.b.md").relative_to(ROOT))
assert all(p.startswith(own + "/") or p == REVIEW or (p.startswith(EDITABLE) and p.endswith(".lean"))
           for p in untracked), untracked
NEW = sorted(module_of(p) for p in added_lean)
EDITED = sorted(module_of(p) for p in changed if p in UNPRIVATE or p == STATEMENTS)

# 2. 既存のモジュールの変更は private を外すことだけ。
unprivated = {}
for path, decls in UNPRIVATE.items():
    diff = git("diff", "-U0", B_WORK, "--", path)
    minus = [l[1:] for l in diff.splitlines() if l.startswith("-") and not l.startswith("---")]
    plus = [l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    assert [l[len("private "):] for l in minus] == plus, (path, minus, plus)
    found = {" ".join(l.split()[:2]) for l in plus}
    assert found == decls, (path, found)
    unprivated[module_of(path)] = sorted(decls)

# 3. 根の import と監査の対象。
root = (ROOT / "formal/Benitoite.lean").read_text()
base_root = git("show", f"{B_WORK}:formal/Benitoite.lean")
root_diff = git("diff", "-U0", B_WORK, "--", "formal/Benitoite.lean")
assert not [l for l in root_diff.splitlines() if l.startswith("-") and not l.startswith("---")]
inserted = [l[len("+import "):] for l in root_diff.splitlines() if l.startswith("+import ")]
assert sorted(inserted) == NEW and len(inserted) == len(set(inserted)), (inserted, NEW)
assert all(root.count(f"import {m}\n") == 1 for m in NEW)
assert [l for l in root.splitlines() if l not in {f"import {m}" for m in NEW}] == base_root.splitlines()
modules = json.loads((HERE / "audit-modules.json").read_text())
assert sorted(modules) == sorted(NEW + EDITED), (modules, NEW + EDITED)
required = json.loads((HERE / "required-names.json").read_text())

# 4. 既定ビルド。
build = args.tmp / "build.log"
text = build.read_text()
assert text.rstrip().endswith("exit=0"), "既定ビルドが失敗した"
assert "error:" not in text
jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", text)[1])


def warnings(log, m):
    path = m.replace(".", "/")
    return collections.Counter(re.sub(r"^warning: [^:]*:\d+:\d+: ", "", w) for w in re.findall(
        rf"^warning: {re.escape(path)}\.lean:\d+:\d+: .*$", log, re.M))


start = (args.tmp / "build0.log").read_text()
rebuilds = [p.read_text() for p in sorted(args.tmp.glob("rebuild*.log"))]
assert rebuilds and all(r.rstrip().endswith("exit=0") and "error:" not in r for r in rebuilds)
for m in EDITED:
    assert any(f"Built {m} " in r for r in rebuilds + [text]), m
warned = [m for m in NEW if warnings(text, m) or any(warnings(r, m) for r in rebuilds)]
warned += [m for m in EDITED if any(warnings(r, m) - warnings(start, m) for r in rebuilds + [text])]
assert not warned, warned

# 5. 公理監査。
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

# 6. 本番のソースの禁止の形。
FORBIDDEN = r"\bsorry\b|#eval|#check|#print|maxHeartbeats|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b"
for p in added_lean:
    src = (ROOT / p).read_text()
    assert not re.search(FORBIDDEN, src), p
design_diff = git("diff", "-U0", B_WORK, "--", *DESIGN)
assert not re.search(r"\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|docs/todo|改造", "\n".join(
    l for l in design_diff.splitlines() if l.startswith("+")))

# 反例の試行（既定ビルドの外）の検査の記録。
counter = args.tmp / "counterexample.log"
counter_text = counter.read_text()
assert "error" not in counter_text
assert re.search(r"not_effect_soundness' depends on axioms: \[propext,\s*Classical.choice,\s*Quot.sound\]", counter_text)

# 7. 記録。
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
    "unprivated": unprivated,
    "build": {"jobs": jobs, "bytes": build.stat().st_size, "sha256": digest(build)},
    "rebuilds": [{"bytes": len(r.encode()), "sha256": hashlib.sha256(r.encode()).hexdigest()} for r in rebuilds],
    "axioms": {"bytes": log.stat().st_size, "sha256": digest(log), "targets": len(targets),
               "new_module_declarations": new_count, "private": private,
               "sets": {",".join(k) or "(none)": v for k, v in sorted(sets.items())},
               "modules": per_module,
               "kinds": {f"{m} {k}": v for (m, k), v in sorted(kinds.items())}},
    "required": len(required),
    "counterexample": {"source_sha256": digest(HERE / "effect-counterexample.lean"),
                       "log_bytes": counter.stat().st_size, "log_sha256": digest(counter)},
    "sources": {m: digest(ROOT / ("formal/" + m.replace(".", "/") + ".lean")) for m in NEW + EDITED},
}
(HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
print(json.dumps(summary, ensure_ascii=False, indent=1))
