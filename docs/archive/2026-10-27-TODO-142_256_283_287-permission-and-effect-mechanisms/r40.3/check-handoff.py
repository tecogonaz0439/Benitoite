#!/usr/bin/env python3
"""固定入力と独立期待値を実 CLI の最終報告で照合し、全出力を保存する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
root = Path.cwd()
manifest_path = out / 'handoff.json'
manifest_bytes = manifest_path.read_bytes()
manifest_hash = hashlib.sha256(manifest_bytes).hexdigest()
assert manifest_hash == (out / 'handoff.sha256').read_text().split()[0]
manifest = json.loads(manifest_bytes)
cli = root / 'target/debug/benitoite'
prefix = sys.argv[1] if len(sys.argv) > 1 else 'handoff-check'
records = []
failures = []
reports_dir = out / (prefix + '-reports')
reports_dir.mkdir(exist_ok=True)


def redact(value):
    return value.replace(str(root), '<wt>').replace(str(Path.home()), '<home>')


for case in manifest['cases']:
    source = out / case['file']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == case['sha256'], case['file']
    expected = case['expected']
    modes = [('doc', ['test', '--doc', '--check', '--report=json'])] if expected.get('doc') else [
        ('main', ['check', '--report=json']), ('test', ['test', '--check', '--report=json'])]
    if expected.get('reason'):
        modes.append(('diagnostics', ['check', '--diagnostics=json']))
    for mode, args in modes:
        command = [str(cli), *args, str(source)]
        start = time.monotonic()
        run = subprocess.run(command, capture_output=True, text=True)
        record = {'file': case['file'], 'mode': mode, 'command': [redact(arg) for arg in command],
                  'exit': run.returncode, 'elapsedSeconds': time.monotonic() - start}
        stem = source.stem + '-' + mode
        (reports_dir / (stem + '.stdout.json')).write_text(redact(run.stdout))
        (reports_dir / (stem + '.stderr.log')).write_text(redact(run.stderr))
        try:
            assert run.returncode == expected['exit'], (run.returncode, run.stderr, run.stdout[:500])
            if mode == 'diagnostics':
                assert run.stdout == ''
                diagnostics = [json.loads(line) for line in run.stderr.splitlines()]
            else:
                assert run.stderr == '', run.stderr
                report = json.loads(run.stdout)
                assert report['schemaVersion'] == (2 if mode == 'doc' else 1)
                assert report['kind'] == ('checkReport' if mode == 'main' else 'testCheckReport')
                assert report['complete'] == expected['complete']
                assert report['executed'] is False
                assert report['status'] == ('ok' if expected['exit'] == 0 else 'checkError')
                assert report['aggregateEffects'] == expected['effects'], report['aggregateEffects']
                target = report['targets'][0]
                if expected['exit'] == 0:
                    if mode == 'main':
                        contracts = [target['main']['effects']]
                    elif mode == 'doc':
                        contracts = [target['docExamples'][0]['effects']]
                    else:
                        contracts = [item['effects'] for item in target['tests']]
                    assert all(value == expected['effects'] for value in contracts), contracts
                    if mode == 'doc' and 'docExampleTests' in expected:
                        assert target['docExamples'][0]['tests'] == expected['docExampleTests']
                    # 任意 bounds を読み飛ばす受け手にも名前ごとの全上限が残る。
                    assert all({'basis': value['basis'], 'expanded': value['expanded']} ==
                               {'basis': 'declaredUpperBound', 'expanded': expected['effects']['expanded']}
                               for value in contracts)
                elif mode == 'main':
                    assert target['main'] is None
                # 所有データを作った後も元の入力・対象の識別と全バイトのハッシュが残る。
                source_id = target['sourceId']
                own_source = next(item for item in report['sources'] if item['sourceId'] == source_id)
                assert own_source['contentHash'] == {'algorithm': 'sha256', 'value': case['sha256']}
                assert any(row['targetId'] == target['targetId'] and source_id in row['sourceIds'] for row in report['sourceSets'])
                diagnostics = report['diagnostics']
                record['aggregateEffects'] = report['aggregateEffects']
                record['sourceHashMatched'] = True
            if expected.get('code'):
                matches = [diag for diag in diagnostics if diag['code'] == expected['code']]
                assert matches, diagnostics
                if expected.get('reason'):
                    assert any('reason: ' + expected['reason'] in diag['notes'] for diag in matches), matches
                record['diagnosticCode'] = expected['code']
                record['reason'] = expected.get('reason')
            if expected.get('diagnosticCode'):
                # doc の期待された診断は例の報告に保持される。
                assert expected['diagnosticCode'] in json.dumps(report['targets'][0]['docExamples'][0])
            record['matched'] = True
        except (AssertionError, KeyError, StopIteration, ValueError) as error:
            record['matched'] = False
            record['error'] = redact(str(error))
            failures.append(record)
        records.append(record)

result = {'manifestSha256': manifest_hash, 'cliSha256': hashlib.sha256(cli.read_bytes()).hexdigest(),
          'commands': len(records), 'successes': len(records) - len(failures), 'failures': failures, 'records': records}
(out / (prefix + '.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'commands': result['commands'], 'successes': result['successes'], 'failures': failures}, ensure_ascii=False))
raise SystemExit(1 if failures else 0)
