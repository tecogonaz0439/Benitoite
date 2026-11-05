"""証拠のlookup前提・固定Pと閉包の文脈の全件照合を集計する。"""
import argparse
from collections import Counter
import json
import re
from pathlib import Path
from inventory import HERE, digest, write
from ledger import pages


def collect(log):
    text = log.read_text()
    assert not re.search(r'error(?:\(|:)|warning:|sorryAx', text)
    rows = [json.loads(line[8:]) for line in text.splitlines() if line.startswith('CONTEXT ')]
    refs = [json.loads(line[18:]) for line in text.splitlines() if line.startswith('SOURCE_REFERENCES ')]
    bodies = json.loads((HERE / 'resume3-body-sources.json').read_text())
    classes = json.loads((HERE / 'resume3-body-classification.json').read_text())
    assert len(refs) == len(bodies) == 130
    assert {r['body'] for r in refs} == {r['constructor'] for r in bodies}
    bybody = {r['constructor']: r for r in bodies}
    for r in refs:
        assert r['references'] == bybody[r['body']]['references']
        assert not any(n.startswith('%') for n in r['references']), r['body']
    counts = Counter(r['kind'] for r in rows)
    assert counts == {'lookupなどの副条件付き': 51, '固定のP/B': 77}
    assert {r['body'] for r in rows} == {r['body'] for r in classes if r['kind'] != '任意のP/B'}
    for r in rows:
        assert r['context'] == bybody[r['body']]['context']
        assert all(x['equal'] is True for x in r['lookups']), r['body']
    # 証拠が関数を参照しない行も記録する。全称の副条件は有限添字を展開して照合する。
    result = {'counts': dict(counts), 'source_bodies': 130,
        'source_reference_occurrences': sum(len(r['references']) for r in refs),
        'internal_source_references': 0, 'mismatches': 0,
        'lookup_comparisons': sum(len(r['lookups']) for r in rows),
        'comparisons_by_kind': {kind: sum(len(r['lookups']) for r in rows if r['kind'] == kind) for kind in counts},
        'no_lookup_by_kind': {kind: sum(not r['lookups'] for r in rows if r['kind'] == kind) for kind in counts},
        'rows': pages('resume4-evidence-context', rows), 'references': pages('resume4-source-references', refs),
        'inputs': {name: digest(HERE / name) for name in ['evidence-context.lean', 'resume3-body-sources.json', 'resume3-body-classification.json']},
        'raw': digest(log), 'execution': json.loads((HERE / 'resume4-context.json').read_text())}
    assert result['lookup_comparisons'] == 114
    assert result['comparisons_by_kind'] == {'lookupなどの副条件付き': 101, '固定のP/B': 13}
    names = re.findall(r'^LOCAL_AUDIT (.+)$', text, re.M)
    axioms = re.findall(r"^'(.*?)' depends on axioms: \[([^]]*)\]", text, re.M)
    assert Counter(names) == Counter(n for n, _ in axioms)
    assert all({s.strip() for s in deps.split(',') if s.strip()} <= {'propext', 'Quot.sound', 'Classical.choice'} for _, deps in axioms)
    result['local_audit'] = {'declarations': len(names), 'names': names, 'new_axioms': 0, 'sorryAx': 0}
    write(HERE / 'resume4-context-summary.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', type=Path, required=True)
    result = collect(parser.parse_args().log)
    print(json.dumps({k: result[k] for k in ['counts', 'source_bodies', 'lookup_comparisons', 'comparisons_by_kind', 'mismatches', 'internal_source_references']}, ensure_ascii=False))
