"""ローカルの import を依存順に一モジュールずつビルドする。"""
from pathlib import Path
import importlib.util, sys, time, fcntl, tempfile
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2] / 'formal'
spec = importlib.util.spec_from_file_location('process_control', OUT / 'process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
# 手動の起動でも Lean の検査を重ねない。取得できなければ直ちに拒否する。
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit('別の L20d Lean 検査が実行中のため起動しない')
seen, order = set(), []
def visit(name):
    if name in seen:
        return
    seen.add(name)
    path = ROOT / (name.replace('.', '/') + '.lean')
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        if line.startswith('import '):
            for dependency in line[7:].split():
                visit(dependency)
    order.append(name)
if len(sys.argv) > 1:
    for name in sys.argv[1:]:
        visit(name)
else:
    for path in sorted(ROOT.rglob('*.lean')):
        if '.lake' not in path.parts and 'docs' not in path.parts:
            visit('.'.join(path.relative_to(ROOT).with_suffix('').parts))
started = time.monotonic()
with (OUT / 'sequential-build.log').open('a') as log:
    for name in order:
        log.write('\n$ lake build ' + name + '\n')
        log.flush()
        before = time.monotonic()
        # 実績の五倍を上限とする。ほかのモジュールも五分で止めて原因を調べる。
        timeout = {'Benitoite.Interval.Examples': 30,
                   'Benitoite.Interval.Sound': 175}.get(name, 300)
        result = control.run(['lake', 'build', name], cwd=ROOT, timeout=timeout)
        log.write(result.stdout.replace(str(ROOT.parent), '<repo>').replace(str(Path.home()), '<home>').replace(tempfile.gettempdir(), '<tmp>').replace('/tmp/', '<tmp>/'))
        log.write(f'\nexit={result.returncode}, seconds={time.monotonic() - before:.3f}\n')
        log.flush()
        if result.returncode:
            print(f'FAILED {name}', flush=True)
            raise SystemExit(result.returncode)
print(f'OK: {len(order)} modules, {time.monotonic() - started:.3f} seconds', flush=True)
