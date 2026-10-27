"""作業末の処理系・テスト・設計書入力を固定する。"""
import hashlib
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
paths = subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
paths += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], text=True).splitlines()
inputs = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in sorted(set(paths)) if not p.startswith(str(HERE.relative_to(Path.cwd()))) and Path(p).is_file()}
(HERE / 'work-inputs-sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
print(len(inputs), 'inputs')
