#!/usr/bin/env python3
"""群 X の指定されたビルド・境界・完全署名・公理依存の検証。"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
# レビュー原本・補助入力と、今回変更しないと指定された本番定義を固定する。
state = json.loads((HERE / "source-state.json").read_text())
for group in ["after", "verification_inputs"]:
    for name, expected in state[group].items():
        actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        if actual != expected:
            raise SystemExit("検証対象のハッシュが不一致: " + name)
for name in state["review_protected_unchanged"]:
    actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    if actual != state["review_before"][name]:
        raise SystemExit("レビュー再開後の保護対象に変更: " + name)
for name in state["protected_unchanged"]:
    if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != state["before"][name]:
        raise SystemExit("主な定理などの保護対象に変更: " + name)
# lake 自体の引数ではなく、各 Lean プロセスの引数を確認する。
lake = (ROOT / "formal/lakefile.toml").read_text()
if not re.search(r'^moreLeanArgs\s*=\s*\["-M",\s*"12288"\]\s*$', lake, re.M):
    raise SystemExit("既定ビルドの Lean メモリ上限が指定と異なる")

TEMP = Path(tempfile.mkdtemp(prefix="benitoite-l10-x-"))
steps = [
    ("build", ["lake", "build"]),
    ("boundary", ["lake", "env", "lean", "-M", "12288", str(HERE.relative_to(ROOT) / "boundary.lean")]),
    ("signatures", ["lake", "env", "lean", "-M", "12288", str(HERE.relative_to(ROOT) / "signatures.lean")]),
    ("axioms", ["lake", "env", "lean", "-M", "12288", str(HERE.relative_to(ROOT) / "axioms.lean")]),
]
parser = argparse.ArgumentParser()
parser.add_argument("--from", dest="resume", choices=[label for label, _ in steps])
args = parser.parse_args()
records = []
if args.resume:
    index = [label for label, _ in steps].index(args.resume)
    records = json.loads((HERE / "verification.json").read_text())[:index]
    if any(record["exit"] for record in records):
        raise SystemExit("失敗した手順を飛ばして再開できない")
    steps = steps[index:]
large = []
for label, command in steps:
    if label != "build":
        command[-1] = "../" + command[-1]
    log = TEMP / (label + ".txt")
    start = time.time()
    with log.open("wb") as out:
        result = subprocess.run(command, cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
    elapsed = time.time() - start
    data = log.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    saved = label + "-output.txt"
    if len(data) <= 100_000:
        (HERE / saved).write_bytes(data)
    else:
        saved = "<tmp>/" + label + ".txt"
        large.append((saved, len(data), digest))
    records.append({"step": label, "cwd": "formal", "command": command,
                    "exit": result.returncode, "seconds": round(elapsed, 3),
                    "bytes": len(data), "sha256": digest, "output": saved})
    (HERE / "verification.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print(label, result.returncode, round(elapsed, 3), len(data), flush=True)
    if result.returncode:
        print(data.decode(errors="replace")[-10000:], flush=True)
        raise SystemExit(result.returncode)
    if label in {"axioms", "boundary"}:
        output = data.decode()
        groups = re.findall(r"depends on axioms:\s*\[([^]]*)\]", output, re.S)
        deps = sorted({a.strip() for g in groups for a in g.split(",") if a.strip()})
        allowed = {"propext", "Quot.sound", "Classical.choice"}
        if set(deps) - allowed or "sorryAx" in output:
            raise SystemExit("許可しない公理への依存: " + str(deps))
        summary = {"dependencies": deps, "printed_declarations": len(groups) + output.count("does not depend on any axioms"),
                   "modules": re.findall(r"AUDIT_MODULE (\S+) (\d+)", output),
                   "case_totals": re.findall(r"CASE_TOTAL (\S+) (\d+)", output)}
        (HERE / (label + "-summary.json")).write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
        if label == "axioms":
            rows = re.findall(r"^CASE (\S+) (\S+) (\S+)$", output, re.M)
            (HERE / "case-matrix.tsv").write_text("family\tjudgment\tconstructor\n" + "".join("\t".join(r) + "\n" for r in rows))
(HERE / "large-records.md").write_text("# 大きい生の記録\n\n100,000 bytes を超える生の出力は一時領域へ保存した。絶対パスは記録しない。\n\n| 記録 | bytes | SHA-256 |\n|---|---:|---|\n" + "".join(f"| {name} | {size} | `{digest}` |\n" for name, size, digest in large))
