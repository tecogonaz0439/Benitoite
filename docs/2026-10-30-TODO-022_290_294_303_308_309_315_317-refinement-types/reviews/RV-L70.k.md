# RV-L70.k: L70 群 K（核の変更とエフェクトの健全性）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.k` のコミット `de7fbf28` で、基準 `dcaa396bad7a60d4da9b99d07ad9b75c0f328b07` からの差分（503ファイル。Lean と設計書は117ファイル、群 K の記録は386ファイル）を読んだ。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-k/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回であり、処置の確認は取りまとめが別に頼む。

読んだもの:

- 依頼文（初回と再開1〜4）と担当の報告（再開4）、[群 K の結果](../l70/k/results.md)の全節（特に「再開4」）。
- [変えた定義と規則の写し](../l70/k/resume4-definitions.md)、[前段の署名の差](../l70/k/resume4-signatures.md)、[範囲パラメータの核の案](../l70/k/range-kernel.md)、[C_Match の案](../l70/k/c-match.md)、群 B の [effect-fix.md](../l70/b/effect-fix.md) と [effect-counterexample.lean](../l70/b/effect-counterexample.lean)。
- 本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭から、2026-11-06 の群 B・C・D・K に関わる項目（範囲パラメータの核の拡張、`C_Match` の前提、RV-L70.b の重1への判断、K.1・再開1〜3の停止への判断）。
- [detail.md](../l70/detail.md) の第3節（F01〜F09）・第7節、R/MainStatements.lean の主な言明、l40・l50・l60 の stage-results.md の「後段へ渡す署名」。
- 核の7モジュール（Syntax・Typing・Semantics・HandlerContracts・SourceScope・ProgramTyping・Step）の差分の全体、新規7モジュール（RangeCode・RangeTyping・RangeTypeProperties・RangeSourceProperties・RangeFunctionExamples・MainEffects・EffectSoundnessExamples）、BuiltinEffects・LegacyHandlerEmbedding・ProgramExtensionTransport・TypingDeclared の差分、01-12・07-04 の差分。

したことは、基準と対象の全変更モジュールの宣言の頭部の機械的な比較（台本は `<tmp>/sigdiff.py`、結果は `<tmp>/sigdiff.tsv`。173件）、その結果と前段の stage-results.md の固定署名の照合、新規の公開の宣言の読者の数え上げ、禁止の語（`sorry`・`native_decide`・`#eval`・`axiom`・新しい `set_option`）の差分での検索、記録の大きさの集計、小さい Lean の確認（下の「実行した検査」）である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行した。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・記録を書き換える台本（`verify.py`・`resume4_tools.py` など）・git の書き込み操作は行っていない。群 K の担当の全環境の公理監査（89,970宣言）とビルドの成功は、記録を読んだだけで再実行していない。処理系（Rust）との照合、群 D の表層の追随、群 E は対象外である。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中2件、軽2件、情報6件である。**

主な言明は保たれている。`effect_soundness` は R/MainStatements.lean の `EffectSoundnessStatement` をそのまま証明し（同モジュールは基準から変わっていない）、前提は満たせ、群 B の反例は空の効果で断られる。発行はハンドラを素通りし、型付けでも実行でも U02 S13 を満たす。核の変更は、plan.md で承認された範囲パラメータ（案 A の `List RangeIx`）、`C_Match` の `Ty.Declared`、`handled` の発行の判定、`E_OpPrim`・`E_PathBasesApply` の変更に収まっており、範囲の外の型付け・Step の規則の変更、新しい公理、`sorry` は見つからなかった。群 C の三入口は独立の `ExhaustiveTransport` なしで閉じた。

条件は記録の二点である。前段の固定署名の差の表が、変わった固定署名の一部しか載せていない（中1）。範囲文脈の判断を全具体化の量化で定義したことで、範囲の置換の保存の実質が群 D の性質1へ移ったが、その受け口と見込みがどこにも書かれていない（中2）。どちらも Lean の変更を要しない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | C/l70/k/results.md「前段の署名の差」の三表と resume4-signatures.md | 差の表は7行だが、前段の stage-results.md で後段へ渡した署名のうち、少なくとも次の13件も変わっている。L40 の `IntervalConnection.H04.FirstFailureHandoff`・`pure_failure`・`IntervalControlLeaves.typed_first_failure`、L50 の `ScopedTargetInputs.response_inputs`・`pure_steps`・`io_steps`・`handled_step`・`path_bases_apply`・`StateTyE.primitive_contract_inputs`・`StateTyE.selected_primitive_step`・`StoreReplyInputs` の構成子、L40 の結果に名前のある `HasTypeVQ.inv_prim`。ほかに、表に載せた `S02Internal.case_C_Match` と同じ種類の `S02Internal.case_V_Fun`、群 C の `Def.WellTyped.ofExtends`・`ImplDecl.WellTyped.ofExtends`（`hex` を `hwf` に替えた）、除いた `Builtins.CoreAssumptions.pathBases_not_handled`（より強い `pathBases_never_handled` に置き換えた）も表にない。内容はどれも承認の範囲に収まる。多くは view の `rs` を `List.map RangeIx.fixed rs` に替えただけである。`handled_step`・`StateTyE.operation_primitive`・`step_prim_handler_selected` は承認済みの `E_OpPrim` の変更に従って種類の選言から `.pathBases` を除いた。`path_bases_apply` などは `NoHandler` を除いた（前提が減り強くなる）。しかし再開2の判断は「一件ずつ results.md の差の表に記して進め」と定めている。results.md は「計画との差」で一括して述べるだけで、表が全てを覆うという報告と食い違う | 上の名前を差の表に足す。行が多いので、種類ごとの副表（構成子の欄の像を明示しただけのもの／承認済みの規則の変更の直接の反映／群 C の内部の前提の差し替え／置き換えた宣言）に分け、各行に元・新・理由・元の形に戻る場合を書く。台本で全件を出すなら、基準と対象の宣言の頭部を比べた一覧を改造に置き、表はその要約にする | 高（差分を読めば確定する） |
| 中2 | 中 | R/RangeTyping.lean の `HasTypeVQR` ほか14判断と `TelBodyTyR`、ProgramTyping.lean の `Def.WellTyped`、07-04 の `RangeCode`・`RangeTyping` の段落と表の行、C/l70/k/range-kernel.md 第1節・第3節 | 範囲文脈 `ks` の下の判断は「`RangesFit rs ks` を満たす全ての閉じた `rs` で具体化した通常の判断」と定義されており、`instR` の各定理は `h rs hr` で終わる。閉じた判断の `V_Fun`・`V_Prim` は `rs.map RangeIx.fixed` の項しか型付けない。このため、範囲変数のまま本体を型付けてから具体化する置換の保存の補題は、核には無く、要らない。range-kernel.md が見込んだ「14判断の相互帰納による同じ形の補題」の実質は、群 D の性質1へ移る。性質1は、表層で開いた本体を一度検査した導出から、全ての適格な具体化について核の `TelBodyTy` を作らなければならない（表層側の範囲の置換か、脱糖と `instR` の可換と核側の置換）。この受け口も、群 D の見込みへの影響も、results.md・range-kernel.md の申し送り・detail.md のどこにも書かれていない。07-04 の「十四判断と四名前空間の保存」は、定義から直ちに出る保存を、実質のある補題と読ませる | results.md「再開4」と群 D への申し送り（range-kernel.md 第3節）に、核の範囲文脈が具体化の量化であることと、性質1が負う補題の署名の案を書く。署名の案は、表層の導出と `RangesFit rs ks` から `TelBodyTy … (rangeTel rs t) ((desugar body).instR rs)` を得る形である。群 D の見込みもこの分だけ改める。07-04 は「十四判断は全具体化の量化で定め、その保存は定義から従う」と書き分ける | 高（定義を読めば確定する）。群 D での補題の大きさは未確認 |
| 軽1 | 軽 | R/RangeCode.lean:285 の `Def.instTel_of_ne_nil` | 既定ビルドの中に読者がない。依頼文の「読者のない補題を残さない」に当たる | 削除するか、`Def.instTel` の非空の枝を読む箇所で使う | 高 |
| 軽2 | 軽 | 07-04 のモジュールの表の `MainProgress・…・MainEffects・EffectSoundnessExamples` の行 | 加えた二つのモジュールの役割（エフェクトの健全性と、その拒否と受理の証人）が説明の文にない | 行の説明に「エフェクトの健全性とその前提を満たす証人」を足す | 高 |
| 情報1 | 情報 | R/EffectSoundnessExamples.lean | `effect_soundness` を空の効果の入力へ適用した証人は、開始自体が終端の単位値（`unit_noLamNames_witness`）だけである。担当はこれを「自明」と正しく分類した。前提が満たせることは、この証人と `StandardModel.statement_premises` で分かる。拒否の側（`empty_typing_rejected`・`handled_environment_rejected`）と、空でない効果での受理（`environment_witness`・`handler_bypass_witness`）は意味を持つ。一方、空の効果で型が付き、ハンドラの下で実際に何段か進む入力の証人はない。例えば、利用者の操作を全て処理する `handle` で、`E_Op` を経て値へ戻る入力である | 言明の健全性には影響しない。群 E の表層の主定理（L70.34）の受理の証人で、空の効果の実行が進む例を置くとよい | 高 |
| 情報2 | 情報 | R/Typing.lean の `HasTypeClausesQ.cons`、R/OperationStateExamples.lean の `primitive_pathBases` | 核は、発行専用の組込みに対する節を型付けで受け付ける。その節は実行で選ばれず（`E_OpPrim` は IO と終了だけ）、処理済みの効果からも除かれる（`pathBases_never_handled`）ので、S13 と健全性は保たれる。ただし利用者から見ると、書いても効かない節である | 表層（群 D）か診断（R60）で、発行の組込みを処理する節を断るか警告するかを申し送る。核は今の形でよい | 高 |
| 情報3 | 情報 | R/LegacyHandlerEmbedding.lean の `legacy_handled_sub`・`LegacyCompCases.handle_case` | 足した前提 `LegacyClausesInput` は、再開3の条件(ii)が挙げる種類（範囲の具体化の量化・範囲の深さ・構成子の欄・宣言の前提）の字面には当たらない。旧の節の操作署名の存在という、旧導出が元から持つ入力である。公開の入口の `embedHasTypeCQ`・`LegacyRule.embed_comp` の頭部は基準と同じであることを機械的な比較で確かめた。新しい信頼条件は増えていない | 条件(ii)をこの形まで含めて読むかを、設計者の署名の見直しで確かめる | 高 |
| 情報4 | 情報 | R/Typing.lean の `C_Match`、R/TypingDeclared.lean、R/PrimitiveScoped.lean | `Ty.Declared` の前提が書ける match を減らすのは、照合する値の型が宣言されていない場合だけである。`HasTypeVQ.declared` は宣言済みの文脈から値の型の宣言を返す。組込みの節の文脈は `B.sig` から作るが、`PrimSig.Scoped.declared` が署名の宣言を要求する。したがって、署名が Scoped な表（Model・合成表）の下の利用者のプログラムでは、前提を導出から供給できる。処理系の照合の型の解決との一致は確かめていない（R10b） | なし（判断の材料） | 中（Lean 側は読んで確定。処理系側は未確認） |
| 情報5 | 情報 | R/RangeFunctionExamples.lean | 本体で範囲変数を組込みへ渡す実例は path の `reader` だけである。host・endpoint は恒等の本体だけで、範囲変数を同じ種類の組込みへ渡す本体はない。別の範囲パラメータの関数を本体の中から `.rvar` で呼ぶ形は、値の判断 `reader_open_reference` だけにあり、定義の `Def.WellTyped` の例はない。K.1 の停止の動機はこの後者の形である | 群 D の表層の範囲パラメータの規則（S9・R4）の受理の例に、関数から関数へ範囲変数を渡す定義を含める | 高 |
| 情報6 | 情報 | C/l70/k/（386ファイル、2,117,955バイト） | 各ファイルは100KB以下で、決まりは守っている。ただし L70 の他の群の記録（58〜237KB）に比べて桁が大きい。全体の半分（1,070,788バイト、290ファイル）は `resume2-candidate/`・`resume3-candidate/`・`resume4-candidate/` の patch で、コミット `de7fbf28` の差分と重なるか、取り消された候補である | 下の「7. 記録の大きさ」の案のとおり分ける | 高 |

## 観点ごとの根拠

### 1. エフェクトの健全性

`effect_soundness (P B σ) : EffectSoundnessStatement P B σ` は、R/MainEffects.lean にある。R/MainStatements.lean は基準から変わっていない（差分0行）。言明が読む `UnhandledOp`・`NoHandler`・`State.Final` の定義も変わっていない（R/Semantics.lean の差分は `Step` の構成子だけである）。`example : ∀ P B σ, EffectSoundnessStatement P B σ := effect_soundness` が型検査を通ることも確かめた。

証明の構成は次のとおりである。`initial_typing` で開始の状態の末尾を空の効果に固定し、`steps_preserved` で到達した状態の型を得て、`StateTyE.no_event` と `StateTyE.no_unhandledOp` を当てる。

- `no_event` は事象を出す規則の全ての場合を分ける。IO・IO の失敗・終了の三つは `NoHandler` と `operation_not_handled` から効果名を末尾へ移す。解放の8規則は継続の解放枠の条件を使う。`E_IssuePathBases` は、閉包の効果が発行の効果を覆うこと（`ClosureTy.issue_path_bases_effect`）と、どの節の下でも発行の効果が残ること（`pathBases_never_handled`）を使う。末尾が空なので、どの場合も矛盾になる。
- `no_unhandledOp` は進行から導く。処理する枠のない操作の呼出しは、終端でなく遷移も持たない（`UnhandledOp.not_final`・`not_step`）。進行の前提 `BuiltinOnly P B Eb` は空の効果で満たされる。

`effect_soundness_noLamNames` は、同じ型付きの閉包について、`StartCondition.of_typed_noLamNames` で開始の条件を作るだけである。ラムダ名の整形式を独立の信頼条件にしていない。

前提は満たせる。`unit_noLamNames_witness` は実表 `Model.builtins` と宣言のないプログラムで、整形式・型付け・効果の検査・`CoreAssumptions`・開始の条件を全て構成している。合成表の側も `StandardModel.statement_premises` がある。受理の側の証人が自明に留まる点は情報1に記した。

群 B の反例（effect-counterexample.lean）と同じプログラム・節・本体・開始・σ を EffectSoundnessExamples.lean が使う。`handled_environment_rejected` は、Process.Environment の唯一の組込み（発行）を処理する節があっても、その名前が処理済みに入らないことを直接示す。`empty_typing_rejected` は、空の効果の型付けがあれば `effect_soundness` と実際の発行の遷移が矛盾することから導く。前者が型付けの規則そのものの拒否であり、後者はその帰結である。`environment_witness` は同じ入力に Process.Environment の効果で型を付け、二段の到達・発行の遷移・発行後の型付きの状態を構成する。両側とも意味を持つ。

U02 S13（発行はハンドラで差し替えられない）は、型付けと実行の両方で満たされる。型付けでは `handled` が `issuesSelected P B l` の名前を処理済みから除く。実行では、`E_OpPrim` の種類の前提が `.io ∨ .exit` に限られ、`E_PathBasesApply` は `NoHandler` を要求しない。`stepRun` も `.pathBases` の枝を `splitHandler` の外へ出した。二つの規則は重ならない。`handler_bypass_witness` は、発行の組込みを処理する節（`handles … = true`）を持つ型付きの状態から、節へ移らずに適用と発行が起き、中間と行先の状態にも型が付くことを示す。

### 2. 核の規則の変更と承認の範囲

resume4-definitions.md の写しと本番の Lean を、`V_Fun`・`V_Prim`・`C_Match`・`handled`・`E_Fun`・`E_PathBasesApply`・`E_OpPrim`・`stepRun` の分岐について照合し、一致を確かめた。基準からの規則の差は次の四つに限られる。

1. 範囲パラメータ（設計者の決定と K.1 の判断の案 A）。`Def.rkinds`（既定値 `[]`）を末尾の欄に加え、`Val.fnRef` に `rs : List RangeIx := []` を足し、`Val.prim` の範囲引数を `List RangeIx` に替えた。`V_Fun`・`V_Prim` と、範囲引数を持つ全ての Step の規則は `rs.map RangeIx.fixed` を読む。`E_Fun` は `(d.body.instR rs).substTy ts es` へ進み、`stepRun` は `closedRanges` が成功したときだけ適用する。`Def.WellTyped` は `Ty.AnnotationR` と `TelBodyTyR` を読み、`rkinds = []` では元の二条件と同値である（`Ty.annotationR_nil`・`telBodyTyR_nil`）。
2. `C_Match` の前提 `Ty.Declared P C Γ a`（設計者の決定）。位置は c-match.md の案のとおり、網羅性の直前である。`K_Guard` は変わっていない。
3. `handled` の発行の判定（再開1の判断）。`(o::os).all (handles h) && !issuesSelected P B l` とし、`issuesSelected` は利用者の一覧を選んだ名前では偽、そうでなければ `B.issuesIn l` である。`handledSelected` は `handled` の別名（`abbrev`）である。`handledSelected_eq_d` は `P.EffectsOk B` の下で案 D の式との等号を示し、公理依存は `propext`・`Quot.sound` だけである。
4. 発行の実行の規則（RV-L70.b の重1への判断）。`E_PathBasesApply` から `NoHandler` を除き、`E_OpPrim` から `.pathBases` を除いた。`stepRun` は `.pathBases` の場合に、型・行・範囲・実引数が空であることだけを見て発行の計算へ進む。

書ける形を狭める変更は見つからなかった。

- `handled` の変更で新たに断られるのは、発行の組込みを持つ名前を「全操作の処理」で効果から除いていた形だけである。以前その名前を除くには、発行の組込みへの節も要り、その節が `E_OpPrim` で発行を差し替えていた（S13 に反する形）。Model・ModelTargets・ModelHttpConditions・ScopeSignatures の表では、Process.Environment の一覧は発行の組込み一つだけである（合成表の一覧の中身は確かめていない）。
- `C_Match` については情報4に記した。
- 範囲パラメータは既定値 `[]` で、範囲パラメータのない定義と参照の意味を保つ。三引数の `.fnRef f ts es` が `.fnRef f ts es []` と定義から等しいことを確かめた。三引数の照合の残りは、R の外の旧 Release・Core の別の型か、範囲が空の場合に限った補題である（例: `HasTypeVQ.fun_empty`・`gate_fun_case`）。一般の場合を扱う `case_V_Fun` などは範囲引数を量化している。

### 3. 前段の固定署名の差

基準と対象の変更モジュールの全ての `theorem`・`def`・`abbrev`・`structure`・`inductive` の頭部を機械的に比べた（`<tmp>/sigdiff.tsv`）。変わった宣言を、l40・l50・l60 の stage-results.md の名前と照らした結果が中1である。

表の7行は、それぞれ三条件を満たすと判断した。

- `Def.WellTyped.inputs`: 新しい核では元の形が偽になる（`DefinitionInputsResumeTrial.old_inputs_statement_false`、再開3の判断で承認済み）。新しい形は具体化の量化を足すだけで、`inputs_no_ranges` が `rkinds = []` で元の形を返す。
- `HasTypeVQ.canonical_function`: 構成子の欄を存在量化へ足すだけである（再開2の判断）。`canonical_function_no_ranges` が空の範囲引数で元の字面を返す。
- `HasTypeCQ.match_legacy`・`S02Internal.case_C_Match`: `C_Match` の前提の宣言を足すだけである。旧導出の側は `LegacyCompCases.match_case`・`match_type_subst` が元の旧入力から宣言を供給する。
- `Program.ExtendsTypingStatement`: 使わない `Ctx.Declared` を除いた。初回の依頼文が許す「使わない前提の削除」に当たり、言明は強くなる。`extends_typing_declared_context` が元の二入口を返す。
- `legacy_handled_sub`・`LegacyCompCases.handle_case`: 前提 `LegacyClausesInput` の追加である。条件(ii)の読み方は情報3に記した。公開の旧埋め込みの入口の頭部は基準と同じである。

表にない変更（中1）も、内容は承認の範囲の中にある。構成子の欄の像（`List.map RangeIx.fixed`）を view に明示しただけのものが大半である。そのほかは承認済みの規則の変更の直接の反映か、群 C の内部の前提を `P.WellFormed` へ差し替えたものである。差し替えは c-match.md 第2節の表のとおりである。結論を弱めて黙って変えた公開の言明は見つからなかった。

### 4. 範囲パラメータ

path・host・endpoint の利用者の関数が実際に型付く。`reader_wellTyped` は、種類 path の範囲パラメータを持ち、本体で `File.readTextIn` へ `.rvar 0` を渡す定義の `Def.WellTyped` である。`target_wellTyped k` は三種類の全てについて恒等の定義の `Def.WellTyped` である。`reader_root_call`・`target_call_top` は具体の範囲での呼出しの型付けである。`target_host_reference` は host の非 Top の条件を渡す参照の型付けである。実例の偏りは情報5に記した。

範囲の置換の保存は14判断の全てで閉じている。ただしそれは、判断を全具体化の量化で定義したからである（中2）。13の `…R` と `TelBodyTyR` の各 `instR` は定義の展開であり、`TelBodyTyR.instR` だけが空の種類列の場合を分けている。

Step の `fnRef` の適用で範囲も具体化される。`Step program builtins σ (.run (Closure.pure (.app (.fnRef "reader" [] [] [.fixed .top]) [.const .unit])) k μ) none (.run (Closure.mk … ((readerDef.body.instR [.top]).substTy [] [])) (markPush k) μ)` を `.E_Fun` で構成して確かめた（`<tmp>/check1.lean`）。保存では `V_Fun` の `Def.RangeAdmissible d rs` と `TelBodyTyR.instR` から具体化した本体の型を得る。

### 5. 群 C の移送

`Program.ExhaustiveTransport` と、それを読む三つの `_of_exhaustive` の定理は削除され、`formal/Benitoite` の中に名前が残っていない。`Program.extends_typing : P.ExtendsTypingStatement P' B`・`Program.extends_declaration`・`Program.compose : P.ComposeStatement P' B` は、追加の網羅性の前提を持たない形で型検査を通り、公理依存は三公理だけである。14判断の移送は `C_Match` の宣言から `Program.extends_exhaustive` を当てる形になっている。

### 6. 守ること

- 差分の追加行に `sorry`・`admit`・`native_decide`・`#eval`・`axiom`・`set_option` はない。既存の `set_option` の行は基準と同じである。
- 追加した `private` の宣言（48行）は、どれも同じファイルの中に読者がある。読者のない公開の宣言は `Def.instTel_of_ne_nil` だけである（軽1）。ほかに読者の数が1の宣言は、証人・例と、言明の証明（`Program.extends_declaration`）である。
- 公理依存は、確かめた11宣言の全てで `propext`・`Classical.choice`・`Quot.sound` の範囲に収まる（下の「実行した検査」）。
- 01-12 の差分は第3部の Lean の写しの節（3,100行以降）と、追加の ```` ```lean ```` 4ブロックに限られ、```` ```text ```` のブロックは変わっていない。写しの `V_Fun`・`V_Prim`・`E_Fun`・`handled` などは本番と同じ字面である。規範の部分（3,100行より前）と 01-07 には、発行をハンドラが処理するという記述はない。07-04 の差分は形式化のモジュールの説明と表に限られる（軽2・中2の文言を除いて、本番と食い違う記述は見つからなかった）。
- Surface・旧 Release・MainStatements は基準と同じである（差分0行）。
- 群 K の記録に、手元の絶対パス・`work/`・docs/todo への参照はない。

### 7. 記録の大きさ

C/l70/k/ は386ファイル、2,117,955バイトである。各ファイルは100KB以下である（最大は resume4-definitions.md の96,998バイト、results.md の80,525バイト）。内訳と処置の案は次のとおりである。

| 分類 | ファイル | 大きさ | 案 |
|---|---|---:|---|
| 残す: 結論と判断の根拠 | results.md、resume4-definitions.md、resume4-signatures.md、range-kernel.md、c-match.md、resume3-obstruction.md、resume2・resume3-definition-candidates.md | 約0.28MB | 残す。中1の副表は results.md か新しい小さい表に足す |
| 残す: plan.md の判断が引く試行 | range-trial.lean、range-resume-trial.lean、effect-trial.lean、match-trial.lean、legacy-resume-trial.lean、canonical-resume-trial.lean、definition-inputs-resume-trial.lean、axioms.lean | 約0.1MB | 残す（停止の反例と判断の根拠） |
| 残す: 最終の要約 | l70k-r4-final-build.json、l70k-r4-final-axioms.json、resume4-verification.json、audit-summary.json | 小 | 残す |
| 除く: コミットと重なる patch | resume4-candidate/（117ファイル、529,104バイト）と resume4-candidate.json | 約0.55MB | 除く。全差分はコミット `de7fbf28` の `git diff dcaa396b` で再構成できる。results.md に「全差分はコミットの差分を正とする」と、patch の束の SHA-256 と大きさだけを残す。verify の再構成の段も除くか、git の差分を読む形に改める |
| 除く: 取り消した候補 | resume2-candidate/（81ファイル、241,118バイト）、resume3-candidate/（92ファイル、300,566バイト）と各 json | 約0.55MB | 除く。停止の判断に要る差は resume*-definition-candidates.md と試行の .lean にある。束の SHA-256 と大きさだけを残す |
| 除く: 途中の状態 | resume*-start-*.json、resume*-restored.json（計287,641バイト）、l70k-r4-b1〜b30-build.json（30ファイル、計17,451バイト）、各再開の checks.json・audit-summary.json | 約0.35MB | 最終と停止の時点のものだけを残し、途中のものは除く。ビルドの30件は単位末の4件（b12・b21・b27・b30）に絞る |
| 台本 | verify*.py・run_*checks.py・replay_resume3.py・resume4_tools.py ほか | 約0.06MB | 残す記録を作り直す台本だけを残す。除いた記録だけを読む台本は除く |

この案で群 K の記録は約0.5MB になり、L70 の他の群と同じ桁に収まる。どの記録を除いても、plan.md と results.md が引く根拠は残る。除く前に、残すファイルから除くファイルへの参照を `git grep` で探して直す（results.md の276行・398行と resume3-obstruction.md の44行が `resume2-candidate/`・`resume3-candidate/` を名指ししている）。

## 実行した検査

全て `<repo>/formal/` から実行した。Lean は同時に一つだけ実行した。

| 検査 | 結果 |
|---|---|
| `python3 <tmp>/sigdiff.py`（基準と HEAD の変更モジュールの宣言の頭部を比べる。読むだけ） | 終了0。173行。変更の分類は中1の根拠 |
| `lake env lean -M 12288 <tmp>/check1.lean`（1回目・2回目） | 終了1。`.E_Fun` の例で、引数の `v` を変数のまま置いたため view が `rfl` で簡約されず失敗した（確認の入力の誤り）。ほかの検査は通った |
| `lake env lean -M 12288 <tmp>/check1.lean`（3回目。実引数を `.const .unit` に替え、`P.defs` の照合を `simp [program]` にした） | 終了0、約3.5秒。(1) `effect_soundness` が `∀ P B σ, EffectSoundnessStatement P B σ` を持つ。(2) 三引数の `.fnRef` が空の範囲列と定義から等しい。(3) 範囲引数を持つ `fnRef` の適用が本体を `instR` で具体化する `Step` を構成した。(4) `#print axioms` は `effect_soundness`・`effect_soundness_noLamNames`・`EffectSoundnessExamples.environment_witness`・`handler_bypass_witness`・`RangeFunctionExamples.reader_wellTyped`・`target_wellTyped`・`Program.extends_typing`・`extends_declaration`・`compose`・`Builtins.CoreAssumptions.pathBases_never_handled` が `propext`・`Classical.choice`・`Quot.sound`、`handledSelected_eq_d` が `propext`・`Quot.sound`。(5) `#check` で群 C の三入口と `handledSelected_eq_d` の言明を読んだ |
| `git diff dcaa396b -- formal` の追加行の禁止の語の検索 | 該当なし |
| 新規の公開の宣言の読者の数え上げ（`grep -w`） | 読者のない補題は `Def.instTel_of_ne_nil` だけ（軽1） |
| 記録の大きさの集計（`find … -exec cat {} + \| wc -c`） | 群 K は2,117,955バイト。patch の三つの束は計1,070,788バイト |

`lake build`・cargo・`scripts/check.sh`・記録を書き換える台本は実行していない。

## Opus による処置の確認（2026-11-06）

対象は処置のコミット `6c100e89`（前は `de7fbf28`）である。担当の報告（再開5）、[群 K の結果](../l70/k/results.md)の「再開5」、[署名の副表](../l70/k/resume4-signatures.md)、[削除の台帳](../l70/k/removed-records.json)、range-kernel.md・c-match.md・resume2/3 の定義の候補・resume3-obstruction.md の差分、07-04 と R/RangeCode.lean の差分、残した台本（verify.py・signatures.py・evidence.py・run_final.py・definitions_resume4.py）を読んだ。Lean は `<repo>/formal/` から `lake env lean -M 12288 <tmp>/check2.lean` を一回だけ実行した（終了0、約2.7秒、`-o` なし）。`lake build`・cargo・`scripts/check.sh`・記録を書き換える台本・git の書き込み操作は行っていない。

### 結論

**可。** 中1・中2・軽1・軽2・情報6は処置済みである。処置は Lean の言明・定義を変えていない（Lean の差分は `Def.instTel_of_ne_nil` の3行の削除だけ）。残った所見は軽1件である。

| 所見 | 確認の結果 |
|---|---|
| 中1 | 済み。副表は A〜G の160行で、節ごとの行数は表の件数（106・12・3・3・14・21・1）と一致する。本レビューが名指した13件、`case_V_Fun`・二つの `.ofExtends`・`pathBases_not_handled` は全て行がある。各行に元・新・条件・範囲なしの系がある。本レビューの比較の173行との対応と、差と誤って数えた7件の帰属も末尾にある。results.md「再開5」は名指しの宣言を種類ごとの表で補っている。`LegacyClausesInput` を(ii)に含める扱いは plan.md の 2026-11-06 の取りまとめの判断(3)と一致する |
| 中2 | 済み。results.md に、十四判断が全適格具体化の量化であり `instR` の保存は定義から従うこと、実質は群 D の性質1が負うこと、受け口の言明の案、証明の案と代案、見込み（最初の確認30〜60分、全体は不明）がある。受け口の案の `TelBodyTy P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTel rs t) (… .instR rs)` は、本番の `TelBodyTyR.instR` の結論の形と引数の並びに一致する（`#check` で確かめた）。range-kernel.md は第1・2節を実装前の案と区別し、第3節から受け口へ参照する。07-04 の本文と表は「定義から従う具体化の保存」と書き分けた |
| 軽1 | 済み。宣言は環境にない（`env.contains` が偽）。定義の写し（resume4-definitions.md）からも同じ3行を除いた。01-12 には元から写しがない。残る名前は取り消した候補の記録と verify.py の照合だけである |
| 軽2 | 済み。07-04 の表の行に MainEffects と EffectSoundnessExamples の役割を足した |
| 情報6 | 済み。351ファイル・1,673,888バイトを除き、残りは42ファイル、各100KB以下である。台帳は全ファイルの名前・大きさ・SHA-256と束ごとの SHA-256 を持つ。残した md から除いたファイルへの参照は、results.md の再開4までの当時の記録（節の冒頭で当時の記録と断っている）と resume3-obstruction.md の「当時の台本は除いた」という記述だけである。停止の判断の根拠（定義の候補・反例・試行の .lean）は残っている。残した台本は除いたファイルを読まず、除いた内容の照合は固定コミットから `git show` で読む |

### 残った所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 確1 | 軽 | resume4-signatures.md の A の `Ty.Declared.rawMapRanges`・`Tel.Declared.rawMapRanges`・`Ty.Sorted.rawMapRanges`・`Tel.Sorted.rawMapRanges`・`Ty.HasKind.rawMapRanges` の5行 | 新しい側を「宣言なし」とし、理由を「旧閉範囲列は fixed の像で読む」としている。実際は5件とも新規モジュール RangeTypeProperties へ移っただけで、言明は基準と同じである（`#check` とモジュールの所属で確かめた）。signatures.py が新規モジュールを比較から除くため、移動が削除に見えた。160件のうち5件は署名の差ではない | 5行を「RangeTypeProperties へ移した。言明は同じ」に改め、件数を差155件と移動5件に分ける。台本で新規モジュールへ移った同名の宣言を照合する。急がないので、次に記録を触るときでよい | 高 |

### 実行した検査

| 検査 | 結果 |
|---|---|
| `lake env lean -M 12288 <tmp>/check2.lean` | 終了0、約2.7秒。`effect_soundness` が `∀ P B σ, EffectSoundnessStatement P B σ` を持ち、公理依存は `propext`・`Classical.choice`・`Quot.sound`。`TelBodyTyR.instR` の言明を読んだ。`Def.instTel_of_ne_nil` は環境にない。`Ty.Declared.rawMapRanges` などは RangeTypeProperties にあり、言明は基準と同じ |
| 副表の節ごとの行数と名指しの宣言の `grep` | 件数の表と一致。名指しの宣言は全て行がある |
| 残した記録から台帳の名前への参照の検索（読むだけの Python） | 上の情報6の行のとおり |
| 群 K の記録と 07-04 の追加行の、手元の絶対パス・`work/`・docs/todo へのリンクの検索 | 該当なし（verify.py の検査の正規表現だけ） |

## 取りまとめの追記

2026-11-06。群 K は Codex が実装し、本レビューと処置の確認は Claude（Opus 5.5）が行った。処置の確認の結論は可である。確1（`*.rawMapRanges` の5件は言明を変えずに RangeTypeProperties へ移っただけで、署名の差ではない）は記録の分類の誤りであり、署名の差は実質155件と読む。Lean と設計書は直さない。情報1〜5の扱いは plan.md の取りまとめの判断に記した（情報3は設計者の見直しの対象）。work の検査は、群 D までの san_benito へ群 K を取り込んで表層を追随させた結合の枝 `m014/l70.k-int` で取りまとめが行った（`C/l70/k-int/results.md`）。
