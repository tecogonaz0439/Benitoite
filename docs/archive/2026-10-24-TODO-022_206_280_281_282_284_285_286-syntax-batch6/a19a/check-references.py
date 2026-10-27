#!/usr/bin/env python3
"""既存の表を変えず、L25S と同じ第三欄の明示で Lean の実行値と比較する。"""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
DIRECTORY = ROOT / "crates/benitoite/testdata/interval-budget"
LOG = OUT / "reference-compatible-output"
LOG.mkdir(exist_ok=True)
spec = importlib.util.spec_from_file_location("reference", DIRECTORY / "regenerate-reference.py")
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


def redact(value):
    for path, replacement in [(str(ROOT), "<repo>"), (str(Path.home()), "<home>"),
                              (tempfile.gettempdir(), "<tmp>")]:
        value = value.replace(path, replacement)
    return value


def lean_rows(filename, width, log_dir, declarations):
    source = (DIRECTORY / filename).read_text()
    source = source.replace("-- RANGE_EXCHANGE: regenerate-reference.py が実交換から宣言をここへ渡す。", declarations)
    for old in ["⟨referenceRangeCheck, .rangeCheck referenceRangeNames⟩",
                "⟨referenceRangeValue, .rangeValue referenceRangeNames.record⟩"]:
        assert source.count(old) == 1
        source = source.replace(old, old[:-1] + ", []⟩")
    with tempfile.NamedTemporaryFile(mode="w", suffix=".lean", dir=ROOT / "target", delete=False) as stream:
        stream.write(source)
        path = Path(stream.name)
    command = ["lake", "env", "lean", "-M", "12288", str(path)]
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT / "formal", stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
    finally:
        path.unlink()
    (LOG / (filename + ".log")).write_text(redact(result.stdout))
    info = {"command": [redact(arg) for arg in command], "exit": result.returncode,
            "seconds": time.monotonic() - started}
    (LOG / (filename + ".json")).write_text(json.dumps(info, indent=2) + "\n")
    print(json.dumps(info), flush=True)
    if result.returncode:
        raise RuntimeError(redact(result.stdout[-5000:]))
    rows = [line.split("\t") for line in result.stdout.splitlines()]
    return [row for row in rows if len(row) in width and row[1].isdigit()]


reference.lean_rows = lean_rows
declarations = reference.range_declarations(None, LOG)
tables = reference.generate(LOG, declarations)
summary = {}
for name, rows in tables.items():
    source = "summary-reference.lean" if name == "summary" else "budget-reference.lean"
    header = ("# 設計書 02-05「区間解析の駆動と予算」「区間解析の報告の集計」; "
              f"Lean testdata/interval-budget/{source}; "
              "regenerate-reference.py; independent expectations\n")
    output = (header + "\n".join("\t".join(row) for row in rows) + "\n").encode()
    saved = (DIRECTORY / (name + ".tsv")).read_bytes()
    summary[name] = {"rows": len(rows), "identical": saved == output,
                     "saved_sha256": hashlib.sha256(saved).hexdigest(),
                     "computed_sha256": hashlib.sha256(output).hexdigest()}
(OUT / "reference-comparison.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary), flush=True)
assert all(value["identical"] for value in summary.values()), "固定表に差があるため停止する"
