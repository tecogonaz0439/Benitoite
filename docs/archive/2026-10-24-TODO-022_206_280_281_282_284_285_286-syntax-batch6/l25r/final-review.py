"""保存物・指定検査・参照・許可した変更範囲を最終点検する。"""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import ast
import hashlib
import json
import re
import subprocess
import zipfile
import run
ROOT, OUT = run.ROOT, run.OUT

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)

assert git('rev-parse', 'HEAD').strip() == run.BASE
assert git('branch', '--show-current').strip() == 'mod012/L25R'
assert not git('diff', '--cached', '--name-only').strip()
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
changed = git('diff', '--name-only').splitlines()
for name in changed:
    assert name.startswith('formal/Benitoite/Interval/') or name in [
        'formal/Benitoite.lean', 'docs/design/01-spec/01-12-core-calculus.md',
        'docs/design/07-quality/07-04-formal-semantics.md'], name
untracked = git('ls-files', '--others', '--exclude-standard').splitlines()
assert all(name.startswith(str(OUT.relative_to(ROOT))+'/') for name in untracked)
work = json.loads((OUT/'work-check.json').read_text())
assert work['check_exit'] == 0
assert work['command'] == ['scripts/check.sh', '--level', 'work', '--base', run.BASE,
                          '--only', 'formal_build,spec_examples,spec_tally']
assert json.loads((OUT/'formal-check.json').read_text())['check_exit'] == 0
assert json.loads((OUT/'record-input-final.json').read_text())['exit'] == 0
assert 'selected checks passed' in (OUT/'work.log').read_text()
assert '7 passed; 0 failed; 0 ignored' in (OUT/'work.log').read_text()
assert 'selected checks passed' in (OUT/'formal.log').read_text()
axioms = (OUT/'axioms.log').read_text()
assert axioms.count('depends on axioms:') == 16
assert not any(word in axioms for word in ['sorryAx', 'error(', 'Unknown constant'])
index = json.loads((OUT/'development-logs-index.json').read_text())
with zipfile.ZipFile(OUT/'development-logs.zip') as archive:
    assert archive.testzip() is None
    assert sorted(archive.namelist()) == sorted(row['name'] for row in index)
    for row in index:
        content = archive.read(row['name'])
        assert len(content) == row['bytes']
        assert hashlib.sha256(content).hexdigest() == row['sha256']
        text = content.decode()
        assert str(ROOT) not in text and str(Path.home()) not in text
        if row['name'].endswith('.json'):
            json.loads(text)
        assert '"exit": 124' not in text and '"exit": 143' not in text
for path in OUT.rglob('*'):
    if not path.is_file() or path.suffix == '.zip':
        continue
    text = path.read_text()
    assert str(ROOT) not in text and str(Path.home()) not in text, path.name
    if path.suffix == '.py':
        ast.parse(text)
    if path.suffix == '.json':
        json.loads(text)
    if path.suffix == '.md':
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if not target.startswith(('http:', 'https:', '#')):
                assert (path.parent/target.split('#')[0]).exists(), (path.name, target)
for filename in ['docs/design/01-spec/01-12-core-calculus.md',
                 'docs/design/07-quality/07-04-formal-semantics.md']:
    path = ROOT/filename
    prose = re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
    prose = re.sub(r'`[^`]*`', '', prose)
    for target in re.findall(r'\]\(([^)]+)\)', prose):
        if not target.startswith(('http:', 'https:', '#')):
            assert (path.parent/target.split('#')[0]).exists(), (filename, target)
# 閉じた評価器・解析・表の定義から HTTP の実装が除かれていることも確認する。
removed = ['HttpRecordDecl', 'fieldDomain', 'httpExpressionBinding', 'BaseApprox.http', 'reserveHttpFact']
for path in (ROOT/'formal/Benitoite/Interval').glob('*.lean'):
    source = path.read_text()
    assert not any(name in source for name in removed), path.name
assert not (ROOT/'formal/Benitoite/Interval/BudgetHttp.lean').exists()
assert json.loads((OUT/'reference-impact.json').read_text())['body']['new_rows'] == 18350
end = datetime.now(ZoneInfo('Asia/Tokyo'))
start = datetime(2026, 10, 26, 12, 41, 28, tzinfo=ZoneInfo('Asia/Tokyo'))
seconds = int((end-start).total_seconds())
hours, rest = divmod(seconds, 3600)
minutes, seconds = divmod(rest, 60)
result_path = OUT/'results.md'
result = result_path.read_text().replace('終了: 記録の最終点検中。所要時間: 最終点検後に記入する。',
    f'終了: {end:%Y-%m-%d %H:%M:%S} JST。所要時間: {hours}時間{minutes}分{seconds}秒。')
result_path.write_text(result)
state = {}
for name in changed:
    path = ROOT/name
    state[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
record = dict(base=run.BASE, head=git('rev-parse', 'HEAD').strip(), checked_at=end.isoformat(),
    changed_files=state, archive_files=len(index), work=work,
    final_formal=json.loads((OUT/'formal-check.json').read_text()),
    result_sha256=hashlib.sha256(result_path.read_bytes()).hexdigest())
(OUT/'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(dict(result='成功', end=end.isoformat(), files=len(changed), archive_files=len(index)), ensure_ascii=False))
