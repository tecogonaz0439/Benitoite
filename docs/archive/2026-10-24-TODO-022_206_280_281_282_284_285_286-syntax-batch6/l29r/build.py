"""新実行器の依存を一モジュールずつ native object までビルドする。"""
from pathlib import Path
import json, os, signal, subprocess, tempfile, time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
FORMAL = ROOT / 'formal'
seen, order = set(), []

def visit(name):
    if name in seen:
        return
    seen.add(name)
    path = FORMAL / (name.replace('.', '/') + '.lean')
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        if line.startswith('import '):
            for dependency in line[7:].split():
                visit(dependency)
    order.append(name)

def redact(text):
    for value, replacement in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                               (tempfile.gettempdir().rstrip('/'), '<tmp>'),
                               ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(value, replacement)
    return text

visit('IntervalDiff.Main')
visit('Benitoite.Interval.ExchangeExamples')
visit('Benitoite')
records = []
with (OUT / 'module-build.log').open('w') as log:
    for name in order:
        command = ['lake', 'build', ('+' if name == 'Benitoite' else '') + name + ':o']
        timeout = 25 if name.endswith('Examples') else 175 if name.endswith('.Sound') else 300
        before = time.monotonic()
        process = subprocess.Popen(command, cwd=FORMAL, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, start_new_session=True)
        try:
            output, _ = process.communicate(timeout=timeout)
            code = process.returncode
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                output, _ = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                output, _ = process.communicate()
            code = 124
        record = dict(module=name, command=' '.join(command), exit=code,
                      seconds=round(time.monotonic() - before, 3), timeout=timeout)
        records.append(record)
        log.write('$ ' + record['command'] + '\n' + redact(output) + '\n')
        log.write(json.dumps(record) + '\n')
        log.flush()
        (OUT / 'module-build.json').write_text(json.dumps(records, indent=2) + '\n')
        if code:
            raise SystemExit(f'FAILED {name}: exit={code}')
print(f'OK: {len(records)} modules, one module per lake build')
