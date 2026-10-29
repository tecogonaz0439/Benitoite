"""試行時の診断と読者の位置を対応させる。変更は診断の指す構成子だけに限定する。"""
from pathlib import Path
import re, json, subprocess, sys
root=Path(__file__).parent
lex=re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\b(?:I?Ty)::Con\s*\(|[()\[\]{},]',re.S)
def calls(s):
    tokens=list(lex.finditer(s)); out=[]
    for i,t in enumerate(tokens):
        if not re.match(r'I?Ty::Con',t[0]): continue
        stack=['(']; commas=[]
        for u in tokens[i+1:]:
            v=u[0]
            if re.match(r'I?Ty::Con',v): stack.append('('); continue
            if len(v)!=1: continue
            if v in '([{':stack.append(v)
            elif v in ')]}':
                stack.pop()
                if not stack:
                    out.append((t.start(),u.start(),commas));break
            elif v==',' and len(stack)==1:commas.append(u.start())
    return out

def diagnostics(log):
    result=[]
    for code,body in re.findall(r'error\[(E\d+)\]:(.*?)(?=\nerror(?:\[|:)|\Z)',log,re.S):
        m=re.search(r'--> (crates/benitoite/.*\.rs):(\d+):(\d+)',body)
        if m:result.append((m[1],int(m[2]),int(m[3]),code))
    return sorted(set(result))
if sys.argv[1]=='inventory':
    ds=diagnostics((root/'check.log').read_text()); (root/'diagnostics.json').write_text(json.dumps(ds,indent=2)+'\n')
    rows=[]
    for group in ['src','tests','examples']:
        for p in sorted(Path('crates/benitoite',group).rglob('*.rs')):
            s=subprocess.check_output(['git','show','HEAD:'+str(p)]).decode()
            for a,b,commas in calls(s):
                line=s.count('\n',0,a)+1; col=a-s.rfind('\n',0,a)
                reached=[d for d in ds if d[0]==str(p) and d[1]==line]
                preceding=list(re.finditer(r'(?m)^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+(\w+)',s[:a]))
                decl=(preceding[-1][1]+':'+str(s.count('\n',0,preceding[-1].start())+1)) if preceding else '<module>'
                rows.append(dict(file=str(p),group=group,line=line,column=col,declaration=decl,text=s[a:b+1],diagnostics=[d[3] for d in reached]))
    (root/'readers.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(len(rows),len(ds))
elif sys.argv[1]=='adapt':
    ds=diagnostics(Path(sys.argv[2]).read_text());count=0
    for fn in sorted(set(d[0] for d in ds)):
        p=Path(fn);s=p.read_text();cs=calls(s); edits={}
        for _,line,col,code in [d for d in ds if d[0]==fn and d[3] in ['E0061','E0023']]:
            offset=sum(len(x) for x in s.splitlines(True)[:line-1])+col-1
            qualified=[c for c in cs if offset<=c[0] and re.fullmatch(r'[\w:]*',s[offset:c[0]])]
            candidates=qualified[:1] or [c for c in cs if c[0]<=offset<=c[1]]
            if not candidates:
                candidates=[c for c in cs if offset<=c[0] and s.count('\n',offset,c[0])==0][:1]
            if not candidates: continue
            a,b,commas=max(candidates,key=lambda c:c[0])
            inside=s[s.index('(',a)+1:b].strip()
            if inside=='..':continue
            trailing=inside.endswith(',')
            if len(commas)!=(2 if trailing else 1):continue
            value='_' if code=='E0023' else 'crate::types::builtin::RangeIndex::TOP'
            if ('/tests/' in fn and '/src/../tests/' not in fn) or '/examples/' in fn: value=value.replace('crate::','benitoite::')
            if trailing:
                pos=commas[-1];edits[pos]=', '+value
            else: edits[b]=', '+value
        for pos,value in sorted(edits.items(),reverse=True):s=s[:pos]+value+s[pos:]
        if edits:p.write_text(s);count+=len(edits)
    print('adapted',count)
