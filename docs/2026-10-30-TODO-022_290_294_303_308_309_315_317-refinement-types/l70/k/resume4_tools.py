"""再開4のビルド・監査・読者と保護範囲の照合。gitは呼ばない。"""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
from run_checks import HERE, ROOT, date, digest, snapshot
from verify_resume3 import audit
from candidate_sources import apply_unified


def baseline():
    start = json.loads((HERE / 'resume4-start.json').read_text())
    result = {}
    for name in start['file_parts']:
        result.update(json.loads((HERE / name).read_text()))
    assert len(result) == start['source_count']
    return result


def source_fingerprint():
    rows = snapshot()
    data = json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()
    return {'files':len(rows), 'sha256':hashlib.sha256(data).hexdigest()}


def changes():
    old = baseline()
    now = snapshot()
    changed = [p for p in now if p not in old or now[p]['sha256'] != old[p]]
    assert not set(old) - set(now), '開始時の入力の削除'
    assert all('/Surface/' not in p for p in changed)
    assert all(not p.startswith('formal/Benitoite/Release/') or
               p.startswith('formal/Benitoite/Release/Refinement/') for p in changed)
    return changed


def import_closure():
    seen = set()
    def visit(module):
        if module in seen:
            return
        seen.add(module)
        p = ROOT / 'formal' / (module.replace('.', '/') + '.lean')
        if p.exists():
            for dep in re.findall(r'^import\s+([A-Za-z0-9_.]+)', p.read_text(), re.M):
                visit(dep)
    visit('Benitoite')
    return seen


def verify(tmp, originals=None):
    changed = changes()
    old = baseline()
    assert digest(ROOT/'formal/Benitoite/Release/Refinement/MainStatements.lean')['sha256'] == old['formal/Benitoite/Release/Refinement/MainStatements.lean']
    new = [p[7:-5].replace('/', '.') for p in changed
           if p.startswith('formal/') and p.endswith('.lean') and p not in old]
    assert set(new) <= import_closure()
    for p in changed:
        if p.endswith('.lean'):
            assert not re.search(r'\b(?:sorry|axiom)\b', (ROOT / p).read_text()), p
    readers = [p for p in changed if p.startswith('formal/Benitoite/Release/Refinement/') and p in old]
    kernel = {f'formal/Benitoite/Release/Refinement/{n}.lean' for n in
              ['Syntax','Typing','Semantics','HandlerContracts','SourceScope','ProgramTyping','Step']}
    assert kernel <= set(changed)
    following = sorted(set(readers) - kernel)
    out = {'date': date(), 'changed_files': len(changed), 'existing_refinement_modules': len(readers),
           'kernel_modules':sorted(kernel), 'following_reader_count':len(following),
           'following_reader_modules':following, 'new_modules': new, 'default_imports': '全新規モジュールが到達可能',
           'protected': 'Surface・旧Releaseの開始時ハッシュ一致',
           'changed_inputs': {p:digest(ROOT/p) for p in changed}}
    if tmp:
        raw = tmp / 'axioms.log'
        if raw.exists():
            summary, names, modules = audit(raw.read_text(), [
                'Benitoite.Release.Refinement.Def.WellTyped.inputs_no_ranges',
                'Benitoite.Release.Refinement.HasTypeVQ.canonical_function_no_ranges',
                'Benitoite.Release.Refinement.effect_soundness',
                'Benitoite.Release.Refinement.effect_soundness_noLamNames',
                'Benitoite.Release.Refinement.StateTyE.no_event',
                'Benitoite.Release.Refinement.StateTyE.no_unhandledOp',
                'Benitoite.Release.Refinement.Program.extends_typing',
                'Benitoite.Release.Refinement.Program.extends_declaration',
                'Benitoite.Release.Refinement.Program.compose',
                'Benitoite.Release.Refinement.LegacyCompCases.match_type_subst',
                'Benitoite.Release.Refinement.Program.extends_typing_declared_context',
                'Benitoite.Release.Refinement.EffectSoundnessExamples.environment_witness',
                'Benitoite.Release.Refinement.EffectSoundnessExamples.handler_bypass_witness',
                'Benitoite.Release.Refinement.EffectSoundnessExamples.unit_noLamNames_witness'])
            assert set(new) <= modules
            targets = tmp / 'audit-targets.txt'
            targets.write_text('\n'.join(names)+'\n')
            summary['target_list'] = digest(targets)
            out['audit'] = summary
    if tmp and tmp.name == 'l70k-r4-final':
        assert originals, '再構成のため開始時の入力を指定する'
        fingerprint = source_fingerprint()
        checks = {}
        for label in ['build','axioms']:
            meta = HERE / (tmp.name+'-'+label+'.json')
            row = json.loads(meta.read_text())
            assert row['exit'] == 0 and row['source_stable']
            assert row['source_before'] == row['source_after'] == fingerprint
            assert row['raw'] == digest(tmp/(label+'.log'))
            if label == 'axioms':
                assert row['input'] == digest(HERE/'axioms.lean')
            checks[label] = digest(meta)
        assert 'Build completed successfully' in (tmp/'build.log').read_text()
        assert out['audit']['unapproved_axioms'] == 0
        manifest = json.loads((HERE/'resume4-candidate.json').read_text())
        assert manifest['fingerprint'] == fingerprint
        assert {r['file'] for r in manifest['files']} == set(changed)
        for row in manifest['files']:
            assert row['before'] == old.get(row['file'])
            assert row['after'] == digest(ROOT/row['file'])
            assert row['patch_digest'] == digest(HERE/row['patch'])
            before = ''
            if row['before']:
                assert digest(originals/row['file'])['sha256'] == row['before']
                before = (originals/row['file']).read_text()
            assert apply_unified(before,(HERE/row['patch']).read_text()) == (ROOT/row['file']).read_text()
        definitions = json.loads((HERE/'resume4-definition-inputs.json').read_text())
        for name, ha in definitions.items():
            assert digest(ROOT/name) == ha
        assert manifest['spec_text_examples_unchanged']
        out['candidate_manifest'] = digest(HERE/'resume4-candidate.json')
        out['definition_inputs'] = digest(HERE/'resume4-definition-inputs.json')
        out['final_checks'] = checks
        out['fingerprint'] = fingerprint
        sizes = [p.stat().st_size for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
        assert all(n <= 100000 for n in sizes)
        assert sum(sizes) < 8000000
        for p in HERE.rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts:
                assert str(ROOT) not in p.read_text(), p
        out['record_bytes_before_verification'] = sum(sizes)
    (HERE / 'resume4-verification.json').write_text(json.dumps(out, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in {'changed_inputs','following_reader_modules','kernel_modules'}}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'audit', 'verify'])
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--lock', type=Path)
    parser.add_argument('--originals', type=Path)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    if args.action == 'verify':
        verify(args.tmp,args.originals)
        return
    assert args.lock
    command = ['/usr/bin/lockf', '-t', '3600', str(args.lock)]
    if args.action == 'build':
        command += ['lake', 'build']
    else:
        source = '../' + str(HERE.relative_to(ROOT)) + '/axioms.lean'
        command += ['lake', 'env', 'lean', '-M', '12288', source]
    label = 'axioms' if args.action == 'audit' else 'build'
    raw = args.tmp / (label+'.log')
    assert not raw.exists(), '生出力を上書きしない'
    before = source_fingerprint()
    start, tick = date(), time.monotonic()
    with raw.open('wb') as stream:
        completed = subprocess.run(command, cwd=ROOT/'formal', stdout=stream, stderr=subprocess.STDOUT)
    after = source_fingerprint()
    record = {'source_before':before, 'source_after':after, 'source_stable':before == after, 'start':start, 'end':date(), 'seconds':round(time.monotonic()-tick,3),
              'exit':completed.returncode, 'cwd':'formal', 'command':[x.replace(str(args.lock), '<lock>') for x in command],
              'raw':digest(raw), 'maximum_rss':'未取得（計画上の非採取）'}
    if label == 'axioms':
        record['input'] = digest(HERE/'axioms.lean')
    name = args.tmp.name + '-' + label + '.json'
    (HERE/name).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(record,ensure_ascii=False), flush=True)
    if completed.returncode:
        print('\n'.join(line for line in raw.read_text().splitlines() if 'error:' in line), flush=True)
    raise SystemExit(completed.returncode)


if __name__ == '__main__':
    main()
