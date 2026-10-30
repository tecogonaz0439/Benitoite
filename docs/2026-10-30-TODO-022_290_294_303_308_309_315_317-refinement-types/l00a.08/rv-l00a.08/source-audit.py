#!/usr/bin/env python3
"""レビュー修正の入力と変更の範囲を照合する。"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
before = json.loads((HERE / "before.json").read_text())
allowed_changes = {
    "formal/Benitoite/Release/Refinement/Exchange.lean",
    "formal/Benitoite/Release/Refinement/OpenSubstitution.lean",
    "formal/Benitoite/Release/Refinement/RangeSubst.lean",
}
def info(path):
    data = path.read_bytes()
    return dict(path=str(path.relative_to(ROOT)), bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
inputs = [info(ROOT / x["path"]) for x in before["inputs"]]
changes = [b["path"] for a, b in zip(before["inputs"], inputs) if a != b]
assert set(changes) == allowed_changes, changes
for path in (ROOT / "formal/Benitoite/Release/Refinement").glob("*.lean"):
    assert not re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern|set_option)\b", path.read_text()), path
names = json.loads((HERE / "public-names.json").read_text())
for mod, expected in names["current"].items():
    prefix = "Benitoite.Release.Refinement." + ("OpenSubstitution." if mod == "OpenSubstitution" else "")
    source = (ROOT / "formal/Benitoite/Release/Refinement" / (mod + ".lean")).read_text()
    actual = [prefix + m[1] for m in re.finditer(r"^\s*(?:@\[[^\]]*\]\s*)?(?:noncomputable\s+)?(?:theorem|def|structure)\s+([^\s({:]+)", source, re.M)]
    assert actual == expected, mod
inputs += [info(HERE / x) for x in ["proof-audit.lean", "public-names.json", "run-checks.py", "source-audit.py"]]
record = dict(captured_at=datetime.now(timezone.utc).isoformat(), B_WORK=before["B_WORK"],
              changed_inputs=changes, new_public_declarations=names["added_by_review"], inputs=inputs)
result = HERE / "source-audit.json"
if result.exists():
    assert json.loads(result.read_text())["inputs"] == inputs, "inputs changed after snapshot"
    print("今回の検査入力と現在の入力が一致した。")
else:
    result.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print("照合を保存した。", len(inputs), "入力、変更は指定のLean 3ファイル。")
