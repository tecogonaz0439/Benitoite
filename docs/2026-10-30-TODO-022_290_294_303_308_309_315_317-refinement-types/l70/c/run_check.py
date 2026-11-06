# -*- coding: utf-8 -*-
"""再開3の最終検査。指定の共有ロックの下で formal から実行し、生出力は一時領域へ置く。"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = json.loads((HERE / 'resume3-audit-modules.json').read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inputs():
    paths = [p for p in (ROOT / 'formal').rglob('*') if p.is_file() and '.lake' not in p.parts]
    paths += [ROOT / p for p in ['docs/design/01-spec/01-12-core-calculus.md',
                                'docs/design/07-quality/07-04-formal-semantics.md']]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}

def fingerprint(values):
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['build', 'audit'])
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--lock', type=Path, required=True)
    parser.add_argument('--record-prefix', choices=['resume3', 'resume4'], default='resume3')
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    before = inputs()
    command = ['lake', 'build'] if args.mode == 'build' else [
        'lake', 'env', 'lean', '-M', '12288', '../' + str((HERE / 'axioms_resume3.lean').relative_to(ROOT))]
    start = datetime.datetime.now().astimezone().isoformat()
    tick = time.monotonic()
    log = args.tmp / (args.mode + '.log')
    with log.open('w') as output:
        result = subprocess.run(['/usr/bin/lockf', '-t', '3600', str(args.lock)] + command,
                                cwd=ROOT / 'formal', stdout=output, stderr=subprocess.STDOUT)
        output.write(f'\nexit={result.returncode}\n')
    after = inputs()
    record = {'command_inside_lock': command, 'cwd': 'formal', 'start': start,
              'end': datetime.datetime.now().astimezone().isoformat(), 'seconds': time.monotonic()-tick,
              'exit': result.returncode, 'input_count': len(before), 'input_sha256': fingerprint(before),
              'unchanged': before == after, 'log_bytes': log.stat().st_size, 'log_sha256': digest(log),
              'sources': {m: digest(ROOT / ('formal/' + m.replace('.', '/') + '.lean')) for m in MODULES}}
    (HERE / (args.record_prefix + '-' + args.mode + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(record, ensure_ascii=False, indent=2))
    assert before == after
    raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
