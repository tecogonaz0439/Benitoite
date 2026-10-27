"""L20 の差分と公理依存を記録する。処理系の恒久的なテストではない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "2fd371c49190ab914c05963f83fdd23d833d6e80"
RANGE = "formal/Benitoite/Interval/Range.lean"
DOCS = {"docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"}

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def before(path):
    return git("show", f"{BASE}:{path}")

def declarations(data):
    # 匿名の独立例・namespace 境界は名前付き宣言の本文に含めない。
    source = re.sub(r"/\-.*?\-/", "", data.decode(), flags=re.S)
    starts = list(re.finditer(r"(?m)^(?:@\[[^\n]*\]\s+)?(?:inductive|structure|def|theorem|lemma|abbrev|example|end|namespace|mutual)\b[^\n]*", source))
    found = {}
    for i, match in enumerate(starts):
        named = re.match(r"(?:@\[[^\n]*\]\s+)?(?:inductive|structure|def|theorem|lemma|abbrev)\s+(\S+)", match.group())
        if named:
            end = starts[i + 1].start() if i + 1 < len(starts) else len(source)
            body = re.sub(r"(?m)--.*$", "", source[match.start():end]).strip()
            found[named.group(1)] = body
    return found

unchanged = []
for path in git("ls-files", "formal").decode().splitlines():
    if path != RANGE:
        assert (ROOT / path).read_bytes() == before(path), path
        unchanged.append(path)
old, current = declarations(before(RANGE)), declarations((ROOT / RANGE).read_bytes())
for name, body in old.items():
    assert current[name] == body, name
central = {}
for name in ("NormalSoundness", "WarningSoundness"):
    path = "formal/Benitoite/Interval/Eval.lean"
    source = (ROOT / path).read_text()
    start = source.index("def " + name)
    central[name] = sha(source[start:source.index("\n\n", start)].encode())
fixed = {}
for path in git("ls-files", "crates/benitoite/testdata/interval-budget", "formal/lakefile.toml").decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    fixed[path] = sha(data)
changed = git("diff", "--name-only", BASE).decode().splitlines()
assert set(changed) == {RANGE} | DOCS, changed
assert git("diff", BASE, "--", "crates") == b""
added = git("diff", BASE, "--", RANGE).decode()
assert not re.search(r"(?m)^\+(?!\+).*\b(?:sorry|admit|axiom|native_decide|implemented_by|extern)\b", added)
axioms = (OUT / "axioms.log").read_text()
deps = re.findall(r"depends on axioms: \[([^]]*)\]", axioms, re.S)
without = len(re.findall(r"does not depend on any axioms", axioms))
expected = len(re.findall(r"^#print axioms ", (OUT / "axioms.lean").read_text(), re.M))
assert len(deps) + without == expected, (len(deps), without, expected)
for names in deps:
    assert {n.strip() for n in names.split(",") if n.strip()} <= {"propext", "Classical.choice", "Quot.sound"}, names
subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
(OUT / "definition-diff.patch").write_text(added)
record = {
    "base": BASE, "head": git("rev-parse", "HEAD").decode().strip(),
    "changed_tracked": changed, "unchanged_formal_files": len(unchanged),
    "preserved_named_declarations_in_range": len(old), "added_declarations": sorted(current.keys() - old.keys()),
    "central_definition_sha256": central, "axiom_dependencies_checked": expected,
    "no_added_sorry_axiom_admit": True, "fixed_file_sha256": fixed,
    "final_inputs_sha256": {p: sha((ROOT / p).read_bytes()) for p in changed},
    "diff_numstat": git("diff", "--numstat", BASE).decode().splitlines(),
}
(OUT / "contract-check.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False, indent=2))
