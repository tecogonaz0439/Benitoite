# 義務27行の段別の照合

生成物（[records.py](records.py)）。証拠は接頭辞 `Benitoite.Release.Refinement.` を除く完全名。

| 義務 | 出どころ | 分類 | L60の完了の判定 | 判定 | 証拠 | L60後に残る段 |
|---|---|---|---|---|---|---|
| O013 | 50 | 技術 | 12欄と同じP/Bの対象条件 | L60の分は完了 | `StandardModel.targets`・`StandardModel.io_op`・`ExternalModels.ModelCase.composition` | L70/R50/V10の全体照合 |
| O015 | 50 | 技術 | 対象3sortの同じ実応答を全表へ。新論理規則なし | L60の分は完了 | `StandardModel.scope_rows`・`ScopeResponse.response` | R50の実装比較 |
| O016 | 共/50 | 共通 | 既定import閉包・旧主定理/新葉の全名、公理・独立レビュー | 群Hの単位へ（群Gの分なし） | なし | L60.35/.36、L70と各段レビュー |
| O022 | 30/40/50 | 技術 | 同じout/toTerm?からのfactsと全表への接続 | L60の分は完了 | `StandardModel.pure_rows`・`StandardModel.scope_rows`・`StandardModel.normal_facts` | R50/V10の実装・領域照合 |
| O027 | 共 | 共通 | 最終workの本体/計測器の終了・原単位・機械を分ける | 群Hの単位へ（群Gの分なし） | なし | L60.37、L70/R20/R70の限定採取 |
| O034 | 30/40/50 | 技術 | 同じ値の表現・観測・所属を実表へ | L60の分は完了 | `StandardModel.scope_rows`・`StandardModel.pure_rows` | R50の同じ値の比較 |
| O035 | 40/50 | 技術 | 同じreq/endpoint/groundVal/valContentのまま全表へ | L60の分は完了 | `StandardModel.io_rows`・`StandardModel.scope_rows`・`ScopedIOResponse.response` | L70全到達、R30/R50 |
| O038 | P/20/40/50 | 技術 | 外部応答・通常解放の同じ状態からの葉と実表 | L60の分は完了 | `StateTyE.external_response_step`・`StateTyE.use_release_all`・`StandardModel.release_all`・`StandardModel.core` | L70全保存 |
| O048 | 50 | 技術 | 同じ値と対象を全表へ。旧eq_of_not_fnへ戻さない | L60の分は完了 | `StandardModel.scope_rows` | L70/R30/R50 |
| O049 | 20/50 | 技術 | 同じreqTarget/内容型を全表で供給 | L60の分は完了 | `StandardModel.io_rows`・`ScopedIOResponse.response` | R30/R50。既存葉の再証明なし |
| O057 | P/40/50 | 技術 | 任意の新型付き入力からexternal/releaseの応答存在 | L60の分は完了 | `StateTyE.external_response_step`・`StandardModel.release_exists`・`ExternalModels.ModelCase.release_all` | L70 progress |
| O058 | P/20/40/50 | 技術 | σ/Eb/μを保持した外部・解放の保存葉と全表 | L60の分は完了 | `StateTyE.external_response_step`・`StateTyE.use_release_all`・`StandardModel.substitution_assumptions` | L70 preservation |
| O059 | P/40/50 | 技術 | 選んだ外部/解放応答からstep→Stepの局所証拠 | L60の分は完了 | `step_external_selected`・`step_release_selected`・`ContTy.selected_release_step` | L70 step_sound |
| O060 | P/40/50 | 技術 | Stateの追跡、外部obs=[]と合成表の全effects。IOへ変換しない | L60の分は完了 | `ExternalSignatureLeaves.collected_contract`・`StandardModel.effect_ops`・`StandardModel.state_effect`・`ExternalModels.ModelCase.composition` | L70 effect_soundness/noLamNames |
| O061 | P/50 | 技術 | external_no_targetsを同じP/Bへ。CoreとTargetAgreement別 | L60の分は完了 | `StandardModel.core`・`StandardModel.targets`・`step_external_selected`・`StandardModel.positive_inputs` | L70一段/到達/表層 |
| O062 | P/40/50 | 技術 | 合成対象の同じδの全BuiltinArgsで存在/型/適格性/非exit。仮定側は名前と理由、外部carrierは別 | L60の分は完了 | `StandardModel.pure_rows`・`StandardModel.numeric_inputs`・`StandardModel.operator_inputs`・`StandardModel.collection_inputs`・`StandardModel.scope_inputs` | R50の算法比較と最終全体照合 |
| O063 | P/50 | 技術 | 新受理を含む全入力、外部三条件とIOを区別 | L60の分は完了 | `StandardModel.io_rows`・`StandardModel.io_inputs`・`StandardModel.external_assumptions` | R50の実応答比較。正常応答存在は要求しない |
| O064 | P/40 | 技術 | 三モデルと証拠のある合成資源の全型付き値で新関係の存在。証拠のない資源は名前と理由 | L60の分は完了 | `StandardModel.release_exists`・`ExternalModels.ModelCase.release_all`・`StandardModel.resource_table`・`ExternalSignatureLeaves.handle_not_release` | R30/R50の実装比較 |
| O065 | 20/40/50 | 技術 | 合成対象の全sourceTelRows/operationKinds/arity/StoreShapeと仮定側の台帳 | L60の分は完了 | `StandardModel.sig_scoped`・`StandardModel.opEff_io`・`StandardModel.store_shape`・`StandardModel.cons_scoped` | L70の新判断への切替 |
| O084 | 共/50 | 共通 | 篩/σ/external差を別記し、全関門と停止条件を守る | 群Gの分は完了（停止条件に当たる変更0）。.36は群H | なし | L60.36、L70/R/K/Vの合成・比較 |
| O086 | P | 技術 | 両除外を外せる外部葉と型の受け口。実0件は未実施と明示 | L60の分は完了 | `ExternalSurface.ref_typed`・`ExternalSurface.call_typed`・`ExternalSurface.named_call`・`ExternalSurface.partial_call`・`ExternalSurface.type_declared_iff` | L70全reader、R50両理由0件/F-CONN、K10 |
| O087 | P/20 | 技術 | 全入れ子・全置換・未知/重複/差替え/偽造の境界 | L60の分は完了 | `ExternalNominal.transformations`・`ExternalNominal.table_wf_iff`・`ExternalNominal.unknown_handle`・`ExternalNominal.handle_declaration` | L70表層収集、R50名目ID交換 |
| O088 | P | 技術 | borrow/own/State、三条件9欄と通常資源の区別、表層5接続 | L60の分は完了 | `ExternalUseAt.mode`・`ExternalModels.responses`・`ExternalModels.ModelCase.composition`・`ExternalSignatureLeaves.handle_not_release`・`ExternalSurface.call_typed` | L70主定理/全脱糖、R50 |
| O118 | 共 | 共通 | 変更した本番/写しに作業IDを残さず、現行の章節/意味の名前を使う | 群Gの分は完了（verify.pyで照合）。.34/.36は群H | なし | L70/R50/R60/D10/V10 |
| O144 | H24 | 他段 | L60はその証拠を合成に使用。新しい理論・CLIの所有を追加しない | 他段（L60の所有なし） | なし | R20/R10b/R40/R50/V10 |
| O157 | P | 記録 | 新しい外部/解放葉と01-12を同じ変更で写し、未実施の全比較を成功にしない | 群Gの分は完了（07-04の外部除外の境界）。.34は群H | なし | L70境界改訂、R50除外0、D10/V10最終候補 |
| O168 | P/50 | 技術 | externalの名目性・不透明性の内側の葉を受理/拒否の対で示す | L60の分は完了 | `ExternalSignatureLeaves.handle_not_source`・`ExternalSignatureLeaves.non_binding_pattern_rejected`・`ExternalSignatureLeaves.constructor_value_rejected`・`ExternalSignatureLeaves.mismatched_handle` | R30/R50/R60/R70/D10/V10のDET-R全実CLI |
