#!/usr/bin/env python3
"""L00b.15 の文書の相対リンク・範囲・大きさを確認する。git は使わない。"""
from pathlib import Path
from urllib.parse import unquote
import difflib
import hashlib
import json
import re
import tempfile
import unicodedata

root = Path(__file__).resolve().parents[3]
base = Path(__file__).resolve().parent
baseline = json.loads((base / 'baseline.json').read_text())
(base / 'document-check.json').write_text('{"all_checks_passed": false}\n')
scratch = Path(tempfile.gettempdir()) / baseline['scratch'].removeprefix('<tmp>/')
chapters = [root / 'docs/design/01-spec/01-12-core-calculus.md',
            root / 'docs/design/07-quality/07-04-formal-semantics.md',
            root / 'docs/design/00-overview/00-04-glossary.md']


def headings(text):
    return [m[1] for m in re.finditer(r'(?m)^#{1,6} (.+)$', text)]


def anchor(text):
    text = text.replace('`', '').lower()
    text = ''.join(c for c in text if c in '_-' or c.isspace() or unicodedata.category(c)[0] in 'LNM')
    return re.sub(r'\s', '-', text)


def prose(text):
    text = re.sub(r'(?ms)^```[^\n]*\n.*?^```[^\n]*$', '', text)
    return re.sub(r'`[^`\n]*`', '', text)


links = 0
changes = []
for path in chapters:
    old = (scratch / path.name).read_text()
    new = path.read_text()
    assert set(headings(old)) <= set(headings(new)), path.name
    added = [line[1:] for line in difflib.ndiff(old.splitlines(), new.splitlines()) if line.startswith('+ ')]
    for line in added:
        for target in re.findall(r'\]\(([^)]+)\)', line):
            assert 'archive/' not in target and 'todo/' not in target and '2026-10-30-TODO-' not in target, target
    changes.append({'path': path.relative_to(root).as_posix(),
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'added_headings': [h for h in headings(new) if h not in headings(old)]})
paths = [*chapters, *base.glob('*.md'), base.parent / 'reviews/RV-L00b.15-request.md']
for path in paths:
    for target in re.findall(r'\]\(([^\n)]+)\)', prose(path.read_text())):
        if re.match(r'[a-z]+://', target):
            continue
        filename, _, fragment = unquote(target).partition('#')
        dest = (path.parent / filename).resolve() if filename else path
        assert dest.is_file(), (path.name, target)
        if fragment and dest.suffix == '.md':
            assert fragment in [anchor(h) for h in headings(dest.read_text())], (path.name, target)
        links += 1
for path in [*base.iterdir(), base.parent / 'reviews/RV-L00b.15-request.md']:
    if path.is_file():
        assert path.stat().st_size <= 100_000, path.name
        if path.suffix != '.py':
            assert not re.search(r'/Users/|/private/(?:tmp|var)/|/var/folders/', path.read_text()), path.name
plan = (base.parent / 'plan.md').read_text()
review_count = sum('**設計者の見直しの対象**' in line for line in plan.splitlines())
assert review_count == 6
result = {'relative_links': links, 'designer_review_items': review_count,
          'headings_removed': 0, 'files': changes, 'all_checks_passed': True}
(base / 'document-check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'relative_links': links, 'designer_review_items': review_count, 'all_checks_passed': True}))
