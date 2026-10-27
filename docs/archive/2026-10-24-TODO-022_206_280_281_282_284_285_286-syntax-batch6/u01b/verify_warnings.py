#!/usr/bin/env python3
"""受け渡された10入口で、取得済みの診断・終了の契約を再確認する。"""
import gzip
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('u01a_inventory', HERE.parent / 'u01a/inventory.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
spec2 = importlib.util.spec_from_file_location('u01b_inventory', HERE / 'inventory.py')
current = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(current)


def main():
    binary = Path(sys.argv[1]).resolve()
    expected_binary = json.loads((old.OUT / 'environment.json').read_text())['currentBinarySha256']
    binary_sha = old.sha(binary.read_bytes())
    deltas = json.loads((old.OUT / 'warning-deltas.json').read_text())
    assert len(deltas) == 10
    ids = {r['id'] for r in deltas}
    saved = {r['id']: r['current'] for r in
             (json.loads(line) for line in gzip.open(old.RECORDS / 'all-observations.jsonl.gz', 'rt'))
             if r['id'] in ids}
    inputs = {r['id']: r for r in current.inputs()}
    rows = []
    current.RECORDS.mkdir(parents=True, exist_ok=True)
    with gzip.open(current.RECORDS / 'warning-raw.jsonl.gz', 'wt') as stream:
        for delta in deltas:
            result = {'id': delta['id'], 'modes': {}}
            for strict in (False, True):
                mode = 'R' if strict else 'W'
                observed, raw = old.observe(binary, inputs[delta['id']], strict)
                stream.write(json.dumps({'id': delta['id'], 'mode': mode, **raw}, ensure_ascii=False) + '\n')
                for field in ('exit', 'acquired', 'warnings', 'errors', 'reportStatus'):
                    assert observed[field] == saved[delta['id']][mode][field], (delta['id'], mode, field)
                assert observed['exit'] == delta['new' + mode]
                assert len(observed['warnings']) == delta['newWarnings']
                result['modes'][mode] = observed
            rows.append(result)
    current.write(HERE / 'warning-check.json', {'binarySha256': binary_sha,
        'u01aBinarySha256': expected_binary,
        'inputs': len(rows), 'cliRuns': len(rows) * 2, 'differencesFromU01a': 0,
        'expectationChanges': [], 'rows': rows})
    print(json.dumps({'inputs': len(rows), 'cliRuns': len(rows) * 2, 'differences': 0}))


if __name__ == '__main__':
    main()
