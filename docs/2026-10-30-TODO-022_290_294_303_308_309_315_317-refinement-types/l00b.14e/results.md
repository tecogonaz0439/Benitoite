# L00b.14e: 節の引数と resume の代表の結果

2026-11-01。**分類は「一部」である。** RV-L00b.14e の中1・軽1〜軽5に対応した。必須の E_Op/E_Resume/E_HRet/E_Drop と、追加の E_ResumeErr/E_DropRel/E_EscDropRel/E_ErrDropRel/E_ExitDropRel の計9種の代表を閉じた。全単相節・多相節・used/drop の全体・全状態の保存は L20 に残る。

**前提を変更した。** 中1への承認に従い、`Builtins.CoreAssumptions` に旧と同じ `state_effect : B.effects stateEff = some []` を戻し、旧の `Program.EffectsOk` の同じ内容の写しを Refinement に置いた。解放時の保存の四補題は `P.EffectsOk B` を入力にする。`NoStateHandled` を独立した前提にせず、これらから導く。`operation_one` の入力からは、開始から導ける `hx`・`hy` を除いた。ContTy・StateTyE と型付け・遷移の規則、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変更していない。

指定ブランチは `m014/l00b.14e`、B_WORK は `c64c0dc376b85185744303c4752d1f1bb34967af` である。git 操作、処理系・設計書・plan・レビュー本文・rv-* の変更、work の実行、L00b.15 の実施は行っていない。初回の結果と署名は [results-initial.md](results-initial.md)・[signatures-initial.md](signatures-initial.md) に保存した。レビューの追記も含め、保護した7入力の不変性は [protected-check.json](protected-check.json) にある。独立した再レビューと受け入れは取りまとめへ残す。

## 所見ごとの処置

| 所見 | 処置と根拠 | 残る範囲 |
|---|---|---|
| 中1 | state_effect と旧 EffectsOk を復帰し、Program.EffectsOk.noStateHandled、ContTy.state_end/prepend_releases、StateTyE.drop_rel_const を本番へ置いた。escape/error/exit の解放も追加した。Release の正例では保存された解放列が実際に非空である | 任意の ret/escape の closeVal と全 drop の合成は L20 |
| 軽1 | CoreAssumptions に旧の io_op がないことと、E_OpPrim で要否を調べる義務を下表へ明記した | 型付けとの照合と必要な条件の反例による確認は L20。未確認の反例を確定事項にはしない |
| 軽2 | ContTy.split_fail/fail_input を HandlerFailure に移し、具体の HasFailureClause と ContTy から使う境界を追加した | E_OpFail 全体はコードの型置換の補題の後 |
| 軽3 | capture_tel/result_tel と telExtend/telLift/telExtend_sig/args_under_capture を HandlerTelescope に移した。第二引数の型と結果が先行する引数を読む、二つの実値 three の正例を追加した | 引数列の捕捉・結果の補題は完成。操作全体の複数引数への合成だけを L20 に残す |
| 軽4 | hx は HasTypeTelArgsQ.param、hy は新しい ClosureTy.pure_operation_signature による SignatureInstance.result の逆転で導き、両方を入力から除いた | 一般の hy/hxn/hyn/hbn の除去は型置換の補題の後。dictParams も下表に追加 |
| 軽5 | signatures の guard の文を先頭 guard の直前にある対象の操作呼出しの不可能性へ修正した | 内側のハンドラで処理される操作を禁止する言明にはしない |

## 前提の新旧とモデル

| 対象 | 対応前 | 対応後 |
|---|---|---|
| Refinement の CoreAssumptions | State の予約の欄がない | 旧と同じ等号 state_effect を追加 |
| Program.EffectsOk | Refinement には未定義 | 旧の三連言を同じ内容で写す。L20 の主な定理でもプログラム側の前提として使う |
| drop_rel_const | 本番では未実装。レビュー補助 t2 は NoStateHandled を直接仮定する | hdecl : P.EffectsOk B と hA から NoStateHandled を導き、開始の StateTyE と実 Step から保存を返す |
| operation_one | hx と hy の Annotation を入力に持つ | 開始から両方を導出。hxn/hyn/hbn と代表の制限は残す |
| ContTy / StateTyE | .14d の K_Update を含む定義 | 変更なし |

旧 Release.Program/Builtins と Refinement.Program/Builtins は別の型であり、旧 EffectsOk をそのまま適用できなかった。定義は旧の三連言をコピーし、名前空間と引数の型だけを変えた。`verify.py` で定義本体の一致も確認している。別の新しいプログラム条件は作っていない。

境界の B は `effects stateEff = some []` に直し、CoreAssumptions の証明を閉じ直した。既存の旧 Model/ModelTargets/ModelHttp の B と仮定充足には同じ state_effect が既にあり、そのまま既定ビルドと公理監査を通した。Refinement.ModelHttp は新しい CoreAssumptions の具体の構築箇所ではなく、必要な部分の仮定を扱う。新しい CoreAssumptions の具体例は境界の assumptions である。

ReviewCounterTable.old_table_rejected は、rv-14e-t1 の操作表・効果表・組み込み表を再現し、CoreAssumptions を満たさないことを state_effect から示す。repaired_but_colliding は、State の予約だけを直すと利用者の State 宣言が EffectsOk の分離の条件に反することを示す。t1 の元の B は State を予約していないので、元の組そのものを EffectsOk の反例と取り違えない。D19 の方式の失敗ではなく、失われていた組み込み表とプログラム表の条件の不足である。

## 閉じた定義と補題

本番は新規8モジュール、公開は定義5・補題31の36宣言である。[source-delta.json](source-delta.json) に、集約 import と ConstraintAssumptions を含む全10ファイルのハッシュを記録した。初回からの既存ファイルの変更は ConstraintAssumptions・HandlerCalls・HandlerOperation・HandlerPreservation の4本だけであり、新規は HandlerEffects・HandlerFailure・HandlerTelescope の3本である。

| 本番のファイル | 公開した定義・補題と役割 |
|---|---|
| [HandlerContinuation.lean](../../../formal/Benitoite/Release/Refinement/HandlerContinuation.lean) | HandlerFrameTy、ContTy.nil_inv/resume_append/split_handle。捕捉とソースの注釈を保持して切り出し・接続 |
| [HandlerStore.lean](../../../formal/Benitoite/Release/Refinement/HandlerStore.lean) | StoreOk.allocate_continuation/use_continuation。割当てと使用時の有限性・WF・Declared・領域・全 CellOk を保存 |
| [HandlerEffects.lean](../../../formal/Benitoite/Release/Refinement/HandlerEffects.lean) | Program.EffectsOk、NoStateHandled、Program.EffectsOk.noStateHandled、ContTy.state_end/prepend_releases。State が handler で消されないことと解放列の型付け |
| [HandlerFailure.lean](../../../formal/Benitoite/Release/Refinement/HandlerFailure.lean) | ContTy.fail_input/split_fail。失敗節の入力の正規形と、原子 et.atoms・Fail ec.fails の切り出し |
| [HandlerCalls.lean](../../../formal/Benitoite/Release/Refinement/HandlerCalls.lean) | HasTypeCQ.operation_call、ClosureTy.pure_operation/pure_operation_signature。宣言への引数・結果・行・元の注釈の逆転 |
| [HandlerTelescope.lean](../../../formal/Benitoite/Release/Refinement/HandlerTelescope.lean) | telExtend/telLift/telExtend_sig/capture_tel/result_tel/args_under_capture。任意の依存列の捕捉の延長と結果の一致 |
| [HandlerPreservation.lean](../../../formal/Benitoite/Release/Refinement/HandlerPreservation.lean) | ContTy.return_annotation、releases_mem、StateTyE.handler_return_const/drop_used_const/resume_used/resume_const/drop_rel_const/esc_drop_rel_const/err_drop_rel/exit_drop_rel。開始から Step と到達の型付けを構成 |
| [HandlerOperation.lean](../../../formal/Benitoite/Release/Refinement/HandlerOperation.lean) | ContTy.guard_effect、StateTyE.operation_under_guard_false、ClosureTy.widen_atoms、StateTyE.operation_one。単相一引数の節へ進み、契約・潜在効果を保存 |

8モジュールは計1,570行、境界は675行である。暗黙の変数も含む完全署名は [public-api.log](public-api.log)、定義の内容・署名・採否は [signatures.md](signatures.md) にある。

## 入力の事実・依存する結果・捕捉・効果

元の境界の execution は、篩を持つ操作の実呼出しから節へ進み、resume で篩の結果を返し、継続が事実を読んで handler と drop を通る5遷移を持つ。clause_reads_input は入力の x<8 を Γ.facts から読み、resume の宣言の結果型 Integer{self=input ∧ self<8} を構成する。three_small/three_returned は D19 の閉じた評価から事実を導く。Snapshot は addEvaluated/addEntailed と close_entails を使い、ストアの used 化の後も捕捉の閉じた事実を読む。状態に経路条件の欄は足していない。

追加の TwoArguments.captured は、入力 [three,three] を具体に型付け、第二引数が第一引数との等号を満たすことと、結果が第一引数を読むことを確認する。capture_tel と result_tel を用い、任意の捕捉を扱う一般の two_dependent_arguments も置いた。複数引数の操作の Step 全体を完成したという主張ではない。

Release.drop_release/escape_release/error_release/exit_release は、保存された `[release resource, handleF empty []]` から空でない解放列を残し、セルを used にする実際の Step と到達の StateTyE を返す。state_end は handler・guard を含む ContTy の全10構成子で State の到達を示し、prepend_releases は同じ保存された ContTy から解放列を前置する。捕捉・閉性は元の保存された継続から取り出し、StoreOk.use_continuation を使う。通常の drop は任意の捕捉から定数の view、escape は pure の定数、error/exit は任意の開始に対する代表である。

split_handle/resume_append は GuardBodyTy と K_Update の証拠・Annotation を保持する。guard の不可能性は、先頭が guardF の継続の直前にある対象の操作呼出しに限定する。guard の内側のハンドラが操作を処理する場合まで禁止しない。

## 場合の数の予定と実際

| 族 | 初回の予定 | 所見対応後の実際 |
|---|---|---|
| 必須の Step | 4種 | E_Op/E_Resume/E_HRet/E_Drop の4種 |
| 追加候補 | 4種 | E_ResumeErr/E_DropRel の2種。E_OpFail/E_OpPrim は L20 |
| 解放時の伝播 | 初回は残件 | E_EscDropRel/E_ErrDropRel/E_ExitDropRel の3種を追加。代表は計9種 |
| ContTy | 全10構成子 | 切り出し・接続・State の到達と解放の前置・Fail の切り出しと入力の照合で全10形 |
| CellOk / GuardBodyTy | 6形 / 1形 | 既存の移送を再利用し、構成子を変更しない |
| 値 / 計算の逆転 | 29形 / 24形 | 部分型・正規化・効果拡大を含めて列挙 |
| 相互三族 / Step | 76形 / 76形 | A-L の環境検査で確認。代表9種とは別の数 |
| 公開 | 初回17宣言 | 36宣言（定義5・補題31）。承認済みの構造体の射影も検査 |
| 境界 | 初回100宣言 | 155宣言。元の5遷移・二度目の再開・契約を外す負例に、4解放遷移・表の拒否・失敗節・二引数を追加 |

## 補助の契約で決めたこと

1. EffectsOk は旧の三連言の写しとし、CoreAssumptions とプログラムの条件を分ける。
2. NoStateHandled は承認済みの二条件から導き、主な定理に独立して仮定しない。
3. state_end/prepend_releases は保存済みの ContTy を入力にし、解放後の結論を仮定しない。
4. 失敗節では `.mk et.atoms ec.fails` を保存し、通常節の noFail の条件を流用しない。
5. 依存列の捕捉と結果の一致は任意の捕捉・任意の長さで公開する。
6. hx/hy を開始から導き、代表の制限として hxn/hyn/hbn を残す。
7. escape の解放は pure の定数、error/exit は任意の状態で閉じる。
8. 元の HandlerFrameTy、EndsWithHandle と Covers、Fail を保つ原子の拡大、D19 の既存の入口、格納型の正規形での再開を維持する。

各案の理由と捨てた案は signatures の表にある。ContTy/StateTyE の定義の強化や新しい公理は必要なかった。

## 残りと送り先

L20 の項目はすべて計画の全ストア・閉包・継続の保存と型/行/範囲/値の置換の枠の内数である。Lazy/Reference と同じ閉包・任意の closeVal の一般化を重複して数えない。

| 送り先 | 残る義務と依存 | 見込み |
|---|---|---|
| L20 | 多相節・型引数・dictParams。HasTypeClausesQ とコードの型/行置換、捕捉の移送を合成する | 既存枠の内数。個別時間は未測定 |
| L20 | 型置換の補題の後に、一般の hy/hxn/hyn/hbn の条件を除く。今回の Normal の一引数の hy は導出して削除済み | 同上 |
| L20 | 複数引数の操作全体を一般化する。capture_tel/result_tel/args_under_capture は本番にあり、その作成自体は残件にしない | 同上 |
| L20 | pure でない操作の呼出し元、任意の再開値と ret/escape の closeVal。Lazy/Reference と共通の補題群で一度だけ扱う | 同上 |
| L20 | E_OpPrim。現在の CoreAssumptions に旧 io_op（Builtins.ShapeOk）がない。引数の範囲の添字と効果の添字の一致、ClauseRangeIs の具体化を照合し、閉じる時点で io_op の要否と条件の不足を反例で調べる。scoped の閉じた値の範囲を広げて読み直す補題も確認する。現時点では未確認 | 同上 |
| L20 | E_OpFail 全体は型置換の補題の後。split_fail/fail_input は本番にあり、失敗節の型の束縛・extendHidden・値なしの継続を開始の逆転と合成する | 同上 |
| L20 | used/drop 全体。今回の四解放入口を再利用し、任意の view と全 escape/error/exit・他の遷移への合成を行う。解放列の型付けと State の到達は未実装として残さない | 同上 |
| L20 | 新しい CoreAssumptions と Program.EffectsOk を主な定理の前提へ置き、代表の Normal・pure・定数・空の dictParams などの条件を主定理に残さず全状態の保存へ合成する | 不明（既存の全保存の枠） |
| L30 | 実装の節の入力/結果・切り出し・resume・used・解放の照合 | 不明（既存枠） |
| L40 | 進行と全 canonical forms。先頭 guard の空行と操作の不可能性も範囲を守って合成する | 不明（既存枠） |
| L00b.15・取りまとめ | 公開36宣言・代表9種・承認済みの前提の復帰・残件を写しと分類の整理へ反映する。今回の代表だけで O051 や全保存を完了扱いしない | 不明（担当外） |
| 再レビュー・work・取り込み・受け入れ | 取りまとめが再レビューと指定の work・取り込みを行い、設計者が受け入れる | 不明（担当外） |

## 計画からのずれ

初回の「既存の CoreAssumptions で足り、表の不足の反例はない」という報告は中1の反例により訂正した。承認された旧の二条件を戻した範囲で、解放の保存まで閉じた。O008 は開始から逆転する代表9種とし、同時構成だけの主張とは区別する。O051 全体と全状態の保存は完了扱いにしない。D19 の方式は元の5遷移で引き続き成立する。

単相全体ではなく一引数・pure・Normal・空の型置換の固定点の代表という限定は残る。Fail と任意長の依存列の補助が本番へ増えたが、これらを使った操作全体の一般化は L20 である。

## ビルド・公理依存・入力のハッシュ

[verify.py](verify.py) を実行した。既定ビルドは [lakefile](../../../formal/lakefile.toml) の moreLeanArgs の -M 12288、境界・完全署名・A-L の単独の Lean にも -M 12288 を付けた。Lean は leanprover/lean4:v4.34.1 である。

| 検査 | 終了 | 件数 | 外側の時間 | 記録 |
|---|---:|---|---:|---|
| 既定の lake build | 0 | 736ジョブ | 0.158秒 | [build.log](build.log) |
| 境界の実遷移・正負例と公理依存 | 0 | 155宣言 | 1.420秒 | [boundary.log](boundary.log) |
| 完全署名と承認済みの欄 | 0 | 公開36宣言と state_effect の射影 | 0.324秒 | [public-api.log](public-api.log) |
| 全差分を含む A-L | 0 | 155モジュール・15,497宣言 | 13.626秒 | [large-records](large-records.md) |

全差分と境界の依存公理は propext・Quot.sound・Classical.choice のみであり、sorryAx はない。全新規8モジュール、ConstraintAssumptions、集約 import、全 Refinement、旧の3モデルの仮定充足と旧 Release の主定理を監査した。本番と境界に sorry/admit/axiom/native_decide/unsafe/implemented_by はない。

今回の最初の一括確認は、既定ビルドの成功後、境界の簡約のリストに存在しない Pred.bind を含めていたため終了1となった。[verification-resume-first.json](verification-resume-first.json)・[boundary-resume-first.log](boundary-resume-first.log) に記録した。不要な名前を除いて境界を再実行し、155宣言すべてを確認した。この修正は境界だけである。境界の再確認では成功済みの既定ビルドをハッシュ一致で引用した。その後、台本のビルドの入力のハッシュを全形式化ソースへ広げ、最後の一括確認で既定ビルドも実行し直した。[verified-build.json](verified-build.json) はライブラリに加えて既定の全実行入口と設定を記録する。

[source-inputs.json](source-inputs.json) は全 Refinement と設定、[boundary-inputs.json](boundary-inputs.json) は境界・公開署名・A-L・台本・保護入力を記録する。[protected-inputs.json](protected-inputs.json) と [protected-check.json](protected-check.json) で、rv-14e-t1〜t5・counts とレビュー本文が同じハッシュであることを開始と終了に確認した。rv 入力は対応前の定義の証拠として保存し、新しい前提でそれらをそのまま再ビルドしたという主張はしない。最終の境界は本番の入口を用いている。

100 KB を超える今回の A-L の生出力1,685,493バイトは一時領域へ置き、大きさと SHA-256 を [large-records.md](large-records.md) に記録した。改造内に100 KBを超えるファイルはない。初回の記録は *-initial と初回の first に残す。既定ビルドの既存の lint の警告はある。Rust の検査、全比較、性能測定、別機、追加の LLM 起動、work は行っていない。最大常駐量は未取得である。

## 外側の時間

初回は 2026-10-31 23:01:37 UTC から23:26:45 UTC まで約25.1分であった。今回の再開は 2026-10-31T23:44:44Z から 2026-10-31T23:59:12.994983+00:00 まで約14.5分である。読み取り・署名・実装・局所確認・一括確認・文書化を含み、能動時間と待ちは分離していない。今回の上限5時間以内である。

## 作業末の work

取りまとめが実行した。基準は `c64c0dc376b85185744303c4752d1f1bb34967af`、コマンドは `scripts/check.sh --level work --base <基準>`、選ばれた単位は `formal_build` だけで、終了状態は 0、外側の時間は 87.22 秒である。実行の前に Refinement の生成物を消した。
