# -*- coding: utf-8 -*-
"""規則タグを先に選ぶ配置で、記録した全72右辺と本番の右辺の一致を調べる。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def check():
    rows = json.loads((HERE/'guide-first-branches.json').read_text())
    text = (ROOT/'formal/Benitoite/Release/Refinement/Surface/Check.lean').read_text()
    lines = text.splitlines()
    headers = [(i, m[1]) for i, line in enumerate(lines)
               if (m := re.fullmatch(r'      \| \.(E_\w+) => match e, children with', line))]
    assert len(headers) == len(rows) == len(set(r['tag'] for r in rows)) == 72
    current = {}
    for index, (start, tag) in enumerate(headers):
        end = headers[index+1][0] if index+1 < len(headers) else next(
            i for i in range(start+1, len(lines)) if lines[i] == '      | _ => false')
        chunk = lines[start+1:end]
        assert chunk[-1] == '        | _, _ => false', tag
        current[tag] = chunk[:-1]
    for row in rows:
        prefix = f"        | {row['source']}, {row['children']} =>"
        chunk = current[row['tag']]
        assert chunk[0].startswith(prefix), row['tag']
        rhs = [chunk[0][len(prefix):]] + [line[4:] for line in chunk[1:]]
        assert hashlib.sha256('\n'.join(rhs).encode()).hexdigest() == row['rhs_sha256'], row['tag']
    return len(rows)


if __name__ == '__main__':
    print(json.dumps({'tags_and_bodies': check()}, indent=1))
