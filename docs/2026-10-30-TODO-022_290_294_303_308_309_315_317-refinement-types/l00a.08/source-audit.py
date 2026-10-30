#!/usr/bin/env python3
"""入力のハッシュ、公開範囲以外の変更、公理を迂回する構文、既定importを照合する。"""
from datetime import datetime, timezone
from pathlib import Path
import gzip
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CHANGE = HERE.parent
PUBLIC = json.loads((HERE / "public-names.json").read_text())
def digest(data):
    return hashlib.sha256(data).hexdigest()

def file_info(path):
    data = path.read_bytes()
    return dict(path=str(path.relative_to(ROOT)), bytes=len(data), sha256=digest(data))

old = json.loads(gzip.decompress((CHANGE / "l00a.01b/inventory.json.gz").read_bytes()))
old_sources = [m["source"] for m in old["modules"]]
unchanged = []
for entry in old_sources:
    path = ROOT / entry["path"]
    if path.name == "Benitoite.lean" and path.parent == ROOT / "formal":
        continue
    assert digest(path.read_bytes()) == entry["sha256"], entry["path"]
    unchanged.append(entry["path"])
previous = json.loads((CHANGE / "l00a.06b/source-audit.json").read_text())
previous_hashes = {x["path"]: x["sha256"] for x in previous["inputs"]}
visibility_only = []
for mod, names in PUBLIC["exposed"].items():
    path = ROOT / "formal/Benitoite/Release/Refinement" / (mod + ".lean")
    restored = re.sub(r"\n\n/-!\n.*?\n-/", "", path.read_text(), count=1, flags=re.S)
    for name in names:
        pat = r"(?m)^(\s*)(noncomputable )?def " + re.escape(name) + r"(?=\s|\()"
        restored, n = re.subn(pat, lambda m: m[1] + "private " + (m[2] or "") + "def " + name, restored)
        assert n == 1, (mod, name, n)
    assert digest(restored.encode()) == previous_hashes[str(path.relative_to(ROOT))], mod
    visibility_only.append(str(path.relative_to(ROOT)))
for mod in ["Types", "Normalize", "Logic", "Syntax", "Typing"]:
    path = ROOT / "formal/Benitoite/Release/Refinement" / (mod + ".lean")
    assert digest(path.read_bytes()) == previous_hashes[str(path.relative_to(ROOT))], mod
aggregate = ROOT / "formal/Benitoite.lean"
restored_aggregate = aggregate.read_text().replace("\nimport Benitoite.Release.Refinement.OpenSubstitution", "")
assert digest(restored_aggregate.encode()) == previous_hashes["formal/Benitoite.lean"]
for relative in ["formal/lakefile.toml", "formal/lean-toolchain"]:
    assert digest((ROOT / relative).read_bytes()) == previous_hashes[relative], relative

sources = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
inputs = [file_info(p) for p in sources]
extra = [ROOT / "formal/lakefile.toml", ROOT / "formal/lean-toolchain", ROOT / "scripts/check.sh",
         CHANGE / "implementation-request.md", CHANGE / "plan.md", CHANGE / "l00a.06a/contracts.md"]
inputs += [file_info(p) for p in extra]
modules = {str(p.relative_to(ROOT / "formal")).removesuffix(".lean").replace("/", "."): p for p in sources}
imports = {m: re.findall(r"^import ([\w.]+)$", p.read_text(), re.M) for m, p in modules.items()}
reachable = set()
queue = ["Benitoite"]
while queue:
    m = queue.pop()
    if m in reachable:
        continue
    reachable.add(m)
    queue.extend(imports.get(m, []))
new_modules = ["Benitoite.Release.Refinement." + m for m in PUBLIC["added"]]
assert all(m in reachable for m in new_modules)
for path in (ROOT / "formal/Benitoite/Release/Refinement").glob("*.lean"):
    assert not re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|set_option)\b", path.read_text()), path
record = dict(captured_at=datetime.now(timezone.utc).isoformat(), B_WORK="22aaeb3cb1faf65264abad20cab8eb99ec3fcc81",
    old_sources_compared=len(old_sources), old_sources_unchanged_except_aggregate=unchanged,
    prior_parallel_modules_unchanged=["Types", "Normalize", "Logic", "Syntax", "Typing"],
    visibility_and_header_only=visibility_only, aggregate_only_added_import=True,
    toolchain_and_lakefile_unchanged=True, new_modules_in_default_import=new_modules,
    bypass_syntax_found=False, inputs=inputs)
result = HERE / "source-audit.json"
if result.exists():
    before = json.loads(result.read_text())
    assert before["inputs"] == record["inputs"], "source inputs changed after snapshot"
    print("記録済みの入力と現在の入力が一致した。")
else:
    result.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print("入力の照合を保存した。", len(inputs), "入力、", len(new_modules), "新モジュール。")
