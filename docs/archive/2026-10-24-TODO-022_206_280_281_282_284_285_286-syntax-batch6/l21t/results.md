# L21T の結果

- 着手: 2026-10-26 05:36:05 JST。
- 終了: 2026-10-26 05:57:49 JST。所要時間は21分44秒である。
- B_WORK・開始時と終了時の HEAD: `f6ed14a88c0a4cb6a7ef8305f6837150bf80036d`。

**状態: L21T（Q-opaque-L1）の実装、写し、実交換の型の照合、指定 work は完了した。独立レビューと受け入れは取りまとめへ引き渡す。** 中心二命題・公開入口の主定理・既存の公理は変更していない。`checkedRange` は残し、Q-opaque-L2 は実施していない。

## 基準と変更範囲

枝は `mod012/L21T`。開始時の作業ツリーに差分はなかった。plan.md「計画の変更（2026-10-26、A18a の停止を受けて）」の L21T の行、依頼の補足、a18a の調べの第三案 C に従った。private/ とそこを指すリンクは読まず、git の変更操作・担当の委任・docs/todo の変更・コミット・取り込み・公開は行っていない。公開の test-audit と japanese-tech-writing、rtk を使用した。

| 変更ファイル | 内容 |
|---|---|
| [Eval.lean](../../../../formal/Benitoite/Interval/Eval.lean) | Range の所有元を DataName、成功値の型を `.data owner []` に統一。引数・結果・Result 包装・IsOk・OkPayload・ResultView・Result 認定を同じ型へ変更。未知の con/rangeError の正常・失敗の四規則を追加し、正常結果の型の証明へ接続 |
| [Range.lean](../../../../formal/Benitoite/Interval/Range.lean) | 全域性の対象を data 型へ拡大。型の合う一般の con・rangeError を含めた導出を証明し、正確な射影を保持。Result 認定の非等号を内部補助証明へ受け渡す。型を含む補題・既存例を更新 |
| [RangeState.lean](../../../../formal/Benitoite/Interval/RangeState.lean) | CheckedModels の説明を data 型へ更新。定義本文・三欄・呼び出しキー・表現可能性の条件は不変 |
| [BudgetRange.lean](../../../../formal/Benitoite/Interval/BudgetRange.lean) | Result の型の認定と成功値の型、rangeValueSource の所有元の型別名を統一。走査・計上の処理は不変 |
| [EvalClosed.lean](../../../../formal/Benitoite/Interval/EvalClosed.lean) | Result の型引数と payload の型の照合を data へ変更。決定的に射影するのは引き続き checkedRange。一般の sameType の opaque 分岐は保持 |
| [Examples.lean](../../../../formal/Benitoite/Interval/Examples.lean) | Range の型を統一。任意の欄数・欄の型の con と同じ所有元の rangeError に任意の正常整数・未知の失敗の導出がある例、閉じた評価器が未知の表現を選ばない表を追加。既存の計上・停止・区間・警告の期待値は不変 |
| [01-12](../../../design/01-spec/01-12-core-calculus.md)・[07-04](../../../design/07-quality/07-04-formal-semantics.md) | 型、射影の全域性、Result の区別、公開境界の意味、checkedRange を使う A1 の限界を反映 |
| 本ディレクトリ | 実交換の型の確認器、差分・公理依存の照会、検査の実行器と記録 |

形式化の Examples ファイルは **38行追加・13行削除**。それ以外の Lean 五ファイルは **133行追加・95行削除**（Eval・Range にある既存例の型の変更も含む）。Rust、本体の標準ソース、型とエフェクトの規則、Release・Surface、依存、固定表、ツールチェーン、lakefile.toml は変更していない。

## 型・導出・同じ成功値の保証

checkInteger の正常な戻り値は `.data result [.data owner [], .data error []]`、value の引数は `.data owner []` となる。成功値の具体表現は `checkedRange owner checkKey checked` のままであり、`Checked.Range.CheckedInteger` の三欄と所属の証拠を保つ。一般の三欄の `.con` と同じ表現にしたとは扱わない。

`ConcreteValue.type` は一般の con の内部を検査しない。このため、型の合う con と rangeError に `rangeValueCon`・`rangeValueError`（任意の正常 Integer64）、`rangeValueConFailed`・`rangeValueErrorFailed`（未知の失敗）を追加した。other の同じ近似も保持する。これらは checkedRange と構成子で分かれ、`range_value_exact` の正確な結果に重ならない。表現不能な checkedRange への `rangeValueUnrepresentable` も保持する。

`range_value_total` は同じ data 型の全表現に導出を構成する。型の合う値を Models・SlotModels から除外していない。閉じた評価器は未知の表現に任意の値を選ばず、none を返す。01-12 と 07-04 は、D18 の「不透明」を E0340 が担う公開境界として説明し、コアの opaque 型と区別した。

## 中心二命題・参照定義・補助言明・公理

[照合スクリプト](contract-check.py)・[照合結果](contract-check.json)・[言明の差分](internal-statement-diff.json)を保存した。既存の名前付き定理 **3,437件の言明がバイト単位で一致**する。型の符号化だけを変えた言明は9件、内部補助条件を追加したものは次の4件である。公開解析入口の主定理の言明は全て一致する。Interval の外の formal は全ファイルが基準と一致する。

| 定義・言明 | 差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | 本文を含め不変 | 量化・前提・結論を保持 |
| EvalPartial・EvalArguments・EvalBlock・Unmodeled・UnknownAt・rangeCallBinding・NormalTyped | 不変 | 具体評価の入口と未知の境界は保持。参照する Range の型と標準規則を下記のとおり変更 |
| ConcreteValue・ConcreteValue.type・RangeNames・StandardRule | owner の型別名、checkedRange の型、引数・結果・包装を data に統一 | 実交換の型に接続。成功値の三欄・証拠・呼び出しキーは保持 |
| EvalStandard | con/rangeError の正常・未知の失敗の四規則を追加 | 新たに型が合う全表現に導出を残す。checkedRange の正確な規則と重ねない |
| IsOk・OkPayload・ResultView・rangeResultNames/Viewable | 成功型と Result 型引数を data に統一 | con の所有元・型引数・構成子・payload の型を照合。other の任意値の近似を保持 |
| AbstractSlot・SlotModels・Models・topSlot・RangeOrigin.CheckedModels・ResultModels・RangeState.Models | 本文は不変 | 不都合な具体表現を除外する条件を加えない。標準表の名前の別名は DataName に統一 |
| targetOperationAt・Reached・concreteRule・構文的な到達可能性・CallReach | 不変 | 警告の対象・到達・未認定 call の除外の保証を保持 |
| range_result_ok_models・range_bind_ok_models・range_ok_payload_models | Ok と Error の構成子の非等号を内部補助条件として追加 | 従来の opaque/data の型の区別に依存せず Error を除外。認定済み Result では既存の rangeResultMatch から構成する |
| range_match_ok_models | evaluated が返す局所の証拠に同じ非等号を追加 | 呼び出し側 baseResultArmEnv_ranges が既存の range_result_match_distinct から渡す。公開入口へ新たな条件を加えない |
| range_value_total など9言明 | 成功型の opaque→data と所有元の型別名の統一だけ | 指定された対象型を拡大。range_value_exact の言明は不変 |
| analyzeBase*・BudgetAnalysis の実行定義・予算・発見・独立入力・本体・全体の駆動 | 不変 | Range の型の認定以外に、走査の順序・回数・保持・停止位置の変更はない |
| BudgetScan.range*・純粋な Range の認定 | 型の符号化以外は不変 | [最終点検](final-review.json)で型の置換後の全文・定義の一致を確認 |
| Builtins.Assumptions・旧主定理・既存公理 | 不変 | Interval の外のバイト一致と、公理追加・証明の穴の検出で確認 |

補助条件が必要になったのは、任意の RangeNames は owner と error、ok と err の同一性を禁止していないためである。型がともに data になると、Error を型の頭だけで排除する旧証明は使えない。既存の Result 認定はもともと ok ≠ err を要求しており、その事実を内部へ渡すことで、認定・計上・公開の前提を変えずに閉じた。

[公理照会入力](axioms.lean)・[最終出力](axioms-final.log)は83宣言を確認し、依存は propext・Classical.choice・Quot.sound の範囲内である。range_value_total・range_value_exact・range_result_ok_models の依存は propext だけである。入力末尾の二例では、実交換の確認器の期待型と StandardRule の定義が一致することも確認した。sorry・admit・独自公理・native_decide は追加していない。

## 保存した実交換との照合

[a18a の保存済み実交換](../a18a/surface-export/corpus.json)をそのまま読み、[確認器](check-surface-types.py)を l21t に写して期待型を新しい StandardRule に合わせた。元の a18a の確認器・JSON・ソースは変更していない。型名と解決済み標準宣言は実交換から取得し、BindingId を固定していない。

| 照合箇所 | 結果 |
|---|---|
| checkInteger の戻り値（Result の二型引数を含む） | `.data result [.data owner [], .data error []]` で一致 |
| checkInteger の三引数 | 三つとも Integer64 で一致 |
| value の引数（recheck の局所引数の型も含む） | `.data owner []` で一致 |
| value の戻り値 | Integer64 で一致 |

[型の照合結果](surface-types.json)に実型・期待型・全四箇所の判定・Lean の定義ファイルの SHA-256 を保存した。**確認器は終了0、allEqual は true**。保存された既存の range.bnt の型の整合を確認した結果であり、全 Range 入力や実 VM との意味の一致まで確認した結果ではない。

## 例の作成時の関門

守る契約は、data 型に統一した後も、既知でない内部表現に任意の正常整数と未知の失敗の導出を残すこと、閉じた評価器が近似規則から値を選ばないことである。未知の con/rangeError の規則を削る、欄数や欄の型から誤って checkedRange と同じ射影をする変更で失敗する。

既存の other の例と checkedRange の正確な射影の例は残し、追加対象になった con/rangeError を一つの表の形の導出例と、閉じた評価器の一表にまとめた。後者には欄なし・二欄・整数三欄・同じ所有元の rangeError を置く。実際の評価関係と閉じた評価器を使い、テスト専用の本番の入口・引数・フラグは加えていない。解析器・評価器の具体実行は #guard を使い、kernel に実行させていない。削除したテストはなく、既存の計上・停止の期待値も変えていない。

## 検査と途中の失敗

実行場所は `<repo>`、Lean は固定版4.34.1。lakefile.toml の `-M 12288` を保持した。Lean のプロセスを重ねず、[local-build.py](local-build.py)で依存順に一モジュールずつ実行した。既定ビルドの前に `lake --no-build build` で351ターゲットが最新であることを確認し、既定ビルドに未ビルドの Lean を並行起動させていない。例・試行の単体検査は `-M 6144`、上限25秒（Examples）・175秒（Sound）・それ以外300秒を使う。今回、時間上限による停止・メモリ不足はない。

| コマンド・検査 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| local-build.py の局所依存 | Eval、Range、EvalClosed、BudgetRange、BudgetWhole と依存証明が成功 | [全試行のログ](sequential-build.log)。各子の終了状態・時間を保存 |
| `lake env lean -M 6144 Benitoite/Interval/EvalClosed.lean` | 0 | 2.748秒。[記録](eval-closed.json) |
| `lake env lean -M 6144 Benitoite/Interval/Examples.lean` | 修正後0 | 4.994秒。[記録](examples-fixed.json) |
| 全259モジュールの直列ビルド | 0 | 初回59.404秒、最終の型別名・コメント訂正後144.200秒。[記録](sequential-build.jsonl) |
| `lake --no-build build` | 0、351ターゲットが最新 | 最終0.151秒。[記録](default-up-to-date.json) |
| 指定三単位と同じ基準・指定の dry-run | 0、三単位だけを選択 | 0.010秒。[記録](dry-run.json) |
| 指定 work 三単位、一度（下記） | **本体0、計測器0、三単位成功** | **6.233秒**。[出力](work.log)・[記録](work.json) |
| spec_examples（work に含む） | 7件成功、失敗0・ignored 0 | 2.95秒 |
| spec_tally（work に含む） | 自己検査・集計成功。完了条件の未記入 none | 未参照節の一覧は表示される |
| formal_build（work に含む） | 既定ビルドと sorry 拒否が成功 | 上記 work に含む |
| 最終の型別名・コメント訂正後の formal_build のみ再検査 | **本体0**。同じ指定の dry-run 後に実行 | 0.169秒。[出力](formal-final.log)・[記録](formal-final.json) |
| `lake env lean -M 6144 <本ディレクトリ>/axioms.lean` | 最終0、83宣言 | 0.313秒。[記録](axioms-final.json) |
| 型・固定表・主定理・計上・差分の最終点検 | 0 | [点検スクリプト](final-review.py)・[結果](final-review.json)。型の照合・契約の照合のコマンドと時間も保存 |

指定の work は次のコマンドである。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。

```sh
scripts/check.sh --level work --base f6ed14a88c0a4cb6a7ef8305f6837150bf80036d --only formal_build,spec_examples,spec_tally --dry-run
scripts/check.sh --level work --base f6ed14a88c0a4cb6a7ef8305f6837150bf80036d --only formal_build,spec_examples,spec_tally
```

[run-work.sh](run-work.sh)を `/usr/bin/time -l /bin/zsh` で包み、本体の終了を L21T_CHECK_EXIT_STATUS として保存した。**三単位の work の最大常駐量は664,780,800バイト（約634.0 MiB）**。real/user/sys は6.23/4.81/0.74秒である。これは依存の直列ビルドを終えた後の work の測定であり、途中の再コンパイルの最大量ではない。

その後の型別名・コメントの訂正では Lean だけが古くなったため、依存を直列に再構築し、同じ B_WORK の `--only formal_build` の dry-run と実行だけを追加した。仕様例・集計の入力にはその後の変更がなく、重ねて実行していない。再検査も time で包んだが、計測器は `sysctl kern.clockrate: Operation not permitted` で終了1となり、最大常駐量は取得不能だった。検査本体の終了0は明示した marker で確認している。real/user/sys は0.16/0.08/0.15秒である。

途中の失敗は次のとおりである。いずれも修正後に関係する検査を成功させた。

- 最初の Range の検査では、Error を opaque/data の違いで除外する旧証明と、payload の data の型引数の空列の反転が通らなかった。前者は既存認定の構成子の非等号を内部補助条件として渡し、後者は型引数を場合分けして修正した。その修正中の例で、任意の RangeNames に非等号を decide/simp で作ろうとした誤り、IntegerRepresentable の判定、state の推論に失敗した。実際に成功した checkedRange の三欄から対応を直接構成し、閉じた小さな整数の条件と state を明示した。主定理や Models の変更で回避していない。全試行は sequential-build.log に残す。
- Examples の追加表の初回は5.030秒・終了1。リストの二要素の所属の簡約に空列の否定と or_false が不足していた。[初回](examples.log)を保存し、同じ期待値で修正後4.994秒・終了0となった。
- 差分確認器の初回は、変更のない既存の定理まで簡易の構文解析をしたため失敗した。次は WarningSoundness の抽出範囲に後続の例まで含めて差分と誤認した。前者は変更のないファイルの全バイト一致、後者は宣言の終端の認識を直して解消した。最後のリンクの点検では仕様のコードの記法を Markdown リンクと誤認したため、コードフェンスとインラインコードを除いて走査するよう直し、二つの設計書と結果のリンクの存在を確認した。
- 最終点検で BudgetRange.rangeValueSource の OpaqueName という型別名の残りを検出した。実体は同じ文字列型なのでビルドは成功していたが、DataName に統一し、上記の直列再構築と formal_build を実行した。

## 固定表・計上・申し送り

**A11 の固定表・生成元・再生成器・README の7ファイルは B_WORK と全バイト一致する。** 保存済み表を再生成していない。BudgetRange の変更は型の符号化と型別名だけであり、純粋な認定も型の置換後の定義が一致する。Analyze・BudgetAnalyze・BudgetScan・BudgetRangeBorrow・BudgetDiscover・BudgetChildren・Budget・BudgetWhole は変更していない。withE のリソース用の opaque とその例も保持した。

固定表の元入力は AbstractEnv.ofLocals [] で標準表を空にし、Range の標準呼び出しの認定を持たない。この枝で変わる期待値の形は見つかっていない。既存の RangeSurface の操作数・保持数・停止・候補の期待値も変更せずに既定ビルドが成功した。今回、固定表の全行を新しい Lean で再計算して照合したとは扱わない。L20d が既に報告した旧固定表との差分は、本枝で作った差分ではなく、引き続き A18a の担当である。

[最終点検](final-review.json)には、formal・固定表・二つの設計書の SHA-256、保護した宣言、計上の型以外の不変、index が空であること、記録中のパスの伏せ方と Python の構文、git diff --check の成功を保存した。最終の Lean 検査後に変えたものは、本ディレクトリの記録・確認器だけである。

| 担当・時期 | 残る検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A18a 再開前 | L21T の定義・言明・仮定の独立レビュー、四つの内部補助条件が既存の認定から構成されること、実交換の四箇所の一致を確認して受け入れる | 調べの目安30〜60分 |
| A18a、L21T の受け入れ後 | 全 Range 入力・Surface と番号・固定表の追加、Rust の計上と分類の照合、割り当て量と全統合の work、レビューと受け入れ | 計画の2〜4時間 |
| A18b・X02・X03b・取りまとめ、計画の各区切り | 設計書・生成物の全体整合、関係状態の区間・費用の比較、実 VM の三欄・成否・逆転優先・射影・到達の比較、既存六入口を含む全体比較と受け入れ | 各計画に従う。今回の関係状態での実測は未実施のため不明 |

L21T が受け持つ未実施・不合格の検査は残っていない。実 VM との比較・check-formal.sh 全体・stage・change・release は本枝では実施していない。型の不一致は解消したが、一般の三欄の con への表現の統一は行っておらず、07-04 にその限界を記した。後続作業は checkedRange を使う現行の規則を前提とする。

## 取りまとめのレビュー（2026-10-26）

中心二命題の本文は基準と同じで、sorry・公理・`decide +kernel` の追加はない。保存済みの実交換の四箇所が新しい `StandardRule` の型と一致した。内部の補助補題4件への条件の追加は、既存の Result の認定から得る構成子の非等号であり、D15 の追記の範囲にある。固定表は全バイト一致。定義の独立レビュー（RV-L21T）を L21U と並行して頼む。07-04 の「三欄の構成子に統一していない」の一文は、設計者の訂正（次の版からの方針を今の改造に当てはめない）を受けて置く L21U で消す。
