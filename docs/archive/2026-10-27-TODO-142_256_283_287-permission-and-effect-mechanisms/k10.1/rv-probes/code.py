import ipaddress
B=1114113
def pair(a,b): return (a+b)*(a+b+1)//2+a
def s(x):
    r=0
    for c in reversed(x): r=ord(c)+1+B*r
    return r
def word(xs):
    if not xs: return 0
    return pair(s(xs[0]),word(xs[1:]))+1
def path(p):
    if p.endswith('/**'): return 2*word([x for x in p[:-3].split('/') if x])+1
    return 2*word([x for x in p.split('/') if x])
def name(h):
    if h.startswith('**.'): return 3*word(h[3:].split('.'))+2
    if h.startswith('*.'): return 3*word(h[2:].split('.'))+1
    return 3*word(h.split('.'))
def host(h):
    try:
        if '/' in h:
            n=ipaddress.ip_network(h); fam=0 if n.version==4 else 1
            ip=2*pair(fam,pair(int(n.network_address),n.prefixlen))+1
        else:
            a=ipaddress.ip_address(h); fam=0 if a.version==4 else 1
            ip=2*pair(fam,int(a))
        return 2*ip+1
    except ValueError:
        return 2*name(h)
def rng_path(p): return 4*path(p)+1
def rng_ep(h,lo=1,hi=2): return 4*pair(host(h),pair(lo,hi))+3
def ix_fixed(r): return 2*r
def atom(n,ix): return 2*pair(s(n),ix)
paths=["/b","/a/**","/ab","/ba","/あ/x"]
print("path", sorted(range(5),key=lambda i: atom("IO.File.Read",ix_fixed(rng_path(paths[i])))))
eps=["0.0.0.1","::1","0.0.0.2","0.0.0.0/1","::/1","ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff","8000::/1","a","*.a","**.a","b"]
print("ep", sorted(range(len(eps)),key=lambda i: atom("Network.Http.Connect",ix_fixed(rng_ep(eps[i])))))
names=["State","effect:1","effect:42","IO.File.Read","IO.File.Write","Network.Http.Connect"]
items=[(f"rho{i}",2*i+1) for i in (0,3)]+[(n,atom(n,0)) for n in names]
print([x for x,_ in sorted(items,key=lambda t:t[1])])
ixs=[("rvar1",3),("top",0),("rvar0",1),("exact/",2*rng_path("/"))]
print([x for x,_ in sorted(ixs,key=lambda t:atom("IO.File.Read",t[1]))])
