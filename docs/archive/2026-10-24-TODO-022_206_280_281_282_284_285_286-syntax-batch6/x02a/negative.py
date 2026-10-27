"""正しい実ソース出力を一箇所ずつ変え、manifest の受け入れを検査する。"""
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASE = Path('target/x02a-identity')
WORK = Path('target/x02a-negative')
SCRIPT = Path('crates/benitoite/tests/desugar_export/interval/check-manifest.py')
records = []

for name, reason in [('all-top', 'allTop source observations'),
                     ('missing-body', 'missing body without stop'),
                     ('incomplete', 'source enumeration incomplete'),
                     ('body-order', 'source body manifest order')]:
    directory = ROOT/WORK/name
    directory.mkdir(parents=True, exist_ok=True)
    for filename in ['interval-manifest.json', 'interval-material.json', 'interval-observations.json', 'interval-manifest-corpus.json']:
        shutil.copyfile(ROOT/BASE/filename, directory/filename)
    manifest = json.loads((directory/'interval-manifest.json').read_text())
    if name == 'all-top':
        manifest['inputs'] = [row for row in manifest['inputs'] if row['counts']['informativeBodies'] == '0']
        assert manifest['inputs']
    elif name == 'incomplete':
        manifest['inputs'][0]['enumerationComplete'] = False
    elif name == 'body-order':
        row = next(row for row in manifest['inputs'] if len(row['manifest']) > 1)
        row['manifest'].reverse()
    else:
        row = next(row for row in manifest['inputs'] if row['name'] == 'point')
        body = row['bodies'][0]
        body.update(analyzed=False, valueAvailable=False, top=None, bottom=None, informative=None)
        row['counts'].update(analyzedBodies='0', notAnalyzedBodies='1')
        row['counts'].update(topBodies='0', bottomBodies='0', informativeBodies='0')
        observed = json.loads((directory/'interval-observations.json').read_text())
        entry = next(entry for entry in observed['inputs'] if entry['name'] == row['input'])
        entry['bodies'] = [body for body in entry['bodies'] if body['definition'] != row['manifest'][0]]
        (directory/'interval-observations.json').write_text(json.dumps(observed))
    (directory/'interval-manifest.json').write_text(json.dumps(manifest))
    command = [sys.executable, '-B', str(SCRIPT), '--source-dir', str(WORK/name),
               '--independent-dir', 'target/x02a-exchange', '--output', str(WORK/name/'check')]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    output = (result.stdout+result.stderr).replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')
    (HERE/(name+'.log')).write_text(output)
    assert result.returncode == 1 and reason in output, (name, result.returncode, output)
    records.append(dict(case=name, exit=result.returncode, reason=reason))
(HERE/'negative.json').write_text(json.dumps(records, indent=2)+'\n')
print(json.dumps(records))
