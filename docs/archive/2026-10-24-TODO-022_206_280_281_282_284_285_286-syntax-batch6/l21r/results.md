# L21R の作業結果

再開の着手: 2026-10-26 02:31:17 JST。終了: 2026-10-26 03:12:17 JST。所要時間: 41.0分（2461秒）。最初の起動は約14.4分であり、その記録は末尾の「最初の起動の確認」に残す。

状態: **担当範囲の実装と指定 work を完了した。** 再開指示に従い案 (b) を実装した。既存の公開定理の言明・型と参照定義を保ち、未認定 call の内側を親の警告から除く別の公開定理を、式・共通入口・本体・独立入力・検査全体へ接続した。取りまとめによる独立レビューと C3 の受け入れは未実施である。

## 基準と作業の条件

B_WORK・HEAD は `d1d706eaa3a181189b512057a5b3f08c110fe241`、枝は `mod012/L21R`。再開時には、最初の起動で残した01-12・07-04の訂正と l21r/ の確認資料があった。これらを引き継いだ。private/ とそれを指すリンクは読まず、git の変更操作・担当の委任・Rust の変更・固定表の再生成は行っていない。公開の rtk・japanese-tech-writing・test-audit を適用した。

計画の L21R の行と RV-C3-response は案 (a) を先に記しているが、今回の再開指示が案 (b) を明示したため、それに従った。局所記法で旧定理の型の変化を隠す方法と、保証の弱まりを受け入れる案 (c) は使っていない。中心二命題・旧主定理・公理を変える必要はなく、停止条件には当たっていない。

## 変更した範囲

| ファイル | 内容 |
|---|---|
| [CallReach.lean](../../../../formal/Benitoite/Interval/CallReach.lean) | 証明用の Scope（番号を占める sources と警告の述語 allows）を定義した。call では、元のキーの rangeCallAt が none でない場合だけ根と引数の述語を認める。callee は番号だけを占め、入れ子の call でも認定の条件を保つ |
| [CallTables.lean](../../../../formal/Benitoite/Interval/CallTables.lean) | 局所位置・定数・忘却・bind・パターン・条件の絞り込みと合流・整数と Result の腕の環境操作で、認定に使う二表が保たれることを証明した |
| [BudgetCallReach.lean](../../../../formal/Benitoite/Interval/BudgetCallReach.lean) | 六つの内部解析について任意予算の追加警告の契約を合成した。前回の確認資料の expr_unrecognized_call_silent_at も既定の証明へ接続した。成功・停止とも既存の警告列を保ち、新しい追加分だけに今の入力の範囲を要求する |
| [CallReachSound.lean](../../../../formal/Benitoite/Interval/CallReachSound.lean) | 式・中心命題と同じ共通入口・本体の全出力警告に別の保証を与えた。根が未認定 call の場合は警告列が空になる系も加えた |
| [CallReachIndependent.lean](../../../../formal/Benitoite/Interval/CallReachIndependent.lean) | 既存の IndependentResult.Sound を変えず、記録した入口環境・元キーによる CallsRecognized を別に保証した。入れ子と停止後の保存列にも合成した |
| [CallReachWhole.lean](../../../../formal/Benitoite/Interval/CallReachWhole.lean) | runBody・別本体の待ち行列・定義・モジュールの順に保証を保存し、検査全体が返す bodyOutputs の全本体の親と独立入力へ接続した。別本体の認定には実際の entryEnv を使う |
| [SyntacticReachExamples.lean](../../../../formal/Benitoite/Interval/SyntacticReachExamples.lean)・[Benitoite.lean](../../../../formal/Benitoite.lean) | 既存の例を保ち、標準表・出現表・キーを変えた認定と除外、同じ call の親／独立入力への候補の振り分けを追加した。新しい六モジュールを既定 import に含めた |
| [01-12](../../../design/01-spec/01-12-core-calculus.md) | concreteRule の true に call を挙げ、concreteRule_known の callKnown の前提と、構文だけの候補範囲の限界を訂正した。新しい定義・公開定理を写し、旧定理と合わせて未認定 call の内側を親から除く保証を書いた。前回の中1(a)(b)・軽3の訂正も保持した |
| [07-04](../../../design/07-quality/07-04-formal-semantics.md) | A1 の型注記の限界（軽1）を保持し、構文的な到達可能性の同じ説明を01-12と揃えた。追加保証の範囲と限界も記した |

新しい主要な公開言明は次のとおりである。

- `analyzeExpr_warning_call_reach`・`analyze_warning_call_reach`・`analyzeBody_warning_call_reach`: 全警告が、入口の二表と元のキーによる CallReach の allows を満たす。評価導出・Models・完走・予算内の前提を加えない。
- `analyzeExpr_independent_call_reach`・`analyzeBody_independent_call_reach`: 保存した各入力が、自身の初期環境と元キーによる IndependentResult.CallsRecognized を満たす。忘却中の停止は空の候補、解析中の停止は保存済みの候補を対象とする。
- `BudgetWhole.analyze_warning_call_reach`: 全体が返す全本体の親の候補と保存済みの全独立入力を同時に保証する。未着手の本体の保証を主張しない。
- `CallReach.unrecognized_call_excluded`・`analyzeExpr_unrecognized_call_warnings`: 未認定 call では allows が成り立たず、その call を根とする式の公開入口の警告列は空である。一般の入力の内側にも CallReach.expr の再帰的な認定条件が残るので、根だけの特殊例に限定した保証ではない。

既存の構文だけの定理では call の引数が候補に残る。その定義を変更せず、追加定理の call ごとの認定条件と合わせる形で C2 相当の除外を保証する。既存の正常値・警告原因・位置の保証はそのまま使う。

## 中心命題・既存の言明・参照定義の差分

[照合スクリプト](resume-contract-check.py)・[照合結果](resume-contract-check.json)で、開始版の formal と固定表318ファイルのうち316ファイルがバイト単位で一致し、残る二つは umbrella の import 6行と SyntacticReachExamples 末尾の49行の追加だけであることを確認した。**既存の名前付き定理3,342件、NormalSoundness・WarningSoundness の本文、旧公理・Builtins.Assumptions、既存の主定理の言明は変更していない。** 既存定理の定義ファイルとその import も不変であり、言明が参照する型も変えていない。[型の照会](resume-axioms.log)でも、旧構文的到達可能性の三定理と独立入力の二定理が旧型のままであることを確認した。

| 参照する定義・言明 | 今回の差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | なし | 量化・前提・結論と本文を保持する |
| EvalPartial・EvalBlock・EvalArguments・EvalResultArms、Unmodeled・UnknownAt | なし | 未知を具体規則へ置き換える変更も今回はない。評価の導出と未知の範囲を保持する |
| ConcreteValue・ConcreteEnv・StandardRule.resultType/argumentType/finish | なし | 具体値・評価の型条件を変更しない。型注記の実ソースとの一致は A18a の確認のままである |
| AbstractEnv・AbstractSlot・SlotModels・Models・topSlot | なし | Models を強めず、二表の保存は既存の環境操作から別の補題で導く |
| targetOperationAt・Reached・WarningLocated | なし | 警告対象・位置・到達後の拒否原因を保持する |
| concreteRule・syntacticReach*・InSyntacticReach・WarningsInSyntacticReach | なし | call の引数を含む構文だけの候補範囲を保持する。未認定の内側の排除は新しい CallReach と別定理で加える |
| IndependentResult.Sound・既存の analyzeExpr_independent_sound / analyzeBody_independent_sound | なし | 既存の連言を変更せず、新しい CallsRecognized を別定理で同じ保存列へ与える |
| CallReach.Scope・expr / block / exprs / armList、WarningsInCallReach、IndependentResult.CallsRecognized | 新設 | 任意予算の既存解析に、call の認定を要する追加の結論を証明する。旧定理の前提を強めない |
| analyzeBase*・BudgetAnalysis の実行定義・BudgetScan.range*・Budget・EvalClosed | なし | 解析出力・操作数・保持数・停止位置・評価器を変えない |
| Core・Release・Surface の主定理、Builtins.Assumptions、lakefile.toml | なし | 旧保証と -M 12288 を保持する |

[公理の照会入力](resume-axioms.lean)・[出力](resume-axioms.log)で、中心二定理と新しい主要公開定理の依存が propext・Classical.choice・Quot.sound だけであることを確認した。新しい公理・sorry・admit・native_decide は追加していない。指定 work の formal_build の sorry 拒否も成功した。

## 例の作成時の関門と途中の失敗

持ち主は、構文だけの候補と、認定を要する追加保証の境界である。同じ call の標準表・出現表・元キーを変えた場合と、call 自身が独立入力となる場合を確かめる。既存の SyntacticReachExamples は call を含まず、BudgetChildrenExamples は実際の警告列を確かめても追加の証明用の範囲を確かめない。既存の例を保ち、専用の本番フラグ・差し込み口・解析器の引数は加えていない。

これは解析の振る舞いの修正ではなく、欠けた保証の追加である。最初の起動の [baseline-regression.log](baseline-regression.log) は、旧候補範囲だけで引数を false とする主張が開始版で失敗する記録として残す。案 (b) は旧候補範囲を保つため、その入力を「修正後に通る退行テスト」とは扱わない。新しい例は、旧候補には除算が残ることと、別の保証では未認定の内側を除くことの両方を確かめる。

定義と合成証明の途中では、Scope と List の取り違え、空の Scope の合成、二表の一致の引き渡し、同名の旧補題の参照、match の結果の分解で終了1になった。言明・前提を緩めず修正し、各試行の call-reach-*.log・call-tables-*.log・call-proof-*.log・call-independent-*.log・call-whole-*.log に残した。最後の型・公理の照会と既定ビルドは成功している。

| 例の試行 | 終了・結果 | 原因の確認と修正 |
|---|---|---|
| call-examples-01 | 手動中断、終了130。時間と中断前 stdout は保存できなかった | 当初は候補述語全体の kernel 計算を疑ったが、後の切り分けでこの帰因は訂正した。大きい候補述語の Decidable を展開する形は小さい認定表の計算と構成的な証明へ変更した |
| [call-examples-02](call-examples-02.json) | 25秒の上限で終了124、プロセス群の終了を確認 | 上限を引き上げず、式を分割して原因を調べた |
| [call-examples-03](call-examples-03.json)・[04](call-examples-04.json)・[05](call-examples-05.json) | 終了143、15.45 / 15.99 / 13.09秒 | 終了値は SIGTERM に対応する。送信元は未確認であり、300秒や25秒の時間上限による終了とは記さない。各試行で小さい証明の書き方・比較の形を変え、最後に局所関数の型を明記した |
| CallProbeExamples の分割検査 | 除外0.334秒、認定0.352秒、候補0.399秒、未認定の実行0.416秒、認定の実行0.409秒、入れ子の実行0.419秒。すべて最終形は終了0 | 個別の述語・解析器の実行は短時間で終わった。小さい証明には型の推論と書き換えの終了1もあり、call-probe-*.log に保存した |
| [call-examples-06](call-examples-06.json) | **終了0、0.414秒** | 直前の形からの差は `entries : Context → List (Nat × List Nat)` の型注記である。全体を成功させ、評価器で比較する #guard と、小さい認定表だけの kernel の decide に限定した |

解析器・評価器を decide・decide +kernel・rfl・simp で具体の入力について実行する証明は加えていない。実解析の比較は #guard の Bool 式で行う。局所関数の結果型を省略すると、#guard であっても検査が長時間化することを後続へ申し送る。Lean のプロセスを重ねず、終了状態を確認してから次へ進んだ。

新しい Lean の定義・証明は六ファイル1,646行、例は49行、umbrella は6行の追加である。既存のテストの削除・期待値の緩和・Rust のテストや実装の変更はない。

## 検査と実測

Lean は固定版4.34.1。単体の確認は `lake env lean -M 6144`、例は25秒、ほかは300秒を基本上限とし、各プロセス群の停止と終了を確認する local-check.py を使った。ビルドは lakefile.toml の -M 12288 を保持した。共通の排他ロックを取り、依存順の確認から work の終了まで、別の Lean や別の作業を並行させていない。

| 実行 | 終了・結果 | 外側の時間と記録 |
|---|---|---|
| 各追加モジュールの単体検査 | すべて最終形は0。内部合成は約2.0秒、独立入力の保存は約1.3秒、公開入口と全体の保存は約0.3秒 | local-check.py と各 call-*.json / log |
| 依存順の逐次ビルド | 0、258モジュールを確認。古いものだけ一つずつビルド | 49.940秒。[出力](resume-sequential-build.log)・[記録](resume-sequential-build.json) |
| 既定ターゲットの最新状態の確認 | 0、351ターゲットが最新。既定ビルドが未ビルドの Lean 依存を並行に開始する状態ではない | 0.153秒。[出力](resume-default-up-to-date.log) |
| 指定 work と同じ基準・対象の dry-run | 0、spec_tally・spec_examples・formal_build の三単位だけを選択 | 0.012秒。[出力](resume-dry-run.log) |
| `/usr/bin/time -l` で包んだ指定 work（一度） | **本体0、計測器0、三単位成功** | **69.777秒**。[出力](resume-work.log)・[記録](resume-work.json) |
| work 内の仕様例（spec_examples） | 7件成功、失敗0・ignored 0 | 3.12秒、work に含む |
| work 内の仕様対応表（spec_tally） | 自己検査・集計成功、初回リリースの完了条件の未記入は none | work に含む。未参照節の一覧は従来どおり表示する |
| work 内の既定 Lean ビルドと sorry 拒否（formal_build） | 0 | work に含む |
| 旧型・公理の照会 | 0 | 0.631秒。[入力](resume-axioms.lean)・[出力](resume-axioms.log) |
| 契約・固定表・差分の照合、git diff --check | 0 | [照合結果](resume-contract-check.json) |

**最大常駐量（maximum resident set size）は4,002,938,880バイト（約3.73 GiB）。** real/user/sys は69.77 / 428.89 / 47.96秒であった。最初の起動では sysctl の拒否で取得できなかったが、今回の time は終了0で数値を得た。

work の実行指定は次のとおりである。`<作業>` は本ディレクトリ、CARGO_HOME は前回と同じ書き込み可能な既存キャッシュである。

```sh
python3 <作業>/sequential-build.py
python3 <作業>/resume-run-checks.py default-up-to-date
scripts/check.sh --level work --base d1d706eaa3a181189b512057a5b3f08c110fe241 --only formal_build,spec_examples,spec_tally --dry-run
env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <作業>/resume-run-checks.py work
```

最後の実行器は `/usr/bin/time -l /bin/zsh <作業>/run-work.sh` で包み、本体の終了を L21R_CHECK_EXIT_STATUS として別に保存する。dry-run も実際には resume-run-checks.py 経由で同じ指定を実行した。

## 固定表・計画との差と申し送り

**A11 の固定表7ファイルはすべて開始版とバイト単位で一致し、作り直していない。** 解析器・評価器・予算・固定入力・生成元も不変であり、今回新たに期待値が変わる形は0件である。このため、新しい Lean での固定入力の再計算は行っていない。L20d の既存の影響（本体47形、全体・集計各7形）は [先行作業の影響表](../l20d/reference-impact.md)を引き継ぐ。

| 担当と残る範囲 | 検査・レビュー・受け入れまでの手順 | 見込み |
|---|---|---|
| 取りまとめ・C3 | 案 (b) の別の保証の定義と各入口への接続、旧型と参照定義の不変、公理、01-12・07-04の写しを独立レビューし、C3 の受け入れを判断する | 不明 |
| A16a〜A18a | L20d の固定表への影響、Range の走査順・回数と保持、親と独立入力の分類、条件環境の合流での忘却、実ソースの型注記と標準表の型の一致を Rust と交換へ揃える。検査は計画の各枝に従う | 計画の各枝の見込み。今回の作業では着手しない |

コミット・取り込み・docs/todo の更新・保管・公開は行っていない。

## 最初の起動の確認

着手: 2026-10-26 02:15:22 JST。停止: 2026-10-26 02:29:46 JST。所要時間: 14.4分。

状態: **未完。公開定理の言明を保つ条件と、環境に依存する候補の接続方法の確認で停止した。** RV-C3 の中2 は解消していない。既定ビルドと指定 work は成功したが、C3 の受け入れや A16 へ進む条件を満たしたとは扱わない。見込み時間や対象の大きさを理由に区切ったものではない。

### 基準と範囲

B_WORK・HEAD は `d1d706eaa3a181189b512057a5b3f08c110fe241`。枝は `mod012/L21R`。開始時の作業ツリーに差分はなかった。private/ とそれを指すリンクは読んでいない。git の変更操作と担当の委任は行っていない。公開の rtk・japanese-tech-writing・test-audit を適用した。

### 停止した点

[公開定理の型の照会](call-silent-probe.log)で、式と本体の結論が次の形であることを確認した。

```lean
InSyntacticReach key (syntacticReachExpr source) warning
InSyntacticReach (bodyRootKey definition)
  (syntacticReachExpr (bodyRoot seed.body)) warning
```

いずれの結論も抽象環境を引数に取らない。同じ source と key を、標準表・出現表の異なる二つの環境で解析しても、これらの結論の候補範囲は同じである。一方、案 (a) が求める候補範囲は rangeCallAt の認定によって変わる。通常の明示的な引数の追加では、式の公開定理に env、本体の公開定理に seed.env と開始キーを渡す必要があり、言明の文字列を変える。

局所記法で env・キーを補えばソース上の文字列だけは保てるが、展開後の公開定理の型には環境依存の引数が入る。これを「言明を保つ」と扱ってよいかは依頼文から確定できなかった。既存の公開言明を変えないよう求める停止条件に関わるため、記法を使って変更を見えにくくする実装は行っていない。非同期の質問として、局所記法による案 (a) を認めるか、案 (b) の別定理を加えるかを提示した。回答はこの記録時点では未着である。

案 (b) へ切り替える時間上の条件（案 (a) の証明が8時間以内に収まらないとの判定）を、今回のインターフェースの確認と同一視していない。案 (b) を完了したとは記さず、保証の弱まりを受け入れる案 (c) も選んでいない。中心二命題や公理に問題が見つかったわけではない。

### 閉じた範囲

| 変更・記録 | 内容 |
|---|---|
| [01-12](../../../design/01-spec/01-12-core-calculus.md) の独立入力の表 | recordUpdate と未認定 call を分けた。認定した Range call は callee の番号だけを占め、引数を親環境・共有状態でソース順に解析することを記した（中1(a)） |
| 同章の match の段落 | 整数とも Range の Result とも認定できない腕を番号だけの走査に限定し、認定した Result の Error・guard・var/wild を含む全腕の解析を記した（中1(b)） |
| 同章の予算付き局所走査の表 | rangeCall は標準表が先、rangeOrigin は借用が先、rangeBorrowCheck はラベルの長さ・三引数・三契約位置の順であることを記した。rangeBorrowValue の順もソースに合わせた（軽3） |
| [07-04](../../../design/07-quality/07-04-formal-semantics.md) | 認定した call の導出が Surface の型の注記と StandardRule.resultType・argumentType の一致に依存し、実ソースの一致は A18a で確かめることを追記した（軽1） |
| [開始版の再現入力](baseline-regression.lean)・[出力](baseline-regression.log) | 未認定 call の根と引数の印がすべて false になる、という #guard が開始版で失敗することを確認した。既定 import の外の再現資料であり、通過する退行テストへ接続したものではない |
| [内部補題の確認入力](call-silent-probe.lean)・[出力](call-silent-probe.log) | `expr_unrecognized_call_silent_at` を証明した。任意の fuel・limits・ctx で、開始キーの rangeCallAt が none なら、その call を根とする走査は停止時も既存の warningsRev を保つ。公開定理・独立入力の保証へは未接続である |

formal/ の実装・証明・例は編集していない。設計書の変更は7行追加・5行削除であり、現在の実装を説明する訂正に限る。SyntacticReachExamples の既定の例への追加、01-12 の構文的な到達可能性と concreteRule_known の訂正は未完である。

### 作成時の関門と初回の失敗

再現の持ち主は構文的な到達可能性の候補範囲である。既存の SyntacticReachExamples は call を含まず、BudgetChildrenExamples は実際の親の警告列と独立入力を確かめるため、候補範囲だけが広がる退行を捕まえない。再現入力は本番の入口・型・フラグを増やさず、開始版に対して終了1となった。解析器・評価器を具体的な入力で kernel に走らせる計算は追加していない。

内部補題の最初の検査は終了1で、末尾の識別対応の証明における型の推論が maximum recursion depth に達した。再帰上限を増やさず、既存の within_unknown の Spec から空の追加分を導く形へ直し、終了0を確認した。最終の型照会・公理照会付きの検査は0.327秒だった。依存する公理は propext・Classical.choice・Quot.sound だけであり、新しい公理・sorry はない。最初の失敗ログは保存前に上書きされたため、原因をここに残す。

準備用の Python のヒアドキュメントは2回、入力の文字コードのエラーで終了1となり、編集前に止まった。coding 指定を加えた後に処理した。検査対象・期待値を緩める変更ではない。

### 中心命題・言明・参照定義の差分

[照合スクリプト](contract-check.py)・[照合結果](contract-check.json)で、formal と保存済み固定表318ファイルが開始版とバイト単位で一致することを確認した。既存の名前付き定理3,342件もそのままである。formal 内の未追跡入力はない。**NormalSoundness・WarningSoundness の本文、公理、既存の主定理の言明は変更していない。**

| 参照する定義・言明 | 今回の差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | なし | 量化・前提・結論を保持する |
| EvalPartial・EvalBlock・EvalArguments・EvalResultArms、Unmodeled・UnknownAt | なし | 未知を具体規則へ置き換える変更も今回はない。既存の認定と評価導出を保つ |
| ConcreteValue・ConcreteEnv・StandardRule.resultType/argumentType/finish | なし | 具体値の範囲や、型の一致の条件を変えない。軽1 は文書の訂正だけである |
| AbstractEnv・AbstractSlot・SlotModels・Models・topSlot | なし | Models を強めず、補助の由来や表について新しい前提を要求しない |
| targetOperationAt・Reached・WarningLocated | なし | 警告対象・位置・到達後の原因を保つ |
| concreteRule・syntacticReach*・InSyntacticReach・WarningsInSyntacticReach | なし | RV-C3 中2 の弱まりは未解消である。今回さらに広げることも、修正済みと扱うこともしない |
| IndependentResult.Sound・analyzeExpr_independent_sound・analyzeBody_independent_sound | なし | 独立入力の公開保証へ新しい排除定理を接続していない |
| analyzeBase*・BudgetAnalysis・BudgetScan.range*・Budget・EvalClosed | なし | 解析出力・費用・停止位置・評価器を変えない |
| Core・Release・Surface の主定理、Builtins.Assumptions、lakefile.toml | なし | 旧保証と Lean の -M 12288 を保持する |

### 検査と結果

Lean は固定版4.34.1。単体の確認には -M 6144、共通の排他ロックと300秒の時間上限を使い、終了状態を確認してから次へ進んだ。既定345ターゲットが最新であることを --no-build で確認したので、未ビルドの依存を Lake が並行してビルドする状態へ進んでいない。既定ビルドの -M 12288 は不変である。

| 実行 | 終了・結果 | 外側の時間と記録 |
|---|---|---|
| 開始版の候補範囲の再現 | 1、意図した #guard の失敗 | 0.315秒。[記録](baseline-regression.json) |
| 内部補題・公開型・公理の単体検査 | 0。既定 import には加えていない | 0.327秒。[記録](call-silent-probe.json) |
| lake --no-build build | 0、既定345ターゲットが最新 | 0.153秒。[出力](default-up-to-date.log) |
| 指定 work と同じ基準・対象の dry-run | 0、三単位だけを選択 | 0.010秒。[出力](dry-run.log) |
| /usr/bin/time -l で包んだ指定 work（一度） | **検査本体0、三単位成功。計測器1** | 68.607秒。[出力](work.log)・[記録](work.json) |
| work 内の仕様例（spec_examples） | 7件成功、失敗0・ignored 0 | 3.11秒、work に含む |
| work 内の仕様対応表（spec_tally） | 自己検査と集計が成功。初回リリースの完了条件の未記入は none | work に含む |
| work 内の既定 Lean ビルドと sorry 拒否（formal_build） | 0 | work に含む |
| 差分・契約の照合と git diff --check | 0 | [照合結果](contract-check.json) |

指定は次のとおりである。work の実行器は /usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh で包み、本体の終了と計測器の終了を別に保存する。Cargo は既存の書き込み可能なキャッシュを CARGO_HOME=<tmp>/benitoite-a01a-cargo として使用した。

```sh
scripts/check.sh --level work --base d1d706eaa3a181189b512057a5b3f08c110fe241 --only formal_build,spec_examples,spec_tally --dry-run
env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
```

**最大常駐量（maximum resident set size）は取得不能。** time は `sysctl kern.clockrate: Operation not permitted` により数値を出さず終了1となった。本体の終了0は L21R_CHECK_EXIT_STATUS=0 で確認した。real/user/sys は68.60/429.72/49.33秒である。検査中に別の作業や Lean を開始していない。再実行による結果の引用の省略はしていない。

### 固定表と申し送り

A11 の固定表を作り直していない。解析器・評価器・予算・入力がすべて開始版と一致するため、今回新たに期待値が変わる形は0件であり、固定表の再計算を行っていない。L20d の既存の影響（本体47形、全体・集計各7形）は [先行作業の影響表](../l20d/reference-impact.md)に残る。

| 残る範囲 | 検査・レビュー・受け入れまでの手順 | 見込み |
|---|---|---|
| 公開言明と案 (a) の接続方法 | 局所記法による文字列維持を認めるか、案 (b) で別定理を追加するかを取りまとめ・設計者が確認する | 不明 |
| RV-C3 中2 の実装と例 | 選んだ方法で保証を接続し、SyntacticReachExamples に未認定 call の引数を追加し、01-12 の説明を実装へ揃える。指定三単位を変更後の状態で検査する | 確認後に再見積もり。元の L21R は2〜4時間 |
| C3 のレビューと受け入れ | 定義・言明・参照定義の方向・公理を独立レビューする。未解消の中2 を A16 の前提にしない | 不明 |

コミット・取り込み・docs/todo の更新・保管・公開は行っていない。

## 取りまとめのレビュー（2026-10-26）

既存の formal のファイルには行の削除がなく（追加は `Benitoite.lean` の import と `SyntacticReachExamples` の例だけ）、既存の定理の言明・型は変わらない。新しい六モジュールに sorry・公理・`decide +kernel` はない。最初の起動は案 (a) の型の変化の確認で止まり、取りまとめが局所記法で型の変化を隠す形を採らず、案 (b)（別の公開の定理）へ切り替えた。再開後、例の検査が `-M 6144` を付けても圧縮とスワップを含めて 101GB に膨らみ、計算機のメモリ不足を起こした。取りまとめが当該の lean を止め、lean の使用量を 14GB で止める番人を置いた（作業中にさらに3件止めた）。Codex は例を書き直し、最後の例の検査は約0.4秒である。新しい定理の定義と各入口への接続は、取りまとめが独立のレビュー（RV-L21R）に回す。RV-C3 の中2 はこのレビューの後に閉じる。
