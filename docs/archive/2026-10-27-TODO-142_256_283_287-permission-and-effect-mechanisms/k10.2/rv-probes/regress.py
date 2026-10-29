import json,sys
p=sys.argv[1]; mode=sys.argv[2]
c=json.load(open(p))
saved=[]
def topify(v):
    if isinstance(v,list): return [topify(x) for x in v]
    if not isinstance(v,dict): return v
    out={}
    for k,x in v.items():
        if k=='ix' and isinstance(x,dict) and x.get('fixed','top')!='top':
            saved.append(x['fixed']); out[k]={'fixed':'top'}
        elif k=='ranges' and isinstance(x,list):
            saved.extend(r for r in x if r!='top'); out[k]=['top' for _ in x]
        else: out[k]=topify(x)
    return out
c=topify(c)
if mode=='cand':
    c['inputs'][0]['candidates']=[{'name':'File.Read','ix':{'fixed':s}} for s in saved]
json.dump(c,open(p,'w'))
print(mode,len(saved))
