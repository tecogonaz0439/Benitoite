#!/usr/bin/env python3
"""F09 の照合の宣言グラフの書き出しの入力（既定の環境と7入口の8件）を graph.lean から作り、実行の手順を示す。

入力は graph.lean の `import Benitoite` を、入口ごとに入口の根のモジュールの import に替えたものである。
書き出しと照合は次のとおりに行う（<tmp> は一時領域）。

  python3 graph_inputs.py --tmp <tmp>
  (cd formal && lake env lean -M 12288 <tmp>/default.lean > <tmp>/default.graph)   # 8件それぞれ。同時に一つ
  python3 f09.py --default <tmp>/default.graph --entry desugarDiff=<tmp>/desugarDiff.graph ...（7入口）

グラフは大きい（各 138〜220 MB）ので改造に置かず、大きさと SHA-256 を f09.json の inputs に残す。
"""
import argparse
import json
from pathlib import Path
from records import HERE, ENTRIES, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    template = (HERE / "graph.lean").read_text()
    assert template.count("import Benitoite\n") == 1
    roots = {"default": "Benitoite", **ENTRIES}
    written = {}
    for key, root in roots.items():
        path = args.tmp / f"{key}.lean"
        path.write_text(template.replace("import Benitoite\n", f"import {root}\n"))
        written[key] = digest(path)
    print(json.dumps(written, indent=2))


if __name__ == "__main__":
    main()
