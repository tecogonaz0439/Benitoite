# L70 群 B の結果（L70.09〜.16）

ブランチ `m014/l70.b`、B_WORK `49f17471442229baf668e7b1f7b6dac8151c6dcf`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の操作と `scripts/check.sh` は行っていない。生の出力は `<tmp>` に置いた。

## 単位の時刻

外側の時間は能動時間と待ち時間を分けていない。時刻は作業中のコマンドの出力の時刻と既定ビルドの記録から書き起こしたものであり、各単位の開始と終了の時点に記録したものではない（依頼文の指示からのずれ）。単位の間は重なっている（ビルドの待ちの間に次の単位を下書きした）。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込み | 2026-11-06 06:59 | 07:08 | 約9分 |
| `Step.lean` の変更と既定ビルド | 07:08 | 07:19 | 11分（ビルドの待ち10分59秒。並行して進行の葉を読んだ） |
| L70.10・.11 進行 | 07:19 | 07:48 | 約29分（`BuilderStateLeaves.lean` の変更の既定ビルドの待ち9分39秒を含む） |
| L70.12・.13 実行関数の健全性 | 07:37 | 07:51 | 約14分（07:37〜07:46 はビルドの待ちの間の下書き） |
| L70.09 保存の包装・L70.16 対象健全性・主な定理のモジュール | 07:51 | 07:53 | 約2分 |
| L70.14 開始状態の型付けと開始の条件の証人 | 07:53 | 07:56 | 約3分 |
| L70.15 エフェクトの健全性（反例の形式化） | 07:55 | 07:58 | 約3分（反例の見当は読み込みの間の 07:10〜07:20 に付けた） |
| L70.14 ラムダ名の整形式を外した閉じ方の接続 | 08:01 | 08:08 | 約7分 |
| 群末（写し・公理監査・照合・読者の照合・記録） | 08:08 | 08:31 | 約23分（最後の既定ビルドの錠の待ち約9分を含む） |

## 結論

`MainStatements` の言明のうち、進行・保存・実行の列の保存・実行関数の健全性・開始の状態の型付け・到達先の対象健全性・事象の種類によらない到達先の対象健全性の七つを新判断で閉じた。noLamNames 版に要る開始の条件への接続は、任意の型が付いた開始の閉包について閉じた（名前の整形式を型付けから供給し、At の呼出し・実行時の閉包・保持した要求の中まで辿る。RV-L70.b の処置で広げた）。公理は許可した三つだけであり、`sorry`・新しい公理・既定 import からの除外はない。

**止める条件に当たる二件がある**（「取りまとめに判断を求める点」）。

1. `EffectSoundnessStatement`（エフェクトの健全性。旧 `effect_soundness`・`effect_soundness_noLamNames` に当たる）は**偽**である。反例を Lean で検査した（[effect-counterexample.lean](effect-counterexample.lean)、`EffectCounterexample.not_effect_soundness`）。言明・規則・信頼条件のどれかを変える必要があり、どれも止める条件に当たる。
2. `StepTargetStatement`（一段の対象健全性。旧 `step_target_sound`）は、事象の実引数の型付けを閉じた view から得るためにプログラムの整形式と型付けを要るが、言明にその前提がなかった。再開1で取りまとめの決定により前提を加え、`R.step_target_sound` で閉じた。

この二件を除く単位は、止めずに最後まで進めた（二件は他の単位の前提にならない）。

## 主な言明の結果と旧主定理との対応

R は `Benitoite.Release.Refinement` を表す。

| 言明 | 証明の完全名 | 前提 | 結果 |
|---|---|---|---|
| `ProgressStatement P B σ` | `R.progress` | `P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`StateTy P B σ s` | 閉じた |
| `PreservationStatement P B σ` | `R.preservation` | 同じ4つ・`StateTy`・`Step` | 閉じた |
| `StepsPreservationStatement P B σ` | `R.steps_preservation` | 同じ4つ・`StateTy`・`Steps` | 閉じた |
| `StepSoundStatement P B σ oracle externalOracle rel fresh` | `R.step_sound` | `P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P`・`StepSelection`・`StateTy` | 閉じた |
| `InitialTypingStatement P B σ` | `R.initial_typing` | `P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P`（証明は読まない）・`ClosureTy … Eff 初期`・`StartCondition` | 閉じた |
| `ReachableTargetStatement P B σ` | `R.reachable_target_sound` | 4つ・`B.TargetAgreement P`・`ClosureTy`・`StartCondition`・`Steps`・IO の `Step` | 閉じた |
| `ReachableTargetEventStatement P B σ` | `R.reachable_target_sound_event` | 同上・任意の事象 | 閉じた |
| `EffectSoundnessStatement P B σ` | なし | — | 偽（反例 `EffectCounterexample.not_effect_soundness`）。止めた |
| `StepTargetStatement P B σ` | `R.step_target_sound`（再開1） | `P.WellFormed`・`P.WellTyped B`（再開1で追加）・`P.EffectsOk B`・`B.CoreAssumptions P`・`B.TargetAgreement P`・`σ.Valid`・`StateTyE`・IO の `Step` | 閉じた（再開1） |
| noLamNames の接続 | `R.StartCondition.of_typed_noLamNames`（`R.ClosureTy.closed_noLamNames`・`R.HasTypeCQ.closed_noLamNames_resolved`）。空の捕捉の形 `R.StartCondition.of_noLamNames` も残す | 任意の開始の閉包の型付け `ClosureTy P B StoreTy.empty [] none q a e`・`Closure.ClosedNoLamNames 0 q`・保持値の適格性・`InitialPrepared` | 閉じた（RV-L70.b の処置）。効果の言明は上の行のとおり |

| 旧主定理（L60 の対応表の12件） | 新しい対応 | 結果 |
|---|---|---|
| `Release.progress` | `R.progress` | 閉じた |
| `Release.preservation` | `R.preservation`（と `R.steps_preservation`） | 閉じた |
| `Release.step_sound` | `R.step_sound` | 閉じた |
| `Release.effect_soundness` | `EffectSoundnessStatement` | 偽。止めた |
| `Release.effect_soundness_noLamNames` | 同じ言明と `R.StartCondition.of_typed_noLamNames` | 接続は任意の型が付いた開始の閉包について閉じた。言明は止めた |
| `Release.reachable_target_sound` | `R.reachable_target_sound` | 閉じた |
| `Release.reachable_target_sound_event` | `R.reachable_target_sound_event` | 閉じた |
| `Release.reachable_target_sound_of_assumptions` | 対応なし（群 A の判断。前提は `ReachableTargetStatement` と同じ） | — |
| `Release.step_target_sound` | `R.step_target_sound`（前提に `P.WellFormed`・`P.WellTyped B` を加えた。再開1） | 閉じた |
| `Release.Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` | L70.19（群 C） | 本群の範囲外。`MainTheorems` の第三の例で、`Model.builtins` と宣言を持たないプログラムが到達先の対象健全性の前提をすべて満たし、定理を適用できることを示した |

旧の主定理の量化（任意の P・B・状態・実行の列、固定した σ、選択の条件を満たす任意の実行関数）を保った。結論は弱めていない。error・exit を消す保証、正常応答の存在、`step` の逆向きの完全性は加えていない。

## L70.15 で止めた件: エフェクトの健全性の反例

`E_IssuePathBases` は、処理する枠の有無を見ずに σ の発行の事象を出す。`E_PathBasesApply` は `NoHandler` を確かめてから `issuePathBases` の計算を作るので、表層から作った実行ではこの計算は処理する枠の下に現れない。しかし `EffectSoundnessStatement` の開始の条件（`StartCondition`）は表層から作る構文であること（`Comp.Source`。`issuePathBases` を拒む）を要求しない。開始の閉包に `issuePathBases` を Process.Environment の全操作を処理する `handle` の中へ直接書くと、`C_Handle` がその効果を消して閉包は空の効果で型が付き、二段の後に事象が起きる。

| 項目 | 内容 |
|---|---|
| 反例 | `Model.builtins`（Process.Environment の操作は `Example.pathBases` だけ）、宣言を持たないプログラム、全起点と secrets を束縛する σ、開始の閉包 `handle (let _ = issuePathBases Example.pathBases in return ()) with [Example.pathBases ⇒ return ()]`。WF・WT・EffectsOk・CoreAssumptions・`ClosureTy … Eff.empty`・`StartCondition` を満たし、`E_Handle`・`E_Let` の後の状態が `E_IssuePathBases` で `Event.pathBases` を出す |
| 検査 | `formal/` で `lake env lean -M 12288 <effect-counterexample.lean>`。終了0、`not_effect_soundness` の公理は propext・Classical.choice・Quot.sound（記録 214 バイト、SHA-256 `247f2d156f7292cac8cb128b11c5e6a9452312a5d73f0bd3c3859ff927b3d21b`）。既定ビルドには含めない |
| 実行時の値の経路 | 開始を表層の構文に限っても、組込みの応答（δ・IO・外部・解放）が `issuePathBases` を含む実行時の閉包を返すことを現在の信頼条件は禁じていない。この経路の反例は形式化していない（推論のみ） |

代案（どれも止める条件に当たる。所要は能動時間の見積もりで実測ではない）:

| 案 | 変えるもの | 実用への影響 | 所要 |
|---|---|---|---|
| A. 実行規則 | `E_IssuePathBases` に `NoHandler k (.prim b)` を加え、処理する枠があるときは `E_OpPrim` と同じく節へ移る規則を `issuePathBases` にも足す（`step` も同じ分岐を足す） | 表層の書ける形は変わらない。表層から作る実行では発行は適用の直後にだけ起き、そのとき枠はないので観測は変わらない見込み（処理系の照合は R30/R50）。01-12 の実行の規則の変更、保存の葉の追加 | 3〜5時間（保存の葉・進行・実行関数の健全性・効果の健全性の証明を含む） |
| B. 開始の条件と信頼条件 | 開始の閉包が `issuePathBases` を含まないことを開始の条件に足し、組込みの応答が実行時専用の計算を含む閉包を返さないことを信頼条件に足し、到達状態で `issuePathBases` が `NoHandler` の継続の下にだけ現れる不変条件を全76遷移で保存する | 新しい信頼条件（独立の信頼条件）と主な言明の形の変更 | 6〜10時間 |
| C. 型付けの規則 | PathBases の組み込みを処理する節を断る（`ClauseSig`）か、`handled` が Process.Environment を消さない | 利用者の書ける形を狭める（`Process.pathBases` を処理する handler） | 2〜5時間 |
| D. 結論 | pathBases の事象を結論から除く | 結論の弱化であり不可 | — |

いずれの案でも、noLamNames 版は `EffectSoundnessStatement` の修正版と `R.StartCondition.of_typed_noLamNames` の合成で得る（名前の条件を独立の信頼条件にしない）。

## L70.16 で止めた件: 一段の対象健全性の前提

`StepTargetStatement` の前提は `P.EffectsOk B`・`B.CoreAssumptions P`・`B.TargetAgreement P`・`σ.Valid` だけである。IO の観測の対象の許可（`Builtins.TargetAgreement.obs_allowed`）は閉じた型付き実引数（`BuiltinArgs`）を要り、`StateTyE` から閉じた実引数を得る補題（`ClosureTy.primitive_view_inputs` → `close_value_typed`）は `P.WellFormed`・`P.WellTyped B` を前提にする。この二つを加えた形 `R.StateTyE.io_target_sound` を閉じ、到達先の二つの言明はこれで閉じた。

| 案 | 内容 | 影響 | 所要 |
|---|---|---|---|
| 1 | `StepTargetStatement` に `P.WellFormed`・`P.WellTyped B` を加え、`R.StateTyE.io_target_sound` で閉じる | 群 A で取りまとめが認めた進行・実行関数の健全性への前提の追加と同じ種類。到達先の言明は既に両前提を持つ | 15分 |
| 2 | 前提を変えずに、閉じた実引数の型付けを WF・WT なしで得る補題を作る | 可否は未調査。閉包の型付けの補題群（`close_value_aux` ほか）の全面の見直し | 不明（数時間以上） |

## 足した・変えた宣言

足したモジュールは5つ、変えた既存のモジュールは2つである。全宣言（private・生成宣言を含む）は公理監査の対象で665件（足したモジュール379件、private 367件）である。

| モジュール | 主な宣言 |
|---|---|
| `R/MainProgress.lean`（150宣言） | 進行の場合ごとの補題 `StateTyE.return_progress`・`escape_progress`・`error_progress`・`exit_progress`・`match_progress`・`primitive_progress`・`operation_progress`・`raise_progress`・`app_progress`・`method_progress`・`resume_progress`・`builder_progress`・`run_progress`・`progress`。継続の逆転 `ContTy.drop_cell`・`guard_boolean`・`fail_end`・`fail_clauses`。ハンドラの探索 `SplitAt.of_not_noHandler`・`findClause_of_handles` |
| `R/MainStepSound.lean`（149宣言） | `splitHandler_split`・`splitHandler_noHandler`、`StateTyE.run_step_sound`・`match_step_sound`・`StateTyE.error_step_sound`・`exit_step_sound`・`StateTyE.step_sound` |
| `R/MainTargets.lean`（4宣言） | `ContTy.allows_end`・`StateTyE.io_target_sound` |
| `R/StartLamNames.lean`（77宣言。RV-L70.b の処置の後） | `Val.ClosedNoLamNames`・`Comp.ClosedNoLamNames`・`Closure.ClosedNoLamNames` ほか（相互の定義6つ）、`CheckedWitness.request_closed`、`HasTypeVQ.closed_noLamNames_resolved`・`HasTypeCQ.closed_noLamNames_resolved`・`DependentClosureTy.closed_noLamNames`・`AtCallAdmissible.closed_noLamNames_resolved` ほか相互の定理11、`HasTypeVQ.closed_noLamNames`・`HasTypeCQ.closed_noLamNames`、`ClosureTy.closed_noLamNames`、`StartCondition.of_typed_noLamNames`・`StartCondition.of_noLamNames` |
| `R/MainTheorems.lean`（17宣言。RV-L70.b の処置の後） | `preservation`・`steps_preservation`・`progress`・`step_sound`・`initial_typing`・`reachable_target_sound`・`reachable_target_sound_event` と、具体の表の三つの例（進行・保存・実行関数の健全性の同時の適用、開始の条件の証人、到達先の対象健全性の全前提の同時の証人） |
| `R/Step.lean`（変更） | `stepRun`・`stepMatch` の `private` を外した（本文は同じ） |
| `R/BuilderStateLeaves.lean`（変更） | `builder_view_operation`・`builder_operation_inputs`・`builder_local_inv`・`builder_cell_convert` の `private` を外した（本文は同じ） |

既存の宣言の言明は変えていない。型付けの規則・実行の規則・信頼条件・主な10言明の形は変えていない。他のモジュールの private の補題のうち短いもの（`EffectAtom` の一式、参照の組み込みの依存列の計算 `refTel`・`store_tel`・`force_tel`・`store_arguments`、`clauses_no_fail`、`resume_form`）は、既存のモジュールを変えないよう新しいモジュールに private の写しとして置いた（既存のコードに同じ書き方の前例がある）。

### 既存のモジュールの変更（変える前の記録）

| モジュール | 変更 | 理由 |
|---|---|---|
| `R/Step.lean` | `stepRun`・`stepMatch` の `private` を外す（本文は変えない） | 実行関数の健全性は `step` の全分岐を読む。両者が非公開だと他のモジュールから展開できず、`change` で各分岐の match を書き写すか定義の写しを置くことになる。公開にすれば `unfold` と `split` で全分岐を同じ定義のまま読める。並行の群がこのファイルを変える予定はない（詳細の第4節の単位の表） |
| `R/BuilderStateLeaves.lean` | `builder_view_operation`・`builder_operation_inputs`・`builder_local_inv`・`builder_cell_convert` の `private` を外す（本文は変えない） | 進行の builderOp の場合は、閉じた view の型付き実引数とセルの内容の種類の一致を要る。四つは閉包の閉じ方の補助（`close_builder_operation` ほか約130行）に依存しており、写すと同じ証明が二つになる |

根の import は `MainStatements` の行の直後に5行を挿入した（並行の群が末尾へ足す行と衝突しにくくするため。既存の行は変えていない）。07-04 は新しいモジュールの説明の段落とモジュールの表の1行を足した。01-12 の写しの対象（定義と規則）は変えていないので、01-12 は変えていない。

## 条件と前提の四分類

| 条件・前提 | 分類 | 証人 |
|---|---|---|
| `StartCondition` の3欄 | 実質（群 A の保留を解消） | `MainTheorems` の第二の例（単位の値を返す閉包、`InitialPrepared` は起点の範囲を辿らないことから） |
| `StepSelection` の4欄 | 実質 | `Builtins.selected_stepSelection` を `MainTheorems` の第一の例で `step_sound` に渡した |
| 進行・保存・実行関数の健全性の前提（WF・WT・EffectsOk・Core と `StateTy` の `BuiltinOnly`） | 実質 | `concrete_finite_preservation` の表と状態（第一の例） |
| 到達先の対象健全性の前提（WF・WT・EffectsOk・Core・`TargetAgreement`・`ClosureTy`・`StartCondition`） | 実質（群 A の「EffectsOk は保留」を解消） | `Model.builtins` と宣言を持たないプログラム（第三の例） |
| `Closure.ClosedNoLamNames`・`Comp.ClosedNoLamNames`（`StartCondition.of_typed_noLamNames`・`of_noLamNames` の前提） | 実質 | 単位の計算（第二の例は `of_noLamNames`、第三の例は `of_typed_noLamNames`） |
| `EffectSoundnessStatement` の前提 | 実質（前提は同時に成り立ち、結論が偽） | `effect-counterexample.lean` |

## 義務・申し送りの判定

読者の照合は、主な定理の型と証明の定数の推移閉包（private の宣言を含む）に名指しの葉が含まれるかを、既定環境で数えた（台本 [readers.lean](readers.lean)・[readers.json](readers.json)。記録 23,411 バイト、SHA-256 `47e584cc7a39889b90238e6d709cd0bb9bb89368e0516ad75af855590e72a59a`）。

| 行 | 判定 | 証拠 | 残る段 |
|---|---|---|---|
| O038・O058・O008・L20-J1（保存の包装） | 完了 | `R.preservation`・`R.steps_preservation` が `StateTyE.step_preserved`・`steps_preserved` を読む | なし |
| O057（進行） | 完了 | `R.progress` | なし |
| O059（step_sound、計算から関係の向き） | 完了 | `R.step_sound` | なし |
| O060（effect_soundness と noLamNames） | 停止 | 言明が偽。接続は `R.StartCondition.of_typed_noLamNames`（任意の型が付いた開始の閉包。RV-L70.b の処置） | 効果の健全性は群 K |
| O061（一段・到達・表層の対象健全性） | 部分 | 一段は `R.step_target_sound`（再開1）、到達の2形は `R.reachable_target_sound`・`_event` | 表層は L70.34 |
| L60-H22（全主定理） | 部分 | 上の表 | 効果の健全性（群 K） |
| L00b-主（新しい量化） | 部分 | 進行・保存・実行関数・対象（到達）の量化は対照のとおり。効果は止めた | L70.15 |
| L60-H28（全開始・全応答） | 完了 | 進行は任意の型付き状態について、応答の存在を信頼条件から読む（`external_response_step`・`selected_primitive_step`・`release_response_exists` が `R.progress` の閉包にある） | なし |
| L60-受口3（外部の存在と計算→関係） | 完了 | `external_response_step` を `R.progress` と `R.step_sound` が読む。実行関数は `StepSelection.external` で応答を戻す | なし |
| L60-受口4（通常資源） | 完了 | `release_response_exists` を両者が読む。実行関数は `StepSelection.release` | なし |
| L50-H02（`TelClosure.apply` の四前提を戻さない） | 完了 | 進行は `StateTyE.app_inputs` を読み、前提を足していない | なし |
| L50-受口1（`AtPrepared.current`・`at_step`・`ScopedTargetInputs`） | 部分 | `AtPrepared.current`・`StateTyE.at_current`・`at_step` を `R.progress` が読む。`ScopedTargetInputs` は保存の葉の側 | 対象健全性の At は IO の事象を持たないので該当なし |
| L40-F01（逆転の形） | 完了 | 進行は `HasTypeVQ.canonical_function`・`inv_op`・`inv_raise` を読む | なし |
| L40-後段1（腕の選択） | 部分 | 進行は `StateTyE.match_inputs`・`Capture.typed_coverage` で腕を選ぶ。decoder の型付けは L70.43 | L70.43 |
| L20-187（全合成・腕） | 部分 | 同上 | L70.43 |
| L50-H08（`Ready` を全状態に加えない） | 完了 | `InitialPrepared` を開始の条件にだけ使い、`StateTyE` に加えていない（`R.reachable_target_sound` の閉包の `PathEnv.Ready` は開始の条件から） | なし |
| O051（捕捉 Φ の閉じ方を開始の定理で使う） | 完了 | 開始の定理は `StartCondition.closed`（捕捉の閉じ方を含む）を読む | なし |
| plan-RV03（開始の定理の前提） | 完了 | `InitialTypingStatement` の前提を群 A のとおり使った | なし |
| L60-H02（`externalRef_contract_inputs` の全合成） | 完了（読者を要しない。再開1の取りまとめの判定） | 進行の外部参照の適用は `E_ExternalApply` が前提を持たず、どの型付き状態でも遷移するので契約の入力を読まない（`R.progress` の閉包にない）。外部参照の適用の行先の型付けは保存（C01 の `external_apply_all`）が受け持つ | なし |
| L50-H01（`canonical_held`・`app_inputs`） | 完了（`canonical_held` は読者を要しない。再開1の取りまとめの判定） | 進行は `app_inputs` を読む。適用の頭は関数の型の値であり `canonical_function` で八つの形に分かれるので、保持値の形を返す `canonical_held` を要らない（`R.reachable_target_sound` の閉包にはある） | なし |
| L60-H01・H03・H04、L50-H03・H04・H22・H28・H31・U1・実行、L20-J6、O035・O036・O048・O141・O006・O031 | 部分 | 主な定理は任意の B で信頼条件の欄（`delta_typed`・`io_target` など）を読む。標準の表の行の葉（`ScopeResponse.response`・`normal_facts`・`StandardModel.core`）は主な定理の閉包にない（標準の表への適用は L70.19） | L70.19・L70.34、R30/R50 |
| L60-H11・L50-H11・L00b-G05・plan-RVat・plan-D28（効果の健全性の pathBases） | 停止 | 言明が偽 | 判断の後に L70.15 |
| L60-H08 | 部分 | 開始の定理と開始の条件の証人 | L70.34 |

## 群末の記録

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 開始状態の確認 | 錠の下で `lake build --no-build` | 0 | 1秒未満（1342 jobs、全て最新） | `<tmp>` の build0.log（45,154 バイト）。変えたモジュールの警告の照合に使う |
| `Step.lean` の変更後の既定ビルド | 錠の下で `lake build` | 0 | 10分59秒 | `<tmp>` の rebuild1.log（68,765 バイト） |
| `BuilderStateLeaves.lean` の変更後の既定ビルド | 同 | 0 | 9分39秒 | rebuild2.log（57,590 バイト） |
| 新しいモジュールを加えた既定ビルド | 同 | 0 | 7秒 | rebuild3.log（45,596 バイト） |
| 単独の検査 | `lake env lean -M 12288 <file>`。後続のモジュールは、既定の出力へのリンクの木を `<tmp>` に作り、新しいモジュールだけを `-o` でその木へ書いて読んだ（既定の出力を上書きしない） | 0（途中の誤りは各回に直した） | 1件1〜5秒 | — |
| 群末の既定ビルド | 錠の下で `lake build` | 0 | 9分3秒（錠の待ちを含む。1347 jobs） | build.log（45,453 バイト、SHA-256 `293801b271b9c7e6f41329560cfe3d0267d0857e4181ac846060406cd40c3269`） |
| 公理監査 | 錠の下で `formal/` から `lake env lean -M 12288 <axioms.lean>` | 0 | 約12秒 | axioms.log（279,700 バイト、SHA-256 `0118294d3433170272163688a43de1f8f1bd6784eadbb6cadb5bf31c1fd52f23`） |
| 反例の試行 | `lake env lean -M 12288 <effect-counterexample.lean>`（末尾に `#print axioms` を足した写し） | 0 | 1秒 | counterexample.log（上記） |
| 読者の照合 | `lake env lean -M 12288 <readers.lean>` | 0 | 約4秒 | readers.log（上記） |
| 照合 | `python3 l70/b/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json) |

公理監査の対象は、足した5モジュールと変えた2モジュール（[audit-modules.json](audit-modules.json)）の全宣言665件である。公理の組は、なし148、propext 278、propext と Quot.sound 7、三公理232で、許可した三公理の外の公理と sorryAx はない。必須の名前47件（[required-names.json](required-names.json)）はすべて対象にある。`verify.py` は、変更の範囲（Refinement の2モジュールの `private` の削除・根の import・07-04 だけ）、既存のモジュールの差分が名指しの宣言の `private` の削除だけであること、根の import に足した5行が一度ずつ現れ既存の行を変えていないこと、足したモジュールの警告がなく変えたモジュールの警告が開始状態の記録にあったものに限ること、`sorry`・`#eval`・工程の ID がないこと、反例の試行の記録、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを照合した。

`scripts/check.sh` の work は取りまとめが群末に実行する。01-12 は変えていない。RSS の正式の測定は取りまとめが行う（未取得、計画上の非採取）。

## 計画からのずれ

- 単位の時刻を各単位の開始と終了の時点に results.md へ書かず、コマンドの出力の時刻から書き起こした。
- 既存のモジュールを2つ変えた（`private` の削除だけ。上の表）。
- 進行と実行関数の健全性の単位の境（.10/.11、.12/.13）は一つのモジュールの中で続けて行い、分けて記録していない。
- L70.14 に、開始の条件の証人（群 A の保留の解消）と、到達先の対象健全性の全前提の同時の証人を足した。
- L70.15 は止めた（反例）。L70.16 の一段の言明は止めた（前提の不足）。前提を加えた形と到達の2形は閉じた。
- 初めの版の `Comp.ClosedNoLamNames` は At の呼出しの値・実行時の閉包・保持した要求の中を元の閉じ方のまま読み、接続は空の捕捉の閉包に限っていた。RV-L70.b の重2の処置で、これらの中まで辿る形と任意の型が付いた開始の閉包の入口に広げた（「RV-L70.b の処置」）。
- 第8.1節の「最初の同種の一群」のうち `progress_ret` などの6件は、旧の補題の写しではなく、新判断の葉を合成する補題（`StateTyE.return_progress` ほか）として置いた。一件ごとの能動時間は分離できないので未取得とする。

## 取りまとめに判断を求める点

1. **エフェクトの健全性の言明が偽である**（L70.15）。代案 A（実行規則）・B（開始の条件と信頼条件）・C（型付けの規則）のどれを採るか。どれも停止条件に当たる（A は実行の規則の変更、B は独立の信頼条件と言明の形の変更、C は書ける形を狭める）。担当の見立てでは A が利用者の書ける形と信頼条件を変えない。
2. **一段の対象健全性の言明に `P.WellFormed`・`P.WellTyped B` を加えるか**（L70.16）。加えれば既存の `R.StateTyE.io_target_sound` で閉じる。
3. L60-H02 と L50-H01 の「進行が名前付きの読者になる」の判定。進行の該当の場合はその葉を要らない（上の表）。完了とみなすか、別の読者を求めるか。
4. 既存のモジュール2つの `private` の削除を受け入れるか。

## 再開1

2026-11-06 08:32 開始、08:37 終了（外側の時間約5分。ビルドと監査の待ちを含む）。取りまとめが判断を求めた4点を決めた（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭）。決定に従って次を処置した。上の節の表は、この処置の後の状態に直した。

| 決定 | 処置 |
|---|---|
| 1. エフェクトの健全性は群 B では直さない。案 D（操作でない組み込みが使うラベルを `handle` の処理済みの集合から除かない）を群 K が行う | 反例を記録に残した（[effect-counterexample.lean](effect-counterexample.lean)）。案 D の言明の形（`handled` の定義の変え方、読者の見込みの数、案 A との比較）を [effect-fix.md](effect-fix.md) に書いた。`EffectSoundnessStatement` は言明を変えずに未了のまま残した |
| 2. `StepTargetStatement` に `P.WellFormed`・`P.WellTyped B` を加え、`StateTyE.io_target_sound` で閉じる | `R/MainStatements.lean` の言明に二つの前提を加え、docstring にその理由を一文足した。`R/MainTheorems.lean` に `R.step_target_sound` を足し、`R.reachable_target_sound` はこれを経て読む形にした。旧主定理との対応の表、07-04 の `MainStatements` の段落（前提の理由）と主な定理の段落（閉じる言明の一覧）を直した |
| 3. L60-H02 と L50-H01 は、読者を要しない完了と判定する | 義務の表の二行に、進行のその場合で葉が要らない理由を書いて完了とした |
| 4. 既存の2モジュールの `private` の削除を認める | 処置なし |

`verify.py` は、`R/MainStatements.lean` の差分が `StepTargetStatement` の docstring と前提の行の二行だけであることを照合するようにした。監査の対象のモジュールに `MainStatements` を加え、必須の名前に `step_target_sound`・`StepTargetStatement` を加えた（49件）。

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 既定ビルド | 錠の下で `formal/` から `lake build` | 0 | 9秒（1347 jobs） | build.log（45,720 バイト、SHA-256 `4f775b0d8506bfa4b13263b77182705d6abf2b5ea1b9927b04c856144895d1e7`） |
| 公理監査 | 錠の下で `formal/` から `lake env lean -M 12288 <axioms.lean>` | 0 | 約12秒 | axioms.log（290,909 バイト、SHA-256 `80d2c88a2522dd03e9b21d327b7db4ddba9d3ac6a44005430f78ae21144cb0bc`）。対象702件（足したモジュール380件、private 367件）、公理の組はなし160・propext 281・propext と Quot.sound 7・三公理254。許可した三公理の外の公理と sorryAx はない |
| 照合 | `python3 l70/b/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json) |

この節の後、「群末の記録」の節の既定ビルドと公理監査の値は、この表の値に置き換わる。残る未了は `EffectSoundnessStatement`（群 K）である。

## RV-L70.b の処置

2026-11-06 08:50 頃開始、09:10 終了（外側の時間約20分。下の検査の待ちを含む）。独立レビュー RV-L70.b（条件付き可、重2・情報1）を、取りまとめの指示に従い指摘の箇所に限って処置した。上の節の表（結論・主な言明の結果・足した宣言・四分類・義務の判定・計画からのずれ）は、この処置の後の到達範囲に直した。

| 所見 | 処置 | 場所 |
|---|---|---|
| 重2（noLamNames の接続の範囲） | 名前だけを除いた閉じ方を、元の閉じ方が中を読むところまで同じ形で辿るようにした。At の呼出しの起点・パターン・入力の値と、実行時の閉包の本体（`Closure.ClosedNoLamNames` を足した）を辿る。型付けが閉性を与えるところは条件を置かず、その証拠を使う。実行時の閉包の捕捉値は `CaptureOk` の Ground の前提（既存の `CaptureOk.closed`）、入力の望遠鏡の整形式は `Tel.RuntimeShape.runtime_wf`、保持した要求（`checkedAt`・`checkedRequest`）は `groundVal` の前提（`groundVal_ground`、足した `CheckedWitness.request_closed`）から得る。型付けは局所参照を解決する前の計算に付くので、相互の定理を任意の解決 `resolveLocals ρ` の後の計算について示した（`*_resolved`）。At の許容の前提の関数の欄を通る帰納は、欄を `∀ b, bases = some b → …` の形の言明にして閉じた。任意の型が付いた閉包について `ClosureTy.closed_noLamNames` を、開始の入口として `StartCondition.of_typed_noLamNames`（`ClosureTy P B StoreTy.empty [] none q a e`・`q.ClosedNoLamNames 0`・保持値の適格性・`InitialPrepared` から開始の条件）を置いた。閉じない場合は残らない。到達先の対象健全性の全前提の証人の例（`R/MainTheorems.lean` の第三の例）は新しい入口を使う形にした | `R/StartLamNames.lean`、`R/MainTheorems.lean`、07-04 の主な定理の段落と表の行、本書の上の節 |
| 重1（案 D と S13） | 取りまとめの判断に従い、[effect-fix.md](effect-fix.md) を、案 D（`handled` から発行のラベルを除く）と、発行の適用をハンドラの探索から外す実行の規則の変更（`E_OpPrim` から pathBases を除く、`E_PathBasesApply` の `NoHandler` を除く、`step` の探索の前に発行へ進める）を合わせた形に書き直した。変える規則と定義の完全な形、進行・保存・実行関数の健全性の変える点、読者の見込み（`handled` の18ファイル、規則の読者、例 `primitive_pathBases` の置き換え、01-12・07-04 の写し）、S13 と効果の健全性を同時に満たす理由（二つの変更がそれぞれ型付けと実行の食い違いを一つずつ直す。2×2 の表）、案 A・発行の節を契約で断る案との比較、書ける形への影響を書き、Step の規則の変更と型付けの定義の変更を設計者の見直しの対象と明記した。群 B では規則と定義を変えていない | `l70/b/effect-fix.md` |
| 情報1 | 処置なし（移管済み）。効果の健全性の noLamNames 版の合成先を `StartCondition.of_typed_noLamNames` に改めた | effect-fix.md 第5節、本書の上の節 |

読者の照合（[readers.lean](readers.lean)、根に `StartCondition.of_typed_noLamNames` を、葉に新しい補題を加えた）で、`of_typed_noLamNames` の閉包（2503 定数）に `ClosureTy.closed_noLamNames`・`HasTypeCQ.closed_noLamNames_resolved`・`CaptureOk.closed`・`CheckedWitness.request_closed`・`groundVal_ground` があることを確かめた。後の三つは相互の定理の実行時の閉包と保持した要求の場合だけが使う。同じ相互の組の `DependentClosureTy.closed_noLamNames`・`AtCallAdmissible.closed_noLamNames_resolved` は閉包に名前として現れない。Lean は相互の構造的再帰の組を一つの補助の定義に翻訳し、組の各定理はその補助から取り出すので、組の内の呼出しは兄弟の定理の名前を経ない（readers.log、33,839 バイト、SHA-256 `8407064de8de4fcaf703e4e1b8df45cbfa53a4bf01d04bd6fb5ae73aed7f99be`）。

`required-names.json` に新しい宣言8件を加えた（57件）。`verify.py` は変えていない。

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 単独の検査 | `formal/` で `lake env lean -M 12288 <R/StartLamNames.lean>` | 0（途中の誤り2回は直した） | 1回約5秒、最大常駐量約1.9 GB | — |
| 既定ビルド | 錠の下で `formal/` から `lake build` | 0 | 約2分（錠の待ちを含む。1347 jobs） | build.log（45,353 バイト、SHA-256 `dc347da663565413b6c4d757fe1d1529563dd226af9cb1f3591266ed4eb6c11d`）。足したモジュールの警告なし |
| 公理監査 | 錠の下で `formal/` から `lake env lean -M 12288 <axioms.lean>` | 0 | 13秒 | axioms.log（304,637 バイト、SHA-256 `d51ae66b0ad09cc4033addf0e0c0272822f32a83035d77c525a54c82021b25f3`）。対象719件（足したモジュール397件、private 368件）、公理の組はなし162・propext 281・propext と Quot.sound 7・三公理269。許可した三公理の外の公理と sorryAx はない |
| 読者の照合 | 錠の下で `formal/` から `lake env lean -M 12288 <readers.lean>` | 0 | 数秒 | 上の段落 |
| 照合 | `python3 l70/b/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json) |

この節の後、「群末の記録」と「再開1」の節の既定ビルドと公理監査の値は、この表の値に置き換わる。残る未了は `EffectSoundnessStatement`（群 K）である。

## 群 B の作業末の work の検査（取りまとめ）

- 基準: `49f17471442229baf668e7b1f7b6dac8151c6dcf`（HEAD と一致）。作業木は RV-L70.b の処置（再開2）の後の未コミットの状態（worktree）。並行の群と錠で順番を取り、再レビュー（Lean を実行しない）と並行して実行した。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf`（`/usr/bin/time -l` で測定）。選ばれた検査は formal_build。
- 終了状態 0（selected checks passed）。外側の時間 876.03秒（09:11:27〜09:26:03）、最大常駐量 4,214,751,232 バイト。
- 生の記録は `<tmp>` に置いた（1,175 バイト、SHA-256 `3183c9fcc390b173bb6e26ffc839b965f63f473c8100a013dfcdc33d1a0714ba`）。
- 取りまとめが verify.py を再開2の記録の後に一度実行し、終了0であった。
- 計画からのずれ: なし。エフェクトの健全性（`EffectSoundnessStatement`）は未了のまま群 K へ渡す。
