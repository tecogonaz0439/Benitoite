# -*- coding: utf-8 -*-
"""群 F1（射影形だけを表す host の条件・At の pattern と対象の起点の違い・種類 host の範囲の変数）の記録と本番の
対応を照合する群末の台本。

1. B_WORK からの変更の範囲。変えたのは根の import と 07-04 だけで、足したのは Refinement の三つのモジュールと
   本ディレクトリだけである。既存のモジュール・旧 Release・旧 Surface・Core・処理系・計画と前段の記録を変えない。
2. 足したモジュールが根の既定 import に一度ずつ現れ、既存の行を変えていない。監査の対象のモジュールは足したモジュール
   と一致する。根のほかに足したモジュールを import するファイルがない（型付け・網羅性・範囲の所属の定義は足した
   判定を読めない）。
3. 既定ビルドの生の出力（終了0、エラーなし、足したモジュールの警告なし、ジョブ数）。
4. 公理監査の生の出力（sorryAx と未知の公理なし、対象の数と重複なし、モジュールごとの件数、必須の名前）。必須の名前の
   完全な署名を signatures.md に書き出す。
5. 足したモジュールに sorry・#eval・#check・#print・maxHeartbeats・maxRecDepth・工程の ID がない。07-04 の足した行に
   工程の ID・docs/todo・改造の語がない。
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
DESIGN = ["docs/design/07-quality/07-04-formal-semantics.md"]
ALLOWED_AXIOMS = {"propext", "Quot.sound", "Classical.choice"}
NEW_FILES = sorted(f"formal/Benitoite/Release/Refinement/{m}.lean"
                   for m in ("MappedHostPatterns", "PathBaseDifference", "HostRangeParams"))

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
assert changed == sorted(DESIGN + ["formal/Benitoite.lean"]), changed
own = str(HERE.relative_to(ROOT))
untracked = sorted(set(git("ls-files", "--others", "--exclude-standard", "-z").split("\0")) - {""})
REVIEW = str((HERE.parents[1] / "reviews/RV-L70.f1.md").relative_to(ROOT))
assert all(p.startswith(own + "/") or p == REVIEW or p in NEW_FILES for p in untracked), untracked
assert all(p in untracked for p in NEW_FILES), untracked
NEW = sorted(module_of(p) for p in NEW_FILES)

# 2. 根の import・監査の対象・足したモジュールの読者。
root = (ROOT / "formal/Benitoite.lean").read_text()
base_root = git("show", f"{B_WORK}:formal/Benitoite.lean")
assert root.startswith(base_root), "根の import の既存の行を変えた"
appended = re.findall(r"^import (\S+)$", root[len(base_root):], re.M)
assert sorted(appended) == NEW and len(appended) == len(set(appended)), (appended, NEW)
modules = json.loads((HERE / "audit-modules.json").read_text())
assert sorted(modules) == NEW, (modules, NEW)
required = json.loads((HERE / "required-names.json").read_text())
importers = []
for path in sorted((ROOT / "formal").rglob("*.lean")):
    rel = str(path.relative_to(ROOT))
    if "/.lake/" in rel or rel == "formal/Benitoite.lean":
        continue
    for m in NEW:
        if re.search(rf"^import {re.escape(m)}$", path.read_text(), re.M):
            importers.append((rel, m))
assert not importers, importers

# 3. 既定ビルド。
build = args.tmp / "build.log"
text = build.read_text()
assert text.rstrip().endswith("exit=0"), "既定ビルドが失敗した"
assert "error:" not in text
jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", text)[1])
warned = [m for m in NEW if re.search(rf"^warning: {re.escape(m.replace('.', '/'))}\.lean:", text, re.M)]
assert not warned, warned
built = sorted(re.findall(r"Built (Benitoite\.Release\.Refinement\.\S+)", text))
assert set(NEW) <= set(built), built

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
signatures = re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)\nSIGNATURE_END \2$", audit, re.M | re.S)
assert sorted(n for _, n, _, _ in signatures) == sorted(required)
lines = ["# 群 F1 の必須の宣言の署名", "",
         "公理監査（axioms.lean）の生の出力から verify.py が書き出した。名前の接頭辞 `Benitoite.Release.Refinement.` を省く。", ""]
for m, n, line, sig in sorted(signatures, key=lambda x: (x[0], int(x[2]))):
    short = n.removeprefix("Benitoite.Release.Refinement.")
    body = sig.replace("Benitoite.Release.Refinement.", "")
    lines += [f"## `{short}`", "", f"{m}、{line}行。", "", "```lean", body.strip(), "```", ""]
(HERE / "signatures.md").write_text("\n".join(lines))

# 5. 本番のソースの禁止の形。
FORBIDDEN = r"\bsorry\b|#eval|#check|#print|maxHeartbeats|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|TODO-\d"
for p in NEW_FILES:
    assert not re.search(FORBIDDEN, (ROOT / p).read_text()), p
design_diff = git("diff", "-U0", B_WORK, "--", *DESIGN)
added_design = [l for l in design_diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
removed_design = [l for l in design_diff.splitlines() if l.startswith("-") and not l.startswith("---")]
assert not removed_design, removed_design
assert not re.search(r"\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b|docs/todo|改造|TODO-\d", "\n".join(added_design))

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
    "importers_of_new_modules": importers,
    "build": {"jobs": jobs, "bytes": build.stat().st_size, "sha256": digest(build)},
    "axioms": {"bytes": log.stat().st_size, "sha256": digest(log), "targets": len(targets), "private": private,
               "sets": {",".join(k) or "(none)": v for k, v in sorted(sets.items())},
               "modules": per_module,
               "kinds": {f"{m} {k}": v for (m, k), v in sorted(kinds.items())}},
    "required": len(required),
    "signatures": {"bytes": (HERE / "signatures.md").stat().st_size, "sha256": digest(HERE / "signatures.md")},
    "sources": {m: digest(ROOT / ("formal/" + m.replace(".", "/") + ".lean")) for m in NEW},
    "design": {p: digest(ROOT / p) for p in DESIGN},
}
(HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1) + "\n")
print(json.dumps(summary, ensure_ascii=False, indent=1))
