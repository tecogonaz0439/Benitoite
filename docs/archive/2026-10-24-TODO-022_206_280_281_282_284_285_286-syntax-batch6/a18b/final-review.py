#!/usr/bin/env python3
"""指定範囲・コメントだけの変更・文書の参照を点検する。"""

import ast
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote

out = Path(__file__).resolve().parent
repo = out.parents[2]
base = 'd82c182642fd7adbfa4a06c78b424a00f32d6fe8'
documents = ['docs/design/03-interop/03-06-stdlib.md',
             'docs/design/07-quality/07-04-formal-semantics.md']
source = 'crates/benitoite/src/prelude/stdlib/Range.bnt'
generated = 'crates/benitoite/skill/references/stdlib/Range.md'
expected = sorted([*documents, source, generated])


def git(*args):
    return subprocess.check_output(['git', *args], cwd=repo, text=True)


def code(text):
    return [line for line in text.splitlines() if not line.lstrip().startswith('//')]


def headings(text):
    return [line for line in text.splitlines() if line.startswith('#')]


def fences(text):
    return re.findall(r'^```[^\n]*\n.*?^```', text, re.M | re.S)


assert git('rev-parse', 'HEAD').strip() == base
assert sorted(git('diff', '--name-only', base).splitlines()) == expected
assert not git('diff', '--cached', '--name-only').strip()
subprocess.run(['git', 'diff', '--check'], cwd=repo, check=True)
assert code(git('show', f'{base}:{source}')) == code((repo / source).read_text())

links = []
for name in documents:
    before = git('show', f'{base}:{name}')
    after = (repo / name).read_text()
    assert headings(before) == headings(after)
    assert fences(before) == fences(after)
    added = '\n'.join(line[1:] for line in git('diff', base, '--', name).splitlines()
                      if line.startswith('+') and not line.startswith('+++'))
    for target in re.findall(r'\[[^\]\n]+\]\(([^)]+)\)', added):
        path, _, anchor = unquote(target).partition('#')
        resolved = (repo / name).parent / path
        assert resolved.is_file(), target
        if anchor:
            candidates = [re.sub(r'[^\w\-\s]', '', h.lstrip('#').strip()).replace(' ', '-')
                          for h in headings(resolved.read_text())]
            assert anchor in candidates, target
        links.append({'document': name, 'target': target})

for script in out.glob('*.py'):
    ast.parse(script.read_text(), filename=script.name)
for path in out.iterdir():
    if path.is_file():
        text = path.read_text()
        for forbidden in [str(repo), str(Path.home())]:
            assert forbidden not in text, path.name

result = {
    'base': base,
    'tracked_changes': expected,
    'rust_lean_fixed_tables_dependencies_and_index_unchanged': True,
    'range_non_comment_content_unchanged': True,
    'design_headings_and_code_fences_unchanged': True,
    'added_links': links,
    'diff_check': True,
    'record_paths_redacted': True,
    'sha256': {name: hashlib.sha256((repo / name).read_bytes()).hexdigest()
               for name in expected},
}
(out / 'final-review.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
