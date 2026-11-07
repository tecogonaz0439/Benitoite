#!/usr/bin/env python3
"""固定入力と現役の生成器の更新案が、既存の値と件数を保つことを照合する。"""

import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import runpy
import sys

KINDS = ("corpus", "builtins", "stdlib", "coverage", "coverage-program")
GENERATORS = {
    "test_range_exchange.py": ("fixtures",),
    "test_range_rejections.py": ("fixtures",),
    "test_width_exchange.py": ("inputs",),
    "test_interval_exchange.py": ("fixtures", "extra_fixtures"),
}


def counts(value):
    result = Counter()

    def walk(node):
        if isinstance(node, (list, tuple)):
            for child in node:
                walk(child)
        elif isinstance(node, dict):
            for field in ("inputs", "definitions", "arms", "matches", "bindings", "cases", "excluded"):
                if isinstance(node.get(field), list):
                    result[field] += len(node[field])
            if "outOfScope" in node:
                result["outside:" + json.dumps(node["outOfScope"], sort_keys=True)] += 1
            for child in node.values():
                walk(child)

    walk(value)
    return dict(result)


def compare_existing(original, candidate, path=()):
    """追加する欄の値を生成せず、既存の全位置の値を直接照合する。"""
    if isinstance(original, dict):
        assert isinstance(candidate, dict), (path, "object")
        for field, value in original.items():
            assert field in candidate, (path, field, "missing")
            fresh = candidate[field]
            if field == "version" and value != fresh:
                assert fresh in (8, 16), (path, field, fresh)
            elif field == "surfaceVersion":
                assert fresh == 16, (path, field, fresh)
            elif field == "exchangeVersions":
                assert fresh == {key: 16 if key == "corpus" else 8 for key in value}
            elif field == "ranges":
                expected = [
                    item if isinstance(item, dict) and ("fixed" in item or "rvar" in item)
                    else {"fixed": item}
                    for item in value
                ]
                assert fresh == expected, (path, field, value, fresh)
            else:
                compare_existing(value, fresh, (*path, field))
    elif isinstance(original, (tuple, list)):
        assert len(original) == len(candidate), (path, "length")
        for index, (before, after) in enumerate(zip(original, candidate)):
            compare_existing(before, after, (*path, index))
    else:
        assert original == candidate, (path, original, candidate)


def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def compare_value(name, original, candidate):
    before, after = counts(original), counts(candidate)
    assert before == after, (name, before, after)
    compare_existing(original, candidate)
    return {"name": name, "before": before, "after": after}


def check(original, candidate):
    fixed, generated, sources = [], [], []
    for path in sorted(original.rglob("*.json")):
        relative = path.relative_to(original)
        fresh = candidate / relative
        assert fresh.exists(), relative
        if path.stem in KINDS or path.name == "width-exchange.json":
            row = compare_value(str(relative), json.loads(path.read_text()), json.loads(fresh.read_text()))
            row.update(original=digest(path.read_bytes()), candidate=digest(fresh.read_bytes()))
            fixed.append(row)
    assert sum(Path(row["name"]).stem in KINDS for row in fixed) == 35
    for path in sorted(original.glob("*.py")):
        fresh = candidate / path.name
        assert fresh.exists(), path.name
        old_tree, new_tree = ast.parse(path.read_text()), ast.parse(fresh.read_text())
        compile(new_tree, str(path.name), "exec")
        tests = lambda tree: sum(isinstance(node, ast.FunctionDef) and node.name.startswith("test_")
                                 for node in ast.walk(tree))
        assert tests(old_tree) == tests(new_tree), (path.name, "test count")
        sources.append({"name": path.name, "tests": tests(new_tree),
                        "original": digest(path.read_bytes()), "candidate": digest(fresh.read_bytes())})
    for name, functions in GENERATORS.items():
        before = runpy.run_path(str(original / name))
        after = runpy.run_path(str(candidate / name))
        for function in functions:
            value = after[function]()
            row = compare_value(f"{name}:{function}", before[function](), value)
            row["candidate"] = digest((json.dumps(value, sort_keys=True, ensure_ascii=False) + "\n").encode())
            generated.append(row)
    return {"fixed": fixed, "generated": generated, "python": sources,
            "fixedExchangeFiles": 35, "pythonFiles": len(sources), "success": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    sys.dont_write_bytecode = True
    result = check(args.original, args.candidate)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({key: result[key] for key in ("fixedExchangeFiles", "pythonFiles", "success")}))


if __name__ == "__main__":
    main()
