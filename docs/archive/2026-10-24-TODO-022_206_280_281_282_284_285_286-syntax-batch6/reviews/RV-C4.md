# RV-C4: 区切り C4 の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `39768486` を detach で取り出した別の作業ディレクトリ（`<review>`）。`formal/Benitoite/Interval/` の全64ファイル、`formal/Benitoite.lean`、`formal/lakefile.toml`。設計書は 01-12 の区間解析の節と 07-04。差分の基準は `be57d4e9`（C3 と A16〜A18 の後）。範囲は L22（`6e47419f`）・L23（`19a200f1`）・L24 の停止の記録と計画の変更（`c6d2eeea`）・L24（`72105b49`）・L25（`39768486`）。
- 照合した文書: plan.md の「前提と依存」、「受け渡す契約」（「評価と中心定理」「標準呼び出し」「HTTPの欄」「予算」「警告」の行）、「Surfaceの全構成子の分類」、「全L作業の停止条件」、作業 L22〜L25、作業群 A19〜A21 の節と枝の表、X03 と「X03cで固定する案IIIの比較範囲」、「計画の変更（2026-10-26、RV-C3 を受けて）」と「計画の変更（2026-10-26、L24 の停止を受けて）」。decisions.md の D4・D15（2026-10-26 の二つの追記を含む）・D16（追記を含む）・D18・D19・D20。README.md の Q2（A1）。reviews/RV-C3.md・RV-C3-response.md・RV-L21R.md。l22・l23・l25 の results.md、l24 の results.md（再開分と「最初の起動の確認」）、l24/contract-obstruction.lean、l24/restart/audit.json・reference-impact.json・axioms-final.log。
- 方法: 読み取り、`git diff`・`git show`・grep・Python による照合だけで行った。基準と HEAD の `formal/Benitoite/Interval/` から宣言を抜き出し（基準55ファイル・2,018件、HEAD 64ファイル・2,419件）、保護対象の本文と全定理の言明（最外側の `:=` まで）を比べた。01-12・07-04 に加えた識別子が Lean に実在するかを照合した。証明の穴・公理・特殊な指定を探した。仮定の妥当性を確かめるため、標準ライブラリの宣言（`crates/benitoite/src/prelude/stdlib/`）、組み込みの本体（`builtins/funcs/process.rs`・`http_server.rs`・`http_client.rs`）、参照インタプリタ（`refinterp/eval.rs`）と 01-07・02-08 の該当箇所も読んだ。作業ディレクトリに `.lake` がないため、`lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果は l22〜l25 の results.md と各 axioms.log の記録に依った。VM・参照インタプリタも実行していない。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 1 |
| 中 | 2 |
| 軽 | 5 |

判定: 条件付き受け入れ。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文は基準と同じである。`Environment.lean` は全バイト一致し、`AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models` は変わらない。`ConcreteValue`・`EvalInput`・`Reached` も同じである。公開の入口の正常値・警告原因の主定理（`analyze_normal_sound`・`analyze_warning_sound`・`analyzeBase_normal_sound`・`analyzeBase_warning_sound` など）の言明も変わらない。消えた宣言はない。公理、`Builtins.Assumptions`、Interval の外の formal、`lakefile.toml` も変わらない。sorry・`admit` タクティク・`native_decide` はなく、`decide +kernel` は新しく使われていない（既存の使用は73件から29件に減った）。

公開の定理の意味は二か所で変わった。L22 は `WarningLocated`・`targetOperationAt` を一般化し、L24 は `WarningOperationSyntax` によって構文的な到達可能性・`CallReach` の警告範囲を広げた。正常値と警告原因の保証は弱まっていない。認定していない call と record の内側を親の警告から除く保証も、構文だけの定理と call reach の定理を合わせれば保たれている。ただし、拡張の範囲と算術の系の意味の記述が、Lean の実際の言明と一致しない（中2）。

重大1 は、C4 の Lean の定義・証明の誤りではない。組み込みの操作（Process.exit・Http.listen・Http.respond・Http.send）に付けた固定域の評価規則という仮定が、言語ハンドラによる差し替えを定めた言語仕様と合わない、という指摘である。この不一致は、D19 の W0404 の説明（the call stops the program at runtime）を一部の入力で偽にする。また、C4 で Lean が接続した範囲が A19〜A21 の割り当てに反映されていない（中1、RV-C2 の中1・RV-C3 の中1 と同じ種類）。

受け入れの条件は次の三つである。

1. 重大1 の扱いを A19 の着手前に設計者が決める。Lean の変更を要する案を選んだ場合は、その枝を A19 の前に置き、該当部分を再レビューする。
2. 中1 の計画の修正（A19〜A21 の枝の置き換えと分類表の訂正）を A19 の前に行う。
3. 中2 の記述の訂正を A19 の前に行い、設計者への報告に正しい範囲を書く。

D15 の停止条件には当たらない（中心二命題・公開の主定理の言明・`Models`・公理は変わらない）。

## 重大

### 重大1 組み込みの操作に付けた固定域の評価規則が、言語ハンドラによる差し替えを考慮していない（仕様と実装の読み取りで確定。VM での再現は未実施）

- 場所: `Eval.lean` の `standardCallHead`（`.opName` を認定する）と `rangeCallBinding` の fixedDomain・fieldDomain の分岐、`EvalStandard` の domainRejected・fieldRejected。`Sound.lean` の `targetOperationAt` の `.opName` の場合。`FixedDomain.lean` の `FixedDomainApi`（processExit・httpListen）と `HttpRecordDecl.binding`（respond・send）。decisions.md の D4・D18・D19。07-04 の案III の段落（A1 の限界）。plan.md の「X03cで固定する案IIIの比較範囲」。
- 問題:
  - 言語仕様は、組み込みの操作も `handle` で処理できると定める。01-07「利用者が定義するエフェクトとハンドラ」の【方針】は「組み込みのエフェクトの操作も、handle で処理できる。…どのハンドラも処理しない組み込みの操作は、処理系が実際に行う」と書く。01-12 の handle の脱糖（981行）も、節の操作に組み込みの関数 b を許す。`Process.bnt` の Exit の注記は「A language handler may replace the exit operation」である。02-08（409行）は「`IO A B C` は、まずハンドラの連鎖を調べる…なければ、処理系が操作を行う」と定める。
  - 範囲の検査は組み込みの本体にある。exit の code は `process.rs` の `u8::try_from`、respond の status は `http_server.rs` の `(200..=599).contains`、send の timeout は `http_client.rs` の `read_request` で検査する。参照インタプリタの `builtin` も、`info.op` があれば `self.operation` でハンドラを先に探し、処理された場合は既定の本体へ進まない。したがって、ハンドラが処理した呼び出しでは範囲外の引数でも停止しない。
  - Lean の評価関係は、`.opName` の標準 call に既定の実装の規則だけを付ける。域外なら outsideDomain の拒否以外の結果を持たない。解析は `handleE` の保護本体を独立入力として解析し、忘却後の環境も同定表を保つ（01-12「局所走査の対応」の `forgetEnv` の行）。そのため、たとえば `handle` の保護本体の中の `Process.exit(300)` にも W0404 を作る。呼び出し元が動的に包むハンドラの場合も同じである。どちらの場合も、D19 の説明「If execution reaches this call and all arguments are evaluated successfully, the call stops the program at runtime」は成り立たない。`--deny-warnings` では、停止しないプログラムを拒否することになる。01-07 はハンドラによる組み込みの操作の差し替えをテストの手段として挙げているので、珍しい書き方ではない。
  - D18 と 07-04 は、固定域の規則と VM の一致を A1 の信頼の範囲とし、比較で確かめるとする。しかし X03c の比較範囲はハンドラの下の呼び出しを含まないので、この不一致は比較でも現れない。07-04 の A1 の限界にもこの場合の記述がない。study の interval-analysis 345行は「ハンドラの実行の全体を検証したことにはならない」と一般的に書くだけである。
  - 影響するのは操作として宣言された四つ（Exit.exit、Listen.listen・Listen.respond、Connect.send）である。シフトは純粋な関数なので影響しない。
- 根拠: 上記の 01-07・01-12・02-08・`Process.bnt` の文言と、`process.rs`・`http_server.rs`・`http_client.rs`・`refinterp/eval.rs` の `builtin` の順序。Lean の解析が handle の中でも W0404 を作ることは、`BudgetChildren` の振り分け（01-12 の handleFail・handleE の行）と `forgetEnv` の同定表の保存から読める。VM での実際の振る舞いは確かめていない。AGENTS.md「レビューの観点」に従い、規則を変える前に、handle の保護本体の `Process.exit(300)` と、Exit を処理するハンドラの下から呼ぶ関数の `Process.exit(300)` の二例で、停止しないことを再現テストで確かめる必要がある。
- 修正案: 次のどれかを設計者が選ぶ。
  - (a) 操作（`.opName`）を固定域の認定から外し、W0404 を純粋な関数（シフト）と、純粋な関数として宣言された API だけに限る。Lean では `rangeCallBinding`・`targetOperationAt`・`WarningOperationSyntax` の fixed の分岐から `.opName` を除き、DomainExamples・HttpUpdateExamples の期待を直す。D4 の範囲の変更になる。
  - (b) 評価関係の操作の規則に、ハンドラが処理した結果（型の中の任意の正常値と任意の失敗）を加える。この場合、操作の W0404 は健全性を示せないので、解析は操作に警告を作れなくなり、結果は (a) と同じになる。
  - (c) Lean の定義を保ち、W0404 の意味を「どのハンドラもその操作を処理しない場合」に限る。D19 の主文・注記・説明（`local_analysis` の文と英語の説明）、01-04 の許可の規範、07-04 の A1 の限界、X03c の比較範囲（ハンドラの下の呼び出しを比較の対象外とする理由）に、この条件を書く。Lean の変更は不要だが、利用者向けの文言の変更になる。
- 時期: 再現テストと設計者の判断は A19 の前（A21 の文言の登録より前）。(a)・(b) を選んだ場合の Lean の枝も A19 の前に置く。

## 中

### 中1 A19〜A21 の割り当てと、計画の分類表・01-12 の振り分け表が、C4 で Lean が接続した範囲に追いついていない（読めば確定）

- 場所: plan.md の作業群 A19・A20・A21 の手順と枝の表、「Surfaceの全構成子の分類」の「C3/C4で条件付き追加」の行（81行）、「計画の変更（2026-10-26、L24 の停止を受けて）」。01-12「区間解析の独立入力の保存と保証」の振り分け表の record・recordUpdate・未認定の call の行（2535〜2537行）、「局所走査の対応」の Range の表の `rangeCall` の行。l24/results.md の「固定表への影響と Rust への申し送り」。
- 問題:
  - (a) 計上の変化は、HTTP や固定域の宣言を含まない入力にも及ぶ。`BudgetAnalysis.expr` の `.local` は、整数でない局所位置を読むたびに `rangeEntry env.ranges.facts index` で RangeState の事実を走査する（要素ごとに environmentRead と作業枠）。全ての record・recordUpdate では、分類の前に `httpBinding` が標準表の全項を `httpSignature` で走査する。型引数付きの funName と opName を頭に持つ call でも、`rangeCall` が `rangeStandardAt` を読むようになった。認定した固定域の call は `domainEntry`・`domainCallShape`（型列の数え上げ、ラベルの長さ、`domainPermutation` の補助項目、引数の数、位置の数の順）と `selectArguments` の classification・recordField を計上する。l24/restart/reference-impact.json では、body の表の変更1,282行・追加62行に、branches・generalProduct・s8_matchUnknown のように HTTP を含まない形が含まれる。
  - (b) 「計画の変更（2026-10-25、RV-C2 を受けて）」と同（2026-10-26、RV-C3 を受けて）は、固定表がどの取り込みの時点でも Rust の計上と一致することを求める。A16a は、この条件のため、Range の標準表のない入力にも効く走査と固定表の作り直しを一つの枝にまとめた。C4 の変化も同じ性質を持つが、A19〜A21 の枝の表にはこれを揃える枝がない。固定表の差を A19〜A21 へ渡すことは l24 の結果と取りまとめのレビューにだけ書かれ、計画には書かれていない。
  - (c) 解析の振る舞いの変化も A19〜A21 の完了条件にない。認定した固定域の call の引数は、親と同じ環境でソース順に解析し、独立入力にせず、未対応の印も付けない。認定した HTTP の構築の欄と、更新の更新元・欄も同じく親で解析する。更新元に正常値がなければ欄の番号だけを辿る。欄の事実は `onlyInteger` の場合だけ作り、合流・一般の call の結果・入口の忘却で捨てる。局所参照と bind で事実を複写するときは recordField を一項確保する。これらは親の警告、独立入力の列、`unsupportedBodies` の件数を変えるが、A20 の表は「明示構築を読む」「局所保存と明示更新」「respond/request への照合」しか挙げない。
  - (d) plan.md 81行は「recordの要素、recordUpdateの更新元と要素はそれぞれ独立解析し、親はTop」のままである。01-12 2535〜2536行も record・recordUpdate の要素を独立入力とだけ書き、2537行の「未認定の call」の行は認定する call を Range の標準 call に限る。L24 の後は、認定した固定域の call と HTTP の構築・更新もこの振り分けに入らない。
  - (e) 01-12 の Range の表の `rangeCall` の行は check と value の走査の順だけを書き、fixedDomain・fieldDomain の分岐の順を書かない。D16 の追記（2026-10-26、RV-C3 を受けて）は Range の走査の順序と回数を Lean の `BudgetRange`・`BudgetRangeBorrow` に委ねるが、`BudgetDomainScan`・`BudgetHttp`・`BudgetSelect` と `BudgetAnalyze` の `.local`・record・recordUpdate の分岐についての同じ指定はない。X02 は操作数・保持数・停止位置を厳密に比べるので、順序の正が定まらないと Rust の担当が判断できない。
- 根拠: 上記の Lean の定義（`BudgetAnalyze.lean` の差分、`BudgetRange.lean` の `rangeCall`・`reserveRangeFact`・`rangeBind`、`BudgetHttp.lean`、`BudgetSelect.lean`、`BudgetDomainScan.lean`）、reference-impact.json の集計、plan.md の枝の表。
- 修正案: 「計画の変更（C4 を受けて）」を設けて A19〜A21 の枝を置き換える。表には次を割り当てる。
  1. 最初の枝で、全ての入力に効く計上（整数でない局所参照の事実の走査、record・recordUpdate の `httpBinding`、型引数付きの funName と opName の頭の `rangeStandardAt`）を Lean と同じ順序と回数に揃え、固定表を新しい Lean で作り直す。A16a と同じく、HTTP・固定域の宣言のない入力では事実を作らないことを完了条件に加える。
  2. 固定域の認定の走査（`domainEntry`・`domainCallShape`）、`selectArguments`、W0404 の候補（不交差だけ）。認定した call の引数を親で解析し、独立入力と未対応の印が変わること。
  3. HTTP の構築・更新の認定（`httpBinding` の順）、子と更新元の親での解析、`onlyInteger`、更新の規則、合流・一般の call・入口での忘却、recordField の確保と返却。
  4. D16 に追記し、固定域・HTTP の走査の順序と回数の正を `BudgetDomainScan`・`BudgetHttp`・`BudgetSelect`・`BudgetAnalyze` とする。
  5. plan.md 81行と 01-12 2535〜2537行、`rangeCall` の行を L24 の後の状態に直す。01-12 の訂正は A の枝ではなく、取りまとめか最初の Lean の訂正の枝で行ってよい。
- 時期: A19 の前。

### 中2 公開の警告範囲の拡張の記述が、Lean の実際の拡張と一致しない（読めば確定）

- 場所: decisions.md「D15 の追記（2026-10-26、L24 の停止を受けて）」。07-04 の案III の段落（「公開の構文的な到達可能性と CallReach の警告範囲は、認定した固定域の call 自身と HTTP の構築・更新の子に広げ、算術警告の従来の範囲を公開の系で保つ」）と、警告位置の段落（「算術の部分の従来の範囲は公開の系で保つ」）。01-12 2413行。`CallReach.lean` の冒頭のコメント（「固定域の call 自身と、認定した HTTP の構築・更新の子だけを追加する」）。l24/results.md の「意味が変わる公開の保証と保った性質」の表。Lean は `SyntacticReach.lean` の `concreteRule`・`syntacticReachChildren`・`InSyntacticReach.arithmetic`、`BudgetReach.lean` の `analyze_warning_arithmetic`・`analyzeBody_warning_arithmetic`、`CallReach.lean` の `exprTables`。
- 問題:
  - (a) 構文的な到達可能性は、HTTP と認定した record・recordUpdate に限らず、全ての record・recordUpdate の子を含むようになった（`concreteRule` の `.record .. | .recordUpdate .. => true` と `syntacticReachChildren` の二行）。構文だけの定義は標準表を見ないので、これ自体は避けられない。しかし基準では、`analyze*_warning_syntactic_reach` と `IndependentResult.Sound` の第一の連言は、全ての record の子にある算術の警告を親の出力から排除していた。今はその排除を言わない。D15 の追記は、拡張を「具体評価を接続する HTTP のレコードの構築・更新の子」に限ると書く。
  - (b) 算術の系 `InSyntacticReach.arithmetic`・`analyze_warning_arithmetic`・`analyzeBody_warning_arithmetic` は、新しい `syntacticReachExpr` に対する言明である。保つのは演算の同定（`arithmeticOperationAt source = some warning.operation`）だけであり、基準の範囲（record の子を含まない）は保たない。D15 の「算術の演算を持つ警告は従来の範囲にある」と 07-04 の「算術警告の従来の範囲を公開の系で保つ」は、実際の言明より強い。認定した HTTP の構築の子にも算術の警告が出うるので、基準の範囲そのものを系で保つことはもともとできない。
  - (c) 認定していない record の子の除外は、`CallReach.exprTables` の gate（`httpExpressionBinding ≠ none`）を通じて、`analyze*_warning_call_reach` と独立入力の call reach の定理だけが保つ。二つを合わせれば既存の入力についての保証は失われていない。これは RV-C3 の中2 の案 (b) と同じ形だが、D15・07-04・01-12 はこの分担を書かない。
  - (d) `CallReach` の allows は、固定域の call 自身だけでなく、認定した固定域の call の引数にある算術の警告も含む。gate が `rangeCallBinding ≠ none` であり、L24 から固定域の call も認定されるからである。引数の区間を得るために必要な拡張で妥当だが、D15 の追記と `CallReach.lean` の冒頭の列挙にない。
  - (e) L22 で、`analyze_warning_located`・`analyzeExpr_warning_located`・`analyzeBody_warning_located` の意味も変わった（`WarningLocated` と `targetOperationAt` が抽象環境と出現のキーを受け取り、`.standard binding` を返す）。plan の L22 の申し送りが指示した拡張であり、算術については `arithmetic_target_at` により同値である。ただし `targetOperationAt` は規則の種類を問わず（Range の規則でも）標準の位置を許し、固定域への限定は `WarningOperationSyntax` の側にある。D15 の追記の列挙にはこの定理群がない。
  - D15 の追記は「公開の定理の意味の拡張なので設計者へ報告する」とする。今の記述のまま報告すると、(a)・(b)・(d)・(e) の範囲が伝わらない。
- 根拠: 基準 `be57d4e9` の `concreteRule` は `.call .. => true | _ => false` であり、record は false だった。HEAD の言明は上記のとおりで、宣言の照合で言明の変わった定理は18件（`analyzeExpr_warning_located`・`analyzeBody_warning_located`・`within_call`・`expr_located`・`target_concrete`・`concreteRule_known` などの位置と内部の補助定理）だった。
- 修正案: D15 の追記、07-04 の二つの段落、01-12 2413行、`CallReach.lean` の冒頭、l24 の結果の表を、(a)〜(e) の実際の範囲に直す。系については、次のどちらかを選ぶ。
  - 系の説明を「演算の同定を保つ」に改め、認定していない call・record の内側の除外は call reach の定理が担うと書く。
  - 「算術の警告は、基準の構文的な到達可能性にあるか、認定した固定域の call の引数か、認定した HTTP の構築・更新の子にある」を述べる系、または認定していない record の内側を除く公開の系（`analyzeExpr_unrecognized_call_warnings` に相当するもの）を加える。
  
  いずれの場合も、`SyntacticReachExamples` か `HttpUpdateExamples` に、認定していない record の欄の除数0が親の警告にならない例を加える。
- 時期: 記述の訂正と系の選択の記録は A19 の前（設計者への報告の前）。系を加える場合の証明は C5（L27〜L29）まで。

## 軽

### 軽1 01-12 の Unmodeled・UnknownAt の説明が Lean と食い違う（読めば確定）

- 場所: 01-12 1217行。
- 問題: 本文は「`Unmodeled e` は…record・recordUpdate を含む」と書き、`UnknownAt` を「call で rangeCallBinding の認定がない出現、または call 以外の api で standardAt に規則のない出現」とする。L24 の後の Lean では `Unmodeled` の record・recordUpdate は False であり、`UnknownAt` は record・recordUpdate について `httpExpressionBinding env input = none` を見る。同じ段落の「後の profile で具体規則を接続する形は、同じ変更で Unmodeled から外す」にも反している。
- 修正案: 1217行を Lean の定義に合わせる。

### 軽2 07-04 の「decide +kernel で証明する」が、#guard への変換と食い違う（読めば確定）

- 場所: 07-04 379行。`BudgetIndependentExamples.lean` の二例。
- 問題: 07-04 は「環境と停止の二例は decide +kernel で証明する」と書くが、L24 はこの二例を `#guard` に変えた。L24・L25 は `BudgetAnalysisExamples`・`Examples`・`IdentityExamples`・`EvalClosed` の具体計算の例も `#guard` に移した。`#guard` は Lean のコンパイラ・インタプリタによる評価を信頼する検査であり、カーネルが検査する証明ではない。メモリの対策として妥当な変更だが、設計書の記述が古い。
- 修正案: 07-04 379行を `#guard` の実行比較に直し、カーネルの証明とは区別することを書く。

### 軽3 Process.exit の結果型の記述が、一つの標準束縛に一つの結果型を持つ形と合わない（読めば確定）

- 場所: 01-12「区間解析の直接引数と固定の定義域」の表の processExit の行（「呼び出しで具体化した型引数」）。`FixedDomain.lean` の `FixedDomainApi.resultType` のコメント（「exit の型引数は呼び出しの型を使う」）。
- 問題: 標準束縛表は宣言ごとに一つの `StandardBinding` を持ち、その `result` は一つの型である。`exit[T]` の T は呼び出しごとに違うが、表に入れる `exitType` は一つしか選べない。`standardCall`（正常値）は入力の型が `binding.rule.resultType` に一致する場合だけ導出を持ち、失敗と return は `fixedCallFailed`・`fixedCallAbrupt` が任意の型で導出する。したがって、型が `exitType` と違う呼び出しには正常値の導出がない。既定の実装の exit は戻らないのでこの欠けは実害がないが、本文の記述とは合わず、交換が `exitType` に何を入れるかも決まっていない。
- 修正案: 01-12 とコメントに、正常値の導出は表の結果型と一致する呼び出しだけにあることと、交換が渡す `exitType` の決め方を書く。重大1 で (b) を選ぶ場合は、この点も合わせて決める。

### 軽4 Http.request の名前と、シフトの別名の宣言が計画に反映されていない（読めば確定）

- 場所: decisions.md の D4、plan.md の「受け渡す契約」「HTTPの欄」の行、作業群 A20（A20c）、「X03cで固定する案IIIの比較範囲」の Http.request の行。作業群 A19。
- 問題:
  - 実ソースに `Http.request` という宣言はなく、ClientRequest を受け取るのは `Http.Connect.send` である。Lean と l24 は send に対応させたが、D4 と計画は request のままである。
  - 標準ライブラリには、Lean の役割（七種と Byte の20方向）より多い27のシフトの宣言がある。`Integer.shift*` と `Integer64.shift*`、`UnsignedInteger.shift*`（UnsignedInteger64 の別名）、`UnsignedInteger8.shift*`（Byte と同じ型）が、同じ役割に別の宣言として並ぶ。Lean の `FixedDomainApi.binding` は宣言名を受け取るので複数の宣言を表せるが、A19 の完了条件はどの宣言を表へ入れるかを挙げない。
- 修正案: D4 と計画の request を send（`Http.Connect.send`）に直す。A19a か A19b の完了条件に、表へ入れる宣言の集合（別名の宣言を含める）を挙げる。

### 軽5 閉じた評価器の固定域の内側の選択を、X03・L28 の比較の契約が扱っていない（読めば確定。比較での影響は実行しないと分からない）

- 場所: `EvalClosed.lean` の `ClosedEval.standard` の fixedDomain・fieldDomain の分岐。plan.md の作業 L28 と作業群 X03 の手順（「evalClosedと実VMで値/失敗種/到達を比較する。未知を含むものは実行比較へ入れず」）。
- 問題: L25 の前の閉じた評価器は、固定域の call と HTTP の構築・更新で none を返し、その入力は比較から外れていた。L25 の後は、域内の正常引数に対して domainOtherFailure・fieldOtherFailure による `failed unknown` を返し、後続を評価しない。これは評価関係の正しい導出の一つであり、Lean の中でそれ以上の主張には使われていない（07-04 と 01-12 もこれを明記している）。しかし X03 の手順のまま比べると、域内のシフトを含む入力で VM の成功値と食い違う。L25 の結果は「実 API の結果へ読み替えない」と申し送るが、計画の X03・L28 の節には書かれていない。
- 修正案: X03 と L28 の節に、固定域・HTTP の API の事象が `unknown` の失敗を選んだ入力は「未知を含む入力」として実行比較から外す（またはその事象より後を比較しない）と書く。

## 確かめて問題がなかった観点

1. 中心二命題と保護対象の定義: `NormalSoundness`・`WarningSoundness` の本文、`Environment.lean` の全体（`AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models`・`resetRanges`）、`ConcreteValue`・`EvalInput`・`Reached` は基準と同じである。`StandardBinding` に欄 `argumentTypes`（既定値 `[]`）が加わったが、`Models` の二表の一致の要求の形は同じで、強まっていない。`RangeLocalFact.httpRecord` と `RangeState.Models` の拡張は公開の `Models` に入らず、公開の入口では `resetRanges` の空の状態から構成される。
2. 公開の入口の主定理: 正常値と警告原因の主定理の言明は変わらない。言明の変わった18件は、L22 の位置の定理2件（中2 の (e)）と内部・private の補助定理であり、`analyze_warning_located` などの移動は名前空間と言明を保っている（l24/restart/audit.json の header_changes と一致）。
3. 証明の穴と公理: 追加行に sorry・`admit` タクティク・`native_decide`・`axiom`・`implemented_by`・`@[extern]` はない。`Budget.lean` の `admit` は基準からある private な関数名である。`decide +kernel` は新しく使われていない。公理の照会の記録（l22〜l25 の axioms.log）は propext・Classical.choice・Quot.sound の範囲で、sorryAx はない。Interval の外の formal、`Builtins.Assumptions`、`lakefile.toml`（`-M 12288`）は変わらない。Interval の全64ファイルは `formal/Benitoite.lean` から import で到達する。
4. 評価規則（D18）: `EvalTypedArguments` はソース順に各引数を評価し、子の失敗・return を伝播して後続の引数と親の事象を作らない。`arguments_typed`・`typed_arguments_uniform` により、Range の規則は旧 `EvalArguments` と同じ導出を持つ（Range の認定は型引数のない funName に限ったまま）。`fixedCallFailed`・`fixedCallAbrupt` は親の型によらず失敗と return を伝播し、`standardCall` と重なっても同じ trace を作る。fieldDomain は域外の既知の欄を outsideDomain、域内を正常値と `unknown` の失敗、読めない欄を正常値と `unknown` の失敗とし、IO の成功と正常復帰を保証しない。timeout は `[1,max64]`、status は `[200,599]`、シフトは `[0,w−1]`・Byte `[0,7]`、exit `[0,255]`、port `[0,65535]` であり、存在しない rightUnsigned は契約を返さない。HTTP の構築は全欄の置換を要求し、更新は更新元、欄の順に評価する。`Expand` は読める con では元の欄列を保ち、読めない表現にも導出を残す。`Unmodeled` の record を False にし、`UnknownAt` で `httpExpressionBinding = none` の場合だけ未知とすることで、具体規則と未知の規則の重なりを除いている。
5. 閉じた評価器（L25）: 域内で選ぶ `failed unknown` は `domainOtherFailure`・`fieldOtherFailure` の導出であり、`evalClosed_sound` の言明は変わらない。正常値の表層導出は `DomainExamples`・`HttpUpdateExamples` で評価関係の構成子から別に組み立てており、閉じた評価器の選択を成功値の予測には使っていない。
6. 解析（D4・D19）: `baseDomainDisjoint` と `FixedDomainContract.disjoint` は Bottom で false、閉区間では端点の比較だけで判定し、交差・Top・Bottom から W0404 を作らない。HTTP の更新は、更新欄を新しい区間に替え（未知の値なら事実を作らない）、更新しない欄は同じ宣言の事実を保つ（`selectedHttpUpdateFact`・`httpRecordUpdateFact`）。`baseJoin` は欄の事実を捨て、一般の call の結果は `baseUnknown`、入口と本体の境界は RangeState を忘れる。
7. 標準束縛の同定（L22）: `targetOperationAt` は算術について `arithmetic_target_at` により旧関数と同じ結果を返す。標準 call は `standardAt` の二表と頭の宣言の一致を要求し、同名の利用者関数、表にない宣言、別の出現キー、関数値・部分呼び出し・パイプを認定しない（DomainExamples の `identityEnvs` と偽の頭の例）。HTTP のレコードは出現の同定表を使わず、標準表の所有元と構成子の文字列で同定する。交換が解決済みの完全な名前を渡すことは 01-12 に入力の条件として書かれている。A20 と交換の担当は、この条件を満たす名前を使う必要がある。
8. 独立入力と認定していない call: L21R の `analyzeExpr_unrecognized_call_warnings` の言明は変わらない。`CallReach.callRoot` は標準の警告に同じキーで認定した同じ束縛を要求し、`WarningOperationSyntax` は `isFixed` を要求するので、Range の call 自身は標準の警告の位置にならない。認定していない call・利用者関数・案III の対象外の標準 call の内側は call reach の範囲に入らない。
9. 予算（D16）: HTTP の欄の事実の複写を recordField 一項、局所の事実の走査を environmentRead とする計上は、D16 の本文（レコードの一欄を1項、環境の参照を1回）と 01-12 1398行に合う。順序の正の指定がないことは中1 の (e) に挙げた。
10. 写し: 01-12・07-04 に加えた識別子は、診断の番号 E0340 を除いて全て Lean に実在する。07-04 には「これらの具体規則も A1 の信頼の範囲であり、実 VM との比較は別に必要である」と「標準束縛表の正しさと実本体・VM との一致は A1 の信頼の範囲として比較で確認する対象」があり、L25 の完了条件（固定域の評価規則も A1 の信頼の範囲で、比較だけで確かめる）を満たす。
11. 例: DomainExamples は20のシフト方向・exit・listen について、7区間×2引数順の解析を `analyzeExpr`、4値×2引数順の評価を `evalClosed` に通し、期待値（域内・端で交差・Top・Bottom で警告なし、全域外で outsideDomain）は D4 と合う。HttpUpdateExamples は status 100・199・200・599・600、timeout 0・1・2^40+1・max64、更新の置換と保存、未知の更新値、局所保存、子の失敗・return、標準表なし・偽の親 call・一般の関数の戻り値での警告なしを、解析入口と閉じた評価器に通す。
