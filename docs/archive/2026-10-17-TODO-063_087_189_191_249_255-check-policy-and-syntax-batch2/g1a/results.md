# G1a の結果

基準 B: `95902e535c2f777d426e0a14df51d8b924baf274`（P1 取り込み後）。コミット・docs/todo・formal/ は変更しない。

## 検査

作業中は `cargo check -p benitoite --example derive_inventory` と `cargo test -p benitoite --test declarations`、同ターゲットの対象名による局所検査を使用した。最終の局所確認は4件成功。初回のコンパイルで sha2 0.11 の配列の十六進表示、任意の型注釈の Span、組み込みエフェクトの欄名を実装へ合わせた。追加テストの準備では const の区切り、公開型から参照する別名の公開指定、一時ディレクトリ名のスレッド間の衝突を直した。既存の assert・期待・ignore は変更していない。

`cargo fmt --all` で、pipeline.rs を直接読む既存 example に対する子のモジュールのパスが不足していることを検出し、明示の `#[path]` を追加した。共通の文言モジュールに置いた CLI 専用の USAGE が統合テストでは未使用となったため、その定数は CLI 側の text へ置いた。

work 実行中の example の最終確認で、設定だけが参照するカスタム関数のモジュールを読み込む必要があることを発見した。既存の JSON テストを未 import の Helpers.text に変え、修正前は `unknown custom function: Helpers.text` で終了101となることを確認した。R93 の修正後に `cargo test -p benitoite --test declarations` を再実行し、4件成功した。非公式の Failure.toResult の解決名・importPath・NoFail の出力も同じテストで確認した。この修正は example と declarations テストだけであり、lib と他の統合の検査は古くならない。formatter の確認だけを追加する。

作業末の work は以下の指定へ `--dry-run` を付けて選択を確認してから一度実行し、終了0（外側443.153秒）となった。既定 lib は1208件成功・既存21件 ignore、37統合ターゲットはすべて成功した。宣言収集の修正後の declarations は下表で再確認した。他の lib・統合・特殊構成は繰り返していない。

```sh
scripts/check.sh --level work --base 95902e535c2f777d426e0a14df51d8b924baf274 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test build_info --test call_allocations --test cli_process --test coverage_export --test declarations --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

| 検査 | 終了状態 | 外側の秒数 |
| --- | ---: | ---: |
| `cargo build -p benitoite --example derive_inventory` | 0 | 2.574 |
| `cargo clippy --all-targets` | 101 | 9.304 |
| `cargo fmt --all --check` | 0 | 2.099 |
| `cargo test -p benitoite --test declarations` | 0 | 1.943 |
| `cargo build -p benitoite --example derive_inventory` | 0 | 0.821 |
| `cargo clippy --all-targets` | 101 | 6.126 |
| `cargo fmt --all --check` | 0 | 2.082 |
| `cargo test -p benitoite --test declarations` | 0 | 1.773 |
| `cargo clippy --all-targets` | 0 | 0.707 |

初回の clippy は example の JSON 添字代入4か所を拒否したため、`as_object_mut` と `insert` へ変えた。次の clippy は新しいテストの一時ディレクトリの片付けにある `let _` を拒否したため、失敗を明示して報告する形にした。lint の許可は追加していない。これらの修正後は古くなった declarations・fmt・example の build・clippy だけを再実行した。表の同一コマンドの反復はこの修正に対応する。

入力ハッシュの期待値は、テスト対象の hash 関数で作らず、Python の hashlib で独立に得た固定の SHA-256 へ変更した。最終の declarations 4件はこの期待値で成功している。

実バイナリの `target/debug/examples/derive_inventory --root /private/tmp/benitoite-g1a-cli --config /private/tmp/benitoite-g1a-cli/<設定>` では valid.json・custom.json が終了0、duplicate.json が2、unknown.json が1となった。`--config` を省いた場合も2となり、失敗時に標準出力が空であることを確認した。5ケースの外側は0.668秒。正常出力は version 1・対象の解決名・Python の hashlib による入力ハッシュと一致し、設定だけが参照するカスタム関数を含む。前後で全入力のファイル名と生バイト列が不変であった。

文書は変更した4章の相対リンク192件と追加した節のアンカーを確認し、終了0。`git diff --check` も終了0。文書だけの検査の外側は未計測。G1a はヒープ・formal/ を変えず、gc-stress・all-targets のテスト・独立の全形式比較は実行していない。


## 計画との差と申し送り

R91 に宣言情報の所有する表、複数対象の仮想の入口、全入力の生バイトの保持と再読時の変化の拒否、既存 example の明示のパスを記録した。R93 に設定だけが参照する関数の読み込みと公開の import 名の対応を記録した。R92 と plan の work 行で基準と lint の重複を避ける割り当てを固定した。

後続は example の README の version 1 契約を使う。型の構造ハッシュでは位置と元の表記を除き、依存とカスタム関数のシグネチャを含める。生成で扱える依存グラフ・別モジュールの生成先・用途別のカスタム関数の型・生成名の衝突と管理領域の検査は G1b/G2/G4 の担当である。宣言収集の成功は通常の check/test --check の成功や実行前のエフェクト上限の確認に代用しない。

## テストの作成時の関門と差分

守る契約は、未生成の本体を検査せず宣言だけを取得すること、宣言の誤りを同じ段・位置で拒否すること、解決した構造と物理位置・全入力ハッシュを JSON に渡すことである。通常の check へ戻す、本体の評価へ進む、宣言の検査を飛ばす、別名を解決しない、位置を文字数で数える、カスタム関数のモジュールを読まない退行で失敗する。既存の check のテストは新しい公開入口と example の JSON を通らないため、この境界に4件を追加した。差し込み口をテストのために増やしていない。カスタム関数の不足は修正前の失敗を確認した。既存テストの削除・期待の緩和・ignore への変更はない。

Rust の差分（追加ファイルを含む）: 本番・example は追加1055行・削除7行、テストは追加265行・削除0行。
