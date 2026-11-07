#!/usr/bin/env python3
"""書き出しの全 JSON を種類に分け、大きな文書は入力の列で分けて Validate.lean の manifest を作る。

分けた文書は元の文書の入力以外の欄をそのまま持つ。入力を省かない（分けた入力の件数の和を元と照合する）。
"""
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[4])
from stream_json import events  # noqa: E402
from classify import kind_of  # noqa: E402


def stream_fields(path):
    fields, first, count = {}, None, 0
    for kind, key, index, value in events(path):
        if key == "inputs":
            if kind == "item":
                if first is None:
                    first = value
                count += 1
            continue
        if kind == "array":
            fields[key] = []
        elif kind == "item":
            fields[key].append(value)
        elif kind == "field":
            fields[key] = value
    return fields, first, count


def split(path, fields, kind, out, limit):
    out.mkdir(parents=True, exist_ok=True)
    rows, chunk, size, total, part = [], [], 0, 0, 0

    def flush():
        nonlocal chunk, size, part
        if not chunk:
            return
        doc = dict(fields)
        doc["inputs"] = chunk
        target = out / f"{path.stem}.part{part:03d}.json"
        target.write_text(json.dumps(doc, ensure_ascii=False))
        rows.append([kind, str(target)])
        part += 1
        chunk, size = [], 0

    for k, key, index, value in events(path):
        if key == "inputs" and k == "item":
            text = json.dumps(value, ensure_ascii=False)
            if chunk and size + len(text) > limit:
                flush()
            chunk.append(value)
            size += len(text)
            total += 1
    flush()
    return rows, total


def main():
    root, manifest, limit, _, parts = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]), sys.argv[4], Path(sys.argv[5])
    rows, skipped, splits = [], [], []
    for p in sorted(root.rglob("*.json")):
        if p.stat().st_size <= limit:
            try:
                doc = json.loads(p.read_text())
            except ValueError as e:
                skipped.append([str(p.relative_to(root)), f"parse: {e}"])
                continue
            k = kind_of(doc)
            if k in (None, "empty"):
                skipped.append([str(p.relative_to(root)), k or "other"])
            else:
                rows.append([k, str(p)])
            continue
        fields, first, count = stream_fields(p)
        probe = dict(fields)
        probe["inputs"] = [first] if first is not None else []
        k = kind_of(probe)
        if k in (None, "empty", "coverage"):
            skipped.append([str(p.relative_to(root)), f"large {k or 'other'}"])
            continue
        part_rows, total = split(p, fields, k, parts / p.relative_to(root).parent, limit)
        assert total == count, (p, total, count)
        rows.extend(part_rows)
        splits.append({"file": str(p.relative_to(root)), "kind": k, "inputs": count, "parts": len(part_rows)})
    manifest.write_text(json.dumps(rows, indent=1) + "\n")
    report = {"entries": len(rows), "skipped": skipped, "splits": splits}
    manifest.with_suffix(".report.json").write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps({"entries": len(rows), "skipped": len(skipped), "splits": splits}, indent=1))


if __name__ == "__main__":
    main()
