import json, sys, collections, runpy
# 使い方: python3 tally.py <前の jsonl> [<後の jsonl>]。原因の分類は formal/tests/test_range_sources.py の preparation_gaps。
from pathlib import Path
ROOT = Path(__file__).resolve().parents[5]
G = runpy.run_path(str(ROOT / 'formal/tests/test_range_sources.py'))['preparation_gaps']
def load(p):
    rows=[json.loads(l) for l in open(p) if l.startswith('{')]
    inputs=[r for r in rows if 'name' in r]; docs=[r for r in rows if 'document' in r]
    return inputs, docs
def summary(p):
    inputs, docs = load(p)
    passed=sum(r['error'] is None for r in inputs); rej=[r for r in inputs if r['error'] is not None]
    causes=collections.Counter(); other=[]
    for r in rej:
        g=G(r['error'])
        if g is None: other.append((r['doc'],r['name'],r['error'][:120])); continue
        for c in g['causes']: causes[c]+=1
    return {'documents': len({r['doc'] for r in rows_all(p)}), 'inputs': len(inputs), 'passed': passed, 'rejected': len(rej),
            'causes': dict(causes), 'unclassified': other, 'documentErrors': [(d['doc'], d['document']) for d in docs],
            'closureAdded': sum(bool(r.get('added')) for r in inputs), 'closureRemoved': sum(bool(r.get('removed')) for r in inputs),
            'builtinPredicate': sum(bool(r.get('builtinPredicate')) for r in inputs)}
def rows_all(p): return [json.loads(l) for l in open(p) if l.startswith('{')]
out={k: summary(v) for k, v in zip(['base','new'], sys.argv[1:])}
if len(sys.argv) > 2:
    b={(r['doc'],r['group'],r['name']): r for r in load(sys.argv[1])[0]}
    n={(r['doc'],r['group'],r['name']): r for r in load(sys.argv[2])[0]}
    out['changed']=[[k, b[k]['error'], n[k]['error']] for k in n if k in b and b[k]['error']!=n[k]['error']]
    out['missing']=[k for k in b if k not in n]
    added=collections.Counter(x for r in n.values() for x in (r.get('added') or []))
    out['addedData']=dict(added)
print(json.dumps(out, ensure_ascii=False, indent=1))
