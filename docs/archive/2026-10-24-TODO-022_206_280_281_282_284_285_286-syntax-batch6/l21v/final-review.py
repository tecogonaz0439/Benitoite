"""依頼の範囲・開始時の入力・記録・リンクを最終確認する。"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import ast, hashlib, json, re, subprocess
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True)
assert git('branch','--show-current').strip()=='mod012/L21V'
start=json.loads((OUT/'start-state.json').read_text())
assert git('rev-parse','HEAD').strip()==start['head']==start['base']
contract=subprocess.run(['python3',str(OUT/'contract-check.py')],cwd=ROOT,capture_output=True,text=True)
assert contract.returncode==0,contract.stdout+contract.stderr
(OUT/'contract-check.log').write_text(contract.stdout)
for path,expected in start['input_sha256'].items():
    if path.endswith(('reviews/RV-L21U.md','reviews/RV-L21U-response.md')):
        assert sha((ROOT/path).read_bytes())==expected,path
for name in ('dry-run','range','axioms','up-to-date'):
    assert json.loads((OUT/(name+'.json')).read_text())['exit']==0,name
work=json.loads((OUT/'work.json').read_text())
assert work['check_exit']==0
assert work['exit']==1
assert 'sysctl kern.clockrate: Operation not permitted' in (OUT/'work.log').read_text()
assert '7 passed; 0 failed; 0 ignored' in (OUT/'work.log').read_text()
for path in OUT.glob('*.py'): ast.parse(path.read_text())
changed=git('diff','--name-only',start['base']).splitlines()
expected={
 'formal/Benitoite/Interval/Eval.lean','formal/Benitoite/Interval/Range.lean',
 'formal/Benitoite/Interval/RangeState.lean',
 'docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md',
 str((OUT.parent/'l21u/results.md').relative_to(ROOT)),
 str((OUT.parent/'reviews/RV-L21T-response.md').relative_to(ROOT)),
}
assert set(changed)==expected,changed
assert not git('diff','--check')
# 変更が許可された三ファイル以外の Lean、固定表、Rust は契約確認器も照合する。
for path in OUT.iterdir():
    if path.is_file():
        text=path.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text,path.name
for path in [OUT/'results.md',ROOT/'docs/design/01-spec/01-12-core-calculus.md',ROOT/'docs/design/07-quality/07-04-formal-semantics.md']:
    prose=re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
    prose=re.sub(r'`[^`]*`', '', prose)
    for target in re.findall(r'\]\(([^)]+)\)',prose):
        target=target.split('#',1)[0]
        if not target or '://' in target: continue
        destination=path.parent/target
        if destination.resolve()==(OUT/'final-review.json').resolve(): continue
        assert destination.exists(),(str(path.relative_to(ROOT)),target)
end=datetime.now(timezone(timedelta(hours=9)))
begin=datetime.fromisoformat('2026-10-26T06:26:56+09:00')
seconds=int((end-begin).total_seconds())
result=OUT/'results.md'
s=result.read_text().replace('終了: 後記の最終確認時に記録する。',
    '終了: '+end.strftime('%Y-%m-%d %H:%M:%S JST')+f'。所要時間は{seconds//60}分{seconds%60}秒である。')
result.write_text(s)
record={'exit':0,'base':start['base'],'head':git('rev-parse','HEAD').strip(),
 'changed_tracked_files':changed,'contract_check_exit':contract.returncode,
 'review_inputs_preserved':True,'links_exist':True,'record_paths_redacted':True,
 'git_diff_check':0,'python_syntax':True,'end':end.strftime('%Y-%m-%d %H:%M:%S JST'),
 'elapsed_seconds':seconds,'artifacts_sha256':{str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in OUT.iterdir() if p.is_file() and p.name!='final-review.json'}}
(OUT/'final-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:record[k] for k in ('exit','base','end','elapsed_seconds','review_inputs_preserved','git_diff_check')},ensure_ascii=False,indent=2))
