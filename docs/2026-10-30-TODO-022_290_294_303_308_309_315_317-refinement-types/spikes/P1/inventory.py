#!/usr/bin/env python3
"""Leanのコメントを除き、直接参照を宣言ごとに集計する。gitを呼ばない。"""
import collections, hashlib, json, pathlib, re
base=pathlib.Path(__file__).resolve().parent
repo=base.parents[3]
def uncomment(src):
    out=[];i=0;nest=0;quoted=False
    while i<len(src):
        if nest:
            if src.startswith('/-',i):nest+=1;out.extend('  ');i+=2
            elif src.startswith('-/',i):nest-=1;out.extend('  ');i+=2
            else:out.append('\n' if src[i]=='\n' else ' ');i+=1
        elif quoted:
            if src[i]=='\\' and i+1<len(src):out.extend(src[i:i+2]);i+=2
            else:
                c=src[i];out.append(c);i+=1
                if c=='"':quoted=False
        elif src.startswith('/-',i):nest=1;out.extend('  ');i+=2
        elif src.startswith('--',i):
            j=src.find('\n',i);j=len(src) if j<0 else j;out.extend(' '*(j-i));i=j
        else:
            c=src[i];out.append(c);i+=1
            if c=='"':quoted=True
    return ''.join(out)
decl=re.compile(r'(?m)^[ \t]*(?:(?:private|protected|noncomputable|partial|unsafe)[ \t]+)*(theorem|lemma|def|abbrev|inductive|structure|instance)\s+([^\s({:]+)')
p1=re.compile(r'Ty\.Le([^A-Za-z0-9_]|$)')
p2=re.compile(r'eq_of_not_fn|\.fn_left|\.fn_right|\.fn_fn|Ty\.fn\.injEq')
# 全場合分けの見直しが要る候補。これは修正必須数でも推移的な依存の数でもない。
p3=re.compile(r'Ty\.(?:rawShift|shift|rawBind|bind|rawInstR|instR|norm|WF|VarsIn|RowsIn|RangesIn|compare)|Eff\.(?:rawShift|rawBind|rawInstR|WF|norm)|\|\s*\.(?:refined|reference|opaque|fn|list)\b')
entries=[];hashes={};counts={}
for area in ['Release','Surface']:
    for file in sorted((repo/'formal'/'Benitoite'/area).rglob('*.lean')):
        data=file.read_bytes();hashes[str(file.relative_to(repo))]=hashlib.sha256(data).hexdigest()
        src=uncomment(data.decode());ds=list(decl.finditer(src))
        for i,d in enumerate(ds):
            body=src[d.start():ds[i+1].start() if i+1<len(ds) else len(src)]
            boundary=re.search(r'(?m)^[ \t]*(?:namespace|end|section|mutual|variable)\b',body)
            if boundary:body=body[:boundary.start()]
            hits=[name for name,p in [('Ty.Le',p1),('inversion',p2),('structure-candidate',p3)] if p.search(body)]
            if hits:entries.append(dict(area=area,file=str(file.relative_to(repo)),line=src.count('\n',0,d.start())+1,kind=d[1],name=d[2],hits=hits))
    es=[x for x in entries if x['area']==area and x['kind'] in ['theorem','lemma']]
    union=[x for x in es if 'Ty.Le'in x['hits'] or 'inversion'in x['hits']]
    extra=[x for x in es if x not in union]
    counts[area]=dict(TyLe=sum('Ty.Le'in x['hits'] for x in es),inversion=sum('inversion'in x['hits'] for x in es),direct_union=len(union),additional_structure_candidates=len(extra),additional_definitions=sum(x['area']==area and x['kind']not in ['theorem','lemma'] and x not in union for x in entries))
(base/'inventory.json').write_text(json.dumps(dict(method='comments stripped; declaration blocks; direct textual references, no transitive analysis',counts=counts,entries=entries),ensure_ascii=False,indent=2)+'\n')
(base/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
md=['# 現行の宣言の棚卸し','','直接参照の再集計であり、修正必須数や推移的な依存の数ではない。追加候補は型・効果の構造を読む宣言の文字列検索である。','','| 範囲 | Ty.Le | 逆転等 | 直接の和集合 | 追加の構造の候補（定理） | 追加候補の定義等 |','|---|---:|---:|---:|---:|---:|']
for a,c in counts.items():md.append(f'| {a} | {c["TyLe"]} | {c["inversion"]} | {c["direct_union"]} | {c["additional_structure_candidates"]} | {c["additional_definitions"]} |')
for area in ['Release','Surface']:
    md+=['',f'## {area} の直接参照','','| ファイル | 行 | 宣言 | 参照 |','|---|---:|---|---|']
    for x in entries:
        if x['area']==area and x['kind']in ['theorem','lemma'] and ('Ty.Le'in x['hits']or'inversion'in x['hits']):
            md.append(f'| {x["file"]} | {x["line"]} | `{x["name"]}` | {", ".join(h for h in x["hits"] if h!="structure-candidate")} |')
(base/'inventory.md').write_text('\n'.join(md)+'\n')
print(json.dumps(counts,ensure_ascii=False))
