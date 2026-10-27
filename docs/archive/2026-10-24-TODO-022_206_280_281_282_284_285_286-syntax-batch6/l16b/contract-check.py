from pathlib import Path
import subprocess,re,hashlib,json
root=Path(__file__).resolve().parents[3];base='2ca69c26cf7397bb5da9e113d19a2f1b6905986d'
out=root/'docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l16b'
def old(path):return subprocess.check_output(['git','show',f'{base}:{path}'],cwd=root,text=True)
def heads(s):
    ans={}
    for m in re.finditer(r'(?m)^(?:@\[[^\n]*\]\s*)?(?:private\s+)?(?:theorem|lemma)\s+([\w.]+)',s):
        dep=0;i=m.end()
        while i<len(s):
            if s[i] in '([{':dep+=1
            if s[i] in ')]}':dep-=1
            if dep==0 and s[i:i+2]==':=':break
            i+=1
        ans[m[1]]=re.sub(r'\s+',' ',s[m.start():i]).strip()
    return ans
paths=subprocess.check_output(['git','diff','--name-only',base],cwd=root,text=True).splitlines()
summary={}
for path in paths:
    if path.endswith('.lean'):
        a=heads(old(path));b=heads((root/path).read_text())
        changes=[name for name,decl in a.items() if b.get(name)!=decl]
        assert not changes,(path,changes)
        summary[path]={'existing_theorems_unchanged':len(a),'new_theorems':len(b.keys()-a.keys())}
        added=subprocess.check_output(['git','diff','--unified=0',base,'--',path],cwd=root,text=True)
        assert not re.search(r'^\+(?!\+).*\b(?:axiom|sorry|admit)\b',added,re.M),path
for name in ['NormalSoundness','WarningSoundness']:
    def extract(s):
        a=s.index('def '+name);b=s.find('\n/--',a)
        return s[a:b if b>=0 else len(s)]
    assert extract(old('formal/Benitoite/Interval/Eval.lean'))==extract((root/'formal/Benitoite/Interval/Eval.lean').read_text()),name
for path in ['formal/lakefile.toml','crates/benitoite/testdata/interval-budget/body.tsv','crates/benitoite/testdata/interval-budget/whole.tsv','crates/benitoite/testdata/interval-budget/summary.tsv']:
    assert old(path)==(root/path).read_text(),path
for path in ['docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md']:
    a=old(path);b=(root/path).read_text()
    assert re.findall(r'^#+ .*$',a,re.M)==re.findall(r'^#+ .*$',b,re.M),path
    assert re.findall(r'```text\n.*?```',a,re.S)==re.findall(r'```text\n.*?```',b,re.S),path
assert not [p for p in paths if p.endswith('.lean') and not p.startswith('formal/Benitoite/Interval/')]
print('B_WORK =',base)
print('HEAD =',subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip())
print(json.dumps(summary,ensure_ascii=False,indent=2))
print('NormalSoundness/WarningSoundness: definition bodies identical')
print('Existing theorem declarations, old Lean files outside Interval, axioms: unchanged')
print('lakefile -M 12288, body/whole/summary.tsv, document headings/text fences: unchanged')
