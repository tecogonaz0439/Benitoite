#!/usr/bin/env python3
"""有限支持・比較・正規化の既定ビルド、署名、実例、公理依存を照合する。"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / 'formal'
MODULES = ['TypeSupport', 'FiniteSupport', 'FiniteCompare', 'FiniteFunctionView', 'Finite']
ALLOWED = {'propext', 'Quot.sound', 'Classical.choice'}
BASE = '78aa5cca81cf24a420c266e6b714934297ce434e'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def protected():
    expected = json.loads((HERE/'protected-inputs.json').read_text())
    expected.update(json.loads((HERE/'review-inputs.json').read_text()))
    changed = [n for n,h in expected.items() if sha(ROOT/n) != h]
    if changed:
        raise SystemExit('PROTECTED_INPUT_CHANGED ' + repr(changed))
    return len(expected)

def inputs():
    paths = [FORMAL/'Benitoite.lean', FORMAL/'lakefile.toml']
    paths += [FORMAL/'Benitoite/Release/Refinement'/(n+'.lean') for n in MODULES]
    paths += [HERE/n for n in ['check.py','boundary.lean','signatures.md','signatures.lean','execution-path.lean','axioms.lean','protected-inputs.json','review-inputs.json','review-before.json']]
    paths += [ROOT/n for n in json.loads((HERE/'review-inputs.json').read_text())]
    paths += [ROOT/n for n in ['docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md','docs/design/00-overview/00-04-glossary.md']]
    return {str(p.relative_to(ROOT)):sha(p) for p in paths}

def run(label, command):
    dest = Path(tempfile.gettempdir())/('l10-s1-'+label+'.log')
    started = datetime.now(timezone.utc).isoformat()
    began = time.monotonic()
    with dest.open('w') as out:
        done = subprocess.run(command,cwd=FORMAL,stdout=out,stderr=subprocess.STDOUT)
    body = dest.read_text().replace(str(ROOT),'<repo>')
    dest.write_text(body)
    if dest.stat().st_size <= 100000:
        dest = HERE/(label+'-output.txt')
        dest.write_text(body)
        output = dest.name
    else:
        output = '<tmp>/'+dest.name
    axioms = set()
    for group in re.findall(r'depends on axioms: \[(.*?)\]',body,re.S):
        axioms.update(x.strip() for x in group.split(',') if x.strip())
    result = {'command':command,'cwd':'formal','started_utc':started,
              'seconds':round(time.monotonic()-began,3),'exit_code':done.returncode,
              'output':output,'bytes':dest.stat().st_size,'sha256':sha(dest),
              'axioms':sorted(axioms),'disallowed_axioms':sorted(axioms-ALLOWED),
              'print_axioms_count':len(re.findall(r"^'.*?' (?:does not depend on any axioms|depends on axioms:)",body,re.M)),
              'sorry_diagnostic':bool(re.search(r"declaration uses ['‘]sorry|\bsorryAx\b",body)),
              'warnings':len(re.findall(r'warning:',body))}
    if label == 'build':
        count = re.search(r'Build completed successfully \((\d+) jobs\)',body)
        result['jobs'] = int(count[1]) if count else None
    if label in ['boundary','signatures']:
        count = re.search(r'LOCAL_CONSTANTS (\d+)',body)
        result['constants'] = int(count[1]) if count else None
        result['complete'] = (result['constants'] == result['print_axioms_count'] and result['constants'] >= (105 if label == 'signatures' else 26))
    if label == 'axioms':
        result['modules'] = {m:int(n) for m,n in re.findall(r'AUDIT_MODULE (\S+) (\d+)',body)}
        result['cases'] = {label:int(n) for label,n in re.findall(r'CASE_TOTAL_(SINGLE|PAIR) (\d+)',body)}
        result['complete'] = (len(result['modules']) == 5 and sum(result['modules'].values())+18 == result['print_axioms_count'] and result['cases'] == {'SINGLE':26, 'PAIR':450})
    if label == 'execution-path':
        result['roots'] = {m:int(n) for m,n in re.findall(r'EXEC_OK (\S+) (\d+)',body)}
        result['complete'] = len(result['roots']) == 11
    (HERE/(label+'-result.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(label,'exit',done.returncode,'seconds',result['seconds'],'axioms',result['print_axioms_count'],flush=True)
    if done.returncode or result['disallowed_axioms'] or result['sorry_diagnostic'] or result.get('complete') is False:
        print(body[-5000:])
        raise SystemExit('CHECK_FAILED '+label)
    return result

def main():
    began = time.monotonic()
    result = {'started_utc':datetime.now(timezone.utc).isoformat(),'base':BASE,'branch':'m014/l10.s1',
              'rss':'未取得（計画上の非採取）','protected_count':protected()}
    before = inputs()
    if 'moreLeanArgs = ["-M", "12288"]' not in (FORMAL/'lakefile.toml').read_text():
        raise SystemExit('BAD_MEMORY_LIMIT')
    result['build'] = run('build',['lake','build'])
    relative = '../'+str(HERE.relative_to(ROOT))+'/'
    for label in ['signatures','boundary','execution-path','axioms']:
        result[label] = run(label,['lake','env','lean','-M','12288',relative+label+'.lean'])
    if before != inputs():
        raise SystemExit('VERIFIED_INPUT_CHANGED')
    protected()
    result['inputs'] = before
    result['seconds'] = round(time.monotonic()-began,3)
    result['ended_utc'] = datetime.now(timezone.utc).isoformat()
    (HERE/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    large = '# 大きな生の記録\n\n100,000 bytes を超える出力は一時領域に置く。手元の絶対パスは記録しない。\n\n| 記録 | bytes | SHA-256 |\n|---|---:|---|\n'
    found = False
    for label in ['build','signatures','boundary','execution-path','axioms']:
        r = result[label]
        if r['output'].startswith('<tmp>/'):
            found = True
            large += f'| `{r["output"]}` | {r["bytes"]} | `{r["sha256"]}` |\n'
    if not found:
        large += '\n最終の生の記録はすべて100,000 bytes以下である。\n'
    (HERE/'large-records.md').write_text(large)
    print('VERIFIED',result['seconds'],'protected',result['protected_count'],flush=True)

if __name__ == '__main__':
    main()
