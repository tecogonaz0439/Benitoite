"""全件 corpus を作らず、実書き出しの短い部分集合で区間接続を試す。"""
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
BASE = Path('target/interval-diff/x04a-local')


def main():
    helper = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
    desugar = Path('target/desugar-diff/x04a-local')
    coverage = Path('target/coverage-diff/x04a-local')
    desugar.parent.mkdir(exist_ok=True)
    if (BASE/'desugar').exists():
        shutil.move(BASE/'desugar', desugar)
    coverage.mkdir(parents=True, exist_ok=True)
    # named の全件の代わりに、同じ CorpusStream が出した manifest の通常入力を使う。
    # 操作上限の補助入力は元の manifest ディレクトリで別に比較する。
    legacy = helper['read'](BASE/'manifest/manifest-corpus.json')
    helper['write'](desugar/'named-programs-corpus.json', legacy)
    names = {i['group']+':'+i['name'] for i in legacy['inputs']}
    selected = desugar/'named-programs-interval'
    selected.mkdir(exist_ok=True)
    for filename in helper['SOURCE_FILES']:
        document = helper['read'](BASE/'manifest/manifest-interval'/filename)
        def keep(row):
            name = row.get('input') or (row['group']+':'+row['name'] if 'group' in row else row['name'])
            return name in names
        document['inputs'] = [row for row in document['inputs'] if keep(row)]
        helper['write'](selected/filename, document)
    args = ['--interval-dir', str(BASE), '--desugar-dir', str(desugar), '--coverage-dir', str(coverage)]
    roots = dict(interval=BASE.resolve(), desugar=desugar.resolve(), coverage=coverage.resolve())
    def artifact(action):
        subprocess.run([sys.executable, '-B', 'scripts/check/formal_interval.py', action, *args],
                       cwd=ROOT, check=True)
    if not (BASE/'input-manifest.json').exists():
        # 失敗した局所試行の途中出力だけを作り直す。実行用の入口は再利用を許さない。
        if (BASE/'programs').exists():
            shutil.rmtree(BASE/'programs')
        artifact('collect')
    command = [sys.executable, '-B', 'formal/tests/test_interval_exchange.py',
               '--output', str(BASE/'comparison'), '--source-dir', str(BASE/'identity')]
    for name in helper['SOURCE_DIRS']:
        command += ['--rust-dir', str(BASE/name)]
    command += ['--vm-dir', str(BASE/'vm')]
    subprocess.run(command, cwd=ROOT, check=True)
    subprocess.run([sys.executable, '-B', 'crates/benitoite/tests/desugar_export/check_batch3.py',
                    '--rust-dir', str(desugar/'batch3/g2'),
                    '--report', str(desugar/'batch3/g2-exchange-results.json')], cwd=ROOT, check=True)
    artifact('manifest')
    artifact('verify')
    # 実際に作った manifest に対し、報告の改変と欠落、入力の改変を順に検査する。
    for path in (BASE/'comparison/vm/vm-summary.json', BASE/'identity/reader-corpus.json'):
        original = path.read_bytes()
        for mutation in ('change', 'remove'):
            if mutation == 'change':
                path.write_bytes(original+b' ')
            else:
                path.unlink()
            try:
                helper['verify'](roots)
            except AssertionError as error:
                print(json.dumps(dict(path=path.as_posix(), mutation=mutation, rejected=str(error))))
            else:
                raise AssertionError('changed artifact accepted')
            finally:
                path.write_bytes(original)
    helper['verify'](roots)
    saved_manifest = BASE/'manifest.json'
    original = saved_manifest.read_bytes()
    changed = json.loads(original)
    changed['counts']['vm']['arithmetic'] += 1
    helper['write'](saved_manifest, changed)
    try:
        helper['verify'](roots)
    except AssertionError as error:
        print(json.dumps(dict(mutation='count', rejected=str(error))))
    else:
        raise AssertionError('wrong count accepted')
    finally:
        saved_manifest.write_bytes(original)
    helper['verify'](roots)


if __name__ == '__main__':
    main()
