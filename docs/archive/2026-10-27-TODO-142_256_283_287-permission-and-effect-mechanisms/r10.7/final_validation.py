"""W-R の件数、同じ状態の段の対象、関係ファイルのハッシュと証拠の保存を確認する。"""
import datetime
import hashlib
import json
import pathlib
import re
import subprocess

root = pathlib.Path.cwd()
record = pathlib.Path(__file__).resolve().parent
work = json.loads((record / "work.json").read_text())
assert work["exit_code"] == work["check_exit_code"] == 0
assert (record / "work-check-exit.txt").read_text().strip() == "0"
log = (record / "work.log").read_text()
assert "\nselected checks passed\n" in log
counts = []
target = None
for line in log.splitlines():
    running = re.search(r"Running (unittests [^ ]+|tests/[^ ]+)", line)
    if running:
        target = running.group(1)
    result = re.match(r"test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out", line)
    if result and target:
        counts.append(dict(target=target, **dict(zip(
            ["passed", "failed", "ignored", "measured", "filtered"], map(int, result.groups())))))
        target = None
assert len(counts) == 42, len(counts)  # lib と全統合41ターゲット。
assert all(c["failed"] == 0 for c in counts)
stage_names = ["golden", "verify", "random_programs", "desugar_export", "checked_args", "fmt_command"]
stage = [next(c for c in counts if c["target"] == f"tests/{name}.rs") for name in stage_names]
(record / "test-counts.json").write_text(json.dumps(counts, ensure_ascii=False, indent=2) + "\n")

def digest(path):
    data = path.read_bytes()
    return {"path": str(path.relative_to(root)), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

tracked = subprocess.check_output(["git", "diff", "--name-only", "HEAD"], text=True).splitlines()
new = ["crates/benitoite/tests/desugar_export/" + n
       for n in ["scope.rs", "scope_tables.rs", "scope-tables-expected.json"]]
allowed_docs = ["docs/design/00-overview/00-04-glossary.md", "docs/design/01-spec/01-07-effects.md",
                "docs/design/07-quality/07-04-formal-semantics.md"]
assert all(p.startswith("crates/benitoite/") or p in allowed_docs for p in tracked), tracked
patch = subprocess.check_output(["git", "diff", "--binary", "HEAD", "--", "crates/benitoite", "docs/design"])
(record / "implementation.patch").write_bytes(patch)
files = [digest(root / p) for p in tracked + new]
work_state = json.loads((record / "work-state.json").read_text())
assert digest(root / work_state["patch"]["path"])["sha256"] == work_state["patch"]["sha256"]
comment_changes = {r["path"]: r for r in json.loads((record / "comment-only-check.json").read_text())}
for old in work_state["implementation_files"]:
    current = next(f for f in files if f["path"] == old["path"])
    if old["sha256"] != current["sha256"]:
        comment = comment_changes[old["path"]]
        assert old["sha256"] == comment["before_sha256"]
        assert current["sha256"] == comment["after_sha256"]
        assert comment["noncomment_lines_unchanged"]
assert json.loads((record / "final-comment-fmt.json").read_text())["exit_code"] == 0
ftable_final = []
for name in ["scope-tables-corpus.json", "scope-tables-builtins.json", "scope-tables-expected.json"]:
    latest = max((root / "target/scope-tables").glob("export-*/" + name), key=lambda p: p.stat().st_mtime)
    assert latest.read_bytes() == (record / name).read_bytes(), name
    ftable_final.append(digest(latest))

# 文書に追加した相対リンクの宛先と見出しを確認する。
glossary = root / allowed_docs[0]
for filename, heading in [
        ("../01-spec/01-06-type-system.md", "エフェクトの包含"),
        ("../02-impl/02-05-typechecker.md", "制約の種類")]:
    assert f"{filename}#{heading}" in glossary.read_text()
    assert f"### {heading}" in (glossary.parent / filename).read_text()
assert "範囲付きのエフェクトである" in (root / allowed_docs[1]).read_text()
for label, target in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", (record / "results.md").read_text()):
    if not target.startswith("https:"):
        assert (record / target.split("#")[0]).exists(), (label, target)
for path in record.iterdir():
    if path.is_file() and path.suffix in {".json", ".md", ".log", ".py", ".txt"}:
        assert str(root) not in path.read_text(), path.name

state = {
    "validation": "passed",
    "date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "branch": subprocess.check_output(["git", "branch", "--show-current"], text=True).strip(),
    "b_work": "765ae6d1606f8874761f881aebef585dd89d294d", "uncommitted": True,
    "implementation_files": files, "patch": digest(record / "implementation.patch"),
    "work_source_state": "work-state.json", "later_comment_changes": "comment-only-check.json",
    "final_rust_ftable_output_same_bytes": ftable_final,
    "work_counts": {"lib": counts[0], "integration_targets": len(counts) - 1,
                    "integration_passed": sum(c["passed"] for c in counts[1:]),
                    "integration_ignored": sum(c["ignored"] for c in counts[1:])},
    "stage_s10_20": {"source": "work.log", "additional_execution": False, "targets": stage,
                     "state": "same HEAD; later edits only full comment lines and records; noncomment lines unchanged; fmt rechecked",
                     "judge": "R10.7 担当", "date": "2026-10-28"}}
(record / "final-state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"validation": "passed", "work_counts": state["work_counts"], "stage_targets": stage},
                 ensure_ascii=False, indent=2))
