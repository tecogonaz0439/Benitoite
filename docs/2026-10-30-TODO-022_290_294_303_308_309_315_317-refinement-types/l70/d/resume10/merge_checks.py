"""群 K2 との結合 e9f7522a の後の追随について、既定ビルド・変えたモジュールの公理監査・照合を行う。
生の出力は指定した一時領域に置く。結合の版の本文は読み取り専用の git show で得る。"""
import argparse
import collections
import hashlib
import json
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / 'merge'
ROOT = HERE.parents[4]
MERGE = 'e9f7522a'
CHANGED = [
    'Benitoite.Release.Refinement.Surface.CheckInfer',
    'Benitoite.Release.Refinement.Surface.CheckOpenInfer',
    'Benitoite.Release.Refinement.Surface.FieldCheckerExamples',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples',
    'Benitoite.Release.Refinement.Surface.PredicateGeneratedNames',
    'Benitoite.Release.Refinement.Surface.PredicateProjectionFixture',
    'Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativePath',
    'Benitoite.Release.Refinement.Surface.PredicateSimulationProgram',
    'Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs',
    'Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples',
]
REQUIRED = [
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.string_accessor_checked',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.float_accessor_checked',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.decimal_accessor_checked',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.data_accessor_checked',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.unproved_contract_rejected',
    'Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples.unproved_argument_rejected',
    'Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples.text_branches',
    'Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples.nested_float_branches',
    'Benitoite.Release.Refinement.Surface.PredicateProjectionFixture.formed',
    'Benitoite.Release.Refinement.Surface.PredicateGeneratedNames.accessor_names',
    'Benitoite.Release.Refinement.Surface.PredicateProgramSemantics.observations_preserved',
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1) + '\n')


def sources():
    files = [p for p in (ROOT / 'formal').rglob('*')
             if p.is_file() and not set(p.parts) & {'.lake', '__pycache__'}]
    files += [ROOT / 'docs/design/01-spec/01-12-core-calculus.md',
              ROOT / 'docs/design/07-quality/07-04-formal-semantics.md']
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(files)}


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def reachable():
    seen, pending = set(), ['Benitoite']
    while pending:
        module = pending.pop()
        if module in seen:
            continue
        seen.add(module)
        path = ROOT / 'formal' / (module.replace('.', '/') + '.lean')
        pending += re.findall(r'^import (Benitoite(?:\.\w+)*)$', path.read_text(), re.M)
    return seen


def audit_input(tmp):
    OUT.mkdir(exist_ok=True)
    save(OUT / 'audit-modules.json', sorted(CHANGED))
    save(OUT / 'required-names.json', sorted(REQUIRED))
    tail = (HERE.parent / 'resume9/axioms.lean').read_text()
    tail = tail[tail.index('open Lean Elab Command in'):]
    tail = tail.replace('l70/d/resume9/', 'l70/d/resume10/merge/')
    tail = tail.replace('| none => false', '| none => true')
    old_pending = 'if selected && !seen.contains name then some name else none'
    assert old_pending in tail
    tail = tail.replace(old_pending, 'if selected && !seen.contains name && !name.hasMacroScopes then some name else none')
    old_lookup = '''      let env ← getEnv
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"'''
    assert tail.count(old_lookup) == 1
    tail = tail.replace(old_lookup, '''      let env ← getEnv
      let some ci := env.find? name | do
        seen := seen.insert name
        logInfo m!"AUDIT_UNRESOLVED {name}"
        continue
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"''')
    (tmp / 'merge-audit.lean').write_text('import Lean\nimport Benitoite\n\n' + tail)


def run(kind, tmp, lock):
    OUT.mkdir(exist_ok=True)
    if kind == 'build':
        command = ['lake', 'build']
    else:
        audit_input(tmp)
        command = ['lake', 'env', 'lean', '-M', '12288', str(tmp / 'merge-audit.lean')]
    before = sources()
    log = tmp / ('merge-' + kind + '.log')
    start = datetime.now().astimezone().isoformat()
    t0 = time.monotonic()
    with log.open('w') as out:
        result = subprocess.run(['/usr/bin/lockf', '-t', '3600', str(lock)] + command,
                                cwd=ROOT / 'formal', stdout=out, stderr=subprocess.STDOUT)
    after = sources()
    record = dict(merge=MERGE, command=[str(c).replace(str(tmp), '<tmp>') for c in command],
                  lock='共有ロック（依頼指定）', start=start, end=datetime.now().astimezone().isoformat(),
                  seconds=time.monotonic() - t0, exit_code=result.returncode, bytes=log.stat().st_size,
                  sha256=digest(log), inputs=len(before), fingerprint=fingerprint(before),
                  after_fingerprint=fingerprint(after), same_inputs=before == after)
    save(OUT / (kind + '-summary.json'), record)
    print(json.dumps(record, ensure_ascii=False, indent=1))
    assert before == after, '検査中の入力の変更'
    return result.returncode


def merged_text(path):
    result = subprocess.run(['git', 'show', MERGE + ':' + path], cwd=ROOT, capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else None


def verify(tmp):
    current = sources()
    assert set(CHANGED) <= reachable(), '変えたモジュールの既定importが不足'
    helpers = {'__file__': str(HERE.parent / 'verify.py')}
    exec((HERE.parent / 'verify.py').read_text().split('parser = argparse.ArgumentParser')[0], helpers)
    statements = {}
    for module in CHANGED:
        path = 'formal/' + module.replace('.', '/') + '.lean'
        before = merged_text(path)
        after = helpers['signature_hashes']((ROOT / path).read_text())
        old = helpers['signature_hashes'](before) if before is not None else {}
        statements[module] = dict(
            new_module=before is None,
            added=sorted(set(after) - set(old)), removed=sorted(set(old) - set(after)),
            changed=sorted(n for n in set(old) & set(after) if old[n] != after[n]))
    for kind in ['build', 'axioms']:
        record = json.loads((OUT / (kind + '-summary.json')).read_text())
        log = tmp / ('merge-' + kind + '.log')
        assert record['exit_code'] == 0 and record['same_inputs'], (kind, record)
        assert record['bytes'] == log.stat().st_size and record['sha256'] == digest(log)
        assert record['fingerprint'] == record['after_fingerprint'] == fingerprint(current)
    assert 'error:' not in (tmp / 'merge-build.log').read_text()
    audit = (tmp / 'merge-axioms.log').read_text()
    assert not re.search(r'error:|sorryAx|AUDIT_(?:MISSING|AXIOM|REQUIRED_MISSING|FIXED_POINT_LIMIT)', audit)
    targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
    assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', audit, re.M)[1])
    axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
    assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
    sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip())) for _, a in axioms)
    assert all(set(s) <= {'propext', 'Classical.choice', 'Quot.sound'} for s in sets)
    records = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', audit, re.M)
    owned = [dict(module=m, kind=k, line=int(line), name=n) for m, k, line, n in records if m in CHANGED]
    counts = {m: int(n) for m, n in re.findall(r'^OWN_MODULE (\S+) (\d+)$', audit, re.M)}
    assert sorted(counts) == sorted(CHANGED)
    for module, count in counts.items():
        assert sum(r['module'] == module for r in owned) == count
    owned_names = {r['name'] for r in owned}
    owned_axioms = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip()))
                                       for n, a in axioms if n in owned_names)
    assert set(REQUIRED) <= set(targets)
    save(tmp / 'merge-declarations.json', owned)
    result = dict(merge=MERGE, modules=len(CHANGED), per_module=counts, declarations=len(targets),
                  owned_declarations=len(owned),
                  unresolved=len(re.findall(r'AUDIT_UNRESOLVED', audit)),
                  owned_axiom_sets={','.join(k) or '(none)': v for k, v in sorted(owned_axioms.items())},
                  statements=statements, declarations_sha256=digest(tmp / 'merge-declarations.json'),
                  fingerprint=fingerprint(current))
    save(OUT / 'verification.json', result)
    print(json.dumps({k: v for k, v in result.items() if k != 'statements'}, ensure_ascii=False, indent=1))
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['build', 'axioms', 'verify'])
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--lock', type=Path)
    args = parser.parse_args()
    args.tmp.mkdir(exist_ok=True, parents=True)
    if args.kind == 'verify':
        raise SystemExit(verify(args.tmp))
    raise SystemExit(run(args.kind, args.tmp, args.lock))
