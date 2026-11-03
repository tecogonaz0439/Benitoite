from pathlib import Path
import re,json,hashlib,time
import argparse
HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description='型域の署名・契約・字句の在庫を再生成する。baseline は基準版のソースの控え。')
parser.add_argument('--baseline',type=Path,required=True)
parser.add_argument('--tmp',type=Path,required=True)
args=parser.parse_args()
root=HERE.parents[3];out=HERE;tmp=args.tmp;tmp.mkdir(parents=True,exist_ok=True);base=args.baseline
def digest(b):return {'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
def decls(s):
 pat=r'(?m)^\s*(?:(?:private|noncomputable|protected)\s+)*(?:@\[[^\n]*\]\s*)?(theorem|def|abbrev|inductive|structure)\s+([\w.]+)'
 ms=list(re.finditer(pat,s));ds={}
 for j,m in enumerate(ms):
  full=s[m.start():ms[j+1].start() if j+1<len(ms) else len(s)].strip();depth=0;end=None
  for i,c in enumerate(full):
   if c in '({[':depth+=1
   if c in ')}]':depth-=1
   if depth==0 and full[i:i+2]==':=':end=i;break
   if depth==0 and full[i:i+5]=='where':end=i;break
  ds[m[2]]={'header':full[:end].rstrip() if end is not None else full,'full':full}
 return ds
changed=[];headers=[];removed=[]
for f in sorted((root/'formal').rglob('*.lean')):
 rel=f.relative_to(root);before=base/rel;b=f.read_bytes()
 if before.exists() and before.read_bytes()==b:continue
 changed.append(str(rel));old=decls(before.read_text()) if before.exists() else {};now=decls(f.read_text())
 for name,d in now.items():
  if name not in old or d['header']!=old[name]['header']:
   headers.append((str(rel),name,d['header']))
 for name in old.keys()-now.keys():removed.append({'file':str(rel),'name':name,'old_header':old[name]['header']})
text='# 群 H・I の完全署名\n\n名前空間は特記しない限り `Benitoite.Release.Refinement`。本番ソースから台本で抽出した新規・変更の署名である。型付けの構成子、Entails.bind、主要十移送は不変である。\n\n'
for f,n,h in headers:
 text+=f'## {n}\n\n配置: `{f}`。\n\n```lean\n{h}\n```\n\n'
text+='## 判断と意味の構成\n\n`Ty.assumeWithCarrier` と `Ctx.factsWithCarrier` は、本来の入口の略記である。`refinementPredicates` は明示した篩の列を保つ。ValueShapeMeaning の23構成子は変わらない。\n\n```lean\n| mk {a v} : ValueShapeMeaning P η a.norm.core v →\n    (∀ p ∈ a.norm.refinementPredicates, p.interpret (selfModel η v) = true) →\n    (∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true) → ValueMeaning P η a v\n```\n\n'
text+='## 置換した旧署名\n\n'
alias_data = json.loads((out/'resume1-aliases.json').read_text())
aliases = {**alias_data['removed_synonyms'], **alias_data['renamed_unique_lemmas']}
for x in removed:
 name=x['name']
 if name in aliases:
  reason=f"本来の入口 `{aliases[name]}` へ統合し、別名を削除した。"
 elif name=='Ty.assume_eq_predicates':
  reason='後継は `Ty.assume_eq_carrier_append`。'
 elif name=='Ty.entails_assume_iff_predicates':
  reason='後継は `Ty.entails_assume_iff`。'
 elif name in ['Const.NumericRepresented','ConstOK.represented']:
  reason='同じ完全名と内容で `NumericRepresented.lean` へ移動した。'
 else:
  reason='定義を `Context.lean` へ移した。assumeWithCarrier/factsWithCarrierは本来の入口の略記である。'
 text+=f"- `{name}`（`{x['file']}`）。{reason}\n"
assert len(text.encode())<100000;(out/'signatures.md').write_text(text)
(out/'source-changes.json').write_text(json.dumps({'changed':changed,'new_or_changed_headers':len(headers),'removed':removed},ensure_ascii=False,indent=2)+'\n')
# Full files for ten public transport statements, typing constructors and Entails.bind.
important=['SubstTyping','TypingShift','TypeShiftTyping','Narrowing','Typing','Basic']
contracts=[]
for n in important:
 f=Path('formal/Benitoite/Release/Refinement')/(n+'.lean');a=(base/f).read_bytes();b=(root/f).read_bytes();assert a==b,n
 contracts.append({'file':str(f),**digest(b),'unchanged':True})
old_files=list((base/'formal/Benitoite/Release').rglob('*.lean'))
legacy=[f for f in old_files if 'Refinement' not in f.relative_to(base).parts]
assert all(f.read_bytes()==(root/f.relative_to(base)).read_bytes() for f in legacy)
(out/'contracts.json').write_text(json.dumps({'base':'82a7f626e38b6e861f896ec5033e08e6acdfa435','files':contracts,'old_Release_files_unchanged':len(legacy)},ensure_ascii=False,indent=2)+'\n')
# Reproduce lexical inventories in temporary output; store only sizes and hashes in the change.
patterns={'assume':r'assume','capture':r'\bCaptureOk\b','expansion':r'\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)','facts-assume':r'facts|assume','value-meaning':r'ValueMeaning|valueMeaning'}
report=[]
for label,pattern in patterns.items():
 rows=[]
 for f in sorted((root/'formal/Benitoite/Release/Refinement').rglob('*.lean')):
  declaration='(先頭)'
  for number,line in enumerate(f.read_text().splitlines(),1):
   match=re.match(r'\s*(?:(?:private|noncomputable|protected)\s+)*(?:theorem|def|inductive|structure|abbrev)\s+(\S+)',line)
   if match:declaration=match[1]
   if re.search(pattern,line):rows.append((str(f.relative_to(root/'formal/Benitoite/Release/Refinement')),number,declaration))
 b=(json.dumps(rows,ensure_ascii=False,indent=2)+'\n').encode();(tmp/(label+'-inventory.json')).write_bytes(b)
 report.append({'pattern':pattern,'files':len(set(x[0] for x in rows)),'lines':len(rows),'declarations':len(set((x[0],x[2]) for x in rows)),**digest(b)})
(out/'inventory-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'changed_files':len(changed),'headers':len(headers),'legacy_unchanged':len(legacy),'inventory':report},ensure_ascii=False))
