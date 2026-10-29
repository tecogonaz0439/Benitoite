import json,hashlib,sys,pathlib,re
raw=pathlib.Path(sys.argv[1]); rec=json.load(open(sys.argv[2])); md=open(sys.argv[3],encoding='utf-8').read()
dg=lambda b: hashlib.sha256(b).hexdigest()
ok=0; probs=[]; tf=tb=0; invok=0
for r in rec:
    p=raw/r['path']
    if not p.exists(): probs.append(('missing',r['path'])); continue
    files=sorted(q for q in p.rglob('*') if q.is_file()) if p.is_dir() else [p]
    rows=[dict(path=q.relative_to(raw).as_posix(),bytes=q.stat().st_size,sha256=dg(q.read_bytes())) for q in files]
    enc=(json.dumps(rows,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
    tf+=len(rows); tb+=sum(x['bytes'] for x in rows)
    good = len(rows)==r['files'] and sum(x['bytes'] for x in rows)==r['bytes'] and dg(enc)==r['inventorySha256']
    if r['sha256'] is not None: good = good and rows[0]['sha256']==r['sha256']
    inv=raw/r['inventory']
    if inv.exists() and dg(inv.read_bytes())==r['inventorySha256']: invok+=1
    shown=r['sha256'] or r['inventorySha256']
    if f"`{r['path']}` | {r['files']} | {r['bytes']} | `{shown}`" not in md: probs.append(('md',r['path']))
    if good: ok+=1
    else: probs.append(('mismatch',r['path'],len(rows),r['files']))
print('units',len(rec),'ok',ok,'inventoryFilesOk',invok,'files',tf,'bytes',tb,'problems',probs[:10])
# extra items in raw not listed
listed={r['path'] for r in rec}
allf=[q.relative_to(raw).as_posix() for q in raw.rglob('*') if q.is_file() and not q.relative_to(raw).as_posix().startswith('.inventories/')]
extra=[f for f in allf if not any(f==l or f.startswith(l+'/') for l in listed)]
print('extra files not under listed units',len(extra),extra[:5])
print('inventory files', len(list((raw/'.inventories').iterdir())))
