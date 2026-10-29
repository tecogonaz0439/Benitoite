import collections
import json
from pathlib import Path
root = Path(__file__).parent
rows = json.loads((root / 'name-readers.json').read_text())
diags = json.loads((root / 'diagnostics.json').read_text())
semantic = {
    'src/bytecode/codegen/tables.rs': {274, 279},
    'src/cli/inspection.rs': {72, 94},
    'src/ir/check.rs': {1326},
    'src/typeck/decls.rs': {328},
    'src/typeck/effects/declarations.rs': {113, 132, 153, 259, 348, 400},
    'src/typeck/effects/handle.rs': {77},
    'src/typeck/external.rs': {40, 48},
    'src/typeck/solve.rs': {2265},
    'src/types/mod.rs': {773, 781, 786, 789},
    'tests/declarations.rs': {611},
    'tests/desugar_export/exchange.rs': {385, 386, 2774, 2796},
}
for r in rows:
    file = r['file'].removeprefix('crates/benitoite/')
    r['class'] = 'comment' if r['comment'] else ('semantic' if r['line'] in semantic.get(file, set()) else 'mechanical')
    r['diagnostics'] = sorted({d[0] for d in diags if d[1] == r['file'] and d[2] == r['line']})
(root / 'name-readers.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
lines = ['| File | Mechanical | Semantic | Comment | Unique declarations | Diagnostic codes |', '|---|---:|---:|---:|---:|---|']
for f in sorted({r['file'] for r in rows}):
    rs = [r for r in rows if r['file'] == f]
    c = collections.Counter(r['class'] for r in rs)
    codes = sorted({d[0] for d in diags if d[1] == f})
    lines.append(f"| `{f.removeprefix('crates/benitoite/')}` | {c['mechanical']} | {c['semantic']} | {c['comment']} | {len({r['declaration'] for r in rs})} | {', '.join(codes) or '-'} |")
lines += ['', '| File / declaration | Mechanical | Semantic | Lines (diagnostic codes) |', '|---|---:|---:|---|']
for f, decl in sorted({(r['file'], r['declaration']) for r in rows if not r['comment']}):
    rs = [r for r in rows if r['file'] == f and r['declaration'] == decl and not r['comment']]
    c = collections.Counter(r['class'] for r in rs)
    refs = ', '.join(f"{r['line']}({','.join(r['diagnostics']) or '-'})" for r in rs)
    lines.append(f"| `{f.removeprefix('crates/benitoite/')}` / `{decl}` | {c['mechanical']} | {c['semantic']} | {refs} |")
text = '\n'.join(lines) + '\n'
for a, b in [('File / declaration','ファイル／宣言'), ('File','ファイル'), ('Mechanical','機械'), ('Semantic','意味'), ('Comment','コメント'), ('Unique declarations','一意の宣言'), ('Diagnostic codes','診断の種類'), ('Lines (diagnostic codes)','基準行（診断の種類）')]:
    text = text.replace(a, b)
(root / 'reader-tables.md').write_text(text)
for area in ['src', 'tests']:
    rs = [r for r in rows if '/' + area + '/' in r['file']]
    print(area, dict(collections.Counter(r['class'] for r in rs)))
