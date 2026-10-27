"""入力の同一性、表の追加範囲、記録のパスと保存した出力を点検する。"""
import ast
import collections
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = '121683e49e2bd94c99357db0951f7decc241b9df'

def main():
    for name, digest in json.loads((HERE / 'work-inputs-sha256.json').read_text()).items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT, text=True).splitlines()
    formal = [p for p in changed if p.startswith('formal/')]
    assert formal == ['formal/Benitoite/Interval/DomainExamples.lean',
                      'formal/Benitoite/Interval/FixedDomainExamples.lean'], formal
    differences = {}
    for table in ['body', 'whole', 'summary']:
        name = f'crates/benitoite/testdata/interval-budget/{table}.tsv'
        old = subprocess.check_output(['git', 'show', f'{BASE}:{name}'], cwd=ROOT, text=True)
        new = (ROOT / name).read_text()
        rows = lambda s: {tuple(line.split('\t')[:3]): line for line in s.splitlines() if not line.startswith('#')}
        before, after = rows(old), rows(new)
        assert before.keys() <= after.keys()
        assert all(after[k] == v for k, v in before.items())
        added = after.keys() - before.keys()
        differences[table] = dict(collections.Counter(key[0] for key in added))
        if table != 'body':
            assert new == old
    assert set(differences['body']) == {'builtinOperation', 'shiftPrimInside', 'shiftPrimOutside',
                                       'shiftPrimReverse', 'shiftFunInside', 'shiftFunOutside', 'shiftReturn'}
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    def inspect(text, name):
        assert str(ROOT) not in text and str(Path.home()) not in text, name
    for path in HERE.rglob('*'):
        if not path.is_file():
            continue
        if path.suffix == '.zip':
            with zipfile.ZipFile(path) as archive:
                index = json.loads(path.with_name('raw-logs-index.json').read_text())
                for name in archive.namelist():
                    data = archive.read(name)
                    inspect(data.decode(), str(path.relative_to(ROOT)))
                    assert hashlib.sha256(data).hexdigest() == index[name]['sha256']
        else:
            source = path.read_text()
            inspect(source, str(path.relative_to(ROOT)))
            if path.suffix == '.py':
                ast.parse(source)
    counts = json.loads((HERE / 'work-counts.json').read_text())
    assert counts['integration_targets'] == 40
    assert all(item['failed'] == 0 for item in counts['targets'])
    assert json.loads((HERE / 'work-check.json').read_text())['exit'] == 0
    report = {'input_hashes_match': True, 'formal_changes_only_examples': True,
              'existing_reference_rows_unchanged': True, 'added_rows': differences,
              'saved_paths_redacted': True, 'archive_hashes_match': True,
              'git_diff_check': True, 'python_syntax': True,
              'work_exit': 0, 'integration_targets': counts['integration_targets']}
    (HERE / 'self-review.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False))

if __name__ == '__main__':
    main()
