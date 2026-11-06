#!/usr/bin/env python3
"""群Aの完全名の対照表を、削除後の同じ宣言環境で更新する。"""
import argparse
import json
from records import HERE, digest, read_graph, write


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--graph", type=__import__("pathlib").Path, required=True)
    args = parser.parse_args()
    inventory_path = HERE.parent / "a/inventory.json"
    inventory = json.loads(inventory_path.read_text())
    graph = read_graph(args.graph)
    rows = []
    for source in inventory["table"]:
        row = {"old": source["old"], "old_present": source["old"] in graph,
               "new": source["new"], "new_present": [name in graph for name in source["new"]]}
        assert all(row["new_present"]), row
        rows.append(row)
    forbidden = set(inventory["old_main"] + inventory["surface_theorems"])
    assert not forbidden & graph.keys(), sorted(forbidden & graph.keys())
    admit = sorted(name for name in graph if name.split(".")[-1] == "admit")
    assert not admit, admit
    write(HERE / "name-correspondence.json", {"source": digest(inventory_path),
          "graph": digest(args.graph), "rows": rows, "old_main_removed": len(inventory["old_main"]),
          "old_surface_theorems_removed": len(inventory["surface_theorems"]), "admit": admit})
    output = ["# 判断と主定理の完全名の対照", "", "群Aの62行を同じ削除後の環境で照合した。残る旧判断は埋め込みの定義域である。",
              "", "| 旧の完全名 | 削除後 | 新判断・主定理の完全名 |", "|---|---|---|"]
    for row in rows:
        targets = "、".join("`" + name + "`" for name in row["new"])
        output.append("| `" + row["old"] + "` | " + ("保持" if row["old_present"] else "削除") + " | " + targets + " |")
    (HERE / "name-correspondence.md").write_text("\n".join(output) + "\n")
    print(json.dumps({"rows": len(rows), "new_names": len({n for r in rows for n in r["new"]}),
                      "admit": len(admit)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
