"""/usr/bin/time -p の終了を直接受け取り、外側時間と補助の子プロセス最大RSSを残す。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time
here = Path(__file__).resolve().parent
root = here.parents[2]
label, *command = sys.argv[1:]
start = datetime.datetime.now(datetime.timezone.utc).isoformat()
tick = time.monotonic()
result = subprocess.run(['/usr/bin/time', '-p', *command], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic()-tick
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
raw = result.stdout.decode(errors='replace').replace(str(root), '<wt>').replace(str(Path.home()), '<home>')
(here/(label+'.log')).write_text(raw)
(here/(label+'.exit')).write_text(str(result.returncode)+'\n')
report = dict(command=command,start=start,end=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit=result.returncode,seconds=elapsed,maxrssRaw=rss,maxrssUnit='bytes' if sys.platform=='darwin' else 'KiB',maxrssBytes=rss if sys.platform=='darwin' else rss*1024)
(here/(label+'.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
print(raw[-3500:])
sys.exit(result.returncode)
