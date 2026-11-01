"""完全署名の入力、foundation対応、全宣言の公理依存の入力を作る。"""
from pathlib import Path
import collections, hashlib, json, re, tempfile
ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
PREFIX = 'Benitoite.Release.Refinement.'
MODULES = ['TypeRegularity','TypeBounds','TypeRows','TypeVariables','TypeShiftFacts','EffectFacts','TypeArgumentRegularity']

def decls(text):
    # この作業の宣言はパターン引数を持たず、型注釈に文字列リテラルを含まない。
    for match in re.finditer(r'^\s*(?:(noncomputable)\s+)?(theorem|def)\s+([\w.]+)\s*', text, re.M):
        start = match.end()
        depth = 0
        colon = None
        end = None
        for i in range(start, len(text)):
            c = text[i]
            if c in '({[': depth += 1
            elif c in ')}]': depth -= 1
            if depth == 0:
                if text.startswith(':=', i):
                    end = i
                    break
                if c == ':' and colon is None:
                    colon = i
                if c == '\n' and text[i+1:].lstrip().startswith('|'):
                    end = i
                    break
                # Markdownの末尾又は次の宣言。
                if text.startswith('\n```', i) or re.match(r'\n(?:theorem|def|noncomputable def|structure)\s', text[i:]):
                    end = i
                    break
        if end is None: end = len(text)
        if colon is None or colon >= end:
            raise ValueError('署名の型注釈がない: '+match[3])
        binders = text[start:colon].strip()
        result = text[colon+1:end].strip()
        # markdownコード枠の閉じだけを除く。
        result = result.split('```')[0].strip()
        yield match[3], binders, result, ('∀ '+binders+', ' if binders else '')+result

sources = {}
for m in MODULES:
    for name, binders, result, full in decls((ROOT/'formal/Benitoite/Release/Refinement'/(m+'.lean')).read_text()):
        sources[name] = (binders,result,full)

# 再開で変えた公開の入力・移送・逆転も完全署名に含める。
SELECTED = {
 'KindValues': ['TypeArgsKinded', 'Ty.HasKind.constructor_ordinary', 'TypeArgsKinded.ordinary', 'TypeArgsKinded.shift', 'TypeArgsKinded.subst', 'Ty.ordinary_bind_values'],
 'TypeShiftKinds': ['TypeArgsKinded.shiftTypes'],
 'AdmissibleMap': ['TypeArgsKinded.norm'],
 'Admissible': ['SignatureInstance.ordinary', 'SignatureInstance.typeScope'],
 'Context/Declarations': ['TypeArgsKindedAt', 'TypeArgsKindedAt.forget', 'TypeArgsKindedAt.shift', 'TypeArgsKindedAt.subst'],
 'HandlerCalls': ['HasTypeCQ.operation_call', 'ClosureTy.pure_operation', 'ClosureTy.pure_operation_signature', 'HasTypeVQ.op_typeScope', 'ClosureTy.pure_operation_typeScope'],
 'HandlerOperation': ['StateTyE.operation_typeScope'],
 'LegacyDeclarations': ['LegacyKindArgs'],
 'LegacyInput': ['LegacyTypesInput', 'LegacyBuilderInput'],
 'ValueFacts': ['HasTypeVQ.constructor_field_inputs', 'HasTypeVQ.con_field_by_type', 'HasTypeVQ.field_facts_by_type'],
}
for mod, names in SELECTED.items():
    ds = {n:(b,r,f) for n,b,r,f in decls((ROOT/'formal/Benitoite/Release/Refinement'/(mod+'.lean')).read_text())}
    for name in names:
        sources[name] = ds[name]

md = (HERE/'signatures.md').read_text().split('\n## 実装で追加した補助と既存の再使用')[0]
documented = set()
for code in re.findall(r'```lean\n(.*?)```', md, re.S):
    documented.update(n for n,*_ in decls(code))
extras = {n:v for n,v in sources.items() if n not in documented}
# 生の比較とzeroは既存の宣言を直接使う。
reused = '''theorem Ty.shiftTypes_compare (k c : Nat) (a b : Ty) : tyCompare (shiftTypes k c a) (shiftTypes k c b) = tyCompare a b
theorem Ty.trees_shiftTypes_compare (k c : Nat) (as bs : List Ty) :
    Order.treesCompare Order.labelCompare (Ty.toTrees (shiftTypesList k c as)) (Ty.toTrees (shiftTypesList k c bs)) =
    Order.treesCompare Order.labelCompare (Ty.toTrees as) (Ty.toTrees bs)
theorem Eff.tree_shiftTypes_compare (k c : Nat) (e f : Eff) :
    Order.treeCompare Order.labelCompare (Eff.toTree (shiftRowsTypes k c e)) (Eff.toTree (shiftRowsTypes k c f)) =
    Order.treeCompare Order.labelCompare (Eff.toTree e) (Eff.toTree f)
theorem Ty.norm_shiftTypes (a : Ty) (k c : Nat) : (shiftTypes k c a).norm = shiftTypes k c a.norm
theorem Ty.normTys_shiftTypes (as : List Ty) (k c : Nat) : Ty.normTys (shiftTypesList k c as) = shiftTypesList k c (Ty.normTys as)
theorem Eff.norm_shiftTypes (e : Eff) (k c : Nat) : (shiftRowsTypes k c e).norm = shiftRowsTypes k c e.norm
theorem shiftTypes_zero (a : Ty) (c : Nat) : shiftTypes 0 c a = a
theorem shiftTypesList_zero (as : List Ty) (c : Nat) : shiftTypesList 0 c as = as
theorem shiftRowsTypes_zero (e : Eff) (c : Nat) : shiftRowsTypes 0 c e = e
'''
md += '\n## 実装で追加した補助と既存の再使用\n\n以下は初版の署名に加えた補助である。RowsInとRangesScopedの定義は既存のままとし、支持との同値を証明した。生の移動のWF四族は、TypeShiftContextに同じ証明があるため、それを再使用する。新しい同名の相互証明は追加しない。\n\n```lean\n'
for name,(binders,result,_) in extras.items():
    kind = 'def' if name in ['rowCondition','rangeCondition','TypeArgsKinded','TypeArgsKindedAt','LegacyKindArgs','LegacyTypesInput','LegacyBuilderInput'] else 'theorem'
    md += f'{kind} {name} {binders} : {result}\n'
md += reused+'```\n\n完全署名は [signatures.lean](signatures.lean) が各宣言の型へ照合する。構造体WFImagesの各欄は本番のstructure宣言をカーネルが検査し、同じ型を前提としてupと置換を証明する。\n'
(HERE/'signatures.md').write_text(md)

entries={}
for code in re.findall(r'```lean\n(.*?)```', md, re.S):
    for name,binders,result,full in decls(code):
        entries.setdefault(name, full)
sig='import Lean\nimport Benitoite\nnamespace Benitoite.Release.Refinement\n\n'
sig+='noncomputable def signature000 : Nat → Nat → Nat → Nat → Nat → Nat → SubstEnv → Prop := @SubstEnv.WFImages\n\n'
theorem_names = {'HasTypeVQ.V_Raise'}
for m in MODULES + list(SELECTED):
    theorem_names.update(re.findall(r'^\s*theorem ([\w.]+)', (ROOT/'formal/Benitoite/Release/Refinement'/(m+'.lean')).read_text(), re.M))
theorem_names.update(n for n,*_ in decls(reused))
for i,(name,full) in enumerate(entries.items(),1):
    for group in re.findall(r'[({]([^:(){}]+)\s*:', full):
        for binder in group.split():
            if binder.isidentifier() and len(re.findall(r'(?<![\w])'+re.escape(binder)+r'(?![\w])', full)) == 1:
                full = re.sub(r'(?<![\w])'+re.escape(binder)+r'(?![\w])', '_'+binder, full)
    kind = 'theorem' if name in theorem_names else 'noncomputable def'
    sig+=f'-- {name}\n{kind} signature{i:03d} : {full} := @{name}\n\n' 
sig+='end Benitoite.Release.Refinement\n'
sig+='open Lean Elab Command in\nrun_cmd do\n'
sig+='  let names := [\n'+',\n'.join('    `'+PREFIX+f'signature{i:03d}' for i in range(len(entries)+1))+'\n  ]\n'
sig+='  logInfo m!"LOCAL_CONSTANTS {names.length}"\n  for name in names do\n    elabCommand (← `(#print axioms $(mkIdent name)))\n'
(HERE/'signatures.lean').write_text(sig)

s2 = {
3:'Eff.memFail_singleFail',4:'Eff.eq_of_sub_of_sub',5:'Eff.allows_norm',6:'Eff.TopAtoms.norm',29:'Eff.substRho_empty',30:'Eff.substRho_name',
44:'Ty.shift_compare_norm',45:'Ty.shift_compare',46:'shift_map',47:'Ty.shift_compareList',48:'Ty.sortUnique_shift',
77:'Ty.rawBind_norm_wf',78:'rawBindTys_norm_wf',79:'Eff.rawBind_norm_wf',80:'Eff.substAt_atoms_wf',81:'Ty.bind_wf',82:'Ty.rawShift_eq_rawBind',83:'Ty.rawShiftTys_eq_rawBindTys',84:'Eff.rawShift_eq_rawBind',86:'Ty.substAt_wf',87:'Ty.subst_wf',88:'Eff.bind_wf',89:'Eff.subst_wf',90:'Ty.substList_wf',91:'Eff.substAt_wf',
102:'Ty.rawShift_of_wf',103:'Ty.rawShiftTys_of_wf',104:'Eff.rawShift_of_wf',105:'Ty.shift_of_wf',106:'Eff.shift_of_wf',
117:'shiftIndex_compare',118:'Ty.shiftTypes_compare',119:'Ty.trees_shiftTypes_compare',120:'Eff.tree_shiftTypes_compare',121:'Ty.norm_shiftTypes',122:'Ty.normTys_shiftTypes',123:'Eff.norm_shiftTypes',124:'Ty.rawShift_canonical',125:'Eff.rawShift_canonical',126:'Ty.shift_canonical',127:'Eff.shift_canonical',128:'shiftTypes_zero',129:'shiftTypesList_zero',130:'shiftRowsTypes_zero',131:'Ty.shift_zero_norm',132:'Eff.shift_zero_norm'}
s1_special={144:'typeEnvAt_support'}
rows=[]
for line in (HERE.parent/'detail.md').read_text().splitlines():
    if not re.match(r'\| FND\d{3} \|',line): continue
    parts=[x.strip() for x in line.split('|')[1:-1]]
    code,old,file,status,explain=parts
    n=int(code[3:]); old=old.strip('`')
    new=None; unit=None
    if status.startswith('L10'):
        unit=int(re.search(r'\.(\d+)',status)[1])
        if 44<=unit<=51:
            new=s2.get(n,old)
            disposition='本群で完了'
        else:
            assert 31<=unit<=43, (n,unit)
            new=s1_special.get(n,old)
            disposition='前群で完了'
    elif status=='済':
        new=explain.split('：',1)[1]
        if new.startswith('private '): new=new.removeprefix('private ')
        new=new.split('（')[0].strip()
        disposition='既済'
    elif status=='不要': disposition='不要'
    else: raise ValueError(status)
    rows.append(dict(id=code,old=old,old_file='formal/Benitoite/Release/'+file.strip('`'),detail_status=status,
                     disposition=disposition,unit=unit,new=PREFIX+new if new else None,reason=explain))
assert len(rows)==158
counts=collections.Counter(r['disposition'] for r in rows)
assert counts=={'本群で完了':68,'前群で完了':31,'既済':16,'不要':43},counts
assert collections.Counter(r['unit'] for r in rows if r['disposition']=='本群で完了')=={44:5,45:7,46:7,47:10,48:12,49:8,50:13,51:6}
(HERE/'foundation-map.json').write_text(json.dumps(dict(counts=counts,rows=rows),ensure_ascii=False,indent=2)+'\n')

fnd='import Lean\nimport Benitoite\n\n'
for r in rows:
    if not r['new']: continue
    if r['id']=='FND033': continue # 既存private。次のrun_cmdでモジュールと末尾名を照合する。
    fnd+=f'-- {r["id"]}\n#check {r["new"]}\n'
fnd+='''open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let some idx := env.getModuleIdx? `Benitoite.Release.Refinement.Normalize | throwError "MISSING_NORMALIZE"
  let names := env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == some idx && name.toString.endsWith ".normTys_sortUnique" then some name else none
  unless names.length == 1 do throwError "PRIVATE_FOUNDATION_COUNT {names.length}"
  logInfo "FOUNDATION_CHECKED 115"
'''
(HERE/'foundation.lean').write_text(fnd)

axioms=(HERE.parent/'s1/axioms.lean').read_text()
a=axioms.index('  for mod in [');b=axioms.index('  ] do',a)
# 元の6新規モジュールと再開で変更した全Leanモジュールを、生成宣言も含め監査する。
meta=json.loads((HERE/'review-initial-record.json').read_text())
snapshot=json.loads((Path(tempfile.gettempdir())/Path(meta['file']).name).read_text())
changed=[n for n,h in snapshot['files'].items() if n.startswith('formal/') and n.endswith('.lean') and
    hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h]
audit_modules=sorted(set([PREFIX+m for m in MODULES]+[n.removeprefix('formal/').removesuffix('.lean').replace('/','.') for n in changed]))
(HERE/'audit-modules.json').write_text(json.dumps(audit_modules,ensure_ascii=False,indent=2)+'\n')
axioms=axioms[:a]+'  for mod in [\n'+',\n'.join('    `'+m for m in audit_modules)+'\n'+axioms[b:]
# 既存の14判断76構成子を数え、四本の証明が扱う判断の内訳を保存する。
v_audit=(HERE.parent/'v/axioms.lean').read_text()
start=v_audit.index('  let judgments := ')
axioms+='\nopen Lean Elab Command in\nrun_cmd do\n  let env ← getEnv\n'+v_audit[start:]
axioms+='  logInfo m!"TYPING_JUDGMENTS {judgments.length}"\n' 
(HERE/'axioms.lean').write_text(axioms)

bnd=(HERE/'boundary.lean').read_text().split('\n-- 全境界宣言の公理依存')[0]
bnd+='''\n-- 全境界宣言の公理依存。匿名exampleではなく名前付きの言明を監査する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "L10S2Boundary." then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"LOCAL_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
'''
(HERE/'boundary.lean').write_text(bnd)
print('署名',len(entries)+1,'新しい公開宣言',len(sources),'foundation',dict(counts))
