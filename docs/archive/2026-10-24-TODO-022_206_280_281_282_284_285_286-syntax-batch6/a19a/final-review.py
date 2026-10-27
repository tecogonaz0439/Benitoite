#!/usr/bin/env python3
"""最終入力・固定表・検査の終了状態と、記録のリンクと伏せ字を点検する。"""

import ast
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "61e04c646797d045d8bf876800c2e8cba690db59"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


assert git("rev-parse", "HEAD").decode().strip() == BASE
assert git("branch", "--show-current").decode().strip() == "mod012/A19a"
assert not git("diff", "--cached")
assert not git("diff", BASE, "--", "formal", "Cargo.toml", "Cargo.lock", "fuzz",
               "deny.toml", "rust-toolchain.toml", "crates/benitoite/skill",
               "crates/benitoite/src/cli/tools/skill/bundle.rs",
               "crates/benitoite/tests/call_allocations.rs",
               "crates/benitoite/testdata/interval-budget")
git("diff", "--check")

hashes = json.loads((OUT / "work-inputs-sha256.json").read_text())
line_changes = {}
for name, digest in hashes.items():
    path = ROOT / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, name
    old = subprocess.run(["git", "show", BASE + ":" + name], cwd=ROOT,
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    diff = list(difflib.unified_diff(old.stdout.decode().splitlines(), path.read_text().splitlines()))
    line_changes[name] = {
        "added": sum(line.startswith("+") and not line.startswith("+++") for line in diff),
        "deleted": sum(line.startswith("-") and not line.startswith("---") for line in diff),
    }
fixed = json.loads((OUT / "fixed-inputs-sha256.json").read_text())
for name, info in fixed.items():
    data = (ROOT / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == info["sha256"]
    assert data == git("show", BASE + ":" + name)

for path in OUT.glob("*.py"):
    ast.parse(path.read_text(), filename=path.name)

for target in re.findall(r"\]\(([^)]+)\)", (OUT / "results.md").read_text()):
    assert (OUT / target.split("#")[0]).exists(), target

prefixes = [str(ROOT), str(Path.home()), tempfile.gettempdir(),
            str(Path("/") / "private" / "tmp"), str(Path("/") / "tmp") + os.sep]
checked = 0
for path in OUT.rglob("*"):
    if path.suffix in {".py", ".md", ".log", ".json"}:
        contents = [(path.name, path.read_text())]
    elif path.suffix == ".zip":
        with zipfile.ZipFile(path) as archive:
            contents = [(name, archive.read(name).decode()) for name in archive.namelist()]
    else:
        continue
    for name, content in contents:
        assert not any(prefix in content for prefix in prefixes), (path.name, name)
        checked += 1

log = (OUT / "work-final.log").read_text()
status = json.loads((OUT / "work-final-check.json").read_text())
assert status["exit"] == 0
outer = json.loads((OUT / "work-final.json").read_text())
rss = re.search(r"(\d+)\s+maximum resident set size", log)
if rss:
    memory = {"bytes": int(rss[1])}
else:
    assert "sysctl kern.clockrate: Operation not permitted" in log
    memory = "unavailable: sandbox denied sysctl kern.clockrate"
assert outer["exit"] == 0 or (outer["exit"] == 1 and rss is None)
units = list(dict.fromkeys(re.findall(r"^== (\w+)$", log, re.MULTILINE)))
assert units == ["fmt", "lint_default", "lib_default", "tests_related", "source_rules",
                 "skill_generated", "spec_tally"]
matches = re.findall(r"test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored", log)
assert matches and all(int(failed) == 0 for _, failed, _ in matches)
targets = re.findall(r"Running tests/([^ ]+)\.rs", log)
assert len(matches) == len(targets) + 1
assert (OUT / "reference-comparison.json").exists()
assert all(row["identical"] for row in json.loads((OUT / "reference-comparison.json").read_text()).values())

report = {
    "base": BASE, "head": BASE, "branch": "mod012/A19a", "index_unchanged": True,
    "work_inputs_unchanged": len(hashes), "fixed_inputs_unchanged": len(fixed),
    "formal_dependencies_generated_skill_unchanged": True, "diff_check": "passed",
    "records_redacted": checked, "python_syntax": "passed", "result_links": "passed",
    "line_changes": line_changes, "work_units": units, "work_check_exit": status["exit"],
    "work_seconds": status["seconds"], "time_exit": outer["exit"],
    "lib": {"passed": int(matches[0][0]), "ignored": int(matches[0][2])},
    "integration": {"targets": len(targets), "passed": sum(int(row[0]) for row in matches[1:]),
                    "ignored": sum(int(row[2]) for row in matches[1:])},
    "maximum_resident_set_size": memory,
}
(OUT / "final-review.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key != "line_changes"}, ensure_ascii=False))
