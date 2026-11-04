"""既定の全宣言を一度監査し、private・生成宣言と印字時の実体化を照合する。"""
from pathlib import Path
import argparse
import collections
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
ALLOWED={'propext','Quot.sound','Classical.choice'}

def digest(path):
    data=path.read_bytes()
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def write_json(name,value):
    data=(json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
    assert len(data)<=100000,(name,len(data))
    path=HERE/name
    path.write_bytes(data)
    return {'file':name,**digest(path)}

def split_names(name,names):
    parts=[];chunk=[]
    for item in names:
        candidate=chunk+[item]
        if len(json.dumps(candidate,ensure_ascii=False,indent=2).encode())>90000 and chunk:
            parts.append(write_json(f'{name}-part-{len(parts)+1:02}.json',chunk));chunk=[]
        chunk.append(item)
    if chunk:parts.append(write_json(f'{name}-part-{len(parts)+1:02}.json',chunk))
    return parts

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tmp',type=Path,required=True)
    ap.add_argument('--reuse-completed',action='store_true',help='同じ入力の完走済み出力から記録だけを再集計する')
    args=ap.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
    requested=json.loads((HERE/'audit-request-modules.json').read_text())
    new=set(json.loads((HERE/'modules.json').read_text()))
    source=(HERE/'axioms.lean').read_text().replace('-- NEW_MODULES',', '.join(json.dumps('Benitoite.Release.Refinement.'+n) for n in requested))
    audit_input=args.tmp/'audit-input.lean'
    target=args.tmp/'audit-targets.txt';raw=args.tmp/'audit.log'
    if args.reuse_completed:
        assert audit_input.read_text()==source
        record=json.loads((HERE/'audit-execution.json').read_text())
        assert record['exit']==0 and record['raw']==digest(raw) and record['audit_input']==digest(audit_input)
    else:
        audit_input.write_text(source)
        command=['lake','env','lean','-M','12288',str(audit_input.resolve())]
        start=datetime.now(timezone.utc);tick=time.monotonic()
        env=dict(os.environ,L40_AUDIT_TARGETS=str(target.resolve()))
        with raw.open('wb') as stream:
            result=subprocess.run(command,cwd=ROOT/'formal',env=env,stdout=stream,stderr=subprocess.STDOUT)
        elapsed=time.monotonic()-tick;end=datetime.now(timezone.utc)
        record={'command':['lake','env','lean','-M','12288','<tmp>/audit-input.lean'],
            'start_utc':start.isoformat(),'end_utc':end.isoformat(),'seconds':elapsed,
            'exit':result.returncode,'raw':digest(raw),'audit_input':digest(audit_input)}
        write_json('audit-execution.json',record)
        if result.returncode:
            write_json('audit-failure.json',{**record,'targets_processed':len(re.findall(r'^AUDIT_TARGET ',raw.read_text(),re.M))})
            print(json.dumps(record,ensure_ascii=False));raise SystemExit(result.returncode)
    output=raw.read_text();names=target.read_text().splitlines()
    assert len(names)==len(set(names)) and len(names)>77000
    assert re.findall(r'^AUDIT_TARGET (.+)$',output,re.M)==names
    assert not re.search(r'error:|AUDIT_(?:REQUIRED_MISSING|MODULE_MISSING|MISSING|DUPLICATE|AXIOM|FIXED_POINT_LIMIT)',output)
    modules={m:int(n) for m,n in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$',output,re.M)}
    assert sum(modules.values())==len(names) and 'Benitoite' in modules
    assert all('Benitoite.Release.Refinement.'+n in modules for n in requested)
    deps=re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])",output,re.M|re.S)
    found=collections.Counter(n for n,_,_ in deps)
    assert set(found)==set(names) and all(v==1 for v in found.values())
    sets=collections.Counter(tuple(sorted(a.strip() for a in s.split(',') if a.strip())) for _,_,s in deps)
    assert all(set(s)<=ALLOWED for s in sets),sets
    added=collections.defaultdict(list)
    for module,name in re.findall(r'^AUDIT_NEW_DECL (\S+) (.+)$',output,re.M):added[module].append(name)
    declarations=[]
    for short in requested:
        module='Benitoite.Release.Refinement.'+short;values=sorted(added[module])
        assert len(values)==modules[module] and len(values)==len(set(values))
        pieces=split_names('declarations-'+short.replace('.','-'),values)
        declarations.append({'module':module,'count':len(values),'parts':pieces})
    module_parts=[];items=list(sorted(modules.items()))
    for i in range(0,len(items),300):
        module_parts.append(write_json(f'audit-modules-part-{i//300+1:02}.json',dict(items[i:i+300])))
    source_inputs={}
    for name in ['formal/Benitoite.lean']+['formal/Benitoite/Release/Refinement/'+n.replace('.','/')+'.lean' for n in requested]:
        source_inputs[name]=digest(ROOT/name)
    source_parts=[];items=list(sorted(source_inputs.items()))
    for i in range(0,len(items),100):
        source_parts.append(write_json(f'audit-source-inputs-part-{i//100+1:02}.json',dict(items[i:i+100])))
    requested_parts=[]
    for i in range(0,len(declarations),75):
        requested_parts.append(write_json(f'audit-requested-part-{i//75+1:02}.json',declarations[i:i+75]))
    summary={**record,'targets' :len(names),'target_list':digest(target),'module_count':len(modules)-1,
        'module_parts':module_parts,'closure_rounds':int(re.search(r'^AUDIT_ROUNDS (\d+)$',output,re.M)[1]),
        'private_and_generated_included':True,'new_axioms':0,
        'axiom_sets':{' + '.join(k) or 'none':v for k,v in sorted(sets.items())},
        'new_modules':{n:modules['Benitoite.Release.Refinement.'+n] for n in sorted(new)},
        'requested_module_declarations':sum(d['count'] for d in declarations),
        'requested_module_parts':requested_parts,'source_input_parts':source_parts,
        'collection_from_completed_execution':args.reuse_completed,
        'audit_script':digest(Path(__file__)),'audit_template':digest(HERE/'axioms.lean')}
    write_json('audit-summary.json',summary)
    print(json.dumps({k:summary[k] for k in ['exit','seconds','targets','module_count','closure_rounds','new_axioms']},ensure_ascii=False))

if __name__=='__main__':main()
