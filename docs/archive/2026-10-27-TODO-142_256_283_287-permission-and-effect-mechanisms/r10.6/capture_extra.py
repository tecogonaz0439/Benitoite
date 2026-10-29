"""旧構文の補足入力と CLI 上限を、同じ入力・オプションで採取する。"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

record = Path(__file__).resolve().parent.relative_to(Path.cwd())
label, binary = sys.argv[1:]
rows = []


def clean(data):
    return data.decode().replace(os.getcwd(), '<wt>').replace(str(Path.home()), '<home>')


for source in sorted((record / 'inputs').glob('*.bnt')):
    for option in ['--diagnostics=text', '--diagnostics=json', '--report=json']:
        proc = subprocess.run([binary, 'check', option, str(source)], capture_output=True)
        rows.append(dict(input=str(source), sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                         options=['check', option], exit=proc.returncode,
                         stdout=clean(proc.stdout), stderr=clean(proc.stderr)))

for name, limit in [('cli-upper', ''), ('cli-upper', 'File.Read'),
                    ('cli-upper', 'IO.All'), ('cli-upper', 'File.Read["/data/**"]'),
                    ('user-handled', ''), ('user-handled', 'Ask')]:
    source = record / 'inputs' / (name + '.bnt')
    options = ['run', '--diagnostics=json', '--allow-effects=' + limit]
    proc = subprocess.run([binary, *options, str(source)], capture_output=True)
    rows.append(dict(input=str(source), sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                     options=options, exit=proc.returncode,
                     stdout=clean(proc.stdout), stderr=clean(proc.stderr)))

(record / (label + '.json')).write_text(json.dumps(dict(
    binary_sha256=hashlib.sha256(Path(binary).read_bytes()).hexdigest(), cases=rows),
    ensure_ascii=False, indent=2) + '\n')
print(len(rows), '補足の CLI 採取を保存した')
