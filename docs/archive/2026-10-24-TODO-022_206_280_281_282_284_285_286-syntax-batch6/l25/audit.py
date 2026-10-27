"""中心二命題・共有の対応・公開言明・固定入力を開始版と照合する。"""
from pathlib import Path
import hashlib,json,re,subprocess
import run
ROOT,OUT,BASE=run.ROOT,run.OUT,run.BASE

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True)
def old(path):return git('show',BASE+':'+path)
def declaration(source,name):
    match=re.search(r'(?m)^(?:private )?(?:def|inductive|structure|theorem) '+re.escape(name)+r'(?=\s|\{|\()',source)
    assert match,name
    end=re.search(r'(?m)^(?:/--|/\*!|-- |end\b|(?:private )?(?:def|inductive|structure|theorem|example|instance)\b)',source[match.end():])
    return source[match.start():match.end()+end.start() if end else len(source)].strip()

protected={}
for path,names in {
 'formal/Benitoite/Interval/Eval.lean':['NormalSoundness','WarningSoundness','ConcreteValue','ConcreteValue.type','EvalInput','Reached'],
 'formal/Benitoite/Interval/Sound.lean':['targetOperationAt','arithmeticOperationAt','WarningLocated'],
 'formal/Benitoite/Interval/Environment.lean':['Models','SlotModels','AbstractSlot','AbstractEnv']}.items():
    current=(ROOT/path).read_text();previous=old(path)
    for name in names:
        left,right=declaration(previous,name),declaration(current,name)
        assert left==right,(path,name)
        protected[name]=hashlib.sha256(right.encode()).hexdigest()

# 言明の変更と移動をすべて列挙する。名前衝突のため、ファイル内の宣言名でも記録する。
tracked=set(git('ls-files','formal').splitlines())
paths=sorted(tracked | {str(p.relative_to(ROOT)) for p in (ROOT/'formal').rglob('*.lean') if '.lake' not in p.parts})
headers={}
for version in ['old','new']:
    table={}
    for path in paths:
        if not path.endswith('.lean'):continue
        if version=='old' and path not in tracked:continue
        source=old(path) if version=='old' else (ROOT/path).read_text()
        for m in re.finditer(r'(?m)^(theorem|lemma) ([\w.\']+)\b',source):
            tail=source[m.start():];end=-1;depth=0
            for index,char in enumerate(tail):
                if char in '({[':depth+=1
                elif char in ')}]':depth-=1
                if depth==0 and tail[index:index+2]==':=':
                    end=index;break
            if end<0:continue
            header=re.sub(r'\s+',' ',tail[:end].strip())
            table[(path,m.group(2))]=header
    headers[version]=table
changes=[]
for key,left in headers['old'].items():
    right=headers['new'].get(key)
    if right==left:continue
    moved=[list(k) for k,v in headers['new'].items() if v==left] if right is None else []
    changes.append(dict(path=key[0],name=key[1],old=left,new=right,moved=moved))

fixtures={}
for path in git('ls-files','crates/benitoite/testdata/interval-budget').splitlines():
    content=(ROOT/path).read_bytes()
    assert content==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
    fixtures[path]=hashlib.sha256(content).hexdigest()
violations=[]
for path in (ROOT/'formal').rglob('*.lean'):
    if '.lake' in path.parts:continue
    # コメント中の説明は除き、命令・証明としての使用を探す。
    text=path.read_text();text=re.sub(r'/-.*?-/','',text,flags=re.S);text=re.sub(r'--[^\n]*','',text)
    if re.search(r'\b(sorry|admit|axiom|native_decide)\b',text):
        relative=str(path.relative_to(ROOT))
        # Budget.admitは既存の予算の関数名であり、証明を省く命令ではない。
        if relative=='formal/Benitoite/Interval/Budget.lean' and path.read_text()==old(relative):continue
        violations.append(relative)
assert not violations,violations
assert git('diff','--cached','--name-only').strip()==''
git('diff','--check')
record=dict(base=BASE,head=git('rev-parse','HEAD').strip(),branch=git('branch','--show-current').strip(),
            protected=protected,header_changes=changes,fixed_files=fixtures,forbidden_proof_commands=violations)
assert not changes, changes
unchanged = {}
for path in git('ls-files', 'formal').splitlines():
    if path in ['formal/Benitoite.lean', 'formal/Benitoite/Interval/EvalClosed.lean',
                'formal/Benitoite/Interval/HttpUpdateExamples.lean']:
        continue
    content = (ROOT/path).read_bytes()
    assert content == subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT), path
    unchanged[path] = hashlib.sha256(content).hexdigest()
assert git('diff', BASE, '--', 'crates', 'scripts', 'Cargo.toml', 'Cargo.lock', 'fuzz').strip() == ''
assert git('rev-parse', 'HEAD').strip() == BASE
record['unchanged_formal_files'] = unchanged
record['existing_public_theorem_headers'] = len(headers['old'])
record['changed_files'] = git('diff', BASE, '--name-only').splitlines()
record['new_inputs'] = {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
    for path in ['formal/Benitoite/Interval/DomainExamples.lean']}
(OUT/'audit.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(protected=list(protected),header_changes=changes),ensure_ascii=False,indent=2))
