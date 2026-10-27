from pathlib import Path
import fcntl
import sys
import tempfile
import run
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
source = run.ROOT / 'formal/Benitoite/Interval/BudgetSound.lean'
probe = Path(tempfile.gettempdir()) / 'benitoite-l24-cause-prefix.lean'
probe.write_text(source.read_text().split('set_option maxHeartbeats')[0] + '\nend Benitoite.Interval.BudgetAnalysis\n')
raise SystemExit(run.run(sys.argv[1], ['lake', 'env', 'lean', '-M', '6144', str(probe)], run.ROOT / 'formal', 300))
