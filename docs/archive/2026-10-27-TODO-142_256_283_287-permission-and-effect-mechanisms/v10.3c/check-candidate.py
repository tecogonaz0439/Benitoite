"""事前固定した期待値を候補の公開 CLI と照合し、出力を保存する。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
CLI = ROOT / 'target/release/benitoite'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def clean(text):
    return text.replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')


def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def run(label, args):
    command = [str(CLI), *args]
    start = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    (OUT / 'outputs').mkdir(exist_ok=True)
    (OUT / 'outputs' / (label + '.stdout')).write_text(clean(result.stdout))
    (OUT / 'outputs' / (label + '.stderr')).write_text(clean(result.stderr))
    record = dict(id=label, command=[clean(x) for x in command], exit=result.returncode,
                        seconds=time.monotonic()-start,
                        stdoutSha256=sha(result.stdout.encode()), stderrSha256=sha(result.stderr.encode()))
    save('outputs/' + label + '.execution.json', record)
    return result, record


frozen = (OUT / 'expectations.json').read_bytes()
assert sha(frozen) == (OUT / 'expectations.sha256').read_text().split()[0]
expected = json.loads(frozen)
producer_expected = expected['producer']


def producer(value):
    assert value['name'] == producer_expected['name'], value
    assert value['version'] == producer_expected['version'], value
    build = value['build']
    for key in ['commit', 'dirty', 'target']:
        assert build[key] == producer_expected[key], value
    assert build['provenance']['dirty'] == 'environment', value
    assert build['provenance']['commit'] == 'git', value


records = []
result, record = run('version', ['--version=json'])
assert result.returncode == 0 and not result.stderr
version = json.loads(result.stdout)
producer(dict(name='benitoite', version=version['version'], build=version['build']))
save('version.json', version)
record['matched'] = True
records.append(record)

for case in expected['cases']:
    assert sha((ROOT / case['source']).read_bytes()) == case['sha256'], case['source']
    result, record = run(case['id'], case['args'])
    e = case['expected']
    try:
        assert result.returncode == e['exit'], (result.returncode, result.stderr)
        if 'singleReport' in e:
            assert not result.stderr, result.stderr
            # json.loads は余分な二つ目の報告や前後の非 JSON 出力を拒む。
            report = json.loads(result.stdout)
            assert report['complete'] == e['complete'], report
            assert report['executed'] is e['executed'], report
            assert report['status'] == ('ok' if e['exit'] == 0 else 'checkError'), report
            assert report['aggregateEffects'] == e['effects'], report['aggregateEffects']
            producer(report['producer'])
            target = report['targets'][0]
            if e['exit'] == 0:
                if e.get('doc'):
                    contracts = [target['docExamples'][0]['effects']]
                    if 'docExampleTests' in e:
                        assert target['docExamples'][0]['tests'] == e['docExampleTests']
                    if 'diagnosticCode' in e:
                        assert e['diagnosticCode'] in json.dumps(target['docExamples'][0])
                elif case['args'][0] == 'check':
                    contracts = [target['main']['effects']]
                else:
                    contracts = [t['effects'] for t in target['tests']]
                assert all(c == e['effects'] for c in contracts), contracts
            if e.get('code'):
                diags = [d for d in report['diagnostics'] if d['code'] == e['code']]
                assert diags, report['diagnostics']
                if e.get('reason'):
                    assert any('reason: '+e['reason'] in d['notes'] for d in diags), diags
                if 'notes' in e:
                    assert diags[0]['notes'] == e['notes'], diags
                    assert [h['message'] for h in diags[0]['helps']] == e['helpMessages'], diags
            source = next(s for s in report['sources'] if s['sourceId'] == target['sourceId'])
            assert source['contentHash'] == dict(algorithm='sha256', value=case['sha256'])
        else:
            if 'stdout' in e:
                assert result.stdout == e['stdout'], result.stdout
            if e['outputKind'] == 'accepted':
                assert not result.stderr, result.stderr
            elif e['outputKind'] == 'usage':
                assert e['stderrContains'] in result.stderr, result.stderr
                assert 'E0512' not in result.stderr, result.stderr
            else:
                diagnostics = [json.loads(line) for line in result.stderr.splitlines()]
                assert any(d['code'] == e['code'] for d in diagnostics), diagnostics
        record['matched'] = True
    except (AssertionError, KeyError, StopIteration, ValueError) as error:
        record.update(matched=False, error=clean(str(error)))
    records.append(record)

# 索引・物理ファイル・許諾本文を独立に列挙して全論理名を照合する。
result, record = run('skill-list', ['skill', 'list', '--format=json'])
assert result.returncode == 0 and not result.stderr
listing = json.loads(result.stdout)
producer(listing['producer'])
save('skill-list.json', listing)
names = [d['name'] for d in listing['documents']]
bundle = (ROOT / 'crates/benitoite/src/cli/tools/skill/bundle.rs').read_text()
bundle_names = re.findall(r'path: "([^"]+)"', bundle)
physical = {str(p.relative_to(ROOT / 'crates/benitoite/skill'))
            for p in (ROOT / 'crates/benitoite/skill').rglob('*') if p.is_file()}
assert len(names) == len(set(names))
assert set(names) == set(bundle_names)
assert set(names) == physical | {'LICENSE-MIT', 'LICENSE-APACHE'}, (set(names)^physical)
record['matched'] = True
records.append(record)
skill_records = []
for index, name in enumerate(names):
    result, record = run('skill-'+str(index), ['skill', 'show', name, '--format=json'])
    assert result.returncode == 0 and not result.stderr
    doc = json.loads(result.stdout)
    producer(doc['producer'])
    path = ROOT / name if name.startswith('LICENSE-') else ROOT / 'crates/benitoite/skill' / name
    source = path.read_bytes()
    rendered = source.replace(b'{{benitoite-version}}', b'0.0.13') if name == 'SKILL.md' else source
    metadata = next(d for d in listing['documents'] if d['name'] == name)
    assert doc['name'] == name
    assert doc['text'].encode() == rendered, name
    assert doc['byteLength'] == metadata['byteLength'] == len(rendered), name
    assert doc['contentHash'] == metadata['contentHash'] == dict(algorithm='sha256', value=sha(rendered)), name
    if name == 'SKILL.md':
        assert 'benitoite-version: "0.0.13"' in doc['text']
        assert '{{benitoite-version}}' not in doc['text']
    record.update(matched=True, name=name)
    records.append(record)
    skill_records.append(dict(name=name, sourceSha256=sha(source), renderedSha256=sha(rendered),
                             bytes=len(rendered), matched=True))
save('skill-audit.json', dict(documents=len(names), missing=[], extra=[], records=skill_records))
summary = dict(finished=datetime.datetime.now().astimezone().isoformat(),
               expectationsSha256=sha(frozen), cliSha256=sha(CLI.read_bytes()),
               cliCases=len(expected['cases']), commands=len(records),
               successes=sum(r['matched'] for r in records),
               failures=[r for r in records if not r['matched']], records=records)
save('candidate-check.json', summary)
print(json.dumps({k: v for k, v in summary.items() if k != 'records'}, ensure_ascii=False))
raise SystemExit(1 if summary['failures'] else 0)
