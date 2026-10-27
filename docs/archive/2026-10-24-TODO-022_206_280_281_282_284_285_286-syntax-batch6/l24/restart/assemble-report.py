"""再開の報告へ一回採取した表と最初の起動の記録を組み込む。"""
from pathlib import Path
import json, re
import run

current = (run.OUT.parent / 'results.md').read_text()
history = current.split('## 最初の起動の確認\n', 1)[1]
# 最初の起動の節を再開後の結論と混同しないよう、見出しを一段下げる。
history = re.sub(r'(?m)^(#{2,}) ', lambda match: '#' + match.group(1) + ' ', history)
history = '## 最初の起動の確認\n\n以下は再開前の記録であり、この時点の「未完」と「不変」は最初の起動を指す。\n\n' + history

impact = json.loads((run.OUT / 'reference-impact.json').read_text())
tables = '| 表 | 保存済み行数 | 新しい選択行数 | 同じキーの変更 | 追加 |\n|---|---:|---:|---:|---:|\n'
for name, result in impact.items():
    tables += f"| {name} | {result['old_rows']} | {result['new_rows']} | {sum(v['changed'] for v in result['shapes'].values())} | {sum(v['added'] for v in result['shapes'].values())} |\n"
tables += '\n| body の入力形 | 最小完走予算の旧→新（kind 0/1/2/3） | 変更行 | 追加行 | 変更列 |\n|---|---|---:|---:|---|\n'
for shape, details in impact['body']['shapes'].items():
    caps = '/'.join(map(str, details['old_success_caps'])) + ' → ' + '/'.join(map(str, details['new_success_caps']))
    tables += f"| {shape} | {caps} | {details['changed']} | {details['added']} | {', '.join(details['columns'])} |\n"
tables += '\n| 表 | 入力形 | 変更行 | 追加行 | 変更列 |\n|---|---|---:|---:|---|\n'
for name in ['whole', 'summary']:
    for shape, details in impact[name]['shapes'].items():
        tables += f"| {name} | {shape} | {details['changed']} | {details['added']} | {', '.join(details['columns'])} |\n"

report = (run.OUT / 'report.md').read_text().replace('FIXTURE_TABLES', tables).replace('HISTORY', history)
(run.OUT.parent / 'results.md').write_text(report.rstrip()+'\n')
