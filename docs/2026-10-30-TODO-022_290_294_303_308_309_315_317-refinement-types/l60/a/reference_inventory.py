"""全159本体出典の関数参照をLeanの構文から集計し、17名の写像の不足を記録する。"""
import argparse
from collections import Counter
import json
from inventory import HERE, digest, write
from ledger import pages


def collect(log):
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    evidence = [r for p in summary['evidence_pages'] for r in json.loads((HERE / p['file']).read_text())]
    bodies = {r['id']: r for r in evidence if r['original_def']}
    rows = []
    for line in log.read_text().splitlines():
        if line.startswith('REFERENCES '):
            _, source, raw = line.split(' ', 2)
            source_row = bodies[source]
            rows.append({'source': source, 'name': source_row['lean_name'],
                'internal_name': source_row['internal_name'], 'original_def': source_row['original_def'],
                'references': json.loads(raw)})
    assert len(rows) == len(bodies) == 159
    assert {r['source'] for r in rows} == set(bodies)
    unique = {}
    for row in rows:
        key = row['internal_name']
        if key in unique:
            assert unique[key]['references'] == row['references']
        else:
            unique[key] = row
    assert len(unique) == 129
    collisions = json.loads((HERE / 'collisions.json').read_text())
    renamed = {c['public_name'] for c in collisions}
    assert len(renamed) == 17 and 'List.filterFrom' not in renamed
    affected = [r for r in rows if any(n in renamed for n in r['references'])]
    helper_readers = [r for r in rows if 'List.filterFrom' in r['references']]
    assert {r['source'] for r in helper_readers} == {'E01.110', 'E13.002', 'E13.004'}
    direct_helper = [r for r in bodies.values() if r['lean_name'] == 'List.filterFrom']
    assert [r['id'] for r in direct_helper] == ['E13.002']
    record = {'source_rows': len(evidence), 'body_source_rows': len(rows),
        'distinct_body_defs': len(unique), 'source_rows_with_references': sum(bool(r['references']) for r in rows),
        'distinct_defs_with_references': sum(bool(r['references']) for r in unique.values()),
        'reference_occurrences_by_source': sum(len(r['references']) for r in rows),
        'reference_occurrences_by_distinct_def': sum(len(r['references']) for r in unique.values()),
        'renamed_names': sorted(renamed), 'sources_referencing_renamed_names': [r['source'] for r in affected],
        'distinct_defs_referencing_renamed_names': len({r['internal_name'] for r in affected}),
        'filter_helper_readers': helper_readers,
        'filter_helper_direct_sources': [r['id'] for r in direct_helper],
        'missing_ordinary_helper': 'StandardBodies.listFromDefinition true',
        'graph_pages': pages('resume2-reference-graph', rows), 'raw': digest(log),
        'status': '17名だけを変更する写像ではList.filterFromの二契約を分離できない。合成未完'}
    write(HERE / 'resume2-reference-summary.json', record)
    return record


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--log', type=__import__('pathlib').Path, required=True)
    r = collect(p.parse_args().log)
    print(json.dumps({k: v for k, v in r.items() if k not in ['filter_helper_readers', 'graph_pages']}, ensure_ascii=False))
