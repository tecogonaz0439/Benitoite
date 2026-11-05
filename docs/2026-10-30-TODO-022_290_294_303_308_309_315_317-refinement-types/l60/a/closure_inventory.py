"""全本体出典から元lookupを推移的に追った閉包と、同名の異Defを照合する。"""
import argparse
from collections import defaultdict
from datetime import datetime
import json
from pathlib import Path
from inventory import HERE, digest, write
from ledger import pages


def collect(log):
    rows = [json.loads(line[8:]) for line in log.read_text().splitlines() if line.startswith('CLOSURE ')]
    seeds = json.loads((HERE/'resume3-closure-seeds.json').read_text())
    assert len(seeds) == 159
    assert {r['source'] for r in rows[:159]} == {r['id'] for r in seeds}
    lookups = {(r['context'], r['name']): r for r in rows if r['source'].startswith('helper:')}
    unique, names, edges = {}, defaultdict(set), defaultdict(set)
    for row in rows:
        unique.setdefault(row['key'], row)
        names[row['name']].add(row['key'])
        for name in row['references']:
            target = lookups[row['context'], name]
            edges[row['key'], name].add(target['key'])
    # 一つの元Defが、同じ参照名について異なる元Defを要求していないかを全件照合する。
    incompatible = [{'parent': k, 'name': n, 'targets': sorted(v)}
                    for (k,n),v in edges.items() if len(v) != 1]
    renamed = sorted(n for n, ks in names.items() if len(ks)>1)
    result = {'body_sources': len(seeds), 'visited_rows': len(rows), 'distinct_original_defs': len(unique),
        'additional_helper_defs': [r for r in rows[159:] if r['fresh']],
        'renamed_count': len(renamed), 'renamed_names': renamed,
        'same_original_reference_conflicts': incompatible,
        'distinct_edges': len(edges), 'lookup_contexts': sorted({r['context'] for r in rows}),
        'rows': pages('resume3-closure-graph', rows),
        'edges': pages('resume3-closure-edges', [{'parent': k, 'name': n, 'target': next(iter(v))}
                        for (k,n),v in edges.items() if len(v)==1]),
        'raw': digest(log),
        'status': '閉包と参照先の一意性を全件照合。型付けは別検査'}
    assert not incompatible, incompatible
    assert len(unique)==130 and len(renamed)==18
    write(HERE/'resume3-closure-summary.json', result)
    return result

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--log',type=Path,required=True)
    result=collect(ap.parse_args().log)
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','edges','additional_helper_defs']},ensure_ascii=False))
