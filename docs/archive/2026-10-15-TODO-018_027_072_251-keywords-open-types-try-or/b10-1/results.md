# B10-1 実装結果

## 目的と変更

B9 の内部の報告値を、既定の Direct の終了と参照インタプリタの終了へ接続する。本番の parser に die を受理させる変更は行わない。

- `vm/dispatch.rs` は報告付きの呼び出しの標準 exit・引数の数・終了状態 1 を確かめる。`vm/dispatch/tasks/io.rs` は言語のハンドラを通過した呼び出しの保存レジスタから String を所有し、採用した状態 1 の終了だけへ原因・説明・位置を移す。ハンドラの節には公開の code だけを渡す。
- `refinterp/eval.rs` と `mod.rs` は App の情報をその呼び出しの中で扱い、ハンドラが処理した場合は捨て、既定の終了では `RefOutcome::Exited.die_failure` に保持する。通常の exit は None にする。
- `tests/golden/differential.rs` は原因・説明・位置を厳密に比較する。既存の refinterp の通常 exit の期待に None を加え、解放の検査でも None を確認する。
- `vm/exit_report_tests.rs` と `refinterp/exit_report_tests.rs` に、独立した bytecode とコア IR の実行の検査を加える。02-08・02-11 は接続した実行の範囲だけを反映する。

## test-audit の作成時の関門

1. 守る契約は、既定の呼び出しだけの報告の所有、説明の空と無しの区別、位置、公開の引数が code 一つであること、処理・再開・破棄・再入後の独立した終了への情報の非混入、未検証の報告の範囲・型・操作・code の拒否である。
2. 報告の読み捨て、原因と説明の取り違え、大域の一時欄への保存、捕まえた継続への情報の残留、検証器に頼って実行時の確認を省く退行を捕まえる。
3. 既存のソースは報告付き App を生成しない。B9 の IR/bytecode の検査は保持と生存が対象であり、実行・ハンドラ後の所有は観察しない。VM は手書きの bytecode、参照インタプリタは独立したコア入力を主な境界とし、ハンドラの契約は両実行器の本物の入口で同じ独立した期待結果に照らす。
4. 本番の公開の範囲・方式フラグ・テスト専用の差し込み口は加えない。再開だけは、型を消去した実行器の検査用に内部の節を直接構築する。通常のソースの `Process.exit` の節の T は剛体なので `resume(())` は E0401 になる。準備のコアは検査器を通した後でこの独立入力へ変え、ソースから受理可能な再開例とは扱わない。

テストは三件追加し、既存のテスト・assert・期待値の厳密さ・ignore を維持した。VM の不正な入力は、意図した処理系の不具合の文まで確認する。

## 診断の変更

言語仕様上の診断コード・主文・help・主副位置・終了状態に変更はない。B9 の未接続の内部入力の拒否を Direct と refinterp で除き、報告付き Request の拒否は外側の実行器へ渡す直前に限って残す。不正な内部入力のエラーは処理系の不具合として扱う。

## 検査

コマンドはリポジトリの根から rtk 経由で実行した。Rust の検査と重い形式化の検査は直列で実行した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 最終 1,175 件成功、既存の ignore 21 件、失敗 0。74.14 秒。追加した三件を含む |
| `cargo test -p benitoite --lib exit_report -- --nocapture` | 関係する既存三件と追加三件が成功。最終 lib 全体でも成功 |
| `cargo test -p benitoite --test runtime_builtins --test random_programs --test golden` | 最終 3 スイート・13 件成功。107.98 秒。既存の入力数と時間制限を維持 |
| `cargo clippy --workspace --all-targets` | 成功。警告・誤りなし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 成功。冒頭の `formal/` の `lake build` を含む。sorry の警告なし。六入口・独立入力・破損入力・manifest の照合がすべて成功 |

初回の内部入力の作成では Span の組み立てと組み込みの名前の指定に誤りがあり、実際の API・登録の表に合わせて修正した。ソースからの `resume(())` は上記の E0401 になったため、再開の検査を内部入力に直した。既存のテストの assert と期待値は変更していない。最初の lib 全体の検査後の差分確認で、短い報告表の拒否を加え、その入力を追加した。上表の最終の lib・関連統合テスト・clippy はこの処理を含む。

Rust の本番部分は 160 行追加・10 行削除（差し引き 150 行増）、テスト部分は 305 行追加・削除なしである。削除行は既存の暫定拒否と状態の構築・分岐の書き換えであり、既存の assert の削除はない。構文の章・標準ライブラリ・診断の表・仕様の例・リファレンス・Skill の例は変更していないため、gen_skill と各例の個別検査は追加していない。

形式化の出力は `target/desugar-diff/run-60904/` と `target/coverage-diff/run-60904/` にある。Rust の全コーパスの書き出しは 563.88 秒、最後の個別照合と破損入力の検査は 203 秒であった。

| 形式化の入口・入力 | 件数と結果 |
|---|---|
| `coverageDiff` | 通常 10,020 件・view 付き 10,028 件がすべて一致。不一致・fuelExhausted 0 |
| `desugarDiff` | 1,736 入力のうち golden 349 件・random 1,000 件が対象。既存の check error の除外は golden 387 件。範囲外・不一致 0。定義は golden 968 件・random 72,778 件が一致 |
| `builtinCheck` | 対象 1,349 入力。summary の比較 72,468 件、不一致・非収束 0。既存の不透明型の引数と State の仮定は維持 |
| `coverageProgramDiff` | match 16,417 件・bind 6,036 件、計 22,453 件一致。不一致・対象外・fuelExhausted 0 |
| `surfaceCheckAll` | 51,645 件一致、不一致・準備失敗・lazyRestriction 0。既存の対象外 19 件・q11 1 件を維持し、manifest と一致 |
| `surfaceCheck` と最終の照合 | 1,736 入力の対応する表・定義・実装と、その全結果を個別確認し、識別名・対象外理由・scope・coverage がすべて一致。73,746 定義・22,453 coverage entries を維持 |
| 独立した交換形式・破損入力 | width 4 件・named 12 件・extensible 22 件・try 8 件が成功。契約の破損 3 件、hole/pipe の破損 6 件、名前付きの破損 6 件も意図した理由で拒否 |

通常の corpus 9・型表 3・網羅性 3 と、独立した corpus 10 の try の正負の検査を維持した。件数・対象外理由の下方修正、Lean の定義・証明・axiom・sorry/admit/native_decide の変更はない。今回の検査を、本番ソースの die の受理・書き出しの検査とは扱わない。

## 計画の具体化と申し送り

Direct も要求キューを通る実態に合わせた所有の時点と Request の暫定拒否を、decisions.md の R58 に推す案として記した。型の変更は、計画の表と R20 が認める RefOutcome::Exited の任意欄だけである。

B10-2 は RequestId ごとの所有・完了・取消しと停止への採用を接続し、ReturnToExecutor の暫定拒否を除く。B10-1 の Direct の情報は serve_inner の呼び出し内のローカルな所有であり、Request.die_failure はまだ使用しない。B10a は報告付き App の生成、B11/B12 は本番ソースからの一貫した実行と終了・解放・flush・test runner の検査を担当する。今回の内部入力の検査をそれらの代わりに数えない。

コミット、docs/todo の変更、scripts/check.sh（dry-run を含む）、gc-stress の構成の検査は、依頼に従って行っていない。共通の検査と G5a の所定レビューはオーケストレータへ引き継ぐ。
