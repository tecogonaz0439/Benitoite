"""実ソースの小さい予算による Required のキー・理由を独立期待値と比較する。

番号付け停止は Rust 独自の制限として区別し、最後の Run の超過と、内側の超過から
外側が回復した場合だけを同じ出現の鍵で Lean と直接比較する。例外や終了2を無視しない。
"""
import argparse
import json
from pathlib import Path
import re
import resource
import runpy
import subprocess
import time


def require(ok, message):
    if not ok:
        raise AssertionError(message)


ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / "formal/.lake/build/bin"
EXPECTED = ROOT / "crates/benitoite/tests/desugar_export/range-budget/expected.json"
HELPERS = runpy.run_path(str(ROOT / "crates/benitoite/tests/desugar_export/check_named.py"))


def read(path):
    return json.loads(path.read_text())


def run(tool, args, report, status):
    cmd = [str(BIN / tool), *map(str, args), str(report)]
    began = time.monotonic()
    process = subprocess.run(cmd, text=True, capture_output=True, timeout=60)
    elapsed = time.monotonic() - began
    raw = process.stdout + process.stderr
    report.with_suffix(".log").write_text(raw.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>"))
    require(process.returncode == status, (tool, status, process.returncode, raw))
    require(report.exists(), (tool, "missing report"))
    return read(report), {"tool": tool, "returncode": process.returncode, "outerSeconds": elapsed}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rust-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    expected = read(EXPECTED)
    manifest = read(args.rust_dir / "manifest.json")
    require({row["name"] for row in manifest["inputs"]} == {row["name"] for row in expected["cases"]}, 'test_range_budget_sources.py:45: requirement failed')
    cases = []
    auxiliary_mismatches = []
    auxiliary_stops = {}
    for case in expected["cases"]:
        name = case["name"]
        source = args.rust_dir / name
        output = args.output_dir / name
        output.mkdir(parents=True, exist_ok=True)
        rust = read(source / "rust.json")
        corrected_stop = case.get("firstStopPreorderCorrection", {}).get("value", case.get("firstStopPreorder"))
        require(rust["auxiliaryFirstStopActual"] == corrected_stop, (name, "corrected auxiliary stop differs"))
        auxiliary_stops[name] = rust["auxiliaryFirstStopActual"]
        if not rust["auxiliaryFirstStopMatches"]:
            auxiliary_mismatches.append({"name": name, "expected": rust["auxiliaryFirstStopExpected"],
                                         "actual": rust["auxiliaryFirstStopActual"]})
        require(rust["calls"] == case["calls"], (name, "Rust Required differs from hand-written expectation"))
        require(rust["numberingComplete"] == case["numberingComplete"], 'test_range_budget_sources.py:58: requirement failed')
        require(rust["finalStop"] == case["finalStop"], 'test_range_budget_sources.py:59: requirement failed')
        if not case["numberingComplete"]:
            require(all(call["preorder"] is None and call["required"] == "top" and
                       call["reason"] == "budgetExceeded" for call in rust["calls"]), 'test_range_budget_sources.py:61: requirement failed')
            cases.append({"name": name, "rustRules": len(rust["calls"]), "lean": "notApplicable-numbering-limit"})
            continue
        corpus = HELPERS["without_candidates"](read(source / "corpus.json"))
        count = HELPERS["non_top_ranges"](corpus)
        require(case["lean"]["nonTopRangesPositive"] and count > 0, (name, "range group became all Top"))
        (output / "corpus-without-candidates.json").write_text(json.dumps(corpus))
        corpus_path = output / "corpus-without-candidates.json"
        builtin_path, stdlib_path = source / "builtins.json", source / "stdlib.json"
        definitions = corpus["inputs"][0]["definitions"]
        require(len(definitions) == 1, 'test_range_budget_sources.py:72: requirement failed')
        definition = definitions[0]
        require(list(definition["scope"]) == ["inScope"], (name, "outside/depth exclusions cannot pass"))
        key = re.search(r"\((fn:\d+)\)$", definition["name"])[1]
        # 先行順番号は手書きの値、定義の鍵は同じ宣言に付いた交換名へ対応させる。
        expected_key = {"definition": key, "surfacePreorder": case["lean"]["preorder"]}
        reports = []
        report = output / "surfaceCheck.json"
        # surfaceCheck は report の後ろに選択定義を取るため他の入口と別に呼ぶ。
        cmd = [str(BIN / "surfaceCheck"), str(corpus_path), str(builtin_path), str(stdlib_path),
               "golden", name, str(report), key]
        began = time.monotonic()
        process = subprocess.run(cmd, text=True, capture_output=True, timeout=60)
        elapsed = time.monotonic() - began
        report.with_suffix(".log").write_text((process.stdout + process.stderr).replace(str(ROOT), "<wt>"))
        require(process.returncode == case["lean"]["surfaceCheckExit"], (name, process.stdout, process.stderr))
        single = read(report)
        require(single["result"] == {"ok": False, "cover": {"key": expected_key, "reason": case["lean"]["reason"]}}, (name, single))
        reports.append({"tool": "surfaceCheck", "returncode": process.returncode, "outerSeconds": elapsed})
        all_report, timing = run("surfaceCheckAll", [corpus_path, builtin_path, stdlib_path], output / "surfaceCheckAll.json", 1)
        reports.append(timing)
        require(all_report["nonTopRanges"] == count and count > 0, 'test_range_budget_sources.py:93: requirement failed')
        outcomes = all_report["outcomes"]
        require(len(outcomes) == 1, 'test_range_budget_sources.py:95: requirement failed')
        require(outcomes[0]["category"] == case["lean"]["surfaceCheckAllCategory"], 'test_range_budget_sources.py:96: requirement failed')
        serialized = json.dumps(outcomes[0])
        require(case["lean"]["surfaceCheckAllReasonContains"] in serialized, 'test_range_budget_sources.py:98: requirement failed')
        require(case["lean"]["reason"] in serialized, 'test_range_budget_sources.py:99: requirement failed')
        desugar, timing = run("desugarDiff", [corpus_path], output / "desugarDiff.json", case["lean"]["desugarDiffExit"])
        reports.append(timing)
        require(desugar["golden"]["definitions"] == {"matched": 1, "mismatched": 0, "outside": 0, "excluded": 0}, 'test_range_budget_sources.py:102: requirement failed')
        require(desugar["nonTopRanges"] == count and count > 0, 'test_range_budget_sources.py:103: requirement failed')
        table, timing = run("builtinCheck", [corpus_path, builtin_path], output / "builtinCheck.json", 0)
        reports.append(timing)
        require(table["errors"] == [] and table["checkedInputs"] == 1, 'test_range_budget_sources.py:106: requirement failed')
        cases.append({"name": name, "rustRules": len(rust["calls"]), "key": expected_key,
                      "reason": case["lean"]["reason"], "nonTopRangesWithoutCandidates": count,
                      "definitions": 1, "reports": reports})
    # 固定済みの補助期待の誤りを、主契約が一致したことへ読み替えない。
    summary = {"version": 1, "success": True, "cases": cases, "rustOnlyCases": 1,
               "auxiliaryExpectedMismatches": auxiliary_mismatches,
               "auxiliaryFirstStops": auxiliary_stops,
               "auxiliaryExpectedMismatchCount": len(auxiliary_mismatches),
               "successScope": "Requiredのキー・添字・理由。補助の停止地点は訂正値との一致を要求し、初稿との不一致も保持する",
               "leanComparedCases": 2, "requiredReasonComparisons": 2,
               "maxRssBytesAuxiliary": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
    (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
