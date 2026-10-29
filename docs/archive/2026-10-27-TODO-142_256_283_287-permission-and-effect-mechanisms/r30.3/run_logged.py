# coding: utf-8
"""指定コマンドの終了、time -p、補助 RSS と伏字済みログを保存する。"""
import datetime
import json
from pathlib import Path
import resource
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
root = out.parents[2]
name, *command = sys.argv[1:]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
t0 = time.monotonic()
# shell はコマンド直後の終了を記録し、同じ終了を time へ返す。
args = ["/usr/bin/time", "-p", "/bin/sh", "-c",
        '\"$@\"; result=$?; printf "\\ncommand_exit=%s\\n" "$result"; exit "$result"',
        "r30.3-check", *command]
proc = subprocess.run(args, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
seconds = time.monotonic() - t0
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
text = proc.stdout.decode("utf-8", "replace")
for source, replacement in [(str(root), "<wt>"), (str(Path.home()), "<home>")]:
    text = text.replace(source, replacement)
(out / (name + ".log")).write_text(text)
record = dict(command=command, wrapper=args[:4], cwd="<wt>",
              started_utc=started, finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              command_exit=proc.returncode, outer_seconds=seconds,
              maxrss_raw=rss, maxrss_unit="bytes", maxrss_mib=rss / 2**20,
              maxrss_method="macOS getrusage(RUSAGE_CHILDREN); maximum descendant, not concurrent sum")
(out / (name + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
print(text[-1600:])
sys.exit(proc.returncode)
