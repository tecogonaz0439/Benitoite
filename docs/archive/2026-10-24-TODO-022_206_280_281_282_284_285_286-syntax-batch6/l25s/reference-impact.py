"""保存済みの三表を変えず、新しいLeanによる影響を各入力一度だけ求める。"""
from pathlib import Path
import collections
import hashlib
import importlib.util
import json
import tempfile
import time
import run
import fcntl
lock = open(Path(tempfile.gettempdir()) / "benitoite-l20d-lean.lock", "a")
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

OUT, ROOT = run.OUT, run.ROOT
DIRECTORY = ROOT / 'crates/benitoite/testdata/interval-budget'
spec = importlib.util.spec_from_file_location('reference', DIRECTORY / 'regenerate-reference.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
LOG = OUT / 'reference-output'
LOG.mkdir(exist_ok=True)
EXPORT = OUT.parent / 'a18a/resume-reference-output'
declarations = module.range_declarations(EXPORT, LOG)

def rows(filename, width, log_dir, declarations):
    source = (DIRECTORY / filename).read_text().replace(
        '-- RANGE_EXCHANGE: regenerate-reference.py が実交換から宣言をここへ渡す。', declarations)
    # StandardBindingの新しい固定長の型欄を明示するだけで、入力式・費用・期待値は変えない。
    source = source.replace('⟨referenceRangeCheck, .rangeCheck referenceRangeNames⟩',
                            '⟨referenceRangeCheck, .rangeCheck referenceRangeNames, []⟩')
    source = source.replace('⟨referenceRangeValue, .rangeValue referenceRangeNames.record⟩',
                            '⟨referenceRangeValue, .rangeValue referenceRangeNames.record, []⟩')
    with tempfile.NamedTemporaryFile(mode='w', suffix='.lean', delete=False) as stream:
        stream.write(source)
        path = Path(stream.name)
    command = ['lake', 'env', 'lean', '-M', '6144', str(path)]
    start = time.monotonic()
    try:
        result = run.control.run(command, cwd=ROOT/'formal', timeout=300)
    finally:
        path.unlink()
    (LOG / (filename+'.log')).write_text(run.redact(result.stdout))
    info = dict(command=[run.redact(x) for x in command], exit=result.returncode,
                seconds=round(time.monotonic()-start,3), timeout_seconds=300)
    (LOG / (filename+'.json')).write_text(json.dumps(info,indent=2)+'\n')
    print(json.dumps(info), flush=True)
    if result.returncode:
        raise RuntimeError(run.redact(result.stdout[-5000:]))
    return [line.split('\t') for line in result.stdout.splitlines()
            if len(line.split('\t')) in width and line.split('\t')[1].isdigit()]

module.lean_rows = rows
before = {name: (DIRECTORY / (name+'.tsv')).read_bytes() for name in ('body','whole','summary')}
tables = module.generate(LOG, declarations)
columns = {
 'body':'name kind cap operations saved peak next stop warnings independent unsupported'.split(),
 'whole':'name kind cap operations saved peak bodies warnings phases discovered pending remaining stop modules'.split(),
 'summary':'name kind cap inputDefinitions unsupportedBodies bodyBudgetExceeded wholeBudgetSkipped unidentifiedBodies phaseStops'.split()}
summary = {}
for name, rows in tables.items():
    oldrows = [line.split('\t') for line in before[name].decode().splitlines() if not line.startswith('#')]
    old, new = ({tuple(row[:3]):row for row in rs} for rs in [oldrows,rows])
    details = collections.defaultdict(lambda:dict(changed=0,removed=0,added=0,columns=set()))
    for key in old.keys() | new.keys():
        shape = details[key[0]]
        if key not in old: shape['added'] += 1
        elif key not in new: shape['removed'] += 1
        elif old[key] != new[key]:
            shape['changed'] += 1
            shape['columns'].update(column for column,left,right in zip(columns[name],old[key],new[key]) if left!=right)
    details = {shape:value for shape,value in sorted(details.items())
               if value['changed'] or value['removed'] or value['added']}
    for shape, value in details.items():
        value['columns'] = [c for c in columns[name] if c in value['columns']]
        if name=='body':
            value['old_success_caps'] = [next(int(r[2]) for r in oldrows if r[0]==shape and r[1]==str(k) and r[7]=='0') for k in range(4)]
            value['new_success_caps'] = [next(int(r[2]) for r in rows if r[0]==shape and r[1]==str(k) and r[7]=='0') for k in range(4)]
    assert (DIRECTORY/(name+'.tsv')).read_bytes()==before[name]
    summary[name]=dict(old_rows=len(oldrows),new_rows=len(rows),shapes=details,
                       saved_sha256=hashlib.sha256(before[name]).hexdigest())
    (LOG/(name+'-new.tsv')).write_text('\n'.join('\t'.join(row) for row in rows)+'\n')
(OUT/'reference-impact.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:{a:b for a,b in v.items() if a!='shapes'} for k,v in summary.items()},ensure_ascii=False),flush=True)
