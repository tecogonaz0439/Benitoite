#!/usr/bin/env python3
"""Repository-only migration inventory, review diff, and checked application."""
import argparse
from collections import Counter
import difflib
import hashlib
import json
import pathlib
import subprocess
from extract import snippets

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = pathlib.Path('docs/archive/2026-10-14-TODO-247-lambda-and-named-arguments')
HANDWRITTEN = {'idioms.md','common-mistakes.md','language-comparison.md','testing.md'}

def sha(data): return hashlib.sha256(data).hexdigest()
def dump(value): return json.dumps(value,ensure_ascii=False,indent=2) + '\n'
def catalog_dump(value):
    """Keep one complete record per line; the review table carries the prose."""
    compact=lambda row:json.dumps(row,ensure_ascii=False,separators=(',',':'))
    entries=[]
    for key,data in value.items():
        if isinstance(data,list):
            body=',\n'.join('    '+compact(row) for row in data)
            entries.append('  '+compact(key)+': [\n'+body+'\n  ]')
        else:
            entries.append('  '+compact(key)+': '+compact(data))
    return '{\n'+',\n'.join(entries)+'\n}\n'
def excluded(path):
    return (path.startswith(('reference/','docs/archive/','docs/todo/','tools/bench/results/','tools/skill-eval/results/','tools/syntax-measure/',str(BASE)+'/','tools/named-arguments-migrate/','crates/benitoite/examples/named_inventory/'))
            or path in ('docs/reference/benitoite-minimal.md','AGENTS.md','crates/benitoite/examples/named_arguments_inventory.rs')
            or (path.startswith('crates/benitoite/skill/references/') and pathlib.Path(path).name not in HANDWRITTEN))

def files(paths):
    if paths:
        names = set()
        for name in paths:
            p = (ROOT/name).resolve()
            if not p.is_relative_to(ROOT): raise ValueError('input must be in repository')
            if p.is_dir(): names.update(str(q.relative_to(ROOT)) for q in p.rglob('*') if q.is_file())
            else: names.add(str(p.relative_to(ROOT)))
        return sorted(n for n in names if not excluded(n))
    return sorted(n for n in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0') if n and not excluded(n))

def expected(path):
    p = ROOT/path
    if path.startswith('crates/benitoite/testdata/'):
        stem = p.with_suffix('')
        exit_path = pathlib.Path(str(stem)+'.exit')
        diag_path = pathlib.Path(str(stem)+'.diag.json')
        if exit_path.exists():
            codes = [json.loads(line)['code'] for line in diag_path.read_text().splitlines()] if diag_path.exists() else []
            status = int(exit_path.read_text())
            return {'classification':'intended_failure' if status else 'success','exit':status,'diagnostics':codes}
    return {'classification':'unclassified','exit':None,'diagnostics':[]}

def callback(c, slot, arity):
    """Q10 is an explicit proposed contract, distinct from extracted old names."""
    path = c.get('source_path','')
    name = c.get('name','').split('.')[-1]
    module = path.removeprefix('<benitoite>/').removesuffix('.bnt')
    if not path.startswith('<benitoite>/'): return None
    if name.endswith('From'): name = name[:-4]
    if module in ('List','Set','Map') and slot in ('f','p'):
        if name == 'fold': return ['acc','key','value'] if module == 'Map' else ['acc','value']
        if name in ('map','forEach','filter','any','all','find'): return ['key','value'] if module == 'Map' else ['value']
    if module in ('Option','Result') and name in ('map','andThen') and slot == 'f': return ['value']
    if module == 'Result' and name == 'mapError' and slot == 'f': return ['error']
    if module == 'Reference' and name == 'update' and slot == 'f': return ['value']
    if module == 'Regex' and name in ('replaceAllWith','replace') and slot == 'f': return ['matched']
    if module == 'Network/Http' and name in ('serve','serveLoop') and slot == 'handler': return ['request']
    if module in ('Task','TaskGroup') and slot in ('actions','action'): return []
    if module == 'Trait':
        if name in ('map','flatMap','traverse','apply'): return ['value']
        if name == 'fold': return ['acc','value']
    return None

class Components:
    def __init__(self): self.parent={}; self.sources={}; self.expect={}; self.holds={}
    def add(self, key, source):
        self.parent.setdefault(key,key); self.sources[key]={**self.sources.get(key,{}),**source,"public":source.get("public",False) or self.sources.get(key,{}).get("public",False)}
    def find(self,key):
        while self.parent[key] != key:
            self.parent[key]=self.parent[self.parent[key]]; key=self.parent[key]
        return key
    def union(self, keys):
        if keys:
            root = self.find(keys[0])
            for k in keys[1:]: self.parent[self.find(k)]=root
    def key(self,s):
        if s.get('kind') in ('lambda','annotation'):
            o = s['origin']; k = f"{o.get('file',0)}:{o['start']}:{o['end']}"
        elif s.get('kind') == 'declaration': k = 'decl:'+s.get('source_path','')+':'+s['name']
        else: return None
        self.add(k,s)
        if s.get('kind')=='annotation':
            if s.get('names') is not None: self.expect.setdefault(k,[]).append(s['names'])
            names=callback(s,s.get('slot'),s['arity'])
            if names is not None: self.expect.setdefault(k,[]).append(names)
        return k


def candidates(unit, inv):
    data = unit['source'].encode()
    host = (ROOT/unit['path']).read_bytes()
    rows = []
    graph = Components()
    annotations = {a['position']['start']:a for a in inv['annotations']}
    for l in inv['lambdas']:
        graph.key({'kind':'lambda','origin':l['position'],'names':[p['name'] for p in l['params']]})
    for d in inv['declarations']:
        for a in d['inner_function_types']:
            c={'name':d['name'],'source_path':'<benitoite>/'+unit['path'].split('/stdlib/')[-1] if '/stdlib/' in unit['path'] else unit['path']}
            names=callback(c,a['slot'].split('.')[0],a['arity'])
            k=graph.key({'kind':'annotation','origin':a['position'],'arity':a['arity'],'names':a.get('names'),'name':d['name'],'slot':a['slot']})
            if names is not None: graph.expect.setdefault(k,[]).append(names)
    returns={}
    for join in inv['joins']:
        if join['kind']=='return': returns.setdefault(join['owner'],[]).extend(join['contract_sources'])
    for d in inv['declarations']:
        values=returns.get(d['name'],[])
        for a in d['inner_function_types']:
            if a['slot']=='return': values=values+[{'kind':'annotation','origin':a['position'],'arity':a['arity'],'public':d['public']}]
        graph.union([k for s in values if (k:=graph.key(s)) is not None])
    for flow in inv.get('flows',[]):
        keys=[graph.key(s) for s in flow['sources']]
        for a in flow['types']:
            keys.append(graph.key({'kind':'annotation','origin':a['position'],'arity':a['arity'],'names':a.get('names')}))
        known=[k for k in keys if k]
        graph.union(known)
        if len(flow['types'])>1 or any(k is None for k in keys):
            for k in known: graph.holds.setdefault(k,[]).append('nested_or_unresolved_contract')
    for join in inv['joins']:
        keys=[graph.key(s) for s in join['contract_sources']]
        known=[k for k in keys if k]
        graph.union(known)
        if any(k is None for k in keys) or not known:
            for k in known: graph.holds.setdefault(k,[]).append('component_origin_unresolved')
    # A declaration's parameter annotation and the passed value belong to the same component.
    for call in inv['calls']:
        if call['pipe']: continue  # Pipe insertion needs the dedicated later migration.
        declarations=[s for s in call['contract_sources'] if s.get('kind') == 'declaration']
        if len(declarations) != 1: continue
        c=declarations[0]
        params=c.get('inner',[])
        for index,arg in enumerate(call['args']):
            param=next((p for p in params if p['name']==arg['label']),None) if arg.get('label') is not None else (params[index] if index<len(params) else None)
            if param is None: continue
            for ft in param['function_types']:
                origin=ft['position']
                annot={'kind':'annotation','origin':origin,'arity':ft['arity'],'names':ft.get('names'),'name':c['name'],'slot':param['name']}
                k=graph.key(annot)
                keys=[graph.key(s) for s in arg.get('sources',[])]
                graph.union([k]+[x for x in keys if x])
                names=callback(c,param['name'],ft['arity'])
                if names is not None: graph.expect.setdefault(k,[]).append(names)
                if len(param['function_types']) != 1 or any(x is None for x in keys): graph.holds.setdefault(k,[]).append('nested_or_unresolved_contract')
                if c.get('public') and names is None and ft.get('names') is None: graph.holds.setdefault(k,[]).append('public_contract')
    groups={}
    for k in graph.parent: groups.setdefault(graph.find(k),[]).append(k)
    chosen={}
    for root, keys in sorted(groups.items()):
        sources=[graph.sources[k] for k in keys]
        declared=[s['names'] for s in sources if s['kind']=='declaration']
        ex=declared+[n for k in keys for n in graph.expect.get(k,[])]
        ex=list({tuple(n):n for n in ex}.values())
        lambdas=sorted((s for s in sources if s['kind']=='lambda'),key=lambda s:(s['origin'].get('file',0),s['origin']['start']))
        names=ex[0] if len(ex)==1 else (lambdas[0]['names'] if not ex and lambdas else None)
        reasons=[r for k in keys for r in graph.holds.get(k,[])]
        if len(ex)>1: reasons.append('conflicting_expectations')
        if names is None: reasons.append('component_not_determined')
        if any(s.get('public') for s in sources): reasons.append('public_contract')
        edits=[]
        if names is not None:
            for s in sources:
                if s['kind']=='lambda':
                    l=next((l for l in inv['lambdas'] if l['position']==s['origin']),None)
                    if l is None: reasons.append('foreign_lambda'); continue
                    old=[p['name'] for p in l['params']]
                    if len(old)!=len(names): reasons.append('arity_mismatch'); continue
                    if len(set(names))!=len(names) or any(n in l['bound_names'] and n!=old_name for n,old_name in zip(names,old)): reasons.append('local_name_collision'); continue
                    for p,n in zip(l['params'],names):
                        if p['name']!=n:
                            for pos in [p['position']]+p['references']: edits.append((pos['start'],pos['end'],n))
                elif s['kind']=='annotation':
                    o=s['origin']
                    if o.get('file') != inv['file']: continue
                    a=annotations.get(o['start'])
                    if a and a['arity']==len(names):
                        if a.get('names') is None:
                            for p,n in zip(a.get('params',[]),names): edits.append((p['start'],p['start'],n+': '))
                        elif a['names'] != names: reasons.append('conflicting_named_annotation')
                    else: reasons.append('annotation_shape_unresolved')
        component={'kind':'component','position':next((s['origin'] for s in sources if 'origin' in s),{'start':0,'end':0}), 'contract_sources':sources,'names':names,'name_origin':'declaration_expectation' if ex else 'first_source_lambda','hold_reasons':sorted(set(reasons)),'edits':edits,'members':keys}
        for k in keys: chosen[k]=component
        rows.append(component)
    # Separate components may rename a captured parameter and its nested binder alike.
    # Compare the resolved reference ranges before approving either atomic component.
    for outer in inv['lambdas']:
        outer_component=chosen.get(graph.key({'kind':'lambda','origin':outer['position']}))
        if outer_component is None or outer_component['names'] is None: continue
        for param,name in zip(outer['params'],outer_component['names']):
            for inner in inv['lambdas']:
                if inner is outer: continue
                span=inner['position']
                if not any(span['start']<=ref['start']<span['end'] for ref in param['references']): continue
                inner_component=chosen.get(graph.key({'kind':'lambda','origin':span}))
                if inner_component is None or inner_component['names'] is None: continue
                if name in inner_component['names']:
                    for component in (outer_component,inner_component):
                        component['hold_reasons']=sorted(set(component['hold_reasons']+['simultaneous_rename_capture']))
    seen=set()
    for call in inv['calls']:
        pos=call['position']; key=(pos['start'],pos['end'])
        if key in seen: continue
        # The pipe-specific row is emitted before its ordinary child row.
        seen.add(key)
        if call['constructor']:
            if any(a['hole'] for a in call['args']):
                rows.append({'kind':'constructor_holes','position':pos,'names':['arg'+str(i+1) for i in range(len(call['args']))],'name_origin':'Q10_position','contract_sources':[],'hold_reasons':['constructor_holes_require_review'],'edits':[]})
            continue
        sources=call['contract_sources']; choices=[]; reasons=[]
        for s in sources:
            k=graph.key(s)
            comp=chosen.get(k)
            names=comp['names'] if comp else s.get('names')
            if comp: reasons.extend(comp['hold_reasons'])
            if names is not None: choices.append(names)
            else: reasons.append('callee_contract_unresolved')
        unique=list({tuple(n):n for n in choices}.values())
        names=unique[0] if len(unique)==1 else None
        if len(unique)>1: reasons.append('conflicting_expectations')
        if names is None: reasons.append('callee_contract_unresolved')
        dependencies=[]
        for s in sources+[s for a in call['args'] for s in a.get('sources',[])]:
            comp=chosen.get(graph.key(s))
            if comp and comp['edits']:
                reasons.extend(comp['hold_reasons'])
                dependencies.append(sha(json.dumps([unit['path'],unit['snippet'],'component',comp['position']],sort_keys=True).encode())[:20])
        edits=[]
        if call['pipe']: reasons.append('pipe_requires_review')
        if names is not None and len(call['args'])!=len(names): reasons.append('arity_mismatch')
        if names is not None and len(call['args'])==len(names) and len(names)>1:
            if any(a.get('label') is not None for a in call['args']):
                if {a.get('label') for a in call['args']} != set(names): reasons.append('mixed_or_invalid_named_arguments')
            else:
                edits=[(a['position']['start'],a['position']['start'],n+': ') for a,n in zip(call['args'],names)]
        if edits or reasons or call['pipe']:
            rows.append({'kind':'call','position':pos,'callee':call['callee'],'contract_sources':sources,'names':names,'name_origin':'resolved_declaration_or_component','hold_reasons':sorted(set(reasons)),'edits':edits,'depends_on':sorted(set(dependencies))})
    # Every anonymous type is visible even when no source of a candidate name is known.
    covered={s['origin']['start'] for row in rows if row['kind']=='component' for s in row['contract_sources'] if s['kind']=='annotation' and s['origin'].get('file')==inv['file']}
    for a in inv['annotations']:
        if a['position']['start'] not in covered:
            rows.append({'kind':'annotation','position':a['position'],'names':None,'name_origin':None,'contract_sources':[],'hold_reasons':['annotation_contract_unresolved'],'edits':[]})
    for row in rows:
        row['hold_reasons'].extend([unit['hold']] if unit['hold'] else [])
        if not inv['typed']: row['hold_reasons'].append('input_not_typed_successfully')
        if unit['expected']['classification']=='intended_failure': row['hold_reasons'].append('negative_input_requires_diagnostic_review')
        converted=[]
        for start,end,after in row.pop('edits'):
            bounds=unit['boundaries']
            if not (0<=start<=end<len(bounds)) or bounds[start]<0 or bounds[end]<0: row['hold_reasons'].append('host_boundary_not_editable'); continue
            converted.append({'start':bounds[start],'end':bounds[end],'before':host[bounds[start]:bounds[end]].decode(),'decoded_before':data[start:end].decode(),'after':after})
        row['edits']=converted
        pos=row['position']; start=pos['start']; end=pos['end']
        row['source_range']=[unit['boundaries'][start],unit['boundaries'][end]] if 0<=start<=end<len(unit['boundaries']) else None
        row['before']=data[start:end].decode(errors='replace')
        row['after']=row['before']
        # Keep the old/new review text local to the syntax node, including its nested edits.
        for edit in sorted(converted,key=lambda e:e['start'],reverse=True):
            # host mapping is recorded independently; snippets may contain escapes.
            local_start=unit['boundaries'].index(edit['start']) if edit['start'] in unit['boundaries'] else -1
            local_end=unit['boundaries'].index(edit['end']) if edit['end'] in unit['boundaries'] else -1
            if start<=local_start<=local_end<=end:
                buf=row['after'].encode(); row['after']=(buf[:local_start-start]+edit['after'].encode()+buf[local_end-start:]).decode()
        row.update(path=unit['path'],snippet=unit['snippet'],source_sha256=unit['source_sha256'],old_result={'typed':inv['typed'],'parse_errors':inv['parse_errors'],'diagnostics':inv['check_codes']},expected_diagnostics=unit['expected'],diagnostic_change={'classification':'separate_review_required' if unit['expected']['classification']=='intended_failure' else 'none','old':unit['expected']['diagnostics'],'new':None},review='pending')
        row['hold_reasons']=sorted(set(row['hold_reasons']))
        row['id']=sha(json.dumps([row['path'],row['snippet'],row['kind'],row['position']],sort_keys=True).encode())[:20]
    return rows


def safe_path(name):
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or excluded(str(path)): raise ValueError('excluded or unsafe path: '+name)
    p=ROOT/path
    if p.is_symlink() or not p.resolve().is_relative_to(ROOT): raise ValueError('unsafe path: '+name)
    golden_expectation=False
    if str(path).startswith('crates/benitoite/testdata/') and path.suffix in ('.formatted','.stdout'):
        stem=p.with_suffix('')
        mode=pathlib.Path(str(stem)+'.mode')
        status=pathlib.Path(str(stem)+'.exit')
        golden_expectation=(mode.is_file() and status.is_file() and status.read_text().strip()=='0'
                            and mode.read_text().strip()==('fmt' if path.suffix=='.formatted' else 'test'))
    if path.suffix not in ('.bnt','.rs','.md') and not str(path).startswith('fuzz/corpus/') and not golden_expectation: raise ValueError('not a supported source: '+name)
    return p


def proposed(manifest, approved_only=False):
    grouped={}
    for row in manifest['candidates']:
        if approved_only and row['review']!='approved': continue
        if row['hold_reasons'] or not row['edits']: continue
        grouped.setdefault(row['path'],[]).append(row)
    results={}
    for path,rows in grouped.items():
        p=safe_path(path); original=p.read_bytes()
        hashes={r['source_sha256'] for r in rows}
        if hashes!={sha(original)}: raise ValueError('source hash mismatch: '+path)
        edits={ (e['start'],e['end'],e['before'],e['after']) for row in rows for e in row['edits'] }
        ordered=sorted(edits)
        prev_end=-1; prev_start=-1
        for start,end,before,after in ordered:
            if not 0<=start<=end<=len(original): raise ValueError('invalid range: '+path)
            # A label insertion can share the start of a renamed reference.
            # Different insertions at the same boundary remain an error.
            if start<prev_end or (start==prev_start and end==start): raise ValueError('overlapping edits: '+path)
            if original[start:end]!=before.encode(): raise ValueError('range content mismatch: '+path)
            prev_end=end; prev_start=start
        updated=original
        for start,end,before,after in reversed(ordered): updated=updated[:start]+after.encode()+updated[end:]
        results[path]=(original,updated)
    return results


def write_diff(results, output):
    chunks=[]
    for path,(before,after) in sorted(results.items()):
        chunks.extend(difflib.unified_diff(before.decode().splitlines(keepends=True),after.decode().splitlines(keepends=True),fromfile='a/'+path,tofile='b/'+path))
    pathlib.Path(output).write_text(''.join(chunks))


def review_table(manifest):
    lines=['# 名前付き引数の移行確認表','','全候補は未確認である。保留のない案も、manifest の review を approved にして内容とハッシュを確認してから適用する。','','| 分類 | 件数 |','|---|---:|']
    for k,n in sorted(Counter('held' if r['hold_reasons'] else 'proposal' for r in manifest['candidates']).items()): lines.append(f'| {k} | {n} |')
    for category in ('proposal','held'):
        lines += ['',f'## {category}','','| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |','|---|---|---|---|---|']
        for r in manifest['candidates']:
            if ('held' if r['hold_reasons'] else 'proposal')!=category: continue
            def cell(x): return str(x).replace('|','\\|').replace('\n',' ')
            lines.append('| '+' | '.join(map(cell,[r['id'],r['path']+':'+str(r['source_range']),r['kind'],r['names'],', '.join(r['hold_reasons'])]))+' |')
    lines += ['','## N1 との照合','', '抽出器を変更したため、字句候補の数を AST の移行件数とは扱わない。元の全候補と合流を reconciliation.json に残し、対応する AST の候補または未一致の理由を記録する。','', '```json',dump(manifest['reconciliation_summary']).rstrip(),'```','']
    return '\n'.join(lines)


def reconcile(units, inventories, rows):
    joins=[]; calls=[]
    current_joins={}
    for u,inv in zip(units,inventories):
        for j in inv['joins']: current_joins.setdefault((u['path'],j['kind'],j['sample']),[]).append({'snippet':u['snippet'],'position':j['position']})
    baseline=json.loads((ROOT/BASE/'n1/joins.json').read_text())
    for j in baseline:
        matches=current_joins.get((j['path'],j['kind'],j['sample']),[])
        status='matched' if matches else ('held_generated_input_regenerate_from_source' if j['path'].startswith('generated/') else 'held_extraction_or_context_difference')
        joins.append({'baseline':j,'matches':matches,'status':status})
    ast_calls={}
    for u,inv in zip(units,inventories):
        host=(ROOT/u['path']).read_bytes()
        for call in inv['calls']:
            start=call['position']['start']
            if start>=len(u['boundaries']) or u['boundaries'][start]<0: continue
            line=host[:u['boundaries'][start]].count(b'\n')+1
            callee=call['callee'].split('.')[-1]
            key=(u['path'],line,callee,len(call['args']),call['pipe'])
            evidence={'snippet':u['snippet'],'position':call['position'],'constructor':call['constructor']}
            if evidence not in ast_calls.setdefault(key,[]): ast_calls[key].append(evidence)
    for c in json.loads((ROOT/BASE/'n1/call-candidates.json').read_text()):
        matches=ast_calls.get((c['path'],c.get('line'),c['callee'],c['explicit_args'],c['pipeline']),[])
        status='excluded_by_design' if excluded(c['path']) else ('matched' if len(matches)==1 else ('held_ambiguous_ast_candidates' if matches else 'held_lexical_candidate_requires_review'))
        calls.append({'baseline':c,'ast_matches':matches,'status':status})
    generated=json.loads((ROOT/BASE/'n1/generated-snapshot.json').read_text())
    return {'joins':joins,'calls':calls,'generated_snapshot':generated,'summary':{'baseline_join_kinds':dict(Counter(j['baseline']['kind'] for j in joins)),'join_status':dict(Counter(j['status'] for j in joins)),'call_status':dict(Counter(c['status'] for c in calls)),'generated_snapshot_count':len(generated)}}


def inventory(args):
    units=[]; generators=[]
    for path in files(args.paths):
        if not path.endswith(('.bnt','.rs','.md','.py')) and not path.startswith('fuzz/corpus/'): continue
        data=(ROOT/path).read_bytes()
        if path.endswith('.py') or (path.endswith('.rs') and (path.startswith(('fuzz/','tools/','crates/benitoite/tests/random_programs')) or path.endswith('/gen_skill.rs'))):
            generators.append({'path':path,'source_sha256':sha(data),'review':'pending','hold_reason':'generated_input_review_source_and_regenerate'})
        for i,s in enumerate(snippets(path,data)):
            unit={'path':path,'snippet':i,'source':s.source,'boundaries':s.boundaries,'kind':s.kind,'hold':s.hold,'direct':s.kind=='bnt','source_sha256':sha(data),'expected':expected(path)}
            units.append(unit)
    command=[str(pathlib.Path(args.helper).resolve())] if args.helper else ['cargo','run','--quiet','-p','benitoite','--example','named_arguments_inventory']
    process=subprocess.run(command,input=json.dumps(units).encode(),stdout=subprocess.PIPE,cwd=ROOT,check=True)
    inventories=[json.loads(line) for line in process.stdout.splitlines()]
    if len(inventories)!=len(units): raise ValueError('helper result count mismatch')
    rows=[r for u,inv in zip(units,inventories) for r in candidates(u,inv)]
    reconciliation=reconcile(units,inventories,rows)
    manifest={'version':1,'helper':'named_arguments_inventory','baseline':str(BASE/'n1/summary.json'),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),'inputs':[{'path':u['path'],'snippet':u['snippet'],'source_sha256':u['source_sha256'],'kind':u['kind'],'host_range':[u['boundaries'][0],u['boundaries'][-1]],'hold':u['hold'],'typed':v['typed'],'parse_errors':v['parse_errors'],'diagnostics':v['check_codes'],'expected':u['expected'],'joins':v['joins']} for u,v in zip(units,inventories)],'generators':generators,'candidates':rows,'reconciliation_summary':reconciliation['summary']}
    output=pathlib.Path(args.output); output.mkdir(parents=True,exist_ok=True)
    (output/'manifest.json').write_text(catalog_dump(manifest))
    (output/'review.md').write_text(review_table(manifest))
    (output/'reconciliation.json').write_text(catalog_dump(reconciliation))
    write_diff(proposed(manifest),output/'migration.diff')
    print(dump({'inputs':len(units),'candidates':len(rows),'held':sum(bool(r['hold_reasons']) for r in rows),'output':str(output)}).strip())


def apply(args):
    raw=pathlib.Path(args.manifest).read_bytes()
    if sha(raw)!=args.manifest_sha256: raise ValueError('reviewed manifest hash mismatch')
    manifest=json.loads(raw)
    if manifest.get('version')!=1: raise ValueError('unknown manifest version')
    approved=[r for r in manifest['candidates'] if r['review']=='approved']
    if any(r['hold_reasons'] for r in approved): raise ValueError('held candidates cannot be approved; resolve and re-inventory them')
    # Components are atomic; calls must not use names from an unapproved rename.
    approved_ids={r['id'] for r in approved}
    for row in approved:
        if any(dependency not in approved_ids for dependency in row.get('depends_on',[])):
            raise ValueError('approve dependent component before its calls')
    # An exact post-image receipt makes a second identical apply a verified no-op.
    receipt=pathlib.Path(args.manifest+'.applied.json')
    if receipt.exists():
        record=json.loads(receipt.read_text())
        if record['manifest_sha256']!=sha(raw) or any(sha(safe_path(p).read_bytes())!=h for p,h in record['files'].items()): raise ValueError('applied receipt mismatch')
        print('already applied; no diff')
        return
    source_hashes={u['path']:u['source_sha256'] for u in manifest['inputs']}
    for path,digest in source_hashes.items():
        if sha(safe_path(path).read_bytes())!=digest: raise ValueError('input hash mismatch: '+path)
    results=proposed(manifest,approved_only=True)
    for path,(before,after) in results.items(): safe_path(path).write_bytes(after)
    receipt.write_text(dump({'manifest_sha256':sha(raw),'files':{**source_hashes,**{p:sha(after) for p,(_,after) in results.items()}}}))
    print(f'applied {len(results)} files')


def main():
    parser=argparse.ArgumentParser(description=__doc__); commands=parser.add_subparsers(dest='command',required=True)
    inv=commands.add_parser('inventory'); inv.add_argument('paths',nargs='*'); inv.add_argument('--output',required=True); inv.add_argument('--helper'); inv.set_defaults(run=inventory)
    diff=commands.add_parser('diff'); diff.add_argument('manifest'); diff.add_argument('--output',required=True); diff.set_defaults(run=lambda a:write_diff(proposed(json.loads(pathlib.Path(a.manifest).read_text())),a.output))
    app=commands.add_parser('apply'); app.add_argument('manifest'); app.add_argument('--manifest-sha256',required=True); app.set_defaults(run=apply)
    args=parser.parse_args()
    try: args.run(args)
    except (ValueError,OSError,subprocess.CalledProcessError) as e: parser.exit(1,str(e)+'\n')
if __name__=='__main__': main()
