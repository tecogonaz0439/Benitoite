"""検査結果・保護入力・保存記録・許可された変更範囲を最後に照合する。"""
from pathlib import Path
import ast
import difflib
import hashlib
import json
import re
import subprocess
import zipfile
import run

ROOT, OUT, BASE = run.ROOT, run.OUT, run.BASE

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)

audit = json.loads((OUT/'audit.json').read_text())
assert git('rev-parse', 'HEAD').strip() == BASE == audit['base']
assert git('branch', '--show-current').strip() == 'mod012/L25'
assert not git('diff', '--cached', '--name-only').strip()
git('diff', '--check')
for path, digest in audit['unchanged_formal_files'].items():
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest, path
for path, digest in audit['fixed_files'].items():
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest, path
for path, digest in audit['new_inputs'].items():
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == digest, path
assert not audit['header_changes']

allowed = {
    'formal/Benitoite.lean', 'formal/Benitoite/Interval/EvalClosed.lean',
    'formal/Benitoite/Interval/HttpUpdateExamples.lean',
    'docs/design/01-spec/01-12-core-calculus.md',
    'docs/design/07-quality/07-04-formal-semantics.md',
}
assert set(git('diff', BASE, '--name-only').splitlines()) == allowed
new_source = 'formal/Benitoite/Interval/DomainExamples.lean'
for path in git('ls-files', '--others', '--exclude-standard').splitlines():
    assert path == new_source or path.startswith(str(OUT.relative_to(ROOT))+'/'), path

for path in OUT.glob('*.py'):
    ast.parse(path.read_text(), filename=path.name)
for path in OUT.glob('*.json'):
    json.loads(path.read_text())
archived = json.loads((OUT/'development-logs-index.json').read_text())
with zipfile.ZipFile(OUT/'development-logs.zip') as archive:
    for item in archived:
        content = archive.read(item['name'])
        assert hashlib.sha256(content).hexdigest() == item['sha256']
        if item['name'].endswith('.json'):
            json.loads(content)
        assert str(ROOT) not in content.decode()
        assert str(Path.home()) not in content.decode()

for path in OUT.iterdir():
    if not path.is_file() or path.suffix == '.zip':
        continue
    text = path.read_text()
    assert str(ROOT) not in text and str(Path.home()) not in text, path.name
    if path.suffix == '.md':
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if not re.match(r'https?://', target):
                assert (path.parent/target.split('#')[0]).exists(), target

work = json.loads((OUT/'work-check.json').read_text())
assert work['check_exit'] == 0
expected = ['scripts/check.sh', '--level', 'work', '--base', BASE, '--only',
            'formal_build,spec_examples,spec_tally']
assert work['command'] == expected
log = (OUT/'work.log').read_text()
assert '7 passed; 0 failed; 0 ignored' in log
assert 'selected checks passed' in log
assert json.loads((OUT/'dry-run.json').read_text())['exit'] == 0
assert json.loads((OUT/'default-up-to-date.json').read_text())['exit'] == 0
assert json.loads((OUT/'axioms.json').read_text())['exit'] == 0
assert 'sorryAx' not in (OUT/'axioms.log').read_text()

def count_changes(before, after):
    diff = list(difflib.ndiff(before.splitlines(), after.splitlines()))
    return dict(added=sum(line.startswith('+ ') for line in diff),
                removed=sum(line.startswith('- ') for line in diff))

path = 'formal/Benitoite/Interval/EvalClosed.lean'
before = git('show', BASE+':'+path)
after = (ROOT/path).read_text()
marker = '-- 実行可能な入口で正常な左辺'
production = count_changes(before.split(marker)[0], after.split(marker)[0])
examples = count_changes(before.split(marker)[1], after.split(marker)[1])
for path in ['formal/Benitoite/Interval/HttpUpdateExamples.lean', new_source]:
    previous = '' if path == new_source else git('show', BASE+':'+path)
    changes = count_changes(previous, (ROOT/path).read_text())
    for kind in examples:
        examples[kind] += changes[kind]

record = dict(base=BASE, head=git('rev-parse', 'HEAD').strip(),
    existing_theorem_headers=audit['existing_public_theorem_headers'],
    unchanged_formal_files=len(audit['unchanged_formal_files']),
    fixed_files=len(audit['fixed_files']), production_lines=production,
    example_lines=examples, archived_files=len(archived),
    final_input_sha256={path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
                        for path in sorted(allowed | {new_source})},
    work=work, paths_redacted=True, scripts_parsed=True, local_links_valid=True)
(OUT/'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({key: value for key, value in record.items() if key != 'final_input_sha256'},
                 ensure_ascii=False, indent=2))
