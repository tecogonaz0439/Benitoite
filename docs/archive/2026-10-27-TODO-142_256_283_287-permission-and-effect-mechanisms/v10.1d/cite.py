# -*- coding: utf-8 -*-
"""V10.1d: 入力が K10.3 と同じ段の出力を、K10.3 の合成の状態から新しい出力先へ複写する（読者を走らせ直さない段の引用）。"""
import hashlib, json, shutil, sys
from pathlib import Path

REGENERATED = ('range-source-comparison/', 'range-known-differences/')  # 走らせ直す段の出力は写さない

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

target = Path(sys.argv[1]); compare = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8')); out = Path(sys.argv[3])
roots = {
    'desugar': (target / 'desugar-diff/v10.1d', [target / 'desugar-diff/k10.3-reexport', target / 'desugar-diff/k10.3']),
    'coverage': (target / 'coverage-diff/v10.1d', [target / 'coverage-diff/k10.3']),
}
rows = []
for name, (new_root, old_roots) in roots.items():
    for rel in compare[name]['missing']:
        if rel.startswith(REGENERATED):
            continue
        src = next(r / rel for r in old_roots if (r / rel).is_file())  # 再出力を先に探す
        dst = new_root / rel
        if dst.exists():
            raise SystemExit('already exists: ' + str(dst))
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        h = digest(dst)
        if h != digest(src):
            raise SystemExit('copy mismatch: ' + rel)
        rows.append(dict(tree=name, path=rel, source=str(src.relative_to(target)), bytes=dst.stat().st_size, sha256=h))
out.write_text(json.dumps(dict(copied=len(rows), bytes=sum(r['bytes'] for r in rows), files=rows), ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
print('copied', len(rows), 'bytes', sum(r['bytes'] for r in rows))
