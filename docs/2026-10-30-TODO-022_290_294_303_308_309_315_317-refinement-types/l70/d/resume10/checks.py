"""既定ビルド・全宣言の監査・記録の照合。生の出力は指定した一時領域に置く。"""
import argparse
import collections
import hashlib
import json
import re
import runpy
import subprocess
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
B_WORK = '1395ebfb01be54bc53299c610c70477c1231898c'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1) + '\n')


def sources():
    files = [p for p in (ROOT / 'formal').rglob('*')
             if p.is_file() and not set(p.parts) & {'.lake', '__pycache__'}]
    files += [ROOT / 'docs/design/01-spec/01-12-core-calculus.md',
              ROOT / 'docs/design/07-quality/07-04-formal-semantics.md',
              *HERE.glob('*.lean')]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(files)}


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def reachable():
    seen = set()
    pending = ['Benitoite']
    while pending:
        module = pending.pop()
        if module in seen:
            continue
        seen.add(module)
        path = ROOT / 'formal' / (module.replace('.', '/') + '.lean')
        pending += re.findall(r'^import (Benitoite(?:\.\w+)*)$', path.read_text(), re.M)
    return seen


def owned_modules(tmp):
    previous = json.loads((HERE.parent / 'resume9/audit-modules.json').read_text())
    surface = ROOT / 'formal/Benitoite/Release/Refinement/Surface'
    added = {str(p.relative_to(ROOT))[7:-5].replace('/', '.') for p in surface.glob('*.lean')
             if p.stem.startswith(('PredicateSimulation', 'PredicateOverlay')) or p.stem in {
                 'PredicatePublicDeltas', 'PredicateGeneratedNames', 'PredicateMainExamples',
                 'PredicateProgramGuarantees', 'PredicateProgramObservations'}}
    # 再開8・9の和集合に、今回追随した群Eの後半のモジュールを加える。
    return sorted(set(previous) | added | {
        'Benitoite.Release.Refinement.SurfaceLibrary',
        'Benitoite.Release.Refinement.SurfaceMainExamples',
        'Benitoite.Release.Refinement.SurfaceCheckedMainExamples',
        'Benitoite.Release.Refinement.Surface.PredicateOverlayValues',
        'Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees',
    })


def statements(tmp):
    """前回の最終台帳をその記録のハッシュで照合し、短名の重複も保持する。"""
    prior = json.loads((HERE.parent / 'resume9/inventory-summary.json').read_text())
    old_path = tmp / 'resume9-signatures.json'
    original = tmp / 'resume8-signatures.json'
    assert digest(old_path) == prior['current_signature_sha256']
    assert digest(original) == prior['baseline']['baseline-signatures.json']['sha256']
    old = json.loads(old_path.read_text())
    earlier = json.loads(original.read_text())
    previously_added = set(json.loads((HERE.parent / 'resume8/inventory-summary.json').read_text())['added'])
    extract = runpy.run_path(str(HERE.parent / 'resume9/inventory.py'))
    simple = extract['EXTRACT']['signature_hashes']
    detailed = extract['new_signatures']
    prefix = ROOT / 'formal/Benitoite/Release/Refinement/Surface'
    current = {str(p.relative_to(ROOT)):
               (simple(p.read_text()) if str(p.relative_to(ROOT)) in earlier and
                str(p.relative_to(ROOT)) not in previously_added else detailed(p.read_text()))
               for p in prefix.glob('*.lean')}
    # 同名の宣言の行番号は記録上の識別子であり、コメントの伸縮で別宣言とはしない。
    def grouped(rows):
        result = collections.defaultdict(collections.Counter)
        for name, header in rows.items():
            result[name.split('@')[0]][header] += 1
        return result
    changes = {}
    removed = {}
    added = {}
    for path in old.keys() | current.keys():
        before, after = grouped(old.get(path, {})), grouped(current.get(path, {}))
        for name in before.keys() | after.keys():
            if before[name] == after[name]:
                continue
            if before[name] and after[name]:
                changes.setdefault(path, {})[name] = dict(before=dict(before[name]), after=dict(after[name]))
            elif before[name]:
                removed.setdefault(path, {})[name] = dict(before[name])
            else:
                added.setdefault(path, {})[name] = dict(after[name])
    origin = 'formal/Benitoite/Release/Refinement/Surface/PredicateProgramSemantics.lean'
    destination = 'formal/Benitoite/Release/Refinement/Surface/PredicatePublicDeltas.lean'
    moved = {}
    for name in ['public_deltas']:
        assert removed[origin][name] == added[destination][name]
        moved[name] = dict(before=origin, after=destination, headers=removed[origin].pop(name))
        del added[destination][name]
    # 名前解決の前の実行の定義と観測の同値は、模倣を読む新しいモジュールへ移し、結合した核の言明へ改めた。
    observations = 'formal/Benitoite/Release/Refinement/Surface/PredicateProgramObservations.lean'
    for name in ['execution', 'infinite', 'observations_preserved']:
        if name not in removed.get(origin, {}):
            continue
        before = removed[origin].pop(name)
        after = added[observations].pop(name)
        moved[name] = dict(before=origin, after=observations, before_headers=before, after_headers=after,
                           changed=before != after)
    removed = {p:r for p,r in removed.items() if r}
    added = {p:r for p,r in added.items() if r}
    assert not removed, ('今回の既存言明の削除', removed)
    save(HERE / 'statement-differences.json', changes)
    save(HERE / 'statement-moves.json', moved)
    save(tmp / 'statement-additions.json', added)
    return dict(before=sum(map(len,old.values())), after=sum(map(len,current.values())),
                changed=sum(map(len,changes.values())), moved=len(moved), removed=0,
                added=sum(sum(sum(counts.values()) for counts in rows.values()) for rows in added.values()),
                baseline_bytes=old_path.stat().st_size, baseline_sha256=digest(old_path),
                additions_bytes=(tmp/'statement-additions.json').stat().st_size,
                additions_sha256=digest(tmp/'statement-additions.json'))


def audit_input(tmp):
    owned = owned_modules(tmp)
    save(HERE / 'audit-modules.json', owned)
    # 生成名を文字列から再構成せず、環境にある Name をそのまま印字する。
    source = ''
    for fixture in sorted(HERE.glob('*.lean')):
        body = fixture.read_text()
        body = re.sub(r'^import .*\n', '', body, flags=re.M)
        body = re.sub(r'^#print axioms .*\n', '', body, flags=re.M)
        source += body + '\n'
    tail = (HERE.parent / 'resume9/axioms.lean').read_text()
    tail = tail[tail.index('open Lean Elab Command in'):]
    tail = tail.replace('l70/d/resume9/', 'l70/d/resume10/')
    tail = tail.replace('| none => false', '| none => true')
    tail = tail.replace('if owned.contains module then', 'if owned.contains module || module == "local_records" then')
    # #print axioms が途中で実現する、マクロのスコープを持つ照合の補助名は宣言の一覧に数えない。
    old_pending = 'if selected && !seen.contains name then some name else none'
    assert old_pending in tail
    tail = tail.replace(old_pending, 'if selected && !seen.contains name && !name.hasMacroScopes then some name else none')
    # 監査の実行中に実現され、まだ lookup できない補助名は、対象に数えずに名前を記録する。
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
    (tmp / 'audit.lean').write_text('import Lean\nimport Benitoite\n' + source + '\n' + tail)
    required = json.loads((HERE.parent / 'resume9/required-names.json').read_text())
    required += [
        'Benitoite.Release.Refinement.Surface.checkProgramAccepted_main',
        'Benitoite.Release.Refinement.Surface.CheckedMainExamples.main_guarantees',
        'Benitoite.Release.Refinement.Surface.PredicateOverlayValues.standard_values',
        'Benitoite.Release.Refinement.Surface.PredicateOverlayValues.prepared_standard_values',
        'Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees.accepted_standard_property1',
        'Benitoite.Release.Refinement.Surface.CheckPredicateProgramExamples.path_property1',
        'Benitoite.Release.Refinement.Surface.OpenScopeAccept.contextsBlock_length',
        'Benitoite.Release.Refinement.Surface.OpenScopeAccept.occurrences_zip_contexts_length',
        'Benitoite.Release.Refinement.Surface.OpenScopeAccept.acceptBody_no_ranges_of_closed',
        'Benitoite.Release.Refinement.Surface.CheckAccept.acceptDef_no_ranges_of_closed',
        'Benitoite.Release.Refinement.Surface.CheckAccept.Accepted.of_no_ranges',
        'Benitoite.Release.Refinement.Surface.CheckAccept.accepted_no_ranges_of_closed',
        'Benitoite.Release.Refinement.Surface.OpenScopeForwardExamples.closed_extension',
        'Benitoite.Release.Refinement.Surface.OpenScopeForwardExamples.closed_conservative',
        'Benitoite.Release.Refinement.PredicateResolutionBoundary.actual_exact_observation_boundary',
        'Benitoite.Release.Refinement.Surface.PredicateProgramSemantics.observations_preserved',
        'Benitoite.Release.Refinement.Surface.PredicateMainExamples.main_observations',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.Setting.forward',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.Setting.backward',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.StateRel.forward',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.StateRel.backward',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.source_expr',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.source_block',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.resolved_program_rel',
        'Benitoite.Release.Refinement.Surface.PredicateSimulation.ResolvedSafe.of_checked',
    ]
    save(HERE / 'required-names.json', sorted(set(required)))


def run(kind, tmp, lock):
    if kind in {'build', 'checkpoint'}:
        command = ['lake', 'build']
    else:
        audit_input(tmp)
        command = ['lake', 'env', 'lean', '-M', '12288', str(tmp / 'audit.lean')]
    before = sources()
    invocation = ['/usr/bin/lockf', '-t', '3600', str(lock)] + command
    log = tmp / (kind + '.log')
    start = datetime.now().astimezone().isoformat()
    t0 = time.monotonic()
    with log.open('w') as out:
        result = subprocess.run(invocation, cwd=ROOT / 'formal', stdout=out, stderr=subprocess.STDOUT)
    after = sources()
    record = dict(b_work=B_WORK, command=[str(c).replace(str(tmp), '<tmp>') for c in command],
                  lock='共有ロック（依頼指定）', start=start,
                  end=datetime.now().astimezone().isoformat(), seconds=time.monotonic()-t0,
                  exit_code=result.returncode, bytes=log.stat().st_size, sha256=digest(log),
                  inputs=len(before), fingerprint=fingerprint(before),
                  after_fingerprint=fingerprint(after), same_inputs=before == after)
    save(HERE / (kind + '-summary.json'), record)
    save(tmp / (kind + '-sources.json'), before)
    print(json.dumps(record, ensure_ascii=False, indent=1))
    assert before == after, '検査中の入力の変更'
    return result.returncode


def verify(tmp):
    owned = owned_modules(tmp)
    assert json.loads((HERE / 'audit-modules.json').read_text()) == owned
    assert set(owned) <= reachable(), '対象モジュールの既定importが不足'
    initial = json.loads((tmp / 'initial-files.json').read_text())
    current = sources()
    added = sorted(p for p in current if p.startswith('formal/') and p not in initial)
    assert all(p.endswith('.lean') and p[7:-5].replace('/', '.') in reachable() for p in added)
    permitted = {
        'formal/Benitoite.lean',
        'formal/Benitoite/Release/Refinement/SurfaceLibrary.lean',
        'formal/Benitoite/Release/Refinement/SurfaceMainExamples.lean',
        'formal/Benitoite/Release/Refinement/SurfaceCheckedMainExamples.lean',
        'formal/Benitoite/Release/Refinement/Surface/OpenScopeAccept.lean',
        'formal/Benitoite/Release/Refinement/Surface/CheckAcceptBase.lean',
        'formal/Benitoite/Release/Refinement/Surface/CheckAcceptedRanges.lean',
        'formal/Benitoite/Release/Refinement/Surface/OpenScopeForwardExamples.lean',
        'formal/Benitoite/Release/Refinement/Surface/CheckPredicateProgramExamples.lean',
        'formal/Benitoite/Release/Refinement/Surface/CheckPreparation.lean',
        'formal/Benitoite/Release/Refinement/Surface/PredicateRowCollection.lean',
        'formal/Benitoite/Release/Refinement/Surface/PredicateProgramSemantics.lean',
        # 証明の補題の追加だけで、定義と既存の言明は変えていない。
        'formal/Benitoite/Release/Refinement/Surface/PredicateCalls.lean',
        'formal/Benitoite/Release/Refinement/Surface/PredicateProjectionCalls.lean',
        'formal/Benitoite/Release/Refinement/Surface/CheckPredicateProjectionExamples.lean',
    }
    changed = sorted(p for p,h in initial.items() if current.get(p) != h)
    assert set(changed) <= permitted, ('採取後の保護範囲の変更', changed)
    helpers = {'__file__': str(HERE.parent / 'verify.py')}
    exec((HERE.parent / 'verify.py').read_text().split('parser = argparse.ArgumentParser')[0], helpers)
    legacy = {}
    for label, ledger_path, difference_path in [
        ('d', HERE.parent / 'resume7-signatures.json', HERE.parent / 'resume7-signature-differences.json'),
        ('e', HERE.parents[1] / 'd-int/resume1-e-ledger.json', HERE.parent / 'resume9/e-ledger-differences.json'),
    ]:
        ledger = json.loads(ledger_path.read_text())
        expected = json.loads(difference_path.read_text())
        actual = {}
        for path, rows in ledger.items():
            headers = helpers['signature_hashes']((ROOT / path).read_text())
            for name, before in rows.items():
                if headers.get(name) != before:
                    actual.setdefault(path, {})[name] = {'before': before, 'after': headers.get(name)}
        assert actual == expected, (label, '再開9の後の既存台帳の追加差', actual)
        legacy[label] = dict(statements=sum(map(len, ledger.values())),
                             prior_differences=sum(map(len, expected.values())), additional_differences=0)
    checks = {k: json.loads((HERE / (k+'-summary.json')).read_text()) for k in ['build', 'axioms']}
    for kind, record in checks.items():
        log = tmp / (kind+'.log')
        assert record['exit_code'] == 0 and record['same_inputs'], (kind, record)
        assert record['bytes'] == log.stat().st_size and record['sha256'] == digest(log)
        assert record['fingerprint'] == record['after_fingerprint'] == fingerprint(current)
    build = (tmp / 'build.log').read_text()
    assert 'error:' not in build
    audit = (tmp / 'axioms.log').read_text()
    assert not re.search(r'error:|sorryAx|AUDIT_(?:MISSING|AXIOM|REQUIRED_MISSING|FIXED_POINT_LIMIT)', audit)
    targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
    assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', audit, re.M)[1])
    axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
    assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
    sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip())) for _, a in axioms)
    assert all(set(s) <= {'propext', 'Classical.choice', 'Quot.sound'} for s in sets)
    records = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', audit, re.M)
    assert collections.Counter(n for _, _, _, n in records) == collections.Counter(targets)
    counts = {m: int(n) for m,n in re.findall(r'^OWN_MODULE (\S+) (\d+)$', audit, re.M)}
    assert sorted(counts) == owned
    owned_records = [dict(module=m,kind=k,line=int(line),name=n) for m,k,line,n in records
                     if m in owned or m == 'local_records']
    save(tmp / 'declarations.json', owned_records)
    local = [r for r in owned_records if r['module'] == 'local_records']
    assert local and any('PredicateResolutionBoundary.counterexample' in r['name'] for r in local)
    required = json.loads((HERE / 'required-names.json').read_text())
    assert set(required) <= set(targets)
    # 全環境から生成した一覧を使い、private・生成宣言も各所属へ数える。
    for module, count in counts.items():
        assert sum(r['module'] == module for r in owned_records) == count
    for p in HERE.parent.rglob('*'):
        if p.is_file() and '__pycache__' not in p.parts:
            assert p.stat().st_size <= 100_000, p
    assert sum(p.stat().st_size for p in HERE.parent.rglob('*')
               if p.is_file() and '__pycache__' not in p.parts) < 3_000_000
    names = ('\n'.join(sorted(targets))+'\n').encode()
    result = dict(b_work=B_WORK, default_imports=True, added_modules=added,
                  changes_since_partial_snapshot=changed,
                  axiom_dependencies_complete=True, modules=len(owned), per_module=counts,
                  declarations=len(targets), owned_declarations=len(owned_records),
                  local_declarations=len(local),
                  legacy_statements=legacy, resume9_statements=statements(tmp),
                  owned_private=sum(r['name'].startswith('_private.') for r in owned_records),
                  names_bytes=len(names),names_sha256=hashlib.sha256(names).hexdigest(),
                  declarations_bytes=(tmp/'declarations.json').stat().st_size,
                  declarations_sha256=digest(tmp/'declarations.json'),
                  axiom_sets={','.join(k) or '(none)':v for k,v in sorted(sets.items())},
                  fingerprint=fingerprint(current))
    save(HERE / 'verification.json', result)
    print(json.dumps({k:v for k,v in result.items() if k != 'per_module'}, ensure_ascii=False, indent=1))
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['build', 'axioms', 'verify', 'checkpoint'])
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--lock', type=Path)
    args = parser.parse_args()
    args.tmp.mkdir(exist_ok=True, parents=True)
    if args.kind == 'verify':
        raise SystemExit(verify(args.tmp))
    assert args.lock is not None
    raise SystemExit(run(args.kind, args.tmp, args.lock))
