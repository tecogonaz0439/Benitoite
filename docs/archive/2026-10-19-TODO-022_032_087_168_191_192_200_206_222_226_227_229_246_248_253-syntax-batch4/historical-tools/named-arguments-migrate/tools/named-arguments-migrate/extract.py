"""名前付き引数の移行で使うホストの選択方針と旧入口を保つ。"""
from __future__ import annotations
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'source-migrate'))
from source_extract import Snippet, decode_rust
from source_extract import markdown as _markdown, rust as _rust, snippets as _snippets

HINT = re.compile(r'\b(function|lambda|bind|language|public|import|uses|end function)\b|\b[A-Z][A-Za-z_0-9]*\.|\b[a-z][A-Za-z_0-9]*\s*\(')

def markdown(data: bytes):
    yield from _markdown(data, accept=HINT.search)


def rust(data: bytes):
    yield from _rust(data, accept=HINT.search)


def snippets(path: str, data: bytes):
    yield from _snippets(path, data, accept=HINT.search)
