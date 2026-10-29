import json,subprocess,sys
B=sys.argv[1]
for args in sys.argv[2:]:
    a=args.split()
    p=subprocess.run([B]+a,capture_output=True,text=True)
    out=p.stdout.strip()
    try:
        j=json.loads(out)
        diag=[(d['code'],d['message']) for d in j.get('diagnostics',[])]
        ents=[]
        for k in ('functions','entries','tests','contracts'):
            if k in j: ents.append((k,j[k]))
        s=json.dumps(j,ensure_ascii=False)
        print('==',args,'exit',p.returncode,'complete',j.get('complete'),'status',j.get('status'))
        print('  diag',diag)
        print('  effects',json.dumps(j.get('effects'),ensure_ascii=False))
        print('  aggregate',json.dumps(j.get('aggregateEffects'),ensure_ascii=False))
        print('  "Audit" in report:', 'Audit' in s, '| tests effects:', [ (t.get('name'),t.get('effects')) for t in j.get('tests',[])])
    except Exception as e:
        print('==',args,'exit',p.returncode,'raw',out[:400],p.stderr[:600])
