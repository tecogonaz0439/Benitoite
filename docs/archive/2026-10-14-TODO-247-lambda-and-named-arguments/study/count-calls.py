#!/usr/bin/env python3
"""TODO-247 の移行量の見積もり。Rust/Benitoite の構文解析器ではない。

git ls-files の現在の内容を読むだけで、結果は標準出力へ JSON で書く。
呼び出し候補の場所も残す。数え方と限界は migration.md を参照。
"""
import collections
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[3]
TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][A-Za-z_0-9]*|\|>|->|<-|\.\.|[^\s]', re.S)
IDENT = re.compile(r'[A-Za-z_][A-Za-z_0-9]*\Z')
RUST_STRING = re.compile(r'r(?P<hash>\#*)"(?P<raw>.*?)"(?P=hash)|"(?P<cooked>(?:\\.|[^"\\])*)"', re.S)
MARKER = re.compile(r'\b(?:function|lambda|bind|shadow|import|return|match|language)\b|\b(?:List|Map|Result|Option|String)\.')


def snippets(path, source):
    if path.endswith('.bnt'):
        yield source, 1
    elif path.endswith('.md'):
        opened, language, lines, first = False, '', [], 0
        for number, line in enumerate(source.splitlines(keepends=True), 1):
            if line.startswith('```'):
                if opened:
                    code = ''.join(lines)
                    if language in {'', 'text', 'bnt', 'benitoite'} and MARKER.search(code):
                        yield code, first
                    opened = False
                else:
                    opened, language, lines, first = True, line[3:].strip(), [], number + 1
            elif opened:
                lines.append(line)
    elif path.endswith('.rs'):
        for m in RUST_STRING.finditer(source):
            value = m['raw'] if m['raw'] is not None else re.sub(
                r'\\(n|r|t|"|\\)', lambda x: {'n': '\n', 'r': '\r', 't': '\t', '"': '"', '\\': '\\'}[x[1]], m['cooked'])
            if MARKER.search(value):
                yield value, source.count('\n', 0, m.start()) + 1


def category(path):
    if path.startswith('crates/benitoite/src/prelude/stdlib/'):
        return 'stdlib_bnt'
    if path.startswith('crates/benitoite/testdata/') and path.endswith('.bnt'):
        return 'testdata_bnt'
    if path.endswith('.bnt'):
        return 'other_bnt'
    if path.startswith('crates/benitoite/skill/'):
        return 'skill_md'
    if path.startswith('docs/reference/'):
        return 'reference_en_md'
    if path.startswith('docs/ja/'):
        return 'translation_md'
    if path.startswith('docs/design/'):
        return 'design_md'
    if path.endswith('.rs'):
        return 'rust_snippets'
    return 'other_md'


def candidates(source, base_line):
    ts = [(m[0], m.start()) for m in TOKEN.finditer(source)
          if not m[0].startswith(('//', '/*'))]
    pairs, stack = {}, []
    for i, (t, _) in enumerate(ts):
        if t in ('(', '['):
            stack.append((t, i))
        elif t in (')', ']') and stack:
            want = '(' if t == ')' else '['
            if stack[-1][0] == want:
                _, start = stack.pop()
                pairs[start] = i
                pairs[i] = start
    for i, (t, offset) in enumerate(ts):
        if t != '(' or i == 0 or i not in pairs:
            continue
        prev = ts[i - 1][0]
        ni = i - 1
        if prev == ']' and i - 1 in pairs:
            ni = pairs[i - 1] - 1
            if ni < 0:
                continue
            prev = ts[ni][0]
        if not IDENT.fullmatch(prev) and prev != ')':
            continue
        if prev in {'function', 'lambda', 'if', 'match', 'with', 'handle', 'uses', 'case', 'return', 'try', 'not', 'and', 'or'}:
            continue
        name_start = ni
        while name_start >= 2 and ts[name_start - 1][0] == '.' and IDENT.fullmatch(ts[name_start - 2][0]):
            name_start -= 2
        before = ts[name_start - 1][0] if name_start > 0 else ''
        if before in {'function', '@', 'case', 'data', 'record', 'type'}:
            continue
        end = pairs[i]
        parts, start, j, blocks = [], i + 1, i + 1, []
        while j < end:
            v = ts[j][0]
            if v in ('(', '[') and j in pairs:
                j = pairs[j] + 1
                continue
            if v == 'end' and j + 1 < end:
                word = ts[j + 1][0]
                if word in blocks:
                    blocks = blocks[:len(blocks) - 1 - blocks[::-1].index(word)]
                j += 2
                continue
            if v in {'lambda', 'match', 'lazy', 'handle'} or (v == 'if' and (j == 0 or ts[j - 1][0] != 'else')):
                blocks.append(v)
            if v == ',' and not blocks:
                parts.append(ts[start:j])
                start = j + 1
            j += 1
        if start < end:
            parts.append(ts[start:end])
        named = sum(len(p) > 1 and IDENT.fullmatch(p[0][0]) is not None and p[1][0] == ':' for p in parts)
        pipeline = before == '|>'
        if len(parts) < 2 and not (pipeline and len(parts) == 1):
            continue
        kind = 'constructor_or_pattern' if prev[:1].isupper() else 'function'
        # 大文字の名前の定義・パターンも参考候補に含む。関数の合計とは分ける。
        if named:
            kind = 'named_record_or_call'
        line = base_line + source.count('\n', 0, offset)
        yield {'line': line, 'callee': prev, 'explicit_args': len(parts), 'pipeline': pipeline,
               'kind': kind, 'sample': source[max(0, offset - 45):min(len(source), offset + 90)].replace('\n', ' ')}


def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    totals, found, scanned = {}, [], collections.Counter()
    for path in sorted(paths):
        if not path.endswith(('.bnt', '.rs', '.md')) or path.startswith(('docs/archive/', 'reference/')):
            continue
        source = (ROOT / path).read_text(encoding='utf-8', errors='replace')
        cat = category(path)
        scanned[cat] += 1
        for code, line in snippets(path, source):
            for row in candidates(code, line):
                row.update(path=path, category=cat)
                found.append(row)
    for cat in sorted(scanned):
        rows = [r for r in found if r['category'] == cat]
        fs = [r for r in rows if r['kind'] == 'function']
        totals[cat] = {'scanned_files': scanned[cat], 'affected_candidate_files': len({r['path'] for r in fs}),
                       'multi_explicit': sum(r['explicit_args'] >= 2 for r in fs),
                       'pipe_one_explicit': sum(r['explicit_args'] == 1 for r in fs),
                       'constructors_or_patterns': sum(r['kind'] == 'constructor_or_pattern' for r in rows),
                       'named_records_or_calls': sum(r['kind'] == 'named_record_or_call' for r in rows)}
    print(json.dumps({'method': 'lexical estimate, not parsed or typechecked', 'totals': totals, 'candidates': found}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
