"""写しの現在の言明、十移送、import と禁止された記述を点検する。"""
import hashlib
import json
import re
from pathlib import Path
from reconcile import HERE, STAGE, ROOT, REF, save, digest


def compact(text):
    text=re.sub(r'/\-.*?\-/','',text,flags=re.S)
    return re.sub(r'\s+','',text)


def main():
    records=[]
    for row in json.loads((STAGE/'e/ten-statements-r6.json').read_text()):
        source=(ROOT/row['file']).read_text()
        match=re.search(r'theorem '+re.escape(row['name'])+r'\b[\s\S]*?(?=:= by)',source)
        assert match and hashlib.sha256(match[0].encode()).hexdigest()==row['sha256'],row['name']
        records.append({**row,'unchanged':True})
    save('ten-statements.json',records)
    core=ROOT/'docs/design/01-spec/01-12-core-calculus.md'
    quality=ROOT/'docs/design/07-quality/07-04-formal-semantics.md'
    source='\n'.join(p.read_text() for p in REF.glob('*.lean'))
    blocks=re.findall(r'```lean\n(.*?)```',core.read_text().split('### 篩を含むコア計算の形式化',1)[1],re.S)
    inspected=[]
    for i,block in enumerate(blocks,1):
        exact=block.strip() in source
        pieces=[p.strip() for p in re.split(r'\n\s*\n',block) if p.strip()]
        component_match=all(compact(p) in compact(source) for p in pieces)
        # 計算規則と実行規則の抜粋は途中の構成子を省略する。
        if i in {4,7,9,10}:
            pieces=[p.strip() for p in re.split(r'(?=^\s*\| (?:C_|E_)|^def |^structure )',block,flags=re.M) if p.strip()]
            component_match=all(compact(p) in compact(source) for p in pieces)
        assert exact or component_match or i==14,(i,block.splitlines()[0])
        inspected.append({'block':i,'first_line':block.splitlines()[0], 'exact':exact,
                          'component_match':component_match,
                          'interpretation':'本文で定める像 ν を省略した close_value_typed の説明' if i==14 else '本番の字面又は抜粋'})
    forbidden=re.compile(r'\b(?:L40|L50|L60|L70|R40|R50|J40)(?:\b|\.)|\bF0[1-7]\b|R 段|'+re.escape('/'+'Users/')+'|'+re.escape('/'+'private/tmp/'))
    for path in [core,quality]:assert not forbidden.search(path.read_text()),path.name
    changed=json.loads((HERE/'changed-modules.json').read_text())
    for module in changed['modules']:
        path=ROOT/'formal'/(module.replace('.','/')+'.lean')
        text=path.read_text()
        assert not forbidden.search(text),path.name
        assert not re.search(r'\bsorry\b|^\s*axiom\b|\bnative_decide\b|\bimplemented_by\b|#eval',text,re.M),path.name
    save('snapshots.json',{'ten_statements_unchanged':10,'lean_blocks':inspected,
                           'inputs':{str(p.relative_to(ROOT)):digest(p) for p in [core,quality]},
                           'changed_sources_checked':len(changed['modules']),
                           'workflow_labels_or_local_paths':0, 'new_axiom_commands':0,
                           'script':digest(Path(__file__))})
    print(json.dumps({'ten_statements':10,'lean_blocks':len(blocks),'changed_sources':len(changed['modules'])}))


if __name__=='__main__':main()
