#!/usr/bin/env python3
"""git show で開始版を読み、finally で作業中のファイルを復元する。"""
import hashlib
import json
from pathlib import Path
import subprocess

out = Path(__file__).resolve().parent
repo = out.parents[2]
source = Path("crates/benitoite/src/typeck/interval/flow/matching.rs")
target = repo / source
original = target.read_bytes()
base = "ef4319f89aab95f6ebc3a0e346da64066e204e59"
status = None
try:
    target.write_bytes(subprocess.check_output(["git", "show", base + ":" + str(source)], cwd=repo))
    status = subprocess.call(["cargo", "test", "-p", "benitoite", "--lib", "typeck::interval::tests::range_calls", "--", "--nocapture"], cwd=repo)
finally:
    target.write_bytes(original)
    restored = target.read_bytes() == original
    (out / "baseline-restore.json").write_text(json.dumps({"file": str(source), "baseline": base, "test_exit": status, "restored": restored, "sha256": hashlib.sha256(original).hexdigest()}, indent=2) + "\n")
if not restored or status != 101:
    raise SystemExit(1)
