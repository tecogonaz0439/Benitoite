#!/usr/bin/env python3
"""試行用: 指定したファイルの match の腕で、Ty.opaque と Atom.name の引数を一つ足す機械的な書き換え。"""
import re, sys
for path in sys.argv[1:]:
    src = open(path, encoding='utf-8').read().splitlines(keepends=True)
    out, n = [], 0
    for line in src:
        m = re.match(r'^(\s*\|)(.*?)(=>)(.*)$', line, re.S)
        if not m:
            m2 = re.match(r'^(\s*\|)(.*)$', line, re.S)
            if not m2:
                out.append(line); continue
            class M:
                def __init__(s, a, b): s.g = {1: a, 2: b, 3: '', 4: ''}
                def group(s, i): return s.g[i]
            m = M(m2.group(1), m2.group(2))
        lhs, rhs = m.group(2), m.group(4)
        k = [0]
        def rw(mm):
            ctor, var = mm.group(1), mm.group(2)
            k[0] += 1
            rv = '_' if var == '_' else ('r' if k[0] == 1 else f'r{k[0]}')
            return f'{ctor} {var} {rv}', var, rv
        newlhs = lhs; ids = []
        for ctor in ('.opaque', '.name'):
            def sub(mm):
                s, var, rv = rw(mm); ids.append((ctor, var, rv)); return s
            newlhs = re.sub(r'(?<![\w.])(' + re.escape(ctor) + r') (\w+|_)(?=\s*(?:,|\||$|\n))', sub, newlhs)
        newrhs = rhs
        for ctor, var, rv in ids:
            if var != '_' and rv != '_':
                newrhs = re.sub(r'(?<![\w.])' + re.escape(ctor) + r' ' + re.escape(var) + r'\b(?!\s+\w)', f'{ctor} {var} {rv}', newrhs)
        if newlhs != lhs or newrhs != rhs: n += 1
        out.append(m.group(1) + newlhs + m.group(3) + newrhs)
    open(path, 'w', encoding='utf-8').write(''.join(out))
    print(path, n)
