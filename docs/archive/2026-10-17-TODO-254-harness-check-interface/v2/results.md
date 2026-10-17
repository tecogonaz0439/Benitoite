# V2 version JSON と提供済み形式の表

## 目的と変更ファイル

既存の版表示を保ち、ビルド時の自己申告と提供済みの形式を `--version=json` で問い合わせられるようにした。開始時は `mod254/V2`、HEAD は `4a44d144291dfc5494a5fa207842f9f2598f6d3d` で、作業ツリーに変更はなかった。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/mod.rs` | VersionJson の解析・実行、使い方の表示、提供済みの三形式の表 |
| `crates/benitoite/src/cli/build_info.rs` | 五つの埋め込み値を実際の JSON の build 欄へ変換 |
| `crates/benitoite/tests/cli_process.rs` | 既存の CLI 契約テストへ版問い合わせの受け入れ例を追加 |
| `docs/design/06-tooling/06-01-cli.md` | 受理条件、JSON の欄・形式の版、出力先と終了状態 |
| `docs/design/05-platform/05-01-distribution.md` | 明示入力、採取元、dirty の notCollected、再採取条件と検知の限界 |
| 本書 | 共通の関門 K、検査と後続作業への受け渡し |

## 型・契約

公開の `cli::Command` に `VersionJson` を加えた。`Version` と `parse_args`・`execute` のシグネチャを保った。build_info は非公開の子モジュールであり、JSON 値の変換だけを親から使う。producer や後続の報告の型は先置きしていない。

`--version=json` は最初の引数にだけ受理し、余分な引数は既存の EXTRA_ARGUMENT、未知・空の値は BAD_VALUE を用いて、既存の文章と終了状態2で拒否する。成功時は標準出力へ単一の UTF-8 JSON と LF、書き込み失敗は状態1となる。従来の `--version` の二行と後続引数を無視する扱いを保った。

build の commit・dirty・target・provenance は `env!` で埋め込み値だけを参照する。実行時の環境・Git を読まない。formats は version/diagnostics/testResults の `[1]` だけであり、未提供のキーや loaderEnvironment のポリシーを出さない。既存の診断とテスト結果の行は変更していない。形式1は 0.0.6 の die・code:null・failure.die を含むことを現行文書に明記した。

## test-audit の作成時の関門

- 守る観測可能な契約は、版問い合わせの JSON 全体・UTF-8 と末尾 LF・標準エラーが空であること、受理位置・値・単独指定、旧版表示と引数の扱い、出力失敗の状態1である。
- 現実的な退行は、JSON と文章の混在、未提供の能力の宣言、不明値の false への変換、埋め込み値と実行時の環境の混同、新しい問い合わせによる既存の引数処理の変更である。
- 既存の CLI テストには機械向けの版問い合わせがなく、build_info の実ビルドの表は埋め込み値の採取を検査しても CLI の解析・JSON・出力失敗には届かない。そのため既存の cli_process_contracts と使い方の表に追加し、同じ契約の単体テストは加えていない。JSON 全体を比較し、既存の assert・期待値・ignore 指定は維持した。
- 本番の差し込み口や公開範囲をテストのために増やしていない。実プロセスと子だけの環境、閉じた UnixStream の出力先を使う。Git の採取・監視は V1 の既存の独立した実ビルドの表に委ねる。

## 検査

依頼の指定に従い、`scripts/check.sh` は dry-run を含めて実行していない。classify を読み、変更した Rust ファイルは `crates/*` により rust、文書は追加の検査なしに分類されることを確認した。gc-stress と段末の `check.sh --only rust,default_lib,skill` はオーケストレータへ渡す。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test cli_process cli_process_contracts` | 実装前は新しい値エラーの期待と既存の unknown option が食い違って失敗。実装後は1 passed、0 failed |
| `cargo test -p benitoite --test cli_process --test test_command` | 28 passed、0 failed（7.49秒）。既存の診断と test/testSummary・die の契約を含む |
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定）、79.22秒 |
| `cargo test -p benitoite --test build_info -- --include-ignored` | 1 passed、0 failed、24.83秒。V1 の全受け入れ表を実ビルドで確認 |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |
| 変更した現行設計書内のローカルリンク | 50件の参照先が存在することを確認 |

## 計画との差と申し送り

実装の範囲と公開契約に計画からの変更はなく、新しい R の判断は不要であった。処理系の版は現在の Cargo の値である 0.0.6 を返す。0.0.7 への更新は計画の M1 に残す。harness-response.md の最終契約は変更していない。

構文・型・脱糖、formal/、診断表・生成元・生成物、docs/todo は変更していない。コミットは行っていない。本番コードは56行増、テストは93行増で、削除したテストとそのための本番コードの整理はない。

G1 の照合資料は P1/P2/V1a/V1b の記録と本書、design.md の段1、decisions.md の Q7〜Q9・R2 である。G1 のレビューと段末の検査は未完了であり、本作業の通常構成の成功で代用しない。後続の機能が完了するたびに、その形式のキーを実際の出力へ追加する。
