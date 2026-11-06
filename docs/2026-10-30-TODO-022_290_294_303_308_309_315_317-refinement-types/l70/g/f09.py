#!/usr/bin/env python3
"""削除後の既定環境と7入口の宣言グラフから、閉包と逆戻りと保持一覧を照合する。"""
import argparse
import collections
import json
from pathlib import Path
from records import HERE, ROOT, ENTRIES, closure, digest, module_graph, read_graph, write

R = "Benitoite.Release.Refinement."


def is_embedding(name, row):
    if not (name.startswith(R) or row["module"].startswith(R)):
        return False
    return (any(p.startswith("embed") or p.startswith("Legacy") for p in name.split(".")) or
            row["module"].split(".")[-1].startswith("Legacy") or row["module"].endswith(".Embedding"))


def backflow(graph, starts, proper):
    # 埋め込みの節点で止め、型と値の辺をともに辿る。
    next_to_bad = {n: None for n in proper}
    reverse = collections.defaultdict(set)
    for name, row in graph.items():
        for dep in row["dependencies"]:
            reverse[dep].add(name)
    pending = collections.deque(proper)
    while pending:
        bad = pending.popleft()
        for user in sorted(reverse[bad]):
            if user in next_to_bad or is_embedding(user, graph[user]):
                continue
            next_to_bad[user] = bad
            pending.append(user)
    failures = sorted(n for n in starts if n in next_to_bad and not is_embedding(n, graph[n]))
    paths = []
    for name in failures[:10]:
        path = [name]
        while next_to_bad[path[-1]] is not None:
            path.append(next_to_bad[path[-1]])
        paths.append(path)
    return failures, paths


def declaration_closure(graph, root):
    return closure({n: row["dependencies"] for n, row in graph.items()}, [root])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--default", type=Path, required=True)
    parser.add_argument("--entry", action="append", default=[], metavar="NAME=GRAPH")
    args = parser.parse_args()
    inventory = json.loads((HERE.parent / "a/inventory.json").read_text())
    plan = json.loads((HERE / "deletion-plan.json").read_text())
    deleted = set(plan["delete_modules"])
    forbidden = set(inventory["old_main"] + inventory["surface_theorems"])
    forbidden |= {d["name"] for edit in plan["edits"].values() for d in edit["declarations"] if d["name"]}
    proper = set(inventory["proper_judgments"])
    modules = module_graph()
    default_modules = closure(modules, ["Benitoite"])
    assert not default_modules & deleted, sorted(default_modules & deleted)
    assert {n for n in default_modules if n.startswith("Benitoite.Surface.")} == set(plan["keep_surface"])
    kept = {n for n in default_modules if n.startswith("Benitoite.Release.") and not n.startswith(R)}
    assert kept == set(plan["keep_release"]), sorted(kept ^ set(plan["keep_release"]))

    graphs = {"default": read_graph(args.default)}
    inputs = {"default": digest(args.default)}
    for item in args.entry:
        key, filename = item.split("=", 1)
        assert key in ENTRIES and key not in graphs, key
        own = read_graph(Path(filename))
        graph = dict(graphs["default"])
        for name, row in own.items():
            assert name not in graph or graph[name] == row, (key, name, "declaration differs")
            graph[name] = row
        graphs[key] = graph
        inputs[key] = digest(Path(filename))
    assert set(graphs) == {"default"} | set(ENTRIES), "7入口の個別の宣言グラフを指定する"
    findings = {}
    for key, graph in graphs.items():
        present = sorted(n for n in graph if n in forbidden or graph[n]["module"] in deleted)
        assert not present, (key, present[:10])
        if key == "default":
            starts = {n for n, row in graph.items() if row["module"].startswith(R)}
        else:
            main_names = [n for n, row in graph.items() if row["module"] == ENTRIES[key]
                          and (n == "main" or n.endswith(".main"))]
            assert len(main_names) == 1, (key, main_names)
            starts = declaration_closure(graph, main_names[0]) & graph.keys()
        failures, paths = backflow(graph, starts, proper)
        findings[key] = {"roots": len(starts), "backflow": len(failures), "paths": paths}
        assert not failures, (key, paths)
        if key == "intervalDiff":
            required = {R + n for n in ["IntervalReport.connect", "IntervalReport.normal_run",
                "IntervalReport.returned_mark", "IntervalReport.failed", "ProgramGuarantees.steps_preservation",
                "IntervalControlLeaves.escape_mark_member", "tracked_failure_sound"]}
            required.add("Benitoite.Interval.ReportFlow.view")
            assert required <= starts, sorted(required - starts)
            findings[key]["new_connections"] = sorted(required)
    # 表の74モジュールを定義域31・共有19・全宣言の依存24に分けて確認する。
    c05 = set(inventory["c05"]["old_release_modules"])
    shared = set(inventory["keep_release"]) - c05
    remainder = set(plan["keep_release"]) - c05 - shared
    assert [len(c05), len(shared), len(remainder)] == [31, 19, 24]
    table = (HERE / "modules-for-spec.md").read_text()
    assert all("`" + n.removeprefix("Benitoite.") + "`" in table for n in kept)
    record = {"deletion_modules": len(deleted), "kept_release": len(kept),
              "kept_surface": sorted(plan["keep_surface"]), "release_groups": [31, 19, 24],
              "proper_judgments": len(proper), "checks": findings, "inputs": inputs,
              "module_table": digest(HERE / "modules-for-spec.md")}
    write(HERE / "f09.json", record)
    print(json.dumps({"modules_deleted": len(deleted), "release_kept": len(kept),
                      "backflow": {k: v["backflow"] for k, v in findings.items()}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
