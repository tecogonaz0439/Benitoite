#!/usr/bin/env python3
"""check_named.py の固定記録の照合のうち、Lean の入口を呼ばない部分を新しい書き出しに当てる。

経路（入力・除外・定義の範囲・網羅性の件数）と、版・件数の固定記録を照合する。
"""
import json
import runpy
import sys
from collections import Counter
from pathlib import Path

worktree, directory, coverage_dir = map(Path, sys.argv[1:4])
named = runpy.run_path(str(worktree / "crates/benitoite/tests/desugar_export/check_named.py"))
require, read, keyed = named["require"], named["read"], named["keyed"]
manifest = read(named["MANIFEST"])
versions = manifest["namedVersions"]

named["check_routing"](directory, manifest)
named["check_coverage_exports"](coverage_dir, manifest["coverageExports"])

# check_programs の Lean を呼ばない部分。
stem = "named-programs"
corpus = read(directory / f"{stem}-corpus.json")
require(corpus["version"] == versions["corpus"], "general corpus version")
expected = {(i["group"], i["name"]): i for i in manifest["programs"]}
keys = [(i["group"], i["name"]) for i in corpus["inputs"]]
require(len(keys) == len(expected) and set(keys) == set(expected), "general program routing")
for path in (directory / f"{stem}-builtins.json", directory / f"{stem}-stdlib.json"):
    table = read(path)
    require(table["version"] == versions["table"], str(path))
    require([(i["group"], i["name"]) for i in table["inputs"]] ==
            [key for key in keys if not expected[key].get("excluded")], str(path))
definitions = surface_definitions = 0
excluded = Counter()
for item in corpus["inputs"]:
    entry = expected[item["group"], item["name"]]
    expected_entry = {**entry, "excluded": entry.get("excluded", [])}
    reloc = named["relocation_independent_routing"]
    require(reloc(item)["excluded"] == reloc(expected_entry)["excluded"], item["name"])
    if item["excluded"]:
        require(item["definitions"] == [], item["name"])
        for reason in item["excluded"]:
            excluded[reason if "NoMainFile" not in reason else "entry: NoMainFile"] += 1
        continue
    require(len(item["definitions"]) == entry["definitions"], item["name"])
    scopes = Counter(next(iter(d["scope"])) for d in item["definitions"])
    require(dict(scopes) == entry.get("scopes", {"inScope": entry["definitions"]}), item["name"])
    definitions += entry["definitions"]
    surfaces = [d["scope"]["inScope"]["surface"] for d in item["definitions"] if "inScope" in d["scope"]]
    implementations = {s["implementation"] for s in surfaces if s["implementation"] is not None}
    surface_checks = sum(s["implementation"] is None for s in surfaces) + len(implementations)
    require(len(implementations) == entry.get("implementations", 0), f"{item['name']}: implementations")
    require(surface_checks == entry.get("surfaceChecks", scopes.get("inScope", 0)), f"{item['name']}: surface checks")
    surface_definitions += surface_checks
coverage = read(directory / f"{stem}-coverage.json")
require(coverage["version"] == versions["coverage"], "general coverage version")
require([(i["group"], i["name"]) for i in coverage["inputs"]] ==
        [key for key in keys if not expected[key].get("excluded")], "general coverage routing")
matches = 0
for item in coverage["inputs"]:
    for kind, count in expected[item["group"], item["name"]]["coverage"].items():
        require(len(item[kind]) == count, f"{item['name']}: {kind}")
        matches += count
require(definitions == manifest["programReports"]["definitions"]
        and surface_definitions == manifest["programReports"]["surfaceChecks"]
        and matches == manifest["programReports"]["coverageEntries"], "general input totals")

# check_named の各入力の版と件数（Lean の入口を除く）。
for entry in manifest["named"]:
    s = entry["stem"]
    c = read(directory / f"{s}-corpus.json")
    require(c["version"] == versions["corpus"], s)
    require(len(c["inputs"]) == 1 and len(c["inputs"][0]["definitions"]) == entry["definitions"], s)
    for path in (directory / f"{s}-builtins.json", directory / f"{s}-stdlib.json"):
        require(read(path)["version"] == versions["table"], str(path))
    if entry["coverage"] is not None:
        cov = read(directory / f"{s}-coverage.json")
        require(cov["version"] == versions["coverage"], s)
        for key, count in entry["coverage"].items():
            require(len(cov["inputs"][0][key]) == count, f"{s}: {key}")
data = read(coverage_dir / "named-corpus.json")
require(data["version"] == manifest["coverageExports"]["named-"]["version"], "coverage version")
require(len(data["cases"]) == manifest["namedCoverageCases"], "coverage cases")
width = read(directory / "width-smoke" / "corpus.json")
require(width["version"] == 16, "width corpus version")
require([(i["name"], len(i["definitions"])) for i in width["inputs"]] ==
        [tuple(e) for e in manifest["width"]["inputs"]], "width inputs and definitions")

print(json.dumps({
    "programs": len(keys), "excludedPrograms": sum(1 for i in corpus["inputs"] if i["excluded"]),
    "definitions": definitions, "surfaceChecks": surface_definitions, "coverageEntries": matches,
    "excludedReasons": {"external function": excluded["external function"],
                        "distinct": len(excluded), "total": sum(excluded.values())},
    "named": len(manifest["named"])}, ensure_ascii=False))
