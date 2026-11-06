"""候補の核と前段の署名を、本番の入力から省略せず書き出す。"""
import argparse
import json
import re
from pathlib import Path
from evidence import HERE, ROOT, digest

R = 'formal/Benitoite/Release/Refinement/'


def between(text, start, stop):
    a = text.index(start)
    b = text.index(stop,a+len(start))
    return text[a:b].rstrip()


def declaration(text, name, signature=False):
    m = re.search(r'^(?:private )?(?:noncomputable )?(?:theorem|def|abbrev|structure) '+re.escape(name)+r'(?=\s|\{)',text,re.M)
    assert m, name
    rest = text[m.start():]
    if signature:
        return rest[:rest.index(':=')].rstrip()
    following = re.search(r'\n(?=(?:private )?(?:noncomputable )?(?:theorem|def|abbrev|structure) |namespace |end\b)',rest)
    return (rest[:following.start()] if following else rest).rstrip()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    args=parser.parse_args()
    records={}
    def read(module):
        name=R+module+'.lean'
        records[name]=digest(ROOT/name)
        return (ROOT/name).read_text()
    chunks=[]
    for name in ['Syntax','RangeCode','RangeTyping','ProgramTyping','SourceScope']:
        chunks.append((name+'.lean（全定義と補助）',read(name).rstrip()))
    typing=read('Typing')
    for begin,end in [('    | V_Fun','    | V_Op'),('    | C_Match','    | C_Lazy'),('    | C_Handle','    | C_Resume')]:
        chunks.append(('Typing.lean',between(typing,begin,end)))
    chunks.append(('HandlerContracts.lean',between(read('HandlerContracts'),'def Builtins.issuesIn','def BinderTypes.LocalWF')))
    semantics=read('Semantics')
    for begin,end in [('  | E_Fun','  | E_Prim'),('  | E_PathBasesApply','  | E_AtOk'),('  | E_OpPrim','  | E_Resume')]:
        chunks.append(('Semantics.lean',between(semantics,begin,end)))
    chunks.append(('Step.lean（組込みの適用の全分岐）',between(read('Step'),'  | (.app (.prim','  | (.issuePathBases')))
    chunks.append(('HandlerGeneral.lean（追加した入口の完全署名）',declaration(read('HandlerGeneral'),'StateTyE.primitive_effect_input',True)))
    for name in ['MainEffects','EffectSoundnessExamples']:
        chunks.append((name+'.lean（全定義と証明）',read(name).rstrip()))
    chunks.append(('MainStatements.lean',declaration(read('MainStatements'),'EffectSoundnessStatement')))
    header='# 再開4の核の定義と規則の完全な形\n\n本番のソースから台本で写した。名前空間は `Benitoite.Release.Refinement`。各欄の本文と全分岐を省略しない。証明と追加の読者は各本番モジュールを正とする。\n\n'
    out=header+'\n\n'.join('## '+name+'\n\n```lean\n'+body+'\n```' for name,body in chunks)+'\n'
    assert len(out.encode()) <=100000,len(out.encode())
    (HERE/'resume4-definitions.md').write_text(out)
    (HERE/'resume4-definition-inputs.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'definitions_bytes':len(out.encode()),'inputs':len(records)}))


if __name__=='__main__':
    main()
