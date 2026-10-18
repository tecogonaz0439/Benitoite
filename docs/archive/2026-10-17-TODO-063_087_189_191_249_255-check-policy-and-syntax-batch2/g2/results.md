# G2 の結果

基準 B: `8fc101a8e17c630ca0e54449ab1e4bb169fda4cf`（G1b 取り込み後）。作業日は2026-10-18。コミットと docs/todo/ の変更は行っていない。

JSON Codec、レコードの JSON 生成、生成例と記録、英語の契約・現行設計・Skill を実装へそろえた。Codec は純粋な Result を返し、Fail を要求しない。往復、欠落と Null、余分なキー、宣言順の最初の失敗、List/Map の相対経路、数の厳密な種類と非有限値、カスタム変換・decodeMissing、未対応型の拒否、再生成の不一致を確認した。

## テストの作成時の関門

1. 守る契約は Codec の戻り値・相対経路・変換順と、型から生成した通常の関数の実行結果・再生成の検出である。
2. 暗黙の数の変換、非有限値の見逃し、キー順での欄検査、先に余分なキーを拒否する変更、経路の欠落、古い型・設定でも生成 check が通る退行を捕まえる。
3. 既存 l21_json は問い合わせと ParseError、管理の自己検査は固定の通常の関数を扱っており、変換の契約には届かない。既存 run_script と管理の準備を共有し、Codec は pipeline から実 VM まで、生成は実 reader・formatter・CLI・VM で検査する。
4. 本番の差し込み口と公開範囲をテストのために増やしていない。管理の既存 assert を保ち、JSON の意味の正負例を新しいクラスへ置いた。モジュール説明の退行テストは旧挿入位置で失敗し、修正後に成功した。

## 作業末の検査

以下は各コマンドの外側で測った時間である。同じ基準・選択の dry-run を各 work 呼び出しの前に行い、すべて終了0だった（dry-run の時間は未計測）。失敗した所と未実行の所だけを再開し、成功した lib 全件・統合ターゲットを繰り返していない。

| ID | 終了状態 | 外側の時間（秒） | 結果 |
|---|---:|---:|---|
| C1 | 1 | 99.278 | fmt 成功。lib は1207成功・1失敗・既存21 ignoreで停止 |
| C2 | 0 | 5.216 | 失敗した標準ソースの整形の1件が成功 |
| C3 | 1 | 26.637 | 統合の先頭6ターゲットまで進み、desugar_export の2件で停止 |
| C4 | 0 | 2.245 | 交換の失敗した2件が成功 |
| C5 | 1 | 189.881 | 次の21ターゲットが成功し、英語例の出力ブロック不足で停止 |
| C6 | 0 | 131.983 | 英語例と残り9ターゲット、規約・生成物・仕様集計・Python・移行器が成功 |
| C7 | 0 | 7.382 | 全 targets の clippy 成功 |
| C8 | 0 | 24.474 | derive の自己検査19件が成功 |
| C9 | 0 | 0.318 | 生成例の通常の check が成功 |
| C10 | 0 | 0.360 | 生成例の @test 1件が成功 |
| C11 | 0 | 0.235 | 生成例の再生成 check が一致 |

既定 lib は修正後の1件を合わせて1208件、統合は全37ターゲットで計253件の成功を確認した。既存の ignore は変更していない。

### C1

```sh
scripts/check.sh --level work --base 8fc101a8e17c630ca0e54449ab1e4bb169fda4cf --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*'
```

### C2

```sh
cargo test -p benitoite --lib cli::tools::formatter::tests::stdlib_sources_are_canonical
```

### C3

```sh
scripts/check.sh --level work --base 8fc101a8e17c630ca0e54449ab1e4bb169fda4cf --only tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*'
```

### C4

```sh
cargo test -p benitoite --test desugar_export export_extensible_
```

### C5

```sh
scripts/check.sh --level work --base 8fc101a8e17c630ca0e54449ab1e4bb169fda4cf --only fmt,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

### C6

```sh
scripts/check.sh --level work --base 8fc101a8e17c630ca0e54449ab1e4bb169fda4cf --only tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

### C7

```sh
cargo clippy --all-targets
```

### C8

```sh
python3 -B tools/derive/test_derive.py
```

### C9

```sh
target/debug/benitoite check tools/derive/examples/People.bnt
```

### C10

```sh
target/debug/benitoite test tools/derive/examples/People.bnt
```

### C11

```sh
python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json
```

## 失敗と修正

- Codec 初稿の局所検査では、文字列の演算子、ラムダの局所名の隠蔽、Result.mapError へ渡すコールバックの契約名を修正した。JSON の自己検査の準備では、二ファイルへの適用件数を2、CLI の静的な拒否を終了2として厳密に照合する形へ直した。既存の期待を緩める変更ではない。
- 生成例を実際に check すると、import をファイルの先頭へ入れたため `//!` が後へ移動し、E0229 で失敗した。AST の先頭部分の終了位置を使う修正と退行テストを加えた（R97）。生成前の手書きの例へ戻し、修正後の preview の差分・記録を確認して apply し直した。
- C1 の標準ソースの整形失敗は Codec の case 行の末尾空白であった。本番 formatter で直し、C2 でその1件を再確認した。
- C3 の交換の失敗は、追加した @extensible な ConversionError が全標準宣言へ入ったためである。標準の厳密な件数を4から5、利用者の三型を含む件数を7から8へ更新し、型名・レコードかどうかの厳密な一覧にも ConversionError を追加した。package・extensible・coverageView・表への保持の assert はすべて保った（R98）。C4 で二件とも成功した。
- C5 は追加した英語の例に output ブロックがなく、例の抽出で停止した。出力なしを厳密に照合する空の output ブロックを補い、C6 で既存の例を含めて成功した。

## 計画からのずれと申し送り

- [decisions.md](../decisions.md) の R96 に基準と lint の割り当て、R97 に import の配置、R98 に新しい標準型による交換の期待の変更を記録し、[plan.md](../plan.md) の G2 の work 行も具体化した。自動 dry-run の9単位から lint_default を除き、依頼の cargo clippy --all-targets を一度だけ別に実行した。
- 初回 work は失敗で停止したため、その後は失敗したテストと未実行の対象だけに絞った。上のコマンドに再開の実値をすべて記した。全件の特殊構成、gc-stress、check-formal.sh、change/release は追加していない。
- reader と CLI は Rust 入力の変更後に再ビルドした。標準ソースと Skill の生成元を変えた後は gen_skill で生成し直し、C6 の skill_generated でも一致を確認した。新しい型の一覧は01-05・英語リファレンス・手書きの Skill にも反映した。形式化の規則と formal/ は変えていない。
- Property のライブラリと生成は G3/G4 の担当であり、現在は Property の生成を要求する設定を拒否する。G4/V1 は新しい標準宣言と例を含む最終の全比較・manifest の照合を行う。訳と版の整合は V1 に残す。
- この記録を含む文書のローカルリンク400件は未解決0件、最終の `git diff --check` は終了0であった。両方の外側の時間は未計測である。
