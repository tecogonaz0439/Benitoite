"""既存シェル4入口を保った最終読者の追加4群を、実交換で確かめる。"""
import json
from pathlib import Path
import runpy
import shutil


def require(ok, message):
    if not ok:
        raise AssertionError(message)

root=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
output=here/'final-batch3-reader'
for profile in ('k3','k4','m1','t3'):
    shutil.copytree(here/'readers-batch3-inputs'/profile,output/'batch3'/profile,dirs_exist_ok=True)
    archived=root/'target/k10.2-raw/readers-batch3-inputs'/profile
    if archived.exists():
        shutil.copytree(archived,output/'batch3'/profile,dirs_exist_ok=True)
shared=runpy.run_path(str(root/'crates/benitoite/tests/desugar_export/check_named.py'))
shared['check_remaining_batch3'](output)
reports={name:json.loads((output/'batch3'/f'{name}-exchange-results.json').read_text()) for name in ('k3','k4','m1','t3')}
require([r['definitions'] for r in reports.values()]==[5,7,31,9], 'check-final-batch3.py:14: requirement failed')
require(all(set(r['results'])=={'coverageDiff','coverageProgramDiff','desugarDiff','builtinCheck','surfaceCheck','surfaceCheckAll'} for r in reports.values()), 'check-final-batch3.py:15: requirement failed')
(output/'summary.json').write_text(json.dumps({'status':'passed','definitions':{p:r['definitions'] for p,r in reports.items()},'sixEntries':list(next(iter(reports.values()))['results'])},indent=2)+'\n')
