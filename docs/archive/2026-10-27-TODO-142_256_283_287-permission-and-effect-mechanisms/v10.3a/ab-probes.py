"""保存済みのレビュー入力を公開版と候補版の実 CLI で照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PROBES = OUT / 'rv-probes'
VARIANTS = PROBES / 'ab-inputs'
VARIANTS.mkdir(exist_ok=True)


def clean(text):
    return text.replace(str(ROOT), '<wt>').replace(str(Path.home()), '<home>')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


clis = [('0.0.12', ROOT / 'target/v10.2b/benitoite-0012'),
        ('0.0.13', ROOT / 'target/debug/benitoite')]
inputs = sorted(PROBES.glob('*.bnt'))
for name in ['file-old-complete', 'write-old-complete', 'send-plain']:
    source = (PROBES / (name + '.bnt')).read_text()
    source = re.sub(r'^language "[^"]+"\n', '', source)
    for version in [None, '0.0.12']:
        path = VARIANTS / (name + ('-0012' if version else '-none') + '.bnt')
        path.write_text((('language "' + version + '"\n') if version else '') + source)
        inputs.append(path)

records = []
identities = []
for version, cli in clis:
    identity = subprocess.run([str(cli), '--version=json'], cwd=ROOT,
                              text=True, capture_output=True)
    assert identity.returncode == 0, identity.stderr
    identities.append(dict(version=version, path=str(cli.relative_to(ROOT)),
                           sha256=sha(cli), output=json.loads(identity.stdout)))
    for path in inputs:
        args = [str(cli), 'check', '--diagnostics=json', str(path.relative_to(ROOT))]
        start = time.monotonic()
        result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
        diagnostics = [json.loads(line) for line in result.stderr.splitlines()
                       if line.startswith('{')]
        records.append(dict(version=version, input=str(path.relative_to(ROOT)),
                            inputSha256=sha(path), command=[clean(x) for x in args],
                            exit=result.returncode, wallSeconds=time.monotonic()-start,
                            stdout=clean(result.stdout), stderr=clean(result.stderr),
                            codes=[d['code'] for d in diagnostics],
                            diagnostics=diagnostics))
    args = [str(cli), 'run', '--allow-effects=Console.Write',
            str((PROBES / 'ip.bnt').relative_to(ROOT))]
    start = time.monotonic()
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    records.append(dict(version=version, input=str((PROBES / 'ip.bnt').relative_to(ROOT)),
                        inputSha256=sha(PROBES / 'ip.bnt'), command=[clean(x) for x in args],
                        exit=result.returncode, wallSeconds=time.monotonic()-start,
                        stdout=clean(result.stdout), stderr=clean(result.stderr)))

tag = subprocess.check_output(['git', 'rev-parse', 'v0.0.12^{commit}'], cwd=ROOT).decode().strip()
assert identities[0]['output']['version'] == '0.0.12'
assert identities[1]['output']['version'] == '0.0.13'
for row in records:
    if '/ab-inputs/' in row['input']:
        if row['version'] == '0.0.12':
            assert row['exit'] == 0, row
        elif '-none.bnt' in row['input']:
            assert row['codes'] == ['E0501'], row
        else:
            assert row['codes'] == ['E0908'], row
            diag = row['diagnostics'][0]
            expected = json.loads((ROOT / 'crates/benitoite/testdata/packages/older-language.diag.json').read_text())
            assert diag['notes'] == expected['notes'][-1:]
            assert diag['helps'] == expected['helps'][-1:]
    if row['command'][1] == 'run':
        assert row['exit'] == 0, row
        if row['version'] == '0.0.13':
            assert row['stdout'] == 'ok\nInvalidPattern("**", "expected a host, *.host, **.host, canonical IP address, or CIDR")\n', row
        else:
            assert 'expected a host, *.host, or **.host' in row['stdout'], row

report = dict(finished=datetime.now(timezone.utc).isoformat(),
              identities=identities, publicTagCommit=tag, records=records,
              publicTagCommitVerified=identities[0]['output']['build']['commit'] == tag,
              provenanceLimitation='指定の旧 CLI の build.commit は null であり、公開タグとの一致は再確認できない',
              checks='old complete handlers pass 0.0.12, leave E0501 without declaration on 0.0.13, and show the new E0908 note/help with 0.0.12 declaration; IP behavior differs as reviewed')
(OUT / 'ab-cli-evidence.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
for row in records:
    print(row['version'], Path(row['input']).name, row['command'][1],
          row['exit'], row.get('codes', row['stdout'].strip()))
