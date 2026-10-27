# 作業 L24 の結果

再開の着手: 2026-10-26 08:13:46 JST。終了: 2026-10-26 11:34:07 JST。所要時間: 3時間20分21秒。

**状態: L24 の実装と指定の work 検査を完了した。** 基準 B_WORK は `c6d2eeea202e7918376cdfb4d30d1be796b98972`、枝は `mod012/L24`。2026-10-26 の D15 と計画の再開判断に従い、固定域の標準 call 自身と HTTP の構築・更新の子へ警告範囲を拡張した。最初の起動の停止記録は、末尾の「最初の起動の確認」にその時点の記録として残す。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文・前提・結論と、`Models`・`SlotModels`・`AbstractSlot`・`AbstractEnv` は開始版とバイト一致する。既存の正常値・警告の主定理の言明を保ち、新しい公理・sorry を加えていない。C4 の独立レビュー、閉じた評価器の固定域・HTTP の実行例の充実、Rust と実 VM との比較を、この結果だけで完了としない。

## 実装した範囲

- `Eval.lean` の `EvalTypedArguments` で、各引数・欄をそれぞれの型としてソース順に評価する。`StandardBinding.argumentTypes` と契約位置から型列を作る。固定域の call は元のキーの出現表・読み込み済み標準表・直接の funName/opName の宣言を照合し、位置の置換と個数も検査する。Range の従来の funName の認定範囲は広げない。
- `StandardRule.fieldDomain` と HTTP の具体規則を加えた。構築は全欄を、更新は元レコードの後で明示欄を評価し、子の失敗と return を伝播する。明示欄は新値へ替え、非更新欄は保存する。構築・更新自体では域外の整数を拒否しない。読める con の展開は元の欄列を保ち、未知の内部表現にも導出を残す。
- `FixedDomain.lean` の `httpRecordUpdateFact` と対応の証明を加えた。更新した対象欄には新しい区間を使い、未知の更新値に古い事実を流用しない。非更新の対象欄は同じ宣言の既知の事実を保つ。`HttpRecordDecl.binding` は Response を respond の第2引数、ClientRequest を send の第1引数へ接続する。実ソースは `Http.Listen.respond` と `Http.Connect.send` である。計画の request という役割名から別の宣言を作っていない。
- `Sound.lean` の非予算解析と `BudgetAnalyze.lean` の実際の予算付き解析に、固定域 call・HTTP 構築・更新・局所保存を接続した。`BaseApprox.http` の一欄の事実を、既存の RangeState の位置・束縛番号と新しい `RangeLocalFact.httpRecord` で保存する。内部の正常値・警告の相互帰納に HTTP の対応を加え、公開入口で構成する。共有の Models に前提を足さない。
- W0404 は、正常に得る対象の整数の区間が固定域と不交差の場合だけ作る。HTTP の status は `[200,599]`、timeoutMilliseconds は `[1,max64]` であり、2^40+1 を域外にしない。交差・Top・Bottom だけから警告を作らない。正常域内にも他の IO 失敗を残し、API の成功や Process.exit の正常復帰を保証しない。
- `BudgetDomainScan.lean`・`BudgetHttp.lean` で、標準表・型列・位置列と置換検査の訪問、補助列の保持を計上する。`BudgetSelect.lean` は全引数をソース順に解析し、必要な契約位置の値だけを保持する。全引数の可変長の近似列を複写しない。HTTP の事実の複写は recordField 一項、局所の事実の走査は environmentRead として計上する。
- `BudgetNormal.lean`・`BudgetSound.lean` の中心入口、番号・警告位置・構文的な到達可能性・CallReach、独立入力・本体・全体駆動の既存の保証を接続した。共有表の保存補題を `TablePreservation.lean` へ移し、依存の循環を避けた。元の環境による位置の公開三定理は、言明と名前空間を保って `CallReachSound.lean` へ移した。
- `HttpUpdateExamples.lean` を既定の import に含めた。01-12 の写しと 07-04 の保証・A1 の限界を更新した。

## 中心二命題と参照定義の差分の向き

[点検器](restart/audit.py)と[点検結果](restart/audit.json)は、保護した宣言のバイト一致、既存の公開言明の移動・変更、固定入力のハッシュ、index の不変更を記録する。名前付きの公開補助定理の変更は後表の3件だけである。Interval の外の旧主定理・Builtins.Assumptions・公理と lakefile.toml は変更していない。

| 参照する定義・契約 | 差分と向き |
|---|---|
| NormalSoundness・WarningSoundness | 定義の本文・量化・前提・結論はバイト一致。評価導出・Models・任意予算の条件を追加していない |
| ConcreteValue・ConcreteValue.type・EvalInput・Reached | 不変。未知の other の集合と同じキー・演算による到達の定義を保つ。原因一致を Reached の前提に移していない |
| AbstractSlot・AbstractEnv・SlotModels・Models | バイト一致。整数の事実、HTTP の内部表現、IO の成功を要求する条件を追加していない |
| RangeLocalFact・RangeState.Models | httpRecord の場合を追加。公開 Models とは別の内部不変条件であり、入口の空状態から構成する。既存の result/checked の意味は保つ |
| HttpRecordFact.Models・HttpRecordState.Models | 定義を変えず RangeState.lean へ移動。共有の保存に使う一欄の事実も、同じ read と区間所属を要求する |
| StandardRule・EvalStandard | fieldDomain の具体規則を追加。既知の域外欄は outsideDomain、域内には正常値と他の失敗、読めない欄には型内の正常値と未知の失敗を許す。既存の Range と直接固定域の結果規則を保つ |
| rangeCallBinding・EvalPartial・EvalTypedArguments | 未認定だった固定域 call と HTTP の構築・更新を具体規則に置き換える。異種の型列とソース順を保ち、正常値・子の失敗・return の導出を接続する。固定域の失敗と return は親の期待型によらず伝播する。旧 EvalArguments との一律の型列の双方向の移送も証明した |
| Unmodeled・UnknownAt | HTTP の認定に成功した形を任意値の未知規則から外し、具体規則との重なりを除く。認定しない record/update、未認定 call は従来の未知に残す。型内の未知値を Bottom に置換していない |
| targetOperationAt・arithmeticOperationAt | 定義は不変。標準束縛の二表と元キーによる同定を使う。標準 call の警告を算術として符号化していない |
| BaseApprox・analyzeBase*・BudgetAnalysis.expr | 正常値の補助欄と固定域警告を追加。合流・一般 call の結果・入口の忘却では欄の事実を捨てる。中心二定理の公開入口と前提は保つ |
| concreteRule・syntacticReach* | HTTP の構築・更新を具体規則の候補として加え、その子を辿る。構文だけの候補は表の認定をしない上界であり、公開の結果には別途 CallReach の元キーによる認定も証明する |
| WarningOperationSyntax・LocatedIn・RootWarning・InSyntacticReach | 算術には従来の arithmeticOperationAt の等式を保ち、固定域の直接 call の根だけを追加する。固定域以外の標準操作をこの追加で許さない |
| WarningsInSyntacticReach | 警告範囲を上記へ拡張し、同じ環境の WarningLocated を連言で要求する。標準表のない構文だけから targetOperationAt の一致を結論しない |
| CallReach.callRoot・exprTables・Scope.allows | 固定域の根には同じ認定済み束縛との一致、HTTP の子には httpExpressionBinding の認定を要求する。既存の認定済み Range の引数の範囲は保ち、未認定 call・利用者関数・対象外の標準 call の内側は広げない |
| WarningsInCallReach・IndependentResult.CallsRecognized・BodyOutput.CallsRecognized | 言明の文字列は保つが、参照する allows が上記の範囲へ拡張される。独立入力はその入力自身の忘却後の環境と元キーで認定する |
| IndependentResult.Sound・InputLocated とそれらの公開の系 | 構文的な警告範囲・LocatedIn を通じて同じ限定的拡張を受ける。正常値・警告原因の前提を増やさず、元の入力と番号の位置、別本体・未認定 call の除外を保つ |
| Budget と本体/全体駆動の状態機械 | 変更なし。局所の HTTP 事実の走査と保持を追加したため操作数・小予算での停止に差が出る。固定表の影響は後表へ分離した |
| EvalClosed | 証明付きの型別引数評価を追加し、既存の Range の例を新しい評価関係へ接続。正常な固定域操作の結果と HTTP 構築・更新の実行は選ばず none。主定理 evalClosed_sound の言明は保つ |

## 意味が変わる公開の保証と保った性質

| 公開の定理・契約 | 変更前 → 変更後 |
|---|---|
| analysis_located*・expr/shortCircuit/block/armList_located・InSyntacticReach.located | 算術演算だけの構文上の位置 → WarningOperationSyntax による算術または固定域の直接 call の位置 |
| expr/shortCircuit/block/armList_warning_syntactic_reach・analyzeExpr/analyze/analyzeBody_warning_syntactic_reach | 算術だけの InSyntacticReach → 上記の限定的に拡張した InSyntacticReach。analyze の契約には実環境の WarningLocated も含む |
| expr/block_warning_call_reach・analyzeExpr/analyze/analyzeBody_warning_call_reach | 認定した call の引数の算術警告 → 既存の範囲に固定域の call 自身と認定した HTTP の子を追加。元キーの認定と未認定 call の除外を保つ |
| analyzeExpr/analyzeBody_independent_sound・independent_located・independent_call_reach・全体駆動の BodyOutput.Sound/CallsRecognized の定理 | 各入力自身の算術の範囲 → 同じ入力自身についての拡張した範囲。親の未知評価の trace から子の原因を結論しない |
| analyzeExpr_warning_located・analyze_warning_located・analyzeBody_warning_located | 名前空間・言明を保って CallReachSound.lean へ移動。構文だけの位置からの導出に代え、実際の認定済み CallReach の元環境の二表から証明する。前提・結論とも不変 |
| 新設 InSyntacticReach.arithmetic・analyze_warning_arithmetic・analyzeBody_warning_arithmetic | 算術の演算を持つ警告に限れば、従来の arithmeticOperationAt の範囲にあることを公開の系として保つ |

公開されている内部補助定理の明示した言明の変更は次の3件である。既存の中心入口の正常値・警告健全性の主定理の前提・結論の変更ではない。

| 補助定理 | 変更と用途 |
|---|---|
| BudgetLocated.expr_located | arithmeticOperationAt の等式を WarningOperationSyntax へ替える。上記の再開判断による範囲拡張 |
| CallExclusion.within_call | 引数列だけの Within に代え、任意の extra に対する引数列と各引数式の Within を受ける。対象位置を選ぶ selectArguments の内部帰納で構成し、公開入口には追加しない |
| concreteRule_known | HTTP の構築・更新にだけ recordKnown を追加。認定された構築・更新が UnknownAt と重ならないことを示す補助定理であり、公開の解析・中心定理の前提にしない |

`TablePreservation.lean` へ移した表保存の11補題と RangeState.lean へ移した HTTP の6補題は、名前空間と同じ言明を保つ。差分点検器は移動先も含めて照合する。

## 例と検査

test-audit の作成時の関門として、実際の解析入口から構築・更新・保存・候補生成をまとめて観測する例を選んだ。局所の実装の分岐を一つずつ写すテストは追加していない。

`HttpUpdateExamples` は #guard で、宣言順と異なる欄順と引数順、status の正常・域外、正常→域外/域外→正常の更新、body の更新による status の保存、未知の更新で古い域外の事実を使わないこと、局所保存後の更新、timeout の境界を照合する。標準出現表なし・偽の親 call・一般の関数戻り値では親の警告が空であることも確認する。域内でも他の失敗が導出できる例を併せた。完全な固定域の独立評価例と C4 のレビューは L25 の担当である。

| 検査 | 結果・実時間 | 証拠 |
|---|---|---|
| 依存順の単独モジュールのビルド | 266 モジュール終了0。実際に更新する依存を一つずつビルドし、Lake 内部で未ビルドの Lean を並行起動していない | restart/integrated-final-*.json、restart/acceptance-ready-*.json |
| 中心の証明の更新後のビルド | Sound 38.590秒、BudgetNormal 19.775秒、BudgetSound 22.666秒、CallReach 9.392秒。成功。Examples は2.430秒 | 対応するビルドの log/json |
| HTTP の例の単体検査 | `lake env lean -M 6144`、終了0、0.371秒。最終の他の IO 失敗の例も既定ビルドで成功 | restart/http-tests-second.json と acceptance-ready の記録 |
| 既定ターゲットの事前確認 | `lake --no-build build`、終了0、0.148秒。既定ターゲットが最新 | [記録](restart/default-up-to-date.json) |
| 公理依存の照会 | 中心二定理、範囲・算術の系・CallReach・HTTP 更新・trace・閉じた評価器を照会。依存は propext・Classical.choice・Quot.sound の範囲。HTTP 更新は propext・Quot.sound | [入力](restart/axioms.lean)・[出力](restart/axioms-final.log) |
| 指定と同じ基準の dry-run | 終了0、0.011秒。spec_tally・spec_examples・formal_build の三単位だけを選択 | [出力](restart/dry-run.log) |
| 指定 work、一度 | **検査本体0、77.549秒。三単位成功。外側の計測器1、77.583秒** | [全出力](restart/work.log)・[本体](restart/work-check.json)・[計測器](restart/work.json) |
| work の仕様例 | 7件成功、失敗0、ignored 0、3.10秒 | 上記 work.log |
| work の仕様対応表 | 自己検査・集計成功。初回リリース版の完了条件の未記入は none | 上記 work.log |
| work の既定 Lean ビルドと sorry 拒否 | 成功。未使用変数・simp 引数などの Lean の警告は残るが、sorry はない | 上記 work.log とモジュールのビルド出力 |
| 開始版との宣言・固定入力・差分の点検 | 成功。指定の B_WORK と比較。公開の主定理の言明、公理の追加なしを確認 | [点検結果](restart/audit.json) |

最終 work は次の指定を `/usr/bin/time -l` で包んだ。計測器は `sysctl kern.clockrate: Operation not permitted` により終了1となった。**最大常駐量（maximum resident set size）はサンドボックスで取得できなかった。** 検査本体の終了0と区別して記録し、未取得を0としていない。

```sh
scripts/check.sh --level work --base c6d2eeea202e7918376cdfb4d30d1be796b98972 --only formal_build,spec_examples,spec_tally
```

作業中の既存の具体計算例には、解析器を kernel で decide するものがあった。BudgetAnalysisExamples の下流ビルドが2回、約16.7秒と16.8秒で終了143となった。使用量は取得できず、停止した主体と理由をこの記録だけから断定しない。1回目の後の変換器が根を一階層誤り、変換0件のまま再試行した。これを修正し、対象ファイルへの適用を確認してから、解析器・評価器を走らせる具体例を #guard へ替えた。メモリや時間上限を上げず、同モジュールは約0.5秒で成功した。旧期待値は保ち、局所の追加走査が関わる BudgetAnalysisExamples の停止例だけ、操作予算14→15・番号付け停止予算17→18と期待操作数14→15に揃えた。主定理の証明へ具体の解析計算を持ち込んでいない。

Lean の固定上限 `moreLeanArgs = ["-M", "12288"]` を保つ。試行は `-M 6144` と時間上限、プロセス群の終了回収を使った。Sound は175秒、既存の Examples は25秒で制限し、実績の5倍を超えて継続させていない。実際の終了状態を待ち、ビルドを残したまま別作業へ進んでいない。

## 固定表への影響と Rust への申し送り

[採取器](restart/reference-impact.py)は保存済みの A18a の実交換の宣言を使い、元の二つの Lean 入力を各一度だけ直列で計算した。予算の選択規則は元の生成器を使い、StandardBinding の追加された型欄 `[]` の明示だけを一時入力へ補った。入力式・旧期待値・固定表のファイルは書き換えていない。budget-reference は69.413秒、summary-reference は16.889秒、いずれも終了0、`-M 6144`・300秒上限である。

以下の表は [全差分の記録](restart/reference-impact.json)の集計である。「変更」は同じ `(name, kind, cap)` の列が変わった行、「追加」は元の選択規則の最小完走予算の変化によって新しく選ばれた行を表す。削除は0件。予算 kind の順は元表の0・1・2・3である。主因は非整数の局所位置を読むときの HTTP の共有事実の追加走査であり、同じ小予算では停止・保存件数・警告や集計も変わり得る。

FIXTURE_TABLES

三表の保存済みハッシュは採取の前後と B_WORK の git object と一致する。新しい行は restart/reference-output の `*-new.tsv` に参考出力として保存した。**固定表の更新・Rust の計上との再照合は A19〜A21 へ渡す。** 三表との差があるまま Rust との全比較済みとは扱わない。取りまとめの補足に残る A16〜A18 の表記も参照したが、本枝ではどちらの担当範囲の Rust も変更していない。

## 後続へ渡す範囲

- **L25:** 表層の固定域 call、HTTP の構築・更新・局所保存、W0404 生成、中心二定理への接続は閉じた。`EvalClosed` は異種の引数の証明付き評価まで接続したが、固定域操作の正常引数の結果や HTTP の構築・更新の実行は none のままである。新しい具体規則を使う独立の表層評価導出、定義域の内外と交差・各引数順・偽装・失敗/return・更新の組合せの充実と C4 の独立レビューを引き継ぐ。HTTP の内部表現が読めない場合の Expand と fieldUnknown の導出もレビュー対象にする。
- **A19〜A21:** 上表の操作数・停止位置・集計の差を参照する。欄の事実を既存の環境位置とは別の recordField 一項として複写計上し、保持を終える領域で返す。可変長の引数値列を作らず、対象位置だけを保持する。標準宣言・元キー・欄/引数の型と位置の照合を Rust 側へ揃える。
- **交換・全比較の担当:** fieldDomain には解決済み owner/constructor・各欄型・各引数型・結果型を渡す。Plan の request は実ソースの Connect.send に対応する。標準表にないモジュールを補ってロードせず、実ソース/VM との対応を A1 の定義内の証明で代用しない。

git の変更操作・private の参照・依存更新・固定表の書き換えは行っていない。指定検査後は設計書の説明と結果記録の整備だけを行い、Lean の実行定義・証明・例・仕様のコードブロックは変えていない。

HISTORY
