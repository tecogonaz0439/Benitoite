# C1b main の完全な初回の報告への接続

## 目的と変更ファイル

`check --report=json` を、一回の検査から契約・ソース・診断を返す経路へ接続した。通常の `run` と、報告を指定しない `check` の出力と終了状態は保つ。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/inspection.rs` | main の宣言と型表の照合、原子的エフェクトの正規名、全参照の表による shell の判定 |
| `crates/benitoite/src/cli/check_report.rs` | 元のバイト列のハッシュ、既存 renderer による診断と位置、成功・検査失敗・抽出失敗の単一報告 |
| `crates/benitoite/src/cli/mod.rs` | 公開の `ReportFormat` と `Options.report`、引数の解析、報告の分岐、段の中での抽出 |
| `crates/benitoite/src/cli/build_info.rs` | 版問い合わせと同じビルド情報を使う producer |
| `crates/benitoite/tests/cli_process.rs` | CLI 境界で報告全体と通常の check を対照する受け入れ表 |
| `docs/design/06-tooling/06-01-cli.md` | 実装済みの報告の形式・出力先・終了状態 |
| `docs/design/02-impl/02-01-pipeline.md` | 一回の検査からの抽出と所有・破棄 |
| `docs/design/02-impl/02-02-source-and-spans.md` | ソースの識別・全バイトのハッシュ・報告の位置 |
| 本書 | 共通の関門 K、検査結果、後続作業への受け渡し |

## 型・契約と所有

公開の `Options` に `report: Option<ReportFormat>` を加え、既定は None、形式は Json だけとした。既存の `parse_args` の公開シグネチャは変えていない。`--report=json` は check のスクリプトより前だけで受け付け、明示した diagnostics=text との併用を拒む。未使用の binding・tests・inspect_tests・ShellReference::Unknown は加えていない。formats の表も変更していない。

非公開の準備処理は報告を指定したときだけ、`CheckedProgram` が存在する間に `types.main`・`resolved.decls`・`Scheme.effects` から main の契約を取り出す。標準の IO.Process の未読なら shell は absent とし、既読で shell の束縛がなければ内部エラーとする。参照は `resolved.refs` の全件の値を比較し、式の AST を再走査しない。宣言と型表の欠落・未確定のエフェクトも内部エラーにする。

AST と型表は、従来と同じ段のスレッド内で破棄する。外へ返す検査結果の program は None のままであり、抽出した所有データだけを追加した。ソース表は同じ Arc を使い、診断と位置は既存の renderer から JSON 値にする。ハッシュはソース表の全バイト列から求める。読み込み・検査・標準ソースの追加 import は繰り返さない。

成功の純粋な main は expanded が空配列となる。検査失敗は main と aggregateEffects を null にし、読み込めたソースと診断を残す。契約の抽出の失敗と標準ソースの誤りは internalError とする。完成した報告をメモリ上で組み立て、一回の出力処理へ渡す。

## test-audit の作成時の関門

- 守る契約は、報告全体の必須欄・null・終了状態、宣言したエフェクトの正規名と順序、標準 shell の参照、元のソースのハッシュ、既存の診断との一致、非実行である。
- 現実的な退行は、不明を純粋な集合に補うこと、State を落とすこと、到達しない shell の参照を落とすこと、索引を作るために標準モジュールを追加で読むこと、BOM・改行・不正 UTF-8 を変換してからハッシュすること、報告に利用者の出力や診断の再送を混ぜることである。
- 既存の check のテストは成功時に契約やソースを返さないため、これらを捕まえられない。同じ CLI 境界の一つの受け入れ表で、純粋・複数エフェクト・import だけ・到達しない関数内の shell・E0414・構文・不正 UTF-8・読み取り失敗を対照した。既定の診断形式と diagnostics=json の併記をともに使う。報告を指定しない check と診断の JSON を厳密に比較し、読み込んだ全ソースのハッシュを元のファイルから独立に求める。
- テスト専用の本番 API・フラグ・大域の状態は追加していない。実ファイルと実プロセスを使う。既存の assert・期待値・ignore は変更していない。

本番コードは394行追加・4行削除（差し引き390行増）、テストは154行追加・削除なしである。削除したテストはない。

## 検査

実行には `rtk` を使った。依頼に従い `scripts/check.sh` は dry-run も含めて実行していない。分類処理を読み、Rust の変更は `crates/*` により rust、変更した設計書と作業記録は追加の検査なしに分類されることを確認した。gc-stress と check.sh の最終検査はオーケストレータへ渡す。

| コマンド・確認 | 最終結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定、79.95秒） |
| `cargo test -p benitoite --test cli_process --test interrupt_process` | 20 passed、0 failed（2 suites、16.28秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |
| 変更した現行設計書内のローカルリンク | 139件の参照先が存在 |

受け入れ表を作成した初回は shell の例の戻り値型・uses が現行宣言に合わず失敗したため、`Result[Process.Output, IOError] uses Process.Run` へ修正した。Clippy が指摘した表の型の複雑さは型別名に整理した。いずれも最終の検査で解消し、期待値を緩める変更はしていない。最終の整形・差分検査は、作業記録の追記後にも実施した。

## 計画との差と申し送り

実装範囲と公開契約に計画からの変更はなく、新しい R の判断は不要であった。構文・型の規則・脱糖・formal/ は変えていない。R4 の判定を保ち、07-04 は更新していない。診断表・標準ソース・生成元は変更していないため、gen_skill は不要である。harness-response.md の合意済みの契約も変えていない。docs/todo には触れず、コミットしていない。

C2a は使い方の誤りの報告化と引数順によらない認識、C2b は報告が確定した後の panic 境界と書き込み失敗の検証を担当する。現時点では引数・入口の選択の誤りと準備の panic は既存の標準エラー出力の経路を使う。これらを完成した報告として実装済みとは扱わない。C3 は IO.All・die・別名・依存と設定ファイルなどの広い受け入れ表、および formats.checkReport=[1] の宣言を担当する。

T2b で必要になる binding・tests・inspect_tests・Unknown は、読む本番処理と同時に追加する。G2 のレビューと段末の検査、gc-stress、scripts/check.sh はオーケストレータの作業として残る。
