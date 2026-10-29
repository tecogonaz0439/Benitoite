"""通常交換の全出力をファイルごとの大きさとSHA-256で比較する。"""
import hashlib
import json
from pathlib import Path
import shutil
import sys
root = Path(__file__).parent
folder = root / sys.argv[1]
rows = [{'path': str(p.relative_to(folder)), 'bytes': p.stat().st_size,
    'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in sorted(folder.rglob('*')) if p.is_file()]
(root / (sys.argv[1] + '-manifest.json')).write_text(json.dumps(rows, indent=2) + '\n')
print('files', len(rows), 'bytes', sum(r['bytes'] for r in rows))
if len(sys.argv) > 2 and sys.argv[2] == '--remove-generated':
    shutil.rmtree(folder)
