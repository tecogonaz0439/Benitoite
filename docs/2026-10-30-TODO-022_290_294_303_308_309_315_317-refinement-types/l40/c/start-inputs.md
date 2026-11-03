# B15 の全22行の現在値

2026-11-03、再開1。群Bから渡された全22行について、**L40.15の供給側を閉じた**。後段欄は閉じられなかったB15の代用ではなく、主定理・実表・標準factsの既存担当である。各入口は既定importの本番と具体の読者に置く。

| 行 | 今回の判定 | 供給元・同じ開始で保持した証拠 | 後段の担当 |
|---|---|---|---|
| B15-Def | 供給側完了 | Def.WellTyped.inputs・TelBodyTy.inputs。元の依存列からRegular文脈と同じ本体の全16構文の直接入力。空ΓのWFを供給 | L70の全宣言の合成 |
| B15-Impl | 供給側完了 | ImplDecl.WellTyped.method_inputs・method_stepの読者。同じメソッド・辞書順・型代入後の列とQsigを保持。実呼出しの形成は既存method_apply_allの閉じた行先とapp_inputsで供給 | L70の型/行具体化と全実装の合成 |
| B15-Capture | 供給側完了 | ClosureTy.inputs・StateTyE.inputs・app_inputs・lambda_inputs。CaptureContextRegularとCaptureLocalsを保持。閉じたappで形成を得る。生lambdaは空捕捉で閉じたclosureへ適用し、元Γを完全なCtx.WFへ強めない | L70の全開始の合成 |
| B15-Fn-fnRef | 供給側完了 | StateTyE.fnRef_contract_inputs。元lookup・NamesWF・Admissible・SignatureInstanceと同じ実引数列、結果LeQ・効果Covers | L70の関数呼出しの合成 |
| B15-Fn-op | 供給側完了 | StateTyE.op_contract_inputs・guard_op_inputs。元lookup・名前・SatAll・SignatureInstanceと元列。同じguard先頭では空行Coversも供給 | L40.20の一般の操作排除、L70の節の合成 |
| B15-Fn-lam | 供給側完了 | StateTyE.lam_contract_inputs・lambda_inputs。元注釈のWF/Sorted/Declared・本体とtoTelの実引数列。元列から個数も導き、広げたE_LamのStepと行先入力を構成 | L70の全開始の合成 |
| B15-Fn-dependentLam | 供給側完了 | StateTyE.dependentLam_contract_inputs・lambda_inputs。元Annotation/TelBodyTyと元列。空捕捉で閉じたclosureへの個数とStepを実開始から構成 | L70の全開始の合成 |
| B15-Fn-closure | 供給側完了 | StateTyE.closure_contract_inputs・lambda_inputs。元Annotation・RuntimeShape・DependentClosureTyと元列。従来と同じ行先 | L70の全開始の合成 |
| B15-Fn-raise | 供給側完了 | StateTyE.raise_contract_inputs。同じFailの元注釈とtoTelの実引数列。Failの正規形と元契約を保持 | L70のFail節の合成 |
| B15-Fn-externalRef | 供給側完了 | StateTyE.externalRef_contract_inputs・inv_externalRef。元宣言・WF・ExternalCallAdmissible・SignatureInstanceと元列。既存external_applyの本番読者も利用 | L60の外部応答、L70の合成 |
| B15-Ret | 供給側完了 | HasTypeCQ.inputsのret・return_step/handler_returnの読者。返す実値と元結果関係を保持。let/handlerが選ぶ実際の行先から次のappの形成も供給 | L70の返却の全合成 |
| B15-Let | 供給側完了 | HasTypeCQ.inv_let・let_step/return_stepの読者。同じ二本体・捕捉とletFを保持。実引数束縛後の行先から構文入力/閉じたapp形成 | L70のletの全合成 |
| B15-If | 供給側完了 | StateTyE.if_inputs・if_selectedの読者。元導出からBooleanの実形、真/偽の選択先の入力を構成 | L40.20の枝の標準facts、L70の合成 |
| B15-Match | 供給側完了 | HasTypeCQ.inv_match・StateTyE.match_inputs・match_start/match_skip/match_body/match_guardの読者。同じ照合値、obs=None/someの条件とsort、HasTypeArmsQ、Exhaustiveを保持 | L40.20の標準比較、L70の全照合の合成 |
| B15-Lazy | 供給側完了 | HasTypeCQ.inv_lazy・StoreOk.lazy_cell・lazy_transition/force_thunk_all/force_done_all/lazy_update_allの読者。同じthunk/doneセルと隠したbuilderの型、選択thunkの実開始から構文入力/閉じたapp形成 | L70の全セル/継続の合成 |
| B15-Escape | 供給側完了 | HasTypeCQ.inv_escape・mark_step/escape_markと全escapeの読者。同じR・markと捕捉/実値を保持。選択行先の入力 | L40.35の標準本体、L70の合成 |
| B15-Use | 供給側完了 | HasTypeCQ.inv_use・use_allと全releaseの読者。同じ資源・本体・release枠を保持。本体を選んだ行先の入力 | L60の解放応答、L70の合成 |
| B15-Handle | 供給側完了 | HasTypeCQ.inv_handle・handle_step/handler_return/operation_all/operation_failure/operation_primitiveの読者。通常/Failの選言と元の節を保持。選択した節の閉じた開始と元列の形成。捕捉元の完全WFを推測しない | L60の実表、L70の通常/Fail節の合成 |
| B15-Resume | 供給側完了 | HasTypeCQ.inv_resumeVar/inv_resumeL・StoreOk.cont_cell・resume_all/resume_usedと全dropの読者。変数/場所×生/正規形の直接前提。保存継続のcont/usedと同じ再開先の入力 | L60の解放応答、L70の合成 |
| B15-Guard | 供給側完了 | StateTyE.match_inputs・guard_true/guard_false/match_guard/err_pop_guard/exit_pop_guardの読者・guard_op_inputs。条件後の本体の同じCaptureOk・腕と真偽選択の入力。操作元列は空行Coversを保持 | L40.20の全操作排除/標準facts、L70の合成 |
| B15-Meth | 供給側完了 | HasTypeCQ.inv_meth・ImplDecl.WellTyped.method_inputs・method_step/super_stepの読者。元辞書と実装/クラス/メソッド対応、同じ型/行/辞書/実引数。選択本体の閉じた形成 | L70の全実装/上位辞書の合成 |
| B15-BuilderLet | 供給側完了 | HasTypeCQ.inv_builderLet/inv_builderOp・StoreOk.builder_cell・builder_new/builder_operation/builder_errorの読者。元local kindと専用本体/実要素を保持。同じ専用セルと選択本体の入力 | L70の専用セルと全本体の合成 |

完了22、停止0、供給側の未完0。primは群Bのprimitive_contract_inputsを継承する。L40.15の見込み50〜100分は、この22行の実装と照合を含む。今回の再開で供給したことは、任意の応答の存在や主定理の全分配を証明した意味ではない。元ΓがCaptureWFだけを持つ場合は、空Γでの実呼出しへの閉じ方と元Annotationを使い、完全なCtx.WFを仮定へ足さない。
