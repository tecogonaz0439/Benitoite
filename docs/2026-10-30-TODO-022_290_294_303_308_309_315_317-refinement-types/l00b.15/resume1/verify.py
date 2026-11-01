#!/usr/bin/env python3
"""L00b.15 の検査。--finalize-only は一時ログなしでも保存した入力と記録を照合する。"""
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
baseline = json.loads((base / 'portable-baseline.json').read_text())
allowed = {'propext', 'Quot.sound', 'Classical.choice'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(name, obj):
    target = base / name
    pending = target.with_suffix(target.suffix + '.pending')
    pending.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
    pending.replace(target)


def protect():
    entries = {}
    for name in baseline['roots']:
        path = root / name
        for p in ([path] if path.is_file() else path.rglob('*')):
            if not p.is_file() or any(x in p.parts for x in ['.lake', 'target', '__pycache__', '.git']):
                continue
            rel = p.relative_to(root).as_posix()
            task = root / baseline['mutable_task']
            if rel in baseline['allowed'] or (task in p.parents and not p.name.startswith('rv-')):
                continue
            entries[rel] = sha(p.read_bytes())
    raw = json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()
    assert len(entries) == baseline['protected_files'], '保護ファイル数の変更'
    assert sha(raw) == baseline['protected_fingerprint'], '保護入力の変更'
    return {'unchanged': True, 'files': len(entries), 'fingerprint': sha(raw)}


def inputs():
    formal = [p for p in (root / 'formal').rglob('*') if p.is_file() and '.lake' not in p.parts]
    evidence = list(base.glob('*.lean')) + [base / name for name in
        ['mapping.json', 'mapping.md', 'theorems.md', 'portable-baseline.json', 'verify.py', 'check-documents.py']]
    evidence.append(base.parent / 'reviews/RV-L00b.15-request.md')
    chapters = [root / p for p in baseline['chapters']]
    paths = sorted(set(formal + evidence + chapters))
    return [[p.relative_to(root).as_posix(), sha(p.read_bytes())] for p in paths if not p.name.startswith('rv-')]


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



parser = argparse.ArgumentParser()
parser.add_argument('--finalize-only', action='store_true', help='再実行せず入力・記録を照合。一時ログの欠落は区別して報告')
options = parser.parse_args()
assert 'moreLeanArgs = ["-M", "12288"]' in (root / 'formal/lakefile.toml').read_text()
protected = protect()
if options.finalize_only:
    assert inputs() == json.loads((base / 'verification-inputs.json').read_text()), '検査後に入力が変更された'
    records = json.loads((base / 'verification.json').read_text())
    unavailable = []
    for record in records:
        assert record['exit_code'] == 0, record['label']
        name = record['record']
        path = Path(tempfile.gettempdir()) / name.removeprefix('<tmp>/') if name.startswith('<tmp>/') else base / name
        if not path.exists():
            assert name.startswith('<tmp>/'), name
            unavailable.append(name)
            continue
        data = path.read_bytes()
        assert len(data) == record['bytes'] and sha(data) == record['sha256'], name
    for record in records:
        if record['label'] in ['axioms', 'boundary', 'model-compatibility']:
            assert set(record['dependencies']) <= allowed
    result = {'records': len(records), 'inputs_match': True, 'protected': protected,
              'raw_logs_unavailable': unavailable,
              'meaning': '入力と保存記録の照合。欠落した生ログの内容を再検証したという意味ではない'}
    dump('record-check.json', result)
    print(json.dumps(result, ensure_ascii=False))
else:
    scratch = Path(tempfile.mkdtemp(prefix='benitoite-l00b15-resume-'))
    scratch_name = '<tmp>/' + scratch.name
    jobs = [('build', ['lake', 'build'], root / 'formal')]
    for name in ['mapping', 'mapping-origins', 'axioms', 'boundary', 'model-compatibility']:
        jobs.append((name, ['lake', 'env', 'lean', '-M', '12288',
                    '../' + str((base / (name + '.lean')).relative_to(root))], root / 'formal'))
    jobs.append(('spec-examples', ['cargo', 'test', '--test', 'spec_examples'], root))
    records = []
    large = []
    for label, command, cwd in jobs:
        raw = scratch / (label + '.log')
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        clock = time.monotonic()
        with raw.open('wb') as out:
            process = subprocess.run(['rtk', 'proxy', *command], cwd=cwd, stdout=out, stderr=subprocess.STDOUT)
        data = raw.read_bytes()
        output = data.decode()
        record = {'label': label, 'command': ('cd formal && ' if cwd.name == 'formal' else '') + ' '.join(command),
                  'started_utc': started, 'exit_code': process.returncode, 'seconds': round(time.monotonic() - clock, 3),
                  'bytes': len(data), 'sha256': sha(data)}
        if len(data) > 100_000 or str(root).encode() in data:
            record['record'] = scratch_name + '/' + raw.name
            large.append(record.copy())
        else:
            name = label + '-' + scratch.name.removeprefix('benitoite-l00b15-') + '.log'
            (base / name).write_bytes(data)
            record['record'] = name
        records.append(record)
        if process.returncode != 0 or "declaration uses 'sorry'" in output:
            dump('verification-attempt.json', records)
            raise RuntimeError(record)
        if label in ['axioms', 'boundary', 'model-compatibility']:
            record.update(audit(output))
        if label == 'axioms':
            modules = sorted(set(re.findall(r'AUDIT_MODULE (\S+)', output)))
            record['modules'] = len(modules)
            (base / 'audited-modules.txt').write_text('\n'.join(modules) + '\n')
        if label == 'mapping':
            record['names'] = sum(line.startswith('#check ') for line in (base / 'mapping.lean').read_text().splitlines())
        print(json.dumps({'label': label, 'exit_code': process.returncode, 'seconds': record['seconds']}), flush=True)
    protected = protect()
    dump('verification-inputs.json', inputs())
    dump('verification.json', records)
    dump('axioms-summary.json', next(r for r in records if r['label'] == 'axioms'))
    dump('protected-check.json', protected)
    dump('large-records.json', large)
    (base / 'large-records.md').write_text('# 今回の大きな記録と生の出力\n\n100 KB を超える出力又は実行環境のパスを含む出力は一時領域に置き、大きさと SHA-256 を残す。初回の記録の一覧は [initial/large-records.md](initial/large-records.md) に保つ。再照合は verification-inputs.json と verification.json だけで可能で、生ログの欠落は record-check.json に区別して記録する。\n\n| 記録 | バイト | SHA-256 |\n|---|---:|---|\n' + ''.join('| '+r['record']+' | '+str(r['bytes'])+' | `'+r['sha256']+'` |\n' for r in large))
