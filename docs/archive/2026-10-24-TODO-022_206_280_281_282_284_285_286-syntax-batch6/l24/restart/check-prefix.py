"""土台の証明の前までを取り出し、補助定義と局所証明を単体で確かめる。"""
from pathlib import Path
import fcntl
import sys
import tempfile
import run
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
source = (run.ROOT / 'formal/Benitoite/Interval/Sound.lean').read_text()
mode = sys.argv[2] if len(sys.argv) > 2 else 'helpers'
markers = {'target': '/-- 既に先行順に平坦化した式列の番号付け。 -/',
           'normal': '/-- 出現の部分木が占める半開区間。',
           'location': 'private def Good',
           'helpers': 'set_option maxHeartbeats 800000 in\nmutual'}
prefix = source.split(markers[mode], 1)[0]

target = Path(tempfile.gettempdir()) / 'benitoite-l24-prefix.lean'
target.write_text(prefix + '\nend Benitoite.Interval\n')
raise SystemExit(run.run(sys.argv[1], ['lake', 'env', 'lean', '-M', '6144', str(target)], run.ROOT / 'formal', 175 if mode != 'helpers' else 300))
