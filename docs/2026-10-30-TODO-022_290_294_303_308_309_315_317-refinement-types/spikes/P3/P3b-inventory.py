#!/usr/bin/env python3
"""P1 inventory.pyのコメント除去・宣言分割をコピーし、RV-P1 S2の文脈変更を加える。gitを呼ばない。"""
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
for extra in ['formal/Benitoite/Scope/Domain.lean','formal/Benitoite/Scope/Signature.lean','spikes/P1/Constants.lean','spikes/P1/inventory.py','docs/design/07-quality/07-04-formal-semantics.md','docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-P1.md']:
    hashes[extra]=hashlib.sha256((repo/extra).read_bytes()).hexdigest()
payload=dict(method='P1 comment stripping/declaration boundaries retained; added V_Sub|C_Sub|\\bhle\\b to direct-reference candidates; no transitive analysis; candidates are not required edits',counts=counts,entries=entries)
entry_key=lambda x:(x['file'],x['line'],x['kind'],x['name'])
s2_all={entry_key(x) for x in entries if 'recommended-direct' in x['sets'] or 'new-extra-structure' in x['sets']}
nat_all={entry_key(x) for x in entries if 'nat-exchange-union' in x['sets']}
summary=dict(s2_direct=sum(c['recommended_direct_union'] for c in counts.values()),s2_union=len(s2_all),s2_priority=sum(c['recommended_priority_union'] for c in counts.values()),nat_exchange_union=len(nat_all),nat_outside_s2=len(nat_all-s2_all),s2_nat_combined_union=len(s2_all|nat_all))
payload.update(nat_exchange_regex=nat_exchange_pattern.pattern,nat_exchange_extra_regex=nat_exchange_extra.pattern,summary=summary)
(base/'P3b-inventory.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
(base/'P3b-source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
md=['# P3b: 文脈に依存する部分型の棚卸し','','P1 inventory.pyをコピーしてRV-P1 S2の検索語を足した。コメント除去・宣言分割は同じ。字面の候補であり、修正必須数・推移的な依存数・派生定理数を保証しない。分類は既存の宣言名と本体の字面から付けた点検の入口である。','','## 集計','','| 範囲 | 旧直接D | 旧追加構造S | 文脈検索C | 新直接D∪C | 追加直接 | うちS内 | D∪S外の脱落 | 新追加構造 | 新全和集合 |','|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for a,c in counts.items(): md.append(f'| {a} | {c["legacy_direct_union"]} | {c["legacy_additional_structure"]} | {c["context_hits"]} | {c["new_direct_union"]} | {c["added_direct"]} | {c["added_direct_already_structure"]} | {c["missed_by_both"]} | {c["new_additional_structure"]} | {c["new_all_union"]} |')
md+=['','DとSは定義上重ならない。追加直接はC−D、既に構造候補の分は(C−D)∩S、脱落はC−(D∪S)。新しい追加構造はS−C。直接95はRelease75とSurface20の計であり、構造515はReleaseだけである。D全体95∪SのRelease515は610件。Surfaceの構造159も含む旧全候補は769件となる。','','## RV-P1の24/3との差と採る候補','','| 範囲 | 字面の脱落 | 無関係hle | 復元するRV件数 | RVより追加の意味ある候補 | 採る脱落 | 採る直接 | 採る全和集合 |','|---|---:|---:|---:|---:|---:|---:|---:|']
for a,c in counts.items(): md.append(f'| {a} | {c["missed_by_both"]} | {c["unrelated_local_name_hits"]} | {c["review_count_reconstruction"]} | {c["semantic_extra_beyond_review"]} | {c["recommended_missed_by_both"]} | {c["recommended_direct_union"]} | {c["recommended_all_union"]} |')
md+=['','RVの全脱落リストは提供されていないため、24/3は本書で復元した集合の件数である。RV本人の全集合と一致したとまでは主張しない。ReleaseはV_Sub/C_Subを含む23件とprogress_runの未使用のhle 1件、SurfaceはBuilderCaptureのreads 2件とReturnTry.withReturn 1件で24/3となる。これにK_Subで実際のTy.Leを運ぶRelease 6件と、E_Sub/B_SubへcheckerのTy.Leを渡すSurface 5件を追加する。単に24/3へ戻すためにこの11件を除かない。無関係なhleはRelease/Order/Tree.leanのtreesCompare_isLE_transとSurface/Lemmas/Dict.leanのclause_outer_instantiateであり、字面の一覧には残すが推す優先集合から除く。','','推す直接集合150は旧95から55増え、そのうち17は既に構造候補、38は旧直接・旧構造の双方の外である。全構造674を含む旧全候補769との和集合は807。Releaseの構造515だけと旧直接95を合わせた610を基準にするなら、追加の意味ある未重複候補45を加えて655となる（Surfaceの構造159の全体を含まないので807と混同しない）。','','## 優先集合','','P1の型基盤の集合F（Type*・RangeInst*・RangeWF*・Normalize*・FiniteSupport*・Order/の旧追加構造）と、無関係hleを除いた新直接の和集合を推す。変更種にTy.Leの文脈依存化（Γ・Φ）を明示した。','','| 範囲 | F | 採る直接 | 優先和集合 | 優先外の候補 |','|---|---:|---:|---:|---:|']
for a,c in counts.items(): md.append(f'| {a} | {c["foundational_legacy_extra"]} | {c["recommended_direct_union"]} | {c["recommended_priority_union"]} | {c["recommended_outside_priority"]} |')
md+=['','F269と採る直接150は今回重ならないので、優先集合は419件（旧364から55増）。残り388件も修正不要とはしない。変数表現を変えるM1の判断は、優先外を含む型・効果の構造の候補へ波及しうる。これは修正件数の見積りの更新そのものではなく、点検する入口の更新である。']
md+=['','## M1: Natの交換・合成の既存候補','','宣言名だけに大文字小文字を区別せず、依頼のregex `'+nat_exchange_pattern.pattern+'` を当てる。補足のregex `'+nat_exchange_extra.pattern+'` は同じ操作を重ねる名前の合成も拾う。コメント除去・宣言分割は上と同じで、theorem/lemmaだけを数える。名前の一致は意味の交換則の網羅ではない。新しい四namespaceへ必要な全数・修正必須数・証明工数とは解釈しない。二つの検索に重なる定理は和集合で一度だけ数える。','','| 範囲 | 依頼regex | 補足regex | 和集合 | 旧D∪S外 |','|---|---:|---:|---:|---:|']
for a,c in counts.items(): md.append(f'| {a} | {c["nat_exchange_requested"]} | {c["nat_exchange_extra"]} | {c["nat_exchange_union"]} | {c["nat_exchange_outside_legacy_union"]} |')
md+=['','Release47にはshift.*compが拾うshift_compare等の比較の保存7件も含む。SubstOk.instのように名前空間のSubstを拾うものもある。47を厳密な交換定理の数と呼ばない。Surfaceの0も、SurfaceがReleaseの交換補題へ依存しないことを意味しない。','','このM1集合はS2の優先419へ機械的に加算しない。P1のmap/bindの統一と、本番Natのcutoff・shift・substAt・instRの交換群とを比較するための別の軸である。値binderを型・効果へ追加した場合の新しい交換補題は、この既存の実数に含まれない。']
md+=['',f'M1を含めて全ての軸の候補を一つにする場合は、S2候補{summary["s2_union"]}とM1候補{summary["nat_exchange_union"]}の重複を除き、未重複{summary["nat_outside_s2"]}を加えた{summary["s2_nat_combined_union"]}件となる。これは優先集合{summary["s2_priority"]}の件数とは別である。']
for label,title in [('review-count-reconstruction','RVの24/3を復元する集合'),('semantic-extra-beyond-review','復元したRV件数へ追加する意味ある候補'),('unrelated-local-name','字面だけ一致した局所名'),('already-structure','追加直接だが旧構造に入っていた定理'),('nat-exchange-union','Natの交換・合成の候補一覧'),('recommended-priority','更新した優先集合')]:
    md+=['',f'## {title}','','| 範囲 | ファイル | 行 | 宣言 | 変更種 |','|---|---|---:|---|---|']
    for x in entries:
        if label in x['sets']: md.append(f'| {x["area"]} | {x["file"]} | {x["line"]} | `{x["name"]}` | {"、".join(x["change_kinds"])} |')
(base/'P3b-inventory.md').write_text('\n'.join(md)+'\n')
print(json.dumps(counts,ensure_ascii=False,indent=2))
