import json, subprocess, sys, os
D = sys.argv[1]; B = sys.argv[2]
H = '''import Benitoite.Trait
import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Console
'''
ep = [  # pattern, host, lo, hi, port
 ("192.168.1.0/24","192.168.1.20",1,65535,80),
 ("192.168.1.0/24","192.168.2.20",1,65535,80),
 ("192.168.1.5/24","192.168.1.5",1,65535,80),
 ("0.0.0.0/0","::1",0,65535,0),
 ("::/0","1.2.3.4",0,65535,65535),
 ("::ffff:192.168.1.0/120","::ffff:192.168.1.7",1,2,2),
 ("192.168.1.0/24","::ffff:192.168.1.7",1,2,1),
 ("::ffff:1.2.3.4/128","::ffff:1.2.3.4",1,2,1),
 ("1.2.3.4/32","1.2.3.4",1,2,1),
 ("::FFFF:1.2.3.4","::ffff:1.2.3.4",1,2,1),
 ("2001:DB8::/32","2001:db8::1",1,2,1),
 ("2001:db8:0::/32","2001:db8::1",1,2,1),
 ("2001:db8::/32","2001:0db8::1",1,2,1),
 ("127.1","127.1",1,2,1),
 ("*.1.2.3","4.1.2.3",1,2,1),
 ("*.1.2.3","x.1.2.3",1,2,1),
 ("**.1.2.3.4","x.1.2.3.4",1,2,1),
 ("API.Example.COM","api.example.com",1,2,1),
 ("1.2.3.4","example.com",1,2,1),
 ("example.com","1.2.3.4",1,2,1),
 ("10.0.0.0/8","10.255.255.255",0,0,0),
 ("10.0.0.0/08","10.0.0.1",0,0,0),
 ("10.0.0.0/33","10.0.0.1",0,0,0),
 ("::/129","::1",0,0,0),
 ("::1/128","::1",65535,65535,65535),
 ("1.2.3.4","1.2.3.4",65535,65536,1),
 ("1.2.3.4","1.2.3.4",-1,5,1),
 ("1.2.3.4","1.2.3.4",5,4,4),
 ("1.2.3.4","1.2.3.4",4,5,6),
 ("1.2.3.4","1.2.3.5",4,5,6),
 ("example.com:80","example.com",1,2,1),
 ("[::1]","::1",1,2,1),
 ("0.0.0.0","0.0.0.0",0,0,0),
 ("255.255.255.255/32","255.255.255.255",0,0,0),
 ("::","::",0,0,0),
 ("::0","::",0,0,0),
 ("0:0:0:0:0:0:0:1","::1",0,0,0),
 ("1:0:0:1:0:0:0:1","1::1:0:0:0:1",0,0,0),
 ("1::1:0:0:0:1","1::1:0:0:0:1",0,0,0),
 ("1:0:0:1::1","1::1:0:0:0:1",0,0,0),
]
def lit(s): return json.dumps(s)
res = {}
for i,(p,h,lo,hi,po) in enumerate(ep):
    f = f"{D}/s{i}.bnt"
    open(f,"w").write(H+f'''function main() -> Unit
 ()
end function
function f() -> Result[Scope.CheckedEndpoint, Scope.ScopeError]
 return Scope.checkEndpoint(hostPattern: {lit(p)}, host: {lit(h)}, minimumPort: {lo}, maximumPort: {hi}, port: {po})
end function
''')
    r = subprocess.run([B,"check",f],capture_output=True,text=True)
    codes = sorted(set(w[6:11] for w in r.stderr.split() if w.startswith("error[")))
    res[i] = ("accept" if r.returncode==0 else ",".join(codes) or r.stderr[:200])
# runtime
body = ""
for i,(p,h,lo,hi,po) in enumerate(ep):
    body += f''' match dyn(p: {lit(p)}, h: {lit(h)}, lo: {lo}, hi: {hi}, po: {po}) with
  case Result.Ok(v) ->
   match dyn(p: Scope.endpointHostPattern(v), h: Scope.endpointHost(v), lo: {lo}, hi: {hi}, po: {po}) with
    case Result.Ok(w) -> Console.writeLine("{i} OK " + Scope.endpointHostPattern(v) + " " + Scope.endpointHost(v) + " reuse=" + Scope.endpointHostPattern(w))
    case Result.Error(e) -> Console.writeLine("{i} OK-REUSE-FAIL " + Trait.Show.show(e))
   end match
  case Result.Error(e) -> Console.writeLine("{i} ERR " + Trait.Show.show(e))
 end match
'''
open(f"{D}/run.bnt","w").write(H+'''function dyn(p: String, h: String, lo: Integer, hi: Integer, po: Integer) -> Result[Scope.CheckedEndpoint, Scope.ScopeError]
 return Scope.checkEndpoint(hostPattern: p, host: h, minimumPort: lo, maximumPort: hi, port: po)
end function
function main() -> Unit uses Console.Write
'''+body+'''end function
''')
r = subprocess.run([B,"run",f"{D}/run.bnt"],capture_output=True,text=True)
lines = {int(l.split()[0]): l for l in r.stdout.splitlines() if l[:1].isdigit()}
if r.returncode: print(r.stderr[:2000])
for i,c in enumerate(ep):
    print(i, c, "| static:", res[i], "| run:", lines.get(i,"?")[len(str(i))+1:][:150])
