"""全既定環境の公理監査から、今回の全宣言と実署名を一回だけ保存する。"""
import argparse
from collections import Counter
import json
import re
from pathlib import Path
from inventory import HERE, digest, write
from ledger import pages

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--tmp',type=Path,required=True)
ap.add_argument('--label',default='audit-final')
ap.add_argument('--summary',default='audit-summary.json')
args=ap.parse_args()
raw=args.tmp/(args.label+'.log')
execution=json.loads((HERE/(args.label+'.json')).read_text())
assert execution['exit']==0 and execution['raw']==digest(raw)
text=raw.read_text()
assert not re.search(r'error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)',text)
targets=re.findall(r'^AUDIT_TARGET (.+)$',text,re.M)
assert len(targets)==len(set(targets))==int(re.search(r'^AUDIT_COUNT (\d+)$',text,re.M)[1])
axioms=re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])",text,re.M|re.S)
assert Counter(n for n,_ in axioms)==Counter(targets)
sets=Counter(tuple(sorted(n.strip() for n in deps.split(',') if n.strip())) for _,deps in axioms)
assert all(set(s)<={'propext','Quot.sound','Classical.choice'} for s in sets)
modules={m:int(n) for m,n in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$',text,re.M)}
assert sum(modules.values())==len(targets)
changed=json.loads((HERE/'changed-modules.json').read_text())
decls=[{'module':m,'kind':k,'line':int(line),'name':n}
    for m,k,line,n in re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$',text,re.M)]
assert len(decls)==sum(modules[m] for m in changed)
assert {r['module'] for r in decls}==set(changed)
declpages=pages('declarations',decls)
signatures=re.findall(r'^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$',text,re.M|re.S)
printed={n for _,n,_,_ in signatures}
assert set(json.loads((HERE/'required-names.json').read_text()))<=printed
records=[{'module':m,'name':n,'line':int(line),'type':typ.strip()} for m,n,line,typ in signatures]
assert all('⋯' not in r['type'] and '...' not in r['type'] for r in records)
# 大きい生成署名も省略しない。一つの型をUTF-8として安全な文字の境界で分割する。
import hashlib
fragments=[]
for record in records:
    typ=record['type']
    if len(json.dumps([record],ensure_ascii=False,indent=2).encode())<=70000:
        fragments.append(record)
        continue
    pieces=[typ[start:start+12000] for start in range(0,len(typ),12000)]
    for i,piece in enumerate(pieces):
        fragments.append({k:record[k] for k in ['module','name','line']} |
            {'type_fragment':i,'type_fragments':len(pieces),'type_piece':piece,
             'type_bytes':len(typ.encode()),'type_sha256':hashlib.sha256(typ.encode()).hexdigest()})
signaturepages=pages('signatures',fragments)
definitiontext=''.join('```lean\n'+s.strip()+'\n```\n\n'
    for s in re.findall(r'^DEFINITION_BEGIN \S+\n(.*?)^DEFINITION_END \S+$',text,re.M|re.S))
(HERE/'definitions.md').write_text('# 追加した定義の実体\n\n'+definitiontext)
summary={'targets':len(targets),'new_declarations':len(decls),
    'new_modules':{m:modules[m] for m in changed},
    'private_declarations':sum(r['name'].startswith('_private.') for r in decls),
    'axiom_sets':[{'axioms':list(k),'count':v} for k,v in sorted(sets.items())],
    'new_axioms':0,'sorryAx':0,'declaration_pages':declpages,'signature_pages':signaturepages,
    'signature_declarations':len(records),'signature_records':len(fragments),
    'definitions':digest(HERE/'definitions.md'),'input':digest(HERE/'axioms.lean'),
    'execution':execution,'modules':modules}
write(HERE/args.summary,summary)
print(json.dumps({k:summary[k] for k in ['targets','new_declarations','private_declarations','new_modules','axiom_sets','new_axioms','sorryAx']},ensure_ascii=False))
