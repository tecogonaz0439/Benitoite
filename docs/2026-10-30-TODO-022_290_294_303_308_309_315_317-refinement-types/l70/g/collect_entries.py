#!/usr/bin/env python3
"""7入口を別々に読み、入口固有の依存と公理を一時領域に書き出す。"""
import argparse
import datetime
import json
import subprocess
import time
from records import HERE, ROOT, ENTRIES, audit, digest, write


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=__import__("pathlib").Path, required=True)
    parser.add_argument("--mode", choices=["graph", "audit"], required=True)
    args = parser.parse_args()
    template = (HERE / ("graph.lean" if args.mode == "graph" else "axioms.lean")).read_text()
    # 既定のBenitoite全環境は別の一回で記録する。ここでは実行ファイルと
    # その共有層だけを追加し、mainの衝突を避けて各入口を個別に読む。
    if args.mode == "graph":
        template = template.replace('mod.startsWith "Benitoite" ||', 'false ||')
    else:
        template = template.replace('n.toString.startsWith "Benitoite"',
            '["DesugarDiff", "BuiltinCheck", "CoverageDiff", "CoverageProgramDiff", "SurfaceCheck", "IntervalDiff"].any n.toString.startsWith')
    rows = []
    for name, module in ENTRIES.items():
        source = args.tmp / (name + "-" + args.mode + ".lean")
        output = source.with_suffix(".log")
        source.write_text(template.replace("import Benitoite\n", "import Benitoite\nimport " + module + "\n", 1))
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        begin = time.monotonic()
        with output.open("w") as stream:
            result = subprocess.run(["lake", "env", "lean", "-M", "12288", str(source)],
                                    cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
        row = {"entry": name, "started": started, "seconds": round(time.monotonic() - begin, 3),
               "exit": result.returncode, "output": digest(output)}
        if args.mode == "audit" and result.returncode == 0:
            row["audit"] = audit(output)
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        if result.returncode:
            break
    write(HERE / ("entry-" + args.mode + ".json"), rows)
    assert len(rows) == len(ENTRIES) and all(r["exit"] == 0 for r in rows)


if __name__ == "__main__":
    main()
