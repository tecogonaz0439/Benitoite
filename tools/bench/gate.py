#!/usr/bin/env python3
"""性能の関門の測定（設計書 07-02「性能の関門」）。

fib(35) と loop（1,500 万回）を、比べる版ごとに交互に走らせ、中央値と最小値を出す。
比べる版は examples/bench_run を、最小実行版の VM（`d4668a9^`）は CLI の `run` を使う。
bench_run の版は実行の段の時間（run_nanos）と経過時間の両方を、最小実行版の VM は経過時間を記録する。

使い方:
    python3 tools/bench/gate.py --version before=PATH/bench_run --version head=PATH/bench_run \\
        --legacy PATH/benitoite --legacy-programs PATH/tools/bench/programs --iterations 10 --output OUT.json

最小実行版の VM の作り方:
    git archive 'd4668a9^' | tar -x -C LEGACY_SRC
    cargo build --release -p benitoite --manifest-path LEGACY_SRC/Cargo.toml --target-dir LEGACY_BUILD
"""

import argparse
import json
import os
import statistics
import subprocess
import time
from pathlib import Path

import run

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = ROOT / "tools" / "bench" / "programs"
INPUTS = {"fib": 35, "loop": 15_000_000}
EXPECTED = {"fib": b"9227465\n", "loop": f"{15_000_000 * 14_999_999 // 2}\n".encode()}


def commands(args, name):
    out = {}
    for label, binary in args.version:
        out[label] = [binary, "--trigger-factor=100", "--io-mode=direct", "--",
                      str(PROGRAMS / f"{name}.bnt"), str(INPUTS[name])]
    if args.legacy:
        out["legacy"] = [str(args.legacy), "run", str(args.legacy_programs / f"{name}.bnt"), str(INPUTS[name])]
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", action="append", default=[], metavar="LABEL=PATH/bench_run",
                        help="LABEL=PATH/bench_run。複数指定できる")
    parser.add_argument("--legacy", type=Path)
    parser.add_argument("--legacy-programs", type=Path)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    versions = []
    labels = set()
    for version in args.version:
        label, separator, binary = version.partition("=")
        if not separator or not label or not binary:
            parser.error("--version must be LABEL=PATH/bench_run")
        if label in labels or (label == "legacy" and args.legacy):
            parser.error(f"duplicate version label: {label}")
        labels.add(label)
        versions.append((label, binary))
    args.version = versions
    if bool(args.legacy) != bool(args.legacy_programs):
        parser.error("--legacy and --legacy-programs must be specified together")
    if not args.version and not args.legacy:
        parser.error("at least one --version or --legacy is required")
    if args.iterations <= 0:
        parser.error("--iterations must be positive")
    env = dict(os.environ)
    legacy_env = dict(env, BENITOITE_DEV_IO_MODE="direct")

    def sample(label, cmd, name):
        started = time.perf_counter_ns()
        process = subprocess.run(cmd, capture_output=True,
                                 env=legacy_env if label == "legacy" and args.legacy else env, check=True)
        wall = time.perf_counter_ns() - started
        if process.stdout != EXPECTED[name]:
            raise SystemExit(f"output mismatch: {label} {name}")
        runtime = None
        if not (label == "legacy" and args.legacy):
            try:
                runtime = run.parse_bench_stats(process.stderr)["run_nanos"]
            except RuntimeError as error:
                raise SystemExit(f"invalid bench_run statistics: {label} {name}: {error}") from error
        return wall, runtime

    # 一度ずつ出力と統計を確かめて温め、測定の標本には含めない（設計書 07-02「性能の関門」）。
    for name in INPUTS:
        for label, cmd in commands(args, name).items():
            sample(label, cmd, name)
    samples = {}
    for i in range(args.iterations):
        for name in INPUTS:
            for label, cmd in commands(args, name).items():
                wall, runtime = sample(label, cmd, name)
                row = samples.setdefault(f"{label}/{name}", {"wall": [], "run": []})
                row["wall"].append(wall)
                if runtime is not None:
                    row["run"].append(runtime)
        print(f"round {i + 1}", flush=True)
    summaries = {
        key: {metric: {"median": statistics.median(values), "min": min(values)}
              for metric, values in row.items() if values}
        for key, row in samples.items()
    }
    args.output.write_text(json.dumps({
        "inputs": INPUTS,
        "versions": {label: str(binary) for label, binary in args.version},
        "legacy": str(args.legacy) if args.legacy else None,
        "revision": run.git_revision(),
        "system": run.collect_system_info(),
        "samples": samples,
        "summaries": summaries,
    }, indent=1) + "\n")
    for key, summary in summaries.items():
        values = " ".join(f"{metric} median {stats['median'] / 1e9:.3f} s min {stats['min'] / 1e9:.3f} s"
                          for metric, stats in summary.items())
        print(f"{key}: {values}")


if __name__ == "__main__":
    main()
