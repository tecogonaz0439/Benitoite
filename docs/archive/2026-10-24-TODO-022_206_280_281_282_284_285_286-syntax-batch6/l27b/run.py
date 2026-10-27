"""L27b の逐次実行とパスを伏せた記録。"""
from pathlib import Path
import datetime, fcntl, json, os, signal, subprocess, sys, tempfile, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
def redact(text):
    for value, replacement in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'), (tempfile.gettempdir().rstrip('/'), '<tmp>'), ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(value, replacement)
    return text
label, cwd, timeout, *command = sys.argv[1:]
started = datetime.datetime.now().astimezone().isoformat()
before = time.monotonic()
env = dict(os.environ)
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
process = subprocess.Popen(command, cwd=ROOT / cwd, env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, start_new_session=True)
try:
    output, _ = process.communicate(timeout=int(timeout))
    code = process.returncode
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        output, _ = process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
    code = 124
record = dict(started=started, command=redact(' '.join(command)), cwd=redact(str(ROOT / cwd)), exit=code, seconds=round(time.monotonic()-before,3))
(OUT / (label+'.log')).write_text(redact(output))
(OUT / (label+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(record, ensure_ascii=False))
print(redact(output)[-2500:])
sys.exit(code)
