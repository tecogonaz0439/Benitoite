# coding: utf-8
"""停止時の関係状態を開始版と照合する。git は読み取り照会だけに使う。"""
from pathlib import Path
import hashlib, json, re, subprocess
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "d1d706eaa3a181189b512057a5b3f08c110fe241"
def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)
def digest(value):
    return hashlib.sha256(value).hexdigest()
paths = git("ls-files", "formal", "crates/benitoite/testdata/interval-budget").decode().splitlines()
inputs = {}
theorems = 0
for path in paths:
    current = (ROOT / path).read_bytes()
    assert git("show", BASE + ":" + path) == current, path
    inputs[path] = digest(current)
    if path.endswith(".lean"):
        theorems += len(re.findall(r"^[ \t]*(?:@\[[^\n]*?\][ \t]*)?(?:(?:private|protected|noncomputable)[ \t]+)*(?:theorem|lemma) ", current.decode(), re.M))
# formal の未追跡入力もないことを確かめる。
assert git("ls-files", "--others", "--exclude-standard", "formal") == b""
diff = git("diff", "--name-only", BASE).decode().splitlines()
assert set(diff) == {"docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"}, diff
for path in diff:
    inputs[path] = digest((ROOT / path).read_bytes())
subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
record = {"base": BASE, "head": git("rev-parse", "HEAD").decode().strip(), "unchanged_formal_and_fixed_files": len(paths), "unchanged_named_theorems": theorems, "changed_tracked_files": diff, "input_sha256": inputs}
(OUT / "contract-check.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k:v for k,v in record.items() if k != "input_sha256"}, ensure_ascii=False))
