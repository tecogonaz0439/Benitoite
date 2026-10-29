import json
from pathlib import Path
import re

root = Path('.')
directory = root / 'docs/2026-10-24-TODO-022_206_280_281_282-syntax-batch6/study'
reports = []
issues = []
for name in ('riders.md', 'riders-questions.md'):
    path = directory / name
    data = path.read_text()
    local_links = []
    for label, target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)', data):
        if target.startswith(('https://', 'http://')):
            continue
        dest = path.parent / target.split('#')[0]
        local_links.append({'target': target, 'exists': dest.exists()})
        if not dest.exists():
            issues.append(f'{name}: missing link: {target}')
        if 'todo/' in target:
            issues.append(f'{name}: link to docs/todo')
    if '/Users/' in data:
        issues.append(f'{name}: absolute home path')
    if any(line.rstrip() != line for line in data.splitlines()):
        issues.append(f'{name}: trailing whitespace')
    if not data.endswith('\n'):
        issues.append(f'{name}: missing final newline')
    reports.append({'file': str(path), 'lines': len(data.splitlines()), 'localLinks': local_links})
result = {'date': '2026-10-24', 'documents': reports, 'issues': issues,
          'note': '文書の静的確認のみ。ビルド・テスト・検査スクリプトは実行していない。'}
Path('work/m012/scratch/s2/document-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(bool(issues))
