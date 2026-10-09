#!/usr/bin/env python3
# coding: utf-8
"""第1段のマーク・スイープの3構成と、VM・循環の負荷を同じ入力で記録する（R12、07-02）。
RC の構成はタグ `stage1-rc-final` で再現する。"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import hashlib
import json
import os
from pathlib import Path
import shlex
import statistics
import subprocess
import sys
import time

import run

ROOT = run.ROOT
PROGRAMS = run.PROGRAMS
VM_NAMES = ("fib", "loop", "list", "tree", "eval", "string", "shared", "live", "roots", "returns", "mixed")
# 既存の値は最小実行版の値を引き継ぐ。追加分は本測定時に1〜10秒へ調整する仮の入力。
INPUTS = {name: run.BENCH_INPUTS[name] for name in VM_NAMES[:6]}
INPUTS.update(shared=16, live=16, roots=3000, returns=20000, mixed=10000)
CYCLES = {"self": [20000, 1], "pair": [20000, 1], "ring": [100, 10000], "list": [100, 100000]}
CONFIGS = {"MS-k0.5": ("ms", "gc-mark-sweep", 50, True),
           "MS-k1": ("ms", "gc-mark-sweep", 100, True),
           "MS-k2": ("ms", "gc-mark-sweep", 200, True)}
COUNTS = ("allocations", "allocated_bytes", "live_bytes", "peak_heap_bytes", "collections", "roots_traced",
          "rc_increments", "rc_decrements", "rc_elided", "reuses", "frees", "remaining")


def checked(command, **kwargs):
    return subprocess.run(command, cwd=ROOT, check=True, **kwargs)


def build(target):
    checked(["cargo", "build", "--release", "-p", "benitoite", "--no-default-features",
             "--features", "gc-mark-sweep", "--example", "stage1_bench", "--example", "stage1_heap_bench",
             "--target-dir", str(target / "ms")])


def source(name):
    return PROGRAMS / ("stage1" if name in VM_NAMES[6:] else "") / f"{name}.bnt"


def expected(name, arguments):
    if name.startswith("cycle-"):
        return b"remaining=0\n"
    n = int(arguments[0])
    if name == "fib":
        a, b = 0, 1
        for _ in range(n):
            a, b = b, a + b
        value = a
    else:
        value = {"loop": lambda: n * (n - 1) // 2,
                 "list": lambda: 3 * ((n - 1) // 2) * (((n - 1) // 2) + 1),
                 "tree": lambda: 2 ** n, "eval": lambda: 41751 * n,
                 "string": lambda: n + 2, "shared": lambda: 50 * 2 ** n,
                 "live": lambda: 2304000 + 2 ** n,
                 "roots": lambda: 32640 * n, "returns": lambda: 129 * n * (int(arguments[1]) if len(arguments) > 1 else 1),
                 "mixed": lambda: n * (n + 1) // 2 + 1537 * n}[name]()
    return f"{value}\n".encode()


def command(target, config, name, arguments):
    folder, _, factor, reuse = CONFIGS[config]
    example = "stage1_heap_bench" if name.startswith("cycle-") else "stage1_bench"
    cmd = [str(target / folder / "release" / "examples" / example), "--factor", str(factor)]
    if not reuse:
        cmd.append("--no-reuse")
    if example == "stage1_bench":
        return [*cmd, "--", str(source(name)), *map(str, arguments)]
    return [*cmd, "--", name.removeprefix("cycle-"), *map(str, arguments)]


def parse_stats(stderr):
    lines = stderr.decode().splitlines()
    stats = [line for line in lines if line.startswith("stage1 ")]
    if len(stats) != 1:
        raise ValueError("expected exactly one stage1 statistics line")
    instrumented = any(line.startswith("stage1-instrumented ") for line in lines)
    pairs = dict(item.split("=", 1) for item in stats[0].split()[1:])
    result = {key: (None if value == "na" else int(value)) for key, value in pairs.items() if key != "pause_nanos"}
    result["instrumented"] = instrumented
    result["pause_nanos"] = [int(value) for value in pairs["pause_nanos"].split(",") if value]
    measurement = [line for line in lines if line.startswith("stage1-measure ")]
    result["cycle_nanos"] = None
    result["cycle_max_nanos"] = None
    result["measurement"] = dict(item.split("=", 1) for item in measurement[0].split()[1:]) if measurement else None
    cycle = [line for line in lines if line.startswith("stage1-cycle ")]
    if cycle and result["measurement"] is not None:
        values = dict(item.split("=", 1) for item in cycle[0].split()[1:])
        result["measurement"]["cycle_collections"] = values["collections"]
        result["cycle_nanos"] = int(values["nanos"])
        result["cycle_max_nanos"] = int(values["max_nanos"])
    return result


def sample(cmd, output, memory=False, timeout=300):
    wrapped = run.memory_wrapper(cmd) if memory else None
    started = time.perf_counter_ns()
    rss_reason = None
    process = subprocess.run(wrapped or cmd, cwd=ROOT, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if process.returncode != 0 and wrapped:
        rss_reason = "; ".join(line for line in process.stderr.decode(errors="replace").splitlines() if line.startswith("time:")) or "OS の計測コマンドが失敗した"
        started = time.perf_counter_ns()
        process = checked(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        wrapped = None
    elif process.returncode != 0:
        raise ValueError(f"benchmark failed ({process.returncode}): {shlex.join(cmd)}: {process.stderr.decode(errors='replace')}")
    wall = time.perf_counter_ns() - started
    if process.stdout != output:
        raise ValueError(f"output mismatch: {shlex.join(cmd)}; expected {output!r}, got {process.stdout!r}")
    result = parse_stats(process.stderr)
    result["wall_nanos"] = wall
    result["rss_bytes"] = run.parse_max_rss(process.stderr) if wrapped else None
    result["rss_reason"] = None if result["rss_bytes"] is not None else (rss_reason or "OS の RSS を取得できなかった")
    return result


def verify(target, require_uninstrumented=False):
    # 期待値は VM の出力から作らず、式または別に保存した値で照合する（test-audit）。
    for name in VM_NAMES:
        args = source(name).with_suffix(".args.small").read_text().split()
        output = expected(name, args)
        fixture = source(name).with_suffix(".stdout.small")
        if fixture.exists() and fixture.read_bytes() != output:
            raise ValueError(f"incorrect fixture: {fixture}")
        for config in CONFIGS:
            result = sample(command(target, config, name, args), output)
            if require_uninstrumented and result["instrumented"]:
                raise ValueError("instrumented binary cannot be used for timing; restore the four measurement-only files and rebuild")
        print(f"verified {name}", flush=True)
    for shape in CYCLES:
        for config in CONFIGS:
            sample(command(target, config, "cycle-" + shape, [2, 8]), b"remaining=0\n")
        print(f"verified cycle-{shape}", flush=True)


def percentile(values, percent):
    # nearest-rank。空の標本は0ではなく欠測として扱う。
    if not values:
        return None
    return sorted(values)[max(0, (len(values) * percent + 99) // 100 - 1)]


def aggregate(samples, timed):
    first = samples[0]
    for other in samples[1:]:
        if any(other[key] != first[key] for key in COUNTS):
            raise ValueError("deterministic heap counts differ between repetitions")
    row = {key: first[key] for key in COUNTS}
    rss = [s["rss_bytes"] for s in samples if s["rss_bytes"] is not None]
    row["rss_bytes"] = max(rss) if rss else None
    row["rss_reason"] = None if rss else first["rss_reason"]
    denominator = first["reuse_denominator"]
    row["reuse_rate"] = first["reuses"] / denominator if denominator else None
    pauses = [p for s in samples for p in s["pause_nanos"]]
    for key in ("check_nanos", "compile_nanos", "run_nanos", "total_nanos", "wall_nanos"):
        row[key] = statistics.median(s[key] for s in samples) if timed else None
    row["pause_sum_nanos"] = statistics.median(sum(s["pause_nanos"]) for s in samples) if timed else None
    row["pause_p50"] = percentile(pauses, 50) if timed else None
    row["pause_p95"] = percentile(pauses, 95) if timed else None
    row["pause_p99"] = percentile(pauses, 99) if timed else None
    row["pause_max"] = max(pauses) if timed and pauses else None
    cycle_times = [s["cycle_nanos"] for s in samples if s["cycle_nanos"] is not None]
    row["cycle_nanos"] = statistics.median(cycle_times) if timed and cycle_times else None
    row["cycle_max_nanos"] = max((s["cycle_max_nanos"] for s in samples if s["cycle_max_nanos"] is not None), default=None) if timed else None
    row["noncycle_nanos"] = row["pause_sum_nanos"] - row["cycle_nanos"] if row["cycle_nanos"] is not None else None
    row["measurement"] = first["measurement"]
    # 動作確認では時間を保存しない。計数用のリビジョンの時間も判断に使わない。
    row["samples"] = samples if timed else [{key: s[key] for key in (*COUNTS, "rss_bytes", "measurement")} for s in samples]
    return row


def table(headers, rows):
    def cell(value):
        return "—" if value is None else str(value).replace("|", "\\|").replace("\n", " ")
    return "\n".join(["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)] +
                     ["| " + " | ".join(map(cell, row)) + " |" for row in rows])


def system_information():
    info = run.collect_system_info()
    if sys.platform == "darwin":
        try:
            hardware = next(iter(json.loads(run.command_output(["system_profiler", "SPHardwareDataType", "-json"]) or "{}").get("SPHardwareDataType", [])), {})
        except ValueError:
            hardware = {}
        if hardware.get("chip_type"):
            info.update(cpu=hardware["chip_type"], model=hardware.get("machine_model", "unknown"), hardware_query="system_profiler SPHardwareDataType -json")
    return info


def write_report(path, data):
    rows = data["rows"]
    index = {(r["name"], r["config"]): r for r in rows}
    comparisons = []
    for name in ("live", "roots", "list", "mixed"):
        if (name, "MS-k1") in index:
            for config in CONFIGS:
                r = index[name, config]
                comparisons.append([name, config, r["peak_heap_bytes"], r["collections"], r["allocations"], r["reuses"]])
    integers = []
    for name in data["inputs"]:
        r = index.get((name, "MS-k1"))
        if r and r["measurement"]:
            for group in ("constant", "arithmetic"):
                bins = [int(r["measurement"].get(group + "_" + str(bits), 0)) for bits in (31, 47, 63, 64)]
                total = sum(bins)
                integers.append([name, group, total, *[f"{100 * sum(bins[:n]) / total:.4f}%" if total else None for n in (1, 2, 3)]])
    value_proposal = ("今回の算術結果はすべて符号付き63ビットに収まった。31ビットや47ビットを超える値も loop にあるため、整数の幅を狭める設計では箱の確保を見積もる必要がある。分布は今回のベンチマークの範囲であり、Float や利用者の実際のスクリプトを代表しない。8バイト案は別の測定専用の試作として検討する価値があるが、演算時の分岐・箱の確保・数値の境界の費用を比べてから採否を決める。" if integers else "8バイト案の採否は、測定専用のリビジョンで集めた整数・対象の分布の記録と併せて判断する。この記録だけでは分布を取得していない。")
    sections = [f"# 第1段の測定 {data['date']} / <COMMIT>",
                "## 環境\n\n" + table(["項目", "値"], data["environment"].items()),
                "## ソースの識別\n\n" + table(["ファイル", "SHA-256"], data.get("file_hashes", {}).items()),
                "## 処理系と構成\n\n基準コミット: `" + data["base_revision"] + "`。道具・本番の測定のコミット: `<COMMIT>`。測定専用のコミット: `<COMMIT>`（`measure/R12-counts`）。コミットとファイル名はオーケストレータが埋める。",
                "CPU 型番は環境の表に示した方法で取得した。旧記録は Apple M4・32 GiB・macOS 27.0、今回は macOS 27.0.1 である。旧 VM の測り直しは今回と同じ環境で行う。",
                table(["構成", "feature", "k（百分率）", "reuse", "trigger_min_bytes", "stress（VM / 循環）"],
                      [[name, value[1], value[2], value[3], 4194304, "false / true"] for name, value in CONFIGS.items()]),
                "release、既定機能なし、`heap-verify`・`alloc-stats`・`gc-stress` なし。VM は Direct。全構成で同じ命令と生存情報を使う。循環は公開ヒープ API の単位測定であり、VM の Reference の統合を確かめるものではない。self は自己参照のセル、pair は2セルの相互参照、ring はセルと構成子の並びの輪、list は同じセルを各要素に持つ ListCell の連結リストをそのセルへ入れた循環である。",
                "RC の過去の構成（タグ `stage1-rc-final`）は解放待ちの量が 4 MiB を超えると要求する。循環は、新しいセル数が `max(1000, 前回の生存セル数)` 以上、または生存セルがあり確保量が `max(4 MiB, k × 前回の生存量)` 以上で要求する。stress の循環では毎回回収し、この負荷では k の閾値の効果を測らない。`reuses` は `reuse_ctor` が `Some` を返した回数である。再利用率は `reuses / (reuses + allocations)` とする。",
                "## 入力の大きさ\n\n" + table(["負荷", "今回の入力", "本測定の仮入力"],
                    [[name, " ".join(map(str, args)), " ".join(map(str, data['full_inputs'][name]))] for name, args in data["inputs"].items()]),
                "追加の本入力は仮の値である。通常の release で1〜10秒に調整し、採った入力を JSON と記録に保存する。小入力の照合は全45組（VM 11×3、循環4×3）を実行する。",
                "## 実行時間と回収の停止時間\n\n" + (f"本測定。各{data.get('iterations',10)}回の中央値、単位 ns。停止時間の百分位は全回の pause_nanos を合わせた nearest-rank。" if data["timed"] else "時間の本測定はオーケストレータが計算機を静かにして行う。この記録は計数と RSS の収集であり、時間の欄は空けてある。"),
                table(["負荷", "構成", "検査", "脱糖・コード生成", "実行", "段を含む合計", "プロセス全体", "回収合計", "p50", "p95", "p99", "最大"],
                      [[r["name"], r["config"], *[r[k] for k in ("check_nanos", "compile_nanos", "run_nanos", "total_nanos", "wall_nanos", "pause_sum_nanos", "pause_p50", "pause_p95", "pause_p99", "pause_max")]] for r in rows]),
                "検査・脱糖・コンパイルと run_program は例の Instant で直接区切る。実行は VM の作成・main の準備・最後の転送・VM とヒープの破棄を含む。total は入力の準備も含み、統計の書き出しを含まない。wall は起動と終了・統計の出力も含む。循環の run は構築と回収を含み、回収合計は pause_nanos の合計である。",
                "## 確保の量、生きている量、最大常駐メモリ\n\n" + table(["負荷", "構成", "確保回数", "累積確保 bytes", "最後の生存 bytes", "最大ヒープ bytes", "最大 RSS bytes", "解放数", "残った対象"],
                      [[r["name"], r["config"], *[r[k] for k in ("allocations", "allocated_bytes", "live_bytes", "peak_heap_bytes", "rss_bytes", "frees", "remaining")]] for r in rows]),
                "live_bytes は最後の回収時の値であり、終了時の到達可能量ではない。frees は HeapCore の破棄前の値である。RSS は `/usr/bin/time -l`（macOS）または `-v`（Linux）で取得した最大値。対象の課金量とプロセス全体の RSS は異なる。",
                "RSS を取得できなかった組:\n\n" + table(["負荷", "構成", "理由"], [[r["name"], r["config"], r["rss_reason"]] for r in rows if r["rss_reason"]]),
                "## 参照の増減・再利用・根・回収\n\n" + table(["負荷", "構成", "増加", "減少", "省いた増減", "再利用", "再利用率", "辿った根", "回収"],
                      [[r["name"], r["config"], r["rc_increments"], r["rc_decrements"], r["rc_elided"], r["reuses"], f"{100*r['reuse_rate']:.6f}%" if r["reuse_rate"] is not None else None, r["roots_traced"], r["collections"]] for r in rows]),
                "## 整数の範囲・対象の大きさ・循環の内訳\n\n" + table(["負荷", "構成", "測定専用の計数"],
                      [[r["name"], r["config"], json.dumps(r["measurement"], ensure_ascii=False) if r["measurement"] else "測定専用のリビジョンで収集する"] for r in rows]),
                table(["循環の負荷", "構成", "循環回収合計 ns", "循環回収最大 ns", "循環以外の回収合計 ns"], [[r["name"], r["config"], r.get("cycle_nanos"), r.get("cycle_max_nanos"), r.get("noncycle_nanos")] for r in rows if r["name"].startswith("cycle-")]),
                "整数は LOADK で読んだ定数と NegI・AddI・SubI・MulI・DivI・ModI の結果を別に数える。区間は符号付き31/47/63ビットに収まる値と、それ以上であり、累積割合は各区間を足して求める。組み込みの関数の整数結果はこの分布に含めない。対象の大きさは頭・切り上げ・別領域を含む課金量の区間別の個数である。循環の時間の内訳は、第 1 段で比べた参照カウント（RC）の構成の循環の回収の内訳であり、R12 の測定専用のリビジョンでだけ埋まる（R14 が RC を外した後の構成では空になる）。当時の定義では、循環以外の回収は停止時間の合計から循環回収時間を差し引いた値で、最初の遅延解放・根の計数・要求の処理などを含み、循環を切った後の解放は循環回収時間に含めた。",
                "整数の累積割合（命令列は同じなので MS-k1 の計数を示す）:\n\n" + table(["負荷", "定数 / 算術結果", "標本数", "31ビット", "47ビット", "63ビット"], integers),
                "## 再現のコマンド\n\nRC の構成はタグ `stage1-rc-final` で再現する。マーク・スイープは次のコマンドでビルドする。測定専用の計数は R12 の記録にあるリビジョンで再現する。本番の時間測定では計数の4ファイルを戻して同じコマンドでビルドする。\n\n```sh\ncargo build --release -p benitoite --no-default-features --features gc-mark-sweep --example stage1_bench --example stage1_heap_bench --target-dir target/stage1/ms\n" + data["reproduce"] + "\n```\n\n小入力での再現確認（測定専用のリビジョン）:\n\n```sh\npython3 tools/bench/stage1.py --no-build --smoke --instrumented --iterations 2 --output target/r12-final-smoke.md --overwrite\n```\n\n通常の本測定（計数用ソースを戻した後）:\n\n```sh\npython3 tools/bench/stage1.py --measure --iterations 10 --output 'tools/bench/results/2026-10-05-stage1-<COMMIT>-timing.md'\n```\n\n`--inputs PATH` で VM の整数と循環の `[回数, 大きさ]` を指定した JSON を読み、入力調整を記録できる。`--render JSON` は実行せず Markdown と HTML を再生成する。既存記録は `--overwrite` を指定したときだけ上書きする。",
                "循環の内訳の本測定（測定専用のリビジョンでのみ実行）:\n\n```sh\npython3 tools/bench/stage1.py --cycle-timing --instrumented --iterations 10 --output 'tools/bench/results/2026-10-05-stage1-<COMMIT>-cycle-timing.md'\n```\n\nこの構成の整数・確保の計数は構築中にだけ行い、循環回収中の計数処理は増やさない。VM の時間測定にこのバイナリを使わない。",
                "## 振り分けのループの変化\n\n" + ("旧 VM の本測定の結果は末尾に示す。" if data.get("legacy") else "時間は未測定。") + "C05 直前のコミット `d4668a9^` を作業ツリー内に展開し、古い構文の fib・loop を MS-k1 と同じ入力で測る。値の大きさ・確保器・コード生成も変わるため、この差を GC 単独の効果とは扱わない。\n\n```sh\nmkdir -p target/stage1-legacy\ngit archive 'd4668a9^' | tar -x -C target/stage1-legacy\ncargo build --release -p benitoite --manifest-path target/stage1-legacy/Cargo.toml --target-dir target/stage1-legacy-build\npython3 tools/bench/stage1.py --measure --legacy target/stage1-legacy-build/release/benitoite --legacy-programs target/stage1-legacy/tools/bench/programs --output 'tools/bench/results/2026-10-05-stage1-<COMMIT>-dispatch.md'\n```",
                "## CPU プロファイルの所見\n\n本測定後に埋める。現時点では採取していない。samply 0.13.1 の版表示と record のヘルプで以下の選択肢を確認した。fib・loop の振り分けと呼び出し、list・tree の確保と回収、eval の値と参照の操作、組み込みの関数の self の割合を比較し、ADR 0269 の見立てを検討する。\n\n```sh\nmkdir -p 'tools/bench/results/profiles/2026-10-05-stage1-<COMMIT>'\nsamply record --save-only --unstable-presymbolicate -o 'tools/bench/results/profiles/2026-10-05-stage1-<COMMIT>/fib-ms.json.gz' -- target/stage1/ms/release/examples/stage1_bench --factor 100 -- tools/bench/programs/fib.bnt 35\npython3 tools/bench/profile_summary.py 'tools/bench/results/profiles/2026-10-05-stage1-<COMMIT>/fib-ms.json.gz' 10\n```\n\n各負荷・構成の実行コマンドは付属 JSON の rows.command にある。そのコマンドを samply の `--` の後に置く。",
                "## 比較対象の言語\n\n既存8本を一度だけ本測定する。bytecode-stats は渡さない。CPython は macOS に付属の版を使う。println のバッファ条件、string/lines の組み込みの実装、list の連結リストと配列の違いは benchmark スキルの注意に従って読む。\n\n```sh\ncargo build --release -p benitoite\ncargo build --release --manifest-path tools/bench/programs/rust/Cargo.toml\npython3 tools/bench/run.py --benitoite target/release/benitoite --verify\npython3 tools/bench/run.py --benitoite target/release/benitoite\n```",
                "## 固定項目から確認できたこと\n\n" + table(["負荷", "構成", "最大ヒープ bytes", "回収回数", "確保回数", "再利用回数"], comparisons) + "\n\nshared は同じ部分木を2回ずつ含む構造を深さの回数だけ作る。論理的な葉の訪問数は大きいが、物理的な対象は少ない。この入力では回収が0回なので、共有した値の読み書きと参照の増減の比較として読み、GC の停止時間の根拠にはしない。collections が0の組には pause_nanos の標本がなく、百分位も求められない。",
                "## 暫定に採る方式・k・閾値・8バイトの値の案\n\n以下は案であり、設計の決定ではない。時間と停止時間が空欄の段階では方式を選ばず、本測定までは比較の基準として MS-k1 を維持する。MS を採る場合の k の案は1である。live の最大ヒープは k=0.5/1/2 で約12.6/16.8/23.6 MB、回収は6/4/2回となり、k=1 はこの入力で保持量と回収回数の中間に位置する。回収の回数から時間の費用は決められないため、停止時間と最大 RSS を本測定で確認してから k を決める。HTTP サーバで許せる停止時間と RSS は設計者に確認してもらい、第2段の R33 で測り直す。RC の過去の計数と閾値は、R12 の記録とタグ `stage1-rc-final` で確認できる。" + value_proposal,
                "## 残したこと\n\nリソースの解放順は第1段では扱えず R33 に回す。呼び出し予算はタスクがないため測らない。方式ごとの勝ち負け、CPU の費用の内訳、学ぶ目的への影響は時間の本測定後に検討する。循環の大きなリストで停止時間が延びるかも本測定後に判断する。\n\n過去の測定専用の変更は `src/runtime/heap/core.rs`・`src/runtime/heap/ctx.rs`・`src/runtime/heap/core/refcount.rs`・`src/vm/dispatch.rs` である（すべて `crates/benitoite/` の下）。R12 の測定専用のリビジョンでは、この4ファイルを基準コミットから復元すれば計数を外せる。RC の本番の構成はタグ `stage1-rc-final` で再現する。本番へ取り込むのは examples の2本と stage1_support、stage1.py、programs/stage1、結果の Markdown・HTML・JSON である。測定の分担は R12 の個別指示に従った。benchmark スキルの本測定・プロファイル・比較対象の測定はオーケストレータが行う。"]
    if data.get("validation"):
        sections.append("## 受け入れ検査と共通検査\n\n" + "\n".join("- " + item for item in data["validation"]))
    if data.get("legacy"):
        sections.append("## 旧VMの本測定\n\n" + table(["負荷", "中央値 ns", "全標本 ns"], [[name, statistics.median(values), values] for name, values in data["legacy"].items()]))
    path.write_text("\n\n".join(sections) + "\n")
    charts = []
    # グラフは線形目盛。外部ライブラリを使わず、HTML単体で閲覧できる。
    for key, title in (("peak_heap_bytes", "最大ヒープ bytes"), ("rss_bytes", "最大 RSS bytes"), ("run_nanos", "実行時間 ns")):
        for name in data["inputs"]:
            group = [r for r in rows if r["name"] == name and r[key] is not None]
            maximum = max((r[key] for r in group), default=0)
            bars = ''.join(f'<div class="row"><span>{html.escape(r["config"])}</span><i style="width:{100*r[key]/maximum if maximum else 0}%"></i><b>{r[key]:,}</b></div>' for r in group)
            charts.append(f'<section><h3>{html.escape(name)}: {title}</h3>{bars or "未測定"}</section>')
    body = html.escape(path.read_text())
    path.with_suffix(".html").write_text('<!doctype html><html lang="ja"><meta charset="utf-8"><title>第1段の測定</title><style>body{font:16px system-ui;margin:2rem;max-width:1200px}section{padding:1rem;border:1px solid #ddd;margin:1rem 0}.row{display:grid;grid-template-columns:100px 1fr 150px;align-items:center;margin:.5rem}i{display:block;height:18px;background:#4169a1}b{text-align:right}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:13px}</style><h1>第1段の測定</h1><p>線形目盛。時間の空欄は未測定。VM と循環の単位測定を分けて読む。</p>' + ''.join(charts) + '<h2>記録</h2><pre>' + body + '</pre></html>')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--verify", action="store_true")
    mode.add_argument("--smoke", action="store_true")
    mode.add_argument("--measure", action="store_true")
    mode.add_argument("--cycle-timing", action="store_true")
    parser.add_argument("--iterations", type=int)
    parser.add_argument("--target-root", type=Path, default=ROOT / "target/stage1")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--instrumented", action="store_true")
    parser.add_argument("--inputs", type=Path)
    parser.add_argument("--output", type=Path, default=run.RESULTS / f"{dt.date.today()}-stage1-<COMMIT>.md")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--render", type=Path)
    parser.add_argument("--legacy", type=Path)
    parser.add_argument("--legacy-programs", type=Path)
    args = parser.parse_args()
    args.iterations = args.iterations if args.iterations is not None else (10 if args.measure or args.cycle_timing else 1)
    if args.cycle_timing and not args.instrumented:
        parser.error("--cycle-timing requires the measurement-only revision and --instrumented")
    if args.iterations < 1 or args.instrumented and args.measure:
        parser.error("positive iterations required; instrumentation cannot be used for timing")
    if bool(args.legacy) != bool(args.legacy_programs) or args.legacy and not args.measure:
        parser.error("--legacy and --legacy-programs must be specified together with --measure")
    args.output = args.output.resolve()
    if not args.verify and not args.overwrite and any(args.output.with_suffix(suffix).exists() for suffix in (".md", ".html", ".json")):
        parser.error("output already exists; choose another path or pass --overwrite")
    if args.render:
        write_report(args.output, json.loads(args.render.read_text()))
        return
    os.environ["BENITOITE_STAGE1_PROBE"] = "1"
    if args.instrumented:
        os.environ["BENITOITE_STAGE1_COUNTS"] = "1"
    else:
        os.environ.pop("BENITOITE_STAGE1_COUNTS", None)
    target = args.target_root.resolve()
    if not args.no_build:
        build(target)
    verify(target, require_uninstrumented=args.measure)
    if args.verify:
        return
    full = {name: [value] for name, value in INPUTS.items()}
    full.update({"cycle-" + name: value for name, value in CYCLES.items()})
    if args.inputs:
        overrides = json.loads(args.inputs.read_text())
        if not isinstance(overrides, dict) or set(overrides) - set(full):
            parser.error("unknown workload in --inputs")
        for name, value in overrides.items():
            values = value if isinstance(value, list) else [value]
            if len(values) != (2 if name.startswith("cycle-") else 1) or any(type(v) is not int or v <= 0 for v in values):
                parser.error("input must contain positive integers with the correct arity")
            full[name] = values
    inputs = full if not args.smoke else {name: source(name).with_suffix(".args.small").read_text().split() for name in VM_NAMES}
    if args.smoke:
        inputs.update({"cycle-" + name: [2, 8] for name in CYCLES})
    if args.cycle_timing:
        inputs = {name: values for name, values in inputs.items() if name.startswith("cycle-")}
    rows = []
    repeats = args.iterations
    timed = args.measure or args.cycle_timing
    for name, arguments in inputs.items():
        output = expected(name, arguments)
        samples = {config: [] for config in CONFIGS}
        if timed:
            for config in CONFIGS:
                sample(command(target, config, name, arguments), output)  # ウォームアップは記録しない。
        for repetition in range(repeats):
            configs = list(CONFIGS)
            if repetition % 2:
                configs.reverse()
            for config in configs:
                cmd = command(target, config, name, arguments)
                samples[config].append(sample(cmd, output, memory=True))
        for config in CONFIGS:
            row = aggregate(samples[config], timed)
            if args.instrumented and row["measurement"] is None:
                raise ValueError("measurement-only revision was not built")
            if not args.instrumented:
                # 本測定には計数を外したバイナリを必須にする。
                if args.measure and any(s["instrumented"] for s in samples[config]):
                    raise ValueError("instrumented binary cannot be used for timing")
                row["measurement"] = None
            saved_command = command(target, config, name, arguments)
            saved_command = [str(Path(value).relative_to(ROOT)) if Path(value).is_absolute() and Path(value).is_relative_to(ROOT) else value for value in saved_command]
            row.update(name=name, config=config, command=saved_command)
            rows.append(row)
        print(f"collected {name}", flush=True)
    files = [ROOT / "tools/bench/stage1.py", *[source(name) for name in VM_NAMES],
             *[ROOT / "crates/benitoite" / path for path in ("examples/stage1_bench.rs", "examples/stage1_heap_bench.rs", "examples/stage1_support/mod.rs", "src/runtime/heap/core.rs", "src/runtime/heap/ctx.rs", "src/runtime/heap/core/mark_sweep.rs", "src/vm/dispatch.rs")]]
    data = {"file_hashes": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}, "date": str(dt.date.today()), "base_revision": run.git_revision(), "environment": system_information(),
            "timed": timed, "iterations": args.iterations, "inputs": inputs, "full_inputs": full, "rows": rows,
            "reproduce": shlex.join(["python3", "tools/bench/stage1.py", *sys.argv[1:]])}
    if args.legacy:
        old = {}
        legacy_env = dict(os.environ, BENITOITE_DEV_IO_MODE="direct")
        for name in ("fib", "loop"):
            cmd = [str(args.legacy.resolve()), "run", str(args.legacy_programs.resolve() / (name + ".bnt")), *map(str, inputs[name])]
            checked(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=legacy_env)
            values = []
            for _ in range(args.iterations):
                started = time.perf_counter_ns()
                process = checked(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=legacy_env)
                if process.stdout != expected(name, inputs[name]):
                    raise ValueError("legacy output mismatch")
                values.append(time.perf_counter_ns() - started)
            old[name] = values
        data["legacy"] = old
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    write_report(args.output, data)
    print(args.output)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
