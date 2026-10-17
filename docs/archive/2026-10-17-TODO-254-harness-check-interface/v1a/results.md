# V1a ビルド時の入力と commit の採取

## 目的と変更ファイル

明示入力を検証し、Git から採取した commit と独立した dirty の由来を Cargo の埋め込み変数へ渡す。開始時は `mod254/V1a`、HEAD は `3156baf9d9dc7d36e10729a3b455400d945b562d`、追跡対象と未追跡の変更はなかった。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/build.rs` | 標準ライブラリだけで入力の検証、根の検証、Git の採取、存在する管理ファイルだけの監視、五つの埋め込み変数の出力を実装 |
| `crates/benitoite/tests/build_info.rs` | 本番 build.rs をコピーした小さな一時ワークスペースで、明示値と通常の Git 採取の受け入れ表を実ビルド |
| 本書 | 契約・検査・後続作業への申し送りを記録 |

Rust の本番コードは167行、テストは393行を追加した。既存のテストと assert・期待値・ignore は変更していない。新規の実ビルドのテストだけに、R10 に従う `long:` の ignore を付けた。

## 型と契約

公開の Rust の型・シグネチャ、CLI の出力、言語の規則は変えていない。実行時のモジュール・定数・宣言は追加していない。05-01 の実行時の説明は計画どおり V2 へ渡す。

`BENITOITE_BUILD_COMMIT` は40桁・64桁の ASCII 十六進数を小文字へ正規化し、`unknown` を空の埋め込み値へ変換する。`BENITOITE_BUILD_DIRTY` は `true`・`false`・`unknown` を受け付ける。明示値の由来は値が不明でも `environment`、dirty の未指定は `unknown`・`notCollected` である。入力の不正は Git で補わず、入力名と許す構文を標準エラーへ出して build.rs の終了状態1とする。検証を終えるまで `rustc-env` は出さない。

commit が未指定のときだけ Git を起動する。候補の根の `.git`、Cargo.toml、同じ実体の crates/benitoite、Git が返す根を照合する。Git の子から指定された六つのリポジトリ選択変数を除き、`--no-optional-locks`・`core.fsmonitor=false` を渡す。取得失敗は空の commit・`unknown` とし、dirty の指定を保つ。status は採らない。

監視は build.rs、二つの明示入力、存在する HEAD・参照中の ref・packed-refs だけである。管理場所と ref のパスは Git で解決し、TARGET・index・作業ツリー・欠けたパスは監視しない。`TARGET` は Cargo の値を埋め込む。

## test-audit の作成時の関門

- 守る契約は、実際にリンクしたプログラムの埋め込み値と由来、入力の拒否、Git を使う条件、Cargo の監視対象である。
- 現実的な退行は、明示 unknown からの Git 採取、未指定 dirty の false 化、不正値の黙認、改行による Cargo 命令の混入、欠けたパスや作業ツリーの監視による不要な再ビルドである。
- 既存の処理系には build.rs とその検査がないため、この契約を捕まえるテストがない。一つの独立した統合テストに正常10例・不正20例（Unix の非 UTF-8 の2例を含む）を置く。内部の関数を直接呼ばず、埋め込み値は一時クレートの stdout、拒否は Cargo と build.rs の終了状態・stderr、監視は実際に Cargo が保存した命令、Git の非起動は外部 Git の trace で確認する。
- 本番の API・フラグ・差し込み口は追加しない。子の Cargo は固定したツールチェーンの実体、絶対パスの一時 target-dir、親の CARGO_TARGET_DIR と明示入力を除いた環境を使う。Git のグローバル・システム設定を無効化し、署名・hooks・fsmonitor などの local 設定を管理する。親の環境と実リポジトリの checkout は変更しない。

## 検査

依頼の指定に従い、`scripts/check.sh` は dry-run を含めて実行していない。`scripts/check.sh` の classify を読み、追加した Rust ファイルが `crates/*` により rust へ分類されることを確認した。gc-stress の構成も実行しない。両者の最終実施はオーケストレータへ渡す。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --test build_info -- --include-ignored` | 1 passed、0 failed。再実行は5.37秒。通常構成で本番 build.rs をコピーし、正常10例・不正20例を実ビルドで確認 |
| `cargo test -p benitoite --lib`（一回目） | 1194 passed、0 failed、21 ignored（既存の指定）。コンパイル26.23秒、テスト80.29秒 |
| `cargo test -p benitoite --lib`（二回目） | 1194 passed、0 failed、21 ignored（既存の指定）。再コンパイルなし。ビルド処理0.12秒、テスト79.33秒 |
| `cargo clippy --workspace --all-targets -v` | 終了状態0、59.73秒。詳細出力で `clippy-driver ... --crate-name build_script_build ... crates/benitoite/build.rs` と workspace の deny 指定を確認 |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` と新規三ファイルの末尾空白の確認 | 問題なし |

一回目と二回目のライブラリテストは rtk を通さず、生の Cargo 出力を `/private/tmp/benitoite-v1a-validation-Szljcp/lib-first.log` と `lib-second.log` に保存した。二回目のログ全体に `Compiling benitoite` がないことを確認した。clippy の詳細出力も同じディレクトリの `clippy.log` に保存した。clippy では sandbox により Cargo の大域キャッシュの最終使用情報を保存できない警告が出たが、lint の診断はなく終了状態0で完了した。

## 計画との差と申し送り

実装の範囲と契約に計画からの変更はなく、新しい R の判断は不要であった。最初の統合テストでは、64桁の正常例に68桁のテストデータを書いていたため、その入力が意図どおり拒否されて失敗した。入力データを64桁へ直し、期待する契約を変えずに再実行した。

V1b は同じテストの準備処理と表を拡張し、detached・worktree・packed refs・Git 採取失敗・親が別 repo のアーカイブ、更新による再採取と監視の限界を確認する。V2 で初めて五つの埋め込み変数を実行時の JSON へ接続し、05-01 の説明を更新する。形式化、生成物、docs/todo は変更していない。コミットは行っていない。
