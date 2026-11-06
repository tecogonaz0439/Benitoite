"""formal/ から共有ロックの下で最終検査を実行し、小さな要約だけを保存する。"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    paths = [p for p in (ROOT / 'formal').rglob('*.lean') if '.lake' not in p.parts]
    paths += [ROOT / 'formal' / name for name in ('lakefile.toml', 'lake-manifest.json', 'lean-toolchain')]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def fingerprint(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['build', 'axioms'])
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--lock', required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    command = ['lake', 'build']
    if args.kind == 'axioms':
        command = ['lake', 'env', 'lean', '-M', '12288', '../' + str((HERE / 'axioms.lean').relative_to(ROOT))]
    before = inputs()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    begin = time.monotonic()
    log = args.tmp / (args.kind + '.log')
    with log.open('w') as output:
        result = subprocess.run(['/usr/bin/lockf', '-t', '3600', args.lock] + command,
                                cwd=ROOT / 'formal', stdout=output, stderr=subprocess.STDOUT)
        output.write(f'\nrc={result.returncode}\n')
    seconds = time.monotonic() - begin
    after = inputs()
    assert before == after, '検査中に本番の入力が変わった'
    summary = dict(command=['lockf', '-t', '3600', '<shared-lock>'] + command,
                   started=started, finished=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   seconds=seconds, exit_code=result.returncode, bytes=log.stat().st_size,
                   sha256=digest(log), inputs=len(before), fingerprint=fingerprint(before))
    (HERE / (args.kind + '-summary.json')).write_text(json.dumps(summary, ensure_ascii=False, indent=1) + '\n')
    if args.kind == 'build':
        (HERE / 'final-inputs.json').write_text(json.dumps({
            'count': len(before), 'fingerprint': fingerprint(before)}, indent=1) + '\n')
    print(json.dumps(summary, ensure_ascii=False))
    raise SystemExit(result.returncode)
