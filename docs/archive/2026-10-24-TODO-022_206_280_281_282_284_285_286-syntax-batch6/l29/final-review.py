"""受け渡す記録のリンク・ハッシュ・ZIP・変更範囲を最後に照合する。"""
from pathlib import Path
import ast
import datetime
import hashlib
import json
import re
import subprocess
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
files = json.loads((OUT/'work-inputs-sha256.json').read_text())
for name, wanted in files.items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == wanted, name
changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT).decode().splitlines()
assert set(changed) == {'formal/Benitoite/Interval/Exchange.lean', 'formal/tests/test_interval_exchange.py',
                       'docs/design/01-spec/01-12-core-calculus.md', 'docs/design/07-quality/07-04-formal-semantics.md'}
assert json.loads((OUT/'work-check.json').read_text())['exit'] == 0
assert json.loads((OUT/'tests-final.json').read_text())['exit'] == 0
index = json.loads((OUT/'test-records-index.json').read_text())
with zipfile.ZipFile(OUT/'test-records.zip') as archive:
    assert len(archive.namelist()) == len(index)
    for entry in index:
        assert hashlib.sha256(archive.read(entry['file'])).hexdigest() == entry['sha256']
for path in OUT.iterdir():
    if path.suffix == '.json':
        json.loads(path.read_text())
    if path.suffix == '.py':
        ast.parse(path.read_text())
    if path.is_file() and path.suffix != '.zip':
        assert str(ROOT) not in path.read_text() and str(Path.home()) not in path.read_text(), path.name
result_file = OUT/'results.md'
result = result_file.read_text()
for target in re.findall(r'\]\(([^)]+)\)', result):
    file = target.split('#', 1)[0]
    assert not file or (OUT/file).exists(), target
assert result.count('```') % 2 == 0
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
zone = datetime.timezone(datetime.timedelta(hours=9))
start = datetime.datetime(2026, 10, 26, 18, 14, 38, tzinfo=zone)
end = datetime.datetime.now(zone).replace(microsecond=0)
seconds = int((end-start).total_seconds())
result = result.replace('**記録の最終点検後に確定**', '**'+end.strftime('%Y-%m-%d %H:%M:%S JST')+'**')
result = result.replace('**同時に確定**', '**'+str(seconds//60)+'分'+str(seconds%60)+'秒**')
result_file.write_text(result)
record = dict(start=start.isoformat(), end=end.isoformat(), seconds=seconds, checkedInputFiles=len(files),
              changedFiles=changed, archivedFiles=len(index), missingLinks=[], workExit=0, localTestsExit=0,
              memoryStatistic='unavailable: sandbox denied sysctl', independentReview='pending C5',
              rustVmConnection='pending X01-X05')
(OUT/'final-review.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record))
