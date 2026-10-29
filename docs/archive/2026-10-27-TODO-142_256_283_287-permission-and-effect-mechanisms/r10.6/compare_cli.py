"""採取した終了・入力ハッシュ・stdout・stderr を比較し、差を隠さず保存する。"""
import json
from pathlib import Path

record = Path(__file__).parent


def leaves(before, after, path=''):
    if type(before) is not type(after):
        return [dict(path=path, before=before, after=after)]
    if isinstance(before, dict):
        return [item for key in sorted(before.keys() | after.keys())
                for item in leaves(before.get(key), after.get(key), path + '/' + key)]
    if isinstance(before, list):
        count = [] if len(before) == len(after) else [dict(
            path=path + '/length', before=len(before), after=len(after))]
        return count + [item for i, (a, b) in enumerate(zip(before, after))
                        for item in leaves(a, b, path + '/' + str(i))]
    return [] if before == after else [dict(path=path, before=before, after=after)]


summaries = []
for group in ['cli', 'extra']:
    after = json.loads((record / (group + '-after.json')).read_text())['cases']
    for baseline in ['b0', 'bwork']:
        before = json.loads((record / (group + '-' + baseline + '.json')).read_text())['cases']
        assert len(before) == len(after)
        differences = []
        for a, b in zip(before, after):
            assert all(a[key] == b[key] for key in ['input', 'options', 'sha256', 'exit'])
            if a == b:
                continue
            changed = {}
            for stream in ['stdout', 'stderr']:
                if a[stream] == b[stream]:
                    continue
                try:
                    left, right = json.loads(a[stream]), json.loads(b[stream])
                except json.JSONDecodeError:
                    changed[stream] = dict(before=a[stream], after=b[stream])
                else:
                    changed[stream] = leaves(left, right)
            differences.append(dict(input=a['input'], options=a['options'], changed=changed))
        if baseline == 'bwork':
            assert not differences, 'B_WORK との差が残る'
        if group == 'cli' and baseline == 'b0':
            assert len(differences) == 3
            for row in differences:
                assert all('/intervalAnalysis/' in item['path']
                           for item in row['changed']['stdout'])
        if group == 'extra' and baseline == 'b0':
            assert len(differences) == 16
            names = {'unknown-scope', 'unknown-http', 'near-path', 'near-path-in'}
            for row in differences:
                if row['options'] == ['check', '--report=json']:
                    for item in row['changed']['stdout']:
                        path = item['path']
                        assert (path.startswith('/sources/') and path.endswith('/contentHash/value')) or (
                            Path(row['input']).stem in names and
                            path.startswith(('/diagnostics/0/helps/', '/diagnostics/0/notes/')))
                else:
                    assert Path(row['input']).stem in names
        summaries.append(dict(group=group, baseline=baseline, total=len(after),
                              accepted=sum(row['exit'] == 0 for row in after),
                              rejected=sum(row['exit'] != 0 for row in after),
                              equal=len(after) - len(differences), differences=differences))

(record / 'cli-comparison.json').write_text(json.dumps(summaries, ensure_ascii=False, indent=2) + '\n')
for row in summaries:
    print(row['group'], row['baseline'], '総数', row['total'], '差', len(row['differences']))
