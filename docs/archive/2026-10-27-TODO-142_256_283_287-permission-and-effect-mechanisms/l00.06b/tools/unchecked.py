import re,sys,os,json
root=sys.argv[1]  # formal dir
failed=sys.argv[2].split(',') if len(sys.argv)>2 and sys.argv[2] else []
roots=["Benitoite","DesugarDiff.Main","BuiltinCheck.Main","CoverageDiff.Main","CoverageProgramDiff.Main","SurfaceCheck.Main","SurfaceCheck.All","IntervalDiff.Main"]
def path(m): return os.path.join(root,*m.split('.'))+'.lean'
imps={}
def load(m):
    if m in imps: return
    p=path(m)
    if not os.path.exists(p): imps[m]=None; return
    ims=[]
    for line in open(p):
        mm=re.match(r'^import\s+(\S+)',line)
        if mm: ims.append(mm.group(1))
    imps[m]=ims
    for x in ims: load(x)
for r in roots: load(r)
local={m for m,v in imps.items() if v is not None}
# transitive dependents of failed
rev={m:set() for m in local}
for m in local:
    for x in imps[m]:
        if x in local: rev[x].add(m)
bad=set(); st=list(failed)
while st:
    x=st.pop()
    for y in rev.get(x,()):
        if y not in bad: bad.add(y); st.append(y)
bad-=set(failed)
print(json.dumps({"closure":len(local),"failed":failed,"unchecked":len(bad)}))
