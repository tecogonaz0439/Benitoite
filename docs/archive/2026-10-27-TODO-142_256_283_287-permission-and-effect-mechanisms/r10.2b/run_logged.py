"""指定コマンドの全出力、直接の終了状態、外側時間と子のRSSを保存する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

output = Path(sys.argv[1])
command = sys.argv[2:]
start = time.monotonic()
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
with output.with_suffix('.log').open('w') as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False)
elapsed = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
log_path = output.with_suffix('.log')
log_path.write_text(log_path.read_text().replace(os.getcwd(), '<wt>').replace(os.path.expanduser('~'), '<home>'))
output.with_suffix('.json').write_text(json.dumps({
    'command': command, 'started_utc': started, 'exit': result.returncode,
    'elapsed_seconds': elapsed, 'ru_maxrss_bytes': usage.ru_maxrss,
    'rss_mib': usage.ru_maxrss / 2**20,
}, ensure_ascii=False, indent=2) + '\n')
print(output, 'exit', result.returncode, 'elapsed', elapsed, 'rss bytes', usage.ru_maxrss)
sys.exit(result.returncode)
