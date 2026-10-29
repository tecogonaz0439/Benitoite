#!/usr/bin/env python3
"""Pinned git-grep inventory; this is lexical evidence, not an elaborated dependency graph."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

OUT = Path(__file__).resolve().parent
BASE = '65b165272b42c3f3621ad59bc2a2c6c9cec9c46e'


def git(*args):
    result = subprocess.run(['git', *args], text=True, capture_output=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr)
    return result.stdout


def erase_comments_strings(source):
    # Preserve newlines, including those in nested block comments.
    out = []
    i = 0
    depth = 0
    string = False
    while i < len(source):
        if depth:
            if source.startswith('/-', i):
                depth += 1; out.extend('  '); i += 2
            elif source.startswith('-/', i):
                depth -= 1; out.extend('  '); i += 2
            else:
                out.append('\n' if source[i] == '\n' else ' '); i += 1
        elif string:
            if source[i] == '\\':
                out.extend('  '); i += 2
            elif source[i] == '"':
                string = False; out.append(' '); i += 1
            else:
                out.append('\n' if source[i] == '\n' else ' '); i += 1
        elif source.startswith('/-', i):
            depth = 1; out.extend('  '); i += 2
        elif source.startswith('--', i):
            end = source.find('\n', i)
            if end == -1:
                end = len(source)
            out.extend(' ' * (end - i)); i = end
        elif source[i] == '"':
            string = True; out.append(' '); i += 1
        else:
            out.append(source[i]); i += 1
    return ''.join(out)


patterns = {
    'eq_of_sub_of_sub': r'\beq_of_sub_of_sub\b',
    'Canonical': r'\bCanonical\b',
    'norm': r'\bnorm\b',
    'norm_family': r'\b(?:\w+_)?norm(?:_\w+)?\b|\bCanonical\b',
}
raw = {}
for symbol in ('eq_of_sub_of_sub', 'Canonical', 'norm'):
    result = git('grep', '-n', '-w', symbol, BASE, '--', 'formal')
    (OUT / (symbol + '.grep.txt')).write_text(result)
    raw[symbol] = {
        'lines': len(result.splitlines()),
        'files': len({line.split(':', 2)[1] for line in result.splitlines()}),
    }

files = git('ls-tree', '-r', '--name-only', BASE, 'formal').splitlines()
entries = []
source_hashes = {}
for path in files:
    if not path.endswith('.lean'):
        continue
    source = git('show', BASE + ':' + path)
    source_hashes[path] = hashlib.sha256(source.encode()).hexdigest()
    clean = erase_comments_strings(source)
    lines = clean.splitlines(keepends=True)
    heads = []
    boundaries = []
    frames = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if re.match(r'^(?:namespace|end|section|noncomputable\s+section|mutual|example|(?:noncomputable\s+)?instance|variable|open|attribute|import)\b|^#', line):
            boundaries.append(index)
        namespace = re.match(r'^namespace\s+(\S+)', line)
        if namespace:
            frames.append(('namespace', namespace.group(1)))
        elif re.match(r'^(?:noncomputable\s+)?section\b', line):
            frames.append(('section', ''))
        elif line.startswith('mutual') and stripped == 'mutual':
            frames.append(('mutual', ''))
        elif re.match(r'^end(?:\s|$)', line):
            if frames:
                frames.pop()
        decl = re.match(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe)\s+)*(theorem|lemma|def|abbrev|inductive|structure)\s+([^\s({:]+)', line)
        if decl:
            name = decl.group(2)
            namespace = '.'.join(n for k, n in frames if k == 'namespace')
            heads.append((index, decl.group(1), namespace + '.' + name if namespace else name, decl))
    for position, (index, kind, name, decl) in enumerate(heads):
        stop = heads[position + 1][0] if position + 1 < len(heads) else len(lines)
        stop = min([stop] + [b for b in boundaries if index < b < stop])
        body = ''.join(lines[index:stop])
        # Count references, excluding the declaration's own name occurrence.
        body = body[:decl.start(2)] + ' ' * (decl.end(2)-decl.start(2)) + body[decl.end(2):]
        categories = [key for key, pattern in patterns.items() if re.search(pattern, body)]
        if categories:
            entries.append({'path': path, 'line': index + 1, 'kind': kind, 'name': name,
                            'categories': categories,
                            'statement_categories': [key for key, pattern in patterns.items()
                                if re.search(pattern, body.split(':=', 1)[0])]})

summary = {}
for category in (*patterns, 'three_symbols_union'):
    selected = [e for e in entries if (category in e['categories'] if category != 'three_symbols_union'
                else any(c in e['categories'] for c in ('eq_of_sub_of_sub', 'Canonical', 'norm')))]
    theorems = [e for e in selected if e['kind'] in ('theorem', 'lemma')]
    summary[category] = {'declarations': len(selected), 'theorems': len(theorems),
                         'files_with_theorems': len({e['path'] for e in theorems}),
                         'files': len({e['path'] for e in selected}),
                         'theorems_without_examples': len([e for e in theorems if '/Examples' not in e['path'] and '/tests/' not in e['path']]),
                         'files_without_examples': len({e['path'] for e in theorems if '/Examples' not in e['path'] and '/tests/' not in e['path']})}
by_area = {}
for area in ('Release', 'Surface', 'Exchange'):
    selected = [e for e in entries if f'/Benitoite/{area}/' in e['path']
                and e['kind'] in ('theorem', 'lemma')]
    by_area[area] = {category: len([e for e in selected if category in e['categories']])
                     for category in patterns}
result = {'base': BASE, 'method': 'git grep -n -w + comment/string-erased declaration blocks; own declaration name excluded; direct lexical references only',
          'raw_grep': raw, 'summary': summary, 'theorems_by_area': by_area,
          'entries': entries, 'source_sha256': source_hashes}
(OUT/'inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
report = ['# 基準版の字句上の依存箇所', '', f'基準: `{BASE}`。詳しい数え方と一覧は `inventory.py` と `inventory.json` にある。', '',
          'コメント・文字列・宣言自身の名前を除き、宣言の本文まで数える。Lean が解決した依存グラフでも推移的な依存件数でもない。', '',
          '| 検索 | grep の一致行 | grep のファイル | 直接参照する定理 | 定理のファイル |',
          '|---|---:|---:|---:|---:|']
for key in ('eq_of_sub_of_sub', 'Canonical', 'norm'):
    report.append(f"| `{key}` | {raw[key]['lines']} | {raw[key]['files']} | {summary[key]['theorems']} | {summary[key]['files_with_theorems']} |")
report += ['', f"三つの和集合: {summary['three_symbols_union']['theorems']}定理、{summary['three_symbols_union']['files_with_theorems']}ファイル。", '',
           f"`norm` を名前に含む補題群まで広げた検索: {summary['norm_family']['theorems']}定理、{summary['norm_family']['files_with_theorems']}ファイル。無関係な正規化名を含みうる字句上の上限寄りの数である。", '', '例示用の `Examples*.lean` と `tests/` を除く数は `inventory.json` の `theorems_without_examples` にある。', '', '## 宣言の一覧', '']
for entry in entries:
    if entry['kind'] not in ('theorem', 'lemma'):
        continue
    report.append(f"- `{entry['path']}:{entry['line']}` `{entry['name']}`: {', '.join(entry['categories'])}")
(OUT/'inventory.md').write_text('\n'.join(report)+'\n')
print(json.dumps({'base': BASE, 'raw': raw, 'summary': summary, 'by_area': by_area}, ensure_ascii=False, indent=2))
