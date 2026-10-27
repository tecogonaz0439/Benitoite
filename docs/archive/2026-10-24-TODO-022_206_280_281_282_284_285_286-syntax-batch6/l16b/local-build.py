from pathlib import Path
import subprocess,time,json
root=Path(__file__).resolve().parents[3]/'formal'
out=root.parent/'docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l16b'
seen=set(); order=[]
def visit(name):
    if name in seen:return
    seen.add(name)
    path=root/(name.replace('.', '/')+'.lean')
    if not path.exists():return
    for line in path.read_text().splitlines():
        if line.startswith('import '):
            for dep in line[7:].split():visit(dep)
    if name.startswith('Benitoite.Interval.'):order.append(name)
for p in sorted((root/'Benitoite/Interval').glob('*.lean')):visit('Benitoite.Interval.'+p.stem)
start=time.monotonic()
with (out/'sequential-build.log').open('a') as log:
    for name in order:
        print(name,flush=True);log.write('\n$ lake build '+name+'\n');log.flush()
        t=time.monotonic()
        result=subprocess.run(['lake','build',name],cwd=root,stdout=log,stderr=subprocess.STDOUT)
        elapsed=time.monotonic()-t
        log.write(f'\nexit={result.returncode}, seconds={elapsed:.3f}\n');log.flush()
        if result.returncode:
            print(f'FAILED {name} ({elapsed:.3f}s)',flush=True);raise SystemExit(result.returncode)
print(f'OK {len(order)} modules, {time.monotonic()-start:.3f}s')
