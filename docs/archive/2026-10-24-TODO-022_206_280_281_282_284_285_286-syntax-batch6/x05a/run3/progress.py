"""進行中のログの末尾と出力容量だけを読む。検査を追加で起動しない。"""
import datetime
import json
from pathlib import Path
import shutil
import subprocess
import re
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
log = (HERE/'k1.log').read_text()
phases = [line for line in log.splitlines() if line.startswith('== formal:')]
record = dict(time=datetime.datetime.now().astimezone().isoformat(),phase=phases[-1] if phases else None,
              freeBytes=shutil.disk_usage('/').free, completed=(HERE/'k1.json').exists(),tail=[line[:800] for line in log.splitlines()[-4:]])
comparison = ROOT/'target/interval-diff/x05a-k1-run3-20261027/comparison'
record['sourceReports'] = {p.name: sum(bool(re.fullmatch(r'source-analysis-[0-9]+\.report\.json', q.name))
                                     for q in p.glob('source-analysis-*.report.json'))
                           for p in sorted(comparison.glob('real-source-*')) if p.is_dir()}
for name in ['interval','desugar','coverage']:
    path = ROOT/'target'/(name+'-diff')/'x05a-k1-run3-20261027'
    if path.exists():
        record[name+'KiB'] = int(subprocess.check_output(['du','-sk',str(path)],text=True).split()[0])
with (HERE/'progress.jsonl').open('a') as stream:
    stream.write(json.dumps(record,ensure_ascii=False)+'\n')
print(json.dumps(record,ensure_ascii=False))
