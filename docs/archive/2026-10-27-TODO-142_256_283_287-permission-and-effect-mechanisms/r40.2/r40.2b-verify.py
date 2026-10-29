# -*- coding: utf-8 -*-
"""レビュー入力・検査したファイル・git の状態の不変を照合する。"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess

out = Path(__file__).resolve().parent
root = Path.cwd()


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


start = json.loads((out / 'r40.2b-start.json').read_text())
checked = json.loads((out / 'r40.2b-checked-inputs.json').read_text())
changed_checked = [p for p, h in checked.items() if digest(p) != h]
protected = {p: h for p, h in start['files'].items()
             if '/rv-probes/' in p or p.endswith('/reviews/RV-R40.2.md')}
changed_protected = [p for p, h in protected.items() if digest(p) != h]
changed = [p for p, h in start['files'].items() if digest(p) != h]
allowed = set(checked)
unexpected = [p for p in git('diff', '--name-only').splitlines() if p not in allowed]
head = git('rev-parse', 'HEAD')
branch = git('branch', '--show-current')
index_matches = digest(git('rev-parse', '--git-path', 'index')) == start['gitIndex']
diff_check = subprocess.run(['git', 'diff', '--check'], capture_output=True, text=True)
for path in out.glob('r40.2b-*'):
    if path.suffix not in ('.log', '.json'):
        continue
    text = path.read_text()
    for value, replacement in [(str(root), '<wt>'), (str(Path.home()), '<home>'),
                               (os.environ.get('TMPDIR', '/private/tmp/'), '<tmp>/')]:
        text = text.replace(value, replacement)
    path.write_text(text)
    if path.suffix == '.json':
        json.loads(text)
lines = {}
for line in git('diff', '--numstat').splitlines():
    added, deleted, path = line.split('\t')
    lines[path] = int(added) - int(deleted)
previous = json.loads((out / 'review.json').read_text())['lines']
net = {}
for group, prefix in [('production', 'crates/benitoite/src/'),
                      ('tests', 'crates/benitoite/tests/')]:
    net[group] = sum(lines.get(p, 0) - (v['added'] - v['deleted'])
                     for p, v in previous.items() if p.startswith(prefix) and p in lines)
record = {
    'checkedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'head': head, 'branch': branch, 'indexUnchanged': index_matches,
    'protectedFiles': len(protected), 'changedProtectedFiles': changed_protected,
    'checkedFiles': len(checked), 'changedCheckedFiles': changed_checked,
    'changedFromStart': changed, 'unexpectedChangedFiles': unexpected,
    'diffCheckExitCode': diff_check.returncode, 'netLinesSinceR402': net,
    'fileHashes': checked,
}
(out / 'r40.2b-verification.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
assert head == start['head'] and branch == 'm013/r40.2' and index_matches, record
assert not changed_checked and not changed_protected and not unexpected, record
assert diff_check.returncode == 0, diff_check.stdout + diff_check.stderr
print(json.dumps({k: v for k, v in record.items() if k != 'fileHashes'}, ensure_ascii=False))
