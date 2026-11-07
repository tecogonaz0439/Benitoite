#!/usr/bin/env python3
"""区間の比較器のうち Rust の書き出し（material・manifest・観測・対応表・VM の地点）を読む部分を、新しい書き出しに当てる。

`formal/tests/test_interval_exchange.py` の `exercise` のうち、Rust の書き出しを読む部分（VM の比較・
実ソースの対応・実ソースの全解析の比較）だけを呼ぶ。固定入力（`fixtures`）の比較は呼ばない。
区間の比較器（`intervalDiff`）と処理系の CLI を使う。

使い方: `interval_readers.py <作業木の根> <VM の書き出し> <対応の書き出し> <出力のディレクトリ> [<実ソースの書き出し>...]`
"""
import json
import runpy
import sys
import time
from pathlib import Path


def main():
    root, export, identity, output = map(Path, sys.argv[1:5])
    sources = [Path(p) for p in sys.argv[5:]]
    tests = root / "formal/tests"
    sys.path.insert(0, str(tests))
    exchange = runpy.run_path(str(tests / "test_interval_exchange.py"))
    import interval_range_vm
    import interval_shift_vm
    import interval_source_compare
    import interval_vm_compare
    executable = (root / "formal/.lake/build/bin/intervalDiff").resolve()
    cli = (root / "target/debug/benitoite").resolve()
    output.mkdir(parents=True, exist_ok=False)
    rows = []

    def run(label, call):
        directory = output / label
        directory.mkdir()
        runner = exchange["Runner"](directory, executable)
        start = time.monotonic()
        call(runner)
        rows.append({"step": label, "calls": runner.calls, "seconds": round(time.monotonic() - start, 3)})
        print(json.dumps(rows[-1]), flush=True)

    run("vm", lambda r: interval_vm_compare.exercise(r, export, cli))
    run("vm-range", lambda r: interval_range_vm.exercise(r, export / "range", cli))
    run("vm-shifts", lambda r: interval_shift_vm.exercise(r, export / "shifts", cli))
    run("source", lambda r: exchange["exercise_source"](r, identity))
    for index, source in enumerate(sources):
        run(f"real-source-{index}", lambda r, s=source: interval_source_compare.exercise(r, s))
    (output / "summary.json").write_text(json.dumps(rows, indent=1) + "\n")


if __name__ == "__main__":
    main()
