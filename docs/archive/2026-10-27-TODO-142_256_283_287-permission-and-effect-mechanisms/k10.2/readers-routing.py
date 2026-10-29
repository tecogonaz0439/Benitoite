"""全corpusのroutingを固定manifestと照合する（Leanの全比較は起動しない）。"""
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
CHECK = runpy.run_path(str(ROOT / 'crates/benitoite/tests/desugar_export/check_named.py'))
MANIFEST = CHECK['read'](CHECK['MANIFEST'])
DIRECTORY = ROOT / 'target/k10.2-readers-routing'
CHECK['check_routing'](DIRECTORY, MANIFEST)
EXPECTED = CHECK['read'](CHECK['MANIFEST'].parent / MANIFEST['routingManifest'])
RESULT = {'status': 'passed', 'inputs': len(EXPECTED),
          'golden': sum(i['group'] == 'golden' for i in EXPECTED),
          'random': sum(i['group'] == 'random' for i in EXPECTED),
          'expectedManifestSha256': hashlib.sha256((CHECK['MANIFEST'].parent / MANIFEST['routingManifest']).read_bytes()).hexdigest(),
          'scope': 'check_routing compared every actual identifier, exclusion, scope classification and coverage entry with this fixed expected manifest'}
(HERE / 'readers-routing-agreement.json').write_text(json.dumps(RESULT, indent=2) + '\n')
