"""Benitoite の既定の新旧閉包を監査し、完全名・所在・実型を保存する。"""
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
ROOT=HERE.parents[2]
OUT=HERE/'g'
ALLOWED={'propext','Quot.sound','Classical.choice'}


def digest(path):
    data=path.read_bytes()
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}


def write(name,value):
    data=(json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
    assert len(data)<=100000,(name,len(data))
    (OUT/name).write_bytes(data)
    return {'file':name,**digest(OUT/name)}


def chunks(label,values):
    result=[];chunk=[]
    for value in values:
        if len(json.dumps(chunk+[value],ensure_ascii=False,indent=2).encode())>90000 and chunk:
            result.append(write(f'{label}-part-{len(result)+1:02}.json',chunk));chunk=[]
        chunk.append(value)
    if chunk:result.append(write(f'{label}-part-{len(result)+1:02}.json',chunk))
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tmp',type=Path,required=True)
    ap.add_argument('--collect',action='store_true',help='完走済みの同じ生出力を再集計する')
    args=ap.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
    raw=args.tmp/'stage-audit.log';target=args.tmp/'stage-targets.txt'
    command=['lake','env','lean','-M','12288','../'+str((HERE/'axioms.lean').relative_to(ROOT))]
    if not args.collect:
        start=datetime.now(timezone.utc);tick=time.monotonic()
        env=dict(os.environ,L40_STAGE_AUDIT_TARGETS=str(target.resolve()))
        with raw.open('wb') as stream:
            result=subprocess.run(command,cwd=ROOT/'formal',env=env,stdout=stream,stderr=subprocess.STDOUT)
        record={'command':command,'start_utc':start.isoformat(),'end_utc':datetime.now(timezone.utc).isoformat(),
                'seconds':time.monotonic()-tick,'exit':result.returncode,'raw':digest(raw),
                'input':digest(HERE/'axioms.lean')}
        write('audit-execution.json',record)
        if result.returncode:
            print(json.dumps(record));raise SystemExit(result.returncode)
    else:
        record=json.loads((OUT/'audit-execution.json').read_text())
        assert record['exit']==0 and record['raw']==digest(raw) and record['input']==digest(HERE/'axioms.lean')
    output=raw.read_text();names=target.read_text().splitlines()
    assert len(names)==len(set(names))
    assert re.findall(r'^AUDIT_TARGET (.+)$',output,re.M)==names
    assert not re.search(r'error:|AUDIT_(?:REQUIRED_MISSING|MODULE_MISSING|MISSING|AXIOM|FIXED_POINT_LIMIT)|SIGNATURE_(?:MODULE_MISSING|AMBIGUOUS|MISSING)',output)
    dependencies=re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])",output,re.M|re.S)
    found=collections.Counter(n for n,_,_ in dependencies)
    assert set(found)==set(names) and all(v==1 for v in found.values())
    axiom_sets=collections.Counter(tuple(sorted(a.strip() for a in s.split(',') if a.strip())) for _,_,s in dependencies)
    assert all(set(s)<=ALLOWED for s in axiom_sets),axiom_sets
    modules={m:int(n) for m,n in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$',output,re.M)}
    assert sum(modules.values())==len(names)
    records=[]
    for module,kind,line,name in re.findall(r'^AUDIT_NEW_DECL (\S+) (\S+) (\d+) (.+)$',output,re.M):
        records.append({'name':name,'module':module,'kind':kind,
                        'source':'formal/'+module.replace('.','/')+'.lean' if module!='local_records' else None,
                        'line':int(line) or None})
    changed=json.loads((OUT/'changed-modules.json').read_text())
    for module in changed['modules']:
        assert sum(r['module']==module for r in records)==modules[module]
    # 同じ所属・所在を宣言ごとに重ねず、全名の写しを段末の一回分だけ保持する。
    catalogue=[]
    for module in changed['modules']:
        entries=[r for r in records if r['module']==module]
        for start in range(0,len(entries),100):
            catalogue.append({'module':module,'source':entries[0]['source'],
                              'columns':['name','kind','line'],
                              'declarations':[[r['name'],r['kind'],r['line']] for r in entries[start:start+100]]})
    for path in OUT.glob('declarations-part-*.json'):path.unlink()
    parts=chunks('declarations',catalogue)
    module_parts=chunks('audit-modules',[{'module':k,'count':v} for k,v in sorted(modules.items())])
    inputs={str(p.relative_to(ROOT)):digest(p) for p in sorted((ROOT/'formal').rglob('*.lean')) if '.lake' not in p.parts}
    manifest=args.tmp/'formal-audit-inputs.json';manifest.write_text(json.dumps(inputs,indent=2)+'\n')
    input_parts=chunks('audit-inputs',[{'file':k,**v} for k,v in inputs.items()])
    # ppExpr の型は証明本体を評価しない。名前と全前提・結論をレビュー用に分割する。
    signatures=re.findall(r'^SIGNATURE_BEGIN (\S+) (\S+)\n(.*?)^SIGNATURE_END \2$',output,re.M|re.S)
    expected_signatures = len(re.findall(r'\(\"Benitoite[^\"]+\", \"[^\"]+\"\)', (HERE/'axioms.lean').read_text().split('let signatures :',1)[1]))
    assert len(signatures)==expected_signatures,(len(signatures),expected_signatures)
    signature_parts=[];page='# 段末の実際の署名\n\n既定環境の宣言の型を印字した。証明本体の評価ではない。\n\n'
    for module,name,typ in signatures:
        item='## '+name+'\n\n所在: `formal/'+module.replace('.','/')+'.lean`\n\n```lean\n'+typ.strip()+'\n```\n\n'
        if len((page+item).encode())>90000:
            dest=f'signatures-part-{len(signature_parts)+1:02}.md';(OUT/dest).write_text(page)
            signature_parts.append({'file':dest,**digest(OUT/dest)});page='# 段末の実際の署名（続き）\n\n'
        page+=item
    if page:
        dest=f'signatures-part-{len(signature_parts)+1:02}.md';(OUT/dest).write_text(page)
        signature_parts.append({'file':dest,**digest(OUT/dest)})
    summary={**record,'targets':len(names),'target_list':digest(target),
             'project_modules':len(modules)-('local_records' in modules),
             'local_records':modules.get('local_records',0),
             'closure_rounds':int(re.search(r'^AUDIT_ROUNDS (\d+)$',output,re.M)[1]),
             'changed_modules':len(changed['modules']),'added_modules':len(changed['new_modules']),
             'changed_module_declarations':len(records),'declaration_parts':parts,
             'new_module_declarations':sum(modules[m] for m in changed['new_modules']),
             'module_parts':module_parts,'formal_input_manifest':digest(manifest),'formal_input_parts':input_parts,
             'axiom_sets':{' + '.join(k) or 'none':v for k,v in sorted(axiom_sets.items())},
             'new_axioms':0,'private_and_generated_included':True,'signatures':len(signatures),
             'signature_parts':signature_parts,'script':digest(Path(__file__))}
    write('audit-summary.json',summary)
    print(json.dumps({k:summary[k] for k in ['exit','seconds','targets','project_modules','local_records','closure_rounds','changed_module_declarations','new_module_declarations','new_axioms','signatures']}))


if __name__=='__main__':main()
