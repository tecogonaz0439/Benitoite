import subprocess,re,os,sys
repo=sys.argv[1]  # リポジトリの根
base='5fd3664e'
root='formal/Benitoite/Release/Refinement'
files=subprocess.check_output(['git','-C',repo,'ls-tree','-r','--name-only',base,root],text=True).split()
def decls(text):
    # returns name-> statement text (up to := or where or | at line start)
    out={}
    pat=re.compile(r'^(\s*)(private\s+|noncomputable\s+|@\[[^\]]*\]\s*)*(theorem|lemma|def|structure|abbrev|inductive)\s+(\S+)',re.M)
    ms=list(pat.finditer(text))
    for i,m in enumerate(ms):
        end=ms[i+1].start() if i+1<len(ms) else len(text)
        body=text[m.start():end]
        kind=m.group(3)
        if kind in('theorem','lemma'):
            j=body.find(':= ')
            k=body.find(':=\n')
            cut=[x for x in (j,k) if x>=0]
            st=body[:min(cut)] if cut else body
            # handle "by" after :=
        else:
            st=body
        st=re.sub(r'--.*','',st)
        st=re.sub(r'/-.*?-/','',st,flags=re.S)
        st=' '.join(st.split())
        st=re.sub(r'^(private |noncomputable |@\[[^\]]*\] )+','',st)
        out[m.group(4)]=(kind,st)
    return out
B={};N={}
for f in files:
    t=subprocess.check_output(['git','-C',repo,'show',f'{base}:{f}'],text=True)
    for k,v in decls(t).items(): B[k]=(f,)+v
for dp,_,fs in os.walk(os.path.join(repo,root)):
    for f in fs:
        if f.endswith('.lean'):
            t=open(os.path.join(dp,f)).read()
            for k,v in decls(t).items(): N[k]=(os.path.relpath(os.path.join(dp,f),repo),)+v
rem=[k for k in B if k not in N]
add=[k for k in N if k not in B]
chg=[k for k in B if k in N and B[k][2]!=N[k][2]]
print('base',len(B),'new',len(N),'removed',len(rem),'added',len(add),'changed',len(chg))
print('REMOVED');
for k in sorted(rem): print(' ',B[k][1],k)
print('CHANGED')
for k in sorted(chg):
    if B[k][1]=='theorem' or B[k][1]=='lemma':
        print('---',k,N[k][0].split('/')[-1]); print(' -',B[k][2]); print(' +',N[k][2])
    else: print('--- def',k,N[k][0].split('/')[-1])
