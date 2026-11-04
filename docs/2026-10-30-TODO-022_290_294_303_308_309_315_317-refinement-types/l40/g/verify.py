"""最終報告前に、記録・入力・担当単位の完了条件を一行ずつ照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import collections
import json
import re
import time
from reconcile import HERE, STAGE, ROOT, digest, save, rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp',type=Path,required=True)
    args=parser.parse_args()
    start=datetime.now(timezone.utc);tick=time.monotonic()
    protected=json.loads((args.tmp/'protected.json').read_text())
    assert all((ROOT/f).is_file() and digest(ROOT/f)==record for f,record in protected.items())
    formal_start=json.loads((args.tmp/'formal-start.json').read_text())
    formal_current={str(p.relative_to(ROOT)):digest(p) for p in (ROOT/'formal').rglob('*.lean') if '.lake' not in p.parts}
    assert formal_current==formal_start,'本番 Lean の開始時からの変更'
    audit=json.loads((HERE/'audit-summary.json').read_text())
    assert audit['exit']==0 and audit['targets']==sum(audit['axiom_sets'].values())
    assert audit['new_axioms']==0 and audit['private_and_generated_included']
    assert audit['input']==digest(STAGE/'axioms.lean') and audit['script']==digest(STAGE/'audit.py')
    assert audit['raw']==digest(args.tmp/'stage-audit.log')
    assert audit['target_list']==digest(args.tmp/'stage-targets.txt')
    declarations=[]
    for part in audit['declaration_parts']:
        assert digest(HERE/part['file'])=={k:part[k] for k in ['bytes','sha256']}
        for group in json.loads((HERE/part['file']).read_text()):
            assert (ROOT/group['source']).is_file()
            declarations.extend((name,group['module'],kind,line) for name,kind,line in group['declarations'])
    names=[d[0] for d in declarations]
    assert len(names)==len(set(names))==audit['changed_module_declarations']==13660
    environment=set((args.tmp/'stage-targets.txt').read_text().splitlines())
    assert set(names)<=environment
    unit_groups=list(json.loads((HERE/'unit-evidence.json').read_text()).values())
    case_rows=json.loads((HERE/'case-evidence.json').read_text())
    assert len(case_rows)==59
    for entries in unit_groups+[row['evidence'] for row in case_rows]:
        for e in entries:
            assert e['full_name'] in environment
            assert re.search(r'\b'+re.escape(e['name_as_written'])+r'\b',
                             (ROOT/e['source']).read_text().splitlines()[e['line']-1])
    for part in audit['formal_input_parts']:
        assert digest(HERE/part['file'])=={k:part[k] for k in ['bytes','sha256']}
        for e in json.loads((HERE/part['file']).read_text()):
            assert digest(ROOT/e['file'])=={k:e[k] for k in ['bytes','sha256']}
    for part in audit['signature_parts']+audit['module_parts']:
        assert digest(HERE/part['file'])=={k:part[k] for k in ['bytes','sha256']}
    assert len([r for r in rows((HERE/'obligations.md').read_text()) if re.fullmatch(r'O\d{3}',r[0])])==64
    assert len([r for r in rows((HERE/'handoffs.md').read_text()) if re.fullmatch(r'H\d{2}',r[0])])==33
    assert collections.Counter(r[2] for r in rows((HERE/'handoffs.md').read_text()) if re.fullmatch(r'H\d{2}',r[0]))=={'今回':25,'継承':3,'他段':5}
    for name in ['signatures','build','selection','work']:
        record=json.loads((HERE/(name+'-check.json')).read_text())
        assert record['exit']==0 and record['raw']==digest(args.tmp/(name+'.log'))
    work=json.loads((HERE/'work-check.json').read_text())
    assert work['command']==['scripts/check.sh','--level','work','--base','fcde6fe216d35c3c74fcaa8d28164df063b6aa8b']
    work_text=(args.tmp/'work.log').read_text()
    assert '7 passed' in work_text and '0 failed' in work_text and '0 ignored' in work_text
    assert 'formal_build' not in (args.tmp/'selection.log').read_text()
    assert 'Build completed successfully (1252 jobs).' in (args.tmp/'build.log').read_text()
    assert not re.search(r'\bsorryAx\b|declaration uses .sorry.',(args.tmp/'stage-audit.log').read_text())
    for path in [STAGE/'audit.py']+list(HERE.glob('*.py')):ast.parse(path.read_text(),filename=path.name)
    # 公開資料のリンクは実在する相対の対象だけにする。
    checked_links=0
    for path in [STAGE/'stage-results.md']+list(HERE.glob('*.md')):
        for link in re.findall(r'\[[^\]]+\]\(([^)]+)\)',path.read_text()):
            if link.startswith(('https:','http:','#')):continue
            assert not link.startswith('/'),(path.name,link)
            target=link.split('#',1)[0]
            assert (path.parent/target).exists(),(path.name,link)
            checked_links+=1
    records=[p for p in HERE.iterdir() if p.is_file()]
    sizes={p.name:p.stat().st_size for p in records}
    assert all(n<=100000 for n in sizes.values()),sizes
    assert (STAGE/'stage-results.md').stat().st_size<=100000
    assert (STAGE/'axioms.lean').stat().st_size<=100000
    assert sum(sizes.values())<4000000
    forbidden=re.compile(re.escape('/'+'Users/')+'|'+re.escape('/'+'private/tmp/')+r'|\]\([^)]*docs/todo')
    for path in records+[STAGE/'stage-results.md',STAGE/'axioms.lean',STAGE/'audit.py']:
        assert not forbidden.search(path.read_text()),path.name
    summary={'start_utc':start.isoformat(),'end_utc':datetime.now(timezone.utc).isoformat(),
             'seconds':time.monotonic()-tick,'exit':0,'protected_files_unchanged':len(protected),
             'formal_sources_unchanged':len(formal_current),'audited_declarations':audit['targets'],
             'changed_module_declarations':len(declarations),'actual_signatures':audit['signatures'],
             'case_table_rows':len(case_rows),
             'obligations':64,'handoffs':33,'relative_links':checked_links,
             'work_runs':1,'default_build_runs':1,'formal_comparison_runs':0,
             'record_files':len(records),'record_bytes':sum(sizes.values()),'largest_record':max(sizes.values()),
             'independent_review':'未実施。受け口だけを準備','acceptance':'未実施',
             'unresolved':'O135の通常decoder接続、328外の演算子34行・構造Equality全入力。O022/O034/O062/O065/O135/O144の6行は一部。担当・時期と閉鎖証拠の確認を要する',
             'script':digest(Path(__file__))}
    save('verification.json',summary)
    print(json.dumps(summary,ensure_ascii=False))


if __name__=='__main__':main()
