#!/usr/bin/env python3
"""比較用 manifest の小さい入力を CLI で実行し、結果と経路を照合する。"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def verify(repository, directory, manifest, binary, case, sample):
    command = [
        str(binary) if argument == manifest["benitoite_placeholder"] else argument
        for argument in case["samples"][sample]["command"]
    ]
    completed = subprocess.run(command, cwd=repository, capture_output=True, timeout=10)
    expected = (directory / manifest["expected_stdout"]).read_bytes()
    if completed.returncode != manifest["expected_exit_code"] or completed.stdout != expected:
        raise ValueError(
            f"{case['id']}/{sample}: exit={completed.returncode}, "
            f"stdout={completed.stdout!r}\n{completed.stderr.decode(errors='replace')}"
        )
    # 統計は本物の宣言から選ばれた経路を読む。成功の出力だけでは経路の誤記を検出できない。
    statistics = json.loads(completed.stderr)
    rounds = int(case["samples"][sample]["arguments"][manifest["repeat_argument"]])
    for declaration in case["declarations"]:
        component = directory.relative_to(repository) / "guests" / f"{declaration['guest']}.wasm"
        name = f"{component}#{declaration['function']}"
        function = statistics["functions"][name]
        routes = function["routes"]
        calls = rounds * declaration["calls_per_round"]
        if routes != {declaration["route"]: calls} or function["calls"] != calls:
            raise ValueError(f"{name}: unexpected route or missing calls: {function}")
    print(f"{case['id']}/{sample}: ok ({statistics['calls']} calls, {statistics['routes']})")


def main():
    directory = Path(__file__).resolve().parent
    repository = directory.parents[2]
    manifest = json.loads((directory / "manifest.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benitoite", type=Path, default=repository / "target/debug/benitoite")
    parser.add_argument("--case", action="append", help="contract or comparison id; repeatable")
    parser.add_argument(
        "--sample", action="append", choices=["zero", "small", "repeat"],
        help="default: small; repeatable; large inputs are reserved for the full measurement",
    )
    args = parser.parse_args()
    for guest in manifest["guests"]:
        for field, digest in [("source", "source_sha256"), ("binary", "sha256")]:
            path = directory / guest[field]
            if hashlib.sha256(path.read_bytes()).hexdigest() != guest[digest]:
                raise ValueError(f"fixture digest differs from manifest: {path}")
    cases = manifest["contracts"] + manifest["comparisons"]
    if args.case:
        unknown = set(args.case) - {case["id"] for case in cases}
        if unknown:
            parser.error(f"unknown cases: {', '.join(sorted(unknown))}")
        cases = [case for case in cases if case["id"] in args.case]
    binary = args.benitoite.resolve()
    for case in cases:
        for sample in args.sample or ["small"]:
            verify(repository, directory, manifest, binary, case, sample)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
