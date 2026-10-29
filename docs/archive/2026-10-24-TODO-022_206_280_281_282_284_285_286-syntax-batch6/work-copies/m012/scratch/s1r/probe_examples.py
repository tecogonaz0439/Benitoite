from pathlib import Path
import json,subprocess,time
out=Path('work/m012/scratch/s1r')
examples={
 'width-add':('function f(n: Integer8) -> Integer8\n  if n > 100s8 then return n + 100s8 else return 0s8 end if\nend function\n','bind _ <- f(101s8)'),
 'width-multiply':('function f(n: Integer8) -> Integer8\n  if n > 64s8 then return n * 2s8 else return 0s8 end if\nend function\n','bind _ <- f(65s8)'),
 'width-subtract':('function f(n: UnsignedInteger16) -> UnsignedInteger16\n  if n < 10u16 then return n - 20u16 else return 0u16 end if\nend function\n','bind _ <- f(1u16)'),
 'width-negate':('function f() -> Integer8\n  bind n <- -128s8\n  return -n\nend function\n','bind _ <- f()'),
 'width-join':('function f(flag: Boolean) -> Integer8\n  bind n <- if flag then 100s8 else 110s8 end if\n  return n + 100s8\nend function\n','bind _ <- f(true)'),
 'zero-bind':('function f(t: Integer) -> Integer\n  bind n <- 0\n  return t div n\nend function\n','bind _ <- f(10)'),
 'shift-domain':('function f(n: Integer) -> Integer\n  if n > 63 then return Integer.shiftLeft(a: 1, n: n) else return 0 end if\nend function\n','bind _ <- f(64)'),
 'http-record':('import Benitoite.Unofficial.Network.Http\nfunction f(status: Integer) -> Http.Response\n  return Http.Response(status: status, headers: [], body: Bytes.empty())\nend function\n','bind _ <- f(700)'),
 'exit-domain':('import Benitoite.Unofficial.IO.Process\nfunction f(code: Integer) -> Unit uses Process.Exit\n  if code > 255 then return Process.exit(code) else return () end if\nend function\n',''),
}
records=[]
bin='target/debug/benitoite'
v=subprocess.run([bin,'--version'],capture_output=True,text=True)
(out/'version.txt').write_text(v.stdout+v.stderr)
for name,(body,main) in examples.items():
 p=out/(name+'.bnt');p.write_text(body+'\nfunction main() -> Unit\n  '+main+'\n  return ()\nend function\n')
 start=time.monotonic();r=subprocess.run([bin,'check',str(p)],capture_output=True,text=True,timeout=30)
 (out/(name+'.check.stdout')).write_text(r.stdout);(out/(name+'.check.stderr')).write_text(r.stderr)
 rec={'name':name,'command':[bin,'check',str(p)],'exit':r.returncode,'seconds':round(time.monotonic()-start,4),'stdout':r.stdout,'stderr':r.stderr}
 # 算術とシフトだけ実行し、HTTP/Process は呼び出さない。
 if name not in ('http-record','exit-domain') and r.returncode==0:
  start=time.monotonic();run=subprocess.run([bin,'run',str(p)],capture_output=True,text=True,timeout=30)
  (out/(name+'.run.stdout')).write_text(run.stdout);(out/(name+'.run.stderr')).write_text(run.stderr)
  rec['run']={'command':[bin,'run',str(p)],'exit':run.returncode,'seconds':round(time.monotonic()-start,4),'stdout':run.stdout,'stderr':run.stderr}
 records.append(rec)
 print(name,'check',rec['exit'],'run',rec.get('run',{}).get('exit','未実行'))
(out/'probes.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
