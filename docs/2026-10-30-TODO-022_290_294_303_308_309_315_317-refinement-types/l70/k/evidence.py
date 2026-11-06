"""検査の入力・出力の指紋と全環境の公理監査の照合。"""
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
HEAD='de7fbf28cdebef9f5b62a7eb8457aecdaa988faa'
BASE='dcaa396bad7a60d4da9b99d07ad9b75c0f328b07'


def digest(path):
    data=path.read_bytes()
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)


def snapshot():
    paths=[p for p in (ROOT/'formal').rglob('*') if p.is_file() and '.lake' not in p.parts
           and (p.suffix=='.lean' or p.name in {'lakefile.toml','lake-manifest.json','lean-toolchain'})]
    paths += [ROOT/'docs/design/01-spec/01-12-core-calculus.md',
              ROOT/'docs/design/07-quality/07-04-formal-semantics.md']
    return {str(p.relative_to(ROOT)):digest(p) for p in sorted(paths)}


def fingerprint(rows=None):
    rows=snapshot() if rows is None else rows
    data=json.dumps(rows,sort_keys=True,separators=(',',':')).encode()
    return {'files':len(rows),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}


def import_closure():
    seen=set()
    def visit(module):
        if module in seen:return
        seen.add(module)
        path=ROOT/'formal'/(module.replace('.','/')+'.lean')
        if path.exists():
            for name in re.findall(r'^import\s+([A-Za-z0-9_.]+)',path.read_text(),re.M):visit(name)
    visit('Benitoite')
    return seen


def audit(raw,required):
    assert not re.search(r'\berror:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)',raw)
    names=re.findall(r'^AUDIT_TARGET (.+)$',raw,re.M)
    counts=[int(n) for n in re.findall(r'^AUDIT_COUNT (\d+)$',raw,re.M)]
    assert len(counts)==1 and len(names)==len(set(names))==counts[0]>0
    printed=re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])",raw,re.M|re.S)
    assert collections.Counter(n for n,_ in printed)==collections.Counter(names)
    assert set(required)<=set(names),set(required)-set(names)
    sets=collections.Counter(tuple(sorted(s.strip() for s in axioms.split(',') if s.strip())) for _,axioms in printed)
    assert all(set(s)<={'propext','Classical.choice','Quot.sound'} for s in sets)
    modules=re.findall(r'^AUDIT_MODULE (\S+) (\d+)$',raw,re.M)
    assert sum(int(n) for _,n in modules)==len(names)
    return {'targets':len(names),'private_targets':sum(n.startswith('_private.') for n in names),
            'modules':len(modules),'rounds':[int(n) for n in re.findall(r'^AUDIT_ROUNDS (\d+)$',raw,re.M)],
            'axiom_sets':{' + '.join(s) or 'none':n for s,n in sorted(sets.items())},
            'unapproved_axioms':0},names,{m for m,_ in modules}
