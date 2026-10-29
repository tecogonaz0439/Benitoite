# V10.1ca: example のテストのビルドの修正

2026-10-30 JST。B_WORK と対象 HEAD は `7179a3026fcf2b463c1ec933aefd23256be6dc93`、ブランチは `m013/v10.1d` である。指定のテストの1行を修正し、局所の4検査の終了0を確認した。change 全体の再実行と判定は取りまとめへ戻す。

## 初回の change の失敗

取りまとめの実行は次のとおりである。本作業では再実行していない。

```sh
scripts/check.sh --level change --base 6124775788579e60530f55fb85570f26ef7fa900
```

終了1。`test_default_all` の `cargo test --workspace --all-targets` が example `wit_transfer_cost` のテストのビルドで E0308 となった。元の `target/v10.1c/change.log` は 6,611 bytes、SHA-256 は `6f7f4f27a8dffdcc7a3eb7bfde5a39c4ace6d1025440030c5a8df2371713028e` である。手元の絶対パスを `<wt>` に置換した [失敗ログ](change-failure.log) と、[元ログの同定](change-failure-source.json) を保存した。以下の行番号は元ログと保存ログで同じである。

- 53〜56行: `test_default_all` の開始と `error[E0308]: mismatched types`、`interpolation_formats.rs:109:17`。
- 61行: `benitoite::types::builtin::RangeIndex::TOP` の型が、example 内の `types::builtin::RangeIndex` と異なることを示す。
- 82〜84行: `could not compile ... (example "wit_transfer_cost" test)` と `FAILED: test_default_all`。

初回の change は外側88.08秒で停止した。先行する fmt・lint の成功を、change 全体の成功へ読み替えない。

## 原因と修正

`examples/wit_transfer_cost.rs` は `#[path = "../src/..."]` により `typeck` と `types` を自分のクレートへ読み込む。ところがテストの期待値だけがライブラリの `benitoite::types::builtin::RangeIndex` を参照していたため、example 内の `Ty::Con` が受け取る型と別の型になった。lib のテストでは `src/lib.rs` の `#[cfg(test)] extern crate self as benitoite` により同じクレートを指すので、この不整合が表面化しなかった。

`crates/benitoite/src/typeck/tests/interpolation_formats.rs` の109行だけを、`benitoite::types::builtin::RangeIndex::TOP` から `crate::types::builtin::RangeIndex::TOP` へ変更した。これにより、lib と example のどちらでも、そのクレート自身の `Ty::Con` と同じ `RangeIndex` を使う。[差分](source-diff.patch) と [状態・ハッシュ](source-state.json) を保存した。本番コードの変更は0行、テストは1行の置換（追加1・削除1）である。

これまでの work は `lib_default` の `--lib` と `tests_related` の `--test`、通常の example を対象にする `lint_default` を選び、example のテストをビルドする `test_default_all`（`cargo test --workspace --all-targets`）を選ばないため、この不整合が見つからなかった（`scripts/check.sh` の42〜44、434、540〜569行）。

作成時の関門は公開の test-audit に従った。既存テストが守る契約は、書式と型の受理表・診断位置・補間式の具体化済み型の保持である。その期待値を変更せず、実ソースを読み込む example でもビルドできるよう型の参照を直した。既存の example のテストのビルドが今回の不整合を捕まえているので、新しいテストや本番の差し込み口を追加しない。

## 局所の検査

既定の機能で、Rust/Cargo 1.98.1、macOS / arm64、既存の target を使った。正確なコマンド・開始日時・終了状態・外側秒は [local-checks.json](local-checks.json) に保存した。

| コマンド | Cargo 自身の終了 | 初回の外側秒 | 終了状態を再確認した外側秒 | 結果 |
|---|---:|---:|---:|---|
| `cargo test -p benitoite --example wit_transfer_cost --no-run` | 0 | 31.641 | 0.179 | テスト用実行ファイルのビルド成功（実行なし）。[終了状態を取得したログ](example-no-run-exit-confirmed.log) |
| `cargo test -p benitoite --lib typeck::tests::interpolation_formats` | 0 | 6.577 | 0.630 | 2成功・失敗0・無視0・1,412件フィルタ。[終了状態を取得したログ](lib-interpolation-formats-exit-confirmed.log) |
| `cargo clippy -p benitoite --all-targets` | 0 | 17.690 | 0.212 | 診断なし。[終了状態を取得したログ](clippy-all-targets-exit-confirmed.log) |
| `cargo fmt --check` | 0 | 2.704 | 2.663 | 書式差分なし。[終了状態を取得したログ](fmt-check-exit-confirmed.log) |

初回は共通依頼文に従い `/usr/bin/time -l` で包んだが、4件とも計時器が `time: sysctl kern.clockrate: Operation not permitted` で終了1となった。Cargo 自身の終了状態は別途取得していなかったため、初回の成功を示す出力だけで終了0と判定せず、計時器を外して4件の終了状態を再確認した。これは「各1回」の指定からのずれである。[初回の計時記録](timed-checks.json) と各ログを保持し、計時器の終了1と再確認した Cargo の終了0を分けた。最大常駐量は環境制限により未取得であり、0として扱わない。外側秒は Python の `time.monotonic()` で計測した。

## 全比較への影響と申し送り

変更箇所は `typeck/mod.rs` の `#[cfg(test)] mod tests` 配下の `tests/interpolation_formats.rs` にある期待値だけである。通常の lib・CLI をビルドする際には含まれず、全比較を行う統合テストが使う処理系の本体にも入らない。全比較の書き出し器・実ソース入力・独立期待値・標準ライブラリ・Lean・交換形式・比較台本・manifest は変更していない。したがって、今回の1行の修正は全比較の書き出しの入力や出力を変えず、影響段の再実行を要しないと判断する（Codex、2026-10-30 JST）。

[plan-v10 の F-Q と停止条件](../plan-v10.md#f-q-最終の関係状態への引用票)、[README の全比較・J1・J2 の決定](../README.md)、[K10.3 の判定と追補](../k10.3/results.md#07-03結果の保存と引用に従う全比較の判定)、[RV-K10.3](../reviews/RV-K10.3.md)、[07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用) を踏まえ、この差分と理由を取りまとめの F-Q の「以後の変更」へ加えるために渡す。今回の局所成功を、change 全体や最終の全比較の引用票の完了とはしない。

`lake build`、`scripts/check-formal.sh`、全比較の再書き出し・各比較段、change の再実行は行っていない。通常の work 全体も追加せず、今回の起動依頼で指定された局所検査に限った。ほかのソース・テスト・設計書・計画、未追跡の `v10.1d/` は変更していない。private/ と同所を指すスキル、docs/todo は読まず、Git の状態を変える操作も行っていない。

## 時間

開始は 2026-10-30 05:53:19 JST、記録作成時は 05:56:35 JST、外側の所要は約 3.3分（196.2秒）である。うち検査・計時器待ちは合計 62.296秒、残りは文書・差分の読解、修正、結果の保存である。見込み15〜30分と停止上限1時間の範囲内である。

## V10.1cb: 二回目の change の失敗と統合テストの期待値の修正

B_WORK・HEAD は `7179a3026fcf2b463c1ec933aefd23256be6dc93`、ブランチは `m013/v10.1d` である。[開始状態](v10.1cb-initial-state.json)に HEAD・ブランチ・index のハッシュと既存差分を記録した。V10.1ca の `interpolation_formats.rs` の修正、取りまとめの README の差分、未追跡のレビューと `v10.1d/` は今回の変更に含めない。`v10.1d/` の内容は読んでいない。

### 二回目の change と失敗の全収集

取りまとめの二回目の change は `scripts/check.sh --level change --base 6124775788579e60530f55fb85570f26ef7fa900` の `test_default_all` で停止した。[保存したログ](v10.1cb-change-2.log)の2040〜2070行は、`scope_annotations::effect_coverage_uses_one_same_named_atom` の753行で、補助位置の実際が `File.Read["/data/a"]`、期待が `caller` だったことを示す。`scope_annotations` は17成功・1失敗、change は終了1・外側369.17秒であり、後続のテストバイナリと heap・stress・doc・long_only 等は未到達である。先行の fmt・lint の成功を change 全体の成功としない。

[一回目と二回目の元ログの同定](v10.1cb-change-sources.json)に大きさと SHA-256 を保存した。一回目の原因と修正は上の V10.1ca の記録を保持する。

今回の修正前に `cargo test --workspace --all-targets --no-fail-fast` を一度実行した。[全出力](LARGE-FILES.md)・[対象別の集計と計時](v10.1cb-default-before.json)に、3,268成功・1失敗・既存の ignored 54件、外側522.79秒を保存した。失敗したターゲットで打ち切らず、後続の統合テストと example のテストまで実行して収集した。失敗の一覧は次の1件だけである。

| テスト | 失敗 | 原因と判断 |
|---|---|---|
| `scope_annotations::effect_coverage_uses_one_same_named_atom` | 補助位置に関数名 `caller` を期待したが、実際は `uses` の同名原子だった | R40.1 の意図した診断変更に対する期待値の追随漏れ。同じテストの古い理由別の案内・注記も追随する。本番コードの退行ではない |

初回の全収集は `/usr/bin/time -l` で包んだ。テスト完了後に `time: sysctl kern.clockrate: Operation not permitted` が出て、計時器の終了は1だった。Cargo 自身の終了コードを分離して取得していないため、計時器の1を Cargo の終了コードとはしない。Cargo の「1 target failed」と各ターゲットの成功・失敗、real 522.79秒は出力から確認できる。RSS は未取得であり0としない。以後は [記録器](v10.1cb-run.py)が Cargo を直接起動し、その returncode・外側秒・macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` を取得する。

### 原因を特定した履歴と決定の根拠

原因の変更は `40716323b01488d179d8568353034537f25869a5`（R40.1、`Explain scope diagnostics and their repairs`）である。[本番の変更の保存](v10.1cb-diagnostic-change.log)には、`typeck/solve.rs` が `.secondary(r.span, "declared")` から有効な効果宣言の同名原子の元位置を収集する形へ変わり、同じ位置を重複させないこと、理由別の案内と五つの欄を注記へ追加することが残る。`git log -L` と `git log -S 'declared_spans'` でこの変更を特定した。

[テストの履歴](v10.1cb-test-history.log)では、このテストは `f200ec42a91f65f39c0d341fbeec46563f308ba4`（R10.4）で加わり、`e7595984`（R10.8）で理由別の期待を補強した後、R40.1 の変更に追随していない。修正前の入力とアサーションは [元のテストファイル](v10.1cb-scope-before.rs.txt)に保存した。

実出力だけを根拠にせず、次の決定と記録を照合した。

| 根拠 | 今回の期待値との対応 |
|---|---|
| [README「設計者の決定（2026-10-27、L00 の骨格の一括の問い）」](../README.md)、[L00.08 問25 DET-05](../l00.08/questions.md#問-25-det-05-e0519e0520-の理由と補足の欄) | 問いの推す案を一括採択し、補助位置は必要な上限の注釈、補足は requiredUpperBound・knownUpperBound・uncoveredAtom・reason・source とする。英文は R40 のレビューで確定する |
| [R40.1「DET-05 の欄と位置」](../r40.1/results.md#det-05-の欄と位置) | 効果の被覆の補助位置は「実際の `uses` の該当原子。同じ略記位置は重ねない」。各補足欄の意味も固定する |
| [RV-R40.1](../reviews/RV-R40.1.md)の中3・軽1・軽4・軽6と「問題がなかった点」 | requiredUpperBound と knownUpperBound を文中でも区別し、契約を保つ案と広げる案を分け、補足の並びを reason からにそろえる。DET-05 の位置と欄を確認済みとする。取りまとめは各修正を採った |
| [R40.2](../r40.2/results.md)・[R40.3](../r40.3/results.md)、[RV-R40.2](../reviews/RV-R40.2.md)・[RV-R40](../reviews/RV-R40.md) | R40.1 の案内・四理由を引き継ぎ、当該位置を関数名へ戻す決定はない。RV-R40 の軽5は純粋な必須判定の別の表示上の候補である |
| [02-10「診断の内部の表現」](../../../design/02-impl/02-10-diagnostics.md#診断の内部の表現)の E0519（50〜70行） | 補助位置は必要な上限の注釈、上限表示は同名原子だけ、補足は reason・requiredUpperBound・knownUpperBound・uncoveredAtom・source の順とする。案内は契約を保つ変更と広げる変更に分ける |

[README の J1](../README.md)は RV-R40 軽5の文言を今回変えず docs/todo の TODO-315 へ送る判断である。今回、処理系の診断文言を新たに変更していない。R40.1 で既に採択・実装された観察可能な診断へ、取り残したテストの期待値を一致させた。

これまでの work は、`scripts/check.sh` の `tests_related` が `--test` で名指しした統合ターゲットだけを実行し、診断を変えた R40.1 の10対象、その後の R40.2/.3 と V10.3a の指定にも `scope_annotations` が含まれなかったため、この追随漏れを検出しなかった（[R40.1 の W-40D](../r40.1/results.md#探査生成物検査)、[R40.2 の W-40](../r40.2/results.md#検査と初回の失敗)、[V10 の W-V](../plan-v10.md#検査の割り当て)、`scripts/check.sh` の42〜44・567〜569行）。

### 修正と test-audit の作成時の関門

変更した処理系のファイルは `crates/benitoite/tests/scope_annotations.rs` だけである。既存の一つの表の入力・受理/拒否・理由の分類を保ち、補助位置、理由別の note/help、五つの補足欄の期待値を更新した。補助位置は数と元のバイト位置も検査し、略記の重複と無関係な `File.Write` の混入を捕まえる。表示上の上限は入力の独立した固定文字列で定め、処理系の出力や本番の整形関数から期待値を作っていない。テストは37行追加・8行削除、本番コードは追加0・削除0行である。

公開の test-audit の四つの関門は、次のとおり通した。

1. 守る契約は、通常の check 入口からの一原子の被覆判定と、拒否した理由・診断位置・修正案・補足欄である。
2. 関数名への位置の後戻り、同じ略記位置の重複、別名原子の混入、上限・流入原子の取り違えや補足欄の欠落を検出する。
3. 既存の表を修正し、新しいテストは足さない。代数の単体検査は通常ソースの制約選択を通らず、CLI の表は直列化の境界を受け持つ。今回の表の既存の受理・拒否の各条件を維持する。
4. 本物の pipeline の公開入口を使い、本番の差し込み口や公開範囲の追加を要しない。最初の全収集で修正前の失敗を確認し、修正後の同じテストバイナリは18件全て成功した。

### 修正後の検査と全比較への影響

局所の `cargo test -p benitoite --test scope_annotations` は Cargo の終了0、18成功・失敗0・ignored 0、外側4.219秒だった（[記録](v10.1cb-scope-annotations.json)・[ログ](v10.1cb-scope-annotations.log)）。続けて既定構成、heap 構成を直列に一度ずつ実行し、両構成とも全ターゲットの失敗0を確認した。Rust/Cargo 1.98.1、macOS / arm64、既存の target を使い、依存・固定版を変更していない。

| 検査 | 正確なコマンド | Cargo の終了 | 成功 | 失敗 | 既存 ignored | 外側秒 |
|---|---|---:|---:|---:|---:|---:|
| 修正前の全収集 | `cargo test --workspace --all-targets --no-fail-fast` | 未分離。計時器は1、Cargo は1ターゲットの失敗を表示 | 3,268 | 1 | 54 | 522.790 |
| 修正したバイナリ | `cargo test -p benitoite --test scope_annotations` | 0 | 18 | 0 | 0 | 4.219 |
| 修正後の既定構成 | `cargo test --workspace --all-targets --no-fail-fast` | 0 | 3,269 | 0 | 54 | 507.998 |
| heap 構成 | `cargo test --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify --no-fail-fast` | 0 | 3,283 | 0 | 54 | 763.905 |

全ターゲットの件数は Cargo のテスト関数の実行件数であり、example がソースを読み込んで実行する単体テストも含む。既定構成の前後54ターゲットを照合し、入力件数と ignored が同じで、該当ターゲットの17成功・1失敗だけが18成功・失敗0へ変わったことを確認した（[照合](v10.1cb-default-comparison.json)）。heap も54ターゲットで、構成に固有のテスト14件が増えた。測定・フィルタは各全収集とも0である。

既定の [実行記録](v10.1cb-default-after.json)・[件数](v10.1cb-default-after-counts.json)・[ログ](LARGE-FILES.md)、heap の [実行記録](v10.1cb-heap.json)・[件数](v10.1cb-heap-counts.json)・[ログ](LARGE-FILES.md)を保存した。省略しない元ログは `target/v10.1c/v10.1cb-{default-before,scope-annotations,default-after,heap}.log` に分け、同名の保存ログは手元の絶対パスを伏せた。元ログの大きさ・SHA-256 と保存ログの SHA-256 は各 JSON に残す。heap のビルドは Cargo 表示1分8秒であり、上の外側秒に含む。

`random_differential` は手動用の環境変数 `BENITOITE_RANDOM_PROGRAMS` と `BENITOITE_RANDOM_SEED` の指定なし、既定・heap とも300件・60秒の予算で成功した。`random_programs` 全体の所要は、修正前47.13秒、既定の修正後46.81秒、heap 47.28秒だった。他のビルド・検査と同時に走らせず、負荷超過の失敗はなかったため単独の再確認はしていない。件数・種・予算・ignore を変えていない。

| 検査 | 最大常駐量の原値（bytes） | MiB | GiB |
|---|---:|---:|---:|
| 修正したバイナリ | 610,156,544 | 581.890625 | 0.568253 |
| 修正後の既定構成 | 1,417,461,760 | 1,351.796875 | 1.320114 |
| heap 構成 | 5,003,902,976 | 4,772.093750 | 4.660248 |

RSS は macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` による補助値であり、子孫の最大値で、同時に常駐するプロセスの合計ではない。MiB は2^20 bytes、GiB は2^30 bytesで換算した。最初の全収集の RSS をこれらの値で補ってはいない。

初回の `cargo fmt --check` は今回追加した match の二つの腕の折り返しで終了1となった（[ログ](v10.1cb-fmt.log)）。rustfmt が示した配置へ該当テストだけを直し、その後の `cargo fmt --check`（[ログ](v10.1cb-fmt-final.log)）と `git diff --check` は終了0だった。全体の `cargo fmt` による書き換えは行っていない。[最終差分](v10.1cb-source-diff.patch)は全構成の検査中に変えていない。

今回の差分は独立した統合テストのアサーションだけであり、通常の lib・CLI の本体、全比較の書き出し器、実ソース・独立期待値、標準ライブラリ、Lean、交換形式・台本・manifest を変更しない。[plan-v10 の F-Q](../plan-v10.md#f-q-最終の関係状態への引用票)と [07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用)に従い、この差分は全比較の入力・出力へ影響せず、再実行を要しないと判断する（Codex、2026-10-30 JST）。最終の引用票への転記と change の残りは取りまとめの担当であり、本作業の局所成功で全体を完了としない。

`lake build`・`scripts/check-formal.sh` と各比較段は実行していない。stress・doc・long_only は取りまとめが change のやり直しで実行する。git の状態を変える操作、private/ と同所を指すスキル、docs/todo の読解も行っていない。

[最終状態](v10.1cb-final-state.json)は、HEAD・ブランチ・index の不変と、開始時からあった README・`interpolation_formats.rs` の内容の SHA-256 の一致を確認した。今回の追跡ファイルの変更は `scope_annotations.rs` だけであり、ほかは本ディレクトリの結果と `v10.1cb-` の補助記録である。未追跡の `v10.1d/` とレビューには触れていない。テストの差分の不変、補助 Python の構文、相対リンク・見出し、保存した記録に手元の絶対パスがないことも確認した。本番コードの退行で J3 により止めたものはない。

### V10.1cb の時間

最初の採時計は2026-10-30 06:04:33 JST、最終状態の確認は06:36:39 JSTであり、外側は約32分6秒である。検査は修正前522.790秒、局所4.219秒、修正後の既定507.998秒、heap 763.905秒であった。検査中に読解・記録も進めており、能動時間と待ちの厳密な分離計時はしていない。見込み0.5〜1.5時間と、3時間の停止条件の範囲内で完了した。設計者の回答待ちはない。最後の変更はこの記録の追記だけであり、検査対象のテストは最初の局所成功以後変えていない。

## 三回目の change（取りまとめ、2026-10-30）

V10.1ca と V10.1cb の修正の後、取りまとめが同じ作業ディレクトリ（ブランチ `m013/v10.1d`、HEAD `7179a3026fcf2b463c1ec933aefd23256be6dc93`。未コミットの差分は `crates/benitoite/src/typeck/tests/interpolation_formats.rs` の1行、`crates/benitoite/tests/scope_annotations.rs`、改造のディレクトリの README と記録だけ）で、change を最初から通しで走らせ直した。一回目と二回目の失敗の記録（[一回目のログ](v10.1cb-change-1.log)、[二回目のログ](v10.1cb-change-2.log)）は書き換えていない。

| 項目 | 値 |
|---|---|
| コマンド | `/usr/bin/time -l scripts/check.sh --level change --base 6124775788579e60530f55fb85570f26ef7fa900` |
| 開始・終了 | 2026-10-30 06:38:48 〜 07:45:22 JST |
| check.sh 自身の終了 | 0（`selected checks passed`） |
| 外側の時間 | real 3,994.08 秒（約67分）、user 11,510.01 秒、sys 193.85 秒 |
| 最大常駐量 | 5,726,470,144 bytes（5.33 GiB。`/usr/bin/time -l` が示す最も大きい子のプロセスの値） |
| 選んだ単位 | fmt、lint_default、lint_heap、test_default_all、test_heap_all、test_stress、doc_default、source_rules、skill_generated、spec_tally、python_syntax、migrate_selftests、licenses、policy_selftest、long_only、formal_build、advisories の17単位（dry-run の選択と同じ。spec_examples・reference_examples・skill_docs は test_default_all に含まれる） |
| 件数 | test_default_all 3,269 成功・失敗0・ignored 54、test_heap_all 3,283・0・54、test_stress 1,884・0・32、doc_default 34・0・1、long_only（heap と stress の ignored の一括）60・0 |
| formal_build | 既存の成果物で `lake build` を実行し、終了0・sorry なし（引用ではなく実行） |
| advisories | ワークスペースと fuzz とも `CHECKED: 0 advisories`（`ALL TARGETS CHECKED: 0 advisories`）、生の終了0 |
| 全ログ | 875,025 bytes（[LARGE-FILES.md](LARGE-FILES.md)） |

random_differential は三構成とも予算内で成功し、再確認はしていない。

続けて、計画の T-D と T-C を一度ずつ走らせた。

| 検査 | コマンド | 終了 | 件数 | real 秒 |
|---|---|---|---|---:|
| T-D（derive の自己検査） | `cargo build -p benitoite --bin benitoite --example derive_inventory && python3 -B tools/derive/test_derive.py` | 0 | 50 成功 | 89.69 |
| T-C（比較道具の自己検査） | `python3 -B -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0 | 39 成功 | 306.89 |

ログは [T-D](logs/t-d.log)・[T-C](logs/t-c.log)。

判断（取りまとめ、2026-10-30）: change は、一回目（example のテストのビルドの E0308）と二回目（統合テストの期待値の追随漏れ）の失敗を直した後の三回目で、全17単位が終了0となった。どちらの修正も `#[cfg(test)]` の中と統合テストだけで、本番のコードと全比較の入力を変えていない（V10.1ca・V10.1cb の節）。この状態を改造全体の回帰の成功とする。
