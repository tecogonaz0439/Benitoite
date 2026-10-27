# RV-C5: 区間解析の Lean の独立した交換（L27a・L27b・L28・L29）の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code の別プロセス（Opus 5.5、API キー、取りまとめが依頼）
- 対象: 範囲 `258735b0..b4b4a245`（HEAD は b4b4a245 と一致）。新設の `formal/Benitoite/Interval/Exchange.lean`・`ExchangeExamples.lean`・`formal/IntervalDiff/Main.lean`・`formal/tests/test_interval_exchange.py`、変更した `formal/lakefile.toml`・`formal/Benitoite.lean`・01-12・07-04。改造ディレクトリ D = `docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/`。
- 方法: 読むだけで行った。`git diff 258735b0..b4b4a245 -- formal docs/design` を中心に読み、`git diff --name-status` で変更ファイルを確かめ、grep で照合した。照合した文書は D/plan.md の契約表（独立交換・独立入力の保存・比較報告・識別・警告の行）、作業群 L27・作業 L28・L29、作業群 X01〜X05 の冒頭と X03c の表、D/decisions.md の D4 の変更・D5・D15（追記を含む）・D17・D20、D/l27a・l27b・l28・l29 の results.md と l29 の profile-manifest.json・comparison-summary.json。参照先の既存定義（`Sound.lean` の `BaseApprox`・`baseUnit`、`Eval.lean` の `standardCallHead`、`FixedDomain.lean`、`Budget.lean` の `State.Valid`、`BudgetWhole.comparisonEligible`、`BudgetIndependentRun.captureIndependent`、`EvalClosed.lean` のリテラル規則）と、Rust の `tests/desugar_export/exchange.rs` の頭の分類、標準ライブラリのシフトの包みの宣言は、所見の確定に要る範囲だけを読んだ。
- 実行: `python3 -B formal/tests/test_interval_exchange.py` の実行は、この環境のサンドボックスが拒否したため行えなかった。局所比較の結果（87 起動、終了0）と `lake build`（既定ビルドと sorry の拒否）の結果は、l28・l29 の results.md の記録に依っている。私自身は再現していない。

## 所見の要約

- 重大: 0 件
- 中: 3 件（中1: Unit などの型で Top を非Top と数える。中2: 未着手の本体の期待を黙って捨てる。中3: X03c の表と、閉じた評価器の除外の範囲が食い違う）
- 軽: 3 件
- 判定: **条件付き受け入れ**

中心二命題、`Models`、区間解析の定義・定理、旧主定理、公理、`Builtins.Assumptions` は変わっていない。既存の Lean ファイルへの変更は `formal/Benitoite.lean` の import 2 行だけである。sorry・admit・native_decide・`decide +kernel` はない。読者の厳密さと終了状態はおおむね計画のとおりに作られている。受け入れの条件は次の三つである。中1 を X02 の前に直すこと（「全結果が Top であるだけの一致は受け入れない」という受け入れ規則に関わるため）。中2 を直すか、そのままとするなら取りまとめがその判断を記録すること。中3 の X03c の表を、X03 に着手する前に改めること。

## 所見

### 中1: Unit など、整数でも Boolean でもない型の本体で、Top を非Top と数える

- 場所: `formal/Benitoite/Interval/Exchange.lean` 775〜782 行（`informative`）。参照先は `formal/Benitoite/Interval/Sound.lean` 109 行（`baseUnit`）、`BudgetAnalyze.lean` 150・256・309 行。
- 問題: 根の型が整数でも Boolean でもない場合、`none` の枝は `approx.integer != top || approx.boolean != (true, true) || !approx.other` で判定している。Unit 型の本体（`()`、空の Block、discard で終わる Block）の近似は `baseUnit = {integer := bottom, boolean := (false,false), other := true}` である。このとき、Integer64 の欄が Bottom であるというだけで `integer != top` が真になり、非Top に数えられてしまう。Unit の正常値の可能性は `other = true` で全てであり、これは Top にあたる。return だけで抜ける本体など、ほかの非整数型で integer が bottom・other が true となる近似も同じ扱いを受ける。
- 根拠: 01-12 には「Top の判定は…正常成分で行い」、07-04 には「別の整数型の欄が Bottom であるだけでは非Topと数えず」とある。l29/results.md は「他の型のBottomを非Topと数えない」と述べているが、実際に直したのは幅付き整数の別本体だけである。Unit の本体だけから成るコーパスは allTop にならず、`accepted` が真になりうる。これは契約表の比較報告の行と D17 の「全ての結果がTopであるだけの一致は受け入れない」に反する。局所検査（test 440〜455 行・565〜571 行）が確かめているのは、幅付き整数と Integer 型の unknown だけである。
- 修正案: 整数・Boolean・六幅以外の型では `!approx.other`（または `!approx.nonIntegerOther`）だけで判定する。Unit の本体だけのコーパスが allTop で終了1になる負例を test に加える。
- 確定の度合い: 読めば確定する（`baseUnit` の定義と `informative` の分岐から導ける）。実行による再現はしていない。

### 中2: 解析されなかった本体の期待を一致の判定から黙って外し、入力全体の消費・段停止を独立期待と比べない

- 場所: `Exchange.lean` 747〜756 行（`bodyComparison` は生成された本体だけを走査する）、823〜834 行・857〜858 行（`unproducedBodies` は報告だけ）、849 行（`good` の条件）、885〜895 行（受け入れの理由は空・全Top・深さだけ）。test 628〜637 行。
- 問題: 全体予算などで未着手になった元定義にも、読者は `expected` を必須で要求する。ところがその期待は比較されず、不一致にも受け入れの失敗にもならない。test の whole-budget-0/1 では、正常値を期待する元の `expected` を残したまま全体上限を 0・1 にしても終了0になっており、古くなった期待がそのまま通ることを示している。さらに、入力全体の最終 `after`、段停止の位置と分類、専用射影の件数（`wholeBudgetSkipped` など）は報告に出るだけで、独立期待と照合する欄がない。このため、BudgetWhole の駆動が早く止まりすぎる退行は、比較した本体が一致していれば検出されない。
- 根拠: 契約表の比較報告の行は「操作数と…保持項目数の消費、停止位置と分類も厳密に比較する」と定めている。01-12・07-04 は「未着手本体は比較しない」としているが、明示した期待を捨てることまでは述べていない。l28/results.md の申し送りも「入力全体の after と段停止も照合する」を X 担当へ渡しており、Lean 側の独立期待との比較は欠けたままである。
- 修正案: (a) 未着手の本体に期待があれば mismatch とするか、期待の側に `{"notAnalyzed": 停止理由}` を明示させて照合する。(b) input の任意欄として、最終 `after`・`phaseStops`・`counts` の期待を加え、与えられたときは比較する。どちらも採らない場合は、取りまとめがその判断と理由を記録し、X02 で Rust との比較により閉じることを明記する。
- 確定の度合い: 読めば確定する（コードと test の入力から導ける）。

### 中3: X03c の表のシフトの行と、閉じた評価器の除外（Byte 16 件・域内 46 件）が食い違う

- 場所: D/plan.md 1065 行（X03c の表のシフトの行）。`formal/Benitoite/Interval/EvalClosed.lean` 78〜92 行・492〜530 行（Byte のリテラルの規則がない）、test 289〜303 行、l29/comparison-summary.json 200〜201 行。
- 問題（観点5）: domain の評価の除外 62 件の内訳は、unknownFailure が 46 件（23 宣言 × 域内の量 0・w−1）、notClosedOrFuel が 16 件（Byte・UnsignedInteger8 の 4 宣言 × 4 行）である。閉じた評価器には Byte のリテラルの具体規則がなく、ConcreteValue にも Byte の値がない。対象構文の評価関係でも、Byte のリテラルは未知（型内の任意の値または失敗）である。そのため、域外の量（−1・8）を含めて Byte の行はすべて評価不能になる。この除外は既存の定義に従っており、C5 の実装として不当ではない。Byte のリテラルの規則を加えると中心二命題が参照する評価関係が変わるので、D15 の停止条件にあたる。ただ、計画の X03c の表は、左の列（VM と評価関係を比べる入力）に「正常な量0・w-1」「Byteのwは8」を挙げている。実際には次のようになる。
  - Byte の 4 宣言は全行が右の列の「未知の引数を含む入力」にあたり、評価関係との厳密な比較は 0 件になる。
  - 整数の域内の行は全件が「evalClosed が域内で unknown の失敗を選んだ入力」にあたる。
  - したがって左の列で実際に比べられるのは、整数の 23 宣言の域外の量の 46 件だけである。
  このままでは、X03 で比べられない入力を比較済みと数えたり、表との違いを X03 の担当がその場で判断したりするおそれがある。
- 根拠: 07-04 の追記は「未知を含む Byte リテラルの評価と、域内シフトで unknown の失敗を選んだ評価は除外する」と記しており、l29/results.md の A1 の表も「unknownとByteの評価不能をVM比較件数へ加えない」と申し送っている。しかし plan の X03c の表は改められていない。
- 修正案: X03 の前に、取りまとめが X03c の表を改める。Byte の行と整数の域内の行は「VM の結果を独立期待値（R0701 がないこと・値）と照合するが、評価関係との比較済みとは数えない」と明記する。評価関係と VM を厳密に比べる入力は整数の域外の量だけと書き、A1 の限界として 07-04 に記す。Byte を評価関係の具体規則に加えるなら、設計者の決定を要する。
- 確定の度合い: 読めば確定する（コード・test・記録の件数が互いに合っている）。

### 軽1: ExchangeExamples の「profile の拒否」の例が、別の理由で拒否されている

- 場所: `formal/Benitoite/Interval/ExchangeExamples.lean` 117〜121 行。
- 問題: `(["profile"], toJson "domain")` を拒否の例にしているが、L29 で domain は受理済みの profile になった。いまこの例が拒否されるのは、base の sample に `widths`・`nonIntegerOther` がないためであり、未知の profile を拒否することは Lean の例では検査されていない（Python の `invalid-profile`（'future'）が補っている）。
- 修正案: 値を `"future"` に変えるか、コメントを実際の理由に合わせる。
- 確定の度合い: 読めば確定する。

### 軽2: plan の X03c の「包みの関数…の6宣言」と、実際の 7 宣言が合わない

- 場所: D/plan.md 1065 行。標準ライブラリは `Integer64.bnt` 68〜79 行（3 宣言）、`UnsignedInteger.bnt` 88〜94 行（2）、`UnsignedInteger8.bnt` 43〜49 行（2）。
- 問題: 包みのシフトは 7 宣言あり、組み込みの 20 宣言と合わせて 27 宣言になる。読者（`Exchange.lean` 478〜486 行）と test（270〜276 行）は 27 宣言で正しく作られており、計画の記述だけが誤っている。
- 修正案: X03c の表を「7宣言」に直す。
- 確定の度合い: 読めば確定する。

### 軽3: INPUT と REPORT が同じであることを、パスの文字列だけで判定している

- 場所: `formal/IntervalDiff/Main.lean` 19 行。
- 問題: `./a.json` と `a.json`、あるいはシンボリックリンクのように、同じファイルを指す別のパスを渡すと検査をすり抜ける。その結果、交換入力の読み込み後に入力ファイルが報告で上書きされる。
- 修正案: 正規化したパスで比べるか、報告の書き込み先が入力と同じ実体でないことを確かめる。
- 確定の度合い: 読めば確定する。

## 確かめて問題がなかった観点

1. 不変であること: `git diff --name-status` で確かめた変更は、01-12・07-04、`formal/Benitoite.lean`（import 2 行の追加）、新設の 4 ファイル、`lakefile.toml` だけである。`crates/`・`scripts/` と既存の Lean ファイルは変わっていない。したがって、`NormalSoundness`・`WarningSoundness`・`Models`・`EvalPartial`・`standardCallHead`・`targetOperationAt`・`evalClosed`・`BudgetWhole`、旧主定理・公理・`Builtins.Assumptions` は変わっていない。新しいファイルには sorry・admit・native_decide・`decide +kernel`・axiom・`implemented_by`・`unsafe` がない（grep で確認）。`lakefile.toml` では既存の六つの入口（desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll）と `-M 12288` が保たれ、`intervalDiff` の追加だけが行われている。
2. 読者の厳密さ:
   - 版などのヘッダ: kind・version 1・surfaceVersion 14・traversalVersion 1・五つの profile を照合し、余分な欄を拒否する（`decodeCorpus`）。
   - 重複欄: `UniqueJson` が、エスケープを解いたキーで、配列の中を含む全ての object を検査する。
   - 深い位置の未知欄・構成子: Surface の既存の復号器で読んだ値を再び符号化し、元の JSON と一致するかで検査する（`surface`）。それ以外の容器も `fields`／`fieldsOptional` で余分な欄と欠けた欄を拒否する。
   - 名前の重複: 入力・モジュール・定義・定数・型キー・元演算キー・標準の ID と役割・apiAt・警告（キーと原因）・別本体の期待の重複を拒否する。
   - 端点: 閉区間は `kind.min ≤ lo ≤ hi ≤ kind.max` を要求する。
   - 十進文字列: 端点は Int、予算・fuel・番号は Nat として読み、`toString` で読み戻して一致を確かめるので、先頭の 0・`-0`・`+`・小数・指数・空白を拒否する。浮動小数点や有限幅の整数を経由しない。
   - 予算状態: `State.Valid` の三条件と一致する検査をしている。
   - Surface・定数: 既存の読者と変換（`Exchange.Ty`・`Block`・`ConstantEntry`・`expandConstant`・`validateIntegerConstants`）を再利用している。
3. 頭の分類: Rust の `exchange.rs` 878〜930 行は、組み込みの関数と組み込みの操作を `primName`、利用者の関数を `funName`、利用者の操作を `opName` に写す。Lean の `standardCallHead` は、型引数・エフェクト引数のない `funName`／`primName` だけを認める。test では、組み込みのシフトは primName、包みの 7 宣言は funName で作られており、opName・型引数付き・エフェクト引数付きの頭は終了2で拒否される。
4. 比較の受け入れ:
   - 拒否する場合: 空のコーパス（両モード）、全 Top、本体または段の深さ停止を受け入れない。除外だけの評価比較も受け入れない。
   - 独立入力の深さ停止: `captureIndependent` が停止を親へ伝えるので、親の本体の深さ除外として必ず受け入れから外れる。
   - 報告する内容: 本体ごとの comparisonEligible、段停止（entry・discovery・queue・embedded・whole）、除外の件数と定義名、未知の理由を報告する。
   - 評価の除外: unknown の失敗は理由付きで外し、observed に残す。除外の期待も実際の理由と照合する。
   - 終了状態: 受け入れは 0、不一致と受け入れ対象なしは 1、引数・交換入力・IO の誤りは 2 である。
   - fuel: Block・Exprs の列でも減る（test の depth-sequence・depth-exprs・builderBind 64 個の fuel 再選択）。
   - mayFail: 一致と受け入れに使わない。
5. profile: width・range・domain が加わっている。両モードの `profileManifest` に、必須の五 profile と入力・元定義・全本体・比較・除外の件数がある。domain の固定域はシフトの 27 宣言（名前の照合）だけで、unsigned と Byte の rightUnsigned は `FixedDomainApi.contract` で拒否される。操作と HTTP の欄は規則として登録できない（test の standard-operation・standard-http）。各 profile に正の固定コーパスと負の変更例がある。期待値（区間・消費・trace・初期 fuel）は Python のリテラルと手計算の式で与えられ、Lean の出力を写して作ってはいない。
6. 設計書: 01-12 の表（Expected・Definition・Module・Input・Corpus の欄）、initialFuel の式、受け入れの条件、評価の除外の理由、manifest の欄は Lean と一致している。食い違うのは中1 の Top 判定の記述だけである。07-04 の欄・標準規則の表・十進文字列の規則・終了状態も Lean と一致している。両文書とも「Rust の解析・実 VM との一致の証拠ではない／この入口では実施しない」と明記し、名前解決と標準表の由来を入力の信頼範囲としている。A1 の限界と、X01〜X05 が未完であることの割り当ては、l29/results.md の「A1の限界とXへの申し送り」に明記されている。
7. 除外の妥当性（観点5 の結論）: 16 件は、閉じた評価器と評価関係が Byte のリテラルを扱わないことによるもので、既存の定義に忠実である。C5 での比較範囲を不当に狭めてはいない。残る問題は中3 の、計画の表との食い違いだけである。
