"""外側の時間・子プロセス最大常駐量・直接の終了状態を保存する。"""
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
label, *command = sys.argv[1:]
root = Path.cwd()
replacements = [(str(root), '<wt>'), (str(Path.home()), '<home>')]

def redact(text):
    for old, new in replacements:
        text = text.replace(old, new)
    return text

started = time.monotonic()
process = subprocess.run(['/usr/bin/time', '-p', *command], text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - started
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
unit = 'bytes' if sys.platform == 'darwin' else 'KiB'
bytes_ = rss if unit == 'bytes' else rss * 1024
(out / f'{label}.log').write_text(redact(process.stdout))
record = dict(command=redact(' '.join(command)), exit=process.returncode,
              elapsed_seconds=elapsed, maxrss_raw=rss, maxrss_unit=unit,
              maxrss_bytes=bytes_, maxrss_mib=bytes_ / 2**20,
              method='fresh Python getrusage(RUSAGE_CHILDREN), maximum child RSS; /usr/bin/time -p direct exit')
(out / f'{label}.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
sys.exit(process.returncode)
