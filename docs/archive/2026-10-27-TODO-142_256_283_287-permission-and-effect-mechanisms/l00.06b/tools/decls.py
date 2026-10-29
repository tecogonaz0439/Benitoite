import re,sys
# usage: decls.py incremental.diff root
diff=open(sys.argv[1]).read().splitlines()
root=sys.argv[2]
res=[]
cur=None; newl=0
for line in diff:
    if line.startswith('+++ '):
        cur=line[4:].split('\t')[0].replace('<wt>/','')
        continue
    m=re.match(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@',line)
    if m: newl=int(m.group(1)); continue
    if cur is None or line.startswith('--- ') or line.startswith('diff '): continue
    if line.startswith('+'):
        res.append((cur,newl,'+')); newl+=1
    elif line.startswith('-'):
        res.append((cur,newl,'-'))
    else:
        newl+=1
decl_re=re.compile(r'^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|noncomputable\s+|protected\s+)*(theorem|lemma|def|abbrev|structure|inductive|instance|attribute|example)\b\s*(\S*)')
out={}
for f,l,k in res:
    try: lines=open(root+'/'+f).read().splitlines()
    except: continue
    name=None;kind=None
    for i in range(min(l,len(lines))-1,-1,-1):
        m=decl_re.match(lines[i])
        if m: name=m.group(2); kind=m.group(1); break
    out.setdefault((f.replace('formal/Benitoite/',''),kind,name),0)
    out[(f.replace('formal/Benitoite/',''),kind,name)]+=1
for (f,k,n),c in sorted(out.items()): print(f"{f}\t{k}\t{n}\t{c}")
