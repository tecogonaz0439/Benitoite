# L21V の結果

- 着手: 2026-10-26 06:26:56 JST。
- 終了: 2026-10-26 06:37:56 JST。所要時間は11分0秒である。
- B_WORK・開始時と終了時の HEAD: `a7944afaa0d93f8beaebce37f45e242d2c8dadbb`。

**状態: 指定された L21V の修正と検査を完了した。独立レビューと受け入れは取りまとめへ引き渡す。** 中心二命題の本文、公開入口の主定理の言明、評価関係・解析器・計上の定義、Models、既存公理、固定表は変更していない。停止条件に当たる変更・判断待ち・本作業が受け持つ未実施の検査はない。

## 基準と修正の範囲

枝は `mod012/L21V`。依頼の補足、RV-L21U-response の L21V の各行、同文書末尾の RV-L21T の残り三件に従った。開始時から l21u/results.md と RV-L21T-response.md に未コミットの変更、RV-L21U.md と RV-L21U-response.md に未追跡の入力があった。[開始状態](start-state.json)に状態と入力の SHA-256 を記録した。取りまとめの変更を保ったうえで、前二文書の該当箇所を訂正した。RV-L21U の二文書は開始時と全バイト一致する。

AGENTS.md・共通依頼文・plan の前提、受け渡す契約、L21 と検査割り当て、decisions D15/D18、指定されたレビューと結果記録を読んだ。private/ とそれを指すリンクは読まず、git の変更操作、委任、docs/todo の編集、コミット、取り込み、公開は行っていない。公開の japanese-tech-writing・test-audit・rtk を使用した。新しい依存・機能は加えていない。

| 所見 | 修正と対応箇所 |
|---|---|
| RV-L21T 軽1：Ok 認定を通る合成例 | [Range.lean](../../../../formal/Benitoite/Interval/Range.lean) の保存・Ok 束縛・射影の既存例に `different : names.ok ≠ names.err` を加え、`range_bind_ok_models different saved fromCheck known` と `range_result_ok_models different fromCheck known` を使う形に戻した。既知の三欄から CheckedModels を直接作る迂回を除いた |
| RV-L21U 軽2：小モデルと成功値の三欄 | 同ファイルの独立補助定理 `range_check_small_model` の成功の腕を、標準規則の結果が `rangePayload names.record lo hi value` であり、`raw = ⟨lo.toInt, hi.toInt, value.toInt⟩` であるという連言にした。`erase_make` と `make_ok` から証明し、失敗の両腕は不変。01-12 の表、07-04、l21u/results.md の説明も合わせた |
| RV-L21U 軽1：成功値・射影の旧説明 | [01-12](../../../design/01-spec/01-12-core-calculus.md) の標準規則の【決定】を、三入力の三欄保存と所属、所有元・構成子・型引数なし・三欄の Integer64 型を認定した射影に合わせた |
| RV-L21U 軽3：呼び出しキー | [RangeState.lean](../../../../formal/Benitoite/Interval/RangeState.lean) の ResultModels・CheckedModels のコメント、01-12 の独立例の説明、[07-04](../../../design/07-quality/07-04-formal-semantics.md)、l21u/results.md を訂正した。具体値との関係は同じ標準規則と二端点で定まり、キーによらない。呼び出しキーは由来の認定と記録の側にあり、成功値の束縛番号は RangeLocalFact に保持する |
| RV-L21U 軽4・RV-L21T 軽3：Result のコメントと対応記録 | [Eval.lean](../../../../formal/Benitoite/Interval/Eval.lean) の「不透明な Result」を「内部を読まない other の Result」に修正した。RV-L21T-response の軽3 と l21u/results.md の取りまとめのレビューに、OpaqueName の解消と残っていたコメントの今回の修正を分けて記した |
| RV-L21U 軽5：RangeNames の入力条件 | 01-12 では、所有元・レコード構成子が保存済み実交換の宣言と一致することを、Lean に渡す入力の条件として定めた。評価規則が表示名を照合するとは書かない。交換から取り出す処理系の実装を完了済みとする記述を除いた |
| RV-L21T 軽2 の残り：経緯の書き方 | 01-12 の「data となったため」を、現在の成功型・エラー型と所有元の条件の説明に直した |
| RV-L21T 軽4：E0340 | 01-12 で対象操作を言い換えず、01-03「公開（初回リリース版）」の規範へのリンクを置いた |

変更した Lean は三ファイルだけである。定義のコメントは6行追加・4行削除、独立補助定理の言明と証明は5行追加・3行削除、既存の合成例は3行追加・6行削除である。Rust の本番・テスト、Examples.lean、閉じた評価器、標準ソース、型・エフェクト、ツールチェーン、lakefile.toml は変更していない。

## 中心二命題・参照定義・公理

[契約の確認器](contract-check.py)と[確認結果](contract-check.json)、[内部言明の差分](internal-statement-diff.json)を保存した。git diff も読んで確認した。**既存の名前付き定理3,450件の言明がバイト単位で一致し、変更した言明は独立補助定理 range_check_small_model の一件だけである。** 公開入口へ新たな前提を加えていない。Interval の外の formal は全ファイルが基準と全バイト一致する。

| 定義・言明 | B_WORK との差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | 本文を含め不変 | 前提・量化・結論を保持 |
| 公開入口の主定理・既存の主定理 | 言明不変。独立補助定理と例以外の証明も不変 | 公開の前提・結論と意味を保持 |
| EvalPartial・EvalArguments・EvalBlock・Unmodeled・UnknownAt・NormalTyped・rangeCallBinding | 定義不変 | 具体評価と未知の境界、導出の範囲を変えない |
| ConcreteValue・ConcreteValue.type・RangeNames・RangeRecord・StandardRule・rangeCheck・rangePayload・rangeStoredValue・EvalStandard | 定義不変 | 値の意味・型・三欄・正確な射影・未知の正常値と失敗の規則を変えない |
| AbstractSlot・SlotModels・Models・topSlot | 本文不変 | Models を強めず、具体値を除外しない |
| RangeOrigin.ResultModels・CheckedModels・RangeLocalFact.Models・RangeState.Models | 定義本文不変。前二者のコメントだけを訂正 | 関係の条件を増減しない。キーによらないという既存定義の意味を文書に合わせた |
| targetOperationAt・concreteRule・Reached・構文的な到達可能性・CallReach | 定義不変 | 警告の対象・到達・呼び出しの境界を保持 |
| range_check_small_model | 成功の腕に raw の三入力との等式を明記。成功値から切り離された checked の存在を除いた | 小モデルと成功値の三欄の対応を回復する。解析の証明から呼ばれない独立補助定理であり、公開の前提を変えない |
| range_bind_ok_models・range_result_ok_models | 言明・証明不変。合成例での使用を回復 | 例に既存の内部補助条件を渡し、Result の由来と Ok 認定から同じ成功値への対応を導く |
| analyzeBase*・BudgetAnalysis.analyze*・本体・全体駆動・純粋な認定・計上 | 定義不変 | 走査の順序・回数・保持・停止位置・期待値に変更なし |
| Builtins.Assumptions・既存公理 | 不変 | sorry・admit・独自公理・native_decide を追加しない |

Eval と RangeState はコメントを除いた全文が一致し、Range は上記の補助定理と合成例を除く全文が一致する。中心命題が参照する定義を変えて意味を弱める変更もない。[公理依存の入力](axioms.lean)と[出力](axioms.log)で、変更した補助定理と合成例の経路にある四宣言を照会した。range_check_small_model・range_bind_ok_models・range_result_ok_models は propext だけ、range_value_origin_evaluated は propext・Classical.choice・Quot.sound に依存し、sorryAx はない。

## 例の作成時の関門

修正する例の契約は、検査が返した Result の保存、Ok の認定、新しい束縛番号への三欄の対応、同じ成功値への射影と所属の合成である。Ok の認定から CheckedModels を導く接続が使えなくなる退行を検出する。以前の例は既知の三欄から CheckedModels を直接構成していたため、その接続を確かめていなかった。新しい例を増やさず、この持ち主の境界にある既存例を修正した。テスト専用の入口・引数・フラグは本番に加えていない。

解析器・評価器を具体実行する新しい計算は加えていない。既存の小さな整数値域の decide と既存の記号的な証明を保ち、解析器・評価器を kernel に走らせる decide・rfl・simp は追加していない。期待値・テストの件数・ignore・時間上限は緩めていない。テスト削除を目的とする監査は行っていない。

## 検査・時間・メモリ

実行場所は `<repo>`、Lean は固定版4.34.1である。lakefile.toml の `moreLeanArgs = ["-M", "12288"]` を保った。[直列ビルドの実行器](local-build.py)は既存の L21U の実行器を写し、各 import を依存順に一モジュールずつ構築した。各子のプロセスの終了状態を確認し、ビルドを背景に残したまま別作業へ進んでいない。Sound の上限175秒、Examples の上限25秒、他は300秒を保った。実測は Sound 32.175秒、Examples 5.214秒で、時間上限・メモリ不足による停止はない。

| コマンド・検査 | 終了と結果 | 外側の時間・保存記録 |
|---|---|---|
| `python3 …/l21v/local-build.py Benitoite.Interval.Range` | 0、依存55モジュール | 26.416秒。[直列記録](sequential-build.jsonl)・[全ログ](sequential-build.log) |
| `python3 …/l21v/local-build.py` | 0、全259モジュール | 155.161秒。同上 |
| `lake --no-build build` | 0、既定351ターゲットが最新。既定ビルドで並行再構築が起きないことを事前確認 | 0.153秒。[結果](up-to-date.json)・[ログ](up-to-date.log) |
| `lake env lean -M 6144 Benitoite/Interval/Range.lean` | 0、300秒上限 | 1.182秒。[結果](range.json)・[ログ](range.log) |
| `lake env lean -M 6144 ../docs/…/l21v/axioms.lean` | 0、300秒上限。四宣言の依存に sorryAx なし | 0.620秒。[結果](axioms.json)・[ログ](axioms.log) |
| 同じ B_WORK・指定の work の dry-run | 0、指定三単位だけを選択 | 0.012秒。[結果](dry-run.json)・[選択](dry-run.log) |
| 指定 work、一度、`/usr/bin/time -l` で計測 | **検査本体0、三単位成功。計測器1** | **71.542秒**。[結果](work.json)・[全ログ](work.log) |
| work に含む仕様例（spec_examples） | 7件成功、失敗0・ignored 0 | テスト本体3.11秒 |
| work に含む仕様対応表（spec_tally） | 自己検査・集計成功、完了条件の未記入 none | 未参照節の一覧も表示される |
| work に含む既定の形式化ビルド（formal_build） | 既定 lake build と sorry 拒否が成功 | 直列再構築済みのキャッシュを使用 |
| 契約・差分の確認 | 0 | [契約確認結果](contract-check.json)。最終の記録・リンク・入力の確認は [最終点検](final-review.json) |

検査の正確な指定は次のとおりである。[検査の実行器](run-check.py)は出力の伏せ字、300秒上限、子の終了確認と外側時間の保存だけを行い、検査内容を変えない。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。

```sh
scripts/check.sh --level work --base a7944afaa0d93f8beaebce37f45e242d2c8dadbb --only formal_build,spec_examples,spec_tally --dry-run
/usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l21v/run-work.sh
```

[run-work.sh](run-work.sh)は dry-run と同じ指定で検査を実行し、実際の終了0を `L21V_CHECK_EXIT_STATUS=0` として保存する。計測器は `sysctl kern.clockrate: Operation not permitted` により終了1になった。**最大常駐量（maximum resident set size）はサンドボックスで取得不能**であり、検査本体の不合格とは扱っていない。time の real/user/sys は71.53/431.11/55.08秒だった。この計測は依存の直列ビルド後の作業末の三単位だけを対象とし、途中のビルドのメモリ測定ではない。途中の状態確認に使った ps もサンドボックスで拒否されたが、全ビルドと検査の終了は子プロセスの終了状態で確認した。

最終点検の初回は、リンクを探す正規表現が 01-12 のコード中の `x̄:Ā` をリンク先と誤認して終了1となった（[記録](final-review-first.log)）。コードブロックとインラインコードを除いてからリンクを点検するよう修正した。Lean・設計書・検査内容は変えていない。修正後の点検は終了0である。

Lean と指定検査の失敗、再試行、時間上限の引き上げはない。検査後に Lean・設計書・仕様例・固定表の入力を変えていない。

## 固定表・計画との差・申し送り

A11 の固定表・生成元・再生成器・README の7ファイルは B_WORK と全バイト一致する。再生成・再計算はしていない。本枝では評価関係・解析器・計上を変えていないため、期待値の変化はない。L20d が既に報告した旧固定表との差は既存の引き継ぎに従い、A16〜A18 の担当が扱う。本枝で新たに固定表の期待値を変えたことにはしない。

依頼の修正範囲と検査の割り当てからの拡張はない。最大常駐量を取得できない環境制約を上記のとおり記録した。Rust と実 VM の全比較、check-formal.sh 全体、stage・change・release は本作業の割り当てに含めていない。

| 担当・時期 | 残る検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、後続作業へ渡す前 | L21V の独立レビューと受け入れ。補助定理の三欄の対応、合成例の補題経由、定義の不変、設計書と対応記録を確認する | 不明 |
| A18a、再開時 | 実交換から RangeNames と構成子を取り出す接続・全 Range 入力との照合、割り当てられた固定表・Rust の費用と保持・停止の比較、work、レビューと受け入れ | 計画では2〜4時間。構成子の接続の追加枠は既存の調べで0.5〜1時間 |
| A18b・X02・X03b・取りまとめ、計画の区切り | 文書・生成物の整合、六入口と実 VM の三欄・成否・射影等の全比較、レビューと受け入れ | 不明 |

## 取りまとめのレビュー（2026-10-26）

中心二命題の本文は基準と同じで、sorry・公理・`decide +kernel` の追加はない。言明を変えたのは独立の補助定理 `range_check_small_model` だけで、RV-L21U の軽2 のとおり対応を戻す向きである。評価関係・解析器・計上・固定表は変わらない。RV-L21T・RV-L21U の所見の修正だけなので、独立レビューは置かずに取り込む。A18a を再開する。
