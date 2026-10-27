# RV-C4R: 区切り C4 の再レビュー（L25R の後の定義・言明・仮定）

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `c18e43f2` を detach で取り出した別の作業ディレクトリ（`<review>`）。`formal/Benitoite/Interval/` の全61ファイル、`formal/Benitoite.lean`、`formal/lakefile.toml`。設計書は 01-12 の区間解析の節と 07-04。差分の基準は L25R の基準 `62949b1d`（RV-C4 の受け入れの記録）と C4 前の基準 `be57d4e9` の二つ。範囲は L25R（`c18e43f2`）。
- 照合した文書: 改造のディレクトリ（以下 D）の reviews/RV-C4.md・RV-C4-response.md、decisions.md の D4（「D4 の変更（2026-10-26、RV-C4 の重大1 を受けて、設計者の決定）」を含む）・D15（2026-10-26 の三つの追記）・D16（二つの追記）・D18・D19、plan.md の「受け渡す契約」「Surfaceの全構成子の分類」「計画の変更（2026-10-26、L24 の停止を受けて）」「計画の変更（2026-10-26、RV-C4 を受けて）」、作業 L22〜L25・L28、作業群 A19〜A21・X03 と「X03cで固定する案IIIの比較範囲」、README.md の Q1・Q2。l25r/results.md と同じディレクトリの audit.json・final-review.json・reference-impact.json・axioms.lean・axioms.log・formal.log・work-check.json。
- 方法: 読み取り、`git diff`・`git show`・grep・Python による照合だけで行った。三つの版の `formal/Benitoite/Interval/` から宣言を抜き出し（`be57d4e9` 2,017件、`62949b1d` 2,420件、`c18e43f2` 2,230件。コメントを除いた本文と、定理は最外側の `:=` までの言明）、保護対象の定義の本文と全定理の言明を比べた。既定 import からの到達、証明の穴・公理・特殊な指定、Lean の残骸を探した。01-12・07-04 に書いた識別子と記述を Lean と照合した。final-review.json の SHA-256 をコミットの内容と照合した（30ファイル、不一致0）。シフトの宣言の集合は `crates/benitoite/src/prelude/stdlib/` の .bnt と組み込みの本体（`builtins/funcs/byte.rs`・`width_bits.rs`）で確かめた。予算の参照入力（`crates/benitoite/testdata/interval-budget/budget-reference.lean`）と Rust の Range の表の作り方（`typeck/interval/flow/range.rs`）も読んだ。作業ディレクトリに `.lake` がないため、`lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果は l25r/results.md と formal.log・axioms.log・work-check.json の記録に依った。VM と参照インタプリタも実行していない。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 1 |
| 軽 | 5 |

判定: 条件付き受け入れ。Lean と設計書（01-12・07-04）は受け入れてよい。条件は中1（計画と判断の文書を L25R の後の状態へ直すこと）を A19 の着手前に行うことである。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文は両基準と同じである。`Environment.lean` と `RangeState.lean` は C4 前の基準と全バイト一致し、`AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models`・`RangeState.Models`・`RangeLocalFact.Models` も同じである。`ConcreteValue`・`ConcreteValue.type`・`EvalInput`・`Reached` も両基準と同じである。公開の入口の主定理（正常値・警告原因・構文的な到達可能性・call reach・独立入力・未認定 call の除外・閉じた評価器）の言明は両基準と一致する（算術の系2件は C4 で新設し、`62949b1d` と一致する）。言明が C4 前から変わったのは `analyzeExpr_warning_located`・`analyzeBody_warning_located` と内部・private の補助定理の計16件で、すべて L22 の位置の一般化と `arithmeticOperationAt` への改名に由来する。C4 前から消えた定理はない。公理、`Builtins.Assumptions`、Interval の外の formal、`lakefile.toml` は変わらない。

重大1 は閉じた。`standardCallHead` は `.funName` だけを返すので、`.opName`・`.opDicts` を頭に持つ call は、どの標準表の下でも `rangeCallBinding` が none になり、`UnknownAt` の第三の選言が `rfl` で成り立つ。操作の call は既存の未知の規則（型の中の任意の正常値と `failed .unknown`）だけで評価され、W0404 の候補・公開の構文的な到達可能性（`WarningOperationSyntax`）・call reach（`callRoot`）にも入らない。HTTP のレコード欄の追跡は Lean・設計書から除かれた。公開の警告範囲は、C4 前の基準に対してシフトの認定した call 自身とその引数だけが広がる。ただし、位置の述語 `targetOperationAt` には `.opName` の分岐が残る（軽1）。

D15 の停止条件には当たらない。

## RV-C4 の各所見の状態

| 所見 | 状態 | 根拠 |
|---|---|---|
| 重大1 操作に付けた固定域の規則がハンドラによる差し替えを考慮していない | 閉じた（Lean・設計書）。Rust での確認は A21 に残る | `standardCallHead`（`Eval.lean`）、`BudgetScan.rangeCall`（表の探索前に断る）、`EvalClosed` の同じ関数の使用、`FixedDomainApi` はシフトだけ。DomainExamples の任意の環境での未知の導出の example と、シフトの表を渡した opName の #guard |
| 中1 A19〜A21 の割り当てと分類表・振り分け表 | 一部が閉じた。01-12 の振り分け表・`rangeCall` の行・順序の正の段落は閉じた。plan.md 81行は HTTP の除去で現状と合う。A19〜A21 の置き換えと D16 の順序の正の追記は未了（新しい中1） | 01-12 2182行・2203行・2460行。plan.md に「計画の変更（2026-10-26、L25R を受けて）」はまだない |
| 中2 公開の警告範囲の拡張の記述 | 閉じた | (a) `concreteRule`・`syntacticReachChildren` は C4 前と全文一致。(b) 算術の警告について `InSyntacticReach` は C4 前の述語と同じになった（後述）。(c)(d) D15 の追記・07-04・01-12・`CallReach.lean` の冒頭に分担と引数の拡張を書いた。(e) D15 の追記が設計者への報告に含める。認定していない record・recordUpdate の欄の除数0の例は SyntacticReachExamples にある |
| 軽1 Unmodeled・UnknownAt の説明 | 閉じた | 01-12 1217行は Lean の `Unmodeled`（record・recordUpdate は True）・`UnknownAt` と一致する |
| 軽2 decide +kernel の記述 | 閉じた | 07-04 379行と 01-12 の対応箇所を #guard の実行比較に直した。`BudgetIndependentExamples.lean` は #guard 4件である |
| 軽3 processExit の結果型 | 解消（exit を除去） | `FixedDomainApi` に processExit がない |
| 軽4 Http.request の名前とシフトの別名 | 名前は HTTP の除去で不要になった。別名は results.md の A19b の案に入ったが、計画への反映は未了（中1） | 実ソースのシフトの宣言は27件で、案の列挙と一致する（後述） |
| 軽5 閉じた評価器の固定域の内側と X03・L28 | 方針は計画の変更の本文にある。X03c の表そのものは未修正（中1） | plan.md「X03cで固定する案IIIの比較範囲」に exit・listen・request・respond の行が残る |

## 中

### 中1 計画と判断の文書が、L25R の後の Lean と案III の範囲に追いついていない（読めば確定）

- 場所: plan.md の作業群 A19・A20・A21 の手順と枝の表、「受け渡す契約」の「HTTPの欄」の行（L23/L24→A20）と「警告」の行（「除数、対象演算、引数または欄を一次位置とし」）、「X03cで固定する案IIIの比較範囲」の表。decisions.md の D16（順序の正の追記がない）、D18（「固定域の規則も、標準宣言と引数または欄の同定」）、D19（`field_message`、``Http.respond`` の欄の主文の例、説明の「argument or field」と日本語の「引数または欄」）。README.md の Q1（案III を「固定の定義域を持つ API の引数の照合」とだけ書き、D4 の変更への参照がない）。
- 問題:
  - A19c は今も Process.exit・Http.listen の直接引数を接続し、A20 は HTTP の欄を実装し、A21a は欄の主文を含む D19 の全型板を登録する。A19a・A19b の完了条件はシフトの別名の宣言を挙げない。このまま A19 に着手すると、Lean にない操作の候補や HTTP の追跡を Rust に作ることになる。
  - X03c の表は exit・listen・request・respond の比較入力を残し、計画の変更の本文（それらの行を除く）と食い違う。
  - D16 の追記（2026-10-26、RV-C3 を受けて）は順序の正を `BudgetRange`・`BudgetRangeBorrow` に限る。固定域の走査の正は 01-12 2203行と l25r/results.md に書かれたが、二つの列挙が一致しない。01-12 は `rangeStandardAt`・`rangeStandard`・`bindingArgument`・`selectedFixedOwn`・`saveWarnings` を挙げず（`rangeStandardAt` は `rangeCall` の行にはある）、results.md は挙げる。X02 は操作数・保持数・停止位置を厳密に比べるので、Rust の担当が正とする関数の範囲は一つに定まっている必要がある。
  - D19 の英語の説明「the argument or field is always out of range」は、欄を対象から除いた後の W0404 には当たらない。results.md の A21a の案は欄の型板を登録しないとするが、D19 の本文が正のままだと担当は D19 に従う。
- 根拠: 上記の各文書の本文。取りまとめのレビュー（l25r/results.md の末尾）は、A19〜A21 を「計画の変更（2026-10-26、L25R を受けて）」で置き換えると書くが、`c18e43f2` の時点では未了である。
- 修正案: 予定の「計画の変更（2026-10-26、L25R を受けて）」で次を行う。
  1. A19〜A21 の枝を results.md の案（A19a〜A19c・A21a〜A21c）で置き換え、A20 を除く。A19b の完了条件に27宣言の集合を挙げる（軽3 の入力条件と、軽5 の表の作り方の条件も加える）。
  2. 「受け渡す契約」の「HTTPの欄」の行を除き、「警告」の行の一次位置を「除数、対象演算、シフトの対象引数」に直す。
  3. X03c の表から exit・listen・request・respond の行を除き、操作を比較しない理由（ハンドラによる差し替え）と、`unknown` の失敗を選んだ入力を比較から外すことを表の下に書く。
  4. D16 に追記し、固定域の走査の順序と回数の正を、results.md と 01-12 の和集合（`BudgetScan.rangeCall`・`rangeStandardAt`・`rangeStandard`・`domainCallShape`、BudgetDomainScan.lean の7関数、`selectArguments`・`bindingArgument`・`selectedFixedOwn`、`BudgetAnalysis.expr`・`fixedOwn`・`saveWarnings`）とする。01-12 2203行も同じ列挙にそろえる。
  5. D18・D19 に D4 の変更を受けた追記を置き、欄の同定・`field_message`・欄の主文の例を除く。説明の英文と日本語の説明から「or field」「または欄」を除く。README の Q1 に D4 の変更への参照を添える。
- 時期: A19 の前。

## 軽

### 軽1 位置の述語 `targetOperationAt` に `.opName` の分岐が残り、例がそれを期待値として固定している（読めば確定）

- 場所: `Sound.lean` の `targetOperationAt`（`.call (.opName ..)` の分岐）と `target_at_operation`（docstring「エフェクトの操作も同じ二表で同定し」）。`FixedDomainExamples.lean` の位置の #guard（`target env key operationCall` の期待値 `some "resolved:Byte.shiftLeft"`）。01-12 2056行・2060行。
- 問題: 認定・評価・警告の候補・構文的な到達可能性・call reach からは `.opName` が除かれたが、公開の `analyze*_warning_located` が参照する `WarningLocated` は、opName の call の位置に標準束縛を持つ警告を許したままである。解析はそこに警告を作らないので健全性は損なわれないが、公開の位置の保証が必要より弱い。FixedDomainExamples の例は、シフトの束縛を Process.exit の形の call（ラベル `"code"`、型引数 Unit、一引数）に付けて opName の位置の同定を期待値として固定しており、L25R の方針（操作は標準の対象にしない）とは逆の向きの検査になっている。results.md はこの点を「C4 前からの意味の拡張として報告する」と明記しており、記述と Lean は一致する。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) `targetOperationAt` の opName の分岐と `target_at_operation` を除き、例の期待値を none に直す。`WarningLocated` の意味が狭まる（保証が強まる）変更なので、D15 の判断の範囲に収まる。証明の修正を伴うので C5 までの Lean の枝に入れる。(b) Lean を保ち、設計者への報告に「位置の述語は opName の位置も許すが、警告の候補と二つの範囲の述語は opName を含めない」と書き、例の call の形をシフトの形（`[a, n]` の二引数）に直す。

### 軽2 Process.exit・Http.Listen.listen の W0404 なしの #guard が空の標準表で行われ、区別の力を持たない（読めば確定）

- 場所: `DomainExamples.lean` の `exitSource`・`listenSource` の #guard（`abstract [] ...`）。01-12 1554行（「Process.exit(300) と域外の port の操作には W0404 がなく」）。l25r/results.md の「独立例と作成時の関門」。
- 問題: 標準表が空なので、opName を認定していた `62949b1d` の定義でもこの #guard は通る。`listenSource` の出現表は `"resolved:Process.exit"` を返し、宣言とも一致しない。opName の除外を実際に区別するのは、シフトの表を渡した次の #guard と、任意の環境での未知の導出の example である。results.md と 01-12 の書き方は、前者の #guard が区別の検査であるように読める。
- 修正案: exit・listen の #guard に、同じ宣言名と `.fixedDomain` の規則を持つ手書きの `StandardBinding`（例えば exit なら `⟨"resolved:Process.exit", .fixedDomain 0 0 255 (.base .unit), [.base .integer]⟩`）を表として渡し、出現表も各宣言にそろえる。急がない。C5 の例の整理でよい。

### 軽3 固定域の規則を純粋なシフトの宣言だけに付けるという交換の入力条件が、設計書と A19b に書かれていない（読めば確定。比較での影響は実行しないと分からない）

- 場所: 01-12「区間解析の直接引数と固定の定義域」、07-04 の案III の段落、results.md の A19b の案。標準ライブラリの `Integer64.bnt`・`UnsignedInteger.bnt`・`UnsignedInteger8.bnt` のシフト。
- 問題:
  - Lean の `rangeCallBinding` は、表に `.fixedDomain` の規則を持つ funName の宣言なら、どの宣言でも認定する。操作の除外は opName の頭の構文で保証されるが、エフェクトを持つ関数（内部で操作を行う標準関数）に交換が固定域の規則を付ければ、重大1 と同じ食い違いが funName の側で起きうる。今の案III ではシフトだけが対象で、シフトの27宣言はすべて `uses` を持たない純粋な関数である（組み込みの本体も `pure fn`）。しかし「固定域の規則は `FixedDomainApi.binding` が作るシフトの宣言だけに付ける」という条件は、01-12 の入力の条件にも A19b の完了条件にもない。
  - 別名の宣言のうち `Integer64.shift*`・`UnsignedInteger.shift*`・`UnsignedInteger8.shift*` の6宣言は、組み込みではなく別のシフトを呼ぶ包みの関数である。X03c は「引数の評価後の R0701 と元位置を比較する」とするが、包みの関数では R0701 の位置が包みの本体の中になる可能性がある。実際の位置は VM を実行しないと分からない。
  - 未知の規則がハンドラの結果を表す仕方のうち、再開しないハンドラ（呼び出し元へ値を返さず handle の外へ出る）は `failed .unknown`（後続の事象を作らない）に当たる。この対応は健全だが、01-12 と 07-04 は「型内の任意の正常値と未知の失敗」とだけ書き、再開しない場合を明示しない。
- 修正案: 01-12 の固定域の節の入力の条件に、固定域の規則はシフトの宣言（別名の宣言を含む）だけに付け、エフェクトを持つ関数には付けないことを書く。A19b の完了条件にも同じ条件を加え、L27 の読者で `.fixedDomain` を持つ宣言の集合を照合できるようにするかを決める。X03c に包みの宣言の R0701 の位置の扱い（元の call の位置で比べるか、包みの本体の位置を許すか）を加え、実行して確かめる。01-12 1319行に、再開しないハンドラが未知の失敗に当たることを一文で書く。

### 軽4 型引数付き funName の標準表の照会は案III に不要になったが、全入力の計上の変化として残っている（読めば確定）

- 場所: `Eval.lean` の `standardCallHead`（`.funName declaration _ _`）、`BudgetRange.lean` の `rangeCall`。l25r/results.md の「固定表への影響」と、「中心二命題と参照定義の差分の向き」の表の「解析・予算・本体/全体駆動」の行。
- 問題:
  - C4 前の `rangeCall` は `.funName declaration [] []` のときだけ `rangeStandardAt` を読んだ。L22 は型引数を持つ `exit[T]` のために型引数付きの funName も読むようにしたが、L25R で exit を除いた後、型引数を持つ固定域の API はない（シフトは単相である）。それでもこの照会は残り、`helper[T]` のような一般の関数の呼び出しを含む7形の body の固定表に492行の変更と14行の追加を生む。results.md が挙げる差の原因はこれだけである。
  - results.md の表は、この費用を「C4 前から残る型引数付き funName の標準表の照会の費用」と書く。C4 前の Lean にはこの照会はなく、L22 で入って L25R の後も残ったものである。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) 今の Lean を保ち、results.md の案のとおり A19a で Rust をそろえて固定表を作り直す。(b) `standardCallHead` を `.funName declaration [] []` に限る Lean の枝を A19 の前に置く。固定表は A18 のものと一致し、A19a の作り直しが要らなくなる。どちらの場合も、results.md の「C4 前から残る」を「L22 で入り L25R の後も残る」に直す。

### 軽5 固定表の作り直しを A19a に限るには、A19b がシフトの宣言を加えても既存の入力の標準表を変えないことが要る（読めば確定）

- 場所: results.md の A19a・A19b の案、計画の変更（2026-10-26、RV-C4 を受けて）の「固定表の作り直しをこの枝に限る」。`budget-reference.lean` の `rangeReferenceEnv`、Rust の `typeck/interval/flow/range.rs` の `Tables::collect`。
- 問題: 予算の参照入力は、Range の出現があるときだけ `[checkInteger, value]` の二項を標準表に置く。Rust も本体ごとに出現があるときだけ同じ二項の表を作る。`rangeStandard` は表を先頭から一致まで走査し、一項ごとに操作を数えるので、A19b がシフトの宣言を表に加える方法（出現がなくても27項を加える、Range の項より前に置く、など）によっては、シフトを含まない参照入力の操作数が変わる。その場合、A19b で再び固定表の差が出て、「作り直しを A19a に限る」と両立しない。results.md の A19b の案はこの条件を挙げない。
- 修正案: A19b の完了条件に「シフトの出現のない本体では標準表と出現表を変えない。シフトの項を加えるときの表の中の順序を、Lean へ渡す交換と同じに固定する」を加える。表の作り方を変える必要が生じたら、作り直しの枝を A19b にも置くかを取りまとめが決める。

## 確かめて問題がなかった観点

1. 中心二命題と保護対象の定義: `NormalSoundness`・`WarningSoundness`・`Models`・`SlotModels`・`LocalsModels`・`AbstractSlot`・`AbstractEnv`・`ConcreteValue`・`ConcreteValue.type`・`EvalInput`・`Reached`・`RangeState`・`RangeState.Models`・`RangeLocalFact`・`RangeLocalFact.Models` の本文は C4 前の基準と一致し、`Environment.lean`・`RangeState.lean` は全バイト一致する。`WarningLocated` の本文は `62949b1d` と一致し、C4 前との差は L22 の一般化（D15 の追記の報告対象）である。`StandardRule`・`EvalStandard`・`Unmodeled`・`UnknownAt` は C4 前と一致する。`StandardBinding` の欄 `argumentTypes`（既定値 `[]`）は C4 で加わったまま残るが、`Models` の二表の一致の形は変わらない。
2. 公開の入口の主定理: 正常値・警告原因・位置・構文的な到達可能性・call reach・独立入力・未認定 call の除外・`evalClosed_sound` の27言明は `62949b1d` と一致する。C4 前とは、位置の2件（言明が変わった）と算術の系の2件（C4 で新設）を除いて一致する。C4 前の定理で消えたものはない。`62949b1d` から消えた81件は HTTP 専用の定理と例であり、言明が変わった6件（`concreteRule_known`・`baseValuesWith_models`・`baseValues_field`・`selectArguments_normal`・`expr_value_normal`・`then_valueModels`）は内部の補助定理で、`concreteRule_known` は C4 前と同じ言明に戻った。
3. 証明の穴と公理: L25R の追加行に sorry・`admit` タクティク・`native_decide`・`decide +kernel`・`axiom`・`implemented_by`・`@[extern]`・`set_option` はない。`decide +kernel` の使用は `62949b1d` と同じ29件である（C4 前は73件）。C4 前からの追加行にある `set_option maxHeartbeats 800000 in` 二件と `maxRecDepth 2048 in` 一件は C4 で入った局所指定で、L25R は増やしていない。axioms.log の16宣言の依存は propext・Classical.choice・Quot.sound の範囲で、sorryAx はない。Interval の全61ファイルは `formal/Benitoite.lean` から import で到達し、消えた3ファイル（`BudgetHttp`・`HttpRecordExamples`・`HttpUpdateExamples`）の import も除かれた。
4. 検査の記録とコミットの対応: final-review.json の30ファイルの SHA-256 は `c18e43f2` の内容と一致し、L25R が変えた formal と設計書のファイルに漏れはない。最後の formal_build（既定ビルドと sorry 拒否）はこの最終点検の後に終了0で記録されている。
5. 重大1 の閉鎖（評価関係）: 操作の call には具体規則がなく、`unknownNormal`（`value.type = input.type` の任意の値）と `unknownFailed` の導出が任意の具体環境で成り立つ（DomainExamples の example は環境と値を量化して構成子から示す）。ハンドラが再開して返す値は前者、再開せずに handle の外へ出る場合は後者（後続の事象を作らない）に当たる。`EvalClosed` は同じ `standardCallHead` を使い、操作の call で none を返す。
6. 重大1 の閉鎖（解析と範囲）: `BudgetScan.rangeCall` は opName の頭で表を探索せず none を返し、解析は未認定の call として頭と引数を独立入力にする。`WarningOperationSyntax` と `callRoot`（`rangeCallBinding` との一致を要求する）は opName を含めない。`#guard` は、シフトの束縛を表に持つ opName の call が W0404 を作らず閉じた評価器でも評価不能になることを確かめる。
7. HTTP の残骸: Interval の Lean に HTTP の定義・欄の事実・`fieldDomain`・`recordField` の新しい使用は残っていない（`BudgetPatterns` の `recordField` は C4 前からのパターンの計上）。`BudgetAnalyze` の `.local` は C4 前と同じく非整数で `baseUnknown` を返し、record・recordUpdate の分岐はなくなった。`rangeBind` は Range の由来だけを保存する。01-12・07-04 にも HTTP の追跡の記述は残らず、02-05・02-10・03-06 などほかの章と処理系に W0404 の記述はない。
8. 公開の警告範囲: `concreteRule`・`syntacticReachChildren`・`syntacticReachExpr` は C4 前と全文一致し、`InSyntacticReach` は `targetOperationAt` を `WarningOperationSyntax` に替えただけである。C4 前の `targetOperationAt` と今の `arithmeticOperationAt` は本文が一致し、`WarningOperationSyntax` は算術の演算では `arithmeticOperationAt` の等式そのものなので、算術の警告についての `InSyntacticReach` は C4 前の述語と同じである。`analyze_warning_arithmetic` の結論は、01-12 が書く「演算の同定を保つ」より強く、C4 前の範囲そのものに当たる。追加はシフトの call の位置の標準の警告だけで、`WarningsInSyntacticReach` には `WarningLocated` の連言が加わった（強める向き）。`CallReach.exprTables` の C4 前との差は call の根の `callRoot` だけで、gate を通るシフトの call の引数が範囲に入る。D15 の追記（2026-10-26、RV-C4 を受けて）・07-04・01-12・`CallReach.lean` の冒頭の記述はこれと一致する。
9. 01-12・07-04 の写し: `rangeCall` の行（root の分類、`standardCallHead`、出現表の一参照、標準表の一致までの走査、宣言の一致、Range の型引数なしと借用、`domainEntry`・`domainCallShape` の順、opName の早い拒否）は `BudgetScan.rangeCall`・`domainCallShape` の順序と一致する。振り分け表の未認定 call の行と record・recordUpdate の行は `BudgetAnalyze` と一致する。挙げた識別子（`domainExprsLength`・`domainPermutation`・`domainRange`・`domainIsPerm`・`domainContains`・`domainErase`・`selectArguments`・`fixedOwn`・`arithmeticOperationAt`・`WarningOperationSyntax`・`InSyntacticReach.arithmetic`・`analyze_warning_arithmetic`・`analyzeBody_warning_arithmetic`・`WarningsInCallReach`）は Lean に実在する。07-04 の A1 の限界に、操作をハンドラが差し替えるので具体規則を付けないことが書かれた。
10. 固定域の契約: `FixedDomainApi` はシフトだけで、七種と Byte の上端（8・16・32・64 の幅から1を引いた値、Byte は7）、符号付き四種だけの rightUnsigned を持つ。DomainExamples は20方向×2引数順×7区間の解析と4値の評価、最大値の左シフト、二表の不在・偽装・別キー、位置の重複・欠落、子の失敗・return を確かめる。
11. シフトの宣言の集合: 標準ライブラリのシフトの宣言は27件である（`Integer`・`Integer8`・`Integer16`・`Integer32`・`Integer64` の各3、`UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64`・`UnsignedInteger`・`Byte`・`UnsignedInteger8` の各2）。results.md の A19b の案の列挙（別名の宣言を含む）と一致し、存在しない符号なし・Byte の rightUnsigned を作らない Lean の契約とも合う。
12. 固定表への影響: reference-impact.json の body の差（7形、変更492行・追加14行、削除0、whole と summary は差なし）は results.md の表と一致する。差の形はすべて `helper[T]` の型引数付き funName を含む入力（`call`・`*_matchUnknown`）であり、原因の説明（`rangeStandardAt` の一参照）と合う。全ての入力に効くこの変化は A19a に割り当てられている。走査の正として results.md が挙げた関数はすべて実在し、`countList`・`rangeLength` は `domainCallShape` の中で呼ばれる。
