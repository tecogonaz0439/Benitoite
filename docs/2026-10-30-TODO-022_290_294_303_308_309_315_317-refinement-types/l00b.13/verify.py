#!/usr/bin/env python3
"""値の葉のビルド、境界、署名、公理依存を記録する。git は使わない。"""
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

start = json.loads(HERE.joinpath('start-inputs.json').read_text())['sha256']
now = {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in (ROOT/'formal').rglob('*.lean')
       if '.lake' not in p.parts}
changes = [dict(path=p, before=start.get(p), after=h, bytes=ROOT.joinpath(p).stat().st_size)
           for p,h in sorted(now.items()) if start.get(p) != h]
save_json('source-delta.json', {'base': '40311429fea38171b53f7e909096c63222ce06e5',
          'comparison': '開始時に読んだソースのハッシュとの照合。git は未使用。', 'changes': changes})
review_before = json.loads(HERE.joinpath('review-before-sha256.json').read_text())
review_changes = [dict(path=p, before=review_before.get(p), after=h)
                  for p,h in sorted(now.items()) if review_before.get(p) != h]
save_json('review-source-delta.json', review_changes)
protected = [p for p in review_before if '/rv-' in p or p.endswith('/plan.md') or p.endswith('/reviews/RV-L00b.13.md')]
protected_changed = [p for p in protected if digest(ROOT.joinpath(p).read_bytes()) != review_before[p]]
save_json('protected-inputs.json', {'checked':protected,'changed':protected_changed})
if protected_changed:
    raise SystemExit('読み取り専用の入力が変わった。')
modules = json.loads(HERE.joinpath('public-names.json').read_text())['audit_modules']
inputs = [ROOT/('formal/'+m.replace('.', '/')+'.lean') for m in modules]
inputs += [ROOT/'formal/lakefile.toml', ROOT/'formal/lean-toolchain']
inputs += sorted(HERE.glob('*.lean')) + [HERE/'verify.py', HERE/'signatures.md', HERE/'public-names.json', HERE/'review-before-sha256.json']
inputs = list(dict.fromkeys(inputs))
input_records = [dict(path=str(p.relative_to(ROOT)), bytes=p.stat().st_size,
                      sha256=digest(p.read_bytes())) for p in inputs]
save_json('inputs-sha256.json', input_records)
checks = [('build', ['lake','build'])]
checks += [(n,['lake','env','lean','-M','12288','../'+REL+'/'+n+'.lean'])
           for n in ['boundary','review-ground-boundary','axioms','public-api']]
checks.insert(3, ('review-reference', ['lake','env','lean','-M','12288','../'+REL+'/rv-13-w2.lean']))
records, large, names, dependencies, audited = [], [], [], set(), []
for name, command in checks:
    started = datetime.now(timezone.utc).isoformat()
    before = time.monotonic()
    with tempfile.TemporaryFile() as sink:
        proc = subprocess.run(command, cwd=ROOT/'formal', stdout=sink, stderr=subprocess.STDOUT)
        sink.seek(0)
        output = sink.read().decode().replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')
    elapsed = time.monotonic() - before
    data = output.encode()
    output_name = name+'.log'
    if len(data) > 100_000:
        with tempfile.NamedTemporaryFile(prefix='l00b13-'+name+'-',suffix='.log',delete=False) as tmp:
            tmp.write(data)
            output_name = '<tmp>/'+Path(tmp.name).name
        large.append(dict(record=name,bytes=len(data),sha256=digest(data),output=output_name))
        HERE.joinpath(name+'.log').write_text(
            f'完全な生の記録は `{output_name}`。\n\nバイト数: {len(data)}\n\nSHA-256: `{digest(data)}`\n')
    else:
        HERE.joinpath(output_name).write_bytes(data)
    row = dict(name=name, command=command, cwd='formal', started_utc=started,
               elapsed_seconds=round(elapsed,6), exit_code=proc.returncode,
               bytes=len(data), sha256=digest(data), output=output_name,
               rss='未取得（計画上の非採取）')
    records.append(row)
    save_json('verification.json', records)
    print(json.dumps(row,ensure_ascii=False), flush=True)
    if name in {'axioms','boundary','review-ground-boundary'}:
        names += re.findall(r"'([^']+)' (?:depends on axioms|does not depend on any axioms)",output)
        for match in re.finditer(r'depends on axioms:\s*\[([^\]]*)\]',output):
            dependencies.update(re.sub(r'\.\{[^}]*\}', '', n.strip())
                                for n in match[1].split(',') if n.strip())
        if 'sorryAx' in output:
            dependencies.add('sorryAx')
    if name == 'axioms':
        audited = re.findall(r'AUDIT_MODULE (\S+)',output)
        HERE.joinpath('case-inventory.txt').write_text('\n'.join(
            s for s in output.splitlines() if s.startswith('cases ') or s.startswith('THREE_FAMILY_CASES'))+'\n')
    if proc.returncode:
        print(output[-6000:],flush=True)
        raise SystemExit(proc.returncode)
invalid = sorted(dependencies-ALLOWED)
summary = dict(checked_declarations=len(names), unique_declarations=len(set(names)),
               dependencies=sorted(dependencies), unapproved=invalid,
               sorryAx='sorryAx' in dependencies, audited_modules=audited,
               expected_modules=modules, missing_modules=sorted(set(modules)-set(audited)),
               scope='Refinement 全133モジュール・集約モジュール・旧モデル/主定理12宣言・初回とレビュー対応の境界の私有/生成宣言を含む。')
save_json('axioms-summary.json',summary)
HERE.joinpath('axiom-targets.txt').write_text('\n'.join(names)+'\n')
# 対象名の全記録も100 KBの条件に従って扱う。
p = HERE/'axiom-targets.txt'
if p.stat().st_size > 100_000:
    data=p.read_bytes()
    with tempfile.NamedTemporaryFile(prefix='l00b13-targets-',suffix='.txt',delete=False) as tmp:
        tmp.write(data)
        target_name='<tmp>/'+Path(tmp.name).name
    large.append(dict(record='axiom-targets',bytes=len(data),sha256=digest(data),output=target_name))
    p.write_text(f'対象名の全記録は `{target_name}`。\nバイト数: {len(data)}\nSHA-256: `{digest(data)}`\n')
HERE.joinpath('large-records.md').write_text('# 大きい記録\n\n'
    '| 記録 | バイト | SHA-256 | 保存先 |\n|---|---:|---|---|\n'+''.join(
    f"| {r['record']} | {r['bytes']} | `{r['sha256']}` | `{r['output']}` |\n" for r in large))
changed_after = [r['path'] for r in input_records if digest(ROOT.joinpath(r['path']).read_bytes()) != r['sha256']]
save_json('input-stability.json', {'changed_during_verification':changed_after})
if invalid or summary['missing_modules'] or changed_after or not names:
    raise SystemExit('公理・対象・入力の照合に失敗した。')
print(json.dumps({k:summary[k] for k in ['checked_declarations','dependencies','unapproved','missing_modules']},ensure_ascii=False))
