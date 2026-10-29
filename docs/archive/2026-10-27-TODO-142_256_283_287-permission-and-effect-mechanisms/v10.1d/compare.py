# -*- coding: utf-8 -*-
"""V10.1d: 新しい出力先と K10.3 の出力（再出力を重ねた合成の状態）をファイルごとの SHA-256 で比べる。"""
import hashlib, json, sys
from pathlib import Path

def digest(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

def tree(root):
    return {p.relative_to(root).as_posix(): p for p in root.rglob('*') if p.is_file()}

def main():
    target = Path(sys.argv[1]); out = Path(sys.argv[2])
    pairs = {
        'desugar': (target / 'desugar-diff/v10.1d', [target / 'desugar-diff/k10.3', target / 'desugar-diff/k10.3-reexport']),
        'coverage': (target / 'coverage-diff/v10.1d', [target / 'coverage-diff/k10.3']),
        'interval': (target / 'interval-diff/v10.1d', [target / 'interval-diff/k10.3']),
    }
    result = {}
    for name, (new_root, old_roots) in pairs.items():
        old = {}
        for r in old_roots:  # 後の根（再出力）が前の根を上書きする
            old.update(tree(r))
        new = tree(new_root)
        same, changed, added = [], [], []
        for rel, p in sorted(new.items()):
            if rel not in old:
                added.append(rel)
            elif digest(p) == digest(old[rel]):
                same.append(rel)
            else:
                changed.append(rel)
        missing = sorted(set(old) - set(new))
        result[name] = dict(newFiles=len(new), oldFiles=len(old), same=len(same), changed=changed,
                            added=added, missing=missing)
        print(name, 'new', len(new), 'old', len(old), 'same', len(same), 'changed', len(changed),
              'added', len(added), 'missing', len(missing))
    out.write_text(json.dumps(result, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')

main()
