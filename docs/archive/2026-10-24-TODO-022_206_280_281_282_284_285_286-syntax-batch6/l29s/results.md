# L29S の実装結果

着手（最初の時刻取得）: **2026-10-26 19:35:26 JST**。終了: **2026-10-26 19:45:21 JST**。所要時間: **9分55秒**。時刻取得前の指示の読み込みは計測に含めていない。

**状態: 実行開始モジュールの空名の受理、正負例、X01a の再現入力と名前付き対照、局所検査、指定 work、定義・言明・仮定の差分確認を完了した。独立レビューと受け入れは取りまとめへ引き渡す。**

B_WORK と HEAD はともに `587f44aaf272db8af4962290cdee82ed008e66a3`、ブランチは `mod012/L29S`。着手時に差分はなかった。共通依頼文、plan の前提・契約表の識別と独立交換・X01a の停止を受けた変更表・L29 の検査指定、D15 の追記と D17、X01a・L27a〜L29R の結果、現行の実装と対応する設計書を確認した。private/ とそこを指すリンクは読まず、git の変更操作と担当の委任を行っていない。

## 変更した範囲

| 対象 | 変更 |
|---|---|
| [Exchange.lean](../../../../formal/Benitoite/Interval/Exchange.lean) | `readInput` がモジュールの位置を渡し、`readModule` は先頭だけ空名を認める。後続の空名と `%` を含むモジュール名は拒否する。モジュール・定義の重複検査、定義名とモジュールの整合、型キーと元演算キーの検査は既存の処理をそのまま使う |
| [ExchangeExamples.lean](../../../../formal/Benitoite/Interval/ExchangeExamples.lean) | 生の読者を通す8組の `#guard` を追加した。空名の入口で通常定義・全型キー・元演算キーを保つこと、メソッドの受理、宣言名の欠落・異なる所有元の拒否、後続の空名・空名の重複・名前付きの重複を検査する |
| [test_interval_exchange.py](../../../../formal/tests/test_interval_exchange.py) | 既存の Runner と point の独立期待値を再利用し、10回の実CLI検査を追加した。空名と名前付きの正常な解析、入口のメソッド、後続の名前付きモジュール、位置・重複・宣言名・古い型キーの拒否を照合する |
| [01-12](../../../design/01-spec/01-12-core-calculus.md#区間解析の独立交換の読者)・[07-04](../../../design/07-quality/07-04-formal-semantics.md#区間解析の独立交換の読者) | 空名を認める位置、通常定義・メソッドの元キー、従来の重複・対応検査の維持、Identity との対応を写した。見出し・構文例・中心命題の写しは変えていない |

交換形式には入口を別に指す欄がないため、`modules` の先頭を実行開始モジュールの位置とする。Rust の `modules/load.rs` は、最初の Pending を空の `ModulePath` と Entry で作ってから標準モジュール等を追加する。名前付きモジュールだけの既存の独立入力も受理する。空名を先頭以外へ移した入力は受理しない。形式の版や新しい欄は増やしていない。

`readDefinition` の既存の結合規則により、空名の通常定義は `.point`、メソッドは `%impl:2:1:point` を保つ。`Identity.QualifiedDefinition` の条件は空でなく、`.` を含み、`%` を含まないことであり、`.point` はこれを満たす。メソッドの `%impl` は従来どおり交換の専用検査で扱う。Identity の定義・走査・番号・別本体名は変更していない。実ソースの名前解決の正しさを読者が証明するという主張も加えていない。

## 修正前後の再現と局所検査

X01a が保存した [entry-final-input.json](../x01a/entry-final-input.json) と [named-final-input.json](../x01a/named-final-input.json) を変更せず使用した。区間・消費・context の期待は保存された独立期待値のままである。[再現の要約](reproduction-summary.json)に終了状態・一致・受け入れを保存した。

| 入力 | 修正前 | 修正後 |
|---|---|---|
| 空モジュール名、定義 `.point` | 終了2、invalid module name。[記録](entry-before.json)・[報告](entry-before-report.json) | **終了0、matched=true、accepted=true**。[記録](entry-after.json)・[報告](entry-after-report.json) |
| 名前付き対照 `M.point` | 終了0、matched=true、accepted=true。[記録](named-before.json)・[報告](named-before-report.json) | **終了0、matched=true、accepted=true**。[記録](named-after.json)・[報告](named-after-report.json) |

修正前の再現入力と対照は各0.020秒・0.021秒、修正後は各0.020秒・0.018秒だった。名前を書き換えて拒否を回避する処理は追加していない。

局所検査は `python3 -B formal/tests/test_interval_exchange.py --output <本ディレクトリ>/test-records` を実行し、**144回の実CLI起動、終了0、4.439秒**となった。[実行記録](local-tests.json)・[出力](local-tests.log)。追加した正常入力は matched・accepted の両方を要求し、不正入力は終了2と意図した拒否理由を要求する。名前付きモジュールを入口の後へ追加した場合、親本体の after/context は後続モジュールの処理前の値なので、既存の期待値を変更していない。

主となる五profileの固定コーパスは従来どおり、解析174本体・閉じた評価器109本体を比較し、評価65本体を理由付きで除外する。[profile-manifest.json](profile-manifest.json)・[fuel-selection.json](fuel-selection.json)に件数と選択を残した。深さ停止の再選択を含む既存検査は保ち、固定表・期待値・燃料の規則を緩めていない。Rust の解析や実 VM との全比較は本作業では行っていない。

局所検査の全545項目を [test-records.zip](test-records.zip) と [各項目の SHA-256・リンク先](test-records-index.json)に保存した。入出力の同一性を調べる既存検査の相対シンボリックリンク1件も、リンクの情報として保存した。ZIPの全内容・ハッシュを照合してから、本作業が作った展開済みの検査出力だけを削除した。既存の検査記録とビルド生成物は削除していない。

テストの作成時の関門では、独立交換の読者と実CLIを持ち主の境界とした。守る契約は「空名の入口で元のキーを保ち、他の空名・重複・対応不整合を拒否する」ことである。現実的な退行は空名の再拒否、位置の制約の脱落、名前の補正による対応のずれであり、従来の名前付き入力だけでは検出できない。既存の準備・期待・Runner を使い、本番の公開範囲・フラグ・テスト専用の差し込み口は増やしていない。読者例は既定ビルドでの復号、実CLI検査は解析と報告・終了状態の接続をそれぞれ確認する。修正前の再現が意図した読者の拒否で失敗したことも上表に残した。削除したテストはない。読者は7行追加・3行削除、Lean の例は23行追加、Python の局所検査は38行追加である。

## 検査・時間・メモリ

実行場所は `<repo>`、Lean の実行は `<repo>/formal`。各コマンドの終了状態と外側時間は [run.py](run.py) が同名の JSON・ログへ保存した。試しの単体検査は `lake env lean -M 6144`、ビルドは既存の `moreLeanArgs = ["-M", "12288"]` を保持した。

| 検査・コマンド | 終了・時間 | 記録 |
|---|---|---|
| `lake env lean -M 6144 Benitoite/Interval/Exchange.lean` | 0、7.935秒 | [reader-first.json](reader-first.json) |
| `lake build Benitoite.Interval.Exchange` | 0、1.605秒 | [reader-build.json](reader-build.json) |
| `lake env lean -M 6144 Benitoite/Interval/ExchangeExamples.lean` | 0、1.012秒 | [examples-first.json](examples-first.json) |
| 依存順のモジュール単位の native object ビルド | 0、44.263秒。258モジュール | [build.py](build.py)・[sequential-build.json](sequential-build.json)・[モジュール別記録](module-build.json)・[ログ](module-build.log) |
| `lake build intervalDiff` | 0、1.293秒 | [executable-build.json](executable-build.json) |
| `lake --no-build build` | 0、0.148秒。All targets up-to-date（410 jobs） | [ready.json](ready.json)・[ログ](ready.log) |
| 指定 work と同じ dry-run | 0、0.010秒。指定の三単位だけを選択 | [dry-run.json](dry-run.json)・[ログ](dry-run.log) |
| 指定 work の検査本体 | **0、92.549秒。三単位すべて成功** | [work-check.json](work-check.json)・[work.log](work.log) |
| 外側の `/usr/bin/time -l` | **1、92.582秒。資源統計の取得拒否** | [work.json](work.json)・[work.log](work.log) |

作業末の指定は次のとおりである。先に同じ指定へ `--dry-run` を付けた。[work-check.py](work-check.py) が本体の終了状態を保存し、その外側を `/usr/bin/time -l` で包んだ。

```sh
scripts/check.sh --level work --base 587f44aaf272db8af4962290cdee82ed008e66a3 --only formal_build,spec_examples,spec_tally
```

仕様集計の自己検査・集計が成功し、初回リリース版の完了条件の未記入は none だった。仕様例は **7件成功・失敗0件・ignored 0件**、テスト本体3.24秒。formal_build は既定 `lake build` と sorry 拒否を通過した。各単位は work から一度だけ実行し、計測のための再実行はしていない。

**最大常駐量（maximum resident set size）は取得不能**である。検査本体の成功後、time が `sysctl kern.clockrate: Operation not permitted` を報告した。real/user/sys は92.57/473.18/70.98秒。未取得を0とは記録しない。プロセス一覧の照会もサンドボックスに拒否された。逐次の待機と各子プロセスの終了状態を確認して進め、Lean のビルドを背景に残して別作業をしていない。

既定ビルドの前に依存を一モジュールずつ更新し、更新済みの全ターゲットを確認したため、既定のビルドで複数の Lean を起動する必要はなかった。例の単体検査は約1秒、逐次ビルドの最長モジュールは Exchange の2.518秒だった。上限時間・メモリ上限・終了143による停止はなく、解析器・評価器を kernel の `decide`・`rfl`・`simp` 等で具体実行する例は加えていない。

## 中心二命題・参照定義・主定理・公理の差分

[audit.py](audit.py) は B_WORK の blob と作業ツリーを照合する。[検査前](audit-report-before.json)・[検査後](audit-report-after.json)で、formal・crates・fuzz・scripts・manifest・固定版指定等の既存4,492ファイル中、変更があるのは読者・読者例・局所検査の3ファイルだけ、残る4,489ファイルはバイト単位で一致した。既存 Lean の名前付き定理3,434件を含むファイル全体を比較し、言明の文字列だけの照合にはしていない。変更した Lean ファイルに定理・公理・sorry はない。

| 言明または参照定義 | 差分とその意味の向き |
|---|---|
| `NormalSoundness`・`WarningSoundness` の本文・前提・結論 | `Eval.lean` 全体が一致。変更・弱化なし |
| `EvalPartial`・`EvalBlock`・`EvalInput`・`Unmodeled`・`UnknownAt` | 同上。未知を具体規則へ置き換える変更なし |
| `ConcreteValue`・`StandardRule`・`StandardBinding`・`EvalStandard`・`standardCallHead` | 同上。具体値・評価規則・頭の認定・操作の扱いの変更なし |
| `evalClosed` とその健全性定理 | `EvalClosed.lean` 全体が一致。具体実行・unknown の選択・trace の変更なし |
| `targetOperationAt`・`arithmeticOperationAt`・`WarningLocated` | `Sound.lean` 全体が一致。対象演算・警告位置の集合の拡大・縮小なし |
| `concreteRule`・`syntacticReachChildren`・CallReach の定義と定理 | `SyntacticReach.lean`・`CallReach.lean` 全体が一致。構文的な到達可能性と未認定 call の除外の変更なし |
| `AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models` | `Domain.lean`・`Environment.lean` 全体が一致。Models を強めていない |
| `RangeState.Models` と由来の表現 | `RangeState.lean` 全体が一致。保存関係・同じ成功値の条件の変更なし |
| 解析・予算・全体駆動・識別と公開入口の主定理 | Analyze・BudgetAnalyze・BudgetSound・BudgetNormal・BudgetWhole・BudgetRange・BudgetDomainScan・BudgetSelect・Identity 等の既存 Lean ファイル全体が一致。解析・計上・停止・番号の変更なし |
| 旧主定理・`Builtins.Assumptions`・公理 | 交換と例以外の既存 Lean 全体が一致。既存の言明・本文・仮定の変更なし。新しい公理なし |
| 交換の読者 | 空名の先頭モジュールを新たに受理する。後続の空名・重複・対応の拒否を保つ。解析と評価関係は参照方向の先にあり、それらが交換の読者を参照する変更はない |
| Rust・VM・予算固定表・既存六入口・lakefile | 全体が一致。`crates/benitoite/testdata/interval-budget/` と `-M 12288` を変更していない |
| 01-12・07-04 | 交換の読者の写しと説明だけを追加。中心二命題・主定理・評価規則の写しの変更なし |

[work-inputs-sha256.json](work-inputs-sha256.json) に変更箇所と関連入力のハッシュを保存し、検査の前後で一致した。`git diff --check` も成功した。新しい言語規則・中心二命題・公開の主定理の意味・公理に関する未決の判断はない。

## 計画との差と申し送り

対象範囲の拡大・停止条件への該当・時間上限による中断はない。検査・Lean のコンパイル失敗はなかった。記録をZIPへまとめる最初の処理は、既存の同一パス検査が作った相対リンクを通常ファイルと同じ条件で扱って AssertionError となった。[bundle.py](bundle.py) でリンクを独立した情報として保存・照合する形へ直した。検査対象や期待値を変更せず、検査を再実行していない。ログ・保存スクリプトには手元の絶対パスを残していない。

stage・change・release・check-formal.sh 全体は本枝の割り当てでは実行していない。Rust の独立交換の本接続と実 VM との比較を本枝の成果に含めない。コミット・取り込み・docs/todo の更新・公開は行っていない。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| L29S の独立レビュー・受け入れ・コミット・取り込み | 取りまとめ。空名を認める位置、元キーの保持、定義・言明・仮定の不変、検査の結果を確認する | 不明 |
| X01a の再開、実装・検査・独立レビュー・受け入れ | X01a 担当と取りまとめ。本枝の受け入れ後、空名の入口と `.point` を保って Rust の書き出しを接続する。X01a の未完成パッチをそのまま受け入れ済みとして扱わない | 元の計画は1〜2時間。レビューの時間は不明 |
| X01b 以降の交換・実ソース・VM の比較と全比較、レビュー・受け入れ | 各担当と取りまとめ。計画の割り当てに従う | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。空のモジュール名は `modules` の先頭の実行開始のモジュールだけに受け付け、後続の空の名前・重複・キーの不整合は拒否する。x01a の再現入力は終了0・matched・accepted になった。区間解析の定義・定理は変わらず、sorry・公理・`decide +kernel` の追加はない。X01a を再開する。
