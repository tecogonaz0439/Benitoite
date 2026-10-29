"""局所コピーをビルドし、同じ公開境界の観測を保存する。"""
from pathlib import Path
import datetime,json,subprocess,sys,time,shutil,os

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
variant=sys.argv[1]
events=HERE/'commands.jsonl'
def run(cmd,**kwargs):
    start=datetime.datetime.now(datetime.timezone.utc).isoformat(); now=time.monotonic()
    out=subprocess.run(cmd,capture_output=True,text=True,**kwargs)
    elapsed=time.monotonic()-now
    with events.open('a') as f:
        f.write(json.dumps({'start':start,'command':cmd,'exit':out.returncode,'elapsed_seconds':elapsed})+'\n')
    return out,elapsed

if '--build' in sys.argv:
    out,elapsed=run(['cargo','build','--manifest-path',str(HERE/variant/'Cargo.toml'),'--example','f0_probe'],env={**os.environ,'CARGO_TARGET_DIR':str(ROOT/'target')})
    (HERE/(variant+'-build.log')).write_text(out.stdout+out.stderr)
    print(variant,'build',out.returncode,f'{elapsed:.3f}s',out.stderr[-150:])
    if out.returncode: sys.exit(out.returncode)
    shutil.copy2(ROOT/'target/debug/examples/f0_probe',HERE/(variant+'-probe'))

inputs=sorted((HERE/'inputs').glob('*.bnt'))
out,elapsed=run([str(HERE/(variant+'-probe')),*map(str,inputs)])
(HERE/(variant+'.jsonl')).write_text(out.stdout)
(HERE/(variant+'.stderr')).write_text(out.stderr)
print(variant,'probe',out.returncode,f'{elapsed:.3f}s','rows',len(out.stdout.splitlines()))
sys.exit(out.returncode)
