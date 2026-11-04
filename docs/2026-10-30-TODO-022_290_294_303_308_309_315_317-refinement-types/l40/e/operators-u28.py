"""Rust原始演算子107行の原スキーマと既存D接続73行を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib,json,re,collections
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SCALARS={"INTEGER":("integer64","integer"),"INTEGER8":("integer8","integer8"),"INTEGER16":("integer16","integer16"),"INTEGER32":("integer32","integer32"),"UNSIGNED_INTEGER16":("unsignedInteger16","unsignedInteger16"),"UNSIGNED_INTEGER32":("unsignedInteger32","unsignedInteger32"),"UNSIGNED_INTEGER64":("unsignedInteger64","unsignedInteger64"),"BYTE":("byte","byte"),"CHARACTER":("character","character"),"FLOAT32":("float32","float32"),"FLOAT":("float64","float"),"DECIMAL":("decimal","decimal"),"STRING":("string","string")}
def digest(p):
 b=p.read_bytes();return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def main():
 path=ROOT/'crates/benitoite/src/builtins/table.rs';text=path.read_text()
 block=text.split('pub const OPERATORS:',1)[1].split('];',1)[0]
 raw=re.findall(r'OperatorKind::(\w+),\s*BuiltinTypeId::(\w+),\s*"([^"]+)"',block)
 assert len(raw)==107 and len({r[2] for r in raw})==107
 rows=[];examples={"StandardArithmeticResponse":[],"StandardOrderResponse":[]}
 for op,operand,name in raw:
  kind,base=SCALARS[operand];unary=op=='Neg';labels=['value'] if unary else ['left','right']
  params=[base] if unary else [base,base];ret='boolean' if op in ['Lt','Le','Gt','Ge'] else base
  status='open';evidence=[];S=[]
  if operand.startswith(('INTEGER','UNSIGNED_INTEGER')) and op in ['Add','Sub','Mul','Neg']:
   status='pure-leaf';api={'Add':'add','Sub':'subtract','Mul':'multiply','Neg':'negate'}[op]
   evidence=['StandardArithmeticResponse.table_response','StandardArithmeticResponse.response_math'];S=['S01']
   signature=f'StandardArithmeticResponse.API.signature .{kind} .{api}'
   named=f'StandardArithmeticResponse.API.name .{kind} .{api}'
   module='StandardArithmeticResponse'
  elif operand!='STRING' and op in ['Lt','Le','Gt','Ge']:
   status='pure-leaf';comparison={'Lt':'lt','Le':'le','Gt':'gt','Ge':'ge'}[op]
   evidence=['StandardOrderResponse.table_response','StandardOrderResponse.response_math'];S=['S03']
   signature=f'StandardOrderResponse.signature .{kind}'
   named=f'StandardOrderResponse.name .{kind} .{comparison}'
   module='StandardOrderResponse'
  elif op in ['IntDiv','Mod']:
   S=['S02'];evidence=['Benitoite.Interval.IntKind.checkedDivMod']
  if status=='pure-leaf':
   expected='⟨[],0,['+','.join(json.dumps(x) for x in labels)+'],['+','.join(f'(.base .{x})' for x in params)+f'],.base .{ret},Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩'
   examples[module] += [f'-- {name}: registered {operand}/{op}',f'example : ({signature}) = ({expected} : PrimSig) ∧',f'    {named} = "{name}" := ⟨rfl,rfl⟩','']
  rows.append({'name':name,'rust_operand':operand,'operator':op,'tparams':[],'row_count':0,'range_count':0,'names':labels,'params':params,'result':ret,'effect':[],
    'ordinary':status,'additional_S':S,'evidence':evidence,
    'unproved':[] if status=='pure-leaf' else ['この実名・原署名の全BuiltinArgs→同namedδ→型/Ground/Adequate/非exitはL40独立未完。新しい演算算法は追加しない。']})
 assert collections.Counter(r['ordinary'] for r in rows)=={'pure-leaf':73,'open':34}
 for module,lines in examples.items():
  p=ROOT/f'formal/Benitoite/Release/Refinement/{module}.lean';code=p.read_text();marker='-- 原始演算子の登録スキーマとの全欄対応。'
  if marker in code:code=code[:code.index(marker)]+'end Benitoite.Release.Refinement.'+module+'\n'
  idx=code.rindex('end Benitoite')
  code=code[:idx]+marker+'\n'+'\n'.join(lines)+'\n'+code[idx:];p.write_text(code)
  assert p.stat().st_size<=100000
 out={'updated_utc':datetime.now(timezone.utc).isoformat(),'source':{'path':str(path.relative_to(ROOT)),**digest(path)},'source_scheme':'builtin_scheme Operator branch; builtin parameter_names VALUE/LEFT/RIGHT。Rust/Leanの実行全比較ではない。',
  'counts':{'operators':107,'pure_leaf':73,'independent_open':34,'equality_names':2,'equality_scalar_domains':12},'rows':rows,
  'full_equality':{'names':['%eq','%ne'],'tparams':[{'kind':'value','constraints':{'equality':True,'key':False}}],'params':['T','T'],'parameter_names':['left','right'],'result':'Boolean','row_count':0,'range_count':0,
    'status':'Full署名を維持したscalar-domain条件付きpartial。構造EqualityはL40独立未完。','evidence':['StandardEqualityResponse.table_response','StandardEqualityResponse.response_math'],
    'retained':'元の篩付きT・Equality sat・Ordinary・Annotationを全BuiltinArgsから回収し、同じTで既存δを呼ぶ。',
    'unproved_statement':'scalar-domain条件を除いた全Equality適格T（List/data/Bytes/Map/Set等）の具体δ/構造走査と型/Ground/Adequate/非exit。狭い署名又はTyped providerで補わない。'},
  'internal_list_patterns':{'names':['%List.length','%List.getFront','%List.getBack','%List.slice'],'schema':'一value型引数T、空row/range。xs、xs/index、xs/front/back。結果Integer/T/List[T]。',
    'evidence':['StandardSafe.front_response','StandardSafeSlice.slice_response'],'limits':'安全な内部契約の実証範囲は既存の.26記録を正とする。元の全内部署名を一括閉鎖しない。'},
  'limits':['通常資源/外部の実モデル充足はL60。L40の未完を移管しない。','区間計算/警告/returned/failed/第一失敗の接続は元.29〜35。今回の数値leafの成功と区別する。']}
 dest=HERE/'operators-r1-u28.json';dest.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');assert dest.stat().st_size<=100000
 print(json.dumps(out['counts']))
if __name__=='__main__':main()
