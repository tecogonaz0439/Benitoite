"""元の直接規則から、逆転の各枝の完全な命題を再生成する。"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[4]
# 台本の保管先からリポジトリの根を特定する。
while not (ROOT/'formal/Benitoite.lean').exists():
    if ROOT==ROOT.parent: raise RuntimeError('repository root not found')
    ROOT=ROOT.parent
HERE=Path(__file__).resolve().parent

def split(text, sep):
    out=[];depth=0;start=0
    for i,c in enumerate(text):
        if c in '([{':depth+=1
        elif c in ')]}':depth-=1
        elif depth==0 and c==sep:
            if text[start:i].strip():out.append(text[start:i].strip())
            start=i+1
    if text[start:].strip():out.append(text[start:].strip())
    return out

def theorem_prop(filename,name):
    source=(ROOT/'formal/Benitoite/Release/Refinement'/filename).read_text()
    header=source.split('theorem '+name+' ',1)[1].split(':=',1)[0].strip()
    depth=0
    for i,c in enumerate(header):
        if c in '([{':depth+=1
        elif c in ')]}':depth-=1
        elif c==':' and depth==0:
            binders,output=header[:i],header[i+1:]
            facts='∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)'
            return '#check (∀ '+binders+',\n    ('+output.strip()+') ∧\n    ('+facts+') : Prop)\n'
    raise ValueError(name)

def main():
    text=(ROOT/'formal/Benitoite/Release/Refinement/Typing.lean').read_text()
    text=re.sub(r'/\-.*?\-/','',text,flags=re.S)
    blocks=re.findall(r'^    \| ((?:V|C)_\w+) ([\s\S]*?)(?=^    \| |^  (?:inductive|/)|\Z)',text,re.M)
    code=['import Benitoite\nopen Benitoite.Release.Refinement\nnamespace Benitoite.Release.Refinement.Signatures\n']
    for name,block in blocks:
        if name in {'V_Sub','V_Normal','V_Refine'}:continue
        if name in {'C_Sub','C_Normal','C_Eff'}:continue
        if not name.startswith(('V_','C_')):continue
        replacements={
            'V_Var':('ValueInversion.lean','HasTypeVQ.inv_var'),
            'V_Const':('ValueFacts.lean','HasTypeVQ.inv_const'),
            'V_List':('ValueInversion.lean','HasTypeVQ.inv_list_core'),
            'V_Con':('ValueFacts.lean','HasTypeVQ.inv_con'),
            'V_Checked':('HeldValues.lean','HasTypeVQ.inv_checked'),
            'V_CheckedRequest':('HeldValues.lean','HasTypeVQ.inv_checkedRequest'),
            'V_CheckedAt':('HeldValues.lean','HasTypeVQ.inv_checkedAt')}
        if name in replacements:
            code.append('-- '+name+' の芯と事実の枝\n'+theorem_prop(*replacements[name]))
            continue
        if name=='V_AtError':
            code.append('-- V_AtErrorの芯と事実の枝\n#check (∀ {P B Ψ Q C Γ Φ T} (detail : AtError),\n  HasTypeVQ P B Ψ Q C Γ Φ (.atError detail) T →\n  (∃ shape : ResultShape, shape.Declared P ∧ T.norm.core = shape.errorType.norm.core) ∧\n  (∀ t, (Val.atError detail).toTerm? = some t → ∀ p ∈ T.assume,\n    Entails (Γ.facts ++ Φ) (p.open t)) : Prop)\n')
            continue
        depth=0;colon=None
        for i,c in enumerate(block):
            if c in '([{':depth+=1
            elif c in ')]}':depth-=1
            elif c==':' and depth==0:colon=i;break
        if colon is None:continue
        prefix=block[:colon];variables=[];annotations={}
        for bind in re.findall(r'[{(]([^{}()]+)[})]',prefix):
            if ':' in bind:
                ns,ty=bind.split(':',1)
                for n in ns.split():variables.append(n);annotations[n]=ty.strip()
            else:variables+=bind.split()
        parts=split(block[colon+1:], '→')
        if len(parts)<2:continue
        result=split(parts[-1], ' ')
        if result[0] not in {'HasTypeVQ','HasTypeCQ'}:continue
        isV=result[0]=='HasTypeVQ'
        source=result[8] if isV else result[9]
        oldtype=result[9] if isV else result[10]
        effect=None if isV else result[11]
        common={'Ψ','Q','C','Γ','Φ'} | (set() if isV else {'R','Δ'})
        tokens=set(re.findall(r'\w+|ε',source))
        public=[v for v in variables if v not in common and v in tokens]
        hidden=[v for v in variables if v not in common and v not in public]
        binders='{P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty}'
        if not isV:binders+=' {R : Option Ty} {Δ : LocalCtx} {outEff : Eff}'
        for v in public:binders+=' {'+v+(' : '+annotations[v] if v in annotations else '')+'}'
        if isV:
            inp=f'HasTypeVQ P B Ψ Q C Γ Φ {source} T'
            if oldtype.startswith('(.dependentFn '):
                hidden+=['u'];tel=oldtype[len('(.dependentFn '):-1]
                relation=f'T.fnCore = some u ∧ TelClosure P Γ Φ {tel} u'
            elif oldtype.startswith('(.fn '):
                ns,ps,ret,eff=split(oldtype[1:-1],' ')[1:]
                hidden+=['u'];relation=f'T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel {ns} {ps} {ret} {eff}) u'
            elif name=='V_Map':
                hidden+=['k','w'];relation="T.norm.core = .map k w ∧ a.norm = k.norm ∧ Ty.LeQ P Γ Φ b w"
            elif name=='V_Set':
                hidden+=['w'];relation='T.norm.core = .set w ∧ a.norm = w.norm'
            elif name=='V_Bytes':relation='T.norm.core = .bytes'
            elif name in {'V_Dict','V_Super'}:relation=f'T.norm.core = (Ty'+oldtype[1:]+'.norm.core'
            else:relation=f'Ty.LeQ P Γ Φ {oldtype} T'
        else:
            inp=f'HasTypeCQ P B Ψ Q C Γ Φ R {source} T outEff Δ'
            relation=f'Ty.LeQ P Γ Φ {oldtype} T ∧ Eff.Covers Γ Φ outEff {effect}'
        # 関係の新しい変数を元の束縛と重ねない。
        assert len(hidden)==len(set(hidden)),(name,hidden)
        if not isV and result[8]!='R':parts.insert(0, 'R = '+result[8])
        output=' ∧\n      '.join('('+p+')' for p in parts[:-1])+ ' ∧\n      '+relation
        if hidden:output='∃ '+' '.join('('+v+' : '+annotations[v]+')' if v in annotations else v for v in hidden)+',\n      '+output
        code.append('-- '+name+' の直接の枝\n#check (∀ '+binders+',\n    '+inp+' →\n    '+output+' : Prop)\n')
    code.append('end Benitoite.Release.Refinement.Signatures\n')
    lean='\n'.join(code)
    (HERE/'signature-check.lean').write_text(lean)
    md=HERE/'signatures.md'
    s=md.read_text().split('\n## 逆転の各枝の完全な命題\n')[0]
    s=s.split('\n## 補足の完全署名\n')[0]
    s+='\n## 補足の完全署名\n\nセルはref_cell/lazy_cell/cont_cell/builder_cellの順である。二成分の関数の型はjoinV、normalF、returnF、seqF/joinFの順である。五つの定義はsignature-extra.leanに具体化した。局所規則の型検査は、その保存則を証明したことを意味しない。\n\n```lean\n'+(HERE/'signature-extra.lean').read_text()+'```\n'
    s+='\n## 内部の安全な契約の依存列\n\n公開名・字面を定めない内部の型である。証明は群D/E。\n\n```lean\n'+(HERE/'safe-contracts.lean').read_text()+'```\n'
    h=(HERE.parents[1]/'l20/n/h04-handoff.lean').read_text()
    h=h[h.index('namespace Benitoite.Release.Refinement.IntervalConnection.H04'):h.index('-- 第二候補')]
    s+='\n### 最初の実行失敗の完全な定義\n\n```lean\n'+h+'```\n'
    s+='\n## 逆転の各枝の完全な命題\n\n同じ構文の複数規則の出力は、該当する枝の出力の選言である。appはその後F02で共通の列へ移す。入力のvは当該構文に書き換えた形であり、一般のvとその等号を取る入口と同じ命題である。台本signatures.pyで本番の直接規則から再生成し、signature-check.leanで全命題の型を検査する。以下の型検査を証明の完成とは数えない。\n\n```lean\n'+lean+'```\n'
    assert len(s.encode())<=100_000,len(s.encode())
    md.write_text(s)
    print(len(code)-2,'branches;',len(s.encode()),'bytes')
if __name__=='__main__':main()
