"""旧定義・旧定理を含む全ファイルと固定表を開始版に照合する。git は読み取りだけ。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "d1d706eaa3a181189b512057a5b3f08c110fe241"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


paths = git("ls-files", "formal", "crates/benitoite/testdata/interval-budget").decode().splitlines()
allowed = {"formal/Benitoite.lean", "formal/Benitoite/Interval/SyntacticReachExamples.lean"}
unchanged, changed, hashes = [], [], {}
theorems = 0
for path in paths:
    previous = git("show", BASE + ":" + path)
    current = (ROOT / path).read_bytes()
    if previous == current:
        unchanged.append(path)
    else:
        assert path in allowed, path
        changed.append(path)
        # この二ファイルには既存の名前付き定理・定義の変更を置かない。
        if path.endswith("SyntacticReachExamples.lean"):
            previous_source = previous.decode()
            current_source = current.decode().replace("import Benitoite.Interval.CallReachWhole\n", "")
            original_prefix = previous_source[:previous_source.rindex("end Benitoite.Interval.BudgetAnalysis")]
            assert current_source.startswith(original_prefix), path
        else:
            lines = [line for line in current.decode().splitlines()
                     if line not in {"import Benitoite.Interval." + name for name in
                                     ["CallReach", "CallTables", "BudgetCallReach", "CallReachSound",
                                      "CallReachIndependent", "CallReachWhole"]}]
            assert "\n".join(lines) + "\n" == previous.decode(), path
    if path.endswith(".lean"):
        theorems += len(re.findall(r"^[ \t]*(?:@\[[^\n]*?\][ \t]*)?(?:(?:private|protected|noncomputable)[ \t]+)*(?:theorem|lemma) ", previous.decode(), re.M))
    hashes[path] = hashlib.sha256(current).hexdigest()
new = git("ls-files", "--others", "--exclude-standard", "formal").decode().splitlines()
expected_new = {"formal/Benitoite/Interval/" + name + ".lean" for name in
                ["CallReach", "CallTables", "BudgetCallReach", "CallReachSound", "CallReachIndependent", "CallReachWhole"]}
assert set(new) == expected_new, new
for path in new:
    value = (ROOT / path).read_bytes()
    assert not re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe)\b", value.decode()), path
    hashes[path] = hashlib.sha256(value).hexdigest()
diff = git("diff", "--name-only", BASE).decode().splitlines()
assert set(diff) == allowed | {"docs/design/01-spec/01-12-core-calculus.md",
                              "docs/design/07-quality/07-04-formal-semantics.md"}, diff
for path in diff:
    hashes[path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
record = {"base": BASE, "head": git("rev-parse", "HEAD").decode().strip(),
          "branch": git("branch", "--show-current").decode().strip(),
          "unchanged_files": unchanged, "changed_tracked_files": changed,
          "unchanged_named_theorems": theorems, "new_formal_files": new,
          "input_sha256": hashes}
(OUT / "resume-contract-check.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({key: value for key, value in record.items()
                  if key not in ("input_sha256", "unchanged_files")}, ensure_ascii=False))
