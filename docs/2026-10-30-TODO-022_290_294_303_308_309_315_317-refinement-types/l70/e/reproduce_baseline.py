# -*- coding: utf-8 -*-
"""取りまとめ・レビュー向け。固定開始版を読み取りのGitで一覧へ復元する。作業担当は実行しない。"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True
from inventory import ROOT, B_WORK

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
a = parser.parse_args()
a.tmp.mkdir(parents=True, exist_ok=True)
assert not (a.tmp / "baseline.json").exists(), "一覧を上書きしない"
paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", B_WORK, "--",
    "formal/Benitoite", "formal/Benitoite.lean", "docs/design"], cwd=ROOT, text=True).splitlines()
paths = sorted(p for p in paths if
    (p.startswith("formal/Benitoite/") and p.endswith(".lean")) or p == "formal/Benitoite.lean" or
    (p.startswith("docs/design/") and p.endswith(".md")))
raw = subprocess.check_output(["git", "cat-file", "--batch"], cwd=ROOT,
    input="".join(B_WORK + ":" + p + "\n" for p in paths).encode())
rows, offset = {}, 0
for p in paths:
    end = raw.index(b"\n", offset)
    header = raw[offset:end].split()
    assert len(header) == 3 and header[1] == b"blob"
    size = int(header[2]); content = raw[end+1:end+1+size]
    assert len(content) == size and raw[end+1+size:end+2+size] == b"\n"
    rows[p] = hashlib.sha256(content).hexdigest()
    if p == "formal/Benitoite.lean":
        (a.tmp / "baseline-root.txt").write_bytes(content)
    offset = end+2+size
assert offset == len(raw)
(a.tmp / "baseline.json").write_text(json.dumps(rows, sort_keys=True))
print(json.dumps({"b_work": B_WORK, "files": len(rows)}, indent=1))
