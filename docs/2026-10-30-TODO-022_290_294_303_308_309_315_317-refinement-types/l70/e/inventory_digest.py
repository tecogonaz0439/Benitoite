# -*- coding: utf-8 -*-
"""前半の一時領域の一覧を、群ごとの件数・大きさ・連結順のSHA-256へまとめる。"""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
a = parser.parse_args()
summary = {"historical_b_work": "aab9025f1f366d6d190298869add18181af7eeb6", "groups": {}}
for label, pattern in [("baseline", "baseline-[0-9]*.json"), ("declarations", "declarations-[0-9]*.json")]:
    chunks = sorted(a.tmp.glob(pattern))
    assert chunks
    files = chunks + ([a.tmp / "baseline-root.txt"] if label == "baseline" else [])
    summary["groups"][label] = {"chunks": len(chunks), "entries": sum(len(json.loads(p.read_text())) for p in chunks),
        "bytes": sum(p.stat().st_size for p in files),
        "sha256_concatenated": hashlib.sha256(b"".join(p.read_bytes() for p in files)).hexdigest()}
print(json.dumps(summary, indent=1))
