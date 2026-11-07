#!/usr/bin/env python3
"""書き出しのディレクトリの JSON を種類に分け、Validate.lean の manifest を作る。"""
import json
import sys
from pathlib import Path


def kind_of(doc):
    if not isinstance(doc, dict):
        return None
    if doc.get("kind") == "interval-corpus":
        return "interval"
    if "operators" in doc and "inputs" in doc:
        return "corpus"
    if "cases" in doc and "seedXor" in doc:
        return "coverage"
    inputs = doc.get("inputs")
    if isinstance(inputs, list) and "version" in doc:
        if not inputs:
            return "empty"
        first = inputs[0]
        if "prims" in first:
            return "builtins"
        if "functions" in first:
            return "stdlib"
        if "matches" in first:
            return "coverage-program"
    return None


def main():
    root, out, limit = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
    rows, skipped, large = [], [], []
    for p in sorted(root.rglob("*.json")):
        if p.stat().st_size > limit:
            large.append([str(p), p.stat().st_size])
            continue
        try:
            doc = json.loads(p.read_text())
        except Exception as e:  # 生の記録の一部は JSON でない
            skipped.append([str(p), f"parse: {e}"])
            continue
        k = kind_of(doc)
        if k in (None, "empty"):
            skipped.append([str(p), k or "other"])
            continue
        rows.append([k, str(p)])
    out.write_text(json.dumps(rows, indent=1) + "\n")
    print(json.dumps({"entries": len(rows), "skipped": len(skipped), "large": large}, indent=1))
    for s in skipped:
        print("skip", *s)


if __name__ == "__main__":
    main()
