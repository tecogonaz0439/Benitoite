"""指定された作業末の共通検査を一度実行し、生の出力は一時領域、要点は群の記録へ保存する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def main():
    target = HERE / 'work-r6.json'
    assert not target.exists(), '既に実行記録があるため再実行しない'
    command = ['scripts/check.sh', '--level', 'work', '--base', '548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8']
    raw = Path(tempfile.gettempdir()) / 'benitoite-l40e6' / 'work-r6.log'
    raw.parent.mkdir(parents=True, exist_ok=True)
    started = datetime.now(timezone.utc)
    clock = time.monotonic()
    with raw.open('wb') as output:
        run = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    result = {'command': command, 'start_utc': started.isoformat(),
        'end_utc': datetime.now(timezone.utc).isoformat(), 'seconds': time.monotonic() - clock,
        'exit': run.returncode, 'raw': {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()},
        'raw_location': '<tmp>/benitoite-l40e6/work-r6.log'}
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(run.returncode)

if __name__ == '__main__':
    main()
