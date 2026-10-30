#!/usr/bin/env python3
"""P3b 台本の走査部分を保存。出力部と作業固有の追加ハッシュを除き、根の相対位置だけを変更した。読み取りのみ。"""
import collections, hashlib, json, pathlib, re
base=pathlib.Path(__file__).resolve().parent
repo=base.parents[2]
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
legacy_p1=re.compile(r'Ty\.Le([^A-Za-z0-9_]|$)')
p2=re.compile(r'eq_of_not_fn|\.fn_left|\.fn_right|\.fn_fn|Ty\.fn\.injEq')
# 全場合分けの見直しが要る候補。これは修正必須数でも推移的な依存の数でもない。
p3=re.compile(r'Ty\.(?:rawShift|shift|rawBind|bind|rawInstR|instR|norm|WF|VarsIn|RowsIn|RangesIn|compare)|Eff\.(?:rawShift|rawBind|rawInstR|WF|norm)|\|\s*\.(?:refined|reference|opaque|fn|list)\b')

nat_exchange_pattern=re.compile(r'shift.*subst|subst.*shift|subst.*comp|bind.*comp|inst.*shift|shift.*inst|inst.*subst|subst.*inst|shift.*comm|shift.*comp',re.I)
nat_exchange_extra=re.compile(r'subst.*subst|instR.*instR|shift.*shift|bind.*bind',re.I)
context_pattern=re.compile(r'V_Sub|C_Sub|\bhle\b')
p1=re.compile(r'Ty\.Le([^A-Za-z0-9_]|$)|V_Sub|C_Sub|\bhle\b')

entries=[]; hashes={}; counts={}; declarations=[]
for area in ['Release','Surface']:
    for file in sorted((repo/'formal'/'Benitoite'/area).rglob('*.lean')):
        data=file.read_bytes(); hashes[str(file.relative_to(repo))]=hashlib.sha256(data).hexdigest()
        src=uncomment(data.decode()); ds=list(decl.finditer(src))
        for i,d in enumerate(ds):
            body=src[d.start():ds[i+1].start() if i+1<len(ds) else len(src)]
            boundary=re.search(r'(?m)^[ \t]*(?:namespace|end|section|mutual|variable)\b',body)
            if boundary: body=body[:boundary.start()]
            hits=[name for name,p in [('legacy-Ty.Le',legacy_p1),('inversion',p2),('structure-candidate',p3),('context-transport',context_pattern)] if p.search(body)]
            if nat_exchange_pattern.search(d[2]): hits.append('nat-exchange-requested-name')
            if nat_exchange_extra.search(d[2]): hits.append('nat-exchange-extra-name')
            if not hits: continue
            role='subtyping-or-structure'
            if context_pattern.search(body): role='value/computation-subsumption'
            if re.search(r'\bK_Sub\b',body) and context_pattern.search(body): role='continuation-subsumption'
            if area=='Surface' and d[2] in ['accept_expr','accept_block','accept_expr_eff','accept_block_eff','accept_block_effCover']:
                role='surface-checker-subsumption'
            if area=='Release' and d[2]=='progress_run': role='inversion-result-unused'
            if (area=='Release' and d[2]=='treesCompare_isLE_trans') or (area=='Surface' and d[2]=='clause_outer_instantiate'):
                role='unrelated-local-name-hle'
            changes=[]
            if legacy_p1.search(body) or p2.search(body) or context_pattern.search(body):
                changes.append('Ty.Leの文脈依存化（Γ・Φ）')
            if context_pattern.search(body):
                changes.append({'continuation-subsumption':'K_Subの部分型を同じ閉じた契約の下で保つ','surface-checker-subsumption':'checker成功からΓ・Φの下で部分型を導く','unrelated-local-name-hle':'部分型と無関係な局所名（優先集合から除外）','inversion-result-unused':'逆転の結果に部分型を含む（この証拠は未使用）'}.get(role,'V_Sub/C_Subの導出と部分型の文脈変更を点検する'))
            if role=='unrelated-local-name-hle': changes=['部分型と無関係な局所名（優先集合から除外）']
            if re.search(r'(?i)subst|bind',d[2]): changes.append('置換と値代入')
            if re.search(r'(?i)rename|shift|hide|store|mono|localRefs|strengthen|withReturn|congr',d[2]): changes.append('環境・番号・ストア・戻り先の変更')
            if p3.search(body): changes.append('型・効果の構造／変数表現の追随候補')
            if 'nat-exchange-requested-name' in hits or 'nat-exchange-extra-name' in hits: changes.append('Natの移動・置換・具体化の交換／合成の名前による候補')
            entry=dict(area=area,file=str(file.relative_to(repo)),line=src.count('\n',0,d.start())+1,kind=d[1],name=d[2],hits=hits,context_role=role,change_kinds=changes)
            entries.append(entry)
    es=[x for x in entries if x['area']==area and x['kind'] in ['theorem','lemma']]
    olddirect=[x for x in es if 'legacy-Ty.Le'in x['hits'] or 'inversion'in x['hits']]
    oldstructure=[x for x in es if 'structure-candidate'in x['hits'] and x not in olddirect]
    context=[x for x in es if 'context-transport'in x['hits']]
    added_direct=[x for x in context if x not in olddirect]
    overlap=[x for x in added_direct if x in oldstructure]
    missed=[x for x in added_direct if x not in oldstructure]
    newdirect=[x for x in es if x in olddirect or x in context]
    newstructure=[x for x in oldstructure if x not in newdirect]
    foundational=[x for x in oldstructure if any(k in x['file'] for k in ['/Type','/RangeInst','/RangeWF','/Normalize','/FiniteSupport','/Order/'])]
    priority=[x for x in es if x in newdirect or x in foundational]
    unrelated=[x for x in context if x['context_role']=='unrelated-local-name-hle']
    recommended_direct=[x for x in newdirect if x not in unrelated]
    recommended_missed=[x for x in missed if x not in unrelated]
    recommended_priority=[x for x in priority if x not in unrelated]
    nat_requested=[x for x in es if 'nat-exchange-requested-name' in x['hits']]
    nat_extra=[x for x in es if 'nat-exchange-extra-name' in x['hits']]
    nat_union=[x for x in es if x in nat_requested or x in nat_extra]
    nat_outside_previous=[x for x in nat_union if x not in olddirect and x not in oldstructure]
    review_reconstruction=[x for x in recommended_missed if x['context_role'] not in ['continuation-subsumption','surface-checker-subsumption']]
    beyond_review=[x for x in recommended_missed if x not in review_reconstruction]
    counts[area]=dict(legacy_TyLe=sum('legacy-Ty.Le'in x['hits'] for x in es),legacy_inversion=sum('inversion'in x['hits'] for x in es),legacy_direct_union=len(olddirect),legacy_additional_structure=len(oldstructure),context_hits=len(context),new_direct_union=len(newdirect),added_direct=len(added_direct),added_direct_already_structure=len(overlap),missed_by_both=len(missed),new_additional_structure=len(newstructure),legacy_all_union=len(olddirect)+len(oldstructure),new_all_union=len(newdirect)+len(newstructure),foundational_legacy_extra=len(foundational),priority_union=len(priority),outside_priority=len(es)-len(priority),additional_definitions=sum(x['area']==area and x['kind']not in ['theorem','lemma'] for x in entries))
    counts[area].update(unrelated_local_name_hits=len(unrelated),recommended_direct_union=len(recommended_direct),recommended_missed_by_both=len(recommended_missed),recommended_all_union=len(recommended_direct)+len(newstructure),recommended_priority_union=len(recommended_priority),recommended_outside_priority=len(recommended_direct)+len(newstructure)-len(recommended_priority),review_count_reconstruction=len(review_reconstruction),semantic_extra_beyond_review=len(beyond_review))
    counts[area]['outside_priority']=len(newdirect)+len(newstructure)-len(priority)
    counts[area]['all_candidate_definitions']=counts[area]['additional_definitions']
    counts[area]['additional_definitions']=sum(x['area']==area and x['kind'] not in ['theorem','lemma'] and any(k in x['hits'] for k in ['legacy-Ty.Le','inversion','structure-candidate']) for x in entries)
    counts[area].update(nat_exchange_requested=len(nat_requested),nat_exchange_extra=len(nat_extra),nat_exchange_union=len(nat_union),nat_exchange_outside_legacy_union=len(nat_outside_previous),nat_exchange_compare_name_count=sum('compare' in x['name'].lower() for x in nat_union))
    for x in entries:
        if x['area']!=area: continue
        x['sets']=[name for name,group in [('legacy-direct',olddirect),('legacy-extra-structure',oldstructure),('context-hits',context),('added-direct',added_direct),('already-structure',overlap),('missed-by-both',missed),('new-direct',newdirect),('new-extra-structure',newstructure),('legacy-foundational-extra',foundational),('priority',priority),('unrelated-local-name',unrelated),('recommended-direct',recommended_direct),('recommended-missed',recommended_missed),('recommended-priority',recommended_priority),('review-count-reconstruction',review_reconstruction),('semantic-extra-beyond-review',beyond_review)] if x in group]
        x['sets'] += [name for name,group in [('nat-exchange-requested',nat_requested),('nat-exchange-extra',nat_extra),('nat-exchange-union',nat_union),('nat-exchange-outside-legacy',nat_outside_previous)] if x in group]
