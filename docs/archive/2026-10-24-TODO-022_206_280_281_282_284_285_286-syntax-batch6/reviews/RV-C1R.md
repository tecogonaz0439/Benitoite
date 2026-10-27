# RV-C1R: RV-C1 への対応（C1Ra〜C1Rc）の再レビュー

- 日付: 2026-10-25
- 担当: Claude Code のサブエージェント（Opus 5.5）
- 対象: 前回のレビューの対象 `73d12d06` から san_benito の HEAD `31cadf63` までの差分（`formal/`、`docs/design/`、`plan.md`）。`formal/` の変更は `Interval/` の26ファイル（新設17）と `Benitoite.lean` の import だけである。`docs/design/03-interop/03-01-library-structure.md` の rustls の段落は S02 の別コミット（`d0ef480e`）の変更であり、本レビューの対象から外した。
- 照合した文書: `reviews/RV-C1.md`・`RV-C1-response.md`、README の「設計者の決定（2026-10-24、C1 のレビューの後）」「同（2026-10-25、用語）」、`decisions.md` の D8・D8a、`plan.md` の契約表・全構成子の分類表・「計画の変更（C1 のレビューを受けて）」「C1Rb」「C1Rb3」の各節、`c1ra/`〜`c1rc/` の `results.md`。中心命題は L02 の `f635f26d` の `Eval.lean` と比べた。処理系の呼び出し位置の確認のため `crates/benitoite/src/typeck/decls.rs` の `check` を読んだ。
- 方法: `git show 31cadf63:<path>` と `git diff` で読んだ。`lake build`・cargo・`scripts/check*.sh` は実行していない。既定ビルドの成功、`sorry` がないこと、公理依存の結果は各 `results.md` の記録に依り、本レビューでは再確認していない。`private/` と `docs/todo/` は読んでいない。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 5 |
| 軽 | 6 |

判定: C1 は条件付きで受け入れてよく、処理系（A01〜）へ進んでよい。RV-C1 の中1〜中5・軽1・軽4〜軽8 は意図どおりに解消し、軽2・軽3 は L22・L18/L19 へ申し送られた。中心命題 `NormalSoundness`・`WarningSoundness`・`Reached` の定義本文は `f635f26d` から変わっていない。新しい入口 `analyzeBody` の正常値・警告原因・位置・構文的な到達可能性の系は、任意の上限・初期消費・深さを量化し、完走や予算内を前提に加えていない。公理・`sorry`・`opaque` 宣言・`Builtins.Assumptions` の追加と変更もない。

条件は次の五つの中の所見の扱いである。いずれも中心命題・評価関係・公理の変更を要さない。中5（定義の範囲・名前・順序と Rust の型検査の対応）と中2（独立入力の入口環境の保存の計上）は A01 の着手前に方針を決め、中2 で Lean を変えるならその変更を A11 より前に終える。中1（独立入力の不変条件の補強）は A07 より前、中3（深さの除外を X02 で空虚にしない条件）と中4（件数の射影）は L27〜L29・X02・A12 より前に計画と契約表へ反映する。

## RV-C1 の各所見の解消の状況

| 所見 | 状況 | 確かめたこと |
|---|---|---|
| 中1 | 解消（残りは本レビューの中1・軽1） | `SyntacticReach.lean` の `concreteRule`・`syntacticReachExpr` は未知の根とその内側を false の印で残し、`unknown_warning_excluded` がそれを警告の位置から除く。`analyze_warning_syntactic_reach`・`analyzeBody_warning_syntactic_reach` は任意の Parameters で全出力警告を根の構文的な到達可能性へ制限し、評価導出を要求しない。`WarningsInSyntacticReach.located` が既存の `WarningLocated` を含意する |
| 中2 | 解消 | `analyzeBody` は定義名を受け取り、次キーを `bodyRootKey definition` に固定して `bodyRoot seed.body` を `expr` で解析する（`BudgetAnalyze.lean` 258〜275行）。`BudgetBody.lean` の三つの系は `Models (forget seed.initial) concrete` と根の `EvalPartial` から正常値と原因を、評価導出なしで位置を示す。独立例は最初の除算を番号1、番号列を0〜3に直した |
| 中3 | 解消（残りは本レビューの中3・中4） | `BudgetDiscovery.discover` が予算内で全53構成子を辿り、`discover_manifest` が完走時の発見順・次キー・対応表を `bodyManifest`・`numbered` に一致させる。`BudgetWhole.analyze` がモジュール・定義・親・別本体の順序と予算の切り替えを定める。fuel は明示入力とし、深さ停止を `StopClass.depth` に分けた |
| 中4 | 解消 | `embeddedBodies`・`discoverBodies`・`BudgetDiscovery.expr` から constE 自身の別本体を除いた。契約表「警告」に、元 NodeId・原因・一次位置による旧警告・新候補の統合を書いた |
| 中5 | 解消（案 b） | `BudgetChildren.unknownChildren` が expr の未知の場合と未対応の二項演算から子を `independentWith` へ渡す。`unknownChildren_walk` が元の先行順の番号の消費を、`independentWith_silent`・`captureIndependent_head` が親の候補と未対応の印の復元を示す |
| 軽1 | 解消 | 01-12 と契約表「比較報告」に、unidentified は停止した操作が番号付けだったことを表すと書いた |
| 軽2・軽3 | 申し送り | plan の L22・L18 の節に修正候補と停止条件を書いた |
| 軽4 | 解消 | 01-12「区間解析の予算付きの局所走査」に Lean の関数定義を正とすると書き、A11・X02 の手順にも加えた |
| 軽5 | 解消 | 01-12「区間解析のIntegerパターンと腕入口」・07-04・A09 に照合値の型の制約を書いた |
| 軽6〜軽8 | 解消 | 07-04 の入口の区別、Unmodeled の負号の説明、独立例の番号を直した |

## 中

### 中1 独立入力の不変条件が、忘却した入口環境と本体の番号列での位置を含まない（読めば確定）

- 場所: `BudgetIndependent.lean` 31行の `IndependentResult.Sound`。`BudgetIndependentSound.lean` 89行の `captureIndependent_head`、410行の `analyzeExpr_independent_sound`、425行の `analyzeBody_independent_sound`。
- 問題: D8a の「外の事実を持ち込まない」と、独立入力の警告キーが元の出現を指すことは、入口の定理として示されていない。
  - 入口環境: `captureIndependent_head` は、一回の捕捉で先頭に積んだ記録について `entry.initial = some initial → initial = forget env` を示す。しかし `IndependentResult.Sound` はこの条件を含まず、`SavesInputs` が合成するのは `Sound` だけである。したがって入れ子を含む全記録について入口環境の整数位置が Top であることは、`analyzeBody_independent_sound` から得られない。`Sound` の正常値と原因の保証は「記録した環境を満たす具体環境」に条件付けられている。記録した環境に狭い区間が残っていると、その条件は親の評価導出から満たせない（親の未知の規則は子を評価しない）。入口環境が Top だけであることが、型どおりの任意の環境で保証が使えるという意味を支えている。
  - 位置: `Sound` の構文的な到達可能性は `entry.key` と `entry.input` に相対的である。記録の開始キーと入力が本体の `numbered (bodyRootKey d) (bodyRoot body)` の連続した区間に一致することは、`independent_walk`・`unknownChildren_walk`・`captureIndependent_head` の組み合わせから導ける見込みだが、系として置かれていない。A07 は `independentRev` の候補のキーから元 NodeId を引くので、この対応が要る。
  - 番号を二重に消費しないこと（`unknownChildren_walk` が親の番号列を `(surfacePreorder source).tail` と示す）と、子の値・return・絞り込み・候補を親へ戻さないこと（戻り値の型が Unit、`independentWith_silent`、`captureIndependent_head` の警告列と未対応の印の復元）は、定理で示されている。
- 修正案: `Sound` に `∀ env, entry.initial = some env → ∀ i, integerAt env i = top`（または `forget env = env`）を加えるか、別の不変条件を置いて `SavesInputs` と同じ形で合成する。本体入口には、`∀ entry ∈ (analyzeBody …).context.independentRev, ∀ w ∈ entry.warningsRev, LocatedIn (bodyRootKey d) (surfacePreorder (bodyRoot seed.body)) w` を置く。可能なら、記録の番号区間 `numberFrom entry.key (entry.input.syntacticReach.map Prod.snd)` が本体の `numbered` の連続部分であることも示す。01-12 の言明の表へ写す。A07 より前に済ませる。

### 中2 独立入力ごとに忘却した入口環境を保存項目として計上するため、保持数が「未知の子の数×局所位置の数」で増え、検査全体の終わりまで残る（増え方は読めば確定、既存の入力での規模は実行しないと分からない）

- 場所: `BudgetIndependentRun.lean` 15〜21行の `prepareIndependent`（`forgetSlots` は位置ごとに `consSlot` で一項を確保し、その全数を `Budget.save` で保存へ移す）。`Budget.lean` の `finishBody`（保存項目を全体の saved へ移し、返さない）。plan の契約表「独立入力の保存」「予算の交換」、A11、U01。
- 問題: 独立入力は、呼び出しの頭と引数、要素、オペランドなど、未知の形の直接の子ごとに作られる。入れ子の未知の形では、内側の子でも同じ長さの環境をもう一度忘却して保存する。現実のスクリプトではほとんどの式が呼び出しを含むので、保存項目はおおむね「本体の出現数×その位置の局所位置の数」で増える。保存項目は本体の終了後も全体の保持として残る。D16 の上限は本体10万項・全体100万項であり、例えば局所位置が30ある本体で独立入力が3,400件あれば本体上限に届く。標準ライブラリの本体も解析の対象に含まれる（U01「標準本体の解析除外は未実施」）ので、全体上限にも近づきうる。加えて `BudgetWhole.runDefinition` は親の解析の後に発見で全出現を再び `identify` し、識別の対応表をもう一組保存する。U01 は「通常入力で上限に当たる入力が0件」を完了条件にしているが、そこで超過が見つかると、Lean の計上の定義・証明・A11・X02 の期待値をやり直すことになる。
- 修正案: A01 の着手前に、取りまとめが次のどちらかを選ぶ。(a) 現行の計上を保ち、代表的な入力（標準ライブラリと examples）で「未知の子の数×局所位置の数」を静的に数える簡単な見積もりを先に行う。(b) Lean を変え、忘却した環境を `independentWith` の scope の一時項目として子の解析の終了時に返す。`IndependentResult.initial` は証明用の欄として計上せず、Rust は保存しない、と 01-12 に書く。発見の識別の対応表の二重保存も同じ判断の対象にする。(b) を選ぶなら A11 より前に済ませる。

### 中3 深さ停止の除外は検査全体を単位とし、fuel は列の長さでも減るのに、X02 で除外が0件であることを要求していない（読めば確定）

- 場所: `BudgetWhole.lean` 258行の `comparisonEligible`。`BudgetChildren.lean` 14行の `childExprs`、`BudgetAnalyze.lean` 131行の `block`（列の要素・文ごとに fuel を一つ減らす）。plan の契約表「比較報告」「独立交換」、X02 の手順。
- 問題: C1Rc の判断（深さ停止を別分類にし、Rust との一致の受け入れから外す）は、Rust に深さの打ち切りがない以上妥当であり、それ自体は X02 の価値を損なわない。fuel は `| 0 => throw .depth` の分岐でだけ使われるので、深さで止まらない限り fuel の値は結果に影響しない構造になっている（証明はない）。ただし次の二点が計画にない。
  - `comparisonEligible` は Report 全体を単位とするので、一本体で深さ停止が起きると、その検査の全本体が比較から外れる。X02 は「全結果がTopであるだけの一致は受け入れない」と定めるが、除外された結果だけで受け入れが成立しうることは塞いでいない。fuel を小さく選ぶと、比較の対象が黙って減る。
  - 名前は「深さ」だが、fuel は入れ子の深さだけでなく、Exprs の要素・Block の文・腕・節の列の長さでも減る。長いリストや長い本体では、入れ子が浅くても fuel が尽きる。fuel の選び方の手引きがない。
- 修正案: 契約表「比較報告」と X02・L28 の完了条件に、(1) 固定した corpus の全入力で `comparisonEligible` が true であることを要求し、偽が出たら fuel を増やして選び直し、件数を報告する、(2) fuel は列の長さも消費することと、選び方（例: 入力の `surfaceSize` の総和に定数を加えた値、または十分大きな定数）を書く。01-12「区間解析の検査全体の駆動」にも (2) を一文で書く。

### 中4 比較報告と A12 の件数を、BudgetWhole.Report からどう求めるかが定まっていない（読めば確定）

- 場所: `BudgetWhole.lean` 241〜256行の `bodyStops`・`phaseStops`・`stopCount`。plan の契約表「比較報告」（型検査成功・未対応・本体予算超過・全体予算超過・番号未取得の件数）と「非実行報告の提供」（`unsupportedBodies/bodyBudgetExceeded/wholeBudgetSkipped/unidentifiedBodies`）。
- 問題: Lean が定めるのは停止の事象の列と分類ごとの数だけである。利用者と X02 が読む「本体の件数」との対応がない。
  - 一回の全体上限の到達が複数回数えられる。親の `analyzeBody` が事前判定で止まると `bodyStops` に一件入る。続いて `runDefinition` の `exhausted` が `embedded.stopped` に、次の定義または次のモジュールでの `exhausted` が `Report.stopped` に同じ理由を入れ、`phaseStops` の wholeBudget は二件になる。
  - `wholeBudgetSkipped` が数える単位（残った定義の数、発見済み未解析の項目、環境未作成の項目、未発見の別本体）が決まっていない。Lean は未発見の本体数を求めない。
  - `unsupportedBodies` は Coverage の unsupported を数えるのか、独立入力の `unsupported` も含むのかが書かれていない。
  - Rust が同じ数を出すには、駆動の構造をそのまま写すしかないが、契約表にはその旨も射影の定義もない。
- 修正案: L27 または A12 の前に、Lean に Report から各件数を求める射影（例: `unsupportedBodies r`・`bodyBudgetExceeded r`・`wholeBudgetSkipped r`・`unidentifiedBodies r`）を定義するか、契約表に各件数が Report のどの欄から何を数えるかを書く。`phaseStops` は事象の列であって本体の件数ではないことと、同じ到達を重ねて数えうることも書く。

### 中5 Lean の Definition の範囲・名前・順序と、Rust の型検査の順序との対応が契約表にない（読めば確定）

- 場所: `BudgetWhole.lean` 17行の `Definition`（kind は function または constant）と 185行の `definitions`。plan の契約表「解析入力と出力」（ソース順・定義順）と「呼ぶ位置と共有状態」（`generate::function` の後処理から呼ぶ）。`crates/benitoite/src/typeck/decls.rs` の `check`（838行で `consts::check` を全モジュールについて先に実行し、その後に `ast.decls` の順で `Item::Fn` と `Item::Impl` のメソッドを検査する）。01-12 の `QualifiedDefinition`（元の定義名の一意性は入力の条件）。
- 問題: A01・A02 の担当は次の三点を文書から一意に決められない。全体予算は本体をまたいで共有するので、順序の違いは全体上限に達する入力で X02 の不一致になる。
  - 定数の宣言を Definition として解析するか、するならどこで呼ぶか。「呼ぶ位置」は関数の本体だけを挙げる。Rust の定数の検査は全モジュールの関数より先に一括で行われるので、そこで呼ぶと Lean の「定義順（関数と定数が交互に並ぶ）」と一致しない。
  - impl のメソッドの本体を Definition に含めるか。含めるなら、同じモジュールの複数の impl にある同名のメソッドへ一意な定義名をどう付けるか（独立交換は重複した定義を拒否する）。
  - テストの本体など、関数・定数以外の本体の扱い。
- 修正案: A01 の着手前に契約表「解析入力と出力」へ、Definition にする宣言の種類、impl のメソッドの定義名の作り方、定数と関数を合わせた順序（例: 型検査中は BodyInput を集めるだけにし、全本体の型検査の後に `ast.decls` の順で駆動する）を書き、「呼ぶ位置と共有状態」をそれに合わせる。

## 軽

### 軽1 整数でない照合値の match の腕も構文的な到達可能性に入り、そこでの警告は空虚に健全になりうる（読めば確定）

- 場所: `SyntacticReach.lean` 17行の `concreteRule`（`.matchE` を常に true とする）。`Eval.lean` の `matchOtherNormal`・`matchOtherFailed`（腕を評価しない）。
- 問題: 照合値が整数以外の値になる導出では腕の事象が trace に現れないので、そうした腕に置いた警告は `Reached` を持たず、`WarningSoundness` と `InSyntacticReach` をともに満たす。照合値の型が構文にない以上、腕を含めること自体は RV-C1 の提案どおりであり、01-12 も「腕の実際の到達…は結論しない」と書いている。ただし、現在の解析が非整数の照合値の腕に警告を出さないことは、定理ではなく定義の性質である。
- 修正案: A09 の完了条件と X02 の照合に「近似が整数だけでない照合値の match の腕には、親の警告を出さない」を加える。01-12 の concreteRule の段落に、この部分は定理で区別できない残りであることを一文で書く。

### 軽2 構文的な到達可能性を「領域」と略す記述が残り、01-12 には改名前の名前 region が残る（読めば確定）

- 場所: 01-12「区間解析の予算付きの式とフロー」の構文的な到達可能性の段落と言明の表（「追加警告がその領域に属する」「領域の契約」など）、「区間解析の独立入力の保存と保証」の「region はそれぞれ syntacticReachExpr source または…」。07-04「01-12 との対応」の同じ段落。plan の契約表「独立入力の保存」（「位置・領域の保証」）。
- 問題: 「領域」は 01-12 で既に整数の閉区間の領域（domain）と予算の `BudgetScan.region`（作業領域）に使われている。設計者が決めた用語の略記として三つ目の意味を与えると、AGENTS.md の「同じ概念に別の語を使わない」に反する。Lean の名前は `IndependentInput.syntacticReach` であり、`region` は `BudgetScan.region` と衝突する。
- 修正案: 該当箇所の「領域」を「構文的な到達可能性」に、01-12 の「region はそれぞれ」を「syntacticReach はそれぞれ」に直す。

### 軽3 用語集の「構文的な到達可能性」の 07-04 へのリンク先に、その記述がない（読めば確定）

- 場所: `00-04-glossary.md` の当該行のリンク `07-04-formal-semantics.md#区間解析の対象構文の評価関係`。
- 問題: 07-04 の構文的な到達可能性の段落（285行付近）は「01-12 との対応」の節にある。
- 修正案: リンクを `#01-12-との対応` に直す。

### 軽4 「未到達の枝には新しい警告を重ねない」が、独立入力では外の事実で死んだ枝を含まない（読めば確定。利用者に出る件数は実行しないと分からない）

- 場所: plan の契約表「警告」（「未到達の枝と子のBottomには新しい警告を重ねない」）。D8a。
- 問題: 独立入力は外の事実を忘れるので、`z = 1` の後の `f(if z == 0 { 10 div z } else { 0 })` では、外の事実なら到達しない枝の除数0に警告が出る。到達すれば失敗するので健全性は保たれ、D19 の「警告してよい」にも反しない。しかし契約表の「未到達」は、各入力の事実に対する未到達という意味に変わった。
- 修正案: 契約表「警告」と 01-12 に、未到達の判定は各入力が持つ事実に対して行うことを一文で書く。U01 の棚卸しでこの種の警告の件数を観察する。

### 軽5 統合する警告の「解析順で最初」が、親の警告列と independentRev をまたいで定まっていない（読めば確定）

- 場所: plan の契約表「警告」（「新候補だけの組は解析順で最初の候補を採る」）、A07。
- 問題: 親の `warningsRev` と各独立入力の `warningsRev` は別の列に保存され、保存の時刻の前後は出力から復元できない。同じ元 NodeId を持つ候補は、例えば親の constE と引数の中の constE から生じる。候補の注記（区間・補助位置）が異なりうるなら、X02 の「まとめた後の利用者の警告」の照合で選び方の違いが不一致になる。
- 修正案: 契約表に決定的な順序（例: 本体の順、次にキーの surfacePreorder、同じキーでは親を先）を書く。

### 軽6 検査全体の駆動の順序と網羅は固定例だけで確かめており、BudgetReach の maxHeartbeats に理由の注記がない（読めば確定）

- 場所: `BudgetWhole.lean` の `runEntries`・`definitions`。`BudgetReach.lean` 184行の `set_option maxHeartbeats 800000 in`。
- 問題: 停止がない場合に、各定義の親と `bodyManifest` の全別本体を順に一度ずつ解析することは、`BudgetWholeExamples` の #guard だけで確かめている。01-12・07-04 はこれを実行比較と明記しており、Lean の定義を X02 の正とする用途には足りる。maxHeartbeats は解析の fuel や予算を変えないが、既存の二か所と違い理由の注記がない。
- 修正案: 余力があれば、停止のない Report の `bodyOutputs` の定義名の列が各定義の親と `bodyManifest` の順に一致することを示す定理を置く。maxHeartbeats の行に理由の注記を加える。

## 確かめて正しかった主な事実

- 中心命題: `NormalSoundness`・`WarningSoundness`・`Reached`・`AnalysisResult`・`IntervalWarning`・`WarningCause`・`WarningCause.toFailure`・`TargetOperation`・`EvalEvent`・`Failure`・`EvalOutcome`・`EvalInput` の定義本文を `f635f26d` と機械的に比べ、一致した。`Eval.lean`・`Sound.lean` は `73d12d06` から変わっていない。
- 仮定: 追加行に `axiom`・`sorry`・`admit`・`opaque` 宣言・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def` はない（grep した。`.opaque` は型の構成子である）。`Interval/` と `Benitoite.lean` 以外の `formal/` に変更はなく、`Builtins.Assumptions` も変わっていない。新しい `maxHeartbeats` は `BudgetReach.lean` の一か所だけである。記録上の公理依存は propext・Classical.choice・Quot.sound の範囲である。
- 本体入口: `analyzeBody` の三つの系と `analyzeBody_warning_syntactic_reach`・`analyzeBody_independent_sound` は、全体上限の事前停止と忘却中の停止を `analyzeBody_property` で扱い、停止時の正常値を Top、警告を空とする。Models の対象は `forget seed.initial` であり、型どおりの具体環境で満たせる。
- 独立入力: `prepareIndependent` は `forgetEnv` で整数位置だけを Top にし、標準束縛表・同定表と非整数位置の型を保つ。`captureIndependent` は子を空の警告列と false の未対応の印で始め、終了後に親の列と印を復元し、予算・次キー・識別対応・入れ子の記録は子の終了状態を引き継ぐ。子の停止は同じ理由で親へ伝わり、親の Coverage の停止として一度だけ数えられる。`IndependentResult.Sound` は型を全称量化し、忘却中の停止では空の候補を要求する。with の本体はリソースの位置0を加えた環境を忘却して解析し、ラムダ・lazy・節は番号だけを辿る。`unknownChildren` の振り分けは 01-12 の表と構成子ごとに一致する。
- 構文的な到達可能性: `concreteRule` の true の形は評価関係の具体規則を持つ形と一致し、`concreteRule_known` がそれらに `UnknownAt` が成り立たないことを示す。未対応の二項演算と負号は false であり、解析の `unknownChildren` の対象と一致する。定義・用語集・01-12 は実行の到達可能性と区別すると明記している。改名前の名前は Lean・01-12・07-04・用語集・plan に残っていない（01-12 の「region はそれぞれ」を除く。軽2）。
- 発見と駆動: `BudgetDiscovery.discover` は constE の子を `clearLocals` で辿り、同じ handle の全節を内側の境界より先に保存し、節の開始位置の先読みも計上する。`saveEntry_top` は保存した入口の整数位置が Top であることを示す。`BudgetWhole.runDefinition` は入口作成・親解析・発見・待ち行列を一つの本体予算で行い、その後に別本体ごとに本体予算を切り替え、全体の消費を引き継ぐ。`entryEnv` は別本体の同定キーを元の定義の番号へ戻し、`entryEnv_parent` が `parentKey` との一致を示す。
- 文書: 01-12 の「区間解析の予算付きの別本体の発見」「区間解析の検査全体の駆動」「区間解析の独立入力の保存と保証」と 07-04 の対応表は、Lean の定義名・場合分け・定理名に対応する。plan の全構成子の分類表は `unknownChildren` と `concreteRule` に一致する。

## 読めば確定する所見と、実行しないと分からない点

- 読めば確定: 中1・中3・中4・中5、中2 の増え方、軽1〜軽3・軽5・軽6、軽4 の機構。
- 実行しないと分からない点: 既定ビルドの成功・`sorry` がないこと・公理依存（各 results.md に依った）。中1 の系が既存の補題から短く導けるという見込み。中2 で既存の入力が D16 の上限に近づく規模。中3 で深さで止まらない限り fuel の値が結果に影響しないこと（構造からの見込みで、証明はない）。軽4 で利用者に出る警告の件数。
