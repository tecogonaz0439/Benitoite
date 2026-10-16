"""ホストに依存しない編集の検証、確認用の diff、検証後の適用を担う。"""
from __future__ import annotations

import difflib
import hashlib
import json
import pathlib


def sha(data: bytes) -> str:
    """元のホストのバイト列の SHA-256 を返す。"""
    return hashlib.sha256(data).hexdigest()


def dump(value) -> str:
    """確認データを、非 ASCII の文字を読める JSON にする。"""
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def safe_path(root, name: str) -> pathlib.Path:
    """根からの相対パスを検証する。適用先の除外方針は呼び出し側が守る。"""
    root = pathlib.Path(root).resolve()
    path = pathlib.PurePosixPath(name)
    if not path.parts or path.is_absolute() or '..' in path.parts:
        raise ValueError('unsafe path: ' + name)
    target = root / path
    if target.is_symlink() or not target.resolve().is_relative_to(root):
        raise ValueError('unsafe path: ' + name)
    return target


def proposed(rows, path_for) -> dict:
    """全編集を検証し、書き込まずに変更前後のバイト列を返す。

    各行は path・source_sha256・edits（start/end/before/after）を持つ。
    確認状態・保留・意味上の依存は呼び出し側が検証する。
    """
    grouped = {}
    for row in rows:
        if row['edits']:
            grouped.setdefault(row['path'], []).append(row)
    results = {}
    for path, candidates in grouped.items():
        original = path_for(path).read_bytes()
        if {r['source_sha256'] for r in candidates} != {sha(original)}:
            raise ValueError('source hash mismatch: ' + path)
        edits = {(e['start'], e['end'], e['before'], e['after'])
                 for row in candidates for e in row['edits']}
        ordered = sorted(edits)
        prev_end = -1
        prev_start = -1
        for start, end, before, after in ordered:
            if not 0 <= start <= end <= len(original):
                raise ValueError('invalid range: ' + path)
            # 同じ開始位置の挿入と置換は共存できる。異なる二重挿入は拒否する。
            if start < prev_end or (start == prev_start and end == start):
                raise ValueError('overlapping edits: ' + path)
            if original[start:end] != before.encode():
                raise ValueError('range content mismatch: ' + path)
            prev_end = end
            prev_start = start
        updated = original
        for start, end, before, after in reversed(ordered):
            updated = updated[:start] + after.encode() + updated[end:]
        results[path] = (original, updated)
    return results


def write_diff(results, output) -> None:
    """ホストの改行を保ち、パス順の unified diff を書く。"""
    chunks = []
    for path, (before, after) in sorted(results.items()):
        chunks.extend(difflib.unified_diff(
            before.decode().splitlines(keepends=True),
            after.decode().splitlines(keepends=True),
            fromfile='a/' + path, tofile='b/' + path))
    pathlib.Path(output).write_text(''.join(chunks))


def reviewed_manifest(path, digest: str):
    """外から渡された確認済みハッシュと一致する manifest だけを読む。"""
    raw = pathlib.Path(path).read_bytes()
    if sha(raw) != digest:
        raise ValueError('reviewed manifest hash mismatch')
    return json.loads(raw)


def apply(inputs, rows, *, manifest_sha256: str, receipt, path_for):
    """全入力と範囲の検証後に書き込む。再適用では変更後の一致を確かめる。

    書き込んだファイル数を返し、検証済みの再適用では None を返す。
    承認済みの行の選択と保留・依存の検証は呼び出し側が先に行う。
    """
    source_hashes = {}
    for unit in inputs:
        path, digest = unit['path'], unit['source_sha256']
        if path in source_hashes and source_hashes[path] != digest:
            raise ValueError('conflicting input hashes: ' + path)
        source_hashes[path] = digest
    rows = list(rows)
    for row in rows:
        if source_hashes.get(row['path']) != row['source_sha256']:
            raise ValueError('candidate input hash mismatch: ' + row['path'])
    receipt = pathlib.Path(receipt)
    if receipt.exists():
        record = json.loads(receipt.read_text())
        if (record['manifest_sha256'] != manifest_sha256
                or set(record['files']) != set(source_hashes)
                or any(sha(path_for(p).read_bytes()) != h
                       for p, h in record['files'].items())):
            raise ValueError('applied receipt mismatch')
        return None
    for path, digest in source_hashes.items():
        if sha(path_for(path).read_bytes()) != digest:
            raise ValueError('input hash mismatch: ' + path)
    results = proposed(rows, path_for)
    for path, (before, after) in results.items():
        path_for(path).write_bytes(after)
    receipt.write_text(dump({
        'manifest_sha256': manifest_sha256,
        'files': {**source_hashes, **{p: sha(after) for p, (_, after) in results.items()}},
    }))
    return len(results)
