"""この作業の差分と仮定の点検。恒久的な処理系テストではない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "f41a35c3116d96862b832032c2d1bcb5efc02b68"
EDITED = {"formal/Benitoite/Interval/Environment.lean", "formal/Benitoite/Interval/Range.lean"}
DOCS = {"docs/design/01-spec/01-12-core-calculus.md",
        "docs/design/07-quality/07-04-formal-semantics.md"}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def before(path):
    return git("show", f"{BASE}:{path}")


def declarations(data):
    # 既存宣言に続く新しいコメントを本文の変更と数えない。
    text = re.sub(r"/\-.*?\-/", "", data.decode(), flags=re.S)
    starts = list(re.finditer(r"(?m)^(?:inductive|structure|def|theorem|lemma)\s+(\S+)", text))
    return {match.group(1): text[match.start():starts[i + 1].start()
            if i + 1 < len(starts) else text.index("\nend Benitoite.Interval", match.start())].strip()
            for i, match in enumerate(starts)}


unchanged, preserved, added = [], {}, {}
for path in git("ls-files", "formal").decode().splitlines():
    data = (ROOT / path).read_bytes()
    old = before(path)
    if path in EDITED:
        previous, current = declarations(old), declarations(data)
        for name, body in previous.items():
            assert current[name] == body, (path, name)
        preserved[path] = len(previous)
        added[path] = sorted(current.keys() - previous.keys())
    else:
        assert data == old, path
        unchanged.append(path)

central = {}
eval_path = "formal/Benitoite/Interval/Eval.lean"
for name in ("NormalSoundness", "WarningSoundness"):
    text = (ROOT / eval_path).read_text()
    start = text.index("def " + name)
    body = text[start:text.index("\n\n", start)]
    central[name] = sha(body.encode())

fixed = {}
for path in git("ls-files", "crates/benitoite/testdata/interval-budget",
                "formal/lakefile.toml").decode().splitlines():
    data = (ROOT / path).read_bytes()
    assert data == before(path), path
    fixed[path] = sha(data)

changed = git("diff", "--name-only", BASE).decode().splitlines()
assert set(changed) == EDITED | DOCS, changed
assert git("diff", BASE, "--", "crates") == b""
for path in EDITED:
    assert not re.search(r"\b(?:sorry|admit|axiom|native_decide|implemented_by|extern)\b|partial def",
                         (ROOT / path).read_text()), path
axioms = (OUT / "axioms.log").read_text()
dependencies = re.findall(r"depends on axioms: \[([^]]*)\]", axioms, re.S)
without = len(re.findall(r"does not depend on any axioms", axioms))
assert len(dependencies) + without == len(re.findall(r"^#print axioms ",
    (OUT / "axioms.lean").read_text(), re.M))
for names in dependencies:
    assert {name.strip() for name in names.split(",") if name.strip()} <= {
        "propext", "Classical.choice", "Quot.sound"}, names
subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
diff = git("diff", BASE, "--", *sorted(EDITED)).decode()
(OUT / "definition-diff.patch").write_text(diff)
record = {
    "base": BASE,
    "head": git("rev-parse", "HEAD").decode().strip(),
    "changed_tracked": changed,
    "unchanged_formal_files": len(unchanged),
    "preserved_declarations_in_edited_files": preserved,
    "added_declarations": added,
    "central_definition_sha256": central,
    "axiom_dependencies_checked": len(dependencies) + without,
    "no_added_sorry_axiom_admit": True,
    "fixed_file_sha256": fixed,
    "final_inputs_sha256": {p: sha((ROOT / p).read_bytes()) for p in changed},
}
print(json.dumps(record, ensure_ascii=False, indent=2))
