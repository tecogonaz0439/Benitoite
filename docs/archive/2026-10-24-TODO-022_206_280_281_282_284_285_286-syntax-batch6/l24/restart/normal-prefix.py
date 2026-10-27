from pathlib import Path
import fcntl
import sys
import tempfile
import run
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
source = run.ROOT / 'formal/Benitoite/Interval/BudgetNormal.lean'
probe = Path(tempfile.gettempdir()) / 'benitoite-l24-normal-prefix.lean'
probe.write_text(source.read_text().split('-- 補助解析を同時')[0] + '\nend Benitoite.Interval.BudgetAnalysis\n')
raise SystemExit(run.run(sys.argv[1], ['lake', 'env', 'lean', '-M', '6144', str(probe)], run.ROOT / 'formal', 300))
