"""L27a の逐次実行とパスを伏せた記録。"""
from pathlib import Path
import datetime, json, os, subprocess, sys, tempfile, time
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
try:
    result = subprocess.run(command, cwd=ROOT / cwd, env=env, capture_output=True, text=True, timeout=int(timeout))
    output, code = result.stdout + result.stderr, result.returncode
except subprocess.TimeoutExpired as error:
    output = str(error.stdout or '') + str(error.stderr or '')
    code = 124
record = dict(started=started, command=redact(' '.join(command)), cwd=redact(str(ROOT / cwd)), exit=code, seconds=round(time.monotonic()-before,3))
(OUT / (label+'.log')).write_text(redact(output))
(OUT / (label+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(record, ensure_ascii=False))
print(redact(output)[-2500:])
sys.exit(code)
