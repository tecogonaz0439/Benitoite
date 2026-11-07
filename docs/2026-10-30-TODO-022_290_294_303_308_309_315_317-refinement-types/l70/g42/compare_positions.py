#!/usr/bin/env python3
"""新旧の全書き出しを、交換の新しい欄の位置だけを許して照合する。

旧版（コーパス15・表7・独立の網羅性4）と新しい版（16/8）の書き出しを、ファイルごとに JSON の構造の列で
比べる。新しい書き出しにだけある欄は、文書の種類とその構造の位置（Lean の `Exchange.Syntax`・
`Exchange.Builtins` の構造）で決めた欄だけを許し、空・null・不変の変性などの中身も確かめる。値を持つ
四欄（`tparamKinds`・`argumentKind`・`constructors`・`opaqueNames`）は、個数と形だけをここで確かめ、
中身は `check_value_fields.py` が照らす。版の番号は根の版の欄だけを、旧→新の既知の対応に限って許す。
範囲の実引数は、関数と組込みの参照の位置でだけ範囲の位置（`{"fixed": …}`）の形を旧版の形へ戻す。
交換でない文書は、作業木と出力先の絶対パスのほかは一致を要求する。

`--changed <相対パス>` で名指しした文書は、意図して中身を変えた文書として構造の照合から外し、大きさと指紋だけを記す。

使い方: `compare_positions.py --old <旧> --new <新> --output <要約> [--map <パス> <印>]... [--changed <相対パス>]... [--jobs N]`
"""
import argparse
import collections
import itertools
import json
import sys
from multiprocessing import Pool
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "g"))
from stream_json import events  # noqa: E402
import compare_exports  # noqa: E402

# 根の版の欄の旧→新の対応（文書の種類ごと）。独立の網羅性は、名前付きの書き出しが版4、batch5 の局所の
# 書き出しが付随の表と同じ版7であった。
VERSIONS = {"corpus": {"version": {(15, 16)}}, "table": {"version": {(7, 8)}}, "stdlib": {"version": {(7, 8)}},
            "coverage-program": {"version": {(7, 8)}}, "coverage": {"version": {(4, 8), (7, 8)}},
            "interval": {"surfaceVersion": {(15, 16)}}}
# `fragments` は区間の交換の式の断片を持つ文書（material・manifest・対応表・VM の地点）である。
HEADER_DOCUMENTS = {"corpus", "stdlib", "interval", "fragments"}
REF_DOCUMENTS = {"corpus", "interval", "fragments"}
FUNCTION_REFS = {"funName", "funDicts", "fnRef"}
PRIMITIVE_REFS = {"prim", "primName"}
MAPS = []


def relocated(value):
    for source, mark in MAPS:
        value = value.replace(source, mark)
    return value


def kind_of(path):
    """根の欄と最初の入力から文書の種類を決める。"""
    with path.open("rb") as f:
        f.seek(max(0, path.stat().st_size - 400000))
        tail = f.read().decode("utf-8", "replace")
    if '"kind":"interval-corpus"' in tail:
        return "interval"
    with path.open("rb") as f:
        head = f.read(200).decode("utf-8", "replace")
    if '"kind":"interval-source-material"' in tail or '"kind":"interval-source-manifest"' in tail \
            or head.startswith('{"sites":'):
        return "fragments"
    if head.startswith("["):
        first = next((v for k, _, _, v in events(path) if k == "item"), None)
        return "fragments" if isinstance(first, dict) and "correspondence" in first else "record"
    if '"seedXor"' in tail:
        return "coverage"
    if '"operators":' in tail:
        return "corpus"
    first = next((v for k, key, _, v in events(path) if key == "inputs" and k == "item"), None)
    keys = set(first) if isinstance(first, dict) else set()
    if keys:
        if "prims" in keys:
            return "table"
        if "functions" in keys:
            return "stdlib"
        if {"matches", "bindings"} <= keys:
            return "coverage-program"
        if {"group", "excluded", "definitions"} <= keys and '"version":' in tail and '"kind":' not in tail[-300:]:
            # 演算子の表を持たない、入力だけのコーパス（検査で除いた入力の書き出し）。
            return "corpus"
    return "record"


def new_only(kind, path, key, value, sibling):
    """新しい書き出しにだけある欄 `key` を、この位置で許すか。許すなら中身も確かめる。"""
    last = path[-1] if path else None
    if kind == "corpus" and path == ("inputs", "*"):
        if key in ("aliases", "records", "testers", "externals", "logicCertificates"):
            return value == []
        if key == "candidates":
            return value == []
    if kind == "corpus" and path == ("inputs", "*", "definitions", "*") and key == "annotations":
        return value == {}
    if kind == "corpus" and path == ("inputs", "*", "classes", "*") and key == "argumentKind":
        return value == "value" or (isinstance(value, dict) and set(value) == {"constructor"})
    if kind == "corpus" and path == ("inputs", "*", "dataTypes", "*") and key == "constructors":
        return isinstance(value, list) and all(isinstance(p, list) and len(p) == 2 for p in value)
    header = (kind in HEADER_DOCUMENTS and last == "header") or \
        (kind == "table" and path == ("inputs", "*", "prims", "*"))
    if header and key == "tparamKinds":
        return isinstance(value, list) and len(value) == len(sibling["tparams"])
    if header and kind != "table" and key == "rangeParams":
        return value == []
    if header and kind != "table" and key == "proofSteps":
        return value is None
    if kind in REF_DOCUMENTS and last in FUNCTION_REFS and key == "ranges":
        return value == []
    if kind == "table" and path == ("inputs", "*") and key == "opaqueNames":
        return isinstance(value, list) and all(isinstance(p, list) and len(p) == 2 for p in value)
    if kind == "table" and path == ("inputs", "*", "dataDecls", "*"):
        if key == "variances":
            return value == ["invariant"] * sibling["ntys"]
        if key in ("requirements", "publicBoundary"):
            return value == []
    return False


def position(path):
    """集計の位置の名前。入力・定義などの浅い位置は全体を、深い位置は最後の欄の名前を使う。"""
    return "/".join(path) if len(path) <= 4 else ".../" + path[-1]


def same(kind, path, old, new, found):
    if isinstance(old, dict) and isinstance(new, dict):
        for key in new:
            if key not in old:
                if not new_only(kind, path, key, new[key], new):
                    return f"{'/'.join(path)}/{key}: unexpected new field"
                found[(kind, position(path), key)] += 1
        for key, value in old.items():
            if key not in new:
                return f"{'/'.join(path)}/{key}: missing field"
            child = new[key]
            if key == "ranges" and kind in REF_DOCUMENTS and path and path[-1] in PRIMITIVE_REFS:
                if not isinstance(child, list) or any(not (isinstance(r, dict) and set(r) == {"fixed"})
                                                      for r in child):
                    return f"{'/'.join(path)}/ranges: not range positions"
                child = [r["fixed"] for r in child]
                found[(kind, position(path), "ranges(fixed)")] += 1
            error = same(kind, path + (key,), value, child, found)
            if error:
                return error
        return None
    if isinstance(old, list) and isinstance(new, list):
        if len(old) != len(new):
            return f"{'/'.join(path)}: length {len(old)} != {len(new)}"
        for a, b in zip(old, new):
            error = same(kind, path + ("*",), a, b, found)
            if error:
                return error
        return None
    if isinstance(old, str) and isinstance(new, str):
        return None if relocated(old) == relocated(new) else f"{'/'.join(path)}: string differs"
    if type(old) is not type(new) or old != new:
        return f"{'/'.join(path)}: {json.dumps(old)[:80]} != {json.dumps(new)[:80]}"
    return None


def compare_file(job):
    name, old_path, new_path, maps = job
    MAPS[:] = maps
    kind = kind_of(new_path)
    assert kind == kind_of(old_path), (name, kind, kind_of(old_path))
    found = collections.Counter()
    a, b = collections.defaultdict(list), collections.defaultdict(list)
    for left, right in itertools.zip_longest(events(old_path), events(new_path)):
        assert left is not None and right is not None, (name, "JSON event count differs")
        assert left[:3] == right[:3], (name, left[:3], right[:3])
        event, key, index, old = left
        new = right[3]
        if event == "field" and key in VERSIONS.get(kind, {}) and old != new:
            assert (old, new) in VERSIONS[kind][key], (name, key, old, new)
            found[(kind, "", f"{key} {old}->{new}")] += 1
            continue
        path = (key, "*") if event == "item" else (key,)
        error = same(kind, path if key else (), old, new, found)
        assert error is None, (name, key, index, error)
        compare_exports.exclusions(old, a)
        compare_exports.exclusions(new, b)
    def deep(value):
        if isinstance(value, str):
            return relocated(value)
        if isinstance(value, (list, tuple)):
            return [deep(v) for v in value]
        if isinstance(value, dict):
            return {k: deep(v) for k, v in value.items()}
        return value
    a, b = deep(dict(a)), deep(dict(b))
    assert a == b, (name, "inputs or exclusions changed")
    return {"file": name, "kind": kind, "old": compare_exports.digest(old_path),
            "new": compare_exports.digest(new_path), "counts": {k: len(v) for k, v in a.items()},
            "newFields": {"|".join(k): v for k, v in found.items()},
            "excluded": [r if isinstance(r, str) else r.get("reason", "structured exclusion")
                         for _, r in a.get("excluded", [])]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--map", nargs=2, action="append", default=[])
    parser.add_argument("--changed", action="append", default=[])
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    # 一方が他方の接頭辞になるパス（作業木の名前の末尾が違うだけのもの）を、長い方から先に置き換える。
    maps = sorted((tuple(m) for m in args.map), key=lambda m: -len(m[0]))
    old, new = args.old.resolve(), args.new.resolve()
    old_files = {p.relative_to(old): p for p in old.rglob("*.json")}
    new_files = {p.relative_to(new): p for p in new.rglob("*.json")}
    assert set(old_files) == set(new_files), (set(old_files) - set(new_files), set(new_files) - set(old_files))
    assert old_files, "empty corpus"
    changed = [Path(c) for c in args.changed]
    assert all(c in old_files for c in changed), changed
    names = sorted((n for n in old_files if n not in changed), key=lambda n: -old_files[n].stat().st_size)
    jobs = [(str(n), old_files[n], new_files[n], maps) for n in names]
    with Pool(args.jobs) as pool:
        rows = pool.map(compare_file, jobs, chunksize=1)
    rows.sort(key=lambda r: r["file"])
    totals, reasons, kinds, fields = collections.Counter(), collections.Counter(), collections.Counter(), \
        collections.Counter()
    for r in rows:
        totals.update(r["counts"])
        kinds[r["kind"]] += 1
        fields.update(r["newFields"])
        for reason in r.pop("excluded"):
            reasons[relocated(reason)] += 1
    listing = args.output.with_suffix(".files.json")
    listing.write_bytes((json.dumps(rows, ensure_ascii=False, sort_keys=True) + "\n").encode())
    summary = {"files": len(rows), "changedFiles": [{"file": str(c), "old": compare_exports.digest(old_files[c]),
                                                    "new": compare_exports.digest(new_files[c])} for c in changed],
               "kinds": dict(kinds), "counts": dict(totals),
               "excluded_reasons": dict(reasons), "newFields": dict(sorted(fields.items())),
               "old_bytes": sum(old_files[n].stat().st_size for n in old_files),
               "new_bytes": sum(new_files[n].stat().st_size for n in new_files),
               "files_digest": compare_exports.digest(listing)}
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
