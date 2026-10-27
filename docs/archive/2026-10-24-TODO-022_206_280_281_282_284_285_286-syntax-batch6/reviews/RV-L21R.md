# RV-L21R: 作業 L21R の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `045b0a22` を取り出した別の作業ディレクトリ（`<review>`）。差分の基準は `d1d706ea`。`formal/Benitoite/Interval/` の新しい六ファイル（CallReach.lean・CallTables.lean・BudgetCallReach.lean・CallReachSound.lean・CallReachIndependent.lean・CallReachWhole.lean）、SyntacticReachExamples.lean の追加例、`formal/Benitoite.lean` の import。設計書は 01-12 の区間解析の節（構文的な到達可能性、予算付きの局所走査の表、独立入力の振り分け表と保証）と 07-04。
- 照合した文書: reviews/RV-C3.md（中1・中2・軽1・軽3）、reviews/RV-C3-response.md、plan.md の「計画の変更（2026-10-26、RV-C3 を受けて）」の L21R の行、l21r/results.md（取りまとめのレビューを含む）、l21r/resume-axioms.lean・resume-axioms.log、l21r/resume-work.json・resume-work.log。比較のために読んだ既存の定義は SyntacticReach.lean（`concreteRule`・`syntacticReachChildren`・`concreteRule_known`・`target_concrete`）、BudgetAnalyze.lean（`expr` の call と match の場合、`arguments`、`resultArmList`）、BudgetRange.lean（`rangeStandardAt`・`rangeCall`・`rangeOrigin`・`rangeCall_agrees`）、BudgetRangeBorrow.lean（`rangeBorrowCheck`・`rangeBorrowValue`）、Range.lean（`rangeTables`・`rangeCallAt`）、Eval.lean（`rangeCallBinding`）、Environment.lean（`AbstractEnv`）、BudgetLocated.lean（`RootWarning`）、Sound.lean（`targetOperationAt`）、BudgetWhole.lean（`runBody`・`runEntries`・`entryEnv`・`bodyOutputs`）。
- 方法: 読み取り、`git diff`・`git show`・grep による照合だけで行った。`lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果、例の `#guard` の成否は、l21r/results.md、resume-work.json・resume-work.log、resume-axioms.log の記録に依った。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 0 |
| 軽 | 4 |

判定: 受け入れ。RV-C3 の中2 は、この変更で閉じてよい。ただし、軽1（案 (b) への切り替えの記録）は中2 を閉じる記録と同時に直す。

新しい公開の定理は空虚でも弱すぎもしない。`CallReach.Scope` の `allows` は、call では元の開始キーでの `rangeCallAt` の認定を gate の条件とし、未認定の call は自身・頭・全引数の全出現で `allows` を満たさない（`CallReach.unrecognized_call_excluded`）。認定の判定は、解析器の `BudgetScan.rangeCall`（`rangeCall_agrees` により完走時は `rangeCallAt`）と同じ関数・同じ二表・同じキーである。公開の入口の定理は、警告の所属以外の前提を持たず、任意の上限・初期消費・深さと、途中停止の場合を含む。独立入力の定理は保存された全ての入力を、全体の定理は `bodyOutputs` の全ての本体を覆う。既存の formal のファイルには削除行がなく、既存の定義・定理の言明・型は変わっていない。

さらに、`CallReach.expr` は call 以外の未知の形の内側も `outside` で除き、根では `RootWarning`（`targetOperationAt` が some）だけを認める。`target_concrete` により `targetOperationAt` が some の形は `concreteRule` が true なので、`allows` を満たす出現は、構文的な到達可能性にも属する。したがって、新しい定理だけで、C2 の水準（未知の形の内側は親の候補の外）に「認定した Range の call の引数は親の候補」を加えた範囲を保証する。01-12・07-04 の「既存の定理と合わせて」という説明は、二つの定理の連言として正しい。この含意そのものは Lean の補題になっていないが、説明は連言に依るので補題を要しない。

見つかったのは記録と設計書の写しの軽い食い違いだけである。

## 軽

### 軽1 案 (a) から案 (b) への切り替えとその理由が、計画・RV-C3 への対応・判断の記録にない（読めば確定）

- 場所: plan.md「計画の変更（2026-10-26、RV-C3 を受けて）」の L21R の行（394行）、reviews/RV-C3-response.md の中2 の行と「中2 の選択の理由」、decisions.md。記録があるのは l21r/results.md の「最初の起動の確認」と「取りまとめのレビュー（2026-10-26）」だけである。
- 問題:
  - plan.md と RV-C3-response.md は案 (a) を選び、案 (b) へ切り替える条件を「証明が見込みの2倍に収まらない」場合とする。実際の切り替えの理由は時間ではない。案 (a) では、`analyzeExpr_warning_syntactic_reach`・`analyzeBody_warning_syntactic_reach` の結論（`InSyntacticReach key (syntacticReachExpr source) warning` など）が抽象環境を引数に取らないため、環境と開始キーを加えると公開の定理の型が変わる（l21r/call-silent-probe.log）。取りまとめは局所記法で型の変化を隠す形を採らず、案 (b) へ切り替えた。この切り替えは計画が定めた条件の外にあるので、計画の変更として残す必要がある。
  - RV-C3 の中2 の修正案 (a) は「`WarningsInSyntacticReach` は env を量化しているので、…定義に置き換えられる」と書いた。この前提は共通の `analyze` の契約にだけ当てはまり、式と本体の入口の定理には当てはまらない。RV-C3-response の「(a) は公開の定理の言明の文字列と意味の両方を C2 の水準に保ち」という選択の理由は、この不正確な前提に依っている。
  - RV-C3-response は (b) の欠点を「構文的な到達可能性の定義と実際の解析の範囲の食い違いを残す」とする。この食い違いは残り、01-12 の 2261行（「この範囲だけでは未認定 call の内側を除外しない」）に明記された。案 (b) を採った場合の受け入れの根拠として、記録に残す価値がある。
- 修正案: plan.md の L21R の行の後に、案 (b) へ切り替えたこと、理由（案 (a) が式・本体の公開の定理の型を変えること、局所記法で隠す形は採らないこと）、判断者と日付を追記する。RV-C3-response.md の中2 の行に同じ旨を追記し、RV-C3 の (a) の前提が analyze の契約にだけ当てはまることを書く。D15 の追記（公開の入口の言明を保つ判断の範囲）に当たるなら、decisions.md にも一行を置く。
- 時期: RV-C3 の中2 を閉じる記録と同時（A16 の前）。

### 軽2 07-04 の独立入力の段落と対応表が、C3 の後の解析の振り分けに追いついていない（読めば確定）

- 場所: 07-04 の 353行（「呼び出しの頭・引数、要素、try のオペランドなどは宣言のフィールド順・列順にそれぞれ独立解析し」「整数以外の可能性が残る match の腕も番号だけを辿り、独立解析しない」）、441行の対応表（「親の整数の種類を認定できない腕は番号だけを辿る」）。
- 問題: RV-C3 の中1 (a)(b) と同じ食い違いである。今の `BudgetAnalysis.expr` は、`rangeCall` で認定した call の頭を `skipExpr` で占め、引数を `arguments` で親の環境・共有状態のまま解析する。独立入力にするのは未認定の call だけである。match では、照合値に正常値があれば整数の種類の判定より前に `rangeMatch` を試み、認定した Result の腕は `resultArmList` で全て解析する。L21R は 01-12 の 2393行（振り分け表の「未認定の call」の行）と 2402行（腕の段落）を直したが、07-04 の写しは直していない。A16〜A18 の依頼文が 07-04 を読むと、古い振り分けを写すおそれがある。
- 修正案: 07-04 の 353行の call を「未認定の call の頭・引数」に改め、認定した Range の call は引数を親で解析することを一文で加える。match の腕の記述を「整数とも Range の Result とも認定できない腕」に改める。441行も同じ語に揃える。
- 時期: A16 の前。

### 軽3 07-04 の対応表と 01-12「区間解析の検査全体の駆動」が、新しい保証を挙げていない（読めば確定）

- 場所: 07-04「01-12 との対応」の表の 440行・441行・443行。01-12「区間解析の検査全体の駆動」（2350〜2377行）。`formal/Benitoite/Interval/CallReachWhole.lean` の先頭の `//!` のコメント。
- 問題:
  - 440行は「同じ analyze について NormalSoundness・WarningSoundness・WarningLocated・WarningsInSyntacticReach を証明する」とし、`WarningsInCallReach` を挙げない。441行は `IndependentResult.Sound` だけを挙げ、`IndependentResult.CallsRecognized` を挙げない。
  - 443行は検査全体の駆動を「本体の主定理の外の実行定義と独立期待値」とする。L21R の前の BudgetWhole には警告の性質の定理がなく、`BudgetWhole.analyze_warning_call_reach` は全体の出力に対する初めての保証である。この行はそれを反映していない。
  - CallReachWhole.lean のコメントは根拠に 01-12「区間解析の検査全体の駆動」を挙げる。しかし、その節には CallReachWhole の説明がなく、説明は「区間解析の独立入力の保存と保証」の節（2461行）にある。
- 修正案: 07-04 の 440行・441行に、未認定の call の内側を除く別の保証（`WarningsInCallReach`・`CallsRecognized`）を一句ずつ加える。443行の第2列と第3列に `BudgetWhole.analyze_warning_call_reach` と、保存済みの出力だけを対象とする範囲を加える。01-12「区間解析の検査全体の駆動」の節には、保証の本文は独立入力の節（2461行）にあることを一文で示す。Lean のコメントを直すにはビルドが要るので、01-12 の側で参照を補う方が軽い。
- 時期: C3 の受け入れの記録と同時か、A16 の前。

### 軽4 新しい `maxHeartbeats` の指定が結果の記録にない（読めば確定）

- 場所: BudgetCallReach.lean の 332行 `set_option maxHeartbeats 800000 in`（`analysis_within_all`）。
- 問題: l21r/results.md と取りまとめのレビューは「新しい六モジュールに sorry・公理・`decide +kernel` はない」と書くが、この指定を記録していない。禁止の対象ではなく、値は Sound.lean の既存の一か所と同じである。それでも、後の改造で証明が重くなったときの手がかりとして、どこで上限を上げたかを残す価値がある。
- 修正案: results.md の取りまとめのレビューか C3 の受け入れの記録に、この指定の場所と値を一行残す。
- 時期: 任意（C3 の受け入れの記録と同時）。

## 確かめて問題がなかった観点

1. 定義（観点 1 の (i)）: `CallReach.exprTables` は、call では `gate (fun key => rangeCallBinding env ⟨source, .base .unit, key⟩ ≠ none) (root source ++ outside (surfacePreorder callee) ++ exprsTables env args)` である。gate は call の部分木の最も外側にあり、`append` が開始キーを左の列の長さだけ進めるので、条件は call 自身の開始キーで評価される。`outside` は番号を占めて警告を認めず、`empty` の述語は False である。未認定なら gate の第一の連言が偽になり、call 自身・頭・全引数のどの位置の警告も認めない。call 以外の形の `childrenTables` は `syntacticReachChildren` と同じ分岐（括弧・constE・return・not、`negModeled`・`binarySupported` による振り分け、短絡、match の照合値と腕、Block、if の三形、それ以外は `outside (surfacePreorder source).tail`）である。`exprTables_sources` などは、番号を占める列が元の先行順と一致することを示す。入れ子の call も、それぞれの開始キーで gate を持つ。
2. 認定の一致（観点 1 の (ii)）: `rangeCallAt env key source` は `rangeCallBinding (rangeTables env) ⟨source, .base .unit, key⟩` であり、`rangeTables env` は `⟨[], env.standards, env.apiAt⟩` である。`rangeCallBinding` は入力の型と局所値を見ない。したがって gate の条件は `rangeCallAt` と定義上一致し、`unrecognized_call_excluded` の証明 `h.1 unknown` もこれに依る。解析器は `identify` で得たキーで `BudgetScan.rangeCall env key source` を走り、`rangeCall_agrees` は完走時の結果が `rangeCallAt` であることを示す。解析中の環境は局所位置・Range の記録・`clearLocals`・忘却・条件と腕の環境操作で変わるが、CallTables.lean の補題（`tables_update`・`tables_clear`・`tables_forget`・`tables_bind`・`tables_pattern`・`tables_resultArm`・`tables_condition`・`tables_branch`・`tables_alternatives`・`tables_kindAlternatives`・`tables_arm` など）が二表の不変を示し、`within_expr_tables`・`within_block_tables` で入口の環境の述語へ戻している。予算の不足で `rangeCall` が止まれば解析も止まるので、認定の食い違いで親へ警告が入る経路はない。
3. 前提（観点 1 の (iii)）: `analyzeExpr_warning_call_reach`・`analyze_warning_call_reach`・`analyzeBody_warning_call_reach`・`analyzeExpr_independent_call_reach`・`analyzeBody_independent_call_reach`・`BudgetWhole.analyze_warning_call_reach` は、警告や入力の所属のほかに前提を持たない。Models・評価導出・完走・予算内・事前の健全性を要求しない。`analyzeExpr_unrecognized_call_warnings` の前提 `rangeCallAt … = none` は、SyntacticReachExamples の三つの負の例で満たされている。結論の `allows` は自明に真にならない（同じ例が否定を証明している）。
4. 予算と途中停止（観点 2）: `CallExclusion.Within` は `Spec` の追加警告の条件であり、成功と停止の両方を含む。`within_throw`・`within_scope` で深さの停止と枠の確保の拒否も扱う。`analyzeBody_warning_call_reach` は `analyzeBody_property` で入口の事前停止と忘却中の停止を空の追加分として扱う。`IndependentResult.CallsRecognized` は、忘却中の停止（`initial = none`）では警告列が空であることを、それ以外では記録した入口環境・`entry.key` での `allows` を要求する。`captureIndependent_saves` は、忘却中の停止で作る記録と、内部の解析の後の記録の両方に条件を与える。`analysis_savesInputs_all` は式・短絡・Block・種類付きの腕・引数列・Result の腕の六つで入れ子の追加分を合成し、`SavesInputs.all` で保存列の全要素へ渡す。全体では `runEntries_call_reach`・`runDefinition_call_reach`・`definitions_call_reach`・`modules_call_reach` が、全体の上限・入口・発見・待ち行列で止まった場合も、保存済みの出力だけを対象に条件を保つ。別本体の seed の環境は `entryEnv` を通した実際の入口環境であり、保証はその環境に相対的である。
5. 既存の定義・定理（観点 3）: `git diff --numstat d1d706ea 045b0a22 -- formal` で削除行は0行である。変わったのは `formal/Benitoite.lean` の import 6行と SyntacticReachExamples.lean の末尾 49行の追加だけで、`lakefile.toml` も変わらない。`concreteRule`・`syntacticReach*`・`InSyntacticReach`・`WarningsInSyntacticReach`・`IndependentResult.Sound`・中心二命題は基準のままである。resume-axioms.log の `#check` は、旧の構文的な到達可能性の三定理と独立入力の二定理の型が基準と同じことを示している（記録に依った）。
6. 証明の穴（観点 3）: 新しい六ファイルに `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def`・`opaque`・`decide` はない。`private` は `listExtension_false_eq` の一つだけである。`decide +kernel` は SyntacticReachExamples の追加例の2か所で、対象は一要素の標準表に対する `rangeCallAt … = none`・`≠ none` である。これは認定の関数の小さな計算であり、解析器や評価器を kernel で展開しない。解析器の実行は `#guard` に限られる。公理の依存が propext・Classical.choice・Quot.sound だけであること、既定ビルドと sorry 拒否が終了0であることは、resume-axioms.log と resume-work.json の記録に依った。
7. 設計書（観点 4）: 01-12・07-04 に加えた識別子（`CallReach.Scope`・`allows`・`append`・`outside`・`root`・`gate`・`CallReach.expr`・`block`・`exprs`・`armList`・`CallReach.input`・`CallReach.unrecognized_call_excluded`・`CallExclusion.expr_unrecognized_call_silent_at`・`CallExclusion.analysis_within_all`・`expr_warning_call_reach`・`block_warning_call_reach`・`analyzeExpr_warning_call_reach`・`analyze_warning_call_reach`・`analyzeBody_warning_call_reach`・`analyzeExpr_unrecognized_call_warnings`・`IndependentResult.CallsRecognized`・`CallExclusion.run_contract`・`CallExclusion.SavesInputs`・`analyzeExpr_independent_call_reach`・`analyzeBody_independent_call_reach`・`BudgetWhole.BodyOutput.CallsRecognized`・`runBody_call_reach`・`runEntries_call_reach`・`runDefinition_call_reach`・`definitions_call_reach`・`modules_call_reach`・`BudgetWhole.analyze_warning_call_reach`・`callKnown`・`rangeStandardAt`・`rangeBorrowCheck`・`rangeBorrowValue`・`rangeFixed`・`rangeCallOrigin`）は Lean に実在する。01-12 の 2261〜2265行の訂正（`concreteRule` の true の形に call を含めること、`concreteRule_known` の `callKnown` の前提、call の頭は false で引数は認定前の候補であること、構文だけの範囲は未認定 call の内側を除かないこと）は今の定義と一致する。2283行の `CallReach.expr` の説明と 2285〜2292行の表、2450〜2461行の独立入力と全体の説明も Lean と一致する。予算付きの局所走査の表の `rangeCall`・`rangeOrigin` の行（2119・2120行）の順序は、`rangeCall`（分類→`rangeStandardAt`→宣言と規則の照合→借用）、`rangeOrigin`（分類→`rangeBorrowCheck`→`rangeStandardAt`→下端・上端の `rangeFixed`）、`rangeBorrowCheck`（ラベルの長さ→引数の三個→契約位置の三個）、`rangeBorrowValue`（ラベルの長さ→契約位置の一個→引数の一個）と一致する（RV-C3 の軽3）。07-04 の 109行の追記は RV-C3 の軽1 の内容である。
8. 例（観点 5）: 追加例は、同じ call について標準表を空にした場合、出現表を空にした場合、開始キーを一つずらした場合の三つで `allows` が成り立たないことを証明する。認定する環境では、第一引数の除算（キー9）の警告が `allows` を満たすことを構成的に証明する。`#guard targets callWithDivision = [(9, some .intDiv)]` は、旧の構文だけの範囲には未認定でも引数が残ることを固定している。解析器の `#guard` は、未認定では親の警告が空で、頭（8）・除算の引数（9、警告9）・残りの引数（12・13）が独立入力になること、認定では親の警告が [9] で独立入力がないこと、外側を list にすると call 自身（7）も独立入力になり警告を持たないことを確かめる。成否は results.md の記録（call-examples-06 の終了0）と既定ビルドに依った。
9. 名前: `CallExclusion` の名前空間の `Within`・`analysis_walk`・`run_contract`・`SavesInputs`・`analysis_savesInputs`・`independent_saves` と、`BudgetWhole.analyze_warning_call_reach` は、既存の `BudgetAnalysis` の同名の宣言と短い名前が重なる。名前空間は分かれており、01-12・07-04 は新しい側を `CallExclusion.`・`BudgetWhole.` で修飾して書いているので、所見にはしない。後の文書で新しい側を引くときも修飾を保つとよい。

## 読めば確定する所見と、実行しないと分からない点

- 読めば確定: 軽1〜軽4。観点 1 の結論（未認定の call の内側の除外、認定の判定の一致、前提の充足可能性、`allows` から構文的な到達可能性への含意）は、定義の展開と `target_concrete`・`rangeCall_agrees` の言明から直接従う。
- 実行しないと分からない点: 既定ビルドの成功・sorry がないこと・公理の依存（resume-work.json・resume-work.log・resume-axioms.log の記録に依った）。追加例の `#guard` の値と `decide +kernel` の成否、例の検査のメモリと時間（results.md の call-examples-06 の記録に依った）。
