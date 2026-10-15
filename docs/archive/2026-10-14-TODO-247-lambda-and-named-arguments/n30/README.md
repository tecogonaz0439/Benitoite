# N30 現行の例・道具の入力・参照解の移行

現行の `.bnt` 53 ファイルを確認し、49 ファイルを名前付き引数と名前を持つ関数型へ移行した。内訳は `tools/bench/programs/` が 12、`tools/bench/wasm/` が 10、`tools/bench/wit-transfer/` が 16、`tools/skill-eval/tasks/` の参照解が 11 ファイルである。構成子の直接の構築・パターン、属性、ハンドラの節は従来の指定を保った。

`crates/benitoite/examples/` に現行の `.bnt` はない。Rust に埋め込む入力は N29 の担当である。今回の対象は、Git が追跡する標準ライブラリ・testdata・文書以外の `.bnt` 全件と一致する。depth・fib・lines・tree は変更不要だった。過去の測定・評価記録、構文の比較資料、reference・archive・docs/todo は編集していない。性能測定と LLM を呼ぶ評価も実行していない。

## 分類と差分の確認

計画の 396 候補は変更箇所数ではない。N1 の記録では、今回の 53 ファイルに通常の関数呼び出し 364 件とパイプを含む関数呼び出し 32 件があり、合計が 396 件になる。別に直接の構成子・パターン 61 件と名前付きのレコード等 5 件がある。全 462 件を `classification.json` に記録した。

初回の AST・型情報による抽出では 534 候補があり、編集を含む保留のない 334 候補を確認し、45 ファイルへ適用した。残る名前・穴・パイプ・関数値は個別に確認した。最終の全 53 入力は型検査を通り、複数位置引数と匿名の非ゼロ引数関数型はゼロである。移行器をもう一度実行した結果も、編集を持つ候補と提案 diff はゼロだった。

- `manifest.json`・`migration.diff`・`manifest.json.applied.json`: 初回の候補、確認した編集、適用時のハッシュ。後続の個別修正を含む最終ソースへ初回の manifest を再適用するものではない。
- `individual-manifest.json`: 初回の適用後から最終ソースまでの 546 編集範囲。元の Git の内容へ確認済みの初回編集を適用し、そのハッシュを受領記録と照合した。その後の個別編集もメモリ内で再適用し、最終ソースとの完全一致を全件確認した。適用方法は direct_edits_verified_by_in_memory_replay と明記した。
- `individual-labels-review.json`: 保留だった 95 呼び出しの契約名・元の理由・元のバイト位置。宣言を確認して名前だけを挿入した。コールバックの適合は別途確認した。
- `final.diff`: 既存の 49 ファイルの最終差分。
- `final-inventory.json`・`second-pass-summary.json`: 最終の入力ハッシュ、全件の型検査、旧表記の残数、再抽出の結果。再抽出で残る public_contract 等の保留は編集を含まず、未移行の箇所数には数えない。
- `input-checks.json`: 実行対象の 51 ファイルの CLI の結果。write_tests は test、ほかは check を使った。入口のない二つの Runner は全件の型情報の検査と、それぞれを import する実行対象で確認した。

WASM の json-b・json-c・regex-c-once・regex-c-resource は、移行前から依存先の関数値と契約名が合わず E0454 になっていた。呼び出し側のラベルとラッパーを移行し、四件とも成功した。依存パッケージ側は変更していない。

## 関数値と局所名

Q10 のコールバック名と異なる標準関数・構成子は、明示のラムダで包んだ。Runner.measure の render は function(value: A) -> String に揃えた。外側の公開名 count・work・render は維持した。

入れ子のコールバックを同じ value にすると外側の束縛を隠すため、三つの参照解では Result.andThen の本体を try と従来の次の処理に書き換えた。Error のときに後続を実行しないことと、成功時の処理順を保っている。json_convert の構成子値には、独立した jsonString 関数で名前を合わせた。詳しい判断は decisions.md の R87 に推す案として記録した。

## テストの作成時の関門

| 問い | 判断 |
|---|---|
| 守る観察可能な振る舞い・契約 | 参照解の出力・生成ファイル・終了状態、write_tests の四つのテストと六つの Assert、WIT の独立した期待値と呼び出し経路を保つ |
| 検出する退行 | ラベルの付け違い、ラムダの捕捉の変化、Result の失敗後の処理の実行、処理順や生成結果の変更 |
| 既存の検査との違い | 新しいテストは加えていない。既存の golden、参照解の自己検査、WIT の検証と期待値を使う。write_tests の六つの引数式と期待値はラベルを除いて完全一致することも照合した |
| 本番の差し込み口 | 追加していない。実際の CLI・型検査・既存の検証道具を使う |

Rust のテストと assertion、診断・標準出力・生成ファイルの期待値、ignore の指定は変更していない。write_tests の照合は `test-invariants.json` に記録した。

## 検査と結果

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,150 passed、既存の 21 ignored |
| `cargo test -p benitoite --test golden` | 成功。2 passed。通常の golden と bench の参照インタプリタとの比較を含む |
| `cargo clippy --all-targets` | 成功 |
| K の heap-verify・alloc-stats の clippy | 成功。gc-stress は指定していない |
| K の gc-mark-sweep の clippy | 成功 |
| `cargo fmt --all --check`・`git diff --check` | 成功 |
| 全対象の AST・型情報の検査 | 53 件すべて成功。旧複数位置引数・旧非ゼロ引数関数型ともゼロ |
| CLI の check・test | 実行対象の 51 件すべて成功 |
| Skill 評価の `--self-test` | 移行前後とも 12 件成功。11 課題と包みのコマンド。LLM を呼ばず、既存の標準出力・生成ファイル・終了状態・テスト結果と比較 |
| WIT の `verify.py --sample zero --sample small --sample repeat` | 移行前後とも 33 件成功。既存の期待出力・終了状態・宣言ごとの経路と呼び出し数が一致 |
| `.args.small` の 14 入力 | 移行前後の標準出力・標準エラー・終了状態が完全一致。`compared-runs.json` |
| 移行器の再実行 | 編集候補ゼロ、提案 diff は空 |

検査の正確なコマンドは `checks.json` に記録した。ユーザーの指定に従い、scripts/check.sh は dry-run を含めて実行せず、gc-stress の構成も実行していない。処理系の構文・型・脱糖と formal/ は変更していないため、形式検査と lake build は実行していない。

## 計画からのずれと申し送り

関数値の契約と局所名の衝突の解き方を R87 に具体化した。処理系の変更と未解決の移行箇所はない。N31〜N32 は現行文書と Skill、N33 は最終規則の強制、N35 は版と language 宣言を引き継ぐ。オーケストレータによる scripts/check.sh と gc-stress の最終検査、コミットを残す。docs/todo は変更していない。
