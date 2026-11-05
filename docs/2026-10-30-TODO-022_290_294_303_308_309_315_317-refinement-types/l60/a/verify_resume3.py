"""閉包・元Def・全lookup・署名・全監査・実行と変更範囲を、群Aの完了条件へ照合する。"""
from collections import Counter
import json
from pathlib import Path
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from ledger import pages, normalized
from rust_inventory import registrations
from composition_inventory import verify_tables
from body_classification import collect as classify
from closure_inventory import collect as close_references


def verify(tmp):
    protected=json.loads((tmp/'protected.json').read_text())
    allowed={'formal/Benitoite.lean','docs/design/01-spec/01-12-core-calculus.md',
             'docs/design/07-quality/07-04-formal-semantics.md'}
    changed={f for f,h in protected.items() if digest(ROOT/f)['sha256']!=h}
    assert changed==allowed,sorted(changed)
    modules=json.loads((HERE/'changed-modules.json').read_text())
    assert len(modules)==11
    inherited=set(modules[:4]);new=set(modules[4:])
    assert len(new)==7
    created={str(p.relative_to(ROOT)) for p in FORMAL.glob('*.lean') if str(p.relative_to(ROOT)) not in protected}
    assert created=={'formal/'+m.replace('.','/')+'.lean' for m in new}
    seen=set()
    def visit(module):
        if module in seen:return
        f=ROOT/'formal'/(module.replace('.','/')+'.lean')
        if not f.exists():return
        seen.add(module)
        for child in re.findall(r'^import (\S+)',f.read_text(),re.M):visit(child)
    visit('Benitoite')
    assert set(modules)<=seen
    for module in new:
        f=ROOT/'formal'/(module.replace('.','/')+'.lean');s=f.read_text()
        assert not re.search(r'\bsorry\b|^axiom |#eval|L60|L70|set_option maxRecDepth',s,re.M),module
        assert f.stat().st_size<100000
    # 必要性を確認した局所上限だけを許す。件数をLeanで評価しない。
    assert 'set_option maxHeartbeats 800000 in' in (FORMAL/'StandardModelDeclarations.lean').read_text()
    assert 'set_option maxHeartbeats 1600000 in' in (FORMAL/'StandardModelSignatures.lean').read_text()
    assert 'set_option maxHeartbeats' not in (FORMAL/'StandardModelPrimitiveLookup.lean').read_text()
    formal_inputs=[]
    for module in sorted(seen):
        f=ROOT/'formal'/(module.replace('.','/')+'.lean')
        formal_inputs.append({'module':module,'file':str(f.relative_to(ROOT)),**digest(f)})
    formal_pages=pages('formal-inputs',formal_inputs)
    closure=close_references(tmp/'resume3-closure-inventory.log')
    assert closure['renamed_count']==18 and closure['distinct_original_defs']==130
    result=verify_tables()
    classification=classify(tmp/'resume3-body-evidence.log')
    assert classification['counts']=={'任意のP/B':2,'lookupなどの副条件付き':51,'固定のP/B':77}
    summary=json.loads((HERE/'ledger-summary.json').read_text())
    def read(key):
        out=[]
        for page in summary[key]:
            assert digest(HERE/page['file'])=={k:page[k] for k in ['bytes','sha256']}
            out.extend(json.loads((HERE/page['file']).read_text()))
        return out
    ledger,evidence,rust=[read(k) for k in ['ledger_pages','evidence_pages','rust_pages']]
    byid={r['id']:r for r in ledger}
    assert [r['name'] for r in rust]==[r['name'] for r in registrations()]
    for r in rust:
        target=byid[r['ledger']]
        assert normalized(r['name'])==target['lean_name'] and r['id'] in target['rust_references']
    # 全373名の提供元の機械展開と、合成側の同じ提供元を照合する。
    providers=json.loads((HERE/'resume3-primitive-providers.json').read_text())
    prims=json.loads((HERE/'resume3-primitive-sources.json').read_text())
    probed=[]
    for line in (tmp/'resume3-primitive-inventory.log').read_text().splitlines():
        if line.startswith('PROVIDER '):
            _,name,raw=line.split(' ',2);probed.append((name,json.loads(raw)))
    assert probed==[(r['name'],r['providers']) for r in prims]
    sig_source=(FORMAL/'StandardModelSignatures.lean').read_text()
    for i in sorted({r['providers'][0] for r in prims}):
        expression=providers[i].replace('ModelTargets.builtins','signatureBase')
        if i==1:expression='precisionProvider'
        if expression=='StandardCollectionModel.builtins':expression='collectionProvider'
        assert f'private def source{i} : Builtins := {expression}' in sig_source
    for r in prims:
        assert r['selected_provider']==providers[r['providers'][0]]
        assert f'| .{r["constructor"]} => source{r["providers"][0]}' in sig_source
    f_names=(FORMAL/'FunctionNameMap.lean').read_text()
    listed=json.loads('['+f_names.split('def collisionNames : List String :=',1)[1].split(']',1)[0].split('[',1)[1]+']')
    assert listed==closure['renamed_names']
    assert (HERE/'function-name-map.lean').read_text()==f_names
    for component in ['ordinary-list-copy.lean','precise-list-copy.lean']:
        code='\n'.join(l for l in (HERE/component).read_text().splitlines() if not l.startswith('import ')).strip()
        for trial in ['map-filter-trial.lean','map-filter-composed-trial.lean']:
            assert code in (HERE/trial).read_text(),(component,trial)
    # 入力ファイルと時刻・終了・生出力のハッシュを同時に照合する。
    labels=['resume3-default-build','resume3-audit-final','resume3-work-final',
            'resume3-closure-inventory','resume3-primitive-inventory','resume3-body-evidence',
            'resume3-short-trial-final','resume3-composed-trial','resume3-f-signatures',
            'resume3-correspondence-1','resume3-correspondence-2']
    for label in labels:
        rec=json.loads((HERE/(label+'.json')).read_text())
        assert rec['exit']==0 and rec['raw']==digest(tmp/(label+'.log')),label
    local=[]
    for file,label in [('closure-inventory.lean','resume3-closure-inventory'),
       ('primitive-inventory.lean','resume3-primitive-inventory'),
       ('body-evidence-types.lean','resume3-body-evidence'),
       ('map-filter-trial.lean','resume3-short-trial-final'),
       ('map-filter-composed-trial.lean','resume3-composed-trial'),
       ('f-signatures.lean','resume3-f-signatures'),
       ('source-correspondence-01.lean','resume3-correspondence-1'),
       ('source-correspondence-02.lean','resume3-correspondence-2')]:
        text=(tmp/(label+'.log')).read_text()
        assert not re.search(r'error(?:\(|:)|warning:|sorryAx',text),label
        targets=re.findall(r'^LOCAL_AUDIT (.+)$',text,re.M)
        axioms=re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])",text,re.M|re.S)
        assert len(targets)==len(set(targets)) and Counter(targets)==Counter(n for n,_ in axioms),label
        assert all({a.strip() for a in deps.split(',') if a.strip()} <= {'propext','Classical.choice','Quot.sound'} for _,deps in axioms),label
        local.append({'input':file,'digest':digest(HERE/file),'declarations':len(targets),
            'private':sum(n.startswith('_private.') for n in targets),'names':targets,
            'raw':digest(tmp/(label+'.log')),'new_axioms':0,'sorryAx':0})
    write(HERE/'resume3-local-audit.json',local)
    assert [r['declarations'] for r in local[:3]]==[3,2,0]
    assert [r['declarations'] for r in local[-2:]]==[80,80]
    audit=json.loads((HERE/'resume3-audit-summary.json').read_text())
    assert audit['targets']==83376 and audit['new_declarations']==2704
    assert audit['new_axioms']==audit['sorryAx']==0
    assert audit['input']==digest(HERE/'axioms.lean')
    assert audit['execution']==json.loads((HERE/'resume3-audit-final.json').read_text())
    assert set(modules)<=set(audit['modules'])
    for key in ['declaration_pages','signature_pages']:
        for page in audit[key]:assert digest(HERE/page['file'])=={k:page[k] for k in ['bytes','sha256']}
    # 分割した型を全て復元し、生出力の完全な型と一致させる。
    from collections import defaultdict
    import hashlib
    stored=defaultdict(list)
    for page in audit['signature_pages']:
        for row in json.loads((HERE/page['file']).read_text()):stored[row['name']].append(row)
    raw_signatures={name:typ.strip() for _,name,_,typ in re.findall(
        r'^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$',
        (tmp/'resume3-audit-final.log').read_text(),re.M|re.S)}
    assert set(stored)==set(raw_signatures)
    for name,rows in stored.items():
        if 'type' in rows[0]:
            assert len(rows)==1 and rows[0]['type']==raw_signatures[name]
        else:
            rows.sort(key=lambda r:r['type_fragment'])
            assert [r['type_fragment'] for r in rows]==list(range(rows[0]['type_fragments']))
            restored=''.join(r['type_piece'] for r in rows)
            assert restored==raw_signatures[name]
            assert len(restored.encode())==rows[0]['type_bytes']
            assert hashlib.sha256(restored.encode()).hexdigest()==rows[0]['type_sha256']
    assert sum(audit['new_modules'][m] for m in new)==2598
    source=(HERE/'f-signatures.lean').read_text()
    assert 'definition_target_iff' in source and 'SelectedStepTarget' in source
    assert 'ProgramTarget' in source and 'VarianceValid' in source
    for file in HERE.glob('*.py'):compile(file.read_text(),file.name,'exec')
    files=[f for f in HERE.iterdir() if f.is_file()]
    for file in files:
        assert file.stat().st_size<=100000,(file.name,file.stat().st_size)
        if file.suffix in ['.md','.lean','.json','.txt']:
            text=file.read_text()
            assert not re.search(r'/(?:Users|private/tmp|tmp)/|\]\([^)]*docs/todo',text),file.name
            if file.suffix=='.md':
                for link in re.findall(r'\]\(([^)]+)\)',text):
                    if not link.startswith(('https:','http:','#')):
                        assert (file.parent/link.split('#')[0]).exists(),(file.name,link)
    assert sum(f.stat().st_size for f in files)<6000000
    outcome={'status':'群Aの実装・自己照合完了。独立レビューと取り込み・受け入れは取りまとめの担当',
      'completed_units':['L60.01','L60.02','L60.03','L60.04','L60.05'],
      'b_work':'80230d96305756057a63a07dc2b0d8aa1ebf3a75',
      **result,'proof_classification':classification['counts'],'default_import_modules':len(seen),
      'protected_files':len(protected),'protected_manifest':digest(tmp/'protected.json'),
      'allowed_changed_files':sorted(changed),'new_production_modules':7,
      'new_declarations_in_resume3':2598,'group_a_declarations':2704,
      'audited_default_declarations':audit['targets'],'audited_local_declarations_by_input':sum(r['declarations'] for r in local),
      'new_axioms':0,'sorryAx':0,'default_build_executions_in_resume3':1,'work_executions_in_resume3':1,
      'formal_inputs':formal_pages,'record_files':len(files),'record_bytes':sum(f.stat().st_size for f in files),
      'maximum_record_bytes':max(f.stat().st_size for f in files),
      'independent_review':'未実施・取りまとめの担当','acceptance':'未実施・設計者の担当'}
    write(HERE/'resume3-verification.json',outcome)
    print(json.dumps(outcome,ensure_ascii=False))
