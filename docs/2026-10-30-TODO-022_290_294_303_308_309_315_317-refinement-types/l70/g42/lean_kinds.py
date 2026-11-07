#!/usr/bin/env python3
"""Validate.lean が表層へ変換して数えた構成子の種類を、書き出した JSON の値と文書ごとに照らす。

Lean の側は、範囲内の定義を `SurfaceDef.toSurface` で表層へ変換した型パラメータの種類と、読者が読んだ
型クラスの引数の種類を数える。こちらは同じ文書の JSON の `tparamKinds`・`argumentKind` を数える。

使い方: `lean_kinds.py <Validate.lean の記録> <出力の JSON>`
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "g"))
from stream_json import events  # noqa: E402


def constructor_kinds(kinds):
    arities = [k["constructor"]["arity"] for k in kinds if k != "value"]
    return len(arities), sum(arities)


def counts(path):
    kinds, classes = [0, 0], [0, 0]
    for kind, key, _, item in events(path):
        if key != "inputs" or kind != "item" or item["excluded"]:
            continue
        n, a = constructor_kinds([c["argumentKind"] for c in item["classes"]])
        classes[0] += n
        classes[1] += a
        for d in item["definitions"]:
            scope = d["scope"].get("inScope")
            if scope is not None:
                n, a = constructor_kinds(scope["surface"]["header"]["tparamKinds"])
                kinds[0] += n
                kinds[1] += a
    return f"kinds={kinds[0]}:{kinds[1]} classes={classes[0]}:{classes[1]}"


def main():
    log, output = Path(sys.argv[1]), Path(sys.argv[2])
    rows, mismatches, totals = 0, [], [0, 0, 0, 0]
    for line in log.read_text().splitlines():
        found = re.fullmatch(r"ok corpus \d+ (\S+) (kinds=\d+:\d+ classes=\d+:\d+)", line)
        if not found:
            continue
        rows += 1
        expected = counts(Path(found[1]))
        if expected != found[2]:
            mismatches.append([found[1], found[2], expected])
        numbers = [int(x) for x in re.findall(r"\d+", found[2])]
        totals = [t + x for t, x in zip(totals, numbers)]
    result = {"corpusDocuments": rows, "mismatches": mismatches,
              "leanConstructorParams": totals[0], "leanConstructorParamArities": totals[1],
              "leanConstructorClasses": totals[2], "leanConstructorClassArities": totals[3]}
    output.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps(result))
    return 1 if mismatches or rows == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
