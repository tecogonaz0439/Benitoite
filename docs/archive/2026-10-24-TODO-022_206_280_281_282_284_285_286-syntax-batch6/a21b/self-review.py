"""検査対象の不変、結果の件数、記録のパスを最終点検する。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
BASE = "c52acdd1bd1da5a15b2d56e771629c11e7e45f20"


def main():
    hashes = json.loads((HERE / "work-final-inputs-sha256.json").read_text())
    assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
               for path, digest in hashes.items())
    initial = json.loads((HERE / "work-inputs-sha256.json").read_text())
    test_path = "crates/benitoite/tests/cli_process.rs"
    before_comments = (ROOT / test_path).read_text().replace(
        "// 関門: 内部候補の検査では届かない、実 CLI の W0404 の発行・位置・由来・",
        "// 関門: A19 の候補の検査では届かない、実 CLI の W0404 の発行・位置・由来・").replace(
        "// 内部候補の検査と異なり、旧定数警告と新診断の統合後の出力を確かめる。",
        "// A19 の内部候補の検査と異なり、旧定数警告と新診断の統合後の出力を確かめる。")
    assert hashlib.sha256(before_comments.encode()).hexdigest() == initial[test_path]
    assert all(hashes[path] == digest for path, digest in initial.items() if path != test_path)
    for stem in ["width-bits-s8-invalid", "width-bits-u64-invalid"]:
        path = f"crates/benitoite/testdata/stdlib/{stem}.diag.json"
        old = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT, text=True)
        warning, remainder = (ROOT / path).read_text().split("\n", 1)
        assert json.loads(warning)["code"] == "W0404"
        assert remainder == old
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", BASE, "--"], cwd=ROOT, text=True).splitlines()
    assert sorted(changed) == sorted([
        "crates/benitoite/src/typeck/interval/diagnostics.rs",
        "crates/benitoite/tests/cli_process.rs",
        "crates/benitoite/testdata/stdlib/width-bits-s8-invalid.diag.json",
        "crates/benitoite/testdata/stdlib/width-bits-u64-invalid.diag.json",
    ]), changed
    subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
    for path in HERE.glob("*.py"):
        ast.parse(path.read_text(), filename=path.name)
    for path in HERE.iterdir():
        if path.is_file() and path.suffix != ".py":
            content = path.read_text()
            assert not re.search(r"/Users/|/(?:private/)?var/folders/|/private/tmp/|(?<![A-Za-z])/tmp/", content), path.name
    first_log = (HERE / "work.log").read_text()
    log = (HERE / "work-final.log").read_text()
    assert json.loads((HERE / "work-check.json").read_text())["exit"] == 1
    assert json.loads((HERE / "work-final-check.json").read_text())["exit"] == 0
    units = list(dict.fromkeys(re.findall(
        r"^== (fmt|tests_related|source_rules|skill_generated|spec_tally)$", log, re.M)))
    assert units == [
        "fmt", "tests_related", "source_rules", "skill_generated", "spec_tally"]
    pattern = r"test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;"
    lib = re.findall(pattern, first_log.split("== lib_default\n", 1)[1].split("== tests_related\n", 1)[0])
    assert len(lib) == 1
    integration = log.split("== tests_related\n", 1)[1].split("== source_rules\n", 1)[0]
    counts = re.findall(pattern, integration)
    targets = re.findall(r"Running tests/(\S+)\.rs", integration)
    assert len(counts) == len(targets) == 40
    record = {"lib": list(map(int, lib[0])),
              "integration": {target: list(map(int, count))
                              for target, count in zip(targets, counts)},
              "integration_total": [sum(int(count[i]) for count in counts) for i in range(3)]}
    (HERE / "work-counts.json").write_text(json.dumps(record, indent=2) + "\n")
    review = {"input_hashes_unchanged": True, "tracked_changes_limited": changed,
              "python_syntax": "ok", "local_paths_redacted": True,
              "diff_check": "ok", "initial_work_exit": 1, "final_work_exit": 0,
              "successful_units_across_runs": 7,
              "source_since_initial_work": "two test comments only",
              "existing_runtime_expectations": "preserved byte for byte",
              "call_allocations": record["integration"]["call_allocations"]}
    (HERE / "self-review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
