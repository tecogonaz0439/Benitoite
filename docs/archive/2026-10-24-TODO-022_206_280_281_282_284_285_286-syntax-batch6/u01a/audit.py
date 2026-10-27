#!/usr/bin/env python3
"""固定した本文・生出力・索引の整合と記録の体裁を読み取りで確認する。"""
import ast
import collections
import gzip
import importlib.util
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('u01_inventory', HERE / 'inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def main():
    manifest = json.loads(inventory.MANIFEST.read_text())
    hosts = json.loads((HERE / 'hosts.json').read_text())
    support = json.loads((HERE / 'support-hosts.json').read_text())
    for row in hosts + support:
        assert inventory.sha((inventory.ROOT / row['path']).read_bytes()) == row['sha256'], row['path']
    for item in manifest['inputs']:
        path = inventory.ROOT / item['path']
        if path.is_file():
            assert inventory.sha(path.read_bytes()) == item['sha256'], item['id']
            for row in item.get('support', []):
                assert inventory.sha((path.parent / row['path']).read_bytes()) == row['sha256']
    counts = json.loads((HERE / 'all-counts.json').read_text())
    assert counts['manifestSha256'] == inventory.sha(inventory.MANIFEST.read_bytes())
    assert counts['inputs'] == len(manifest['inputs']) == 1217
    ids, summary = [], {}
    for path in sorted(HERE.glob('all-inputs-*.json')):
        for row in json.loads(path.read_text()):
            assert row['id'] not in summary
            summary[row['id']] = row
    with gzip.open(inventory.RECORDS / 'all-observations.jsonl.gz', 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            ids.append(row['id'])
            for version in ('b0', 'current'):
                for mode in ('W', 'R'):
                    observed = row[version][mode]
                    assert observed['acquired'], row['id']
                    compact = summary[row['id']][version][mode]
                    assert len(observed['warnings']) == compact['warnings']
                    assert len(observed['errors']) == compact['errors']
                    if mode == 'R':
                        assert all(d['severity'] == 'error' for d in observed['warnings'])
    assert ids == [item['id'] for item in manifest['inputs']]
    raw_count = sum(1 for _ in gzip.open(inventory.RECORDS / 'all-raw.jsonl.gz', 'rt'))
    assert raw_count == len(ids) * 4
    records = []
    for path in sorted(inventory.RECORDS.rglob('*')):
        if path.is_file():
            data = path.read_bytes()
            records.append({'path': str(path.relative_to(inventory.ROOT)), 'bytes': len(data),
                            'sha256': inventory.sha(data)})
    inventory.write(HERE / 'records-index.json', records)
    documents = [HERE / 'results.md', HERE.parent / 'u01/warnings.md']
    links = 0
    for path in documents:
        text = path.read_text()
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if '://' in target or target.startswith('#'):
                continue
            assert (path.parent / target.split('#')[0]).is_file(), (path.name, target)
            links += 1
        assert all(line == line.rstrip() for line in text.splitlines())
    for path in HERE.rglob('*'):
        if not path.is_file():
            continue
        assert path.stat().st_size <= 1_000_000, path.name
        if path.suffix == '.py':
            ast.parse(path.read_text())
        elif path.suffix == '.json':
            json.loads(path.read_text())
        data = path.read_bytes()
        assert str(inventory.ROOT).encode() not in data, path.name
        assert str(Path.home()).encode() not in data, path.name
    assert not subprocess.check_output(['git', 'diff', '--name-only'], cwd=inventory.ROOT)
    assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=inventory.ROOT)
    changed = list(filter(None, subprocess.check_output(
        ['git', 'ls-files', '--others', '--exclude-standard'], cwd=inventory.ROOT, text=True).splitlines()))
    prefix = str(HERE.parent.relative_to(inventory.ROOT)) + '/'
    assert all(name.startswith(prefix + 'u01a/') or name == prefix + 'u01/warnings.md' for name in changed)
    inventory.write(HERE / 'audit.json', {'hostFilesUnchanged': len(hosts) + len(support),
        'entryInputsUnchanged': len(ids), 'cliRuns': raw_count, 'allCliRunsAcquired': True,
        'recordFiles': len(records), 'recordBytes': sum(r['bytes'] for r in records),
        'relativeLinksChecked': links, 'trackedDiff': [], 'indexDiff': [],
        'changedRecords': changed})
    print(json.dumps({'hosts': len(hosts) + len(support), 'inputs': len(ids), 'runs': raw_count,
                      'recordFiles': len(records), 'links': links}))


if __name__ == '__main__':
    main()
