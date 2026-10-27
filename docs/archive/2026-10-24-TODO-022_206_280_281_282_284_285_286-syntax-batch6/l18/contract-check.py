"""L18 の一回限りの差分点検。処理系の恒久的なテストではない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "d2d9954264daea806db0bf202449938bd1dd0291"
EVAL = "formal/Benitoite/Interval/Eval.lean"
RANGE = "formal/Benitoite/Interval/Range.lean"
IMPORTS = "formal/Benitoite.lean"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def before(path):
    return git("show", f"{BASE}:{path}")


def sha(data):
    return hashlib.sha256(data).hexdigest()


previous = before(EVAL).decode()
current = (ROOT / EVAL).read_text()
start = current.index("  -- 小モデルの Int は言語の値域より広い。")
stop = current.index("  | domainNormal", start)
assert current[:start] + current[stop:] == previous
assert (ROOT / IMPORTS).read_text().replace("import Benitoite.Interval.Range\n", "") == before(IMPORTS).decode()
unchanged = []
theorem_count = 0
for path in git("ls-files", "formal").decode().splitlines():
    if path in (EVAL, IMPORTS):
        continue
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    unchanged.append(path)
    if path.endswith(".lean"):
        theorem_count += len(re.findall(rb"(?m)^(?:@\[[^\n]*\]\s*)?(?:private\s+)?(?:theorem|lemma)\s+", data))

central = {}
for name in ("NormalSoundness", "WarningSoundness"):
    def extract(data):
        start = data.index("def " + name)
        return data[start:data.index("\n\n", start)]
    assert extract(previous) == extract(current)
    central[name] = sha(extract(current).encode())

fixed = {}
for path in git("ls-files", "crates/benitoite/testdata/interval-budget", "formal/lakefile.toml").decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    fixed[path] = sha(data)

new_lean = (ROOT / RANGE).read_text() + current[start:stop]
assert not re.search(r"\b(?:sorry|admit|axiom|native_decide|implemented_by|extern)\b|partial def", new_lean)
axiom_text = (OUT / "axioms.log").read_text()
dependencies = re.findall(r"depends on axioms: \[([^]]*)\]", axiom_text, re.S)
without_axioms = len(re.findall(r"does not depend on any axioms", axiom_text))
assert len(dependencies) + without_axioms == len(re.findall(r"^#print axioms ", (OUT / "axioms.lean").read_text(), re.M))
for names in dependencies:
    assert {name.strip() for name in names.split(",") if name.strip()} <= {
        "propext", "Classical.choice", "Quot.sound"}, names

changed = git("diff", "--name-only", BASE).decode().splitlines()
assert set(changed) == {EVAL, IMPORTS,
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md"}, changed
assert git("diff", BASE, "--", "crates") == b""
subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
record = {
    "base": BASE,
    "head": git("rev-parse", "HEAD").decode().strip(),
    "changed_tracked": changed,
    "new_lean_module": RANGE,
    "eval_change": "EvalStandard の3構成子の追加だけ。既存の全宣言・証明本体が一致",
    "unchanged_formal_files": len(unchanged),
    "unchanged_named_theorems_in_those_files": theorem_count,
    "central_definition_sha256": central,
    "axiom_dependencies_checked": len(dependencies) + without_axioms,
    "no_added_sorry_axiom_admit": True,
    "fixed_file_sha256": fixed,
    "final_inputs_sha256": {path: sha((ROOT / path).read_bytes()) for path in changed + [RANGE]},
}
print(json.dumps(record, ensure_ascii=False, indent=2))
