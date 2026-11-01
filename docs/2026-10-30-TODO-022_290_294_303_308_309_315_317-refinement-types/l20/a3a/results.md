# A3a の結果（r1、実装完了）

2026-11-02。B_WORK は `14492156debe5f6b8925963e55c2d9aecdc6923c`、ブランチは起動依頼の `m014/l20.a3a` である。git による照合・切替・作成・コミットは行っていない。開始時の各ファイルの SHA-256 は [baseline.json](baseline.json)、現在の差分の一覧は [changed-files.json](changed-files.json) に保存した。

**L20.08〜.13 の実装と自己点検を完了した。既定の `lake build` を含む作業末の `formal_build` は終了0、公理依存は許可一覧外0である。** 取りまとめがr1で承認した `HasTypeVQ.shift_types_var` と private の `shift_var_aux` のkindの対応を反映した。初回の停止時の報告は [results-r0.md](results-r0.md) に残した。独立レビュー・取り込み・受け入れは未実施である。

## 実装した内容

Cを `TypeCtx = List TParamDecl` とし、`TypeArgsKinded` は同じCのkindの列だけを読む。`TypeArgsKindedAt` はその別名であり、forgetは恒等である。`B.sat` と `PrimSig.admits` の生の制約の型を保ち、呼出し側だけ `TypeCtx.constraints C` へ射影した。SatAll/Admissibleの相手の制約の列も生の型を保つ。

`Ty.Declared` のtappは、headのkindが引数の個数と一致するconstructorであることを検査する。既存の値置換・normではそのlookupと列の長さを保ち、型shiftでは `TypeParamRenaming.kindRenaming` を渡す。値のshift・逆shift・bind・文脈の移送、閉じた型とNoTappの読者を含め、既定ビルドが通ることを確認した。S00の場所・ストアの定義に追加の変更はない。

Def/Methは実際の宣言をCにし、操作・実装は既存のvalue固定の宣言を `TypeCtx.values` で写す。OpSigの組み込みの枝は `s.tparams` のkindを保持する。通常節は `sg.tparams ++ C`、Fail節は `TypeCtx.valueParam :: C` を読む。V_Raiseには結果型のvalue kindを保持し、エラー型へ新しいkind前提は加えていない。旧Cのtargetは `legacyTypeCtx C κ`、旧contextの三つの橋はkind列の等号を読む。

`KindRenaming` と `rawRenameTypesList_length` は同名・同じ式と証明のまま低いTypeRenamingへ移した。TypeParamRenamingの五包装とTAK.shiftTypes/TypeCtxMap.signatureから同じkindの対応を供給する。長さだけで新しいkindの列を作るinsertKindsの経路を除いた。

`TypeSubstContracts.lean` にS12.7の九欄の `ClosedTypeSubstInput` を置き、既定Benitoiteのimportへ加えた。S02の十四成分、kindの五言明、Declaredの四成分は、[contracts.lean](contracts.lean) で略記を展開して型検査した。ここで固定した23命題の型と、それらの証明の完成は別である。後続の型置換の本体、SignatureInstance.rowKinds、kindの像の全族は実装していない。

## 承認された追加署名

初回に、kindの異なる同長の文脈を許す `HasTypeVQ.shift_types_var` の署名が偽になる反例をLeanで示し、取りまとめへ返した。r1で取りまとめが、その公開補題とprivate補題へ `TypeParamRenaming C C' (shiftIndex k c)` を渡す変更を承認した。同じ性質のkindの対応だけを足す公開補助も、この群で続けてよいとの指示を受けた。

実際にS12の指定を越えて追加した公開署名の変更は、承認された **HasTypeVQ.shift_types_varの1件だけ**である。privateのshift_var_auxでは、V_Sub/V_Refineの二つのDeclaredへhCを渡し、V_Normalの再帰も同じ対応で呼ぶ。唯一の外部の読者ContextMap.shiftEでは、prefixから組み立てる既存のinsertを使って供給した。長さだけでkindを選ぶ仮定や、新しい信頼条件は加えていない。

完全な追加署名は実装前に [signatures.md](signatures.md) に保存した。現在の公開67件の完全署名・定義の印字は [public-signatures.lean](public-signatures.lean) と [r1-public-signatures.log](r1-public-signatures.log) にある。主な十移送の字面は開始時と一致する（[main-signatures.json](main-signatures.json)）。

初回の反例は [stop-reproduction.lean](stop-reproduction.lean) の `signature_false` であり、現在の本番の定義でも再検査して終了0である。これは改訂前の署名の否定であり、改訂後の補題への反例ではない。反例の公理依存も許可された三つだけである。

## L20.08〜.13 の完了条件

| 単位 | 判定と証拠 |
|---|---|
| L20.08 | 完了。TypeCtx/TAK/Atの定義、九欄のClosedTypeSubstInput、23命題の完全な型を固定。boundaryの双方向の不適合と正しいtvar/bytes/ctorを検査 |
| L20.09 | 完了。計画の69変更7保持と追加6出現の全読者を照合。B.sat/admitsの入口だけconstraintsへ射影。全読者の既定ビルド成功 |
| L20.10 | 完了。Declared.tappのheadと個数、旧context三署名を変更。bad arityを拒否。既存Annotationの欄は三つのまま |
| L20.11 | 完了。Def/Meth/Impl/OpSig/通常節/Fail/V_Raiseの定義と全読者、旧Cκの11橋がビルド成功。新しいkindの選び直しなし |
| L20.12 | 完了。DeclaredのrawSubstV/norm、bind/shift/逆shift/context、closed_contextとNoTappの全読者を確認。TypeFormationの総称の生のTParamをvalueParamへ修正。S00の追加変更0 |
| L20.13 | 完了。kindを保つTypeParamRenamingと五包装、低層への二宣言の移動、TAK.shiftTypes/TypeCtxMap.signature、承認された変数の補題と読者を接続 |

A3aの定義変更をビルド可能にするため、A3bのL20.14/.18に名指しされた既存のDeclared型shift補助・読者とV_Raiseの追随を同時に閉じた。この依存の追随をA3bで再実装する必要はない。L20.14の一般ρのheadの本番の公開case補題、kind像の全族、Declaredの全型置換、SignatureInstance.rowKinds、その全読者とS02の本体は後続の担当のままである。一般ρのheadはboundary入力でcaseの式を型検査してあるが、全型改名の新しいrecursorは作っていない。

関門(b)全体の通過は宣言しない。V_Op/V_Fun/C_Methの型引数の三本体、escape/lambdaの注釈、閉じた型像と行像からS02の結論へ進む本証明はA3b/A3cに残る。定義の変更が全Rustソースの受理と一致すること（J20-7）も、このLeanのビルドからは結論しない。

## 計画の件数との比較

[occurrences-before.json](occurrences-before.json) は開始時の全出現の内容・行・列を保存し、[occurrence-reconciliation.json](occurrence-reconciliation.json) はファイルごとに分類する。残る生の `List TParam` は指定どおり7出現だけである。

| 集合 | 計画 | 最終の結果 | 差と理由 |
|---|---:|---:|---|
| 明示した型注記の変更 | 69 | 75 | +6。前群のCaptureRegularityの4、StateTypingの2を追加で追随 |
| 生の制約の型を保持 | 7 | 7 | 0。Syntaxの5、SatAll/Admissibleの相手の2を保持 |
| 四移送の手修正 | 39枝 | 38枝 | −1。型shift35、値shift1、値subst1、narrowing1。腕のplainはPred.Declaredの既存移送で通り、本体を変える必要がなかった |
| 四移送の保持 | 265枝 | 266枝 | +1。同じrecursorを保ち、全304枝の作り直し0 |
| 承認されたprivate補題 | 計画外 | 3枝 | shift_var_auxのV_Sub/V_Refineの証拠とV_Normalの再帰へのhCの供給。四移送の304枝とは別集合 |
| 四移送の外のV_Raiseの明示arity | 4枝 | 5枝 | +1。前群のCaptureRegularityに1枝増えていたため |
| 既存Declared.tappの直接の枝 | 4枝 | 4枝 | rawSubstV/norm/型shift/旧contextの全てを検査 |
| 旧Cの橋 | 11橋 | 11橋 | 8橋と旧context三署名。全て既定ビルド成功 |

[branch-inventory.json](branch-inventory.json) は各明示match枝の差分を記す。四移送38枝とprivate補題3枝の計41枝を変更した。V_Raiseの外の5枝、Declaredの4枝、基盤の宣言の集合は別に照合した。同じ枝をこれらの表の重複分として足した総数は作らない。

S12の基盤21宣言の外に、ReferencePreservationの閉じた実引数のkindの取り出しと、参照の組み込みを構成する箇所のTAK/constraintsの射影も追随した。後者は新しい保存則の追加ではなく、既存の空のCとvalue kindの証拠を新しい定義へ渡す変更である。HandlerOperationではuser操作のTypeCtx.valuesの空列を簡約する読者を追随した。

## 検査

途中は関係するモジュールの局所ビルドを行い、失敗した読者を修正して再検査した。初回停止時の失敗とr1の途中の失敗も削除せず保存した。主なr1の記録は次のとおりであり、各JSONにコマンド・終了・外側の時間・生出力のSHA-256がある。

| 記録 | 終了 | 外側の時間 | 詳細 |
|---|---:|---:|---|
| `r1-handler-formation` | 0 | 1.534秒 | [r1-handler-formation.json](r1-handler-formation.json) |
| `r1-upper-bridges` | 1 | 18.609秒 | [r1-upper-bridges.json](r1-upper-bridges.json) |
| `r1-upper-bridges-r1` | 1 | 8.444秒 | [r1-upper-bridges-r1.json](r1-upper-bridges-r1.json) |
| `r1-legacy-values` | 0 | 0.479秒 | [r1-legacy-values.json](r1-legacy-values.json) |
| `r1-all-readers` | 1 | 2.077秒 | [r1-all-readers.json](r1-all-readers.json) |
| `r1-contract-module-r1` | 1 | 0.923秒 | [r1-contract-module-r1.json](r1-contract-module-r1.json) |
| `r1-contract-module-r2` | 1 | 12.444秒 | [r1-contract-module-r2.json](r1-contract-module-r2.json) |
| `r1-contract-module-r3` | 0 | 10.196秒 | [r1-contract-module-r3.json](r1-contract-module-r3.json) |
| `r1-handler-operation` | 0 | 0.811秒 | [r1-handler-operation.json](r1-handler-operation.json) |
| `r1-contracts-check-r2` | 0 | 0.339秒 | [r1-contracts-check-r2.json](r1-contracts-check-r2.json) |
| `r1-boundary-r1` | 0 | 0.326秒 | [r1-boundary-r1.json](r1-boundary-r1.json) |
| `r1-work-dry-run` | 0 | 0.008秒 | [r1-work-dry-run.json](r1-work-dry-run.json) |
| `r1-work` | 0 | 0.825秒 | [r1-work.json](r1-work.json) |
| `r1-axioms` | 0 | 4.387秒 | [r1-axioms.json](r1-axioms.json) |
| `r1-public-signatures` | 0 | 0.684秒 | [r1-public-signatures.json](r1-public-signatures.json) |
| `r1-stop-reproduction` | 0 | 1.155秒 | [r1-stop-reproduction.json](r1-stop-reproduction.json) |

作業末は、同じB_WORKを指定したdry-runを確認してから、`scripts/check.sh --level work --base 14492156debe5f6b8925963e55c2d9aecdc6923c --only formal_build` を一度実行し、終了0だった。**既定の八ターゲットのlake buildとsorryの拒否が通った。** `--only` の経路はgitの変更分類・基準の照合を通らず、基準は表示にだけ使うことをスクリプトで確認した。型注記の変更・Leanとその写しの作業なので、Rustのlib全件・比較全体・性能測定は追加していない。01-12ではLeanのコードブロックと説明だけを変え、言語仕様のtext例・構文は変更していない。

boundary入力は、正しいvalue/constructorのtvarとbytes/ctor像、双方向のkind不適合、tappの誤個数、正しいtappの注釈、一般ρのhead、値shift/norm、閉じた型、旧contextの二つの射影を検査する。入力は [boundary.lean](boundary.lean)、結果は [r1-boundary-r1.log](r1-boundary-r1.log) であり終了0。23の後続の型置換の命題は [r1-contracts-check-r2.log](r1-contracts-check-r2.log) で全て型検査済みである。

## 公理依存

[axioms.lean](axioms.lean) は既定Benitoiteをimportし、**変更した43モジュールの全4213宣言**（private・生成宣言を含む）に `#print axioms` を実行した。主な十移送、旧主定理5、旧モデル3も完全名で再照合した。終了0、許可一覧の `propext`・`Quot.sound`・`Classical.choice` 以外は0。sorryAxの依存も0である。

対象別の件数は [axioms-summary-r1.json](axioms-summary-r1.json)、全宣言名と公理の一覧は `axioms-r1/` のJSONに保存した。印字した件数と解析した件数は全モジュールで一致する。100 KBを超える生の出力は `<tmp>` に置き、[large-records.md](large-records.md) に大きさとSHA-256を保存した。初回の部分監査は当時の記録として残し、r1の全対象の検査で置き換える。

主な十言明の字面は開始時と一致し、型付けの構成子の数と判断の引数の個数は変えていない。今回承認されたCの中身・V_Raiseの前提・Declared.tappを除き、型付けの規則の形とS12の固定した定義を変更していない。新公理・明示したsorry・旧Releaseの定義の変更は0。既定importの削除は0、新しいTypeSubstContractsの追加だけである。

## S12の切替条件と時間

各局所ビルドの区切りと最後にS12の条件を照合した。固有の移送の手修正は四移送38枝、承認されたprivate補題3枝であり、76枝を超える見込みは生じなかった。固有の仕事が42時間40分を超える見込みも生じていない。**案4を維持し、案1へ切り替えていない。** r1で許可されたkindの対応の追加を使って、主な十言明を変更せず閉じた。

r1の開始記録から本結果を作る直前までの外側の時間は 808.8秒（13.5分）である。初回のスナップショットから停止時の最後の自己照合までの記録区間は 755.6秒（12.6分）、両区間の合計は 26.1分である。初回の先行する読み込みはこの区間に含まれず、停止中の取りまとめの判断待ちは合計に含めない。能動時間と待ちを全区間で分離していないため、能動時間の実測値や後続の段への倍率は作らない。最大常駐量は未取得（群A3aは計画上の非採取）。

当初のA3aの見込み4時間30分〜10時間20分、初回停止時の追加を含む見込み5時間〜11時間50分に対し、A3aの実装に残る作業は0となった。起動依頼の上限20時間40分には達していない。今回の定義と既存読者の追随が短く終わった実績を、A3b以降のkindの像・全型置換の証明へ一律に掛けて見込みを縮めない。

## 変更したファイルと残る担当

既存45ファイルを変更し、本番のLeanを1ファイル追加した。Leanは既存43・新規1、設計書の写しは2、合計46ファイルである。既存Leanには既定の入口Benitoite.leanを含む。全ての相対パス・差分の行数・SHA-256は [changed-files.json](changed-files.json) に保存した。plan/detail/既存レビュー/処理系の編集とgit操作は行っていない。

| ファイル（リポジトリからの相対パス） | 区分 | 追加行 / 削除行 |
|---|---|---:|
| `formal/Benitoite.lean` | 変更 | 2 / 0 |
| `formal/Benitoite/Release/Refinement/CaptureRegularity.lean` | 変更 | 5 / 5 |
| `formal/Benitoite/Release/Refinement/HandlerOperation.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/HandlerAlgebra.lean` | 変更 | 8 / 8 |
| `formal/Benitoite/Release/Refinement/Narrowing.lean` | 変更 | 12 / 10 |
| `formal/Benitoite/Release/Refinement/TypingShift.lean` | 変更 | 5 / 5 |
| `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 変更 | 12 / 12 |
| `formal/Benitoite/Release/Refinement/ReferencePreservation.lean` | 変更 | 5 / 7 |
| `formal/Benitoite/Release/Refinement/ProgramTyping.lean` | 変更 | 8 / 8 |
| `formal/Benitoite/Release/Refinement/AdmissibleMap.lean` | 変更 | 3 / 3 |
| `formal/Benitoite/Release/Refinement/DeclaredTransport.lean` | 変更 | 5 / 5 |
| `formal/Benitoite/Release/Refinement/HandlerContracts.lean` | 変更 | 3 / 3 |
| `formal/Benitoite/Release/Refinement/LegacyKinds.lean` | 変更 | 16 / 0 |
| `formal/Benitoite/Release/Refinement/Declared.lean` | 変更 | 10 / 10 |
| `formal/Benitoite/Release/Refinement/External.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/ClosedCapture.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean` | 変更 | 16 / 16 |
| `formal/Benitoite/Release/Refinement/TypeShiftExchange.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/KindValues.lean` | 変更 | 7 / 9 |
| `formal/Benitoite/Release/Refinement/LegacyTables.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean` | 変更 | 14 / 14 |
| `formal/Benitoite/Release/Refinement/LegacyDeclarations.lean` | 変更 | 16 / 16 |
| `formal/Benitoite/Release/Refinement/ProgramWellFormed.lean` | 変更 | 10 / 11 |
| `formal/Benitoite/Release/Refinement/Typing.lean` | 変更 | 17 / 17 |
| `formal/Benitoite/Release/Refinement/TypeRenaming.lean` | 変更 | 28 / 13 |
| `formal/Benitoite/Release/Refinement/TypingDeclared.lean` | 変更 | 2 / 2 |
| `formal/Benitoite/Release/Refinement/StateTyping.lean` | 変更 | 3 / 3 |
| `formal/Benitoite/Release/Refinement/LazyPreservation.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/TypeShiftKinds.lean` | 変更 | 5 / 33 |
| `formal/Benitoite/Release/Refinement/Admissible.lean` | 変更 | 10 / 10 |
| `formal/Benitoite/Release/Refinement/PathFacts.lean` | 変更 | 2 / 2 |
| `formal/Benitoite/Release/Refinement/TypeShiftContext.lean` | 変更 | 22 / 21 |
| `formal/Benitoite/Release/Refinement/Types.lean` | 変更 | 19 / 0 |
| `formal/Benitoite/Release/Refinement/TypeArgumentRegularity.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/TypeFormation.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/LegacyInput.lean` | 変更 | 2 / 2 |
| `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean` | 変更 | 11 / 11 |
| `formal/Benitoite/Release/Refinement/VarianceValidation.lean` | 変更 | 2 / 2 |
| `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | 変更 | 46 / 45 |
| `formal/Benitoite/Release/Refinement/LegacyValues.lean` | 変更 | 15 / 14 |
| `formal/Benitoite/Release/Refinement/Context/Facts.lean` | 変更 | 1 / 1 |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | 変更 | 8 / 12 |
| `formal/Benitoite/Release/Refinement/Context/WF.lean` | 変更 | 2 / 2 |
| `docs/design/01-spec/01-12-core-calculus.md` | 変更 | 17 / 9 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 変更 | 3 / 1 |
| `formal/Benitoite/Release/Refinement/TypeSubstContracts.lean` | 新規 | 19 / 0 |

| 残る手順・義務 | 担当 | 見込み |
|---|---|---:|
| A3aの独立レビュー・受け入れ・取り込み | 取りまとめ・設計者 | 不明 |
| A3bのkind像全族・Declared全型置換・SignatureInstance.rowKindsと読者 | A3bの実装担当 | A3bの計画どおり。今回の実績から縮めない |
| A3cの型引数の三本体とescape/lambdaの注釈、関門(b)(c) | A3cの実装担当 | A3cの計画どおり |
| J20-7の合法ソースとの対応 | L70/R10b/R50の担当 | 当該段で照合 |

O167の型引数の双方向の不適合の拒否はA3aの部分を検査済みであり、提供範囲全体の閉鎖ではない。O006/O010/O020/O023/O024/O025/O029/O031/O032等の全型置換、O042の全埋め込み、O051の全使用先は、その後続の証明を今回の定義のビルドで代えない。群の自己点検を独立レビュー済みとは扱わない。

最終の完了条件の照合は [self-check.json](self-check.json)、入力・出力・設定・道具と差分のSHA-256は [artifact-manifest.json](artifact-manifest.json) に保存する。記録を取る台本は [record-command.py](record-command.py) に写し、消える作業領域を恒久の出どころにしない。

## r2: RV-L20.a3a の所見への対応

2026-11-02。取りまとめが中1の案1を選んだ指示に従い、中1・中2・軽2へ対応した。r2の差分はLean4ファイル（LegacyTables、Typing、Types、ReferencePreservation）と設計書の写し2ファイルである。[changed-files-r2.json](changed-files-r2.json) に差分の行数とSHA-256を保存した。r1の文書中の件数・所要は当時の記録であり、以下が再検査後の状態である。

| 所見 | 対応 | 判定 |
|---|---|---|
| 中1 | LegacyPrimSignatureへ `operationKinds : s.opEff ≠ none → TypeCtx.kinds s.tparams = List.replicate s.tparams.length .value` の一欄を追加。LegacyRuleの引数・LegacyOutputInputの欄を増やさない。操作でない組み込みにはこの欄でkindを制限しない | 指定された案1を実装済み。実表の供給の照合は下記のL60への申し送り |
| 中2 | 01-12のadmits_satを `s.admits (TypeCtx.constraints C) (Ty.normTys ts)` へ修正し、Leanの二行の式と一致させた | 完了 |
| 軽2 | Typing.leanのV_Fun/V_Prim/C_Methの計5箇所をTypeCtx.constraints/TypeCtx.kindsへ統一 | 完了。参照の組み込みの二箇所には下記の等号の補題を明示して供給 |

表の対応の一欄追加は、取りまとめが承認した入力条件の変更である。CoreAssumptionsやLegacyRuleに新しい仮定を加える変更とは区別する。新しい欄の型と、表記の変更に使った `TypeCtx.kinds_eq_map` の完全署名は実装前に [signatures.md](signatures.md) に記録した。現在の署名の印字は [r2-public-signatures.lean](r2-public-signatures.lean) と [r2-public-signatures.log](r2-public-signatures.log) にある。01-12と07-04にも表の対応の現在の条件を写した。

### Clauses_cons の短い Lean による確認

`<tmp>` の短い入力で、次の二段階を閉じた。

1. `LegacyTables.primitives` と実際の新旧の組み込みの `opSigAt` のlookupから、旧の子の型文脈
   `legacyTypeCtx (sg0.tparams ++ C) (replicate sg0.tparams.length value ++ κ)` が、新の `sg.tparams ++ legacyTypeCtx C κ` に等しいことを導く。追加したoperationKindsと既存のconstraints/opEffの対応を使い、新しい独立のkind入力は取らない。
2. この等号とlookupから得る型パラメータの個数の等号で、旧のvalue接頭辞の下にある子の帰納仮定を新しい `HasTypeClausesQ.cons` へ渡す。`clauses_cons_primitive_case` はその構成子まで組み立てる。

入力は [r2-clauses-probe.lean](r2-clauses-probe.lean) に写した（96行、入力のSHA-256は [r2-probe-input.json](r2-probe-input.json)）。`<tmp>` の検査も、保存した同じ入力を現在の既定ビルドの下で再検査した [r2-clauses-final.log](r2-clauses-final.log) も終了0である。単独Leanのメモリ上限は `-M 12288`。三定理の公理依存はpropext・Classical.choice・Quot.soundだけである。

この確認はレビューが特定したkindの接頭辞と個数の不一致を解消するものであり、`embedHasTypeClausesQ` 全体の証明ではない。値文脈・戻り先・注釈・本体の写しは、子のIHとして新しい構文の型付けの形で受ける。これらと旧の実際の導出からの合成、他の通常節の枝はL20.142の担当に残る。

### L60への申し送り

**LegacyTablesを実表から供給するL60の担当は、全ての `B.sig b = some s` で `s.opEff ≠ none` の署名を列挙し、型パラメータのkindの列が `List.replicate s.tparams.length .value` と一致することを照合して、新しいoperationKinds欄を供給する。** 旧新の制約・opEffの対応と同じ署名について確認する。型パラメータ0個の操作も対象に含める。操作を持たない組み込みのconstructor kindはこの条件で除かない。

Reference系など現在の組み込みの操作がvalue kindであることは、案1を選んだ取りまとめの理由であり、今回の担当が実表全件の照合を済ませたという記録ではない。L60でconstructor kindの操作又は対応の不一致が見つかった場合は、kindをvalueへ書き換えて表の条件を満たさず、具体的な署名と受理への影響を取りまとめへ返す。実表の照合の状態は**未実施、担当L60**である。

レビュー軽1のLegacyTypingContractsの割当ては取りまとめの担当のままとし、plan/detail/レビューの記録は変更していない。

### 検査と途中の失敗

射影の字面の変更だけでは、ReferencePreservationの既存のmapの等号を使う二箇所が通らなかった。`TypeCtx.kinds_eq_map C : TypeCtx.kinds C = C.map TParamDecl.kind` を加え、必要な二箇所だけで明示した。既定のsimpで射影を全面的に展開する属性は付けていない。局所ビルドを通してから作業末のformal_buildを再実行した。

初回の局所ビルドでは、射影の置換に伴う識別子の誤りも検出し、修正した。短い入力の初回のelaboration失敗も保存し、最終の終了0の記録と区別する。失敗した入力が出すsorryAxを成功の根拠にはしていない。

| 記録 | 終了 | 外側の時間 | 詳細 |
|---|---:|---:|---|
| `r2-local` | 1 | 1.901秒 | [r2-local.json](r2-local.json) |
| `r2-local-r1` | 0 | 34.422秒 | [r2-local-r1.json](r2-local-r1.json) |
| `r2-prefix-probe-r1` | 0 | 0.339秒 | [r2-prefix-probe-r1.json](r2-prefix-probe-r1.json) |
| `r2-clauses-probe-r1` | 0 | 0.364秒 | [r2-clauses-probe-r1.json](r2-clauses-probe-r1.json) |
| `r2-work` | 1 | 17.687秒 | [r2-work.json](r2-work.json) |
| `r2-reference` | 0 | 75.677秒 | [r2-reference.json](r2-reference.json) |
| `r2-work-r1` | 0 | 15.647秒 | [r2-work-r1.json](r2-work-r1.json) |
| `r2-clauses-final` | 0 | 0.456秒 | [r2-clauses-final.json](r2-clauses-final.json) |
| `r2-axioms` | 0 | 4.356秒 | [r2-axioms.json](r2-axioms.json) |
| `r2-public-signatures` | 0 | 0.752秒 | [r2-public-signatures.json](r2-public-signatures.json) |

同じB_WORKと `--only formal_build` のdry-runを確認し、最後の [r2-work-r1.log](r2-work-r1.log) で既定の八ターゲットのlake buildとsorryの拒否が終了0で通った。`--only` によりgitの変更分類を通らず、git操作は行っていない。処理系・旧Release・既定import・lakefileはr2で変更していない。

公理依存は [axioms-r2.lean](axioms-r2.lean) で変更した43モジュールの全4215宣言と、主な十移送・旧主定理5・旧モデル3を再確認した。終了0、許可一覧外0、sorryAx0である。集計は [axioms-summary-r2.json](axioms-summary-r2.json)、全宣言名・公理は `axioms-r2/` に保存した。大きな生出力は `<tmp>` に置き、large-records.mdに大きさとSHA-256を残す。

主な十言明の字面は変更していない。型付け規則への変更は五つの定義上等しい射影の表記だけであり、規則の意味と構成子数を変えていない。S12の切替条件に関する四移送38枝・private補題3枝・生の制約の7保持の件数はr1から不変である。76枝又は42時間40分を超える見込みは生じておらず、案4を維持した。

r2開始から本追記を作る直前までの外側の時間は 580.9秒（9.7分）。能動時間と待ちは全区間で分離していない。最大常駐量は未取得（計画上の非採取）。今回依頼された修正の残作業は0、L60の実表照合と独立レビューの再確認は担当へ申し送る。

最終のr2の照合は [self-check-r2.json](self-check-r2.json)、入力・出力と構成のハッシュは更新した [artifact-manifest.json](artifact-manifest.json) に保存した。

## 作業末の work

`scripts/check.sh --level work --base 14492156debe5f6b8925963e55c2d9aecdc6923c` を、Refinement の生成物を消した状態で実行した。終了0、外側98.89秒、最大常駐量1,456,668,672バイト。
