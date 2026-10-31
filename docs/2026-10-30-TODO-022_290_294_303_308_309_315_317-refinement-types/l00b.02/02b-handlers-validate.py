"""handlersの停止点の反例・既定ビルド・公理依存を照合する。gitは使わない。"""
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
PREFIX = '02b-handlers-'
ALLOWED = {'propext', 'Quot.sound', 'Classical.choice'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inputs():
    files = sorted(p for p in FORMAL.rglob('*.lean') if '.lake' not in p.parts)
    files += [FORMAL / 'lakefile.toml', FORMAL / 'lean-toolchain']
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in files}


def main():
    prior_path = HERE / (PREFIX + 'commands.json')
    previous = json.loads(prior_path.read_text()) if prior_path.exists() else []
    records = []
    summaries = {}
    raw = Path(tempfile.mkdtemp(prefix='l00b02b-handlers-validation-'))
    large = []
    before = json.loads((HERE / (PREFIX + 'start.json')).read_text())
    current = inputs()
    if current != before['inputs']:
        raise SystemExit('停止点の照合前に本番入力が変わった')

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
        save(name, (json.dumps(obj, ensure_ascii=False, indent=2) + '\n').encode())

    rel = '../' + str(HERE.relative_to(ROOT)) + '/'
    cmds = [
        ('build', ['lake', 'build']),
        ('contract-boundary', ['lake', 'env', 'lean', '-M', '12288', rel + PREFIX + 'contract-boundary.lean']),
        ('axioms', ['lake', 'env', 'lean', '-M', '12288', rel + '02b-at-r2-axioms.lean']),
        ('lean-version', ['lake', 'env', 'lean', '-M', '12288', '--version']),
    ]
    for name, cmd in cmds:
        cached = next((x for x in previous if x['name'] == 'build' and name == 'build'
                       and x['exit'] == 0 and x['command'] == cmd), None)
        if cached:
            data = (HERE / cached['output']['name']).read_bytes()
            if sha(data) != cached['output']['sha256']:
                raise SystemExit('前のビルドの出力が変わった')
            records.append({**cached, 'reused_same_production_inputs': True})
            print(name, '同一本番入力の成功を引用', flush=True)
            continue
        tick = time.monotonic()
        start = datetime.datetime.now().astimezone().isoformat()
        proc = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - tick
        data = proc.stdout.replace(str(ROOT).encode(), b'<repo>').replace(str(Path.home()).encode(), b'<home>')
        record = {'name': name, 'command': cmd, 'cwd': 'formal', 'start': start,
                  'exit': proc.returncode, 'elapsed_seconds': elapsed, 'output': save(name + '.log', data)}
        if cmd[-1].endswith('.lean'):
            record['input_sha256'] = sha((FORMAL / cmd[-1]).read_bytes())
        records.append(record)
        write('commands.json', records)
        print(name, '終了', proc.returncode, '秒', round(elapsed, 3), flush=True)
        if proc.returncode:
            raise SystemExit(proc.returncode)
        text = data.decode()
        names = re.findall(r"^'([^']+)' (?:depends on axioms|does not depend)", text, re.M)
        used = {a.strip() for group in re.findall(r'depends on axioms:\s*\[([^\]]*)\]', text)
                for a in group.split(',') if a.strip()}
        modules = [{'module': n, 'declarations': int(c)} for n, c in
                   re.findall(r'^MODULE ([^:]+): (\d+)$', text, re.M)]
        summaries[name] = {'checked_declarations': len(names), 'unique_declarations': len(set(names)),
                           'used': sorted(used), 'rejected': sorted(used - ALLOWED), 'modules': modules}
        if name == 'contract-boundary':
            expected = int(re.search(r'BOUNDARY_DECLARATIONS (\d+)', text).group(1))
            if len(names) != expected or len(set(names)) != expected:
                raise SystemExit('補助入力の宣言の検査数が一致しない')
        if used - ALLOWED:
            raise SystemExit('許可外の公理への依存がある')
    write('axioms-summary.json', summaries)
    audit = summaries['axioms']
    if audit['checked_declarations'] != audit['unique_declarations'] or audit['checked_declarations'] != sum(x['declarations'] for x in audit['modules']) + 7:
        raise SystemExit('本番の公理依存の検査数が一致しない')
    hits = [str(p.relative_to(ROOT)) for p in (FORMAL / 'Benitoite/Release/Refinement').glob('*.lean')
            if re.search(r'\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial)\b', p.read_text())]
    after = inputs()
    state = {'status': '信頼条件の判断が必要な停止点。handlers群は未実装',
             'base_work': before['base_work'], 'input_count': len(current),
             'production_changed_files': [name for name in set(current) | set(after) if current.get(name) != after.get(name)],
             'inputs_unchanged': before['inputs'] == current == after,
             'completed_handler_derivations': 0, 'planned_handler_derivations': 14,
             'all_commands_exit_zero': True, 'production_token_hits': hits,
             'lean_memory_mib': 12288, 'work': '依頼に従い未実行', 'rss': '未取得（計画上の非採取）',
             'completed_at': datetime.datetime.now().astimezone().isoformat(),
             'external_elapsed_seconds': time.time() - datetime.datetime.fromisoformat(before['start_utc']).timestamp(),
             'large_records': large}
    write('validation.json', state)
    write('inputs-final.json', current)
    artifacts = [Path(__file__), HERE / (PREFIX + 'contract-boundary.lean'), HERE / '02b-at-r2-axioms.lean']
    write('artifact-inputs.json', {p.name: sha(p.read_bytes()) for p in artifacts})
    table = HERE / 'large-records.md'
    text = table.read_text()
    for item in large:
        if item['sha256'] not in text:
            text += f'| `{item["name"]}` | {item["bytes"]} | `{item["sha256"]}` |\n'
    table.write_text(text)
    print(json.dumps(state, ensure_ascii=False, indent=2))
    if hits or not state['inputs_unchanged']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
