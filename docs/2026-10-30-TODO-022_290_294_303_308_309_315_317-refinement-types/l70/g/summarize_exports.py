#!/usr/bin/env python3
"""全入力をメモリに保持せず、書き出しの件数・除外理由・指紋を集計する。"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
from compare_exports import digest
from stream_json import events
from records import ROOT


def count(value, counts, reasons):
    if isinstance(value, list):
        for v in value:
            count(v, counts, reasons)
    elif isinstance(value, dict):
        if "group" in value and "name" in value and "excluded" in value:
            counts["source_inputs"] += 1
            counts["excluded_inputs"] += bool(value["excluded"])
            for reason in value["excluded"]:
                category = reason if isinstance(reason, str) else reason.get("reason", "structured exclusion")
                reasons[category.replace(str(ROOT), "<repo>")] += 1
        if value.get("reason") == "externalType":
            counts["externalType"] += 1
        for v in value.values():
            count(v, counts, reasons)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--listing", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    totals, reasons, rows, main_corpus = collections.Counter(), collections.Counter(), [], None
    for p in sorted(args.directory.rglob("*.json")):
        counts, local_reasons = collections.Counter(), collections.Counter()
        for kind, key, index, value in events(p):
            if kind == "end":
                counts["root_" + (key or "array")] = index
            count(value, counts, local_reasons)
        totals.update(counts)
        reasons.update(local_reasons)
        row = {"file": str(p.relative_to(args.directory)), "digest": digest(p),
               "counts": dict(counts), "reasons": dict(local_reasons)}
        rows.append(row)
        if p.name == "named-programs-corpus.json" and p.parent == args.directory:
            main_corpus = {"counts": dict(counts), "reasons": dict(local_reasons)}
    args.listing.write_text(json.dumps(rows, ensure_ascii=False, sort_keys=True) + "\n")
    summary = {"files": len(rows), "bytes": sum(r["digest"]["bytes"] for r in rows),
               "counts": dict(totals), "reasons": dict(reasons), "main_corpus": main_corpus,
               "listing": digest(args.listing)}
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    assert args.output.stat().st_size <= 100000
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
