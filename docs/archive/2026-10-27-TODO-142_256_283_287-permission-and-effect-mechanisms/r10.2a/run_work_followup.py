"""初回の失敗を保ち、必要な検査の続行と直接の終了状態を記録する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path(__file__).parent
base = 'bbc22ac0913910d26936f4b2e2def2204da93c4f'
command = ['scripts/check.sh', '--level', 'work', '--base', base]
if '--retry' in sys.argv:
    command += ['--only', 'fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally', '--test', '*']
prefix = 'work-retry' if '--retry' in sys.argv else 'work-followup'
if '--dry-run' in sys.argv:
    command += ['--dry-run']
    prefix += '-dry-run'
environment = os.environ.copy()
environment['BENITOITE_DESUGAR_DIFF_DIR'] = str((root / 'top-after').resolve())
exit_path = root / (prefix + '-check-exit.txt')
script = '''
exit_path=$1
shift
"$@"
check_status=$?
printf '%s\n' "$check_status" > "$exit_path"
exit "$check_status"
'''
start = time.monotonic()
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
log_path = root / (prefix + '.log')
with log_path.open('w') as log:
    result = subprocess.run(
        ['/usr/bin/time', '-p', '/bin/sh', '-c', script,
         'check-work', str(exit_path), *command],
        stdout=log, stderr=subprocess.STDOUT, env=environment, check=False,
    )
elapsed = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
direct_exit = int(exit_path.read_text())
log_path.write_text(log_path.read_text().replace(os.getcwd(), '<wt>').replace(os.path.expanduser('~'), '<home>'))
summary = {
    'command': command, 'timer': '/usr/bin/time -p',
    'started_utc': started,
    'finished_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'check_exit': direct_exit, 'time_wrapper_exit': result.returncode,
    'elapsed_seconds': elapsed, 'ru_maxrss_bytes': usage.ru_maxrss,
    'rss_mib': usage.ru_maxrss / 2**20,
}
(root / (prefix + '.json')).write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False))
sys.exit(direct_exit or result.returncode)
