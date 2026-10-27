# L28 の実装結果

着手（最初の時刻取得）: **2026-10-26 17:41:12 JST**。終了: **2026-10-26 18:12:57 JST**。所要時間: **31分45秒**。時刻取得より前の指示の読み込みは、この計測に含めていない。

**状態: L28 の解析・具体評価の比較報告、base/flow の独立期待値、指定 work を完了した。独立レビュー・受け入れは取りまとめへ引き渡す。**

B_WORK・HEAD は `640538669de0da18d8d0947327ff9c84fef22b55`、ブランチは `mod012/L28`。着手時には Exchange.lean・ExchangeExamples.lean に途中の差分があった。flow の読者、具体評価と独立入力の期待の読者、追加した欄に合わせた既存例のパターンを引き継いで完成させた。既存差分を消して作り直してはいない。private/ とそれを指すリンクは読まず、担当の委任と git の変更操作を行っていない。

共通依頼文、plan の前提・契約・L27〜L29・X01〜X05・C1R2・計画の変更、decisions の D5・D15・D17・D20 と D4 の変更、README の設計者の決定、preflight、study の9.3〜9.4、L26・L27a・L27b・L25T・A21d の結果と現行の実装・対応する設計書を確認した。

## 変更した範囲

| ファイル | 実装した内容 |
|---|---|
| [Exchange.lean](../../../../formal/Benitoite/Interval/Exchange.lean) | base/flow の期待結果を厳密に読み、`analyzeCorpus` と `evalCorpus` を別々に提供する。解析は `BudgetWhole.analyze` を使い、本体・独立入力の正常値、候補のキー・演算・原因、coverage、終了前の context、終了後の after を比較する。mayFail は観測だけとする |
| 同上の報告 | 元定義と別本体の全 manifest、本体別の comparisonEligible、未着手の本体と原因、段停止、本体の停止、残る元入力、発見・待ち行列・別本体の進行、専用射影による集計を JSON に残す。取得済みの番号・次の番号・保存した候補を停止時も保持する |
| 同上の評価 | `evalClosed` の normal・failed・returned、キー・演算・正常引数・結果を持つ trace を比較する。引数付きの元定義、評価不能、unknown の失敗、環境を作っていない別本体は理由付きの除外とする。unknown の観測結果は observed に残し、実行比較件数には含めない |
| [IntervalDiff/Main.lean](../../../../formal/IntervalDiff/Main.lean) | `intervalDiff analyze\|eval INPUT REPORT` を接続した。受け入れ0、不一致・比較対象なし1、不正入力・引数・IOの失敗2。生入力を重複欄を失わない読者へ渡す。INPUT と REPORT が同名なら拒否し、入力を変更しない |
| [test_interval_exchange.py](../../../../formal/tests/test_interval_exchange.py) | 独立した区間・trace・消費の期待を持つ正常入力と、その一箇所を壊した負例を実 CLI から検査する。47回の起動、base/flow と fuel 再選択を含む。Lean のビルドはこの Python から起動しない |
| [ExchangeExamples.lean](../../../../formal/Benitoite/Interval/ExchangeExamples.lean) | 追加した欄に合わせ、既存の2か所の構造体パターンを更新した。既存の正負例の期待を緩めていない |
| [01-12](../../../design/01-spec/01-12-core-calculus.md#区間解析の独立交換の読者)・[07-04](../../../design/07-quality/07-04-formal-semantics.md#区間解析の独立交換の読者) | 追加した交換の型・入口・比較項目、fuel、除外、終了状態と保証の限界を反映した。見出しは改名していない |

`context` は読者だけの入力では任意だが、analyze で比較する本体には必要とした。`after` は本体の消費をリセットした後なので、それだけで body の操作数やピークまで比較済みとしないためである。context は budget・next・identities・unsupported を持ち、独立期待値と一致しなければ終了1になる。別本体の期待は expectedBodies へ置き、元構文の manifest にない名前を拒否する。

数学的な manifest と初期 fuel のための全列挙は交換の検証にだけ使い、予算付き解析の事前走査へ接続していない。元定義・別本体・独立入力の状態と停止を混同せず、利用者向け件数には BudgetWhole の専用射影を使った。段停止の事象数を利用者向けの本体数へ置き換えていない。入口・待ち行列・別本体制御の afterDefinition は定義終了後の状態であり、失われた停止直前の body の状態を推測して補ってはいない。

## 独立期待値と fuel

[比較の要約](comparison-summary.json)、[fuel の選択](fuel-selection.json)、[生の入力・報告 ZIP](test-records.zip)・[各ファイルの SHA-256](test-records-index.json)に保存した。ZIP は生成した全ファイルの内容とハッシュを照合してから展開物を片付けた。初回の失敗の入力・報告も同じ ZIP に含む。最終検査の記録は ZIP 内の `tests-final/` にある。

| 正常な固定コーパス | 元定義 | 解析の比較本体 | Top 以外の本体 | 解析の深さ除外／段の深さ停止 | 評価の比較／除外 |
|---|---:|---:|---:|---|---|
| base、fuel 132 | 8 | 8 | 6 | 0／0 | 8／0 |
| flow、fuel 292 | 9 | 10（別本体1を含む） | 8 | 0／0 | 7／3 |
| flow の長い容器、fuel 80 | 1 | 1 | 1 | 0／0 | 1／0 |

flow の評価除外3件は、未対応の pipe、lazy の親、具体環境を作っていない lazy の別本体である。最初の二件は notClosedOrFuel、別本体は embeddedEnvironment として報告する。これらを VM との実行比較済みとは数えない。

初期 fuel は展開後の全元定義の `surfaceSize (bodyRoot body)` の総和の4倍に32を加える。base は132、flow は292で最初から深さ停止0だった。式を増やさない64個の builder 位置を持つ別の固定コーパスでは、初期値40で本体・発見に深さ停止が生じ、コーパス全件を80で再実行すると停止0・期待との一致になった。選んだ fuel は全本体と発見へ同じ明示値として渡す。Block の列と Exprs の列で小さい fuel が尽きる負例も確認した。深さ停止がなくなる一般の定理は追加していない。

正常入力は i64 両端・一点・加算・負号のあふれ・除数0・剰余0・return・短絡・分岐・長い discard の列・左からの trace・子の失敗による親の未到達・独立入力・lazy の別本体を含む。期待する消費は D16 の操作と保持の単位を手計算して固定した。解析器・評価器の出力を期待値へ写す生成・更新の処理はない。

負例では区間・候補・独立入力・別本体・実消費・次のキーを含む context・未知理由・評価値・trace の不一致を終了1とした。未知版・未接続 profile・深い余剰欄・重複欄・不正端点・欠落対応・不正な別本体期待を終了2とした。引数と入出力の失敗も2である。空コーパス、全Topだけの一致、深さ停止を残した比較を0にしない。mayFail だけの変更は不一致にしないことも確認した。

本体操作上限2で番号付けの unidentified、3で式の訪問の exceeded を区別した。拒否した操作は消費せず、次番号・保存した対応・本体件数・段停止を独立に確認した。全体操作上限0・1では本体を始めず、wholeBudgetSkipped と残る元入力を報告する。深さ停止した本体と同じ input にある浅い本体は比較対象に残る。

unknownFailure の負例では、空の腕列を持つ交換入力で評価器が failed unknown を返すことを確認し、実行比較から除外した。これは交換の除外の検査であり、その入力を通常 checker が受理するという主張ではない。引数付きの本体を空環境で実行しないことも確かめた。

## 中心二命題・参照定義・既存主定理・公理

[点検器](audit.py)が B_WORK の git blob と作業ツリーの内容を照合した。[検査前の詳細](audit-report-before.json)と[検査後の詳細](audit-report-after.json)は、既存の対象4,491ファイルのうち、交換・既存例・実行入口の3ファイルだけが変わり、残る4,488ファイルがバイト単位で一致することを確認する。既存 Lean の名前付き定理3,434件は言明・本文ともファイル全体として不変である。追加した交換と Main に theorem・独自公理・sorry はない。

| 言明・参照定義 | 差分とその意味の向き |
|---|---|
| NormalSoundness・WarningSoundness の本文・前提・結論 | Eval.lean 全体が一致。中心二命題の変更・弱化なし |
| EvalPartial・EvalBlock・EvalInput・Unmodeled・UnknownAt | 同上。未知を具体規則へ置き換える変更もなし |
| ConcreteValue・StandardRule・StandardBinding・EvalStandard・standardCallHead | 同上。値・標準規則・頭の認定・操作の扱いの変更なし |
| evalClosed とその既存の健全性定理 | EvalClosed.lean 全体が一致。実行の選択と導出の変更なし |
| targetOperationAt・arithmeticOperationAt・WarningLocated | Sound.lean 全体が一致。警告位置・対象演算の集合の拡大・縮小なし |
| concreteRule・syntacticReachChildren・CallReach | SyntacticReach.lean・CallReach.lean 全体が一致。到達可能性の意味の変更なし |
| AbstractSlot・AbstractEnv・SlotModels・LocalsModels・Models | Domain.lean・Environment.lean 全体が一致。Models の前提を強めていない |
| RangeState.Models と由来の表現 | RangeState.lean 全体が一致。成功値・保存関係の変更なし |
| BudgetAnalysis・BudgetWhole とその公開の入口・主定理 | 該当する既存 Lean 全体が一致。今回の変更は既存の実行結果を読む側に限る |
| 旧主定理・Builtins.Assumptions・公理 | 交換の二ファイルと例以外の既存 formal が一致。前提・結論・公理の変更なし |
| Rust・予算固定表・既存六入口・設定 | crates・fuzz・scripts・manifest・ツールチェーン指定・lakefile.toml が一致。`-M 12288` も保持 |

[作業末の入力の SHA-256](work-inputs-sha256.json)は、Lean・既存例・Main・Python 検査・設計書の6ファイルを固定した。指定 work の後はこれらを変えていない。点検の最初の記録名が外側の実行記録と重なったため、詳細の保存名を audit-report-before/after.json に分けた。記録名の訂正であり、実装・検査入力の変更ではない。

## 検査と計測

実行場所は `<repo>`、Lean の入口は `<repo>/formal`。固定された Lean 4.34.1・Rust 1.98.1 を使い、作業末の Cargo には既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。シェルでは rtk proxy を通した。[run.py](run.py)が各コマンド・開始時刻・終了状態・外側時間を同名の JSON と log に保存した。手元の絶対パスは伏せた。

| 検査 | 結果・時間 | 記録 |
|---|---|---|
| 交換の初回の単体検査 | 終了1、1.083秒。型と構文のエラーを検出 | [JSON](reader-first.json)・[出力](reader-first.log) |
| 交換の修正後の単体検査 | 終了0、1.045秒 | [JSON](reader-third.json) |
| 段停止などの報告を追加した後の最終の単体検査 | 終了0、1.061秒 | [JSON](reader-unproduced.json) |
| 最初の逐次ビルド | 257モジュール成功後、root の指定誤りで終了1。63.192秒 | [全体](sequential-build.json)・[モジュール別](module-build.json)・[出力](module-build.log) |
| root の指定を訂正したビルド | 終了0、0.757秒 | [JSON](root-build.json) |
| 最終の reader・Main・例・root・実行器の逐次ビルド | 各終了0。依存を一つずつ更新 | reader-unproduced-build、main-unproduced-build、examples-ready-build、root-ready-build、executable-unproduced-build の各 JSON・log |
| 既定ターゲットの更新済み確認 | 終了0、0.147秒。410 jobs、All targets up-to-date | [JSON](ready.json)・[出力](ready.log) |
| 局所の独立比較（最終） | 47起動の期待した結果を確認、終了0、0.931秒 | [JSON](tests-verified.json)・[要約](tests-verified.log)・上記 ZIP |
| 指定 work の dry-run | 終了0、0.012秒。指定の3単位と基準を確認 | [JSON](dry-run.json)・[出力](dry-run.log) |
| 指定 work の検査本体 | **終了0、3.368秒。3単位すべて成功** | [本体の結果](work-check.json)・[出力](work.log) |
| 外側の `/usr/bin/time -l` | **終了1、3.396秒。検査後の資源統計取得を拒否された** | [外側の結果](work.json)・[出力](work.log) |

指定のコマンドは次のとおりであり、先に同じ指定の `--dry-run` を実行した。[work-check.py](work-check.py)から一度だけ実行し、その外側を `/usr/bin/time -l` で包んだ。仕様集計の自己検査と集計、仕様例7件（失敗0・ignored 0、テスト本体2.96秒）、既定 lake build と sorry 拒否を通過した。初回リリース版の完了条件の未記入は none だった。

```sh
scripts/check.sh --level work --base 640538669de0da18d8d0947327ff9c84fef22b55 --only formal_build,spec_examples,spec_tally
```

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体が終了0となった後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1になった。real/user/sys は3.39/3.79/0.29秒である。検査の失敗やメモリ超過とは扱わず、最大常駐量を0とも記録していない。資源統計のための検査の再実行はしていない。

Lean のプロセスは一つずつとし、未ビルドの依存を Lake へ一括で渡していない。[build.py](build.py)で依存順に一モジュールずつ native object を作り、その後の変更も読者→Main→例→root→実行器の順で更新した。各プロセスの終了状態を確認してから次へ進み、ビルドを背景に残して編集していない。単体検査は `lake env lean -M 6144` と時間上限300秒、例のビルドは25秒、Sound は175秒の上限とした。ビルドの `-M 12288` は変えていない。時間・メモリ上限、終了143による停止はなかった。新しい解析器・評価器の実行は通常の計算として行い、証明の rfl・decide・simp で展開していない。

既存の lint 警告とリンク時の `/usr/local/lib` 不在の警告は再表示されたが、新しいコードの警告はない。

## 途中の失敗とテストの作成時の関門

- 初回の交換の単体検査は、引き継いだ `fromTy` へ Release の Eff を渡した型の取り違え、型の射影の推論、予約語の名前、match の字下げで失敗した。正しい交換の空効果列と型注釈・名前・字下げへ直し、既存の規則は変えていない。段停止の追記時の match の字下げの失敗も単体検査で直した。
- 最初の逐次ビルドは root の `Benitoite:o` を lean_lib の facet と解釈されて失敗した。`+Benitoite:o` としてモジュールを指定し、以後のビルドと既定の更新済み確認が成功した。
- 最初の Python 検査は、長い列の整数を捨てる入力を Unit が必要な seq で作っていたため、flow の評価で notClosedOrFuel となった。[初回の記録](tests-first.json)・[失敗の出力](tests-first.log)を残した。入力を discard に直し、手計算した区間・消費・trace の期待は変えずに成功した。これはテスト入力の誤りであり、評価器・評価関係・中心二命題を変更していない。

作成時の関門で守る契約は、交換の生入力・実行器の2モード・報告と終了状態、独立期待値との一致、fuel と本体別の除外である。区間・候補・trace・予算・停止原因の取り違え、深い欄の読み捨て、全Topや空の成功化、除外の比較件数への混入があれば失敗する。既存の読者の `#guard` だけでは、解析・評価を呼んだ結果、ファイルIOとCLIの終了状態まで検査できない。準備は一つの Python の表と共通関数へまとめ、本番へテスト専用の差し込み口・フラグ・公開範囲を足していない。既存のテスト・上限・ignore・期待値を緩めず、低価値テストの削除もしていない。基準との差分は Exchange が420行追加・9行削除、Main が22行追加・10行削除、既存例が2行追加・2行削除、新規 Python が448行である。

## 計画との差と引き渡し

対象の拡張、停止条件への該当、見込み上端の2倍による中断はない。言語規則・中心二命題・既存主定理・公理を変えなければ進めない点は見つからなかった。作業末の検査後に実装・設計書・テストを変えていない。別の状態の検査結果を引用して省いた検査はない。

| 残る手順 | 担当・受け渡す内容 | 見込み |
|---|---|---|
| L28 の独立レビュー・受け入れ、コミット・取り込み | 取りまとめ。本報告の比較対象・除外・fuel と参照定義の不変を確認する | 不明 |
| 全 profile、C5 の点検と受け入れ | L29。width/range/domain の読者・表・値と失敗・演算の表現を追加し、必須 profile と件数を固定する。現行の base/flow の独立期待を保つ | 計画による。今回の実測からは不明 |
| Rust の交換・全関係定義・解析・VM との比較、全比較の接続と受け入れ | X01〜X05。unknownFailure を実行比較から除き、親と独立入力の候補をともに読み、入力全体の after と段停止も照合する。操作とHTTPの欄を固定域へ戻さない | 計画による。今回の実測からは不明 |

Rust・予算の固定表・stage・short・change・release・`check-formal.sh` 全体と実 VM はこの枝で変更・実施していない。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめの担当である。

## 取りまとめのレビュー（2026-10-26）

受け入れる。変更は交換の読者・例・実行器と局所の検査（`formal/tests/test_interval_exchange.py`）と設計書の写しで、区間解析の定義・定理と中心二命題は変わらない。sorry・公理・`decide +kernel` の追加はない。最初の起動は Codex のモデルの混雑で途中で終わり、10 分あけた二回目で完了した。比較の受け入れの条件（空・全 Top・深さ停止を受け入れない、`unknown` の失敗を選んだ評価を理由付きで除く）は計画どおりである。L29 へ進む。
