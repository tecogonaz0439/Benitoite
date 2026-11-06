"""再開5の固定基準・import・保護範囲・全環境監査と記録を照合する。"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import time
from evidence import HERE,ROOT,HEAD,BASE,digest,fingerprint,git,import_closure,audit,snapshot
from signatures import revision_rows,render,category


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp',type=Path,required=True)
    args=parser.parse_args()
    tick=time.monotonic()
    assert git('rev-parse','HEAD').decode().strip()==HEAD
    assert git('branch','--show-current').decode().strip()=='m014/l70.k'
    # 本番で許した差は読者のない補題の削除と、07-04の二所見だけ。
    changed=git('diff','--name-only',HEAD,'--','formal','docs/design').decode().splitlines()
    allowed=['docs/design/07-quality/07-04-formal-semantics.md',
             'formal/Benitoite/Release/Refinement/RangeCode.lean']
    assert sorted(changed)==sorted(allowed),changed
    assert not git('ls-files','--others','--exclude-standard','--','formal').strip()
    diff=git('diff','--binary',HEAD,'--','formal','docs/design')
    range_path=ROOT/allowed[1]
    old=git('show',HEAD+':'+allowed[1]).decode()
    removed='theorem Def.instTel_of_ne_nil (d : Def) {rs : List RangeExpr} (h : rs ≠ []) :\n    d.instTel rs = Tel.instR rs d.tel := by cases rs <;> simp_all [Def.instTel]\n\n'
    assert old.count(removed)==1 and old.replace(removed,'')==range_path.read_text()
    def tree(revision):
        return set(git('ls-tree','-r','--name-only',revision,'formal').decode().splitlines())
    new=sorted(p[7:-5].replace('/','.') for p in tree(HEAD)-tree(BASE) if p.endswith('.lean'))
    assert len(new)==7 and set(new)<=import_closure()
    required=['Benitoite.Release.Refinement.'+s for s in [
        'effect_soundness','effect_soundness_noLamNames','Def.WellTyped.inputs_no_ranges',
        'HasTypeVQ.canonical_function_no_ranges','Program.extends_typing',
        'Program.extends_declaration','Program.compose','LegacyCompCases.match_type_subst',
        'Program.extends_typing_declared_context','EffectSoundnessExamples.environment_witness',
        'EffectSoundnessExamples.handler_bypass_witness','EffectSoundnessExamples.unit_noLamNames_witness']]
    checks={}
    current_inputs=snapshot()
    current=fingerprint(current_inputs)
    post_build_document_edit=None
    for label in ['build','axioms']:
        row=json.loads((HERE/('resume5-'+label+'.json')).read_text())
        assert row['exit']==0 and row['head']==HEAD
        assert row['source_before']==row['source_after']
        before=json.loads((args.tmp/(label+'-sources.json')).read_text())
        assert fingerprint(before)==row['source_before']
        assert set(before)==set(current_inputs)
        altered=[name for name in before if before[name]!=current_inputs[name]]
        if altered:
            assert label=='build' and altered==['docs/design/07-quality/07-04-formal-semantics.md']
            path=ROOT/altered[0]
            text=path.read_text()
            prior=text.replace('具体化による四名前空間の上限の保存','四名前空間の操作との可換')
            data=prior.encode()
            assert before[altered[0]]=={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
            post_build_document_edit={'file':altered[0],'before':before[altered[0]],'after':current_inputs[altered[0]],
                                      'reason':'ビルド後に表の語句を、実装済みの上限の保存へ訂正。Lean入力は全件一致'}
        assert row['raw']==digest(args.tmp/(label+'.log'))
        checks[label]=row
    assert 'Build completed successfully' in (args.tmp/'build.log').read_text()
    assert checks['axioms']['input']==digest(HERE/'axioms.lean')
    summary,names,modules=audit((args.tmp/'axioms.log').read_text(),required)
    assert set(new)<=modules
    assert not any(n.endswith('.Def.instTel_of_ne_nil') for n in names)
    targets=args.tmp/'audit-targets.txt'
    targets.write_text('\n'.join(names)+'\n')
    summary['target_list']=digest(targets)
    rows=revision_rows()
    assert render(rows)==(HERE/'resume4-signatures.md').read_text()
    raw=(json.dumps(rows,ensure_ascii=False,indent=2)+'\n').encode()
    assert raw==(args.tmp/'signatures.json').read_bytes()
    definitions=json.loads((HERE/'resume4-definition-inputs.json').read_text())
    assert all(digest(ROOT/name)==ha for name,ha in definitions.items())
    deleted=json.loads((HERE/'removed-records.json').read_text())
    for row in deleted['files']:
        assert not (HERE/row[0]).exists(),row[0]
        # 削除前の内容を固定コミットから読み、台帳の大きさとハッシュを検査する。
        data=git('show',HEAD+':'+str(HERE.relative_to(ROOT)/row[0]))
        assert [len(data),hashlib.sha256(data).hexdigest()]==row[1:]
    assert deleted['removed_bytes']==sum(row[1] for row in deleted['files'])
    files=[p for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    for p in files:
        assert p.stat().st_size<=100000,p.name
        text=p.read_text()
        assert str(ROOT) not in text and not re.search(r'\]\([^)]*docs/todo',text),p.name
        if p.suffix=='.md':
            prose=re.sub(r'^```[^\n]*\n.*?^```[ \t]*$', '', text, flags=re.M|re.S)
            for target in re.findall(r'\]\(([^)]+)\)',prose):
                if '://' not in target and not target.startswith('#'):
                    assert (p.parent/target.split('#')[0]).exists(),(p.name,target)
    assert sum(p.stat().st_size for p in files)<650000
    out={'head':HEAD,'signature_base':BASE,'protected':'Surface・旧Release・MainStatements・01-12・固定設定を含む formal と設計書の他の差分0',
         'production_change':'RangeCode の未使用補題1件の削除のみ',
         'new_modules':new,'default_imports':'全7モジュールが既定importから到達し、全環境監査にも存在',
         'fingerprint':current,'post_build_document_edit':post_build_document_edit,
         'production_and_design_diff':{'bytes':len(diff),'sha256':hashlib.sha256(diff).hexdigest()},
         'evidence_inputs':{p.name:digest(p) for p in sorted(HERE.glob('*.py'))},
         'review_input':digest(HERE.parents[1]/'reviews/RV-L70.k.md'),
         'checks':{k:digest(HERE/('resume5-'+k+'.json')) for k in checks},
         'audit':summary,'signatures':{'rows':len(rows),'kinds':dict(collections.Counter(r['kind'] for r in rows)),
             'categories':dict(collections.Counter(category(r) for r in rows)),
             'raw':{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}},
         'removed_records':digest(HERE/'removed-records.json'),'removed_files':len(deleted['files']),
         'removed_bytes':deleted['removed_bytes'],'record_files_before_summary':len(files),
         'record_bytes_before_summary':sum(p.stat().st_size for p in files),
         'seconds':round(time.monotonic()-tick,3),'verification':'成功'}
    (HERE/'resume5-verification.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(out,ensure_ascii=False))


if __name__=='__main__':main()
