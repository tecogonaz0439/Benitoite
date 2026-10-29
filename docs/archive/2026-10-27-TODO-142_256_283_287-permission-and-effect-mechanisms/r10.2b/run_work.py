"""W-Rを計時し、check.sh自身の終了状態も直接保存する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path(__file__).parent
base = 'a26ed29afaeb444325da1daf362d9fe7ad12b18b'
command = ['scripts/check.sh', '--level', 'work', '--base', base]
environment = os.environ.copy()
environment['BENITOITE_DESUGAR_DIFF_DIR'] = str((root / 'top-after').resolve())
script = '''
scripts/check.sh --level work --base "$1"
check_status=$?
printf '%s\n' "$check_status" > "$2"
exit "$check_status"
'''
start = time.monotonic()
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
with (root / 'work.log').open('w') as log:
    result = subprocess.run(
        ['/usr/bin/time', '-p', '/bin/sh', '-c', script,
         'check-work', base, str(root / 'check-exit.txt')],
        stdout=log, stderr=subprocess.STDOUT, env=environment, check=False,
    )
elapsed = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
direct_exit = int((root / 'check-exit.txt').read_text())
log_path = root / 'work.log'
log_path.write_text(log_path.read_text().replace(os.getcwd(), '<wt>').replace(os.path.expanduser('~'), '<home>'))
summary = {
    'command': command, 'timer': '/usr/bin/time -p',
    'started_utc': started, 'check_exit': direct_exit,
    'time_wrapper_exit': result.returncode, 'elapsed_seconds': elapsed,
    'ru_maxrss_bytes': usage.ru_maxrss, 'rss_mib': usage.ru_maxrss / 2**20,
}
(root / 'work.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False))
sys.exit(direct_exit or result.returncode)
