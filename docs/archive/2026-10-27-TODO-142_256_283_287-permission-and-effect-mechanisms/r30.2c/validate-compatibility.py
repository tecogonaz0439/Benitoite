"""表示の全バイトと公開宣言を開始版へ照合し、根拠を保存する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools/bench/compare"))
from run import execute

base = "42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab"
stdlib = "crates/benitoite/src/prelude/stdlib/"
old_scope = subprocess.check_output(["git", "show", f"{base}:{stdlib}Scope.bnt"], text=True)
new_scope = (ROOT / stdlib / "Scope.bnt").read_text()
old_trait = subprocess.check_output(["git", "show", f"{base}:{stdlib}Trait.bnt"], text=True)
new_trait = (ROOT / stdlib / "Trait.bnt").read_text()
start = old_scope.index("\n// ", old_scope.index("function stringError"))
moved = old_scope[start+1:].replace("Trait.Show", "Show").replace("ScopeError", "Scope.ScopeError")
assert new_scope == old_scope[:start].replace("\nimport Benitoite.Trait\n", "").rstrip() + "\n"
assert new_trait == old_trait.replace("\n\n", "\n\nimport Benitoite.Unofficial.Scope\n\n", 1).replace("// Show\n", "// Show\n\n" + moved, 1)

record = dict(base=base, scope_public_declarations_and_bodies_unchanged=True,
              show_and_helpers_only_qualification_changed=True, outputs={})
for state in ("before", "after"):
    result = execute([str(ROOT / "target/r30.2c" / state / "benitoite"), "run", "--diagnostics=json", str(HERE / "scope-show.bnt")], 30)
    assert result["status"] == 0 and result["stderr"] == "", result
    data = result["stdout"].encode()
    (HERE / f"scope-show-{state}.txt").write_bytes(data)
    record["outputs"][state] = dict(status=result["status"], bytes=len(data), lines=len(data.splitlines()),
                                     sha256=hashlib.sha256(data).hexdigest(), seconds=result["seconds"])
assert (HERE / "scope-show-before.txt").read_bytes() == (HERE / "scope-show-after.txt").read_bytes()
assert b"unexpected success" not in (HERE / "scope-show-after.txt").read_bytes()
record["byte_identical"] = True
(HERE / "show-compatibility.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
