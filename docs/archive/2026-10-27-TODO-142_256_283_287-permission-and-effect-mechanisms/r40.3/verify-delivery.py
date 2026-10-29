#!/usr/bin/env python3
"""最終の実 CLI の文書・固定入力・リンク・変更範囲を照合する。"""
import hashlib
import datetime
import json
import os
from pathlib import Path
import re
import subprocess

root = Path.cwd()
out = Path(__file__).resolve().parent
change = out.parent
cli = root / 'target/debug/benitoite'
version = json.loads(subprocess.check_output([str(cli), '--version=json']))
(out / 'version.json').write_text(json.dumps(version, ensure_ascii=False, indent=2) + '\n')
assert version['formats']['checkReport'] == [1]
assert version['formats']['testCheckReport'] == [1, 2]
documents = []
for name in ['SKILL.md', 'references/inspection.md', 'references/idioms.md', 'references/diagnostics.md',
             'references/stdlib/Scope.md', 'references/stdlib/IO.File.md', 'references/stdlib/Network.Http.md']:
    source = (root / 'crates/benitoite/skill' / name).read_bytes()
    expected = source.replace(b'{{benitoite-version}}', version['version'].encode()) if name == 'SKILL.md' else source
    rendered = subprocess.run([str(cli), 'skill', 'show', name], capture_output=True, check=True)
    assert not rendered.stderr and rendered.stdout == expected, name
    metadata = json.loads(subprocess.check_output([str(cli), 'skill', 'show', '--format=json', name]))
    digest = hashlib.sha256(expected).hexdigest()
    assert metadata['schemaVersion'] == 1 and metadata['kind'] == 'skillDocument'
    assert metadata['text'].encode() == expected and metadata['byteLength'] == len(expected)
    assert metadata['contentHash'] == {'algorithm': 'sha256', 'value': digest}
    documents.append({'document': name, 'sourceSha256': hashlib.sha256(source).hexdigest(),
                      'renderedSha256': digest, 'bytes': len(expected), 'matchesSourceWithVersionRendering': True})
(out / 'embedded-skill.json').write_text(json.dumps({'cliSha256': hashlib.sha256(cli.read_bytes()).hexdigest(),
                                                  'documents': documents}, ensure_ascii=False, indent=2) + '\n')

manifest_data = (out / 'handoff.json').read_bytes()
assert hashlib.sha256(manifest_data).hexdigest() == (out / 'handoff.sha256').read_text().split()[0]
manifest = json.loads(manifest_data)
for case in manifest['cases']:
    assert hashlib.sha256((out / case['file']).read_bytes()).hexdigest() == case['sha256']
fixed = next(case for case in manifest['cases'] if case['file'] == 'inputs/handled-scoped-write.bnt')
assert hashlib.sha256((root / 'crates/benitoite/tests/cli_process/fixtures/handled-scoped-write.bnt').read_bytes()).hexdigest() == fixed['sha256']

paths = [root / 'docs/design/06-tooling/06-06-agent-skills.md', root / 'crates/benitoite/skill/SKILL.md',
         root / 'crates/benitoite/skill/references/idioms.md', root / 'crates/benitoite/skill/references/inspection.md',
         out / 'results.md', out / 'handoff.md', change / 'r40/results.md']
links = []
for path in paths:
    text = re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
    text = re.sub(r'`[^`\n]*`', '', text)
    for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', text):
        if re.match(r'[a-z]+://', target):
            continue
        name, _, anchor = target.partition('#')
        dest = (path.parent / name).resolve() if name else path
        if dest != out / 'verification.json':
            assert dest.exists(), (str(path.relative_to(root)), target)
        # 今回加えた節の参照を照合する。既存の全見出しの処理を別実装しない。
        if anchor in ['main-の非実行の検査報告', '検査の確定値と時間']:
            heading = 'main の非実行の検査報告' if anchor.startswith('main') else '検査の確定値と時間'
            assert re.search(r'^#+ ' + re.escape(heading) + r'$', dest.read_text(), re.M), target
        links.append({'from': str(path.relative_to(root)), 'target': target})
(out / 'documentation-links.json').write_text(json.dumps({'checked': len(links), 'links': links}, ensure_ascii=False, indent=2) + '\n')

status = subprocess.check_output(['git', 'status', '--porcelain', '-uall'], text=True)
changed = [line[3:] for line in status.splitlines()]
allowed = ['crates/benitoite/', str(change.relative_to(root) / 'r40.3') + '/']
special = ['docs/design/06-tooling/06-06-agent-skills.md', str(change.relative_to(root) / 'r40/results.md')]
assert all(any(name.startswith(prefix) for prefix in allowed) or name in special for name in changed)
assert subprocess.run(['git', 'diff', '--check'], capture_output=True).returncode == 0

leaks = []
for directory in [out, change / 'r40']:
    for path in directory.rglob('*'):
        if not path.is_file():
            continue
        data = path.read_bytes()
        for value in [str(root), str(Path.home()), os.environ.get('TMPDIR', '')]:
            if value and value.encode() in data:
                leaks.append(str(path.relative_to(root)))
assert not leaks, leaks
record = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'documents': len(documents), 'fixedInputs': len(manifest['cases']), 'relativeLinks': len(links),
          'scopeMatched': True, 'localAbsolutePathLeaks': leaks, 'diffCheckExit': 0,
          'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
          'branch': subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip(),
          'changedPaths': changed, 'cargoTargetDirWasSetByThisTask': False}
(out / 'verification.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
assert (out / 'verification.json').is_file()
print(json.dumps({key: value for key, value in record.items() if key != 'changedPaths'}, ensure_ascii=False))
