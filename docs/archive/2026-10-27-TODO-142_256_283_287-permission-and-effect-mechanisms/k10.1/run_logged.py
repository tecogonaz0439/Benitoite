"""指定コマンドの終了状態・外側時間・補助RSSを保存する。"""
import datetime
import json
from pathlib import Path
import resource
import subprocess
import sys
import time

base = Path(__file__).resolve().parent
root = Path.cwd()
label, *command = sys.argv[1:]
status = base / (label + ".exit")
script = '\n'.join(['"$@"', 'result=$?', 'printf "%s\\n" "$result" > "$STATUS_FILE"', 'exit "$result"'])
import os
env = dict(os.environ, STATUS_FILE=str(status))
start = datetime.datetime.now(datetime.timezone.utc)
tick = time.monotonic()
result = subprocess.run(["/usr/bin/time", "-p", "sh", "-c", script, "logged-command", *command],
                        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
seconds = time.monotonic() - tick
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
output = result.stdout.decode("utf-8", errors="replace")
for source, replacement in [(str(root), "<wt>"), (str(Path.home()), "<home>")]:
    output = output.replace(source, replacement)
(base / (label + ".log")).write_text(output)
record = {"command":command, "start":start.isoformat(), "end":datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "exit":int(status.read_text()), "time_exit":result.returncode, "seconds":seconds,
          "max_rss_raw":rss, "max_rss_unit":"bytes", "max_rss_mib":rss/(2**20),
          "max_rss_gib":rss/(2**30), "rss_method":"macOS getrusage(RUSAGE_CHILDREN), child process maximum, not concurrent sum"}
(base / (label + ".json")).write_text(json.dumps(record, indent=2, ensure_ascii=False)+"\n")
print(json.dumps(record, ensure_ascii=False))
sys.exit(result.returncode)
