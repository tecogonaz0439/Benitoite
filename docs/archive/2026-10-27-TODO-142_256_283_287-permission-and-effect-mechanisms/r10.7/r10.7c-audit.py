"""R10.7b の保存物を再照合する。ビルド・展開・git の状態変更は行わない。"""
import ast
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path.cwd()
RECORD = Path(__file__).resolve().parent


def read(name):
    return json.loads((RECORD / name).read_text())


def digest(path):
    data = path.read_bytes()
    return {"path": str(path.relative_to(ROOT)), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def verify(row, root):
    actual = digest(root / row["path"])
    assert actual["bytes"] == row["bytes"], row["path"]
    assert actual["sha256"] == row["sha256"], row["path"]
    return actual


state = [verify(row, ROOT) for row in read("r10.7b-work-state.json")]
comparison = read("r10.7b-comparison.json")
comparison_files = [verify(row, ROOT) for row in comparison["artifacts"]]
verify(comparison["source"], ROOT)

# 採取・ビルドを含む台本全体は実行せず、保存済みの最終バイト列へ同じ射影だけを適用する。
tree = ast.parse((RECORD / "r10.7b-compare.py").read_text())
projection = next(node for node in tree.body
                  if isinstance(node, ast.FunctionDef) and node.name == "legacy_projection")
namespace = {"changes": []}
exec(compile(ast.Module(body=[projection], type_ignores=[]), "<saved-projection>", "exec"),
     namespace)
project = namespace["legacy_projection"]
canonical = lambda value: json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()
for name in ("corpus.json", "builtins.json", "stdlib-decls.json", "coverage.json", "stream.json"):
    before = read("r10.7b-baseline-" + name)
    after = read("r10.7b-current-" + name)
    assert canonical(project(after, "/" + name)) == canonical(before), name
assert sorted(set(namespace["changes"])) == comparison["projected_paths"]

ftable = [verify(row, RECORD) for row in read("r10.7b-ftable-artifacts.json")]
for row in read("r10.7b-ftable-artifacts.json"):
    assert row["identical_to_r10_7"]
    assert (RECORD / row["path"]).read_bytes() == (RECORD / row["path"].removeprefix("r10.7b-")).read_bytes()
ftable_runs = {label: read(label + ".json") for label in
               ("r10.7b-ftable-export", "r10.7b-ftable-builtin", "r10.7b-ftable-desugar")}
assert all(run["exit_code"] == 0 for run in ftable_runs.values())
builtin = read("r10.7b-builtin-report.json")
assert builtin["checkedInputs"] == 1 and builtin["errors"] == []
assert builtin["summaryMismatchCount"] == 0 and builtin["summaryComparisons"] == 4
assert builtin["inputs"][0]["converted"] == 13
desugar = read("r10.7b-desugar-report.json")
assert desugar["golden"]["definitions"] == dict(matched=2, mismatched=0, outside=0, excluded=0)
assert desugar["golden"]["programs"] == dict(matched=1, mismatched=0, outside=0, excluded=0)

temporary_paths = [Path("crates/benitoite/tests") / (stem + suffix)
                   for stem in ("r10_7b_baseline", "r10_7b_current") for suffix in ("", ".rs")]
assert not any(path.exists() for path in temporary_paths)
failure = RECORD / "r10.7b-work.log"
assert "No space left on device" in failure.read_text()
report = {
    "checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "unchanged_r10_7b_sources": state,
    "comparison_artifacts": comparison_files,
    "comparison_documents_equal_after_saved_projection": 5,
    "ftable_artifacts": ftable,
    "ftable_runs": {name: {key: run[key] for key in ("exit_code", "elapsed_seconds")}
                    for name, run in ftable_runs.items()},
    "temporary_comparison_sources_absent": True,
    "preserved_failure_log": digest(failure),
    "review": digest(RECORD.parent / "reviews/RV-R10.7.md"),
    "new_build_directory_or_baseline_extraction": False,
}
(RECORD / "r10.7c-audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print("R10.7b のソース11件・比較5文書・F-table の保存物5件と終了0を確認した。")
