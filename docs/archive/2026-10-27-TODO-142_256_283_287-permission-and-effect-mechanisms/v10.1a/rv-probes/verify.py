import json,gzip,hashlib,os,sys,random
root=sys.argv[1]
d=json.load(gzip.open(sys.argv[2]))
sh=d["sourceHashes"]
ok=bad=miss=0; bads=[]
sample=random.Random(1).sample(sorted(sh),6)
for p,h in sh.items():
    v=h if isinstance(h,str) else h.get("sha256")
    fp=os.path.join(root,p)
    if not os.path.isfile(fp): miss+=1; bads.append(("miss",p)); continue
    c=hashlib.sha256(open(fp,"rb").read()).hexdigest()
    if c==v: ok+=1
    else: bad+=1; bads.append(("bad",p))
    if p in sample: print("sample",p,v[:16],c[:16])
print("ok",ok,"bad",bad,"miss",miss,bads[:5])
ex=[p for p in sh if p.startswith("formal/.lake/build/bin/")]
print("exe in sourceHashes:",ex)
cats={}
for p in sh:
    k=p.split("/")[0] if "/" in p else p
    cats[k]=cats.get(k,0)+1
print(cats)
print(type(next(iter(sh.values()))))
