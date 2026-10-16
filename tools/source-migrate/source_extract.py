"""ホストを復号し、元のファイルの UTF-8 バイト位置を対応付ける。"""
from __future__ import annotations
from dataclasses import dataclass
import re

@dataclass
class Snippet:
    source: str
    boundaries: list[int]
    kind: str
    hold: str | None = None


def markdown(data: bytes, *, accept=None):
    lines = data.splitlines(keepends=True)
    offset = 0
    fence = None
    content = bytearray()
    start = 0
    for line in lines:
        m = re.match(rb' {0,3}(`{3,}|~{3,})([^\r\n]*)', line)
        if fence is None and m:
            fence = (m[1][:1], len(m[1]), m[2].strip().decode('utf-8'))
            start = offset + len(line)
            content.clear()
        elif fence is not None:
            if m and m[1][:1] == fence[0] and len(m[1]) >= fence[1] and not m[2].strip():
                source = content.decode('utf-8')
                if fence[2] in ('text', 'bnt', 'benitoite', '') and (accept is None or accept(source)):
                    yield Snippet(source, list(range(start, start + len(content) + 1)), 'markdown')
                fence = None
            else:
                content.extend(line)
        offset += len(line)


def decode_rust(data: bytes, start: int, end: int):
    out = bytearray()
    boundaries = [start]
    i = start
    while i < end:
        begin = i
        if data[i] != 92:
            chunk = bytes([data[i]])
            i += 1
        else:
            i += 1
            c = data[i]
            simple = {110:b'\n',114:b'\r',116:b'\t',48:b'\0',92:b'\\',34:b'"',39:b"'"}
            if c in simple:
                chunk = simple[c]
                i += 1
            elif c == 120:
                chunk = bytes([int(data[i+1:i+3], 16)])
                i += 3
            elif c == 117 and data[i+1:i+2] == b'{':
                close = data.index(b'}', i+2, end)
                chunk = chr(int(data[i+2:close].replace(b'_', b''),16)).encode('utf-8')
                i = close + 1
            elif c in (10,13):
                while i < end and data[i] in b' \t\r\n':
                    i += 1
                boundaries[-1] = i
                continue
            else:
                raise ValueError('unsupported Rust escape')
        out.extend(chunk)
        # Unicode のエスケープの内部のバイト境界では編集できない。
        boundaries.extend([-1] * (len(chunk)-1) + [i])
    return out.decode('utf-8'), boundaries


def rust(data: bytes, *, accept=None):
    i = 0
    while i < len(data):
        if data[i:i+2] == b'//':
            stop = data.find(b'\n', i+2)
            i = len(data) if stop < 0 else stop + 1
            continue
        if data[i:i+2] == b'/*':
            depth = 1
            i += 2
            while i < len(data) and depth:
                if data[i:i+2] == b'/*': depth += 1; i += 2
                elif data[i:i+2] == b'*/': depth -= 1; i += 2
                else: i += 1
            continue
        # 寿命の印と文字リテラルを区別し、文字の中の引用符を文字列と誤認しない。
        char = re.match(rb"'(?:\\(?:u\{[0-9a-fA-F_]+\}|x[0-9a-fA-F]{2}|.)|[^'\\\r\n])'", data[i:])
        if char:
            i += len(char[0]); continue
        raw = re.match(rb'(?:br|r)(#{0,255})"', data[i:]) if i == 0 or not (chr(data[i-1]).isalnum() or data[i-1] == 95) else None
        is_bytes = False
        if raw:
            is_bytes = data[i:i+2] == b'br'
            start = i + len(raw[0])
            close = data.find(b'"' + raw[1], start)
            if close < 0: break
            end = close
            stop = close + 1 + len(raw[1])
            try: source = data[start:end].decode('utf-8'); boundaries = list(range(start,end+1))
            except UnicodeDecodeError: source = ''; boundaries = []
            kind = 'rust_raw'
        elif data[i:i+1] == b'"' or data[i:i+2] == b'b"':
            is_bytes = data[i:i+2] == b'b"'
            start = i + (2 if is_bytes else 1)
            end = start
            while end < len(data):
                if data[end] == 92: end += 2
                elif data[end] == 34: break
                else: end += 1
            stop = end + 1
            try: source, boundaries = decode_rust(data,start,end)
            except (ValueError,UnicodeDecodeError,IndexError): source = ''; boundaries = []
            kind = 'rust_string'
        else:
            i += 1; continue
        if accept is None or accept(source):
            prefix = data[max(0,i-160):i]
            generated = re.search(rb'(?:format|format_args|concat|write|writeln)!\([^;]*$', prefix) is not None
            generated = generated or re.match(rb'\s*(?:\.to_(?:string|owned)\(\)\s*)?\+', data[stop:]) is not None
            hold = 'generated_or_concatenated_rust' if generated else None
            if is_bytes: hold = 'byte_literal'
            yield Snippet(source,boundaries,kind,hold)
        i = stop


def snippets(path: str, data: bytes, *, accept=None):
    if path.endswith('.bnt') or path.startswith('fuzz/corpus/'):
        try: yield Snippet(data.decode('utf-8'),list(range(len(data)+1)), 'bnt')
        except UnicodeDecodeError: yield Snippet('',[0], 'invalid_utf8','invalid_utf8')
    elif path.endswith('.md'):
        yield from markdown(data, accept=accept)
    elif path.endswith('.rs'):
        yield from rust(data, accept=accept)
