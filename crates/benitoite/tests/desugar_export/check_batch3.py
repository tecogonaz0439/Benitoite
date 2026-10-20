"""実ソースの局所交換を六入口で照合し、入力ハッシュと結果を保存する。Cargoは起動しない。"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import time

SHARED = runpy.run_path(str(Path(__file__).with_name("check_named.py")))
ROOT = Path(__file__).resolve().parents[4]
BATCH3 = runpy.run_path(str(ROOT / "formal/tests/test_batch3_exchange.py"))
TOOLS = {
    "coverageDiff": ("coverage",),
    "coverageProgramDiff": ("coverage-program", "builtins"),
    "desugarDiff": ("corpus",),
    "builtinCheck": ("corpus", "builtins"),
    "surfaceCheck": ("corpus", "builtins", "stdlib"),
    "surfaceCheckAll": ("corpus", "builtins", "stdlib"),
}
FILES = ("corpus", "builtins", "stdlib", "coverage", "coverage-program")


def require(condition, message):
    SHARED["require"](condition, message)


def check_builder_sources(data):
    """実ソースの五定義を、L7の手書きの変換元と期待コアに照合する。"""
    inputs = {item["name"]: item for item in data["corpus"]["inputs"]}
    if "builders" not in inputs:
        return
    independent = json.loads((ROOT / "formal/tests/batch4-exchange/corpus.json").read_text())
    names = {"Reference.new": "new", "Reference.get": "get", "Reference.set": "set",
             "%String.add": "add", "String.join": "join", "String.byteLength": "strLen",
             "List.append": "append", "List.concatenate": "listCat", "List.length": "listLen",
             "Bytes.empty": "empty", "Bytes.fromList": "fromList", "Bytes.concatenate": "bytesCat",
             "Bytes.length": "bytesLen"}

    def renamed(value):
        if isinstance(value, str):
            return names.get(value, value)
        if isinstance(value, list):
            return [renamed(v) for v in value]
        if isinstance(value, dict):
            return {k: renamed(v) for k, v in value.items()}
        return value

    for actual_name, expected_id in (("stringCopy", 201), ("listCopy", 202), ("bytesLength", 203),
                                     ("interleaved", 205), ("typeRow", 207)):
        actual = next(d["scope"]["inScope"] for d in inputs["builders"]["definitions"]
                      if d["name"].startswith(actual_name + " ("))
        actual = renamed(copy.deepcopy(actual))
        expected = copy.deepcopy(next(d["scope"]["inScope"] for d in independent["inputs"][0]["definitions"]
                                      if d["name"].endswith(f"(fn:{expected_id})")))
        # 所属とviewは実際のロード結果。独立入力の架空の所属とは比較しない。
        for key in ("package", "coverageView"):
            expected["surface"][key] = actual["surface"][key]
        if expected_id == 207:
            # RustのE0418に従い、行変数を引数型にも出す。未使用の引数なので
            # セルから始まる期待コアの局所番号は変わらない。
            for layer in ("surface", "core"):
                expected[layer]["header"]["names"] = ["callback"]
                expected[layer]["header"]["params"] = [expected[layer]["header"]["ret"]["list"]["elem"]]
        def tail(block):
            while "last" not in block:
                block = next(iter(block.values()))["rest"]
            return block["last"]["expr"]["returnE"]
        # 末尾returnの到達しない続きはRustでUnit。返す値の型は頭とinner、
        # 期待コア全体で別に照合し、入力を検査する六入口にも渡す。
        require(tail(actual["surface"]["body"])["ret"] == {"base": {"name": "Unit"}}, actual_name)
        require(tail(expected["surface"]["body"])["ret"] == expected["surface"]["header"]["ret"], actual_name)
        tail(expected["surface"]["body"])["ret"] = {"base": {"name": "Unit"}}
        require(actual == expected, f"{actual_name}: independent surface/core differ")

    def selected(input_name, function):
        return next(d["scope"]["inScope"]["surface"] for d in inputs[input_name]["definitions"]
                    if d["name"].startswith(function + " ("))
    received = selected("numbering", "received")["body"]["builderBind"]
    require(received["rest"]["last"]["expr"]["returnE"]["inner"]["methName"]["dict"] ==
            {"local": {"index": 2}}, "received dictionary must count the cell")
    clause = selected("numbering", "numbering")["body"]["last"]["expr"]["returnE"]["inner"]["handleE"]["clauses"][0]
    rest = clause["body"]["builderBind"]["rest"]["bind"]["rest"]["discard"]
    dictionary = rest["expr"]["call"]["callee"]["methName"]["dict"]["clause"]
    require(dictionary == dict(outer=0, arity=1, dictCount=1, constraint=0, depth=2), "clause dictionary depth")
    require(rest["rest"]["last"]["expr"]["resume"] ==
            dict(index=2, inner={"local": {"index": 0}}), "resume and ordinary local numbering")


def check(directory, report_path):
    started = time.monotonic()
    paths = {name: directory / f"{name}.json" for name in FILES}
    data, expected = BATCH3["rust_inputs"](directory)
    check_builder_sources(data)
    for name, doc in data.items():
        require(doc["version"] == (13 if name == "corpus" else 5), f"{name}: exchange version")
    inputs = data["corpus"]["inputs"]
    require(inputs, "empty Rust corpus")
    names = [item["name"] for item in inputs]
    require(len(set(names)) == len(names), "duplicate Rust input names")
    count = 0
    surface_count = 0
    for item in inputs:
        require(item["group"] == "golden" and item["excluded"] == [], f"{item['name']}: input excluded")
        require(item["definitions"], f"{item['name']}: empty definitions")
        implementations = set()
        for definition in item["definitions"]:
            require(set(definition["scope"]) == {"inScope"}, f"{item['name']}: definition outside scope")
            count += 1
            surface = definition["scope"]["inScope"]["surface"]
            if surface["implementation"] is None:
                surface_count += 1
            else:
                implementations.add(surface["implementation"])
        # メソッドと上位辞書を含む実装は、表層の入口では実装一件として検査する。
        surface_count += len(implementations)
    for name in ("builtins", "stdlib", "coverage-program"):
        keys = [(item["group"], item["name"]) for item in data[name]["inputs"]]
        require(len(keys) == len(set(keys)) and set(keys) == {("golden", name) for name in names},
                f"{name}: input coverage differs")
    require(data["coverage"]["cases"], "empty standalone coverage cases")
    require(any(item["matches"] or item["bindings"] for item in data["coverage-program"]["inputs"]),
            "empty program coverage")
    require(count == expected["definitions"] and surface_count == expected["surfaceChecks"],
            "Rust manifest totals")
    results = {}
    with tempfile.TemporaryDirectory(prefix="benitoite-batch3-check-") as temporary:
        for tool, files in TOOLS.items():
            selected_inputs = names if tool == "surfaceCheck" else [None]
            reports = []
            for index, name in enumerate(selected_inputs):
                args = [paths[file] for file in files]
                if name is not None:
                    args.extend(["golden", name])
                result = SHARED["run"](tool, args, Path(temporary) / f"{tool}-{index}.json")
                if tool == "desugarDiff":
                    require(result["mismatches"] == [], f"{tool}: mismatches")
                    require(result["golden"]["definitions"] == dict(matched=count, mismatched=0, outside=0, excluded=0),
                            f"{tool}: definition counts")
                elif tool == "builtinCheck":
                    require(result["errors"] == [] and result["summaryMismatchCount"] == 0, f"{tool}: errors")
                elif tool.startswith("coverage"):
                    require(result["matched"] > 0 and result["mismatched"] == 0 and result["fuelExhausted"] == 0,
                            f"{tool}: coverage mismatch or empty comparison")
                    require(result["matched"] == expected["coverageCases" if tool == "coverageDiff" else "programCoverageCases"],
                            f"{tool}: manifest counts")
                elif tool == "surfaceCheck":
                    require(result["result"] == {"ok": True}, f"{tool}: {name}: rejection")
                else:
                    require(result["counts"] == dict(matched=surface_count, mismatched=0, outOfScope=0, q11=0,
                            lazyRestriction=0, preparationFailure=0), f"{tool}: counts")
                reports.append(result)
            results[tool] = reports
    report = dict(elapsed_seconds=time.monotonic() - started, inputs=names, definitions=count,
                  surface_checks=surface_count,
                  files={name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in paths.items()},
                  results=results)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"batch3: {len(inputs)} inputs, {count} definitions, six entries agree: {report_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rust-dir", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    check(args.rust_dir.resolve(), args.report.resolve())


if __name__ == "__main__":
    main()
