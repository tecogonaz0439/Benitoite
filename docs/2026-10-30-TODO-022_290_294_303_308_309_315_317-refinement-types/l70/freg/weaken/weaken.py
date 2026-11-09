"""照合を弱めていないことを、壊した報告で確かめる（一時ファイルは引数の作業ディレクトリに置く）。"""
import copy, json, runpy, sys
from pathlib import Path

repo, work = Path(sys.argv[1]), Path(sys.argv[2])
N = runpy.run_path(str(repo / "crates/benitoite/tests/desugar_export/check_named.py"))
D = repo / "target/desugar-diff/run-23827"
corpus_path = D / "named-programs-corpus.json"
corpus = json.loads(corpus_path.read_text())
desugar = json.loads((D / "report.json").read_text())
results = []

def expect_failure(label, action):
    try:
        action()
    except AssertionError as error:
        results.append((label, "rejected", str(error)[:300]))
        return
    results.append((label, "ACCEPTED", ""))

# 正の対照: 元の報告は既知の差だけで分類できる。
_, known = N["classify_program_desugar"](desugar, corpus)
results.append(("control: original desugar report", "classified", json.dumps(known)))

def with_report(mutate):
    def action():
        broken = copy.deepcopy(desugar)
        mutate(broken)
        path = work / "report.json"
        path.write_text(json.dumps(broken))
        report = N["full_report"]("desugarDiff", [corpus_path], path, work / "unused.json", (0, 1))
        N["classify_program_desugar"](report, corpus)
    return action

def unknown_shape(r):
    # 一件だけ、結果型の差を篩の付加でない差（基底型の取り違え）にする。
    m = r["mismatches"][0]
    m["actual"] = {"base": {"name": "String"}}
    m["actualDefinition"]["header"]["ret"] = {"base": {"name": "String"}}
expect_failure("desugar: one difference of an unknown shape", with_report(unknown_shape))

def hidden_body(r):
    # 一件だけ、結果型の既知の差に加えて本体にも差を混ぜる。
    m = r["mismatches"][0]
    m["actualDefinition"]["body"] = {"ret": {"value": {"var": {"index": 9}}}}
expect_failure("desugar: known shape plus a body difference", with_report(hidden_body))

def other_path(r):
    r["mismatches"][0]["path"] = "definition.body"
expect_failure("desugar: known shape on another path", with_report(other_path))

def missing_record(r):
    r["mismatches"].pop()
expect_failure("desugar: mismatched count without a record", with_report(missing_record))

surface = json.loads((D / "surface-check/report.json").read_text())

def with_surface(mutate):
    def action():
        broken = copy.deepcopy(surface)
        mutate(broken)
        path = work / "surface-report.json"
        path.write_text(json.dumps(broken))
        N["full_report"]("surfaceCheckAll", [corpus_path, D / "named-programs-builtins.json",
                         D / "named-programs-stdlib.json"], path, work / "unused.json")
    return action

def unclassified(r):
    r["preparationErrors"][0]["reason"] = "builtin signature disagrees with the standard table: [Foo.bar]"
expect_failure("surface: preparation rejection outside the table (full report)", with_surface(unclassified))

def other_reason(r):
    r["preparationErrors"][0]["reason"] = "stdlib declaration is ill-formed"
expect_failure("surface: preparation rejection of another kind (full report)", with_surface(other_reason))

# 単独の入口の拒否の文: 分類の表にない名前は分類しない。
results.append(("surface: single rejection text outside the table",
                "rejected" if N["preparation_gaps"]("surfaceCheck: builtin signature disagrees with the standard table: [Foo.bar]") is None
                else "ACCEPTED", ""))
for row in results:
    print(" | ".join(row))
sys.exit(0 if all(r[1] != "ACCEPTED" for r in results) else 1)
