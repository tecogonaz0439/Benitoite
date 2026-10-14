#!/usr/bin/env python3
"""WIT の受け渡しの時間・RSS・実行統計を JSON に記録する。"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import threading
import signal
import shutil
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tools/bench/wit-transfer"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(command, timeout, allow_timeout=False):
    # wait4 はこの子の使用量を返すため、親の累積最大値や sysctl に依存しない。
    with tempfile.TemporaryDirectory(dir=ROOT / "target", prefix="wit-rss-") as directory:
        stdout_path, stderr_path = [Path(directory) / name for name in ["stdout", "stderr"]]
        started = time.perf_counter_ns()
        with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
            process = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                                       stdin=subprocess.DEVNULL)
            expired = threading.Event()

            def expire():
                expired.set()
                try:
                    os.kill(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

            timer = threading.Timer(timeout, expire)
            timer.daemon = True
            timer.start()
            try:
                _, status, usage = os.wait4(process.pid, 0)
                process.returncode = os.waitstatus_to_exitcode(status)
            finally:
                timer.cancel()
                if process.returncode is None:
                    process.kill()
                    process.wait()
            if expired.is_set() and not allow_timeout:
                raise subprocess.TimeoutExpired(command, timeout)
        wall = time.perf_counter_ns() - started
        stderr = stderr_path.read_text()
        rss = usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)
        return {"command": command, "wall_nanos": wall, "peak_rss_bytes": rss,
                "stdout": stdout_path.read_text(), "stderr": stderr,
                "exit_code": process.returncode, "timed_out": expired.is_set()}


def validate_stats(stats, case, rounds, version="final"):
    for declaration in case["declarations"]:
        name = (f"tools/bench/wit-transfer/guests/{declaration['guest']}.wasm"
                f"#{declaration['function']}")
        function = stats["functions"][name]
        count = rounds * declaration["calls_per_round"]
        route = declaration["route"]
        if version == "numbers" and route == "adapter":
            route = "dynamic"
        if function["calls"] != count:
            raise ValueError(f"unexpected calls or route: {name}: {function}")
        if version in {"start", "numbers"} and "routes" not in function:
            continue
        if function["routes"] != {route: count}:
            raise ValueError(f"unexpected calls or route: {name}: {function}")


def cli_variants(case, version="final"):
    if "cli_variants" not in case:
        return [] if version == "start" else [dict(case, cli_route="combined")]
    return [dict(case, script=v["script"], cli_route=v["route"],
                 declarations=[d for d in case["declarations"] if d["function"] in v["declarations"]])
            for v in case["cli_variants"] if version in v["versions"]]


def cli_sample(binary, case, sample, rounds, timeout, version="final", allow_failure=False):
    settings = case["samples"][sample]
    command = [str(binary), "run", "--diagnostics=json", "--wasm-stats",
               f"tools/bench/wit-transfer/{case['script']}",
               settings["arguments"][0], str(rounds)]
    result = capture(command, timeout, allow_timeout=allow_failure)
    result.update(case=case["id"], sample=sample, rounds=rounds,
                  cli_route=case["cli_route"], script=case["script"],
                  scope="single-benitoite-execution",
                  input=dict(settings, command=command,
                             arguments=[settings["arguments"][0], str(rounds)]))
    if allow_failure and result["exit_code"]:
        diagnostics, stats = [], None
        for line in result["stderr"].splitlines():
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(entry, dict) and "code" in entry:
                diagnostics.append(entry)
            elif isinstance(entry, dict) and "functions" in entry:
                stats = entry
        codes = sorted({d["code"] for d in diagnostics})
        result.update(status="failed", diagnostics=diagnostics, stats=stats,
                      failure_kind="timeout" if result["timed_out"] else
                      "resource-limit" if any(c in {"R0902", "R0904", "R0905", "R0906"} for c in codes) else
                      "internal-error" if result["exit_code"] == 3 else "execution-failure",
                      diagnostic_codes=codes)
        return result
    expected = (FIXTURES / "expected/ok.stdout").read_text()
    if result["exit_code"] or result["stdout"] != expected:
        raise ValueError(f"result mismatch: {case['id']}: {result['stdout']!r} {result['stderr']}")
    result["stats"] = json.loads(result.pop("stderr"))
    validate_stats(result["stats"], case, rounds, version)
    result["unreported_stats"] = [field for field in ["routes", "construction_bytes"]
                                  if field not in result["stats"]]
    result["status"] = "verified"
    return result


def version_manifest(path):
    data = json.loads(path.read_text())
    # 保存済みの実体を検査するだけで、再ビルドと strip は行わない。
    for artifact in data["artifacts"].values():
        for file_key, size_key, hash_key in [
            ("path", "size_bytes", "sha256"),
            ("stripped_path", "stripped_size_bytes", "stripped_sha256"),
        ]:
            binary = ROOT / artifact[file_key]
            if binary.stat().st_size != artifact[size_key] or digest(binary) != artifact[hash_key]:
                raise ValueError(f"saved artifact differs from manifest: {binary}")
    return {"manifest_path": str(path.relative_to(ROOT)), "manifest_sha256": digest(path),
            "manifest": data}


def validate_cost(data, case, rounds):
    if data["schema_version"] != 1 or data["case"] != case["id"]:
        raise ValueError("invalid cost schema")
    if data["host_conversion_scope"] != "adapter-codec-only; typed/dynamic host conversion is unmeasured and cannot be compared":
        raise ValueError("missing host conversion comparison restriction")
    expected = {d["function"]: d["route"] for d in case["declarations"]}
    observed = {}
    for measurement in data["measurements"]:
        function, route = measurement["function"], measurement["route"]
        if function not in expected or route not in [expected[function], "dynamic"]:
            raise ValueError(f"unexpected measured function/route: {function}/{route}")
        if (function, route) in observed:
            raise ValueError(f"duplicate measurement: {function}/{route}")
        observed[function, route] = True
        for field in ["prepare_nanos", "generation_nanos", "compile_nanos", "component_bytes"]:
            if type(measurement[field]) is not int or measurement[field] < 0:
                raise ValueError(f"invalid measurement: {field}")
        samples = measurement["samples"]
        if not samples or {s["round"] for s in samples} != set(range(rounds)):
            raise ValueError("missing same-session samples")
        for s in samples:
            for field in ["instantiate_nanos", "call_nanos", "fuel"]:
                if type(s[field]) is not int or s[field] < 0:
                    raise ValueError(f"invalid sample: {field}")
            for field in ["host_pack_nanos", "host_decode_nanos"]:
                value = s[field]
                if route == "adapter":
                    if type(value) is not int or value < 0:
                        raise ValueError(f"invalid adapter conversion time: {field}")
                elif value is not None:
                    raise ValueError(f"unmeasured host conversion must be null: {field}")
            if route == "adapter" and (
                not isinstance(s["transfer_bytes"], dict) or
                type(s["construction_bytes"]) is not int
            ):
                raise ValueError("missing adapter budgets")
    if set(observed) != {(name, route) for name, selected in expected.items()
                         for route in [selected, "dynamic"]}:
        raise ValueError("missing measured declaration")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true",
                        help="小さい入力・最終版・JSON の形式を数回だけ確認する")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--benitoite", type=Path, help="最終版。省略時は最終版だけをビルドする")
    parser.add_argument("--cost-example", type=Path, help="最終版の wit_transfer_cost")
    parser.add_argument("--case", action="append", help="契約または比較の ID。複数指定可")
    parser.add_argument("--iterations", type=int, default=5, help="別プロセスの試行回数")
    parser.add_argument("--rounds", type=int, default=20, help="同一実行内の呼び出し回数")
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--profile", choices=["debug", "release"], default="release")
    parser.add_argument("--sample", choices=["zero", "small", "large"], default="large")
    parser.add_argument("--versions-dir", type=Path, default=ROOT / "target/p3a-versions")
    args = parser.parse_args()
    if args.iterations < 1 or args.rounds < 1 or args.timeout <= 0:
        parser.error("iterations, rounds and timeout must be positive")
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    profile = "debug" if args.quick else args.profile
    iterations, rounds = (2, 3) if args.quick else (args.iterations, args.rounds)
    sample = "small" if args.quick else args.sample
    manifest = json.loads((FIXTURES / "manifest.json").read_text())
    cases = manifest["contracts"] + manifest["comparisons"]
    if args.case:
        unknown = set(args.case) - {c["id"] for c in cases}
        if unknown:
            parser.error(f"unknown cases: {sorted(unknown)}")
        cases = [c for c in cases if c["id"] in args.case]
    for guest in manifest["guests"]:
        for field, checksum in [("source", "source_sha256"), ("binary", "sha256")]:
            if digest(FIXTURES / guest[field]) != guest[checksum]:
                raise ValueError(f"fixture digest mismatch: {guest[field]}")
    if not args.benitoite or not args.cost_example:
        command = ["cargo", "build", "-p", "benitoite"]
        if profile == "release":
            command.append("--release")
        if not args.benitoite:
            command += ["--bin", "benitoite"]
        if not args.cost_example:
            command += ["--example", "wit_transfer_cost"]
        subprocess.run(command, cwd=ROOT, check=True)
    binary = (args.benitoite or ROOT / f"target/{profile}/benitoite").resolve()
    cost = (args.cost_example or ROOT / f"target/{profile}/examples/wit_transfer_cost").resolve()
    versions = {} if args.quick else {name: version_manifest(args.versions_dir.resolve() / name / "manifest.json")
                for name in ["start", "numbers", "adapter"]}
    measurements = []
    costs = []
    for case in cases:
        for trial in range(iterations):
            # 初回の別プロセスと、キャッシュを共有する一実行の反復を別の標本にする。
            for variant in cli_variants(case):
                for count in [1, rounds]:
                    result = cli_sample(binary, variant, sample, count, args.timeout)
                    result.update(version="final", trial=trial)
                    measurements.append(result)
            command = [str(cost), f"tools/bench/wit-transfer/{case['script']}", case["id"], str(rounds)]
            result = capture(command, args.timeout)
            if result["exit_code"]:
                raise ValueError(f"cost example failed: {result['stderr']}")
            data = json.loads(result.pop("stdout"))
            validate_cost(data, case, rounds)
            result.update(trial=trial, data=data, fixture="small-values.json",
                          scope="isolated-functions-small-input")
            costs.append(result)
        print(f"{case['id']}: results, routes, timings and RSS verified", file=sys.stderr)
    # quick では中間版を実行しない。本測定でも各版は保存済みの実体を直接使う。
    unavailable = []
    if not args.quick:
        for name, version in versions.items():
            saved = ROOT / version["manifest"]["artifacts"]["benitoite"]["path"]
            for case in cases:
                for variant in cli_variants(case, name):
                    check = capture([str(saved), "check", "--diagnostics=json",
                                     f"tools/bench/wit-transfer/{variant['script']}"], args.timeout)
                    if check["exit_code"]:
                        diagnostics = [json.loads(line) for line in check["stderr"].splitlines()]
                        errors = [d for d in diagnostics if d.get("severity") == "error"]
                        if check["exit_code"] == 2 and errors and all(
                            d.get("code") in {"E1008", "E1009", "E1010"} for d in errors
                        ):
                            unavailable.append({"version": name, "case": case["id"],
                                                "cli_route": variant["cli_route"],
                                                "reason": "unsupported-wit-contract", "check": check})
                            continue
                        raise ValueError(f"saved version check failed: {check}")
                    for trial in range(iterations):
                        for count in [1, rounds]:
                            result = cli_sample(saved, variant, sample, count, args.timeout, name,
                                                allow_failure=True)
                            result.update(version=name, trial=trial)
                            measurements.append(result)
    summaries = []
    keys = sorted({(m["version"], m["case"], m["cli_route"], m["rounds"]) for m in measurements})
    for version, case, route, count in keys:
        group = [m for m in measurements if
                 (m["version"], m["case"], m["cli_route"], m["rounds"]) == (version, case, route, count)]
        passed = [m for m in group if m["status"] == "verified"]
        summaries.append({"version": version, "case": case, "cli_route": route, "rounds": count,
                          "verified_trials": len(passed), "failed_trials": len(group) - len(passed),
                          "wall_median_nanos": statistics.median(m["wall_nanos"] for m in passed) if passed else None,
                          "peak_rss_median_bytes": statistics.median(m["peak_rss_bytes"] for m in passed) if passed else None})
    final_artifacts = {}
    for p in [binary, cost]:
        artifact = {"sha256": digest(p), "size_bytes": p.stat().st_size}
        if not args.quick:
            with tempfile.TemporaryDirectory(dir=ROOT / "target", prefix="wit-strip-") as directory:
                copy = Path(directory) / p.name
                shutil.copy2(p, copy)
                subprocess.run(["strip", str(copy)], check=True, capture_output=True)
                artifact.update(stripped_size_bytes=copy.stat().st_size,
                                stripped_sha256=digest(copy), strip_command=["strip", "TEMP_COPY"])
        final_artifacts[str(p)] = artifact
    document = {"schema_version": 2, "quick": args.quick, "platform": platform.platform(),
                "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "profile": profile, "default_features": True, "features": ["gc-mark-sweep"],
                "final_binaries": final_artifacts,
                "configuration_source": "default Cargo build" if not args.benitoite and not args.cost_example else "caller-supplied binaries; profile/features declared by caller",
                "source_sha256": {str(p.relative_to(ROOT)): digest(p) for p in [
                    ROOT / "Cargo.lock", Path(__file__).resolve(),
                    ROOT / "crates/benitoite/examples/wit_transfer_cost.rs",
                    FIXTURES / "expected/small-values.json"]},
                "unavailable": unavailable,
                "fixture_manifest_sha256": digest(FIXTURES / "manifest.json"),
                "versions": versions, "measurements": measurements, "isolated_costs": costs,
                "summaries": summaries,
                "limits": ["段別計時は最終版の小さい独立入力。CLI 全体の時間の内訳ではない。",
                           "RSS はプロセス全体の最大値。関数ごとのメモリではない。",
                           "typed/dynamic の転送・構築量は CLI stats を読む。独立例では null。",
                           "typed/dynamic のホスト変換は未測定（null）。補助の encode/decode との比較に使わない。",
                           "保存版の失敗は記録するが、成功の時間と RSS の中央値に含めない。",
                           "call は Wasmtime が行う canonical ABI の変換と post-return を含む。",
                           "quick の時間は道具の動作確認であり、性能の評価には使わない。"]}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x") as stream:
        json.dump(document, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(f"wrote {output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
