# coding: utf-8
"""全場合・旧逆転・API・義務の対応と入力の識別を再生成する。"""
from pathlib import Path
import argparse,collections,hashlib,json,re
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
CHANGE=HERE.parents[1]
FORMAL=ROOT/'formal'
NEW=['TelApplication','StandardKeyTyping','StandardContracts','StandardScalar','StandardBodies','IntervalFailure','ValueInversion']

def digest(p):
 data=p.read_bytes();return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def ctors(path,name):
 s=path.read_text();m=re.search(r'^\s*inductive '+re.escape(name)+r'(?=\s|:)',s,re.M);assert m,(path,name)
 tail=s[m.end():];end=re.search(r'^\s*(?:inductive|structure|def|abbrev|theorem|namespace|end)\b',tail,re.M)
 if end:tail=tail[:end.start()]
 return [a or b for a,b in re.findall(r'^\s*\| (?:«(\w+)»|(\w+))',tail,re.M)]

def part(s,a,b):return s.split(a,1)[1].split(b,1)[0]

def units(s):
 out=set()
 for p in re.split(r'[/、]',s):
  if '〜' in p:
   a,b=map(int,p.split('〜'));out.update(range(a,b+1))
  elif p.isdigit():out.add(int(p))
 return out

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--tmp',required=True,type=Path);args=ap.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
 rel=FORMAL/'Benitoite/Release/Refinement';evalp=FORMAL/'Benitoite/Interval/Eval.lean'
 defs={}
 groups=[('Syntax.lean',{'Val':25,'Comp':16}),('RuntimeSyntax.lean',{'State':4,'Frame':7,'Cell':6}),('Types.lean',{'Ty':21}),('Typing.lean',{'HasTypeVQ':29,'HasTypeVsQ':2,'HasTypeEachQ':2,'HasTypeCQ':24}),('Le.lean',{'Ty.LeQ':14,'TelLe':2,'TelClosure':2,'TypeArgsLe':4}),('StateTyping.lean',{'ContTy':10}),('KeyContracts.lean',{'Observation.KeyShape':11,'Observation.KeySlots':2,'Observation.KeyPairs':2}),('Semantics.lean',{'Step':76})]
 for path,expected in groups:
  for name,n in expected.items():
   xs=ctors(rel/path,name);assert len(xs)==n,(name,len(xs),xs);defs[name]=xs
 h04={'EvalPartial':69,'EvalArguments':4,'EvalTypedArguments':4,'EvalArms':6,'EvalWidthArms':6,'EvalResultArms':6,'EvalBlock':14,'EvalStandard':7}
 for name,n in h04.items():
  xs=ctors(evalp,name);assert len(xs)==n,(name,len(xs));defs[name]=xs
 assert sum(h04.values())-7==109
 proof=(rel/'IntervalFailure.lean').read_text()
 for judgement,thm in [('EvalPartial','expr_failure'),('EvalArms','armList_failure'),('EvalWidthArms','armListKind_failure'),('EvalResultArms','resultArmList_failure'),('EvalBlock','block_failure')]:
  body=part(proof,'theorem '+thm+' ','termination_by')
  seen=set()
  for line in body.splitlines():
   if re.match(r'^    \| \.',line):seen.update(re.findall(r'\.(\w+)',line.split('=>')[0]))
  assert set(defs[judgement])<=seen,(judgement,set(defs[judgement])-seen)
 old=(FORMAL/'Benitoite/Release/Lemmas/Inversion.lean').read_text()
 oldnames=re.findall(r'^theorem ((?:HasTypeVQ|HasTypeCQ)\.inv_\w+)\b',old,re.M)
 assert len(oldnames)==31
 plantext=(CHANGE/'plan.md').read_text();plan={}
 for l in plantext.splitlines():
  if re.match(r'^\| O\d{3} \|',l):
   f=[x.strip() for x in l.split('|')[1:-1]]
   if 'L40' in f[3]:plan[f[0]]=f
 assert len(plan)==56,len(plan)
 detail=(HERE.parent/'detail.md').read_text();rows=[]
 for l in part(detail,'## 7.','## 8.').splitlines():
  if re.match(r'^\| O\d{3} \|',l):rows.append([x.strip() for x in l.split('|')[1:-1]])
 assert len(rows)==64
 ids={r[0] for r in rows};assert ids-set(plan)=={'O006','O015','O050','O054','O016','O027','O084','O118'}
 union=set(plan)
 stagecounts={}
 for n in ['l20','l30']:
  stage=set()
  for l in (CHANGE/n/'stage-results.md').read_text().splitlines():
   if re.match(r'^\| O\d{3}',l):
    f=[x.strip() for x in l.split('|')[1:-1]]
    if 'L40' in f[-1]:stage.add(re.match(r'O\d{3}',f[0])[0])
  stagecounts[n]=len(stage);union|=stage
 assert stagecounts=={'l20':37,'l30':21},stagecounts
 assert len(union)==60
 assert union-set(plan)=={'O006','O015','O050','O054'}
 source=(HERE.parent/'results.md').read_text()
 stepnames=re.findall(r'`(E_\w+)`',part(source,'### 既存76葉','### H04'))
 assert len(stepnames)==76 and set(stepnames)==set(defs['Step'])
 legacy=part(source,'## 旧31逆転定理の行き先','## F01')
 assert all('| '+n+' |' in legacy for n in oldnames)
 legacy_classes=collections.Counter()
 for l in legacy.splitlines():
  if re.match(r'^\| HasType[V|C]Q.inv_',l):legacy_classes[l.split('|')[2].strip()]+=1
 assert legacy_classes=={'最初の旧14移植':14,'既済み継承':7,'同種の残り10':10},legacy_classes
 api=[]
 for l in source.splitlines():
  if re.match(r'^\| \w+\.bnt \|',l):
   f=[x.strip() for x in l.split('|')[1:-1]];mod=f[0][:-4]
   path=ROOT/'crates/benitoite/src/prelude/stdlib'/f[0]
   names=re.findall(r'^public function (\w+)',path.read_text(),re.M)
   assert len(names)==int(f[-1])
   for n in names:assert n in f[1]+'、'+f[2],(mod,n)
   api.append({'module':mod,'count':len(names),'source':digest(path)})
 assert len(api)==23 and sum(x['count'] for x in api)==328
 sig=(HERE/'signatures.md').read_bytes();assert len(sig)<=100_000
 # 全形式化ソースのmanifestは大きくなるので一時領域に置き、識別だけを保存する。
 manifest={str(p.relative_to(ROOT)):digest(p) for p in sorted(FORMAL.rglob('*.lean')) if '.lake' not in p.parts}
 raw=args.tmp/'formal-sources.json';raw.write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n')
 selected=[rel/(n+'.lean') for n in NEW]+[FORMAL/'Benitoite.lean',FORMAL/'lakefile.toml',FORMAL/'lean-toolchain',ROOT/'docs/design/01-spec/01-12-core-calculus.md',ROOT/'docs/design/07-quality/07-04-formal-semantics.md',CHANGE/'plan.md',CHANGE/'README.md',CHANGE/'implementation-request.md',HERE.parent/'detail.md',HERE.parent/'results.md',CHANGE/'reviews/RV-L40-plan.md',CHANGE/'l20/n/h04-handoff.md',CHANGE/'l20/n/h04-handoff.lean',CHANGE/'l30/l/review-handoffs.md']
 selected += [p for p in HERE.rglob('*') if p.is_file() and p.name not in {'results.md','inventory.json','checks.json','audit-summary.json','completion-check.json'}]
 inv={'B_WORK':'2a2453825e956404fbe82d0a586d8776f323150a','branch':'m014/l40.a','basis':'起動依頼の指定を採用。gitコマンドは担当から実行していない。未コミット差分と新規ファイルは入力ハッシュで識別する','configuration':'既定8対象、Lean -M12288、増分ビルド','formal_manifest':digest(raw),'formal_sources':len(manifest),'constructors':{k:len(v) for k,v in defs.items()},'h04_count':109,'standard_count':7,'legacy_classes':dict(legacy_classes),'N_V':1,'N_C':9,'preproved_legacy_inversion':['HasTypeVQ.inv_var'],'remaining_legacy_before_B':23,'remaining_legacy_B':13,'plan_obligations':56,'stage_obligations':stagecounts,'union_obligations':60,'all_obligations':64,'api':api,'signature_bytes':len(sig),'inputs':{str(p.relative_to(ROOT)):digest(p) for p in sorted(set(selected))}}
 selected_rust=['Cargo.toml','Cargo.lock','rust-toolchain.toml','crates/benitoite/Cargo.toml','crates/benitoite/src/lib.rs','crates/benitoite/src/pipeline.rs','crates/benitoite/src/typeck/decls.rs','crates/benitoite/src/typeck/solve.rs','crates/benitoite/src/ir/check.rs','crates/benitoite/src/ir/core_ir.rs','crates/benitoite/src/base/decimal.rs','crates/benitoite/src/builtins/funcs/decimal.rs','crates/benitoite/src/types/builtin.rs']
 inv['rust_inputs']={n:digest(ROOT/n) for n in selected_rust if (ROOT/n).exists()}
 c={
 'C01':['Ty.LeQ','TelLe','TelClosure','TypeArgsLe'],
 'C02':['Ty.LeQ.listCore','Ty.LeQ.listCore_right','Ty.LeQ.fnCore','Ty.LeQ.fnCore_right','Ty.LeQ.names_eq','Ty.LeQ.refCore','Ty.LeQ.refCore_right'],
 'C03':['Ty.listCore_norm','Ty.fnCore_norm','Ty.refCore_norm','TelClosure.trans','TelLe.of_norm_eq'],
 'C04':['HasTypeVQ.inv_list','HasTypeVQ.inv_closure','canonical_ref','canonical_lazy','Ty.LeQ.lazyCore_right'],
 'C05':['HasTypeVQ.inv_const','HasTypeVQ.facts','HasTypeVQ.subtype_facts','HasTypeVQ.list_element_facts','HasTypeVQ.field_facts_by_type','HasTypeVQ.constructor_field_inputs'],
 'C06':['Ty.LeQ.holds','HasTypeVQ.inv_checked','HasTypeVQ.inv_checkedRequest','HasTypeVQ.inv_checkedAt','HasTypeVQ.checkedRequest_content'],
 'C07':['ModelHttp.valueRun_typed','ModelHttp.valueRun_request','ModelHttp.valueRun_checkedAt_request','ModelHttp.valueRun_embed'],
 'C08':['AtPrepared.request','CheckedWitness.of_prepared_request','checkAt.sound','checkAt.absolute'],
 'C09':['Ty.VarianceOK','Program.VarianceValid','Program.ParamOccursInFields','variance_field_mono'],
 'C10':['MeaningTransport.variance_meaning','MeaningTransport.variance_meaning_args','MeaningTransport.field_order','valueMeaning_sub'],
 'C11':['typed_value_meaning_closed','inhabits_of_typed','ValueMeaning.assume'],
 'C12':['type_subst_all','close_value_typed','StateTyE.store_reply','HasTypeVQ.narrow'],
 'C13':['HasTypeCQ.ite_branch','ClosureTy.ite_selected','StateTyE.if_true','StateTyE.if_false'],
 'C14':['selectOracle_response','selectRelease_response','selectFresh_empty','StateTyE.control_leaf'],
 'C16':['Ty.carrierFacts','Const.NumericRepresented.carrierFacts'],
 'C17':['typed_observation','observations_16','HasTypeVQ.represented'],
 'C18':['measure_machine_exact','measure_stable','field_measure_stable','NumericContracts.binary_normal','NumericContracts.neg_normal','NumericContracts.decimal_result','NormalResultLeaves.binary_leaf','NormalResultLeaves.binary_entails_at'],
 'C19':['Observation.KeyShape.code','Key.code_of_shape','Key.equal_of_shapes','decimal_key_compare','Key.map_measure','Key.set_measure','Key.normalizeMap','Key.normalizeSet'],
 'C20':['PreparedLeaf.checkIn','PreparedLeaf.entailsIn','PreparedLeaf.bind_entails','checked_refinement','ValueRel.toApprox_eq','normal_shared_iff','typed_returned_mark','connect_bind','connect_return']}
 names=(args.tmp/'audit-targets.txt').read_text().splitlines()
 resolved={}
 for cid,symbols in c.items():
  resolved[cid]={}
  for symbol in symbols:
   found=[n for n in names if n.startswith('Benitoite.Release.Refinement.') and n.endswith('.'+symbol)]
   assert found,(cid,symbol)
   resolved[cid][symbol]=found
 resolved['C15']={'general_leaves':76,'step_conclusions':60,'target_state_only':16}
 inv['deductions']=resolved
 source_declarations=[]
 for mod in NEW:
  path=rel/(mod+'.lean')
  for i,line in enumerate(path.read_text().splitlines(),1):
   m=re.match(r'\s*(private )?(def|theorem|structure|inductive|instance|abbrev) (\S+)',line)
   if m:source_declarations.append({'module':mod,'line':i,'kind':m[2],'name_as_written':m[3],'private':bool(m[1])})
 inv['handwritten_declarations']=len(source_declarations)
 inv['handwritten_by_module']=dict(collections.Counter(x['module'] for x in source_declarations))
 (HERE/'declarations.json').write_text(json.dumps(source_declarations,ensure_ascii=False,indent=2)+'\n')
 if (args.tmp/'key_probe.log').exists():inv['key_probe_raw']=digest(args.tmp/'key_probe.log')
 (HERE/'inventory.json').write_text(json.dumps(inv,ensure_ascii=False,indent=2)+'\n')
 assert (HERE/'inventory.json').stat().st_size<=100_000
 table=['# 義務の担当分の判定\n\n2026-11-03。今回の範囲はAとF1である。段全体の閉鎖は判定しない。独立レビューと受け入れは取りまとめ・設計者が行う。\n\n| 義務 | 今回の担当分の判定と証拠 | 残るL40単位と後段 |\n|---|---|---|\n']
 specific={'O021':'署名と元の枠を記録。単位の切替時刻に未採取があり、初期実装の外側時間は未分離。能動時間や群Bの単価へ外挿しない',
  'O090':'F1の第一候補を証明。既存のG07と重ねず、検査の時間と初期実装の未分離を記録',
  'O091':'F1分完了。tracked_failure_soundは指定の全Parametersで成立。正常/returnedと最初の実失敗を完了と数えない',
  'O137':'F1の失敗成分を完了。演算自身の失敗に正常な子のContainsを使う。δとの接続と正常/returnedは残る',
  'O169':'F1の第一候補を完了。expr_failure・block_failure・全引数/腕から実analyzeへ接続。第二候補と実δの合成は残る',
  'O016':'既定import全体の公理依存をaudit.pyで再生成し、許可三公理だけと確認。件数とハッシュはaudit-summary.json。独立レビューは未実施',
  'O027':'-M12288と検査のコマンド・終了・外側時間を保存。正式RSSは未取得（計画上の非採取）',
  'O084':'定義・型検査・証明・Rustの五代表・全比較・自己点検・独立レビューを区別。自己点検を独立レビュー済みとしない',
  'O118':'新定義と写しを照合。旧Release/処理系/計画/レビュー記録を変更しない。新しい本番コメントに工程ID・絶対パスを置かない'}
 handled={1,2,3,4,5,30,31,32}
 for oid,origin,kind,us,condition,later in rows:
  remaining=sorted(units(us)-handled)
  status=specific.get(oid,'今回に割り当てられた証明の閉鎖なし。detailの当該単位と既存の控除を維持し、後続へ渡す')
  table.append('| '+oid+' | '+status+' | '+('・'.join(f'.{x:02d}' for x in remaining) or '群末の照合')+'。'+later+' |\n')
 (HERE/'obligations.md').write_text(''.join(table))
 print(json.dumps({k:inv[k] for k in ['formal_sources','h04_count','standard_count','legacy_classes','plan_obligations','union_obligations','all_obligations','signature_bytes']},ensure_ascii=False))
if __name__=='__main__':main()
