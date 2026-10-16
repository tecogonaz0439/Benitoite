#!/usr/bin/env python3
"""同じ最小入力で変更前後のプロセス全体の時間を短く比較する。"""

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile
import time


SOURCE = "function main() -> Unit\n  return ()\nend function\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path, help="記録の拡張子なしのパス")
    args = parser.parse_args()
    paths = [args.output.with_suffix(suffix) for suffix in (".json", ".md", ".html")]
    if any(path.exists() for path in paths):
        parser.error("既存の記録は上書きしない")
    binaries = {"before": args.before.resolve(), "after": args.after.resolve()}
    env = dict(os.environ, BENITOITE_DEV_IO_MODE="direct")
    samples = {command: {version: [] for version in binaries} for command in ("run", "check")}
    with tempfile.TemporaryDirectory(prefix="benitoite-startup-") as temp:
        source = Path(temp) / "noop.bnt"
        source.write_text(SOURCE, encoding="utf-8")

        def once(command, version):
            start = time.perf_counter_ns()
            result = subprocess.run(
                [str(binaries[version]), command, str(source)], env=env,
                capture_output=True, timeout=30, check=True,
            )
            elapsed = (time.perf_counter_ns() - start) / 1_000_000
            if result.stdout or result.stderr:
                raise RuntimeError(f"unexpected output: {result}")
            return elapsed

        for command in samples:
            for version in binaries:
                for _ in range(3):
                    once(command, version)
            for index in range(11):
                versions = list(binaries) if index % 2 == 0 else list(reversed(binaries))
                for version in versions:
                    samples[command][version].append(once(command, version))

    summary = {
        command: {
            version: {"median_ms": statistics.median(values), "min_ms": min(values)}
            for version, values in versions.items()
        }
        for command, versions in samples.items()
    }
    record = {
        "platform": platform.platform(), "machine": platform.machine(),
        "cpu": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
        "rustc": subprocess.check_output(["rustc", "--version"], text=True).strip(),
        "binary_sha256": {v: hashlib.sha256(p.read_bytes()).hexdigest() for v, p in binaries.items()},
        "source": SOURCE, "source_sha256": hashlib.sha256(SOURCE.encode()).hexdigest(),
        "io_mode": "direct", "warmups": 3, "samples_per_version": 11,
        "samples_ms": samples, "summary": summary,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    paths[0].write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    rows = []
    for command, versions in summary.items():
        before, after = (versions[v]["median_ms"] for v in ("before", "after"))
        rows.append(f"| {command} | {before:.3f} | {after:.3f} | {after - before:+.3f} | {after / before:.3f} |")
    markdown = (
        "# B10-3 起動・静的検査の短い比較\n\n"
        f"実機: {record['cpu']}、{record['platform']}、{record['rustc']}。\n\n"
        "release の既定構成、Direct。tools/bench/run.py の generated_sources と同じ最小の main を使用した。"
        "各組を3回予熱後、11標本ずつ採り、変更前後を交互の順で実行した。"
        "全標本で終了状態0・標準出力と標準エラーが空であることを確認した。"
        "時間は OS のプロセス起動から終了までを含む。ビルド・他の検査・エージェントの作業とは並行しなかった。\n\n"
        "| 操作 | 変更前の中央値 (ms) | 変更後の中央値 (ms) | 差 (ms) | 比率 |\n"
        "|---|---:|---:|---:|---:|\n" + "\n".join(rows) + "\n\n"
        "最小入力の局所的な比較であり、通常のスクリプト全体の性能や別言語との位置を示さない。"
        "標本・最小値・実行ファイルと入力の SHA-256 は隣の JSON に保存した。\n"
    )
    paths[1].write_text(markdown, encoding="utf-8")
    maximum = max(value["median_ms"] for versions in summary.values() for value in versions.values())
    bars = []
    for command, versions in summary.items():
        for version, values in versions.items():
            width = 100 * values["median_ms"] / maximum
            bars.append(f'<p>{command} / {version}: {values["median_ms"]:.3f} ms</p>'
                        f'<div style="width:{width:.3f}%;height:24px;background:{"#557" if version == "before" else "#169"}"></div>')
    paths[2].write_text(
        '<!doctype html><html lang="ja"><meta charset="utf-8"><title>B10-3 起動の比較</title>'
        '<body style="font-family:sans-serif;max-width:900px;margin:2em auto">'
        '<h1>B10-3 起動・静的検査の比較</h1><p>中央値。棒の長さは0からの線形目盛。</p>'
        + "".join(bars) + "<pre>" + html.escape(markdown) + "</pre></body></html>\n", encoding="utf-8",
    )
    print("\n".join(str(path) for path in paths))


if __name__ == "__main__":
    main()
