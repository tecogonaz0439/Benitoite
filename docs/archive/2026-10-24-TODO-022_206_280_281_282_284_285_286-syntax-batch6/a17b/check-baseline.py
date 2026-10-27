#!/usr/bin/env python3
"""開始版を読み、射影の退行を確認後に作業中のファイルを必ず復元する。"""
import hashlib
import json
from pathlib import Path
import subprocess

out = Path(__file__).resolve().parent
repo = out.parents[2]
base = "0aa2bd66829f6a3f1f5c3ec23d7290c4ea13ec64"
sources = [Path("crates/benitoite/src/typeck/interval") / p for p in ["flow.rs", "flow/range.rs"]]
originals = {p: (repo / p).read_bytes() for p in sources}
status = None
try:
    for source in sources:
        (repo / source).write_bytes(subprocess.check_output(["git", "show", base + ":" + str(source)], cwd=repo))
    status = subprocess.call(["cargo", "test", "-p", "benitoite", "--lib", "range_projection", "--", "--nocapture"], cwd=repo)
finally:
    for source, original in originals.items():
        (repo / source).write_bytes(original)
    restored = all((repo / p).read_bytes() == original for p, original in originals.items())
    (out / "baseline-restore.json").write_text(json.dumps({
        "baseline": base, "test_exit": status, "restored": restored,
        "sha256": {str(p): hashlib.sha256(original).hexdigest() for p, original in originals.items()},
    }, indent=2) + "\n")
if not restored or status != 101:
    raise SystemExit(1)
