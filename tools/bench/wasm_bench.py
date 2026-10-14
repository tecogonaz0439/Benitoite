#!/usr/bin/env python3
"""入力の生成と結果の一致の確認を行い、JSON の三つの実装を比較する。"""

import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import re
import signal
import struct
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = ROOT / "tools/bench/wasm"
LIBRARIES = ROOT / "crates/benitoite/testdata/packages/libraries.files"
DIGEST = re.compile(r"digest=([0-9a-f]{64})")
TIMING = re.compile(r"first_ms=(\d+) rest_ms=(\d+) rounds=(\d+)")
RSS = re.compile(r"bench-rss: (\d+)")


def node_count(value):
    """対象の鍵も含め、WIT の節点を反復で数える。"""
    count = 0
    work = [value]
    while work:
        item = work.pop()
        count += 1
        if isinstance(item, dict):
            count += len(item)
            work.extend(item.values())
        elif isinstance(item, list):
            work.extend(item)
    return count


def generate_json(size, seed, destination):
    if size < 512:
        raise ValueError("JSON size must be at least 512 bytes")
    rng = random.Random(seed)
    records = []
    encoded = []
    used = 2
    while True:
        # 文字列も十分に含め、数だけの大量の節点を作らない。
        row = {
            "id": len(records),
            "label": f'é😀 row {rng.randrange(100000)} "quoted" \\ slash\n',
            "active": bool(rng.randrange(2)),
            "empty": None,
            "score": rng.randrange(-100000, 100000) / 8.0,
            "nested": [[rng.randrange(100), False], ["水", None]],
            "payload": "".join(rng.choice("abcdef0123456789") for _ in range(192)),
        }
        text = json.dumps(row, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        addition = len(text) + bool(encoded)
        if used + addition > size:
            break
        records.append(row)
        encoded.append(text)
        used += addition
    content = b"[" + b",".join(encoded) + b"]"
    content += b" " * (size - len(content))
    destination.write_bytes(content)
    return {"bytes": len(content), "seed": seed, "records": len(records),
            "nodes": node_count(records), "sha256": hashlib.sha256(content).hexdigest()}


def run_process(command, timeout):
    # RSS の積算を混ぜないよう、一つの子だけを測る既存の包みを使う。
    wrapped = [sys.executable, str(ROOT / "tools/bench/rss.py"), *map(str, command)]
    started = time.perf_counter()
    process = subprocess.Popen(wrapped, cwd=ROOT, text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               start_new_session=True,
                               env={**os.environ, "BENITOITE_DEV_IO_MODE": "direct"})
    timed_out = False
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        # RSS の包みだけを止めると実行中の子が残るため、同じプロセス群を止める。
        timed_out = True
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        stdout, stderr = process.communicate()
        stderr += f"\nprocess exceeded timeout of {timeout} seconds\n"

    elapsed = time.perf_counter() - started
    rss = RSS.search(stderr)
    digest = DIGEST.search(stdout)
    timing = TIMING.search(stdout)
    row = {"command": list(map(str, command)), "process_seconds": elapsed,
           "max_rss_bytes": int(rss.group(1)) if rss else None,
           "exit": process.returncode, "stdout": stdout, "stderr": stderr,
           "timed_out": timed_out, "timeout_seconds": timeout,
           "digest": digest.group(1) if digest else None}
    if timing:
        row.update(zip(("first_ms", "rest_ms", "rounds"), map(int, timing.groups())))
        row["per_iteration_ms"] = (row["rest_ms"] / (row["rounds"] - 1)
                                   if row["rounds"] > 1 else row["first_ms"])
    for line in stderr.splitlines():
        try:
            value = json.loads(line)
        except (ValueError, TypeError):
            continue
        if isinstance(value, dict) and value.get("wasm_stats"):
            row["wasm_stats"] = value
    if timed_out:
        row["limit"] = "timeout"
    return row


def compare(rows, label):
    if not rows or any(row["exit"] != 0 or row["digest"] is None for row in rows):
        raise RuntimeError(f"verification failed: {label}\n" + "\n".join(row["stderr"] for row in rows))
    if len({row["digest"] for row in rows}) != 1:
        raise RuntimeError(f"output mismatch: {label}\n" + "\n".join(row["stdout"] for row in rows))
    print(f"verified {label}: {rows[0]['digest']}", flush=True)


def float_samples():
    # 正規数の二の冪をすべてと、固定の非正規化数を符号の両側で調べる。
    values = [math.ldexp(1.0, exponent) for exponent in range(-1022, 1024)]
    rng = random.Random(232)
    bits = [1, 2, 3, (1 << 51), (1 << 52) - 1]
    bits += [rng.randrange(1, 1 << 52) for _ in range(64)]
    subnormals = [struct.unpack(">d", struct.pack(">Q", bits_value))[0] for bits_value in bits]
    return values + subnormals + [-value for value in subnormals] + [-0.0]


def suite(args, records):
    binary = Path(args.benitoite).resolve()
    cost = Path(args.wasm_cost).resolve()
    timeout = args.timeout
    differences = []
    timeouts = []

    def script(name, parameters, label, *, stats=True):
        flags = ["--wasm-stats"] if stats else []
        for option_name in ("memory", "fuel", "transfer"):
            value = getattr(args, f"wasm_{option_name}")
            if value is not None:
                flags.append(f"--wasm-{option_name}={value}")
        row = run_process([binary, "run", *flags, PROGRAMS / f"{name}.bnt", *parameters], timeout)
        row["label"] = label
        row["configured_limits"] = {"memory": args.wasm_memory or "64MiB", "fuel": args.wasm_fuel or "10000000000", "transfer": args.wasm_transfer or "256MiB"}
        records.append(row)
        print(f"{label}: exit={row['exit']} process={row['process_seconds']:.3f}s", flush=True)
        return row

    def accept(row):
        if row["exit"] == 0:
            return True
        if row.get("timed_out"):
            timeouts.append(row["label"])
            return False
        if not args.quick and ("R0905" in row["stderr"] or "R0904" in row["stderr"]):
            row["limit"] = "R0905" if "R0905" in row["stderr"] else "R0904"
            print(f"limit recorded: {row['label']}", flush=True)
            return False
        raise RuntimeError(f"{row['label']} failed\n{row['stdout']}\n{row['stderr']}")

    def verify(rows, label):
        available = [row for row in rows if accept(row)]
        if available:
            compare(available, label)
        return available

    def measured_group(names, parameters, expected, label):
        if not names:
            return
        rounds = {}
        for name in names:
            if args.quick or args.rounds is not None:
                rounds[name] = args.rounds or 2
                continue
            # 時計の分解能より長い区間で較正し、課題と大きさごとに回数を決める。
            count = 2
            while True:
                row = script(name, [*parameters, str(count)], f"calibrate-{label}-{name}", stats=False)
                row["phase"] = "calibration"
                if not accept(row):
                    break
                compare([expected[name], row], row["label"])
                if row["rest_ms"] >= 1000:
                    rounds[name] = count
                    break
                count = (max(count * 2, math.ceil(1200 / row["per_iteration_ms"]) + 1)
                         if row["rest_ms"] >= 50 else count * 4)
        samples = {name: [] for name in names}
        for trial in range(args.samples):
            # 回ごとに先頭をずらし、二巡目は逆順にする。
            order = names[trial % len(names):] + names[:trial % len(names)]
            if (trial // len(names)) % 2:
                order = order[::-1]
            for name in order:
                if name not in rounds:
                    continue
                row = script(name, [*parameters, str(rounds[name])], f"{label}-{name}-{trial}", stats=False)
                row.update(phase="measurement", sample=trial)
                if not accept(row):
                    continue
                compare([expected[name], row], row["label"])
                samples[name].append(row)
        for name, rows in samples.items():
            if rows:
                result = summary(f"{label}-{name}", rows)
                result["configured_limits"] = expected[name]["configured_limits"]
                wasm_stats = expected[name].get("wasm_stats")
                if wasm_stats is None:
                    raise RuntimeError(f"{label}-{name}: verification WASM statistics missing")
                result["wasm_stats"] = wasm_stats
                records.append(result)

    with tempfile.TemporaryDirectory(prefix="benitoite-wasm-", dir=ROOT / "target") as temporary:
        directory = Path(temporary)
        sizes = [1024] if args.quick else [1024, 100_000, 10_000_000]
        for size in sizes:
            path = directory / f"json-{size}.json"
            metadata = generate_json(size, args.seed, path)
            records.append({"input": "json", **metadata})
            print(f"input JSON: {json.dumps(metadata)}", flush=True)
            # 計時の前に、parse と stringify の往復を三者で確認する。
            checks = [script(f"json-{version}", ["verify", path, "1"], f"verify-json-{size}-{version}")
                      for version in "abc"]
            verify(checks, f"json-{size}")
            for task in ("parse", "stringify", "read", "pretty", "validate"):
                checks = {f"json-{version}": script(f"json-{version}", [task, path, "1"],
                                                  f"verify-json-{size}-{task}-{version}") for version in "abc"}
                available = verify(list(checks.values()), f"json-{size}-{task}")
                expected = {name: row for name, row in checks.items() if row in available}
                measured_group(list(expected), [task, path], expected, f"json-{size}-{task}")

        samples = float_samples()
        for offset in range(0, len(samples), 128):
            path = directory / "floats.json"
            path.write_text(json.dumps(samples[offset:offset + 128]), encoding="utf-8")
            checks = [script(f"json-{version}", ["verify", path, "1"], f"floats-{offset}-{version}")
                      for version in "abc"]
            try:
                verify(checks, f"floats-{offset}")
            except RuntimeError:
                # 差異を隠さず個々の出力を残し、残りの道具も確認してから失敗を返す。
                actual = {}
                for version in "abc":
                    row = script(f"json-{version}", ["canonical", path, "1"], f"float-difference-{offset}-{version}")
                    if accept(row):
                        actual[version.upper()] = json.loads(row["stdout"], parse_float=str, parse_int=str)
                for index, values in enumerate(zip(*actual.values())):
                    if len(set(values)) > 1:
                        difference = {"float_sample": offset + index,
                                      "input": repr(samples[offset + index]), **dict(zip(actual, values))}
                        differences.append(difference)
                        records.append(difference)
                        print(f"difference: {json.dumps(difference)}", flush=True)
        print(f"float samples checked: {len(samples)} (2046 powers of two), differences={len(differences)}", flush=True)
        if args.quick:
            path = directory / "deep.json"
            path.write_text("null", encoding="utf-8")
            verify([script(f"json-{version}", ["deep", path, "1"], f"deep-1000-{version}")
                    for version in "ab"], "compact-deep-1000")
            path = directory / "depth-object.json"
            path.write_text('{"a":' * 127 + "0" + "}" * 127, encoding="utf-8")
            verify([script(f"json-{version}", ["verify", path, "1"], f"depth-object-127-{version}")
                    for version in "ab"], "parse-object-depth-127")

        hash_sizes = [0, 1024] if args.quick else [0, 1024, 1_000_000, 6_000_000, 32 * 1024 * 1024]
        for size in hash_sizes:
            path = directory / "bytes.bin"
            path.write_bytes((bytes(range(256)) * ((size + 255) // 256))[:size])
            versions = ("a", "c-fast") if size > 6_000_000 else ("a", "c-fast", "c-list")
            checks = [script(f"hash-{version}", [path, "1"], f"verify-hash-{size}-{version}")
                      for version in versions]
            available = verify(checks, f"hash-{size}")
            expected = {f"hash-{version}": row for version, row in zip(versions, checks) if row in available}
            measured_group(list(expected), [path], expected, f"hash-{size}")

        path = directory / "regex.txt"
        path.write_text("abc123 水 def42\n", encoding="utf-8")
        versions = ("a", "c-resource", "c-once")
        for task, content in (("match", "abc123 水 def42\n"),
                              ("count", "abc123 水 def42\n" * (4 if args.quick else 150_000)),
                              ("find-all", "abc123 水 def42\n" * (4 if args.quick else 1000))):
            path.write_text(content, encoding="utf-8")
            checks = {f"regex-{version}": script(f"regex-{version}", [task, path, "1"],
                                                 f"verify-regex-{task}-{version}") for version in versions}
            available = verify(list(checks.values()), f"regex-{task}")
            expected = {name: row for name, row in checks.items() if row in available}
            measured_group(list(expected), [task, path], expected, f"regex-{task}")

        commands = [[mode] for mode in ("calls", "fuel", "fuzzy")]
        commands += [["compile", str(LIBRARIES / f"{name}/wasm/{name.removeprefix('wasm-')}.wasm")]
                     for name in ("wasm-hash", "wasm-json", "wasm-regex", "fuzzy")]
        synthetic_sizes = [1024] if args.quick else [mib * 1024 * 1024 for mib in (1, 4, 16, 64)]
        if args.include_256_mib:
            synthetic_sizes.append(256 * 1024 * 1024)
        for size in synthetic_sizes:
            for kind in ("code", "data", "nop"):
                path = directory / f"{kind}-{size}.wasm"
                row = run_process([cost, "synthesize", str(size), kind, path], timeout)
                row["label"] = f"synthesize-{kind}-{size}"
                records.append(row)
                if accept(row):
                    commands.append(["compile", str(path)])
        # 生成プロセスの作業領域を、コンパイルの最大 RSS に混ぜない。
        for command in commands:
            rows = []
            for trial in range(args.samples):
                row = run_process([cost, *(["--quick"] if args.quick else []), *command], timeout)
                row.update(label="wasm-cost-" + "-".join(command), sample=trial, phase="measurement")
                compilation = re.search(r"compile .*nanos=(\d+)", row["stdout"])
                if compilation:
                    row["compile_nanos"] = int(compilation.group(1))
                records.append(row)
                if accept(row):
                    rows.append(row)
                print(row["stdout"].rstrip(), flush=True)
            if rows:
                records.append(summary("wasm-cost-" + "-".join(command), rows))
    if timeouts:
        raise RuntimeError(f"{len(timeouts)} processes timed out: {', '.join(timeouts)}")

    if differences:
        raise RuntimeError(f"A/B/C float formatting differs for {len(differences)} samples; see the recorded outputs")


def summary(label, rows):
    result = {"summary": label, "samples": len(rows)}
    rounds = {row["rounds"] for row in rows if "rounds" in row}
    if len(rounds) > 1:
        raise ValueError(f"mixed iteration counts: {label}")
    if rounds:
        result["rounds"] = rounds.pop()
    for key in ("first_ms", "per_iteration_ms", "process_seconds", "max_rss_bytes", "compile_nanos"):
        values = [row[key] for row in rows if row.get(key) is not None]
        if values:
            result[key] = {"median": statistics.median(values), "minimum": min(values)}
    return result


def machine_info():
    def read(command):
        try:
            return subprocess.check_output(command, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
        except (OSError, subprocess.CalledProcessError):
            return None
    memory_description = None
    if sys.platform == "darwin":
        cpu = read(["sysctl", "-n", "machdep.cpu.brand_string"])
        memory = read(["sysctl", "-n", "hw.memsize"])
        if not cpu or not memory:
            # sandbox が sysctl を拒否する場合も、表示用の機械の情報を残す。
            hardware = read(["system_profiler", "SPHardwareDataType", "-json"])
            for row in json.loads(hardware or "{}").get("SPHardwareDataType", []):
                cpu = cpu or row.get("chip_type") or row.get("cpu_type")
                memory_description = row.get("physical_memory")
    else:
        cpu = platform.processor() or platform.machine()
        try:
            for line in Path("/proc/cpuinfo").read_text().splitlines():
                key, _, value = line.partition(":")
                if key.strip().lower() in ("model name", "hardware"):
                    cpu = value.strip()
                    break
        except OSError:
            pass
        memory = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
    return {"cpu": cpu or platform.machine(), "logical_cpus": os.cpu_count(), "memory_bytes": int(memory) if memory else None, "memory_description": memory_description,
            "commit": read(["git", "rev-parse", "HEAD"]),
            "dirty": bool(read(["git", "status", "--porcelain"])),
            "rustc": read(["rustc", "--version"])}


def probe(args, records):
    timeouts = []
    with tempfile.TemporaryDirectory(prefix="benitoite-wasm-probe-", dir=ROOT / "target") as temporary:
        path = Path(temporary) / "json-10mb.json"
        records.append({"input": "json", **generate_json(10_000_000, args.seed, path)})
        print("| limits | task | result |")
        print("|---|---|---|")
        for label, memory, transfer in (("default", "64MiB", "256MiB"), ("raised", "1GiB", "1GiB")):
            for task in ("verify", "parse", "stringify", "read", "pretty", "validate"):
                flags = ["--wasm-stats"]
                if label == "raised":
                    flags += [f"--wasm-memory={memory}", f"--wasm-transfer={transfer}"]
                if args.wasm_fuel:
                    flags.append(f"--wasm-fuel={args.wasm_fuel}")
                row = run_process([Path(args.benitoite).resolve(), "run", *flags,
                                   PROGRAMS / "json-c.bnt", task, path, "1"], args.timeout)
                row.update(label=f"probe-{label}-{task}", configured_limits={"memory": memory, "transfer": transfer, "fuel": args.wasm_fuel or "10000000000"})
                if row["exit"]:
                    row["limit"] = ("timeout" if row["timed_out"] else "R0905" if "R0905" in row["stderr"]
                                    else "R0904" if "R0904" in row["stderr"] else "error")
                if row["timed_out"]:
                    timeouts.append(row["label"])
                records.append(row)
                print(f"| {label} | {task} | {row.get('limit', 'ok')} |", flush=True)
                if row.get("limit") == "error":
                    raise RuntimeError(row["stderr"])
    if timeouts:
        raise RuntimeError(f"probe processes timed out: {timeouts}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command")
    generator = commands.add_parser("gen-json", help="generate a deterministic mixed JSON array")
    generator.add_argument("--bytes", type=int, required=True)
    generator.add_argument("--seed", type=int, required=True)
    generator.add_argument("output", type=Path)
    parser.add_argument("--probe", action="store_true", help="run each 10 MB C task once at default and raised limits")
    parser.add_argument("--samples", type=int, default=None, help="process samples per combination (default: 5; quick: 1)")
    parser.add_argument("--wasm-memory", help="CLI memory limit (default: 64MiB)")
    parser.add_argument("--wasm-fuel", help="CLI fuel limit (default: 10000000000)")
    parser.add_argument("--wasm-transfer", help="CLI transfer budget (default: 256MiB)")
    parser.add_argument("--build-features", default="default (gc-mark-sweep)", help="features of the measured binaries")
    parser.add_argument("--quick", action="store_true", help="verify tools using small inputs only")
    parser.add_argument("--benitoite", default="target/release/benitoite")
    parser.add_argument("--wasm-cost", default="target/release/examples/wasm_cost")
    parser.add_argument("--rounds", type=int, default=None)
    parser.add_argument("--seed", type=int, default=212)
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--include-256-mib", action="store_true")
    parser.add_argument("--output", type=Path, help="write a new JSON record; never overwrite")
    args = parser.parse_args()
    if args.command == "gen-json":
        if args.output.exists():
            parser.error(f"output already exists: {args.output}")
        print(json.dumps(generate_json(args.bytes, args.seed, args.output)))
        return 0
    args.samples = args.samples if args.samples is not None else (1 if args.quick else 5)
    if (args.rounds is not None and args.rounds < 1) or args.samples < 1 or args.timeout <= 0:
        parser.error("rounds, samples, and timeout must be positive")
    if args.quick and args.rounds is not None and args.rounds > 3:
        parser.error("--quick permits at most three rounds")
    if args.include_256_mib and args.quick:
        parser.error("256 MiB cannot be requested with --quick")
    if args.probe and args.quick:
        parser.error("--probe and --quick are mutually exclusive")
    # 排他的に開いて、開始の時点で既存の記録を保護する。
    output = args.output.open("x", encoding="utf-8") if args.output else None
    records = []
    report = {"quick": args.quick, "started": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "platform": platform.platform(), "python": sys.version, "seed": args.seed,
              "rounds": args.rounds, "samples": args.samples, "probe": args.probe,
              "build_features": args.build_features, "records": records}
    try:
        report.update(machine_info())
        for name in ("wasm-hash", "wasm-json", "wasm-regex", "fuzzy"):
            path = LIBRARIES / f"{name}/wasm/{name.removeprefix('wasm-')}.wasm"
            content = path.read_bytes()
            records.append({"component": name, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()})
        report["benitoite_bytes"] = Path(args.benitoite).stat().st_size
        if args.probe:
            probe(args, records)
        else:
            suite(args, records)
        report["status"] = "ok"
        return 0
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        report["status"] = "failed"
        report["error"] = str(error)
        print(error, file=sys.stderr)
        return 1
    finally:
        if output:
            json.dump(report, output, ensure_ascii=False, indent=2)
            output.write("\n")
            output.close()


if __name__ == "__main__":
    raise SystemExit(main())
