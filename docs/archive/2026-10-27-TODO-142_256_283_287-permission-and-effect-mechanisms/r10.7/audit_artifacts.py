"""局所照合の入力・報告を保存し、手書きの出どころと件数を照合する。Lean は起動しない。"""
import datetime
import hashlib
import json
import pathlib
import runpy
import shutil
import subprocess

root = pathlib.Path.cwd()
record = pathlib.Path(__file__).resolve().parent
source = root / "target/r10.7-ftable"
names = ["scope-tables-corpus.json", "scope-tables-builtins.json", "scope-tables-expected.json",
         "builtin-report.json", "desugar-report.json"]
for name in names:
    shutil.copyfile(source / name, record / name)

def read(name):
    return json.loads((record / name).read_text())

expected = read("scope-tables-expected.json")
corpus = read("scope-tables-corpus.json")
builtins = read("scope-tables-builtins.json")
builtin_report = read("builtin-report.json")
desugar_report = read("desugar-report.json")
assert corpus["version"] == 15 and builtins["version"] == 7
assert builtins["inputs"][0]["prims"] == expected["prims"]
for key, value in expected["tables"].items():
    assert builtins["inputs"][0][key] == value
assert corpus["inputs"][0]["scopeAcceptance"] == {
    "patterns": [], "hosts": [],
    "limits": {"body": {"operations": 1000, "items": 1000},
               "whole": {"operations": 10000, "items": 10000}}}
assert '"rvar"' not in json.dumps(corpus)
assert len(corpus["inputs"]) == 1
assert len(corpus["inputs"][0]["definitions"]) == 2
assert corpus["inputs"][0]["excluded"] == []
assert builtin_report["checkedInputs"] == 1 and builtin_report["errors"] == []
assert builtin_report["inputs"][0]["prims"] == builtin_report["inputs"][0]["converted"] == 13
assert builtin_report["summaryMismatchCount"] == 0 and builtin_report["summaryComparisons"] == 4
assert desugar_report["golden"]["definitions"] == dict(matched=2, mismatched=0, outside=0, excluded=0)
assert desugar_report["golden"]["programs"] == dict(matched=1, mismatched=0, outside=0, excluded=0)
assert desugar_report["nonTopRanges"] == 18 and desugar_report["mismatches"] == []

# L50.2 を import するだけであり、六入口の実行と unittest.main は起動しない。
independent = runpy.run_path(str(root / "formal/tests/test_range_exchange.py"))
rename = {
    "101:[]": "32:[]", "102:[]": "16:[]", "103:[]": "16:[]", "104:[]": "17:[]", "105:[]": "33:[]",
    "Result": "data:1001", "Http.RequestCheckError": "data:1002",
    "File.Write": "IO.File.Write", "Http.Connect": "Network.Http.Connect"}

def renamed(value):
    if isinstance(value, list):
        return [renamed(v) for v in value]
    if isinstance(value, dict):
        return {k: renamed(v) for k, v in value.items()}
    return rename.get(value, value) if isinstance(value, str) else value

assert expected["prims"][:3] == renamed(independent["PRIMS"])
assert expected["dataDecls"] == renamed(independent["DATA_DECLS"])
assert expected["dataTypes"] == renamed(independent["DATA_TYPES"])
assert expected["summaries"] == renamed(independent["SUMMARIES"])
for key, rows in renamed(independent["TABLE_DATA"]).items():
    assert all(row in expected["tables"][key] for row in rows), key

def digest(path):
    content = path.read_bytes()
    return {"path": str(path.relative_to(root)), "bytes": len(content),
            "sha256": hashlib.sha256(content).hexdigest()}

relations = [root / "formal/tests/test_range_exchange.py", root / "formal/Benitoite/Release/TargetTable.lean",
              root / "formal/Benitoite/Exchange/Range.lean", root / "formal/Benitoite/Exchange/Version.lean",
              root / "formal/Benitoite/Exchange/Builtins.lean", root / "formal/Benitoite/Exchange/Convert.lean",
              root / "formal/lakefile.toml", root / "formal/lean-toolchain", root / "formal/lake-manifest.json",
              root / "formal/.lake/build/bin/builtinCheck", root / "formal/.lake/build/bin/desugarDiff",
              root / "rust-toolchain.toml", root / "Cargo.toml", root / "Cargo.lock", root / ".cargo/config.toml",
              root / "crates/benitoite/tests/desugar_export/scope-tables-expected.json"]
relations += [record / name for name in names]
manifest = {
    "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "branch": subprocess.check_output(["git", "branch", "--show-current"], text=True).strip(),
    "b_work": "765ae6d1606f8874761f881aebef585dd89d294d",
    "source_directory": "target/r10.7-ftable", "corpus_version": 15, "sidecar_version": 7,
    "counts": {"inputs": 1, "definitions": 2, "signatures": 13, "pure": 6, "io": 7,
               "effKinds": 3, "valKinds": 2, "admitsR": 13, "valContents": 1, "nonTopRanges": 18},
    "l502_provenance": {"first_three_prims": "matched", "dataDecls": "matched", "dataTypes": "matched",
                         "summaries": "matched", "common_table_entries": "matched", "name_mapping": rename},
    "files": [digest(path) for path in relations],
    "formal_diff_from_b_work": subprocess.check_output(["git", "diff", "HEAD", "--", "formal"], text=True)}
assert manifest["formal_diff_from_b_work"] == ""
(record / "inputs-and-tools.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"audit": "passed", "counts": manifest["counts"], "l502_provenance": manifest["l502_provenance"]},
                 ensure_ascii=False, indent=2))
