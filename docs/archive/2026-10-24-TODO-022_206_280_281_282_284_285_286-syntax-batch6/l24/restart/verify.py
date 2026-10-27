"""同じ基準の選択確認と最終workを直列に実行する。"""
import fcntl,sys,tempfile
from pathlib import Path
import run
lock=open(Path(tempfile.gettempdir())/'benitoite-l20d-lean.lock','a')
fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
if sys.argv[1]=='dry-run':
    command=['scripts/check.sh','--level','work','--base',run.BASE,'--only',
             'formal_build,spec_examples,spec_tally','--dry-run']
elif sys.argv[1]=='work':
    command=['/usr/bin/time','-l',sys.executable,str(run.OUT/'work-check.py')]
else:raise SystemExit('未知の検査モード')
raise SystemExit(run.run(sys.argv[1],command,run.ROOT,300))
