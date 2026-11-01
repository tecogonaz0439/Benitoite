from pathlib import Path
import hashlib,json,re
D=Path('docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types')
rows=json.loads((D/'l10/s2/main-contracts-reference.json').read_text())['rows'];out='import Lean\nimport Benitoite\nnamespace Benitoite.Release.Refinement\n'
for i,r in enumerate(rows):
 s=Path(r['file']).read_text();m=re.search(r'theorem '+re.escape(r['name'])+r'\b',s);depth=0;colon=None
 for at in range(m.end(),len(s)):
  c=s[at]
  if c in '({[':depth+=1
  elif c in ')}]':depth-=1
  if depth==0:
   if s.startswith(':=',at):end=at;break
   if c==':' and colon is None:colon=at
 digest=hashlib.sha256(re.sub(r'\s+','',s[m.start():end+2]).encode()).hexdigest()
 if digest!=r['full_header_sha256']:raise SystemExit('MAIN_HEADER_CHANGED '+r['name'])
 r['current_header_sha256']=digest;r['header_unchanged']=True
 binders=s[m.end():colon].strip();result=s[colon+1:end].strip()
 full='∀ '+binders+', '+result
 for group in re.findall(r'[({]([^:(){}]+)\s*:',full):
  for binder in group.split():
   if binder.isidentifier() and len(re.findall(r'(?<![\w])'+re.escape(binder)+r'(?![\w])',full))==1:
    full=re.sub(r'(?<![\w])'+re.escape(binder)+r'(?![\w])','_'+binder,full)
 out+=f'-- {r["name"]}\ntheorem mainContract{i} : {full} := @{r["name"]}\n#print axioms mainContract{i}\n\n' 
out+='end Benitoite.Release.Refinement\n'
(D/'l10/s2/main-contracts.lean').write_text(out)
(D/'l10/s2/main-contracts.json').write_text(json.dumps(dict(reference='l10/s2/main-contracts-reference.json',method='theoremから本体の:=までを含め、空白を除去してSHA-256を比較',rows=rows),ensure_ascii=False,indent=2)+'\n')
print('MAIN_HEADERS_UNCHANGED',len(rows))
