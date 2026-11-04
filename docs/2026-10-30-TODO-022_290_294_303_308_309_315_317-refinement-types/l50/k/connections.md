# 7位置・5具体化行・11実行葉の接続

全称の言明を根拠にし、具体例から全入力を推測しない。同じws/req/endpoint/σを保ち、出力の型・効果からrsを逆算しない。

位置・具体化行の読者は型と値の依存の閉包で証拠を使う名前付き宣言（定理・定義、privateを含む）だけを示す。同じ行でも読者が使う証拠は併記した名前に限る。[抽出台本](reader_dependencies.py)・[依存の経路](reader-dependencies.json)で再現する。

## U1の7位置

| 行 | 判定と全称の境界 | 実定理 | 読者・関係 |
|---|---|---|---|
| 直接 | 完了：同じBuiltinArgsの元列へTelClosure.reflを使う。入力rsは変更しない。 | `Benitoite.Release.Refinement.ScopedTargetExamples.single_io`、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_request` | 読者：`Benitoite.Release.Refinement.ScopedTargetExamples.request_io`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.single_io`）。 |
| 明示拡大 | 完了：同じvのscoped導出を再構成し、明示された被覆で広げて忘却する。 | `Benitoite.Release.Refinement.HasTypeVQ.widen_opaque`、`Benitoite.Release.Refinement.ScopedTargetExamples.widened_input` | 読者：`Benitoite.Release.Refinement.HasTypeVQ.widen_instTarget_covers`（依存する証拠：`Benitoite.Release.Refinement.HasTypeVQ.widen_opaque`）。 |
| 関数値 | 完了：任意uへのTelClosureから同じwsを元列へ戻す。結果と効果は適用の出力である。 | `Benitoite.Release.Refinement.ScopedCallContracts.single_inputs`、`Benitoite.Release.Refinement.ScopedTargetExamples.request_io` | 読者：`Benitoite.Release.Refinement.ScopedTargetExamples.single_io`（依存する証拠：`Benitoite.Release.Refinement.ScopedCallContracts.single_inputs`）。 |
| callback | 完了：実際のC_DependentAppで同じf/wsのappを型付けし、元列へ戻して全応答へ進む。 | `Benitoite.Release.Refinement.TelClosure.apply`、`Benitoite.Release.Refinement.ScopedTargetExamples.single_io` | 読者：`Benitoite.Release.Refinement.ScopedTargetExamples.request_io`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.single_io`、`Benitoite.Release.Refinement.TelClosure.apply`）、`Benitoite.Release.Refinement.ScopedTargetInputs.io_steps`（依存する証拠：`Benitoite.Release.Refinement.TelClosure.apply`）。 |
| ADT/List格納 | 完了：Listの任意要素とADTの任意欄を同じΨで読む。ws[p]?=some vで元の同じ値と実対象位置を接続する。 | `Benitoite.Release.Refinement.HasTypeVsQ.get`、`Benitoite.Release.Refinement.HasTypeEachQ.member`、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io` | 読者：`Benitoite.Release.Refinement.HasTypeVQ.con_field`（依存する証拠：`Benitoite.Release.Refinement.HasTypeVsQ.get`）、`Benitoite.Release.Refinement.HasTypeVQ.list_element_facts`（依存する証拠：`Benitoite.Release.Refinement.HasTypeEachQ.member`）、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_request`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io`）。 |
| Reference/Lazy | 完了：StoreOk.ref_cell/lazy_cellから実セルを読む。Lazyの未評価thunkは値とせず、doneの同じvだけを対象位置へ渡す。 | `Benitoite.Release.Refinement.StoreOk.ref_cell`、`Benitoite.Release.Refinement.StoreOk.lazy_cell`、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io` | 読者：`Benitoite.Release.Refinement.HasTypeVQ.reference_cell_inputs`（依存する証拠：`Benitoite.Release.Refinement.StoreOk.ref_cell`）、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_request`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io`）。 |
| 節/resume | 完了：HasTypeVsQ.widen_coversが同じ列を節へ移す。resumeの直接/正規化入力と実引数位置を接続する。ハンドラは実wsと新継続セルを保存する。 | `Benitoite.Release.Refinement.HasTypeVsQ.widen_covers`、`Benitoite.Release.Refinement.HasTypeCQ.inv_resumeL`、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_request` | 読者：`Benitoite.Release.Refinement.ScopedTargetInputs.handled_step`（依存する証拠：`Benitoite.Release.Refinement.HasTypeCQ.inv_resumeL`）。 |

## D09の5具体化行

| 行 | 判定と全称の境界 | 実定理 | 読者・関係 |
|---|---|---|---|
| 直接 | 完了：具体化済みrsをBuiltinArgsの入力として一度だけ使う。 | `Benitoite.Release.Refinement.ScopedTargetExamples.single_io` | 読者：`Benitoite.Release.Refinement.ScopedTargetExamples.request_io`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.single_io`）。 |
| 明示拡大 | 完了：与えたrと明示先s、s.Covers rを使い同じ値を渡す。 | `Benitoite.Release.Refinement.ScopedTargetExamples.widened_input`、`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io` | 読者：`Benitoite.Release.Refinement.ScopedTargetExamples.selected_request`（依存する証拠：`Benitoite.Release.Refinement.ScopedTargetExamples.selected_io`）。 |
| 関数値 | 完了：任意TelClosureの同じwsを元署名へ戻し、同じrsを使う。 | `Benitoite.Release.Refinement.ScopedTargetExamples.request_io` | 関係：証拠そのものが入口。読者なし。証拠そのものが入口で、合成の読者は後段に残る。受け口：R10b/R30のPrimitiveAdmissible/RangeAdmissible/SignatureInstanceへの具体化入力、L70の同じ実引数の全開始への合成。 |
| 無制約Top | 完了：明示されたTopへ同じ値を拡大し、元の保持対象を返す。 | `Benitoite.Release.Refinement.ScopedTargetExamples.widened_input`、`Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection` | 関係：証拠そのものが入口。読者なし。証拠そのものが入口で、合成の読者は後段に残る。受け口：R10b/R30のPrimitiveAdmissible/RangeAdmissible/SignatureInstanceへの具体化入力、L70の同じ実引数の全開始への合成。 |
| 比較不能 | 完了：被覆の否定からscoped共変を拒否する。異なる起点は解決先が等しくても比較できない。 | `Benitoite.Release.Refinement.ScopedTargetExamples.incomparable`、`Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base` | 関係：証拠そのものが入口。読者なし。証拠そのものが入口で、合成の読者は後段に残る。受け口：R10b/R30のPrimitiveAdmissible/RangeAdmissible/SignatureInstanceへの具体化入力、L70の同じ実引数の全開始への合成。 |

## 実行の11葉

| 行 | 判定と全称の境界 | 実定理 | 同じ実δ・応答表又は準備・検査（読者の主張ではない） |
|---|---|---|---|
| E_Prim | 完了：元状態→元依存列→正規化→実δのval→同じ継続/ストア | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps`、`Benitoite.Release.Refinement.StateTyE.primitive_value_all` | `Benitoite.Release.Refinement.ScopeResponse.delta`、`Benitoite.Release.Refinement.ModelTargets.builtins`、`Benitoite.Release.Refinement.ModelHttp.builtins` |
| E_Err | 完了：同じ実δのerrを同じ継続/ストアのerrorへ渡す | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps`、`Benitoite.Release.Refinement.StateTyE.primitive_error_all` | `Benitoite.Release.Refinement.ScopeResponse.delta`、`Benitoite.Release.Refinement.ModelTargets.builtins`、`Benitoite.Release.Refinement.ModelHttp.builtins` |
| E_IO | 完了：全実ioResponseのvalを同じσ/Eb/k/μで保存する | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.io_steps`、`Benitoite.Release.Refinement.StateTyE.io_value_all` | `Benitoite.Release.Refinement.ScopedIOResponse.ioResponse`、`Benitoite.Release.Refinement.ModelTargets.ioResponse`、`Benitoite.Release.Refinement.ModelHttp.ioResponse` |
| E_IOErr | 完了：全実ioResponseのerr。元のkindのio/exit両側を保つ | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.io_steps`、`Benitoite.Release.Refinement.StateTyE.io_error_all` | `Benitoite.Release.Refinement.ModelTargets.ioResponse`、`Benitoite.Release.Refinement.ModelHttp.ioResponse` |
| E_Exit | 完了：io_kindでexit側を得て同じ終了応答と継続/ストアへ渡す。範囲IO7行の非exitとは区別する | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.io_steps`、`Benitoite.Release.Refinement.StateTyE.io_exit_all` | `Benitoite.Release.Refinement.ModelTargets.io_kind`、`Benitoite.Release.Refinement.ModelTargets.ioResponse` |
| E_OpPrim | 完了：実IOを実行せず同じwsを節へ渡す。μ.setでfreshな継続セルを追加する。保存には既存EffectsOkも用いる | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.handled_step`、`Benitoite.Release.Refinement.StateTyE.operation_primitive` | `Benitoite.Release.Refinement.ScopeSignatures.io_op` |
| E_AtOk | 完了：元状態→ClosureTy.at_inputs→準備→同じsnapshot=σ→checkAt成功→同じ対象/要求の保持 | `Benitoite.Release.Refinement.ScopedTargetInputs.at_ok`、`Benitoite.Release.Refinement.ScopedTargetInputs.at_steps`、`Benitoite.Release.Refinement.StateTyE.at_ok_all` | `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.checkAt` |
| E_AtError | 完了：元状態の同じsnapshot、同じ準備の生入力、同じcheckAt失敗、九欄と内部観測 | `Benitoite.Release.Refinement.AtErrorReaders.check_reader`、`Benitoite.Release.Refinement.ScopedTargetInputs.at_error`、`Benitoite.Release.Refinement.StateTyE.at_error_all` | `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.checkAt`、`Benitoite.Release.Refinement.AtError.fromCheck` |
| E_AtPrepareError | 完了：同じAtPrepareの全失敗と元の生入力。型付きindexのstaticIndexを除く | `Benitoite.Release.Refinement.AtErrorReaders.prepare_reader`、`Benitoite.Release.Refinement.ScopedTargetInputs.at_prepare`、`Benitoite.Release.Refinement.StateTyE.at_prepare_error_all` | `Benitoite.Release.Refinement.AtPrepare`、`Benitoite.Release.Refinement.AtPrepare.error_saved` |
| E_PathBasesApply | 完了：空の実引数の正規化したBuiltinArgs→専用issue状態。IOの応答存在を使わない | `Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`、`Benitoite.Release.Refinement.ScopedTargetInputs.path_bases_apply`、`Benitoite.Release.Refinement.StateTyE.path_bases_apply_all` | `Benitoite.Release.Refinement.ScopeSignatures.pathBases`、`Benitoite.Release.Refinement.Model.builtins` |
| E_IssuePathBases | 完了：同じσの値・同じEnvironment事象・同じ効果表membership・同じμ | `Benitoite.Release.Refinement.ScopedTargetInputs.issue`、`Benitoite.Release.Refinement.StateTyE.issue_path_bases_all` | `Benitoite.Release.Refinement.Model.builtins`、`Benitoite.Release.Refinement.ScopeSignatures.pathBases` |

## 後段の所有

R10b/R30は入力の推論と一度の具体化、scopeの上限、結果型/許容効果から逆算しないことを実入力で照合する。受け口は同じ PrimitiveAdmissible・RangeAdmissible・SignatureInstance と BuiltinArgs であり、上表の実定理が具体化後の根拠である。ソースの推論手続きは未実装である。

L60は外部三条件・通常資源の解放と同じ表のCoreを構成する。12欄の根拠と注意は [l60-fields.md](l60-fields.md)。L70は、上表の同じ実StateTyE/Stepを全開始・全到達・表層・主定理へ合成する。この合成は未実装である。特にio_stepsの観測上限は呼出し効果eであり、継続の末尾Ebへの対象の全伝播を完了としない。

## 全σと否定の境界

| 行 | 全入力の判定 | 根拠 |
|---|---|---|
| 同一起点 | 任意Wordと全4パターン対から全σの所属保存 | `Benitoite.Release.Refinement.PathPattern.covers_atBase`、`Benitoite.Release.Refinement.RangeExpr.Covers.mem` |
| 起点差 | lookupが等しい場合の意味の同値と静的被覆の否定。root=cwdの実適用例も既定内にある | `Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base` |
| 非Topの絶対/記号付き | absoluteの非Topからbased/secretsの被覆を拒否。root=cwdでも例は同じ否定を返す | `Benitoite.Release.Refinement.RangeExpr.Covers`、`Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base` |
| 分割した被覆 | 任意ホスト/σ/対象でポート0..9の所属が0..4又は5..9へ分かれても、効果の一原子の被覆を拒否する | `Benitoite.Release.Refinement.ScopedTargetExamples.split_endpoint`、`Benitoite.Release.Refinement.ScopedTargetExamples.no_collective_cover` |
| secrets | noneは未解決、some []は解決済み空。任意psの所属を要素で表し、任意p::psの非空の受理とTopへの保存を既定内で読む | `Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members`、`Benitoite.Release.Refinement.RangeExpr.Covers.mem` |
| Top/絶対射影 | 同じvを拡大して同じ絶対対象を射影する。snapshotを再解決しない | `Benitoite.Release.Refinement.ScopedTargetExamples.widened_input`、`Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection` |
| 未束縛 | 任意起点のlookup none又はsecrets noneは所属しない。必要束縛からの解決と動的Errorを分離する | `Benitoite.Release.Refinement.PathEnv.Ready.resolve_required`、`Benitoite.Release.Refinement.AtPrepare.error_saved` |
