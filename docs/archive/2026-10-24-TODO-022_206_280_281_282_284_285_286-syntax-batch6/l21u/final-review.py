"""提出前の差分・固定表・記録を読み取りで点検する。"""
from pathlib import Path
import ast, hashlib, json, re, subprocess, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '060eee90a4a43b2b88b780546ee96954291aeb56'
def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)
def run(name, command):
    started = time.monotonic()
    result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    output = result.stdout + result.stderr
    output = output.replace(str(ROOT),'<repo>').replace(str(Path.home()),'<home>')
    (OUT/(name+'.log')).write_text(output)
    assert result.returncode == 0, output
    return {'command':command,'exit':result.returncode,'seconds':time.monotonic()-started}
commands = [run('surface-types',['python3',str((OUT/'check-surface-types.py').relative_to(ROOT))]),
            run('contract-check',['python3',str((OUT/'contract-check.py').relative_to(ROOT))])]
contract=json.loads((OUT/'contract-check.json').read_text())
prefix=(OUT/'contract-check.py').read_text().split("paths = git(")[0]
context={'__file__':str(OUT/'contract-check.py')}
exec(prefix,context)
declaration=context['declaration']
# 同定の一項の内容を所有元から所有元と構成子の組へ変えた以外、計上の処理は不変。
def normalize(text):
    return (text.replace('Option (DataName × Nat)', 'Option (RangeRecord × Nat)')
            .replace('Option (OpaqueName × Nat)', 'Option (RangeRecord × Nat)')
            .replace('origin.names.owner = owner', 'origin.names.record = owner'))
path='formal/Benitoite/Interval/BudgetRange.lean'
assert normalize(git('show',BASE+':'+path).decode()) == (ROOT/path).read_text()
path='formal/Benitoite/Interval/RangeBorrowed.lean'
assert normalize(git('show',BASE+':'+path).decode()) == (ROOT/path).read_text()
# 純粋な認定も構成子の同一性の受け渡し以外は不変。
path='formal/Benitoite/Interval/Range.lean'
for name in ['rangeTables','rangeCallAt','rangeFixedInteger','rangeCallOrigin','rangeResultOrigin',
             'rangeSaveResult','rangeOkPattern','rangeBindOk','rangeCheckedOrigin','rangeMatchOk',
             'rangeValueCall','rangeValueOrigin','rangeValueInterval','rangeMatchAt','baseResultArmEnv']:
    before=declaration(git('show',BASE+':'+path).decode(),'def',name)
    after=declaration((ROOT/path).read_text(),'def',name)
    assert normalize(before) == after, name
for name in ['Analyze','BudgetDiscover','BudgetChildren','BudgetChildrenExamples','BudgetRangeBorrow',
             'BudgetAnalyze','BudgetScan','Budget','BudgetWhole','Environment','Sound']:
    path='formal/Benitoite/Interval/'+name+'.lean'
    assert path in contract['unchanged_files_sha256'],path
assert git('diff','--cached','--name-only') == b''
for path in git('diff','--name-only').decode().splitlines():
    assert path.startswith('formal/Benitoite/Interval/') or path in [
      'docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md'],path
for path in git('ls-files','--others','--exclude-standard').decode().splitlines():
    assert path.startswith(str(OUT.relative_to(ROOT))+'/'),path
for path in OUT.glob('*.py'):
    ast.parse(path.read_text())
for path in OUT.rglob('*'):
    if path.is_file() and '__pycache__' not in path.parts:
        assert str(ROOT) not in path.read_text(),path.name
        assert str(Path.home()) not in path.read_text(),path.name
work=json.loads((OUT/'work.json').read_text())
assert work['check_exit']==0
formal_final=json.loads((OUT/'formal-final.json').read_text())
assert formal_final['check_exit']==0
axioms=(OUT/'axioms.log').read_text()
assert 'sorryAx' not in axioms
for line in axioms.splitlines():
    if 'depends on axioms:' in line:
        allowed = {'propext', 'Classical.choice', 'Quot.sound'}
        found = set(re.findall(r'[A-Za-z][A-Za-z.]*', line.split('depends on axioms:')[1]))
        assert found <= allowed, found
assert json.loads((OUT/'surface-check.json').read_text())['exit'] == 0
assert json.loads((OUT/'surface-types.json').read_text())['allEqual']
assert json.loads((OUT/'default-up-to-date.json').read_text())['exit'] == 0
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
record={'commands':commands,'base':BASE,'head':git('rev-parse','HEAD').decode().strip(),
        'budgetRange_only_constructor_identity_changed':True,'range_recognizers_only_constructor_identity_changed':True,
        'fixed_tables_and_generators_byte_equal':True,'unchanged_resource_opaque_rules':True,
        'protected_contracts_passed':True,'index_unchanged':True,'git_diff_check':0,
        'recorded_paths_redacted':True,'python_syntax_passed':True,
        'axioms_queries':len(re.findall(r'^#print axioms', (OUT/'axioms.lean').read_text(),re.M)),
        'work':work,'formal_final':formal_final,
        'source_hashes':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
          for path in git('ls-files','formal','crates/benitoite/testdata/interval-budget',
            'docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md').decode().splitlines()}}
previous = OUT/'final-review.json'
if previous.exists():
    assert json.loads(previous.read_text())['source_hashes'] == record['source_hashes'], '最終検査後に関係入力の差分がある'
for document in [OUT/'results.md', ROOT/'docs/design/01-spec/01-12-core-calculus.md',
                 ROOT/'docs/design/07-quality/07-04-formal-semantics.md']:
    prose = re.sub(r'```.*?```', '', document.read_text(), flags=re.S)
    prose = re.sub(r'`[^`]*`', '', prose)
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', prose):
        if '://' in target or target.startswith('#'):
            continue
        path = target.split('#')[0]
        if path and (document.parent/path).resolve() != (OUT/'final-review.json').resolve():
            assert (document.parent/path).exists(), (document.name,target)
for name in ['run-work.sh','run-formal.sh']:
    subprocess.run(['/bin/zsh','-n',str(OUT/name)],check=True)
record['source_hashes_equal_previous_review'] = True
record['relative_links_and_shell_syntax_passed'] = True
(OUT/'final-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print('最終点検成功。公理照会',record['axioms_queries'],'件。固定表・計上・主定理・記録を確認した。')
