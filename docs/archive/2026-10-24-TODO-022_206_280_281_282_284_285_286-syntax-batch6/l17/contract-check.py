"""開始版と今回の例・対応文書を照合する。恒久的なソース検査ではない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "5b491e3f549b505b58ece01f8953bbca8642b45f"
EXAMPLES = "formal/Benitoite/Interval/Examples.lean"
CORRESPONDENCE = "docs/design/07-quality/07-04-formal-semantics.md"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def old(path):
    return git("show", f"{BASE}:{path}")


def digest(data):
    return hashlib.sha256(data).hexdigest()


changed = git("diff", "--name-only", BASE).decode().splitlines()
assert set(changed) == {EXAMPLES, CORRESPONDENCE}, changed
formal = git("ls-files", "formal").decode().splitlines()
unchanged = 0
theorems = 0
for path in formal:
    if path == EXAMPLES:
        continue
    data = (ROOT / path).read_bytes()
    assert data == old(path), path
    unchanged += 1
    if path.endswith(".lean"):
        theorems += len(re.findall(
            rb"(?m)^(?:@\[[^\n]*\]\s*)?(?:private\s+)?(?:theorem|lemma)\s+", data))

# 旧例も、観察用の一分岐と追加例を除けば本文が完全に同じである。
before = old(EXAMPLES).decode()
after = (ROOT / EXAMPLES).read_text()
marker = "-- 型の上下限そのものから期待値を作らず、十進の境界を七種とも固定する。"
start = after.index(marker)
stop = after.index("end Benitoite.Interval.Examples", start)
restored = after[:start] + after[stop:]
restored = restored.replace("# 土台と七種の整数の評価・解析の独立例", "# 土台 C1 の評価と解析の独立例")
restored = restored.replace("  | .integer n => some (.integer64, n.toInt)\n", "")
assert restored == before, "既存の独立例の本文に追加以外の差がある"

central = {}
path = "formal/Benitoite/Interval/Eval.lean"
for name in ("NormalSoundness", "WarningSoundness"):
    def extract(data):
        start = data.index("def " + name)
        stop = data.index("\n\n", start)
        return data[start:stop]
    previous = extract(old(path).decode())
    current = extract((ROOT / path).read_text())
    assert previous == current, name
    central[name] = digest(current.encode())

fixed = ["formal/lakefile.toml"] + [
    f"crates/benitoite/testdata/interval-budget/{name}.tsv"
    for name in ("body", "whole", "summary")
]
hashes = {}
for path in fixed:
    data = (ROOT / path).read_bytes()
    assert data == old(path), path
    hashes[path] = digest(data)

before = old(CORRESPONDENCE).decode()
after = (ROOT / CORRESPONDENCE).read_text()
assert re.findall(r"^#+ .*$", before, re.M) == re.findall(r"^#+ .*$", after, re.M)
assert re.findall(r"```text\n.*?```", before, re.S) == re.findall(r"```text\n.*?```", after, re.S)
added = "\n".join(line[1:] for line in git("diff", "--unified=0", BASE, "--", "formal").decode().splitlines()
                  if line.startswith("+") and not line.startswith("+++"))
assert not re.search(r"\b(?:axiom|sorry|admit)\b", added)

axioms = re.findall(r"depends on axioms: \[([^]]*)\]", (OUT / "axioms.log").read_text(), re.S)
assert len(axioms) == 33, len(axioms)
for dependencies in axioms:
    assert {name.strip() for name in dependencies.split(",")} <= {
        "propext", "Classical.choice", "Quot.sound",
    }, dependencies

print(json.dumps({
    "base": BASE,
    "head": git("rev-parse", "HEAD").decode().strip(),
    "changed_tracked": changed,
    "unchanged_formal_files_except_examples": unchanged,
    "unchanged_named_theorems_and_lemmas_in_those_files": theorems,
    "existing_examples": "本文一致。観察用のInteger64分岐と追加例だけを除いた比較",
    "central_definition_sha256": central,
    "no_added_axiom_sorry_admit": True,
    "axiom_dependencies_checked": len(axioms),
    "document_headings_and_text_fences_unchanged": True,
    "fixed_file_sha256": hashes,
}, ensure_ascii=False, indent=2))
