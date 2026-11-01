#!/usr/bin/env python3
"""L00b.15 の既定ビルド・名前・公理依存・例・保護入力を照合する。git は使わない。"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[3]
base = Path(__file__).resolve().parent
baseline = json.loads((base / 'baseline.json').read_text())
scratch = Path(tempfile.gettempdir()) / baseline['scratch'].removeprefix('<tmp>/')
allowed = {'propext', 'Quot.sound', 'Classical.choice'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(name, obj):
    (base / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')


def protect():
    raw = (scratch / 'protected-before.json').read_bytes()
    assert sha(raw) == baseline['protected_sha256']
    entries = json.loads(raw)
    changed = [n for n, h in entries.items() if not (root / n).is_file() or sha((root / n).read_bytes()) != h]
    assert not changed, changed
    return {'unchanged': True, 'files': len(entries), 'inventory_sha256': sha(raw)}


def audit(output):
    dependencies = set()
    reports = 0
    lines = output.splitlines()
    for index, line in enumerate(lines):
        if 'depends on axioms:' in line:
            reports += 1
            value = line.split('depends on axioms:', 1)[1]
            cursor = index + 1
            while ']' not in value and cursor < len(lines):
                value += lines[cursor]
                cursor += 1
            value = re.sub(r'\.\{[^}]*\}', '', value)
            dependencies.update(re.findall(r'[A-Za-z_][A-Za-z0-9_.]*', value))
        elif 'does not depend on any axioms' in line:
            reports += 1
    assert reports > 0
    assert not dependencies - allowed, dependencies
    return {'reports': reports, 'dependencies': sorted(dependencies)}


assert 'moreLeanArgs = ["-M", "12288"]' in (root / 'formal/lakefile.toml').read_text()
dump('protected-check.json', protect())
records = []
large = [{'record': baseline['scratch'] + '/protected-before.json', 'bytes': baseline['protected_bytes'],
          'sha256': baseline['protected_sha256']}]
jobs = [
    ('build', ['rtk', 'proxy', 'lake', 'build'], root / 'formal'),
    ('mapping', ['rtk', 'proxy', 'lake', 'env', 'lean', '-M', '12288',
                 '../' + str((base / 'mapping.lean').relative_to(root))], root / 'formal'),
    ('mapping-origins', ['rtk', 'proxy', 'lake', 'env', 'lean', '-M', '12288',
                 '../' + str((base / 'mapping-origins.lean').relative_to(root))], root / 'formal'),
    ('axioms', ['rtk', 'proxy', 'lake', 'env', 'lean', '-M', '12288',
                '../' + str((base / 'axioms.lean').relative_to(root))], root / 'formal'),
    ('spec-examples', ['rtk', 'proxy', 'cargo', 'test', '--test', 'spec_examples'], root),
]
parser = argparse.ArgumentParser()
parser.add_argument('--finalize-only', action='store_true', help='実行済みの記録と保護入力を照合して一覧を確定する')
options = parser.parse_args()
if options.finalize_only:
    records = json.loads((base / 'verification.json').read_text())
    latest = {r['label']: r for r in records}
    for label, _, _ in jobs:
        assert latest[label]['exit_code'] == 0, label
    for record in records:
        name = record['record']
        path = Path(tempfile.gettempdir()) / name.removeprefix('<tmp>/') if name.startswith('<tmp>/') else base / name
        data = path.read_bytes()
        assert len(data) == record['bytes'] and sha(data) == record['sha256'], name
        if name.startswith('<tmp>/'):
            large.append(record)
    jobs = []
for label, args, cwd in jobs:
    raw = scratch / (label + '.log')
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    clock = time.monotonic()
    with raw.open('wb') as out:
        process = subprocess.run(args, cwd=cwd, stdout=out, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    output = data.decode()
    record = {'label': label, 'command': ('cd formal && ' if cwd.name == 'formal' else '') + ' '.join(args),
              'started_utc': started, 'exit_code': process.returncode, 'seconds': round(time.monotonic() - clock, 3),
              'bytes': len(data), 'sha256': sha(data)}
    if len(data) > 100_000 or str(root).encode() in data:
        record['record'] = baseline['scratch'] + '/' + raw.name
        large.append(record.copy())
    else:
        (base / raw.name).write_bytes(data)
        record['record'] = raw.name
    records.append(record)
    dump('verification.json', records)
    assert process.returncode == 0, record
    assert "declaration uses 'sorry'" not in output
    if label == 'axioms':
        record.update(audit(output))
        modules = sorted(set(re.findall(r'AUDIT_MODULE (\S+)', output)))
        record['modules'] = len(modules)
        dump('axioms-summary.json', record)
        (base / 'audited-modules.txt').write_text('\n'.join(modules) + '\n')
        assert 'Benitoite.Release.Theorems' in modules
        assert 'Benitoite.Release.Refinement.StateTyping' in modules
    if label == 'mapping':
        expected = sum(1 for line in (base / 'mapping.lean').read_text().splitlines() if line.startswith('#check '))
        record['names'] = expected
    print(json.dumps({'label': label, 'exit_code': process.returncode, 'seconds': record['seconds'],
                      'reports': record.get('reports')}), flush=True)
dump('verification.json', records)
dump('protected-check.json', protect())
formal = sorted(p for p in (root / 'formal').rglob('*') if p.is_file() and '.lake' not in p.parts)
inputs = [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
          for p in formal]
raw = json.dumps(inputs, ensure_ascii=False, indent=2).encode()
target = scratch / 'formal-inputs.json'
target.write_bytes(raw)
large.append({'record': baseline['scratch'] + '/' + target.name, 'bytes': len(raw), 'sha256': sha(raw)})
dump('formal-inputs-summary.json', {'files': len(inputs), 'bytes': len(raw), 'sha256': sha(raw),
                                   'record': baseline['scratch'] + '/' + target.name})
for name in ['01-12-core-calculus.md', '07-04-formal-semantics.md', '00-04-glossary.md']:
    data = (scratch / name).read_bytes()
    large.append({'record': baseline['scratch'] + '/' + name, 'bytes': len(data), 'sha256': sha(data)})
(base / 'large-records.md').write_text('# 大きな記録と生の出力\n\n100 KB を超える生の記録と全入力の一覧は一時領域に置く。初回の仕様例の小さな出力も、実行環境のパスを含むため一時領域に保ち、本文へ転記しない。\n\n| 記録 | バイト | SHA-256 |\n|---|---:|---|\n' +
    ''.join('| ' + r['record'] + ' | ' + str(r['bytes']) + ' | `' + r['sha256'] + '` |\n' for r in large))
