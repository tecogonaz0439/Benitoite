# -*- coding: utf-8 -*-
"""再開3の開始版・変更範囲・既定import・全環境の公理監査・記録を照合する。"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
from run_check import HERE, ROOT, MODULES, digest, fingerprint, inputs

B_WORK = 'e70794188e24de95b5bb424f9d75090f77d1c703'
OWN = str(HERE.relative_to(ROOT))
REVIEWS = str((HERE.parents[1]/'reviews').relative_to(ROOT)) + '/'
LEGACY = ['verify.py', 'axioms.lean', 'audit-modules.json', 'required-names.json', 'audit-summary.json']
NEW = ['formal/' + m.replace('.', '/') + '.lean' for m in MODULES]
DESIGN = ['docs/design/01-spec/01-12-core-calculus.md',
          'docs/design/07-quality/07-04-formal-semantics.md']
ALLOWED = set(NEW + DESIGN + ['formal/Benitoite.lean'])

def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], check=True, capture_output=True, text=True).stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp', type=Path, required=True)
    parser.add_argument('--record-prefix', choices=['resume3', 'resume4'], default='resume3')
    args = parser.parse_args()
    assert git('rev-parse', 'HEAD').strip() == B_WORK
    assert git('branch', '--show-current').strip() == 'm014/l70.c2'
    changed = set(git('diff', '--name-only', '-z', B_WORK).split('\0')) - {''}
    untracked = set(git('ls-files', '--others', '--exclude-standard', '-z').split('\0')) - {''}
    assert all(p in ALLOWED or p.startswith((OWN+'/', REVIEWS)) for p in changed | untracked), changed | untracked
    assert sorted(p for p in untracked if p.endswith('.lean') and p.startswith('formal/')) == sorted(NEW)
    assert json.loads((HERE/'resume3-audit-modules.json').read_text()) == [p[7:-5].replace('/', '.') for p in NEW]
    for name in LEGACY:
        expected = subprocess.run(['git', '-C', str(ROOT), 'show', B_WORK+':'+OWN+'/'+name],
                                  check=True, capture_output=True).stdout
        assert (HERE/name).read_bytes() == expected, '旧記録に差がある: '+name
    baseline = json.loads((HERE/'resume3-baseline.json').read_text())
    protected = {}
    for base in [ROOT/'formal', ROOT/'docs/design', HERE.parents[1]]:
        for p in base.rglob('*'):
            if p.is_file() and '.lake' not in p.parts:
                rel = str(p.relative_to(ROOT))
                if rel not in ALLOWED and not rel.startswith((OWN+'/', REVIEWS)):
                    protected[rel] = digest(p)
    # 元の基準指紋を保持する。reviews/ は開始版の固定値だけで補い、現在の記録は照合しない。
    # これにより、レビューの追加・変更・削除を許し、それ以外の保護を元の基準のまま保つ。
    baseline_reviews = {}
    for rel in git('ls-tree', '-r', '--name-only', B_WORK, '--', REVIEWS).splitlines():
        data = subprocess.run(['git', '-C', str(ROOT), 'show', B_WORK+':'+rel],
                              check=True, capture_output=True).stdout
        baseline_reviews[rel] = hashlib.sha256(data).hexdigest()
    baseline_protected = protected | baseline_reviews
    assert len(baseline_protected) == baseline['protected_count']
    assert fingerprint(baseline_protected) == baseline['protected_sha256'], '保護範囲に差がある'
    root = (ROOT/'formal/Benitoite.lean').read_text()
    base_root = git('show', B_WORK+':formal/Benitoite.lean')
    assert root.startswith(base_root)
    assert root[len(base_root):].splitlines() == ['import '+m for m in MODULES]
    for path in NEW:
        text = (ROOT/path).read_text()
        assert not re.search(r'\bsorry\b|\baxiom\b|native_decide|#eval|#reduce|#check|#print|maxHeartbeats|maxRecDepth|\bL\d\d\.\d|\bJ\d\d-\d|\bU0\d\b', text)
        assert not re.search(r'^import .*\.Surface\.', text, re.M)
    build = json.loads((HERE/(args.record_prefix+'-build.json')).read_text())
    audit = json.loads((HERE/(args.record_prefix+'-audit.json')).read_text())
    for name, record in [('build',build),('audit',audit)]:
        log = args.tmp/(name+'.log')
        assert record['exit'] == 0 and record['unchanged']
        assert record['log_bytes'] == log.stat().st_size and record['log_sha256'] == digest(log)
        assert record['input_sha256'] == fingerprint(inputs())
        assert record['sources'] == {m:digest(ROOT/('formal/'+m.replace('.','/')+'.lean')) for m in MODULES}
    output = (args.tmp/'build.log').read_text()
    jobs = int(re.search(r'Build completed successfully \((\d+) jobs\)', output)[1])
    assert 'error:' not in output
    for m in MODULES:
        assert not re.search(r'^warning: .*'+re.escape(m.replace('.','/'))+r'\.lean:', output, re.M)
    output = (args.tmp/'audit.log').read_text()
    assert not re.search(r'error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)', output)
    targets = re.findall(r'^AUDIT_TARGET (.+)$', output, re.M)
    assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$',output,re.M)[1])
    axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])",output,re.M|re.S)
    assert collections.Counter(n for n,_ in axioms) == collections.Counter(targets)
    sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(',') if x.strip())) for _,ax in axioms)
    assert all(set(s) <= {'propext','Quot.sound','Classical.choice'} for s in sets)
    per_module = {m:int(n) for m,n in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$',output,re.M)}
    assert sum(per_module.values()) == len(targets) and set(MODULES) <= set(per_module)
    decls = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$',output,re.M)
    assert len(decls) == sum(per_module[m] for m in MODULES)
    assert all(m in MODULES for m,_,_,_ in decls)
    required = json.loads((HERE/'resume3-required-names.json').read_text())
    assert set(required) <= {n for _,_,_,n in decls}
    names = sorted(n for _,_,_,n in decls)
    (args.tmp/'declarations.txt').write_text('\n'.join(names)+'\n')
    sources = {m:digest(ROOT/('formal/'+m.replace('.','/')+'.lean')) for m in MODULES}
    for p in HERE.rglob('*'):
        if p.is_file():
            assert p.stat().st_size <= 100000, p.name
            text = p.read_text()
            assert '/Us'+'ers/' not in text and '/priv'+'ate/tmp' not in text, p.name
            assert not re.search(r'\]\([^)]*docs/todo',text),p.name
    size = sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file())
    assert size < 3000000
    result = {'b_work':B_WORK,'changed':sorted(changed),'added_modules':MODULES,
              'jobs':jobs,'protected_files':len(protected),'sources':sources,
              'excluded_reviews':REVIEWS,'baseline_review_files':len(baseline_reviews),
              'legacy_files_restored':LEGACY,'check_record_prefix':args.record_prefix,
              'axioms':{'environment_declarations':len(targets),'environment_modules':len(per_module),
                        'rounds':int(re.search(r'^AUDIT_ROUNDS (\d+)$',output,re.M)[1]),
                        'new_declarations':len(names),'new_private':sum(n.startswith('_private.') for n in names),
                        'new_modules':{m:per_module[m] for m in MODULES},
                        'required':len(required),'declaration_list_bytes':(args.tmp/'declarations.txt').stat().st_size,
                        'declaration_list_sha256':digest(args.tmp/'declarations.txt'),
                        'sets':{','.join(k) or '(none)':v for k,v in sorted(sets.items())}},
              'records_bytes_before_summary':size}
    (HERE/(args.record_prefix+'-audit-summary.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__ == '__main__':
    main()
