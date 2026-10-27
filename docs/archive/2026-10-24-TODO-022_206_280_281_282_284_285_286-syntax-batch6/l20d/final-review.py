"""最終検査前後の入力・固定表・相対リンク・記録のパスを照合する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode()


paths = set(git('ls-files', 'formal', 'crates/benitoite/testdata/interval-budget').splitlines())
paths.update(str(file.relative_to(ROOT)) for file in (ROOT / 'formal/Benitoite/Interval').glob('*.lean'))
paths.update(['docs/design/01-spec/01-12-core-calculus.md',
              'docs/design/07-quality/07-04-formal-semantics.md'])
hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in sorted(paths)}
if sys.argv[1] == 'before':
    (OUT / 'final-inputs-before.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(f'最終検査前の入力 {len(hashes)} ファイルを保存した。')
    raise SystemExit(0)
assert hashes == json.loads((OUT / 'final-inputs-before.json').read_text()), '検査後に実装入力が変わっている'
links = re.findall(r'\[[^\]]+\]\(([^)]+)\)', (OUT / 'results.md').read_text())
for link in links:
    assert (OUT / link.split('#')[0]).exists(), link
absolute_paths = []
for file in OUT.rglob('*'):
    if not file.is_file() or '__pycache__' in file.parts:
        continue
    text = file.read_text()
    if str(ROOT) in text or str(Path.home()) in text:
        absolute_paths.append(str(file.relative_to(ROOT)))
assert not absolute_paths, absolute_paths
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = {'base': '8a59b630f9fdef8d1e1595f7999c6242d167d739',
          'head': git('rev-parse', 'HEAD').strip(),
          'before_after_inputs_equal': True, 'inputs_sha256': hashes,
          'results_relative_links_exist': len(links),
          'local_absolute_paths_in_records': absolute_paths, 'git_diff_check': 0}
(OUT / 'final-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({key: value for key, value in record.items() if key != 'inputs_sha256'}, ensure_ascii=False))
