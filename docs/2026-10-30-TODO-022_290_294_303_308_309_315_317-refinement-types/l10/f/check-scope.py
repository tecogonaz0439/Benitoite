"""担当差分と改名の同一性、仕様の text ブロックを git なしで照合する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sha = lambda data: hashlib.sha256(data).hexdigest()
def read_parts(name):
    index = json.loads((HERE / name).read_text())
    return {k: v for part in index["parts"] for k, v in json.loads((HERE / part).read_text()).items()}

original = read_parts("before-sha256.json")
before = read_parts("review-before-sha256.json")
allowed = {
    "formal/Benitoite/Release/Refinement/LegacyInput.lean",
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
}
changed = [p for p, h in before.items() if not p.endswith("/reviews/RV-L10-request.md") and sha((ROOT / p).read_bytes()) != h]
assert set(changed) == allowed, changed

for name in ["formal/Benitoite/Interval/Budget.lean", "formal/Benitoite/Surface/ScopeState.lean"]:
    old = (ROOT / name).read_text().replace("checkLimit", "admit")
    assert sha(old.encode()) == original[name], name

# 今回の01-12の追記は本文の一文だけであり、textブロックは変えない。
name = "docs/design/01-spec/01-12-core-calculus.md"
current = (ROOT / name).read_text()
addition = " 操作の宣言の入力は、辞書の添字が型パラメータの個数未満であり、写した引数列の先頭が宣言した辞書型の列と一致することも要求する。実装の辞書型の value kind は各 LegacyTypeInput から取り出す。"
assert current.count(addition) == 1
old = current.replace(addition, "")
assert sha(old.encode()) == before[name], "01-12に今回の一文のほかの差分がある"
blocks = lambda s: re.findall(r"^```text\s*\n(.*?)^```", s, flags=re.M | re.S)
assert blocks(old) == blocks(current)

# 本番の Lean の旧名は二つの宣言とその補題から全て除いた。
old_readers = []
for p in (ROOT / "formal/Benitoite").rglob("*.lean"):
    for i, line in enumerate(p.read_text().splitlines(), 1):
        if re.search(r"\badmit(?=\b|_)", line):
            old_readers.append({"file": str(p.relative_to(ROOT)), "line": i})
assert not old_readers, old_readers

report = {
    "changed_protected_files": changed,
    "other_protected_files_unchanged": len(before) - len(changed) - 1,
    "authorized_request_update": "RV-L10-request.md",
    "rename_only_lean_files": ["formal/Benitoite/Interval/Budget.lean", "formal/Benitoite/Surface/ScopeState.lean"],
    "spec_text_blocks_unchanged": True,
    "spec_text_block_count": len(blocks(current)),
    "old_lean_readers": old_readers,
    "plan_detail_review_original_rv_runtime_unchanged": True,
    "note": "今回の再開の変更はLegacyInputと二章だけ。初回からの改名は元の開始時とも照合。既存レビュー依頼の更新は別に許可された範囲である。",
}
(HERE / "scope-check.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False))
