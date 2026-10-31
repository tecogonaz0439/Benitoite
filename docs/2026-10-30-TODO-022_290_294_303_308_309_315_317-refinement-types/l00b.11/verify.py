#!/usr/bin/env python3
"""正規化の移行・全体ビルド・境界・全モジュールの公理依存を記録する。git は使わない。"""
import hashlib
import json
import os
import sys
import re
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = HERE.relative_to(ROOT).as_posix()
DELTA = json.loads(HERE.joinpath('source-delta.json').read_text())
INPUTS = [ROOT / x['path'] for x in DELTA['changes']]
INPUTS += [ROOT / ('formal/' + m.replace('.', '/') + '.lean') for m in DELTA['audit_modules']]
INPUTS = list(dict.fromkeys(INPUTS))
INPUTS += [ROOT / 'formal/lakefile.toml', ROOT / 'formal/lean-toolchain']
INPUTS += sorted(HERE.glob('*.lean')) + [HERE / 'rv-11-sigdiff.py', HERE / 'source-delta.json', HERE / 'review-before-sha256.json', HERE / 'review-contracts.json', HERE / 'signatures.md', HERE / 'verify.py']
HERE.joinpath('inputs-sha256.json').write_text(json.dumps([
    dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size,
         sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in INPUTS
], ensure_ascii=False, indent=2) + '\n')

records, declarations, dependencies = [], [], set()
audited_modules, unavailable_modules = [], []
checks = [('local-build', ['lake', 'build', 'Benitoite.Release.Refinement.ConstraintAssumptions',
                          'Benitoite.Release.Refinement.Canonical',
                          'Benitoite.Release.Refinement.BindCongr',
                          'Benitoite.Release.Refinement.SubstitutionContracts',
                          'Benitoite.Release.Refinement.NormalWellFormed',
                          'Benitoite.Release.Refinement.TypeShiftOrder',
                          'Benitoite.Release.Refinement.ExternalCheck',
                          'Benitoite.Release.Refinement.OpenSubstitution',
                          'Benitoite.Release.Refinement.ValueRegularity',
                          'Benitoite.Release.Refinement.DeclaredTransport',
                          'Benitoite.Release.Refinement.AdmissibleMap',
                          'Benitoite.Release.Refinement.TypedFacts',
                          'Benitoite.Release.Refinement.LocalTransport',
                          'Benitoite.Release.Refinement.LocalResolveLemmas',
                          'Benitoite.Release.Refinement.ValueReferences',
                          'Benitoite.Release.Refinement.PatternSemantics',
                          'Benitoite.Release.Refinement.TelTyping',
                          'Benitoite.Release.Refinement.TypeShiftContext',
                          'Benitoite.Release.Refinement.TypeShiftTyping',
                          'Benitoite.Release.Refinement.SubstTyping',
                          'Benitoite.Release.Refinement.Narrowing',
                          'Benitoite.Release.Refinement.ClosureTyping',
                          'Benitoite.Release.Refinement.NormalizedApplication',
                          'Benitoite.Release.Refinement.BuiltinResponse',
                          'Benitoite.Release.Refinement.Step',
                          'Benitoite.Release.Refinement.StateTyping',
                          ])]
checks = [('build', ['lake', 'build'])] + checks
checks += [(n, ['lake', 'env', 'lean', '-M', '12288', '../' + REL + '/' + n + '.lean'])
           for n in ['boundary', 'normalization-boundary', 'normalization-obstruction',
                     'normalization-contract-obstruction', 'typing-normalization-obstruction',
                     'normalization-retractions', 'type-shift-normalization-obstruction',
                     'normalized-rules-boundary', 'resume-return-contract-obstruction',
                     'review-builtins-boundary', 'review-store-boundary', 'review-lambda-boundary',
                     'rv-11-primraw', 'rv-11-count', 'axioms', 'public-api']]
large_rows = []
for name, command in checks:
    started = datetime.now(timezone.utc).isoformat()
    before = time.monotonic()
    # /usr/bin/time -l は sandbox 内で sysctl kern.clockrate を読めない。
    # wait4 の対象プロセスの資源統計を使い、検査本体の終了コードを保存する。
    with tempfile.TemporaryFile(mode='w+', encoding='utf-8') as sink:
        proc = subprocess.Popen(command, cwd=ROOT / 'formal', text=True,
                                stdout=sink, stderr=subprocess.STDOUT)
        _, status, usage = os.wait4(proc.pid, 0)
        proc.returncode = os.waitstatus_to_exitcode(status)
        sink.seek(0)
        output = sink.read().replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')
    elapsed = time.monotonic() - before
    if name == 'axioms':
        audited_modules = re.findall(r'AUDIT_MODULE (\S+)', output)
        unavailable_modules = re.findall(r'AUDIT_UNAVAILABLE (\S+)', output)
    data = output.encode()
    digest = hashlib.sha256(data).hexdigest()
    log = name + '.log'
    if len(data) > 100_000:
        with tempfile.NamedTemporaryFile(prefix='l00b11-' + name + '-', suffix='.log', delete=False) as f:
            f.write(data)
            tmp_name = Path(f.name).name
        large_rows.append(f'| {log} | {len(data)} | `{digest}` | `<tmp>/{tmp_name}` |\n')
        HERE.joinpath(log).write_text(f'完全な生の記録は `<tmp>/{tmp_name}`。\n\n'
                                      f'バイト数: {len(data)}\n\nSHA-256: `{digest}`\n')
        log = '<tmp>/' + tmp_name
    else:
        HERE.joinpath(log).write_bytes(data)
    rss = re.search(r'(\d+)\s+maximum resident set size', output)
    item = dict(name=name, command=command, cwd='formal', started_utc=started,
                elapsed_seconds=round(elapsed, 6), exit_code=proc.returncode,
                bytes=len(data), sha256=digest, output=log,
                maximum_resident_set_size_bytes=int(usage.ru_maxrss * (1 if sys.platform == 'darwin' else 1024)),
                resource_measurement='wait4 ru_maxrss')
    records.append(item)
    HERE.joinpath('verification.json').write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps(item), flush=True)
    if name not in {'build', 'local-build', 'public-api'} and proc.returncode == 0:
        declarations += re.findall(r"'([^']+)' (?:depends on axioms|does not depend on any axioms)", output)
        for match in re.finditer(r'depends on axioms:\s*\[([^\]]*)\]', output):
            dependencies.update(re.sub(r'\.\{[^}]*\}', '', n.strip()) for n in match[1].split(',') if n.strip())
        if 'sorryAx' in output:
            dependencies.add('sorryAx')
    if proc.returncode:
        print(output[-4000:], flush=True)
HERE.joinpath('large-records.md').write_text('# 大きい記録\n\n'
    '| 記録 | バイト | SHA-256 | 保存先 |\n|---|---:|---|---|\n' + ''.join(large_rows))
invalid = sorted(dependencies - {'propext', 'Quot.sound', 'Classical.choice'})
summary = dict(checked_declarations=len(declarations), dependencies=sorted(dependencies),
               unapproved=invalid, sorryAx='sorryAx' in dependencies,
               scope='全差分を包含する Refinement 全129モジュールと集約モジュールの全宣言、追加した正負の境界とレビュー入力を含む14補助入力を監査。私有・生成宣言も含む。',
               audited_modules=audited_modules, unavailable_modules=unavailable_modules,
               full_delta_audit_completed=bool(audited_modules) and not unavailable_modules and
                 next((r['exit_code'] for r in records if r['name'] == 'axioms'), 1) == 0)
# 対象名の全列も100 KBを超える場合は同じ上限に従う。
targets = ('\n'.join(declarations) + '\n').encode()
if len(targets) <= 100_000:
    HERE.joinpath('axiom-targets.txt').write_bytes(targets)
else:
    with tempfile.NamedTemporaryFile(prefix='l00b11-axiom-targets-', suffix='.txt', delete=False) as f:
        f.write(targets)
        tmp_name = Path(f.name).name
    digest = hashlib.sha256(targets).hexdigest()
    HERE.joinpath('axiom-targets.txt').write_text(f'<tmp>/{tmp_name}\n{len(targets)} bytes\nSHA-256 {digest}\n')
    with HERE.joinpath('large-records.md').open('a') as f:
        f.write(f'| axiom-targets.txt | {len(targets)} | `{digest}` | `<tmp>/{tmp_name}` |\n')
HERE.joinpath('axioms-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False), flush=True)
if invalid or unavailable_modules or any(r['exit_code'] for r in records):
    raise SystemExit(1)
