"""本番blockの交換をL7の独立入力と六つのLean入口で照合する。"""
import copy
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
CHECK = runpy.run_path(str(ROOT / "crates/benitoite/tests/desugar_export/check_batch3.py"))


def main():
    directory = ROOT / "target/formal-batch3/blocks"
    corpus = json.loads((directory / "corpus.json").read_text())
    independent = json.loads((ROOT / "formal/tests/batch4-exchange/corpus.json").read_text())
    actuals = next(i for i in corpus["inputs"] if i["name"] == "block-values")["definitions"]
    expected_defs = [d for i in independent["inputs"] for d in i["definitions"]]
    for actual_name, expected_id in [("blockValue", 301), ("blockReturn", 302), ("lambdaBlock", 303)]:
        actual = next(d["scope"]["inScope"] for d in actuals if d["name"].startswith(actual_name + " ("))
        expected = copy.deepcopy(next(d["scope"]["inScope"] for d in expected_defs if d["name"].endswith(f"(fn:{expected_id})")))
        CHECK["require"](actual["core"] == expected["core"], f"{actual_name}: independent core differs")
        for key in ("package", "coverageView"):
            expected["surface"][key] = actual["surface"][key]
        # 独立入力の末尾 return の、到達しない続きだけを Unit に合わせる。
        # return の頭の型・inner・ほかの returnE は書き換えずに比較する。
        terminal = ("body", "last", "expr", "returnE")
        paths = {
            "blockValue": [terminal],
            "blockReturn": [("body", "last", "expr", "block") + terminal],
            "lambdaBlock": [terminal, terminal + ("inner", "lam", "body", "last", "expr", "block") + terminal],
        }
        for path in paths[actual_name]:
            node = expected["surface"]
            for key in path:
                node = node[key]
            CHECK["require"]("ret" in node and "inner" in node, f"{actual_name}: terminal return missing")
            node["ret"] = {"base": {"name": "Unit"}}
        CHECK["require"](actual["surface"] == expected["surface"], f"{actual_name}: independent surface differs")
    report_path = HERE / "exchange-results.json"
    CHECK["check"](directory, report_path)
    report = json.loads(report_path.read_text())
    report["independent_definitions"] = 3
    report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
