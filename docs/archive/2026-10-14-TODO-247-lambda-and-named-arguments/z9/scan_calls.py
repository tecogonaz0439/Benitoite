#!/usr/bin/env python3
"""複数行を含む文書から、位置指定の複数引数の呼び出しの候補を探す。

レビューの補助であり、数式・宣言・比較する他言語・移行前の例は文脈を読んで判別する。
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / 'Cargo.toml').is_file())
HANDWRITTEN = ('SKILL.md', 'references/idioms.md',
               'references/common-mistakes.md', 'references/language-comparison.md')


def fragments(source):
    """元の文字位置を保持してコードブロックとインラインコードを取り出す。"""
    offset = 0
    fence = None
    body = []
    for line in source.splitlines(keepends=True):
        marker = re.match(r' {0,3}(`{3,}|~{3,})([^\r\n]*)', line)
        if fence:
            if marker and marker[1][0] == fence[0] and len(marker[1]) >= fence[1] and not marker[2].strip():
                if fence[2] in ('text', 'bnt', 'benitoite', ''):
                    yield start, ''.join(body)
                fence = None
            else:
                body.append(line)
        elif marker:
            fence = (marker[1][0], len(marker[1]), marker[2].strip())
            body = []
            start = offset + len(line)
        else:
            for inline in re.finditer(r'(?<!`)`([^`\n]+)`(?!`)', line):
                yield offset + inline.start(1), inline[1]
        offset += len(line)


def candidates(code):
    for match in re.finditer(r'(?<![\w.])([A-Za-z_]\w*(?:\.\w+)*)\(', code):
        name = match[1]
        if name in ('lambda', 'function') or name.rsplit('.', 1)[-1][0].isupper():
            continue
        if re.search(r'\bfunction\s+$', code[:match.start()]):
            continue
        cursor = start = match.end()
        stack, args = [], []
        quote = None
        while cursor < len(code):
            char = code[cursor]
            if quote:
                if char == '\\':
                    cursor += 2
                    continue
                if char == quote:
                    quote = None
            elif char == '"' or (char == "'" and re.match(r"'(?:\\.|[^'\n])'", code[cursor:])):
                quote = char
            elif code[cursor:cursor+2] == '//':
                newline = code.find('\n', cursor)
                cursor = len(code) if newline < 0 else newline
                continue
            elif char in '([{':
                stack.append(char)
            elif char in ')]}':
                if not stack:
                    args.append(code[start:cursor].strip())
                    if char == ')' and len(args) > 1 and any(not re.match(r'^\w+\s*:', arg) for arg in args):
                        yield match.start(), code[match.start():cursor+1]
                    break
                stack.pop()
            elif char == ',' and not stack:
                args.append(code[start:cursor].strip())
                start = cursor + 1
            cursor += 1


def scan(head):
    files = sorted((ROOT / 'docs/design').rglob('*.md'))
    files += [ROOT / 'docs/reference/benitoite.md']
    files += [ROOT / 'crates/benitoite/skill' / name for name in HANDWRITTEN]
    found = []
    for path in files:
        relative = str(path.relative_to(ROOT))
        source = (subprocess.check_output(['git', 'show', f'HEAD:{relative}'], cwd=ROOT).decode()
                  if head else path.read_text())
        for offset, code in fragments(source):
            for pos, call in candidates(code):
                found.append({'path': relative, 'line': source.count('\n', 0, offset + pos) + 1,
                              'call': call})
    return {'files': len(files), 'candidates': found}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', action='store_true', help='Z9 の編集前の HEAD を走査する')
    print(json.dumps(scan(parser.parse_args().head), ensure_ascii=False, indent=2))
