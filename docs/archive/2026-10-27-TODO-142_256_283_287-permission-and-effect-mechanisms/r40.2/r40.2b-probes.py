# -*- coding: utf-8 -*-
"""変更しないレビュー入力を実 CLI で照合する。"""
import json
import os
from pathlib import Path
import subprocess
import time

out = Path(__file__).resolve().parent
root = Path.cwd()

def redact(text):
    for source, replacement in [(str(root), '<wt>'), (str(Path.home()), '<home>'), (os.environ.get('TMPDIR', '/private/tmp/'), '<tmp>/'), ('/private/tmp/', '<tmp>/'), ('/tmp/', '<tmp>/')]:
        text = text.replace(source, replacement)
    return text

records = []
for name, args, expected in [
    ('docerr', ['test', '--check', '--doc', '--report=json'], 0),
    ('h1', ['check', '--report=json'], 2),
]:
    command = ['target/debug/benitoite', *args, str(out / 'rv-probes' / (name + '.bnt'))]
    start = time.monotonic()
    result = subprocess.run(command, capture_output=True, text=True)
    value = json.loads(result.stdout)
    (out / ('r40.2b-' + name + '.json')).write_text(redact(json.dumps(value, ensure_ascii=False, indent=2)) + '\n')
    record = {'name': name, 'command': [redact(s) for s in command], 'exitCode': result.returncode, 'elapsedSeconds': time.monotonic() - start, 'stderr': redact(result.stderr), 'status': value['status']}
    assert result.returncode == expected, record
    assert result.stderr == '', record
    if name == 'docerr':
        example, = value['targets'][0]['docExamples']
        assert value['schemaVersion'] == 2 and value['status'] == 'ok' and value['complete'] and not value['executed'], value
        assert example['mode'] == 'error' and example['status'] == 'ok' and example['complete'], example
        assert example['effects'] == {'basis': 'declaredUpperBound', 'expanded': [], 'bounds': []}, example
        assert [d['code'] for d in example['observedDiagnostics'] if d['severity'] == 'error'] == ['E0401'], example
        assert value['aggregateEffects'] == {'basis': 'declaredUpperBound', 'expanded': [], 'bounds': []}, value
        record['effects'] = example['effects']
        record['observedError'] = 'E0401'
    else:
        assert value['status'] == 'checkError' and not value['complete'], value
        assert any(d['code'] == 'E0520' for d in value['diagnostics']), value
        assert value['targets'][0]['main'] is None and value['aggregateEffects'] is None, value
        record['observedError'] = 'E0520'
    records.append(record)
(out / 'r40.2b-probes.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(records, ensure_ascii=False))
