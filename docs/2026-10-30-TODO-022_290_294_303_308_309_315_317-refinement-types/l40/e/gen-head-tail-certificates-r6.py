"""有限の線形証明書を生成する。正しさは出力先のKernel.checkの証明が検査する。"""
from itertools import combinations
from pathlib import Path
import argparse
v=lambda i:('var',i)
c=lambda n:('integer',n)
add=lambda x,y:('add',x,y)
eq=lambda x,y:('eq',x,y)
le=lambda x,y:('le',x,y)
def conj(xs):return ('truth',) if not xs else xs[0] if len(xs)==1 else ('and',xs[0],conj(xs[1:]))
def keys(x):
 if x[0]=='integer' or x[0]=='truth':return []
 if x[0]=='var':return [x]
 return sum((keys(y) for y in x[1:]),[])
def affine(t,ks):
 if t[0]=='integer':return [0]*len(ks),t[1]
 if t[0]=='var':
  a=[0]*len(ks);a[ks.index(t)]=1;return a,0
 a,x=affine(t[1],ks);b,y=affine(t[2],ks)
 return [x+y for x,y in zip(a,b)],x+y
# 定数項の取り違えを避けるため、係数と定数を別々に保持する。
def bound(a,b,n,ks):
 ca,ka=affine(a,ks);cb,kb=affine(b,ks)
 return ('linear',tuple(x-y for x,y in zip(ca,cb)),n-ka+kb)
def normalize(p,neg,ks):
 op=p[0]
 if op=='truth':return ('false',) if neg else ('true',)
 if op=='and':return ('or' if neg else 'and',normalize(p[1],neg,ks),normalize(p[2],neg,ks))
 if op=='eq':return ('or' if neg else 'and',bound(p[1],p[2],-1 if neg else 0,ks),bound(p[2],p[1],-1 if neg else 0,ks))
 if op=='le':return bound(p[2],p[1],-1,ks) if neg else bound(p[1],p[2],0,ks)
 raise ValueError(p)
def refute(todo,facts,n):
 if todo:
  x,*rest=todo
  if x[0]=='or':return f'(.cases {refute([x[1]]+rest,facts,n)} {refute([x[2]]+rest,facts,n)})'
  if x[0]=='and':return f'(.consume {refute([x[1],x[2]]+rest,facts,n)})'
  if x[0]=='linear':return f'(.consume {refute(rest,facts+[x],n)})'
  if x[0]=='true':return f'(.consume {refute(rest,facts,n)})'
  if x[0]=='false':return '(.consume (.closeLinear 0))'
 for size in range(1,len(facts)+1):
  for chosen in combinations(range(len(facts)),size):
   cs=[sum(facts[i][1][j] for i in chosen) for j in range(n)]
   k=sum(facts[i][2] for i in chosen)
   if not any(cs) and k<0:
    terms='['+','.join(f'({i},1)' for i in chosen)+']'
    return f'(.derive (.combine {terms} ⟨List.replicate {n} 0,{k}⟩) (.closeLinear {len(facts)}))'
 raise ValueError(('反証の非負結合が見つからない',facts))
def lean(x):
 return f'(.{x[0]} ({x[1]}))' if x[0] in ['var','integer'] else '.truth' if x[0]=='truth' else f'(.{x[0]} '+ ' '.join(lean(y) for y in x[1:])+')'
def output():
 out=[]
 for filt in [False,True]:
  rel=le if filt else eq;tag='filter' if filt else 'map'
  cases=[('none',[rel(add(v(0),v(1)),v(2)),eq(v(1),c(0))],rel(v(0),v(2))),
   ('append',[rel(add(v(0),v(1)),v(2)),eq(v(3),add(v(1),c(-1))),eq(v(4),v(3)),eq(v(5),add(v(0),c(1)))],rel(add(v(5),v(4)),v(2))),
   ('initial',[],rel(add(c(0),v(0)),v(0)))]
  if filt:cases.append(('skip',[rel(add(v(0),v(1)),v(2)),eq(v(3),add(v(1),c(-1))),eq(v(4),v(3))],rel(add(v(0),v(4)),v(2))))
  for name,ps,q in cases:
   p=conj(ps);ks=keys(p)+keys(q)
   cert='(.refute '+refute([('and',normalize(p,False,ks),normalize(q,True,ks))],[],len(ks))+')'
   out+= [f'private def {tag}_{name}_premise : Pred := {lean(p)}',f'private def {tag}_{name}_goal : Pred := {lean(q)}',
    f'private def {tag}_{name}_certificate : Certificate := {cert}',
    f'private theorem {tag}_{name}_checked : CertificateKernel.check {tag}_{name}_premise {tag}_{name}_goal {tag}_{name}_certificate = true := by decide','']
 return '\n'.join(out)
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args();args.output.write_text(output()+'\n')
if __name__=='__main__':main()
