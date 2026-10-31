#!/usr/bin/env python3
"""依存βの既定ビルド、境界、署名、公理依存を記録する。git は使わない。"""
import hashlib
import json
import re
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = HERE.relative_to(ROOT).as_posix()
ALLOWED = {'propext', 'Quot.sound', 'Classical.choice'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def save_json(name, value):
    HERE.joinpath(name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


large = []


def save_output(name, data):
    if len(data) > 100_000:
        with tempfile.NamedTemporaryFile(prefix='l00b14a-' + name + '-', suffix='.log', delete=False) as sink:
            sink.write(data)
            destination = '<tmp>/' + Path(sink.name).name
        large.append(dict(record=name, bytes=len(data), sha256=digest(data), output=destination))
        HERE.joinpath(name + '.log').write_text(
            f'生の記録: `{destination}`\n\nバイト数: {len(data)}\n\nSHA-256: `{digest(data)}`\n')
        return destination
    HERE.joinpath(name + '.log').write_bytes(data)
    return name + '.log'


start = json.loads(HERE.joinpath('start-inputs.json').read_text())
now = {p.relative_to(ROOT).as_posix(): digest(p.read_bytes())
       for p in (ROOT / 'formal').rglob('*.lean') if '.lake' not in p.parts}
changes = [dict(path=p, before=start['sha256'].get(p), after=h,
                bytes=ROOT.joinpath(p).stat().st_size)
           for p, h in sorted(now.items()) if start['sha256'].get(p) != h]
save_json('source-delta.json', {'base': start['base'], 'comparison': '開始時のハッシュとの照合。git は未使用。',
                               'changes': changes})
review_start = json.loads(HERE.joinpath('review-start-inputs.json').read_text())
request_path = (HERE.parent / 'reviews/RV-L00b.14a-request.md').relative_to(ROOT).as_posix()
protected = {p: h for p, h in review_start['sha256'].items()
             if not p.startswith('formal/') and p != request_path}
review_changes = [dict(path=p, before=review_start['sha256'].get(p), after=h)
                  for p, h in sorted(now.items()) if review_start['sha256'].get(p) != h]
save_json('review-source-delta.json', {'comparison': 'RV対応の開始時との照合。gitは未使用。',
                                     'changes': review_changes})
protected_changed = [p for p, h in protected.items() if digest(ROOT.joinpath(p).read_bytes()) != h]
save_json('protected-inputs.json', {'checked': len(protected), 'changed': protected_changed})
if protected_changed:
    raise SystemExit('読み取り専用の入力が変わった。')
modules = sorted('Benitoite.Release.Refinement.' + p.relative_to(ROOT / 'formal/Benitoite/Release/Refinement').with_suffix('').as_posix().replace('/', '.')
                 for p in (ROOT / 'formal/Benitoite/Release/Refinement').rglob('*.lean')) + ['Benitoite']
inputs = [ROOT / ('formal/' + m.replace('.', '/') + '.lean') for m in modules]
inputs += [ROOT / 'formal/lakefile.toml', ROOT / 'formal/lean-toolchain']
inputs += [HERE / (name + '.lean') for name in ['boundary', 'axioms', 'public-api']]
inputs += sorted(HERE.glob('rv-*.lean')) + [HERE / 'verify.py', HERE / 'signatures.md']
input_hashes = {p.relative_to(ROOT).as_posix(): digest(p.read_bytes()) for p in inputs}
save_json('inputs-sha256.json', input_hashes)
checks = [('build', ['lake', 'build'])]
checks += [(name, ['lake', 'env', 'lean', '-M', '12288', '../' + REL + '/' + name + '.lean'])
           for name in ['boundary', 'axioms', 'public-api']]
checks += [('lean-version', ['lake', 'env', 'lean', '-M', '12288', '--version'])]
records, names, dependencies, audited, counts = [], [], set(), [], []
for name, command in checks:
    started = datetime.now(timezone.utc).isoformat()
    before = time.monotonic()
    with tempfile.TemporaryFile() as sink:
        proc = subprocess.run(command, cwd=ROOT / 'formal', stdout=sink, stderr=subprocess.STDOUT)
        sink.seek(0)
        output = sink.read().decode().replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')
    elapsed = time.monotonic() - before
    data = output.encode()
    output_name = save_output(name, data)
    row = dict(name=name, command=command, cwd='formal', started_utc=started,
               elapsed_seconds=round(elapsed, 6), exit_code=proc.returncode, bytes=len(data),
               sha256=digest(data), output=output_name, rss='未取得（計画上の非採取）')
    records.append(row)
    save_json('verification.json', records)
    print(json.dumps(records[-1], ensure_ascii=False), flush=True)
    return_code = records[-1]['exit_code']
    if return_code:
        print(output[-6000:], flush=True)
        raise SystemExit(return_code)
    if name in {'axioms', 'boundary'}:
        names += re.findall(r"'([^']+)' (?:depends on axioms|does not depend on any axioms)", output)
        for match in re.finditer(r'depends on axioms:\s*\[([^\]]*)\]', output):
            dependencies.update(re.sub(r'\.\{[^}]*\}', '', n.strip())
                                for n in match[1].split(',') if n.strip())
        if 'sorryAx' in output:
            dependencies.add('sorryAx')
    if name == 'axioms':
        audited = re.findall(r'AUDIT_MODULE (\S+)', output)
        counts = [s for s in output.splitlines() if s.startswith(('cases ', 'THREE_FAMILY_CASES'))]
    if name == 'build' and re.search(r'declaration uses [‘\']sorry', output):
        raise SystemExit('sorry を含むビルド。')
invalid = sorted(dependencies - ALLOWED)
save_json('axioms-summary.json', dict(checked_declarations=len(names), unique_declarations=len(set(names)),
    dependencies=sorted(dependencies), unapproved=invalid, sorryAx='sorryAx' in dependencies,
    audited_modules=audited, expected_modules=modules, missing_modules=sorted(set(modules)-set(audited)),
    scope='Refinement全モジュール・集約・旧モデル/主定理12宣言・境界の私有/生成宣言を含む。'))
save_output('axiom-targets', ('\n'.join(names) + '\n').encode())
HERE.joinpath('case-inventory.txt').write_text('\n'.join(counts) + '\n')
changed_inputs = [p for p, h in input_hashes.items() if digest(ROOT.joinpath(p).read_bytes()) != h]
save_json('input-stability.json', {'checked': len(input_hashes), 'changed': changed_inputs})
HERE.joinpath('large-records.md').write_text('# 大きい記録\n\n'
    '| 記録 | バイト | SHA-256 | 保存先 |\n|---|---:|---|---|\n' + ''.join(
    f"| {v['record']} | {v['bytes']} | `{v['sha256']}` | `{v['output']}` |\n" for v in large))
if invalid or set(modules)-set(audited) or changed_inputs:
    raise SystemExit('公理依存・監査の範囲・入力の安定性が不適合。')
print('全検査終了0。未承認公理・未監査モジュール・検査中の入力変更は0。', flush=True)
