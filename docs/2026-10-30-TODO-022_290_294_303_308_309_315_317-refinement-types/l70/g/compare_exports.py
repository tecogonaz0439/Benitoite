#!/usr/bin/env python3
"""新旧の全書き出しの入力・除外と、形式だけを除いた JSON を照合する。"""
import argparse
import collections
import hashlib
import json
import itertools
from stream_json import events
from pathlib import Path


def digest(path):
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
            size += len(block)
    return {"bytes": size, "sha256": h.hexdigest()}


def normalize(value, root):
    if isinstance(value, list):
        return [normalize(v, root) for v in value]
    if isinstance(value, str):
        return value.replace(str(root), "<export>")
    if not isinstance(value, dict):
        return value
    value = dict(value)
    # 新版で必須になった空の欄は、旧版の省略と同じ意味として比較する。
    # 非空の候補・注釈・範囲列は残し、その内容を通常の比較へ渡す。
    for key, empty in [("candidates", []), ("annotations", {}), ("ranges", [])]:
        if value.get(key) == empty:
            value.pop(key)
    # 現行の処理系は新機能を持たない。新しい欄が実質的な内容を持つなら比較を止める。
    for key in ["aliases", "records", "testers", "externals", "logicCertificates", "rangeParams", "requirements", "publicBoundary"]:
        if key in value:
            assert value.pop(key) == [], (key, "expected empty new field")
    if "opaqueNames" in value:
        entries = value.pop("opaqueNames")
        assert all(len(pair) == 2 and all(isinstance(v, str) for v in pair) for pair in entries)
    if "variances" in value:
        assert value.pop("variances") == ["invariant"] * value["ntys"]
    if "constructors" in value and "builtin" in value and "typeName" in value:
        assert all(len(pair) == 2 and all(isinstance(v, str) for v in pair) for pair in value.pop("constructors"))
    if "proofSteps" in value:
        assert value.pop("proofSteps") is None
    if "tparamKinds" in value:
        kinds = value.pop("tparamKinds")
        assert len(kinds) == len(value["tparams"])
        assert all(k == "value" or isinstance(k, dict) and set(k) == {"constructor"}
                   and isinstance(k["constructor"].get("arity"), int) and k["constructor"]["arity"] > 0
                   for k in kinds)
    if "argumentKind" in value:
        kind = value.pop("argumentKind")
        assert kind == "value" or isinstance(kind, dict) and set(kind) == {"constructor"}
    if "version" in value and value["version"] != 1:
        value["version"] = "exchange"
    if "surfaceVersion" in value:
        value["surfaceVersion"] = "surface-exchange"
    if isinstance(value.get("ranges"), list):
        value["ranges"] = [v["fixed"] if isinstance(v, dict) and set(v) == {"fixed"} else v
                           for v in value["ranges"]]
    return {k: normalize(v, root) for k, v in value.items()}


def exclusions(value, results):
    if isinstance(value, list):
        for v in value:
            exclusions(v, results)
    elif isinstance(value, dict):
        if "group" in value and "name" in value:
            identity = (value["group"], value["name"])
            if "excluded" in value:
                results["inputs"].append(identity)
                for reason in value["excluded"]:
                    results["excluded"].append((identity, reason))
        if value.get("reason") == "externalType":
            results["externalType"].append(value)
        for v in value.values():
            exclusions(v, results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.old, args.new = args.old.resolve(), args.new.resolve()
    old_files = {p.relative_to(args.old): p for p in args.old.rglob("*.json")}
    new_files = {p.relative_to(args.new): p for p in args.new.rglob("*.json")}
    assert set(old_files) == set(new_files), (set(old_files) - set(new_files), set(new_files) - set(old_files))
    assert old_files, "empty corpus"
    rows, totals = [], collections.Counter()
    external_reasons = collections.Counter()
    for name in sorted(old_files):
        a, b = collections.defaultdict(list), collections.defaultdict(list)
        for left, right in itertools.zip_longest(events(old_files[name]), events(new_files[name])):
            assert left is not None and right is not None, (str(name), "JSON event count differs")
            assert left[:3] == right[:3], (str(name), left[:3], right[:3])
            kind, key, index, old = left
            new = right[3]
            if kind == "field":
                before = normalize({key: old}, args.old)
                after = normalize({key: new}, args.new)
            else:
                before, after = normalize(old, args.old), normalize(new, args.new)
            assert before == after, (str(name), key, index)
            exclusions(before, a)
            exclusions(after, b)
        assert a == b, (str(name), "inputs or exclusions changed")
        for key in a:
            totals[key] += len(a[key])
        for _, reason in a["excluded"]:
            category = reason if isinstance(reason, str) else reason.get("reason", "structured exclusion")
            external_reasons[category] += 1
        rows.append({"file": str(name), "old": digest(old_files[name]), "new": digest(new_files[name]),
                     "counts": {k: len(v) for k, v in a.items()}})
    encoded = (json.dumps(rows, ensure_ascii=False, sort_keys=True) + "\n").encode()
    # 全ファイルの一覧は一時領域に置き、改造には集計と指紋を保存する。
    listing = args.output.with_suffix(".files.json")
    listing.write_bytes(encoded)
    summary = {"files": len(rows), "counts": dict(totals), "excluded_reasons": dict(external_reasons),
               "old_bytes": sum(r["old"]["bytes"] for r in rows),
               "new_bytes": sum(r["new"]["bytes"] for r in rows),
               "files_digest": digest(listing)}
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
