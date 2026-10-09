#!/usr/bin/env python3
"""R33: reuse bench_run, run.py and the R12 workloads; default to one trial."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import time

import run
import stage1


def default_plan():
    rows = []
    for name in run.NAMES + run.FIRST_RELEASE_NAMES:
        value = run.BENCH_INPUTS[name]
        args = list(value) if isinstance(value, tuple) else [value]
        if name == "lines":
            args = [f"@lines:{value}"]
        rows.append(dict(label=name, name=name, args=args))
    for name in stage1.VM_NAMES[6:]:
        rows.append(dict(label=name, name=name, args=[stage1.INPUTS[name]]))
    for busy in (0, 1):
        for clients in (1, 8):
            rows.append(dict(label=f"http-{busy}-{clients}", name="http",
                             args=[run.BENCH_INPUTS["http"][0], busy], clients=clients))
    return rows


def expected(item, arguments):
    name = item["name"]
    if run.has_comparators(name):
        # Independently implemented Rust also checks the full-size output.
        command = [str(run.PROGRAMS / "rust/target/release" / name), *arguments]
        started = time.perf_counter()
        output = run.require_success(command)
        return output, dict(command=command, wall_seconds=time.perf_counter() - started)
    if name in stage1.VM_NAMES:
        return stage1.expected(name, arguments), None
    if name.startswith("handler-") or name == "tasks":
        value = 1
        work = int(arguments[1] if name == "tasks" else arguments[0])
        for _ in range(work):
            value = (value * 17 + 11) % 65521
        if name == "tasks":
            value *= int(arguments[0])
        elif len(arguments) > 2:
            value *= int(arguments[2])
        return f"{value}\n".encode(), None
    if name == "cycle":
        return f"{arguments[0]}\n".encode(), None
    raise ValueError(f"unknown workload: {name}")


def sample(tool, source, arguments, options, output, timeout):
    command = [tool, *options, str(source), *arguments]
    wrapped = run.memory_wrapper(command)
    started = time.perf_counter_ns()
    process = subprocess.Popen(wrapped or command, cwd=run.ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=os.name == "posix")
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
        process.communicate()
        raise
    wall = time.perf_counter_ns() - started
    if process.returncode:
        raise RuntimeError(f"exit={process.returncode}: {stderr.decode(errors='replace')}")
    if stdout != output:
        raise RuntimeError(f"output mismatch: expected {output[:200]!r}, got {stdout[:200]!r}")
    stats = run.parse_bench_stats(stderr)
    match = re.search(rb"^bench-pauses: *(.*)$", stderr, re.MULTILINE)
    if match is None:
        raise RuntimeError("raw pause samples missing; rebuild bench_run")
    pauses = [int(p) for p in match.group(1).split(b",") if p.strip()]
    if len(pauses) != stats["pause_count"] or sum(pauses) != stats["pause_total_nanos"]:
        raise RuntimeError("raw pause samples disagree with summary")
    return dict(stats, wall_nanos=wall, pause_nanos=pauses, command=command)


def render(path, data):
    timing, heap, old = [], [], []
    historical = json.loads((run.RESULTS / "2026-10-05-stage1-5b300d4-timing.json").read_text())
    previous = {row["name"]: row for row in historical["rows"] if row["config"] == "MS-k1"}
    for row in data["rows"]:
        if row.get("error"):
            timing.append([row["label"], " ".join(map(str, row["args"])), "失敗", row["error"][:250]])
            continue
        samples = row["samples"]
        median = lambda k: statistics.median(s[k] for s in samples)
        pauses = [p for s in samples for p in s.get("pause_nanos", [])]
        percentiles = [stage1.percentile(pauses, p) for p in (50, 95, 99)]
        maximum = max(pauses) if pauses else None
        row["aggregate"] = {k: median(k) for k in samples[0]
                            if isinstance(samples[0][k], (int, float)) and all(k in s for s in samples)}
        row["aggregate"].update(pause_pooled_p50=percentiles[0], pause_pooled_p95=percentiles[1],
                                pause_pooled_p99=percentiles[2], pause_all_max=maximum,
                                rss_max=max((s["rss"] for s in samples if s.get("rss") is not None), default=None))
        timing.append([row["label"], " ".join(map(str, row["args"])), f"{median('run_nanos') / 1e9:.6f}",
                       row.get("output", "HTTP 200 / ok")])
        heap.append([row["label"], *[median(k) for k in ("allocations", "allocated_bytes", "live_bytes",
                     "peak_heap_bytes", "roots_traced", "collections", "frees")], row["aggregate"]["rss_max"],
                     len(pauses), *[None if p is None else f"{p / 1e6:.6f}" for p in (*percentiles, maximum)],
                     f"{median('pause_total_nanos') / 1e6:.6f}"])
        if row["label"] == row["name"] and row["name"] in previous:
            p = previous[row["name"]]
            old.append([row["name"], historical["inputs"][row["name"]], row["args"],
                        f"{p['run_nanos'] / 1e9:.6f}", f"{median('run_nanos') / 1e9:.6f}",
                        "同じ入力" if list(map(str, historical['inputs'][row['name']])) == list(map(str, row['args'])) else "入力が異なる"])
    title = "R33 メモリの測り直し" if data["measure"] else "R33 と完了時の測定の短い試行（本測定ではない）"
    if data.get("profile_directory"):
        title = "CPU プロファイルの採取（時間の本測定には使わない）"
    document = [f"# {title}\n", f"日付: {data['date']}。コミット: `{data['revision']}`。標本数: {data['iterations']}。",
                "既定 release、MS-k1。通常の VM は stress なし。cycle-self/pair/ring/list は R12 のヒープ API の単位測定で stress を有効にする。RSS は独立した Python ラッパーの子プロセスの getrusage。"
                "実行時間は bench_run 内の run_nanos。wall は RSS ラッパーの起動も含む。",
                "## 環境\n\n" + run.markdown_table(["項目", "値"], list(data["environment"].items())),
                "## 実行と出力\n\n" + run.markdown_table(["負荷", "入力", "実行 (秒)", "出力または失敗"], timing),
                "println の出力は独立した Rust 版と全バイトを照合し、SHA-256 を記録する。"
                "HTTP は要求ごとに状態 200 と本体 ok、指定応答数を照合する。",
                "## 回収と保持量\n\n" + run.markdown_table(
                    ["負荷", "確保回数", "累積確保 bytes", "最後の生存 bytes", "最大ヒープ bytes", "辿った根", "回収", "解放", "最大 RSS bytes",
                     "停止標本", "p50 ms", "p95 ms", "p99 ms", "最大 ms", "合計 ms"], heap),
                "停止の百分位は R12 と同じく全実行の標本を合わせた nearest-rank。標本なしは欠測である。"
                "合計は各実行の合計の中央値。live_bytes は最後の回収時の生存量である。"
                "個々の停止標本と各実行の百分位・最大・合計を JSON に保存する。"
                "MS では参照の増減・再利用・遅延解放は該当しない。",
                "## R12 MS-k1 との比較\n\n" + run.markdown_table(["負荷", "R12 入力", "今回入力", "R12 実行秒 (10 回)", "今回実行秒", "条件"], old),
                "VM とコード生成の変更を含む。list は連結リストから永続ベクタへ変わっており、GC 単独の比較ではない。"
                "短い試行の値から方式を確定する案は出さない。10 回の測定と CPU プロファイルの後に停止と保持量を評価する。"]
    path.write_text("\n\n".join(document) + "\n")
    bars = []
    maximum = max((r['aggregate']['run_nanos'] for r in data['rows'] if 'aggregate' in r), default=1)
    for row in data["rows"]:
        if "aggregate" in row:
            ns = row['aggregate']['run_nanos']
            bars.append(f"<div>{html.escape(row['label'])}: {ns / 1e9:.6f} s"
                        f"<div style='background:#397ca8;height:16px;width:{100 * ns / maximum:.4f}%'></div></div>")
    path.with_suffix(".html").write_text("<!doctype html><meta charset='utf-8'><title>" + html.escape(title) +
        "</title><main style='max-width:1000px;margin:32px auto;font-family:sans-serif'><h1>" + html.escape(title) +
        "</h1><p>実行時間・線形目盛。詳細と条件は同名の Markdown / JSON を参照。</p>" + "\n".join(bars) + "</main>")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bench-run", default="target/release/examples/bench_run")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--measure", action="store_true", help="explicitly enable ten repetitions")
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--profile-directory", type=Path, help="one samply profile per plan row; timing is not a measurement")
    args = parser.parse_args()
    if args.output.suffix != ".md":
        parser.error("--output requires a .md path")
    if args.profile_directory is not None:
        if args.measure:
            parser.error("CPU profiles must be separate from timing measurements")
        args.profile_directory.mkdir(parents=True, exist_ok=True)
        if args.profile_directory.is_symlink() or any(args.profile_directory.iterdir()):
            parser.error("--profile-directory requires an empty directory")
    for extension in (".md", ".html", ".json"):
        if args.output.with_suffix(extension).exists():
            parser.error(f"output exists: {args.output.with_suffix(extension)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    scratch = run.ROOT / "target/r33-trial/tmp"
    scratch.mkdir(parents=True, exist_ok=True)
    # http_sample uses TemporaryFile. Keep even unlinked temporary files in the workspace.
    os.environ["TMPDIR"] = str(scratch)
    os.environ["BENITOITE_BENCH_RSS"] = "resource"
    plan = json.loads(args.plan.read_text()) if args.plan else default_plan()
    files = [Path(__file__), run.BENCH / "run.py", run.BENCH / "rss.py",
             run.ROOT / "crates/benitoite/examples/bench_run.rs", Path(args.bench_run)]
    if any(item["name"].startswith("cycle-") for item in plan):
        files += [Path(args.bench_run).with_name("stage1_heap_bench"),
                  run.ROOT / "crates/benitoite/examples/stage1_heap_bench.rs",
                  run.ROOT / "crates/benitoite/examples/stage1_support/mod.rs"]
    files += list(run.PROGRAMS.glob("*.bnt")) + list((run.PROGRAMS / "stage1").glob("*.bnt"))
    data = dict(date=dt.date.today().isoformat(), revision=run.git_revision(), environment=stage1.system_information(),
                source_hashes={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
                measure=args.measure, iterations=10 if args.measure else 1, plan=plan, rows=[])
    data["profile_directory"] = str(args.profile_directory) if args.profile_directory else None
    for item in plan:
        row = dict(item, samples=[])
        try:
            arguments = []
            for value in item["args"]:
                if str(value).startswith("@lines:"):
                    count = int(str(value).split(":")[1])
                    path = scratch / f"lines-{count}.txt"
                    if not path.exists():
                        run.generate_lines(path, count)
                    arguments.append(str(path))
                else:
                    arguments.append(str(value))
            options = item.get("options", [])
            tool = args.bench_run
            if args.profile_directory is not None:
                # Plan labels become filenames; keep them within the chosen directory.
                label = item["label"]
                if not re.fullmatch(r"[A-Za-z0-9_-]+", label):
                    raise ValueError("profile labels must use letters, digits, _ or -")
                options = ["record", "--save-only", "--unstable-presymbolicate", "-o",
                           str(args.profile_directory / f"{label}.json.gz"), "--", tool, *options]
                tool = "samply"
            if item["name"].startswith("cycle-"):
                if args.profile_directory is not None:
                    raise ValueError("heap API profiles require the stage1_heap_bench executable")
                command = [str(Path(args.bench_run).with_name("stage1_heap_bench")), "--factor", "100", "--",
                           item["name"].removeprefix("cycle-"), *arguments]
                row["output"] = "remaining=0"
                row["heap_stress"] = True
                for _ in range(data["iterations"]):
                    result = stage1.sample(command, b"remaining=0\n", memory=True, timeout=args.timeout)
                    pauses = result["pause_nanos"]
                    result.update(rss=result["rss_bytes"], pause_count=len(pauses),
                                  pause_total_nanos=sum(pauses), pause_max_nanos=max(pauses, default=0),
                                  command=command)
                    for p in (50, 95, 99):
                        result[f"pause_p{p}_nanos"] = stage1.percentile(pauses, p) or 0
                    row["samples"].append(result)
            elif item["name"] == "http":
                for _ in range(data["iterations"]):
                    result = run.http_sample(tool, int(arguments[0]), int(arguments[1]),
                                             item["clients"], *options, timeout=args.timeout)
                    if result["responses"] != int(arguments[0]):
                        raise RuntimeError("HTTP response count mismatch")
                    row["samples"].append(result)
            else:
                source = stage1.source(item["name"]) if item["name"] in stage1.VM_NAMES[6:] else run.benchmark_source(item["name"])
                output, verifier = expected(item, arguments)
                row["verifier"] = verifier
                row["output_sha256"] = hashlib.sha256(output).hexdigest()
                row["output"] = output.decode().strip() if len(output) < 256 else f"SHA-256 {row['output_sha256']} ({len(output)} bytes)"
                for _ in range(data["iterations"]):
                    row["samples"].append(sample(tool, source, arguments, options, output, args.timeout))
            print(f"{item['label']}: {row['samples'][0]['run_nanos'] / 1e9:.6f} s; rss={row['samples'][0].get('rss')}", flush=True)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            row["error"] = str(error)
            print(f"{item['label']}: ERROR {error}", flush=True)
        data["rows"].append(row)
        args.output.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    render(args.output, data)
    args.output.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return int(any(row.get("error") for row in data["rows"]))


if __name__ == "__main__":
    raise SystemExit(main())
