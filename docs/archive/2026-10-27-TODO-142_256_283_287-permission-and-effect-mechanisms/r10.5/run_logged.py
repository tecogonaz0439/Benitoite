"""局所検査と作業末検査の生ログ・終了・外側時間・補助RSSを保存する。"""
import datetime
import json
import pathlib
import resource
import shlex
import subprocess
import sys
import time

root = pathlib.Path.cwd()
record = pathlib.Path(__file__).resolve().parent
label, *command = sys.argv[1:]
work = command and command[0] == "--work"
if work:
    command = command[1:]
    exit_path = record.relative_to(root) / f"{label}-check-exit.txt"
    body = shlex.join(command) + '; check_code=$?; printf "%s\\n" "$check_code" > ' + shlex.quote(str(exit_path)) + '; exit "$check_code"'
    invoked = ["/usr/bin/time", "-p", "sh", "-c", body]
else:
    invoked = command
def sanitize(text):
    return text.replace(str(root), "<wt>").replace("/private/tmp/benitoite-r105-baseline", "<baseline>").replace(str(pathlib.Path.home()), "<home>")

started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
start = time.monotonic()
with (record / f"{label}.log").open("w") as log:
    log.write("$ " + sanitize(shlex.join(invoked)) + "\n")
    log.flush()
    proc = subprocess.Popen(invoked, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        log.write(sanitize(line))
        log.flush()
    code = proc.wait()
elapsed = time.monotonic() - start
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
result = dict(command=command, invoked=invoked, started_at=started_at,
              ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              exit_code=code, elapsed_seconds=elapsed, auxiliary_max_rss_bytes=rss,
              auxiliary_max_rss_mib=rss / 2**20,
              rss_method="macOS getrusage(RUSAGE_CHILDREN).ru_maxrss; this command only; maximum child, not concurrent sum")
if work:
    result["check_exit_code"] = int((root / exit_path).read_text())
(record / f"{label}.json").write_text(sanitize(json.dumps(result, ensure_ascii=False, indent=2)) + "\n")
print(sanitize(json.dumps(result, ensure_ascii=False, indent=2)))
sys.exit(code)
