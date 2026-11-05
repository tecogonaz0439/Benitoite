"""552出典行を展開し、Leanの同名Def比較から全衝突と名前の対応を再生成する。"""
import argparse
from collections import defaultdict
import json
import re
from inventory import HERE, write, digest
from ledger import lean_rows, branches, pages


def sources():
    rows = lean_rows()
    aliases = {json.loads(v): k for k, v in branches('StandardAliasBodies.lean', 'API.name').items()}
    for r in rows:
        expression = None
        n, g = r['lean_name'], r['group']
        if r['category'] == 'body':
            if g == 1:
                if any('StandardAliasBodies' in p for p in r['evidence']):
                    expression = f'(StandardAliasBodies.API.{aliases[n]}.row).definition'
                elif n in ['List.map', 'List.filter']:
                    expression = f'(StandardBodies.listHigherRow {str(n.endswith("filter")).lower()}).definition'
                elif n.startswith(('Map.', 'Set.')) and n.split('.')[-1] in ['map', 'filter']:
                    expression = f'(StandardBodies.collectionHigherRow {str(n.startswith("Map.")).lower()} {str(n.endswith("filter")).lower()}).definition'
                else:
                    expression = f'StandardOrdinaryCoreProgram.program.defs {json.dumps(n)}'
            elif g == 11:
                expression = r['expression'] + '.definition'
            elif g == 12:
                expression = r['expression'] + '.row.definition'
            elif g == 13:
                expression = f'StandardCollectionRefinedBodies.program.defs {json.dumps(n)}'
            elif g == 15:
                index = int(r['expression'].split('[')[1][:-1])
                expression = f'(StandardOrdinaryCoreProgram.allDefinitions[{index}]?).map Prod.snd'
            assert expression, r
        r['original_def'] = expression
    assert len(rows) == 552
    return rows


def analyze(log):
    rows = sources()
    bodies = [r for r in rows if r['original_def']]
    byid = {r['id']: r for r in bodies}
    parent = {r['id']: r['id'] for r in bodies}
    pairs = [line.split()[1:] for line in log.read_text().splitlines() if line.startswith('COMPARE ')]
    expected = {(x['id'], y['id']) for i, x in enumerate(bodies) for y in bodies[:i]
                if x['lean_name'] == y['lean_name']}
    assert {(p[0], p[1]) for p in pairs} == expected and len(pairs) == len(expected)

    def root(k):
        while parent[k] != k:
            k = parent[k]
        return k

    for x, y, same, body, inputs in pairs:
        assert {same, body, inputs} <= {'true', 'false'}
        if same == 'true':
            assert body == inputs == 'true'
            parent[root(x)] = root(y)
    byname = defaultdict(lambda: defaultdict(list))
    for r in bodies:
        byname[r['lean_name']][root(r['id'])].append(r['id'])
    collisions = []
    for name, defs in byname.items():
        if len(defs) == 1:
            continue
        assert len(defs) == 2
        # 精密側が先に現れるList.mapFromでも通常側/精密側を逆にしない。
        groups = sorted(defs.values(), key=lambda ids: byid[ids[0]]['group'] in [12, 13])
        x, y = groups[0][0], groups[1][0]
        pair = next(p for p in pairs if set(p[:2]) == {x, y})
        assert pair[2] == 'false'
        collisions.append({'public_name': name, 'sources': groups,
            'definitions': [byid[x]['original_def'], byid[y]['original_def']],
            'internal_names': ['%' + name + '.ordinary', '%' + name + '.refined'],
            'bodies_differ': pair[3] == 'false', 'inputs_differ': pair[4] == 'false'})
    assert len(bodies) == 159 and len(collisions) == 17
    write(HERE / 'collisions.json', collisions)
    summary = {'source_rows': len(rows), 'body_source_rows': len(bodies),
        'nonbody_source_rows': len(rows) - len(bodies), 'same_name_source_pairs': len(pairs),
        'equal_def_pairs': sum(p[2] == 'true' for p in pairs),
        'different_def_source_pairs': sum(p[2] == 'false' for p in pairs),
        'collision_groups': len(collisions), 'body_differences': sum(c['bodies_differ'] for c in collisions),
        'input_differences': sum(c['inputs_differ'] for c in collisions),
        'distinct_body_defs': len({root(r['id']) for r in bodies}),
        'source_comparison_log': digest(log), 'collisions': digest(HERE / 'collisions.json')}
    write(HERE / 'collision-summary.json', summary)
    return rows, collisions


def proofs(collisions, log):
    byid = {r['id']: r for r in sources() if r['original_def']}
    text = "import Lean\nimport Benitoite\nnamespace Benitoite.RefinementContractCollisions\nopen Benitoite.Release.Refinement\n"
    text += """private def firstCall : Comp → String
  | .letIn m _ => firstCall m
  | .app (.fnRef name _ _) _ => name
  | .app (.prim name _ _ _) _ => name
  | _ => ""
"""
    for c in collisions:
        left, right = ['(' + e + ')' for e in c['definitions']]
        for field, projection in [('bodies', 'body'), ('inputs', 'params')]:
            different = c[field + '_differ']
            name = c['public_name'].replace('.', '_') + '_' + field
            text += f"theorem {name} :\n    {left}.map Def.{projection} " + ('≠' if different else '=')
            text += f"\n    {right}.map Def.{projection} := by\n"
            if not different:
                text += "  rfl\n"
            elif field == 'bodies' and c['public_name'] in ['NonEmptyList.map', 'List.mapFrom']:
                x, y = ('Benitoite.NonEmptyList.NonEmptyList.first', 'List.map') if c['public_name'] == 'NonEmptyList.map' else ('List.get', 'List.head')
                text += f'''  intro equal
  have names := congrArg (Option.map firstCall) equal
  change some "{x}" = some "{y}" at names
  have different : (some "{x}" : Option String) ≠ some "{y}" := by decide
  exact different names
'''
            else:
                text += "  intro equal\n  cases equal\n"
            text += "\n"
    for i, line in enumerate(log.read_text().splitlines()):
        if not line.startswith('COMPARE '):
            continue
        x, y, same, _, _ = line.split()[1:]
        if same == 'true':
            text += f"theorem duplicate_{i} : ({byid[x]['original_def']}) = ({byid[y]['original_def']}) := rfl\n"
    text += "end Benitoite.RefinementContractCollisions\n"
    (HERE / 'all-contract-collisions.lean').write_text(text + (HERE / 'local-axiom-audit.txt').read_text())


def annotate(rows, collisions):
    names = {source: name for c in collisions for ids, name in zip(c['sources'], c['internal_names']) for source in ids}
    for r in rows:
        r['public_name'] = r['lean_name']
        r['internal_name'] = names.get(r['id'], r['lean_name'])
        r['internal_name_status'] = '対応先のキー。合成先lookup/型付けの完成は未証明'
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    oldrows = [r for p in summary['evidence_pages'] for r in json.loads((HERE / p['file']).read_text())]
    for r, old in zip(rows, oldrows):
        assert r['id'] == old['id']
        r['ledger'], r['rust_names'] = old['ledger'], old['rust_names']
    ledger = [r for p in summary['ledger_pages'] for r in json.loads((HERE / p['file']).read_text())]
    for entry in ledger:
        matches = [r for r in rows if r['ledger'] == entry['id']]
        entry['internal_names'] = sorted({r['internal_name'] for r in matches})
        entry['name_correspondence'] = [{'source': r['id'], 'public_name': r['public_name'],
            'internal_name': r['internal_name'], 'original_def': r['original_def'], 'evidence': r['evidence']}
            for r in matches]
        if matches:
            entry['status'] = '対応先キーを固定。元本体内の参照名の衝突で合成未完'
    summary['evidence_pages'] = pages('evidence', rows)
    summary['ledger_pages'] = pages('ledger', ledger)
    summary['verified_lookup_collisions'] = [c['public_name'] for c in collisions]
    summary['planned_composition_keys'] = len({r['internal_name'] for r in rows})
    summary['name_correspondence_rows'] = len(rows)
    summary['name_correspondence_complete'] = True
    summary['composition_complete'] = False
    write(HERE / 'ledger-summary.json', summary)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--log', type=__import__('pathlib').Path)
    args = parser.parse_args()
    if args.prepare:
        write(HERE / 'def-sources.json', [{k: r[k] for k in ['id', 'lean_name', 'original_def', 'evidence']}
                                         for r in sources() if r['original_def']])
    else:
        assert args.log
        rows, collisions = analyze(args.log)
        proofs(collisions, args.log)
        annotate(rows, collisions)
        print((HERE / 'collision-summary.json').read_text())
