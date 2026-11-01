"""群S後半の局所入力と最終検証。記録は相対パスだけを残す。"""
from pathlib import Path
import datetime, hashlib, json, re, subprocess, sys, time, tempfile
ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent

def run(label, args, cwd):
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    t = time.monotonic()
    proc = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - t
    seq = len(list(OUT.glob('run-*.json'))) + 1
    stem = f'run-{seq:03d}-{label}'
    proc.stdout = proc.stdout.replace(str(ROOT).encode(), b"<repo>").replace(str(Path.home()).encode(), b"<user>")
    digest = hashlib.sha256(proc.stdout).hexdigest()
    if len(proc.stdout) > 100_000:
        tmp = Path(tempfile.gettempdir()) / f'l10-s2-{digest}.log'
        tmp.write_bytes(proc.stdout)
        log = f'<tmp>/{tmp.name}'
        with (OUT/'large-records.md').open('a') as f:
            f.write(f'\n- `{log}`: {len(proc.stdout)} bytes、SHA-256 `{digest}`。\n')
    else:
        log = stem + '.txt'
        (OUT/log).write_bytes(proc.stdout)
    record = dict(label=label, command=args, cwd=str(cwd.relative_to(ROOT)), start_utc=start,
                  exit=proc.returncode, seconds=elapsed, bytes=len(proc.stdout), sha256=digest, log=log)
    body = proc.stdout.decode(errors='replace')
    axioms = set()
    for group in re.findall(r'depends on axioms: \[(.*?)\]', body, re.S):
        axioms.update(x.strip() for x in group.split(',') if x.strip())
    record.update(axioms=sorted(axioms), disallowed_axioms=sorted(axioms-{'propext','Quot.sound','Classical.choice'}),
                  print_axioms_count=len(re.findall(r"^'.*?' (?:does not depend on any axioms|depends on axioms:)",body,re.M)),
                  sorry=bool(re.search(r"declaration uses ['‘]sorry|\bsorryAx\b",body)), warnings=body.count('warning:'))
    if label == 'build':
        jobs = re.search(r'Build completed successfully \((\d+) jobs\)',body)
        record['jobs'] = int(jobs[1]) if jobs else None
    if label in ['signatures','boundary']:
        count = re.search(r'LOCAL_CONSTANTS (\d+)', body)
        record['constants'] = int(count[1]) if count else None
        record['complete'] = (record['constants'] == record['print_axioms_count'] and record['constants'] >= (106 if label == 'signatures' else 60))
    if label == 'axioms':
        record['modules'] = {m:int(n) for m,n in re.findall(r'AUDIT_MODULE (\S+) (\d+)',body)}
        record['cases'] = {m:int(n) for m,n in re.findall(r'CASE_TOTAL_(SINGLE|PAIR) (\d+)',body)}
        record['complete'] = (set(record['modules']) == set(json.loads((OUT/'audit-modules.json').read_text())) and sum(record['modules'].values())+18 == record['print_axioms_count'] and record['cases'] == {'SINGLE':26,'PAIR':450} and 'TYPING_TOTAL 76' in body and 'TYPING_JUDGMENTS 14' in body)
    if label == 'foundation':
        record['complete'] = 'FOUNDATION_CHECKED 115' in body
    if record['disallowed_axioms'] or record['sorry'] or record.get('complete') is False:
        record['verification_failure'] = True
    (OUT/(stem+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(record, ensure_ascii=False))
    if proc.returncode or record.get('verification_failure'):
        print(body[-18000:])
    return proc.returncode or int(record.get('verification_failure',False))

if __name__ == '__main__':
    label = sys.argv[1]
    args = sys.argv[2:]
    raise SystemExit(run(label, args, ROOT/'formal'))
