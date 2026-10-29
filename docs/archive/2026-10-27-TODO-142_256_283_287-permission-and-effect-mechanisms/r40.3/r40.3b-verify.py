#!/usr/bin/env python3
"""R40.3b の固定値・保護対象・引用と作業状態を照合する。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess

out = Path(__file__).resolve().parent
root = Path.cwd()
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
start = json.loads((out / 'r40.3b-start-state.json').read_text())
frozen = json.loads((out / 'r40.3b-frozen-expectations.json').read_text())
manifest = json.loads((out / 'handoff.json').read_text())
before = json.loads((out / 'r40.3b-before-handoff.json').read_text())
assert manifest['cases'][:-1] == before['cases']
assert manifest['cases'][-1] == frozen['addedCase']
assert sha(out / 'handoff.json') == frozen['manifestSha256'] == (out / 'handoff.sha256').read_text().split()[0]
assert all(sha(out / c['file']) == c['sha256'] for c in manifest['cases'])
assert all(sha(Path(p)) == h for p, h in start['protected'].items())
for args, expected in [(['rev-parse', 'HEAD'], start['head']), (['branch', '--show-current'], start['branch'])]:
    assert subprocess.check_output(['git', *args], text=True).strip() == expected
assert hashlib.sha256(subprocess.check_output(['git', 'diff', '--cached', '--binary'])).hexdigest() == start['indexSha256']
subprocess.run(['git', 'diff', '--check'], check=True)
for name in ['results.md', 'handoff.md', '../r40/results.md']:
    p = out / name
    for link in re.findall(r'\[[^\]]+\]\(([^)]+)\)', p.read_text()):
        target = link.split('#', 1)[0]
        if target and not target.startswith(('http:', 'https:')):
            assert (p.parent / target).exists(), (name, link)
for p in out.glob('r40.3b-*'):
    if p.is_file():
        text = p.read_text()
        assert str(root) not in text and str(Path.home()) not in text, p.name
work = json.loads((out / 'r40.3b-work.json').read_text())
assert work['checkExitCode'] == work['exitCode'] == 0
report = json.loads((out / 'r40.3b-handoff-after-work-check.json').read_text())
assert report['successes'] == report['commands'] == 54 and not report['failures']
assert report['manifestSha256'] == frozen['manifestSha256']
record = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'protectedFilesMatched': True,
          'headBranchIndexMatched': True, 'existing25CasesUnchanged': True, 'all26SourceHashesMatched': True,
          'expectationsUnchangedAfterExecution': True, 'relativeLinksExist': True, 'pathsRedacted': True,
          'gitDiffCheckExit': 0, 'workCheckExit': work['checkExitCode'], 'finalCliCommandsMatched': report['commands']}
(out / 'r40.3b-verification.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
