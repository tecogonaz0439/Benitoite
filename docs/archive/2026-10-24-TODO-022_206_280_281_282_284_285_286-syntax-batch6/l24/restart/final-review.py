"""保存する記録のパス・構文・リンクと許可範囲を最終点検する。"""
import ast,json,re,subprocess,zipfile
from pathlib import Path
import run

root = run.OUT.parent
forbidden=['/'+'Users/', '/'+'private/var/', '/'+'Library/Developer/']
counts={}
for path in root.rglob('*'):
    if not path.is_file() or '__pycache__' in path.parts:continue
    if path.suffix in ['.py','.md','.log','.json','.lean']:
        text=path.read_text()
        assert not any(prefix in text for prefix in forbidden),path.name
        counts[path.suffix]=counts.get(path.suffix,0)+1
        if path.suffix=='.py':ast.parse(text)
        if path.suffix=='.json':json.loads(text)
with zipfile.ZipFile(run.OUT/'development-logs.zip') as archive:
    assert archive.testzip() is None
    for name in archive.namelist():
        text=archive.read(name).decode()
        assert not any(prefix in text for prefix in forbidden),name
links=0
report=(root/'results.md').read_text()
for raw in re.findall(r'\]\(([^)]+)\)',report):
    path=raw.split('#')[0]
    if not path or '://' in path:continue
    assert (root/path).exists(),path
    links+=1
assert 'END_TIME' not in report and 'DURATION' not in report
record=json.loads((run.OUT/'audit.json').read_text())
explicit=[entry['name'] for entry in record['header_changes'] if not entry['moved']]
assert sorted(explicit)==['concreteRule_known','expr_located','within_call']
assert record['base']==run.BASE and record['head']==run.BASE and record['branch']=='mod012/L24'
git=lambda *args:subprocess.check_output(['git',*args],cwd=run.ROOT,text=True)
assert git('diff','--name-only',run.BASE,'--','crates','scripts','formal/lakefile.toml')==''
outside=[p for p in git('diff','--name-only',run.BASE,'--','formal').splitlines()
         if p!='formal/Benitoite.lean' and not p.startswith('formal/Benitoite/Interval/')]
assert not outside,outside
git('diff','--check')
work=json.loads((run.OUT/'work-check.json').read_text())
assert work['check_exit']==0
assert 'selected checks passed' in (run.OUT/'work.log').read_text()
result=dict(status='passed',base=run.BASE,record_files=counts,checked_local_links=links,
            explicit_helper_header_changes=explicit,work_exit=work['check_exit'],
            outside_interval_changed=outside,table_files=len(record['fixed_files']),
            new_guard_examples=(run.ROOT/'formal/Benitoite/Interval/HttpUpdateExamples.lean').read_text().count('#guard'))
(run.OUT/'final-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
