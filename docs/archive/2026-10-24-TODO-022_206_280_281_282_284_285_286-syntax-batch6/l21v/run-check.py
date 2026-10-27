"""時間上限・終了状態・伏せ字を付けて L21V の検査を保存する。"""
from pathlib import Path
import importlib.util, sys, time, os, json, tempfile
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location('process_control', OUT.parent / 'l20d/process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
commands = {
 'dry-run': ['scripts/check.sh','--level','work','--base','a7944afaa0d93f8beaebce37f45e242d2c8dadbb','--only','formal_build,spec_examples,spec_tally','--dry-run'],
 'work': ['/usr/bin/time','-l','/bin/zsh',str(OUT.relative_to(ROOT) / 'run-work.sh')],
 'up-to-date': ['lake','--no-build','build'],
 'range': ['lake','env','lean','-M','6144','Benitoite/Interval/Range.lean'],
 'axioms': ['lake','env','lean','-M','6144',str(Path('..') / OUT.relative_to(ROOT) / 'axioms.lean')],
}
mode=sys.argv[1]
cwd = ROOT/'formal' if mode in ('up-to-date','range','axioms') else ROOT
env=os.environ.copy()
cargo_cache=Path('/tmp')/'benitoite-a01a-cargo'
if cargo_cache.is_dir(): env['CARGO_HOME']=str(cargo_cache)
before=time.monotonic()
result=control.run(commands[mode],cwd=cwd,timeout=300,env=env)
output=result.stdout.replace(str(ROOT),'<repo>').replace(str(Path.home()),'<home>').replace(tempfile.gettempdir(),'<tmp>').replace('/tmp/','<tmp>/')
(OUT/(mode+'.log')).write_text(output)
record={'command':commands[mode], 'exit':result.returncode,'seconds':round(time.monotonic()-before,3)}
if mode=='work':
 import re
 match=re.search(r'L21V_CHECK_EXIT_STATUS=(\d+)',output)
 record['check_exit']=int(match.group(1)) if match else None
record['cargo_home']='<tmp>/benitoite-a01a-cargo' if cargo_cache.is_dir() else 'inherited'
(OUT/(mode+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False))
print(output[-2000:])
sys.exit(result.returncode)
