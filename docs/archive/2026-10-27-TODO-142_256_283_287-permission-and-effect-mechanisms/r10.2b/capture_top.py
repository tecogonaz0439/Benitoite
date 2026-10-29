"""同じ入力のCLI出力・終了と旧版交換ファイルのハッシュを保存する。"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).parent
binary = Path('target/debug/benitoite')
rows = []
for group in ['effects', 'handlers']:
    for source in sorted(Path('crates/benitoite/testdata', group).glob('*.bnt')):
        for options in [['--diagnostics=text'], ['--diagnostics=json'], ['--report=json']]:
            command = [str(binary), 'check', *options, str(source)]
            result = subprocess.run(command, capture_output=True, check=False)
            def normalize(data):
                return data.decode().replace(os.getcwd(), '<wt>').replace(os.path.expanduser('~'), '<home>')
            rows.append({'input': str(source), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'options': options, 'exit': result.returncode,
                'stdout': normalize(result.stdout), 'stderr': normalize(result.stderr)})
output = root / (sys.argv[1] + '.json')
output.write_text(json.dumps({'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
    'cases': rows}, ensure_ascii=False, indent=2) + '\n')
print(len(rows), 'CLI cases saved')
