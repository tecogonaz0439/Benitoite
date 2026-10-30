#!/usr/bin/env python3
"""P2 だけへ書き込む再検査。依存の追加・本番のビルド・git 操作はしない。"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
LOGS = HERE / "logs"
TARGET = HERE / "target"


def run(name, cmd, cwd):
    start = time.monotonic()
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=600)
    seconds = time.monotonic() - start
    (LOGS / f"{name}.log").write_text(p.stdout + p.stderr)
    record = dict(name=name, command=cmd, cwd=str(cwd), exit=p.returncode,
                  seconds=seconds, time=datetime.datetime.now().astimezone().isoformat(),
                  fallback_ru_maxrss_bytes=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
    with (LOGS / "verification.jsonl").open("a") as f:
        f.write(json.dumps(record) + "\n")
    print(json.dumps(record), flush=True)
    if p.returncode:
        print(p.stdout + p.stderr)
        raise SystemExit(p.returncode)
    return p.stdout


parser = argparse.ArgumentParser()
parser.add_argument("--rust", action="store_true")
parser.add_argument("--replay", action="store_true")
parser.add_argument("--clean", action="store_true")
args = parser.parse_args()
if args.rust:
    for verb in ("build", "test"):
        run(f"rust-{verb}", ["cargo", verb, "--locked", "--target-dir", str(TARGET)], HERE / "rust")
    run("rust-fmt", ["cargo", "fmt", "--", "--check"], HERE / "rust")
    table = run("rust-examples", [str(TARGET / "debug/p2-lia-spike"),
                                  str(HERE / "lean/generated.lean")], HERE / "rust")
    (HERE / "measurements.md").write_text(
        "# P2 の予算の実測\n\n非最適化のビルドを一度実行した値である。wall µs は参考値であり、性能比較に使わない。\n\n" + table)
if args.replay:
    base = (HERE / "lean/P2.lean").read_text()
    generated = (HERE / "lean/generated.lean").read_text().replace("import P2\n", "")
    replay = HERE / "lean/Replay.lean"
    replay.write_text(base + "\n" + generated)
    meta = {"base_sha256": hashlib.sha256(base.encode()).hexdigest(),
            "generated_sha256": hashlib.sha256(generated.encode()).hexdigest(),
            "guards": generated.count("#guard"), "replay": str(replay)}
    (LOGS / "replay-inputs.json").write_text(json.dumps(meta, indent=2) + "\n")
    # /usr/bin/time -l の失敗と Lean 本体の終了を分ける担当の runner。
    run("lean-replay-wrapper", [sys.executable, str(HERE / "lean/run.py"), "Replay.lean"], HERE)
    latest = json.loads((LOGS / "lean-runs.jsonl").read_text().splitlines()[-1])
    if latest.get("lean_exit") != 0:
        raise SystemExit("Lean 本体が終了0ではない")
    print(json.dumps(meta), flush=True)
if args.clean:
    if TARGET.exists():
        size = sum(p.stat().st_size for p in TARGET.rglob("*") if p.is_file())
        shutil.rmtree(TARGET)
        (LOGS / "cleanup.json").write_text(json.dumps(dict(target=str(TARGET), bytes=size,
                                            removed=not TARGET.exists()), indent=2) + "\n")
        print(f"P2/target を削除: {size} bytes", flush=True)
    probe = HERE / "lean/review_probe"
    if probe.exists():
        probe.unlink()
        print("照合用の一時の実行ファイルを削除: lean/review_probe", flush=True)
