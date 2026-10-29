import json,subprocess,sys,pathlib,shutil
B=sys.argv[1]; D=pathlib.Path(sys.argv[2]); W=pathlib.Path(sys.argv[3])
h=json.load(open(D/'handoff.json'))
for c in h['cases']:
    src=D/c['file']; dst=W/src.name; shutil.copy(src,dst)
    e=c['expected']
    for mode in (['check','--report=json'],['test','--check','--report=json']):
        p=subprocess.run([B]+mode+[str(dst)],capture_output=True,text=True)
        try: d=json.loads(p.stdout)
        except Exception: print('NOJSON',src.name,mode,p.returncode,p.stdout[:200],p.stderr[:200]); continue
        agg=d.get('aggregateEffects')
        if mode[0]=='check':
            t=d['targets'][0]; eff=(t.get('main') or {}).get('effects') if t.get('main') else None
        else:
            t=d['targets'][0]; ts=t.get('tests') or []; eff=ts[0]['effects'] if ts else None
        codes=[x.get('code') for x in d.get('diagnostics',[])]
        notes=' '.join(' '.join(n if isinstance(n,str) else json.dumps(n) for n in x.get('notes',[])) for x in d.get('diagnostics',[]))
        ok = p.returncode==e['exit'] and d.get('complete')==e['complete']
        if e['exit']==0 and not e.get('doc'):
            ok = ok and (mode[0]=='test' and not ts or eff==e['effects'])
        if e.get('code'): ok = ok and e['code'] in codes and (not e.get('reason') or e['reason'] in notes)
        if e['exit']!=0: ok = ok and agg is None
        print('OK ' if ok else 'BAD',src.name,mode[0],p.returncode,codes,json.dumps(eff)[:120] if not ok else '')
