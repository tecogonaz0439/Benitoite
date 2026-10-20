"""Explicit shared graphs: Python counts nodes and edges without invoking the bridge."""
import json
from model import Case, common, EMPTY


def graph(shape, n):
    if shape == 'shared':
        # Each constructor has two edges to the same predecessor; the leaf is immediate.
        nodes = [[i-1, i-1] if i else [] for i in range(n+1)]
    else:
        # Join small shared trees into a chain. Exactly n heap constructors, not depth n.
        nodes = [[i-1, max(0, i-2)] if i else [] for i in range(n)]
    return dict(nodes=nodes, root=len(nodes)-1, unique_nodes=len(nodes), edges=sum(map(len, nodes)))


def cases(quick=False, repeats=1, fixtures=None):
    result = []
    points = [('empty', 0), *(('shared', n) for n in ((4,) if quick else (8, 12, 16, 24))),
              *(('nodes', n) for n in ((4, 8) if quick else (16, 32, 64)))]
    for shape, n in points:
        g = dict(nodes=[], root=-1, unique_nodes=0, edges=0) if shape == 'empty' else graph(shape, n)
        cid = 'bridge-empty' if shape == 'empty' else f'bridge-{shape}-{n}'
        # The probe input is an adjacency list, making the independent graph part of the evidence.
        files = common(EMPTY, {'graph.json': json.dumps(g, sort_keys=True)+'\n'})
        result.append(Case(cid, '16.8', shape, n, files, command='probe', probe='bridge',
                           probe_arguments=(shape, str(n)), validator='probe',
                           state_requires=('after',) if shape == 'nodes' or (shape == 'shared' and n > 12) else (),
                           metrics=('bridge_to_heap', 'bridge_from_heap', 'bridge_time', 'allocated_bytes', 'unique_nodes'),
                           params=dict(shape=shape, unique_nodes=g['unique_nodes'], edges=g['edges'], observation=7 if n else 0)))
    return result


def short_point(case):
    return case.id == 'bridge-shared-8'
