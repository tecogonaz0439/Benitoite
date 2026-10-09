#!/usr/bin/env python3
"""SECB6: alternate two bench_run binaries using the existing HTTP and sampling tools."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys

import remeasure
import run
import stage1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.suffix != ".md":
        parser.error("--output requires a .md path")
    if any(args.output.with_suffix(suffix).exists() for suffix in (".md", ".json", ".html")):
        parser.error("output already exists")
    scratch = run.ROOT / "target/secb6/tmp"
    scratch.mkdir(parents=True, exist_ok=True)
    os.environ["TMPDIR"] = str(scratch)
    os.environ["BENITOITE_BENCH_RSS"] = "resource"
    tools = {"before": str(args.before.resolve()), "after": str(args.after.resolve())}
    files = [Path(__file__), run.BENCH / "run.py", run.BENCH / "remeasure.py", run.BENCH / "rss.py",
             run.ROOT / "crates/benitoite/examples/bench_run.rs", *map(Path, tools.values())]
    files += [run.PROGRAMS / f"{name}.bnt" for name in ("fib", "loop", "http")]
    changed = subprocess.check_output(["git", "diff", "--name-only"], cwd=run.ROOT).decode().splitlines()
    files += [run.ROOT / p for p in changed if p.endswith(".rs")]
    data = dict(date=dt.date.today().isoformat(), revision=run.git_revision(), environment=stage1.system_information(),
                command=sys.argv, source_hashes={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
                compute_trials=7, http_trials=3, clients=1, rows=[], http_verification=[])
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.output.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    # HTTP の全応答を照合する。計測する条件のほか、8 クライアントでも小さな入力を通す。
    for version, tool in tools.items():
        for clients in (1, 8):
            result = run.http_sample(tool, 16, 0, clients, timeout=60)
            assert result["responses"] == 16
            data["http_verification"].append(dict(version=version, clients=clients, **result))
        print(f"verified HTTP: {version}, 1/8 clients", flush=True)
    for name, argument in (("fib", "34"), ("loop", "20000000")):
        source = run.benchmark_source(name)
        expected = run.require_success([str(run.PROGRAMS / "rust/target/release" / name), argument])
        row = dict(name=name, args=[argument], output=expected.decode().strip(), samples=[])
        for trial in range(data["compute_trials"]):
            for version, tool in tools.items():
                sample = remeasure.sample(tool, source, [argument], [], expected, 60)
                row["samples"].append(dict(version=version, trial=trial + 1, **sample))
                print(f"{name} {version} #{trial+1}: {sample['run_nanos']/1e9:.6f} s", flush=True)
        data["rows"].append(row)
        save()
    for count in (20000, 80000):
        row = dict(name="http", args=[count, 0], clients=1, samples=[])
        for trial in range(data["http_trials"]):
            for version, tool in tools.items():
                sample = run.http_sample(tool, count, 0, 1, timeout=240)
                assert sample["responses"] == count
                row["samples"].append(dict(version=version, trial=trial + 1, **sample))
                print(f"http {count} {version} #{trial+1}: {sample['run_nanos']/1e9:.6f} s; rss={sample.get('rss')}", flush=True)
                save()
        data["rows"].append(row)
        save()
    rows, http_rows, bars = [], [], []
    for row in data["rows"]:
        aggregate = {}
        for version in tools:
            samples = [s for s in row["samples"] if s["version"] == version]
            aggregate[version] = dict(min_run_seconds=min(s["run_nanos"] for s in samples)/1e9,
                                      median_run_seconds=statistics.median(s["run_nanos"] for s in samples)/1e9,
                                      max_rss_bytes=max(s.get("rss", 0) for s in samples))
        row["aggregate"] = aggregate
        old, new = aggregate["before"], aggregate["after"]
        rows.append([row["name"], " ".join(map(str, row["args"])), f"{old['min_run_seconds']:.6f}",
                     f"{new['min_run_seconds']:.6f}", f"{100*(new['min_run_seconds']/old['min_run_seconds']-1):+.2f}%"])
        if row["name"] == "http":
            count = row["args"][0]
            http_rows.append([count, f"{old['median_run_seconds']:.6f}", f"{new['median_run_seconds']:.6f}",
                              f"{1e6*old['median_run_seconds']/count:.3f}", f"{1e6*new['median_run_seconds']/count:.3f}",
                              old["max_rss_bytes"], new["max_rss_bytes"]])
        for version in tools:
            bars.append((f"{row['name']} {' '.join(map(str, row['args']))} {version}", aggregate[version]["min_run_seconds"]))
    document = ["# SECB6 リソース表とタスク終了の性能比較\n",
                f"日付: {data['date']}。開始時のコミット: `{data['revision']}`。変更後は未コミット。",
                "## 環境\n\n" + run.markdown_table(["項目", "値"], list(data["environment"].items())),
                "## 方法\n\n既定 release の MS-k1、呼び出し予算 10,000、direct IO、stress なし。"
                "開始時に保存した bench_run と修正後の bench_run を before → after の順で交互に実行した。"
                "fib・loop は各 7 回の最小値、HTTP は各 3 回の最小値と中央値を示す。"
                "run_nanos は bench_run 内の実行時間で、プロセスの起動と静的検査を含めない。"
                "HTTP は計算タスクなし、1 クライアント、接続は要求ごとに閉じる。"
                "run.py の http_sample が全応答の状態 200・本体 ok・応答数を照合した。"
                "fib・loop の全出力は独立した Rust 版と照合した。"
                "最大 RSS は rss.py の resource ラッパーが対象の子だけを起動して取得し、各条件の最大値を示す。"
                "測定中にビルドやテストを並行実行しなかった。計算機全体の他アプリの負荷は確認していない。"
                "CPU プロファイルは依頼の指定に従い取得しなかった。",
                "## 実行時間の最小値\n\n" + run.markdown_table(["負荷", "入力", "修正前 秒", "修正後 秒", "変化"], rows),
                "## HTTP の要求数と実行時間・保持量\n\n" + run.markdown_table(
                    ["要求数", "修正前 中央値 秒", "修正後 中央値 秒", "修正前 µs/要求", "修正後 µs/要求", "修正前 最大 RSS bytes", "修正後 最大 RSS bytes"], http_rows),
                "## 再実行\n\n" + "```sh\n" + " ".join(["python3", *sys.argv]) + "\n```",
                "既存の出力は上書きしないため、再実行時は --output を別名にする。実行ファイル・入力・"
                "変更した Rust ソース・測定道具の SHA-256、各回の時間・RSS・回収統計は同名の JSON に保存した。"]
    args.output.write_text("\n\n".join(document) + "\n")
    maximum = max(seconds for _, seconds in bars)
    chart = "\n".join(f"<div>{html.escape(label)}: {seconds:.6f} s<div style='height:18px;background:#397ca8;width:{100*seconds/maximum:.4f}%'></div></div>" for label, seconds in bars)
    args.output.with_suffix(".html").write_text("<!doctype html><meta charset='utf-8'><title>SECB6 性能比較</title><main style='max-width:1000px;margin:32px auto;font-family:sans-serif'><h1>SECB6 性能比較</h1><p>実行時間の最小値・線形目盛。条件と全標本は同名の Markdown / JSON を参照。</p>" + chart + "</main>\n")
    save()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
