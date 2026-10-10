#!/usr/bin/env python3
"""性能の関門の測定（設計書 07-02「性能の関門」）。

fib(35) と loop（1,500 万回）を、比べる版ごとに交互に走らせ、時間の中央値を出す。
初回リリース版の版は examples/stage1_bench を、最小実行版の VM（`d4668a9^`）は CLI の `run` を使う。
初回リリース版の版は実行の段の時間（run_nanos）と経過時間の両方を、最小実行版の VM は経過時間を記録する。

使い方:
    python3 tools/bench/gate.py --version r15=PATH/stage1_bench --version head=PATH/stage1_bench \\
        --legacy PATH/benitoite --legacy-programs PATH/tools/bench/programs --iterations 10 --output OUT.json

最小実行版の VM の作り方:
    git archive 'd4668a9^' | tar -x -C LEGACY_SRC
    cargo build --release -p benitoite --manifest-path LEGACY_SRC/Cargo.toml --target-dir LEGACY_BUILD
"""

import argparse
import json
import os
import re
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = ROOT / "tools" / "bench" / "programs"
INPUTS = {"fib": 35, "loop": 15_000_000}
EXPECTED = {"fib": b"9227465\n", "loop": f"{15_000_000 * 14_999_999 // 2}\n".encode()}


def commands(args, name):
    out = {}
    for label, binary in args.version:
        out[label] = [binary, "--factor", "100", "--", str(PROGRAMS / f"{name}.bnt"), str(INPUTS[name])]
    if args.legacy:
        out["legacy"] = [str(args.legacy), "run", str(args.legacy_programs / f"{name}.bnt"), str(INPUTS[name])]
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", action="append", default=[], type=lambda s: tuple(s.split("=", 1)),
                        help="LABEL=PATH（初回リリース版の stage1_bench）。複数指定できる")
    parser.add_argument("--legacy", type=Path)
    parser.add_argument("--legacy-programs", type=Path)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if bool(args.legacy) != bool(args.legacy_programs):
        parser.error("--legacy and --legacy-programs must be specified together")
    env = dict(os.environ, BENITOITE_DEV_IO_MODE="direct")
    # 一度ずつ走らせて出力を確かめ、温める。
    for name in INPUTS:
        for label, cmd in commands(args, name).items():
            process = subprocess.run(cmd, capture_output=True, env=env, check=True)
            if process.stdout != EXPECTED[name]:
                raise SystemExit(f"output mismatch: {label} {name}")
    samples = {}
    for i in range(args.iterations):
        for name in INPUTS:
            for label, cmd in commands(args, name).items():
                started = time.perf_counter_ns()
                process = subprocess.run(cmd, capture_output=True, env=env, check=True)
                wall = time.perf_counter_ns() - started
                if process.stdout != EXPECTED[name]:
                    raise SystemExit(f"output mismatch: {label} {name}")
                row = samples.setdefault(f"{label}/{name}", {"wall": [], "run": []})
                row["wall"].append(wall)
                found = re.search(rb"run_nanos=(\d+)", process.stderr)
                if found:
                    row["run"].append(int(found.group(1)))
        print(f"round {i + 1}", flush=True)
    args.output.write_text(json.dumps({"inputs": INPUTS, "samples": samples}, indent=1) + "\n")
    for key, row in samples.items():
        run = f" run median {statistics.median(row['run']) / 1e9:.3f} s" if row["run"] else ""
        print(f"{key}: wall median {statistics.median(row['wall']) / 1e9:.3f} s{run}")


if __name__ == "__main__":
    main()
