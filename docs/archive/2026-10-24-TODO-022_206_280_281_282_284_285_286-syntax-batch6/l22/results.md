# 作業 L22 の結果

着手: 2026-10-26 07:25:18 JST。終了: 2026-10-26 07:43:06 JST。所要時間は17分48秒である。

基準 B_WORK と HEAD はともに `be57d4e92d7a48fb74dc33a4d3c3867b60207aeb`、ブランチは `mod012/L22` である。L22 の範囲を実装し、指定 work の三単位は成功した。計測器はサンドボックスの制約で終了1になったが、検査本体の終了0を別に保存した。最大常駐量は取得できなかった。

## 実装と写し

| ファイル | 実装した内容 |
|---|---|
| `formal/Benitoite/Interval/FixedDomain.lean`（新設） | 七種と Byte のシフト量、exit の code、listen の port の契約表・引数名・契約上の位置・型を定義。正常区間との不交差、任意の正常整数に対する評価導出、正常結果の所属、全域外の拒否理由を証明し、解決済み標準束縛の EvalStandardAt に合成した |
| `formal/Benitoite/Interval/FixedDomainExamples.lean`（新設） | 幅と上端、存在しない rightUnsigned、port=0、端の交差、Top・Bottom、同じ表示名の別宣言、二表の不在・出現キーの違い・部分呼び出し・パイプを独立期待値で確認した。Http.listen の型は実交換と同じ data の組にした |
| `formal/Benitoite/Interval/Sound.lean` | targetOperationAt を抽象環境・出現キー・式を受け取る形に一般化。standardAt と同じ二表と表層の宣言を照合する。標準関数の funName とエフェクト操作の opName の両方を扱い、exit の型引数を除外しない |
| `BudgetLocated.lean`・`BudgetBody.lean`・`SyntacticReach.lean`・`SyntacticReachExamples.lean` | WarningLocated、式・本体の位置の結論と、構文的な到達可能性から位置への含意を一般化後の認定へ接続。旧関数は arithmeticOperationAt とし、内部の算術の位置と構文的な到達可能性の意味を保持した |
| `CallReachWhole.lean` | RV-L21R 軽3 のコメントの根拠を、説明のある 01-12「区間解析の独立入力の保存と保証」へ訂正した |
| `formal/Benitoite.lean`・01-12・07-04 | 新しい二モジュールを既定 import に追加。契約・定義・補題・位置の認定・現時点の接続範囲と A1 の限界を写した |

シフト量はすべて Integer64 であり、シフトする値の型とは区別する。Byte は IntKind に加えず [0,7] とし、存在しない Byte と符号なし三種の shiftRightUnsigned は契約を返さない。Integer64 のシフト量は [0,63]、exit は [0,255]、listen は [0,65535] である。左シフトの捨てるビットを overflow にする規則は加えていない。

`FixedDomainContract.rule` は既存の StandardRule.fixedDomain と EvalStandard の domainNormal・domainOtherFailure・domainRejected を使う。Eval.lean は全バイト不変である。`fixed_disjoint_rejected` は全域外なら outsideDomain で拒否すること、`fixed_at_disjoint_failed` は標準束縛の実際の評価から failed outsideDomain になることを示す。正常域内でも他の失敗を許し、exit の正常復帰や listen の IO の成功は保証しない。Http.listen の Result・Listener・NetworkError は、交換から渡す解決済み data 名から作り、モジュールの追加ロードや表示名からの推測を行わない。

## 中心命題・既存の言明・参照定義の差分

[差分点検器](contract-check.py)の[記録](contract-check.json)は、基準との `git diff` と各ファイル・宣言を照合した結果である。中心二命題の定義の本文、正常値・警告原因・構文的な到達可能性の既存の主定理の言明を保った。**既存定理の言明3,443件はそのままである。** 下記の位置の補助言明8件だけに差分がある。

| 定義・言明 | 差分と向き |
|---|---|
| NormalSoundness・WarningSoundness | 本文を含め不変。Eval.lean 全体が基準と一致する |
| EvalPartial・EvalArguments・EvalBlock・EvalStandard・StandardRule・Unmodeled・UnknownAt・rangeCallBinding・NormalTyped | 不変。固定域の局所補題は既存の標準評価の定義から導く。表層の固定域 call を未知から外す変更はしていない |
| ConcreteValue・ConcreteValue.type・RangeNames・RangeRecord・rangePayload・rangeStoredValue | 不変。任意の未知の値や other を除外せず、型や表現に新たな条件を加えない |
| AbstractSlot・SlotModels・Models・topSlot・RangeState.Models | 不変。局所値と具体値の対応、二表の一致の要求を強めない |
| targetOperationAt | env・key を追加し、直接 call の funName/opName について standardAt と頭の宣言の一致から standard binding を返す。局所の値や Range の由来は認定に使わない。二表が同じなら同じ結果であることを target_at_tables で示す |
| arithmeticOperationAt | 旧 targetOperationAt と、名前の置換後に定義全体が一致する。arithmetic_target_at が任意の二表・キーで新しい認定への一致を示す |
| WarningLocated | 位置にある式を、解析入口の環境と警告自身のキーで認定する形へ一般化。依頼された標準束縛の位置の契約に対応する。現在の解析は従来どおり算術だけの強い位置の性質も保つ |
| analyzeExpr_warning_located・analyzeBody_warning_located | 結論の targetOperationAt に env/seed.initial と warning.key を追加した、依頼の位置の補助定理2件。評価導出や新たな前提は足さない |
| negOwnTyped_warning_located・neg_warning_located・located_root・binary_warning_origin・expr_located・target_concrete | 言明中の旧関数名を arithmeticOperationAt に置換した6件。定義を展開した意味は同じである |
| LocatedList・LocatedIn・Located・RootWarning・concreteRule・InSyntacticReach・WarningsInSyntacticReach・IndependentResult.Sound・CallReach | 内部の位置・構文的な到達可能性は旧認定の意味を保つ。concreteRule や未認定 call の範囲を広げず、RV-C3 中2 の保証を弱めない。WarningsInSyntacticReach.located の言明はそのままで、本文に一般化後の位置への橋渡しを加えた |
| 解析器・予算・発見・独立入力・本体/全体の駆動・閉じた評価器 | 実行定義は不変。新しい targetOperationAt を解析の実行へ追加していないため、操作数・保持数・停止位置・分類・警告列は変わらない |
| Builtins.Assumptions・旧主定理・Interval の外の formal | 全バイト不変。公理・sorry・admit・native_decide を追加していない |

[公理照会入力](axioms.lean)と[出力](axioms.log)は、中心二命題、新しい補題、正常値・警告原因・位置・独立入力の公開定理の25宣言を照会した。依存は propext・Classical.choice・Quot.sound の範囲内であり、sorryAx や独自公理はない。中心命題や既存の主定理の保証を弱める判断、言語の規則の変更、公理の追加を要する停止条件には当たっていない。

## 独立例の作成時の関門

守る契約は、型ごとの固定域・域外の拒否と域内の他の失敗・二表と出現キーによる同定である。幅そのものをシフト量の上端にする、Byte を64ビットと扱う、port=0を拒否する、区間の端の交差や Bottom を域外にする、Listener を opaque にする、同じ表示名の別宣言を標準と認める変更で失敗する。

既存の例は Range と算術、および一般の fixedDomain に対する exit の一点の例であり、今回の契約表・標準関数とエフェクト操作の位置の同定は確かめていない。その境界に6個の #guard と5個の証明例をまとめ、期待する数値・型・同定結果を独立に記述した。解析器・評価器の具体入力を kernel の計算で実行しておらず、新しい試しの計算は -M 6144 と時間上限で検査した。型の構成だけを比べる小さな例は rfl、実際の標準評価は構成子と局所補題の合成で示す。テスト専用の公開範囲・本番の引数・注入点は足していない。既存テストの削除や期待値の緩和はない。

## 検査と途中の修正

実行場所は `<repo>`、Lean は固定版4.34.1、Rust は固定版1.98.1（実行した rustc も1.98.1）である。lakefile.toml の -M 12288 は不変である。[local-build.py](local-build.py)でローカル import を依存順に一モジュールずつビルドし、Lake の内部に未ビルドの Lean を並行起動させない。[process-control.py](process-control.py)は時間上限時にプロセス群を停止し、終了を回収してから戻す。Sound は175秒、既存 Examples は25秒、他は300秒を上限とした。Lean を背景に残して別の作業へ進めていない。

| 検査・コマンド | 終了状態・結果 | 外側の時間と記録 |
|---|---|---|
| `lake env lean -M 6144 Benitoite/Interval/FixedDomain.lean` | 0 | 0.413秒。[記録](fixed-domain-local.json) |
| `lake env lean -M 6144 Benitoite/Interval/Sound.lean` | 0 | 32.892秒。[記録](sound-local.json) |
| `lake env lean -M 6144 Benitoite/Interval/FixedDomainExamples.lean`（最後の型・同定例の追加後） | 0 | 0.420秒。[記録](fixed-domain-examples-types-fixed.json) |
| 全261モジュールの直列ビルド | 修正後0 | 70.846秒。[全試行のログ](sequential-build.log)・[成功した実行の集計](sequential-build.jsonl) |
| 最後の独立例の変更後、FixedDomainExamples と Benitoite の依存251モジュールを直列ビルド | 0 | 40.084秒。同上のログと集計 |
| 公理照会25宣言 | 0 | 0.650秒。[記録](axioms.json) |
| `lake --no-build build` | 0、既定の353ターゲットが最新 | 0.149秒。[出力](default-up-to-date.log)・[記録](default-up-to-date.json) |
| 下記と同じ基準・指定の dry-run | 0、指定三単位だけを選択 | 0.011秒。[出力](dry-run.log)・[記録](dry-run.json) |
| 指定 work 三単位、一度 | **検査本体0、三単位成功**。spec_examples は7件成功・失敗0・ignored 0、3.03秒 | 検査本体6.620秒、計測器を含め6.648秒。[出力](work.log)・[本体の記録](work-check.json)・[計測器の記録](work.json) |
| 基準と参照定義・旧言明・固定入力の差分点検 | 0 | [点検器](contract-check.py)・[詳細](contract-check.json)・[実行記録](contract-check-run.json) |

指定 work は次のコマンドを [work-check.py](work-check.py) から一度実行し、その外側を `/usr/bin/time -l` で包んだ。

```sh
scripts/check.sh --level work --base be57d4e92d7a48fb74dc33a4d3c3867b60207aeb --only formal_build,spec_examples,spec_tally
```

**最大常駐量（maximum resident set size）は取得不能である。** 検査本体が selected checks passed・終了0となった後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1になった。計測器の終了1を検査の失敗や成功へ読み替えず、両者の終了状態を分けた。補助の ps によるプロセス情報の取得も環境に拒否された。時間上限による停止・メモリ不足・番人による停止はなかった。

spec_tally の自己検査は成功し、初回リリースの未記入の完了条件は none である。Rust のテスト参照がない仕様節の情報表示には、既存の Lean の節と新しい固定域の節が含まれる。Lean の定義と独立例は既定のビルドで検査した。

途中の失敗と修正は次のとおりである。すべての Lean の試行の出力は上記のログまたは対応する局所ログへ残した。

- FixedDomain の初回ビルドで、閉区間の kind の推論と使用できない by_contra により失敗した。Integer64 を明示し、端点の二つの比較の by_cases と omega に直して成功した。
- 独立例の初回は record update の括弧・レイアウト、予約語 at、partialCall の引数順で失敗した。表層の定義に合わせて修正した。最後の型の例の追加時は、Eff を含む Ty 全体に DecidableEq がないため #guard による型の等号が失敗し、構成だけを比べる rfl の証明例へ直した。いずれも上限を増やしていない。
- 全件ビルドの最初は SyntacticReach の位置への含意に旧認定の結果をそのまま渡して失敗した。WarningsInSyntacticReach.located の本文で arithmetic_target_at を使い、言明を変えずに修正した。
- 差分点検器の初回は、変更のない全 formal も言明の解析へ渡し、既存の宣言形式を読み取れず失敗した。変更のないファイルはバイト一致で確認し、変更したファイルだけを言明の解析へ渡すよう修正した。Lean の定義や検査の基準を変更していない。

## 固定表・計画との差・申し送り

**A11 の固定表・生成元・再生成器・README の7ファイルは基準と全バイト一致し、再生成・再計算していない。** 解析器・予算・閉じた評価器が不変であるため、本枝で新たに期待値が変わる形は0件である。先行作業が既に報告した旧固定表との差は本枝の新しい差ではなく、既存の A16〜A18 の引き継ぎに従う。

Eval.lean の既存規則を再利用したため、同ファイルの変更は不要だった。位置の一般化に伴い Sound・BudgetLocated・BudgetBody・SyntacticReach と既存の位置の独立例を変更したほか、新しい独立例を別モジュールにまとめた。計画の言語の規則・保証・検査の割り当ての変更はない。W0404 の候補生成、固定域 call の表層評価、レコード欄は L23〜L25 の割り当てであり、L22 で実装済みとは扱わない。

| 担当・時期 | 引き渡す内容と残る実装・検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、後続へ渡す前 | L22 の定義・言明・参照定義の向き・公理の独立レビューと受け入れ。位置の一般化以外の公開保証と固定表の不変を確認する | 不明 |
| L23、L22 の受け入れ後 | HTTP の二つの欄の構築・局所保存。@opaque の data とレコードの構成子は実交換から同定する。引数のソース順と契約上の位置を区別する | 計画の当該枝に従う |
| L24、L23 の後 | 固定域 call と HTTP 欄の評価・解析・W0404 を接続する。正常な全引数が得られた場合の fixed_at_disjoint_failed を使い、中心命題へ前提を足さない。StandardRule.argumentType の Range 用の一律の型を異種の引数列へ使わず、FixedDomainApi.argumentTypes と実署名を照合する。未知の規則との重なり・欠け、位置・構文的な到達可能性・独立入力の保証も同じ区切りで閉じる | 計画の当該枝に従う |
| L24 の位置の証明 | targetOperationAt env warning.key source を使える。現在の内部の LocatedIn・RootWarning・InSyntacticReach は、旧保証を保つため算術のままである。標準の警告を加える際に既存の公開保証を弱める必要があれば、D15 の停止条件に従って戻す | 上記の接続に含む。証明の反復時間は不明 |
| L25・C4、A19〜A21、X02・X03、計画の各区切り | 全 API の内外・交差・名前付き順・HTTP 欄と更新の独立例、構成に実在する解決済み宣言と型の Rust 接続、A1 の信頼の範囲としての実 VM 比較、各 work と接続の stage、独立レビュー・受け入れ | 各計画に従う。今回未測定の範囲は不明 |

検査後の実装・設計書・固定表は [work-inputs.json](work-inputs.json) と [最終確認](final-review.json) で同一性を照合した。以後の編集は L22 の結果と確認記録だけである。別状態の検査結果の引用による省略はない。Rust/Lean・VM の全比較、stage・change・release、性能測定は本枝で先取りしていない。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめへ引き渡す。private/ とそこを指すリンクは読まず、git の変更操作は行っていない。

## 取りまとめのレビュー（2026-10-26）

中心二命題の本文と Eval.lean は基準と同じで、sorry・公理・`decide +kernel` の追加はない。`targetOperationAt` を抽象環境・出現キー・式を受け取る形へ一般化し（C1Rc の申し送り）、算術の認定を保ったまま、認定した標準束縛の call を対象位置に加えた。これは警告の位置の述語（`analyze_warning_located` などが参照する）が許す位置を、W0404 の対象の標準 call へ広げる計画どおりの拡張である。公開の定理の意味がこれ以外で弱まっていないかは、C4 のレビューで確かめる。固定表は不変。L23 へ進む。
