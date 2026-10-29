#!/usr/bin/env python3
"""試行用: lean の出力の「ScopeRange → Atom/Ty」の型の不一致の位置にある構成子を、Top の構築関数へ置き換える。
使い方: fixtop.py <lean の出力> <ファイル>。置き換えた件数を出す。"""
import re, sys
out, path = open(sys.argv[1], encoding='utf-8').read(), sys.argv[2]
lines = open(path, encoding='utf-8').read().split('\n')
pos = set()
for m in re.finditer(r'^[^\s:]+\.lean:(\d+):(\d+): error: ((?:Application )?[Tt]ype mismatch.*?)(?=^[^\s:]+\.lean:\d+:\d+: |\Z)', out, re.S | re.M):
    if re.search(r'ScopeRange → (Atom|Ty)\b', m.group(3)):
        pos.add((int(m.group(1)), int(m.group(2))))
n = 0
for (ln, col) in sorted(pos, reverse=True):
    s = lines[ln - 1]
    # 位置は UTF-8 ではなく文字の列で数える
    seg = s[col:]
    mm = re.match(r'(\(?)(Atom\.name|Ty\.opaque|\.name|\.opaque|name|opaque)\b', seg)
    if not mm:
        # 位置が引数の式の外側（括弧や関数適用）を指すとき、その範囲で最初の構成子を探す
        mm2 = re.search(r'(Atom\.name|Ty\.opaque|(?<![\w.])\.name|(?<![\w.])\.opaque)\b', seg)
        if not mm2:
            print(f'unresolved {path}:{ln}:{col}: {s.strip()[:100]}'); continue
        st, tok = col + mm2.start(), mm2.group(1)
    else:
        st, tok = col + len(mm.group(1)), mm.group(2)
    rep = {'Atom.name': 'Atom.nameTop', 'Ty.opaque': 'Ty.opaqueTop', '.name': '.nameTop', '.opaque': '.opaqueTop',
           'name': 'Atom.nameTop', 'opaque': 'Ty.opaqueTop'}[tok]
    lines[ln - 1] = s[:st] + rep + s[st + len(tok):]
    n += 1
open(path, 'w', encoding='utf-8').write('\n'.join(lines))
print(path, n)
