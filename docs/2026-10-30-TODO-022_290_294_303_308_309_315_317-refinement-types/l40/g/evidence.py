"""段別の証拠を、現行ソースの宣言位置とともに再生成する。"""
from pathlib import Path
import json
import re
from reconcile import HERE, STAGE, REF, ROOT, rows, section, save

# 同じ証拠を複数の義務が利用する。件数は義務番号で数え、宣言数と加算しない。
UNITS = {
  6:['ValueInversion:HasTypeVQ.inv_var,HasTypeVQ.inv_fnRef,HasTypeVQ.inv_prim'],
  7:['ValueInversion:HasTypeVQ.inv_op,HasTypeVQ.inv_lam,HasTypeVQ.inv_dependentLam,HasTypeVQ.inv_raise'],
  8:['CollectionInversion:HasTypeVQ.inv_mapV,HasTypeVQ.inv_setV,HasTypeVQ.inv_bytesV'],
  9:['ValueInversion:HasTypeVQ.inv_dict,HasTypeVQ.inv_super','ComputationInversion:HasTypeCQ.inv_app,HasTypeCQ.inv_let,HasTypeCQ.inv_escape,HasTypeCQ.app_tel'],
 10:['StandardVariance:valid,covariant_positions','StandardHigherPositions:option_checked,consumer_checked,reference_checked,fail_checked,names_arity_checked'],
 11:['TelApplication:TelClosure.apply','ApplicationInputs:StateTyE.app_inputs'],
 12:['CanonicalValues:HasTypeVQ.canonical_scalar,HasTypeVQ.canonical_boolean,HasTypeVQ.canonical_list,HasTypeVQ.canonical_data,HasTypeVQ.inv_atError'],
 13:['CanonicalValues:HasTypeVQ.inv_externalRef,HasTypeVQ.inv_externalHandle,HasTypeVQ.inv_pathBases,HasTypeVQ.inv_scopePattern,HasTypeVQ.canonical_held'],
 14:['CanonicalCells:StoreOk.ref_cell,StoreOk.lazy_cell,StoreOk.cont_cell,StoreOk.builder_cell,HasTypeVQ.inv_loc'],
 15:['LeafInputs:StateTyE.inputs,StateTyE.lambda_inputs,StateTyE.match_inputs,StateTyE.if_inputs,StateTyE.guard_op_inputs','ComputationInputs:HasTypeCQ.inputs','ClosureStateLeaves:StateTyE.lambda_beta_all','Step:step_lambda'],
 16:['StandardInteger:integerDelta_floor,integerDelta_absolute,integerDelta_minMax,integerDelta_bitwise,integerDelta_shift,integerDelta_binary_facts'],
 17:['StandardByteCharacter:byte_compare,byteConvert_some,characterConvert_some,character_code'],
 18:['StandardFloat:float32_compare_reply,float64_compare_reply'],
 19:['StandardDecimal:decimalRound_represented,decimalRound_typed,decimalDelta_round,decimalFromFloatDelta'],
 20:['StandardFactExamples:length_le,false_fact_typing,false_if_typing,guard_body_typing'],
 21:['StandardCollections:string_lengths,list_length,bytes_length','StandardListResponse:related_response','StandardBytesResponse:response'],
 22:['StandardKeySound:key_table_sound,key_values_sound,key_each_sound,key_closed_slots,key_map_normal,key_set_normal'],
 23:['StandardHeadTailBodies:from_typed','StandardCollectionRefinedBodies:seven_public_rows,program_typed,response_assumptions'],
 24:['StandardMapReplaceValues:response,delta_aligned','StandardCollectionRefinedBodies:seven_public_rows,program_typed,response_assumptions'],
 25:['StandardRecordFields:record_valid,record_chain,whole_construct','StandardDecodeBodies:postprocess_wellTyped,postprocess_row_typed,postprocess_error_steps,postprocess_raw_steps,checkedRawResult,DecodeResult,postprocess_all,postprocess_raw_general_steps,decode_let_typed','StandardDecodeConnection:decodeThen,decodeThen_typed,decodeThen_normal,decodeThen_firstReturn,decodeThen_failed'],
 26:['StandardSafeBodies:precise_rows_typed,head_row_typed','StandardHeadTailBodies:concrete_nonempty_public_typed'],
 27:['StandardHigherPositions:dep_apply,length_all_images,callback_checked,result_checked,effect_checked,list_checked,option_checked,consumer_checked,reference_checked,fail_checked,names_arity_checked'],
 28:['StandardArithmeticResponse:response_math','StandardIntegerResponse:minMax_response','StandardConversionResponse:response','StandardDecimalResponse:response','StandardByteStringResponse:response','StandardCharacterResponse:response','StandardIntegerTextResponse:response','StandardFloatMathResponse:response','StandardNumericRemainingResponse:response','StandardStringOrdinaryResponse:response','StandardBytesOrdinaryResponse:response','StandardListRemainingResponse:response'],
 29:['StandardIntegerFailure:binary_delta_split,divMod_delta_split,division_overflow_iff,floor_delta_split,floorModulo_normal,signed_minimum_stops,shift_outside'],
 30:['IntervalFailure:expr_failure,typed_arguments_failure,arguments_failure'],
 31:['IntervalFailure:block_failure,armList_failure,armListKind_failure,resultArmList_failure'],
 32:['IntervalFailure:report_failure,analyzeExpr_failure,tracked_failure_sound'],
 33:['IntervalFlowLeaves:joinV,normalF,returnF,seqF,joinF,normal_mem_of_related,returned_mem_of_related,return_leaf,expression_block_leaf,match_integer_leaf,match_width_leaf,match_result_leaf,match_abrupt_leaf'],
 34:['FirstFailure:first_error,pure_failure,first_failure_handoff,old_candidate_false,revised_counterexample_accepted'],
 35:['IntervalControlLeaves:normal_state_member,escape_mark_member,error_let_typed,error_mark_typed,typed_first_failure'],
}

UNITS[28] += ['StandardOperatorArguments:arguments',
  'StandardIntegerOperatorResponse:response','StandardFloatOperatorResponse:response',
  'StandardDecimalOperatorResponse:response','StandardStringOperatorResponse:response',
  'StandardOperatorResponse:entries_count,entries_unique,table_response',
  'StandardStructuralEqualityResponse:table_response,reply_normal']

# 表の各行では、同じ単位の先頭の代表ではなく、その構文・演算を読む宣言を示す。
CASE_SPECS={
 'Ty.LeQ':['Le:Ty.LeQ','ValueInversion:HasTypeVQ.inv_var'],
 'TelLe':['Le:TelLe','TelApplication:TelLe.open_done,TelLe.open_tail'],
 'TelClosure':['Le:TelClosure','TelApplication:TelClosure.apply'],
 'TypeArgsLe':['Le:TypeArgsLe','StandardVariance:valid'],
 'Polarity.compose と位置':['VarianceSyntax:Polarity.compose','StandardVariance:valid'],
 '変性の構造再帰':['VarianceValidation:Ty.VarianceOK','StandardVariance:valid'],
 '組込みの共変位置':['StandardVariance:covariant_positions'],
 '範囲添字':['HeldValues:Ty.LeQ.holds','CanonicalValues:HasTypeVQ.canonical_held'],
 'const':['ValueFacts:HasTypeVQ.inv_const,HasTypeVQ.facts'],
 'lam / dependentLam':['ValueInversion:HasTypeVQ.inv_lam,HasTypeVQ.inv_dependentLam'],
 'closure':['Canonical:HasTypeVQ.inv_closure','LeafInputs:StateTyE.closure_contract_inputs'],
 'raise':['ValueInversion:HasTypeVQ.inv_raise'],
 'con':['ValueFacts:HasTypeVQ.constructor_field_inputs','CanonicalValues:HasTypeVQ.canonical_data'],
 'list':['ValueInversion:HasTypeVQ.inv_list_core','ValueFacts:HasTypeVQ.list_element_facts'],
 'loc':['CanonicalCells:HasTypeVQ.inv_loc,StoreOk.ref_cell,StoreOk.lazy_cell'],
 'mapV':['CollectionInversion:HasTypeVQ.inv_mapV'],
 'setV':['CollectionInversion:HasTypeVQ.inv_setV'],
 'bytesV':['CollectionInversion:HasTypeVQ.inv_bytesV'],
 'dict / super':['ValueInversion:HasTypeVQ.inv_dict,HasTypeVQ.inv_super'],
 'externalRef':['CanonicalValues:HasTypeVQ.inv_externalRef'],
 'externalHandle':['CanonicalValues:HasTypeVQ.inv_externalHandle'],
 'pathBases / scopePattern':['CanonicalValues:HasTypeVQ.inv_pathBases,HasTypeVQ.inv_scopePattern'],
 'checked / checkedRequest / checkedAt':['HeldValues:HasTypeVQ.inv_checked,HasTypeVQ.inv_checkedRequest,HasTypeVQ.inv_checkedAt'],
 'atError':['CanonicalValues:HasTypeVQ.inv_atError'],
 'app':['ComputationInversion:HasTypeCQ.inv_app,HasTypeCQ.app_tel','ApplicationInputs:StateTyE.app_inputs'],
 'ret / escape':['DependentBeta:HasTypeCQ.ret_value','ComputationInversion:HasTypeCQ.inv_escape'],
 'letIn / meth':['ComputationInversion:HasTypeCQ.inv_let','ComputationInputs:HasTypeCQ.inputs'],
 'ite':['StandardFactExamples:false_if_typing','LeafInputs:StateTyE.if_inputs'],
 'match':['ComputationInputs:HasTypeCQ.inv_match','LeafInputs:StateTyE.match_inputs'],
 'handle / use / resume':['ComputationInputs:HasTypeCQ.inputs'],
 'builderLet / builderOp / lazyC':['CanonicalCells:StoreOk.builder_cell,StoreOk.lazy_cell','ComputationInputs:HasTypeCQ.inputs'],
 'externalCall / issuePathBases / checkAt':['ComputationInputs:HasTypeCQ.inputs','CanonicalValues:HasTypeVQ.inv_atError'],
 'integer':['StandardInteger:integerConvert_result,integerDelta_binary_facts'],
 'character':['StandardByteCharacter:character_scalar,character_code'],
 'float64 / float32（2）':['StandardFloat:float32_class_reply,float64_class_reply,float32_compare_reply,float64_compare_reply'],
 'decimal':['StandardDecimal:decimalRound_represented,decimal_compare_reply'],
 'boolean':['CanonicalValues:HasTypeVQ.canonical_boolean','StandardFactExamples:false_if_typing'],
 'unit':['CanonicalValues:HasTypeVQ.canonical_scalar','TypedMeaning:typed_value_meaning_closed'],
 'string':['StandardCollections:string_lengths'],
 'bytes':['StandardCollections:bytes_length','CollectionInversion:HasTypeVQ.inv_bytesV'],
 'map':['StandardKeySound:key_map_normal','CollectionInversion:HasTypeVQ.inv_mapV'],
 'set':['StandardKeySound:key_set_normal','CollectionInversion:HasTypeVQ.inv_setV'],
 'data':['CanonicalValues:HasTypeVQ.canonical_data','StandardRecordFields:record_valid,record_chain'],
 'target path/host/endpoint（3）':['CanonicalValues:HasTypeVQ.canonical_held','ExternalObservation:HasTypeVQ.represented'],
 '幅':['StandardInteger:integerConvert_result','CanonicalValues:HasTypeVQ.canonical_scalar'],
 '線形に使う算術':['StandardInteger:integerDelta_binary_facts,integerDelta_negate','StandardIntegerFailure:binary_delta_split'],
 '除算・剰余':['StandardIntegerFailure:divMod_delta_split,division_overflow_iff'],
 '整数比較':['StandardInteger:integerDelta_equality,integerDelta_order'],
 'Byte':['StandardByteCharacter:byteConvert_some,byteConvert_none,byte_compare'],
 'Character':['StandardByteCharacter:character_scalar,characterConvert_some,character_code,character_compare'],
 'Float':['StandardFloat:float32_class_reply,float64_class_reply,float32_compare_reply,float64_compare_reply'],
 'Decimal':['StandardDecimal:decimalRound_represented,decimalRound_typed,decimalDelta_round'],
 '応答':['StandardArithmeticResponse:response_math','StandardListResponse:response'],
 '区間の失敗理由':['StandardIntegerFailure:binary_delta_split,divMod_delta_split,floor_delta_split,absolute_split,shift_outside','IntervalFailure:tracked_failure_sound'],
}


def resolve(spec):
    module, names = spec.split(':')
    path = REF/(module+'.lean')
    source = path.read_text()
    output = []
    for name in names.split(','):
        match = re.search(r'^[ \t]*(?:private )?(?:theorem|def|abbrev|structure|inductive) '+re.escape(name)+r'(?=\s|[:({])',source,re.M)
        assert match, (module,name)
        # 完全名は環境監査の所属モジュールで再照合する。これは手書き名と所在である。
        line = source[:match.start()].count('\n')+1
        entry={'module':'Benitoite.Release.Refinement.'+module, 'source':str(path.relative_to(ROOT)),
               'line':line, 'name_as_written':name}
        if (HERE/'audit-summary.json').exists():
            candidates=[]
            for part in json.loads((HERE/'audit-summary.json').read_text())['declaration_parts']:
                for group in json.loads((HERE/part['file']).read_text()):
                    if group['module']==entry['module']:
                        candidates.extend(n for n,_,_ in group['declarations']
                                          if n.endswith('.'+name) and not n.startswith('_private.'))
            if not candidates and entry['module'] not in json.loads((HERE/'changed-modules.json').read_text())['modules']:
                namespace=re.search(r'^namespace (\S+)',source,re.M)[1]
                candidates=[namespace+'.'+name]
            assert len(candidates)==1,(module,name,candidates)
            entry['full_name']=candidates[0]
        output.append(entry)
    return output


def units(s):
    values=set()
    for token in re.split(r'[/、]',s):
        if '〜' in token:
            a,b=map(int,token.split('〜')); values.update(range(a,b+1))
        elif token.isdigit():values.add(int(token))
    return values


def main():
    evidence={str(u):[e for spec in specs for e in resolve(spec)] for u,specs in UNITS.items()}
    save('unit-evidence.json',evidence)
    detail=(STAGE/'detail.md').read_text()
    table=['# 64義務の段別照合\n\n2026-11-04、群 G の自己点検。全体の閉鎖は0行。'
           '証拠は現行の宣言の所在を [unit-evidence.json](unit-evidence.json) へ列挙し、'
           '全名・実際の型・仮定は段末の環境監査と署名の記録で照合する。'
           'E の再開2・3の表を現在の完了判定として引用せず、再開6・7で閉じた16行を優先する。\n\n'
           '| 義務 | 出どころ・分類 | L40 の判定・本番の証拠 | 残る段・境界 |\n|---|---|---|---|\n']
    for row in rows(section(detail,'## 7.','## 8.')):
        if not re.fullmatch(r'O\d{3}',row[0]):continue
        oid,origin,kind,us,condition,later=row
        selected=sorted(units(us)&UNITS.keys())
        names=[]
        for u in selected:
            # 一行で各担当単位の先頭の代表を指し、全宣言は同じ単位の一覧へ渡す。
            e=evidence[str(u)][0]
            names.append(f'.{u:02d}: `{e["name_as_written"]}`（{Path(e["source"]).stem}）')
        status={'継承':'継承を照合。再証明なし','技術':'担当する局所の証拠を照合','運用':'記録を照合。能動時間と待ちは未分離',
                '他段':'新規証明は他段','共通':'群 G の検査・写しと受け口。独立レビュー／受け入れは未了'}[kind]
        if oid in {'O022','O034','O062','O065','O135','O144'}:
            status='担当分の局所証拠を照合。再開2で独立未完を閉鎖。独立レビューと全体の閉鎖は別'
            names += ['`StandardOperatorResponse.table_response`（34実名）',
                      '`StandardStructuralEqualityResponse.table_response`（全入力）',
                      '`StandardDecode.decodeThen_normal/decodeThen_firstReturn`（同じResult）']
        if oid in {'O011','O050'}:later='L40.39 の段末の独立レビュー。'+later
        if oid=='O016':later='L40.39 の独立レビュー応答。'+later
        if oid=='O027':later='正式 RSS は取りまとめが別採取。'+later
        table.append(f'| {oid} | {origin}・{kind} | {status}。'+('；'.join(names) if names else condition)+f' | {later} |\n')
    (HERE/'obligations.md').write_text(''.join(table))
    # 出どころ33行のまま処分し、追加の群内所見は後段への受渡し表へ別記する。
    handoffs=rows(section(detail,'## 8.','## 9.'))[1:]
    lines=['# 33申し送りの処分\n\n2026-11-04。今回25・継承3・他段5の出どころを保つ。'
           '再開2で H02 の decode 接続と H03 の演算子・構造等号の独立未完を閉じた。'
           '実装を参照する行が重なっても義務数へ加算しない。\n\n'
           '| 番号 | 出どころ | 受け方 | 本番の証拠・判定 | 残る段 |\n|---|---|---|---|---|\n']
    for i,(origin,how,us,condition) in enumerate(handoffs,1):
        us=us.replace('〜','〜')
        chosen=sorted(units(us)&UNITS.keys())
        names=['`'+evidence[str(u)][0]['name_as_written']+'`' for u in chosen]
        state='処置を照合' if how=='今回' else ('継承を照合' if how=='継承' else '後段を固定')
        if i==2:state+='。decodeThen_normal/firstReturnとpostprocess_allで同じResultの接続を閉鎖'
        if i==3:state+='。34実名のtable_responseと構造Equality全入力を接続'
        lines.append(f'| H{i:02d} | {origin} | {how} | {state}。'+('、'.join(names) if names else '既定の既存葉')+f' | {condition} |\n')
    (HERE/'handoffs.md').write_text(''.join(lines))
    cases=['# 第2節の全表と本番の対応\n\n2026-11-04。表の行を一行ずつ保つ。'
           '生成器・変性の再帰・数値の展開数・遷移数を足して証明件数にしない。'
           '各単位の全証拠と所在は [unit-evidence.json](unit-evidence.json)。'
           '全76葉は [群 C の76行](../c/leaves.md)、H04 の109場合は '
           '[constructors.json](constructors.json) と [reconciliation.json](reconciliation.json) に対応する。\n\n']
    groups=section(detail,'## 2.','## 3.').split('### ')[1:]
    mappings=[[[11],[11],[11],[10,11],[10,27],[10,27],[10,27],[13,28]],
              [[6],[12,16],[6],[6],[7],[7],[11,15],[7],[10,12],[12,21],[14],[8,22],[8,22],[8,17],[9],[13],[13],[13],[13],[12,13],
               [9,11,15],[15,35],[9,15],[20],[12,15,20],[14,15],[14,15],[13,15]],
              [[16,17,29],[17],[18],[19,22],[20],[12,35],[17,21],[12,21,23],[17,21],[8,22,24],[8,22,24],[10,12,25],[13,28]],
              [[16],[16,29],[29],[16,20],[17],[17],[18],[19],[16,28,29],[29,32,34]]]
    # 値の表の lam/dependentLam 等の同じ行を重複して展開しない。
    case_records=[]
    for gi,group in enumerate(groups):
        title=group.splitlines()[0]
        bodyrows=[]
        for r in rows(group):
            if r[0] in {'母集団','値の構文（Syntax の Val 全25形）','計算の構文','sort（具体化後16）','系列'}:continue
            bodyrows.append(r)
        if gi==1:
            # 二つ目の表の見出しは長い説明を含むため名前の先頭で除く。
            bodyrows=[r for r in bodyrows if not r[0].startswith(('計算の構文','開始の16形'))]
        assert len(bodyrows)==len(mappings[gi]), (title,len(bodyrows),len(mappings[gi]))
        cases.append('## '+title+'\n\n| detail の行 | 本番の証拠 | 判定と後段 |\n|---|---|---|\n')
        for r,us in zip(bodyrows,mappings[gi]):
            symbols=[]
            current=[e for spec in CASE_SPECS.get(r[0],[]) for e in resolve(spec)]
            if not current:current=[evidence[str(u)][0] for u in us]
            case_records.append({'table':title,'row':r[0],'evidence':current})
            for e in current:symbols.append('`'+e['name_as_written']+'`（'+Path(e['source']).stem+'）')
            boundary='局所の宣言と読者を照合。主定理の全合成は L70'
            if 13 in us or 28 in us:boundary+='、全有効 σ は L50、外部・実表の全欄は L60'
            if 25 in us:boundary+='。O135は同じ通常Resultの実行へ接続済み。生成器全体はR40'
            if 23 in us or 24 in us:boundary+='。正常時の長さは精密 tel の型付け、callback の順序は R40 の実行の検査'
            cases.append('| '+r[0]+' | '+'；'.join(symbols)+' | '+boundary+' |\n')
        cases.append('\n')
    cases.append('## 表の外で固定した母集団\n\n'
                 'Val25・Comp16・State4・Frame7・Cell6、値の導出29＋2＋2、計算の導出24、ContTy10、'
                 'KeyShape11・KeySlots2・KeyPairs2、Measure7、Step76を現行構成子から抽出した。'
                 'sort は13行のうち Float 二幅と target 三形を展開して16。'
                 '独立評価は69＋4＋4＋6×3＋14＝109、EvalStandard7は別に保持する。'
                 'H04 の第一候補の unknown 除外は TrackedFailure の範囲であり、unknown の失敗例を削除しない。\n\n'
                 '旧31逆転は旧14移植・既済み7・供給側10。var の移植1を群 A が先行し、'
                 'dependentLam/raise は新2目的として別計上。群 C が loc1・計算9の供給側を閉じ、'
                 'N_V=N_C=N_g=0。B15全22行と76行の入力の証拠は群 C の最終表を使う。\n')
    (HERE/'cases.md').write_text(''.join(cases))
    save('case-evidence.json',case_records)
    print('単位の証拠',sum(len(v) for v in evidence.values()),'64義務・33申し送りを生成')


if __name__=='__main__': main()
