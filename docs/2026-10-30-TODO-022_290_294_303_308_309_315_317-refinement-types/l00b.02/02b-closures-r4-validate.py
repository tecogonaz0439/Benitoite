"""閉包の群の既定ビルド、境界入力、全宣言の公理依存を照合する。gitは使わない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / 'formal'
PREFIX = '02b-closures-r4-'
ALLOWED = {'propext', 'Quot.sound', 'Classical.choice'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inputs():
    files = sorted(p for p in FORMAL.rglob('*.lean') if '.lake' not in p.parts)
    files += [FORMAL / 'lakefile.toml', FORMAL / 'lean-toolchain']
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in files}


def main():
    before = json.loads((HERE / (PREFIX + 'start.json')).read_text())
    current = inputs()
    records, large, summaries = [], [], {}
    raw = Path(tempfile.mkdtemp(prefix='l00b02b-closures-r4-validation-'))

    def save(name, data):
        name = PREFIX + name
        info = {'name': name, 'bytes': len(data), 'sha256': sha(data)}
        if len(data) > 100_000:
            (raw / name).write_bytes(data)
            info['storage'] = '<tmp>'
            large.append(info)
        else:
            (HERE / name).write_bytes(data)
            info['storage'] = '改造/l00b.02'
        return info

    def write(name, obj):
        return save(name, (json.dumps(obj, ensure_ascii=False, indent=2) + '\n').encode())

    import shutil
    cache = FORMAL / '.lake/closures-r4'
    cache.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HERE / (PREFIX + 'boundary.lean'), cache / 'ClosureR4Boundary.lean')
    shutil.copyfile(HERE / (PREFIX + 'extra.lean'), cache / 'ClosureR4Extra.lean')
    rel = '../' + str(HERE.relative_to(ROOT)) + '/'
    commands = [
        ('build', ['lake', 'build']),
        ('boundary', ['lake', 'env', 'lean', '-M', '12288', '-R', '.lake/closures-r4', '-o', '.lake/build/lib/lean/ClosureR4Boundary.olean', '.lake/closures-r4/ClosureR4Boundary.lean']),
        ('extra', ['lake', 'env', 'lean', '-M', '12288', '-R', '.lake/closures-r4', '-o', '.lake/build/lib/lean/ClosureR4Extra.olean', '.lake/closures-r4/ClosureR4Extra.lean']),
        ('guard', ['lake', 'env', 'lean', '-M', '12288', rel + PREFIX + 'guard.lean']),
        ('rows', ['lake', 'env', 'lean', '-M', '12288', rel + PREFIX + 'rows.lean']),
        ('public-api', ['lake', 'env', 'lean', '-M', '12288', rel + PREFIX + 'public-api.lean']),
        ('axioms', ['lake', 'env', 'lean', '-M', '12288', rel + PREFIX + 'axioms.lean']),
        ('lean-version', ['lake', 'env', 'lean', '-M', '12288', '--version']),
    ]
    for name, command in commands:
        tick = time.monotonic()
        start = datetime.datetime.now().astimezone().isoformat()
        proc = subprocess.run(command, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - tick
        data = proc.stdout.replace(str(ROOT).encode(), b'<repo>').replace(str(Path.home()).encode(), b'<home>')
        record = {'name': name, 'command': command, 'cwd': 'formal', 'start': start,
                  'exit': proc.returncode, 'elapsed_seconds': elapsed, 'output': save(name + '.log', data)}
        if command[-1].endswith('.lean'):
            record['input_sha256'] = sha((FORMAL / command[-1]).read_bytes())
        records.append(record)
        write('commands.json', records)
        print(name, '終了', proc.returncode, '秒', round(elapsed, 3), flush=True)
        if proc.returncode:
            raise SystemExit(proc.returncode)
        text = data.decode()
        names = re.findall(r"^'(.+)' (?:depends on axioms|does not depend)", text, re.M)
        used = {a.strip() for group in re.findall(r'depends on axioms:\s*\[([^\]]*)\]', text)
                for a in group.split(',') if a.strip()}
        modules = [{'module': n, 'declarations': int(c)} for n, c in
                   re.findall(r'^MODULE ([^:]+): (\d+)$', text, re.M)]
        summaries[name] = {'checked_declarations': len(names), 'unique_declarations': len(set(names)),
                           'used': sorted(used), 'rejected': sorted(used - ALLOWED), 'modules': modules}
        if name in ('boundary', 'extra', 'guard', 'rows'):
            expected = int(re.search(r'BOUNDARY_DECLARATIONS (\d+)', text).group(1))
            assert len(names) == len(set(names)) == expected
        if used - ALLOWED:
            raise SystemExit('許可外の公理への依存がある')
        if name == 'public-api':
            save('public-api.md', ('# 第4版の公開宣言\n\n```text\n' + text + '\n```\n').encode())
        if name == 'axioms':
            assert len(names) == len(set(names)) == sum(m['declarations'] for m in modules) + 7
            counts = [{'type': n, 'constructors': int(c), 'names': ns} for n, c, ns in
                      re.findall(r'^CONSTRUCTORS ([^:]+): (\d+): (.+)$', text, re.M)]
            write('case-inventory.json', counts)
    after = inputs()
    hits = [str(p.relative_to(ROOT)) for p in (FORMAL / 'Benitoite/Release/Refinement').glob('*.lean')
            if re.search(r'\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b', p.read_text())]
    changed = [{'path': n, 'before': before['inputs'].get(n), 'after': current.get(n)}
               for n in sorted(set(before['inputs']) | set(current)) if before['inputs'].get(n) != current.get(n)]
    write('source-changes.json', changed)
    write('inputs-final.json', after)
    write('axioms-summary.json', summaries)
    write('validation.json', {
        'base_work': before['base_work'], 'branch': before['branch'], 'status': '再々レビューの所見への対応の検査',
        'input_count': len(after), 'validation_inputs_unchanged': current == after,
        'production_changes': len(changed), 'new_production_files': [x['path'] for x in changed if x['before'] is None],
        'forbidden_tokens': hits, 'allowed_axioms': sorted(ALLOWED), 'summaries': summaries,
        'rss': '未取得（計画上の非採取）', 'work': '起動依頼に従い取りまとめが実行する',
        'started_at': '2026-10-31T15:13:11+09:00', 'finished_at': datetime.datetime.now().astimezone().isoformat(),
    })
    write('artifact-inputs.json', {p.name: sha(p.read_bytes()) for p in sorted(HERE.glob(PREFIX + '*'))
                                  if p.suffix in ('.lean', '.py', '.md')})
    prior_large = (HERE / 'large-records.md').read_text()
    large = [row for row in large if row['sha256'] not in prior_large]
    if large:
        with (HERE / 'large-records.md').open('a') as f:
            f.write('\n### `.02b-closures` の第4版の検査\n\n| 記録 | 保存先 | バイト | SHA-256 |\n|---|---|---:|---|\n')
            for row in large:
                f.write(f"| `{row['name']}` | `<tmp>` | {row['bytes']:,} | `{row['sha256']}` |\n")
    if current != after or hits:
        raise SystemExit('検査中の入力変更又は抜け道の語の検出')
    print('全入力', len(after), '変更', len(changed), '新規', sum(x['before'] is None for x in changed), flush=True)


if __name__ == '__main__':
    main()
