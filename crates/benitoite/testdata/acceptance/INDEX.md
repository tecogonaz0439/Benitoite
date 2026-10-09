# 完了条件と受け入れテスト

## 最小実行版の完了条件

| 完了条件 | テスト |
|---|---|
| 固定の文字列を標準出力に書く | `acceptance/hello.bnt` |
| 利用者が代数的データ型で定義したリストを、パターンマッチで集計して出力する | `acceptance/adt_list_sum.bnt` |
| 十分に深い末尾再帰を行う | `acceptance/deep_tail_recursion.bnt` |
| 型の合わない式を含む | `acceptance/type_error_check.bnt`, `acceptance/type_error_run.bnt` |
| 網羅していないパターンマッチを含む | `acceptance/nonexhaustive.bnt` |
| IO を行う関数を、IO を許さない文脈から呼ぶ | `acceptance/effect_violation.bnt` |
| ファイルを読んで行数を数える | `acceptance/count_lines_ok.bnt`, `acceptance/count_lines_missing.bnt` |
| 構文エラーを含む | `acceptance/syntax_error.bnt` |
| ベンチマーク（最小実行版の範囲） | `tools/bench/programs/` |

## 初回リリース版の完了条件

処理系のテストに対応させる行を載せる。JSON の集計の行は、LLM の試行を処理系のテストに含めないため、同じ課題の解のスクリプトのテストを載せる。

| 完了条件 | テスト |
|---|---|
| 同梱の Agent Skill だけを与えた LLM が、JSON ファイルを読んで集計するスクリプトを書く | `acceptance/json_summary.bnt` |
| 外部コマンドを引数の配列で起動するスクリプト（`Process.run`）と、シェルで実行するスクリプト（`Process.shell`）を実行する | `acceptance/process_run.bnt`, `acceptance/process_shell.bnt` |
| 影響の大きい操作（外部コマンドの起動、プロセスの終了、ファイルの書き込み）を、テストのコードのハンドラで差し替えて `test` を実行する | `acceptance/test_replaces_effects.bnt` |
| コメントを含むスクリプトに `fmt` を適用する | `acceptance/fmt_comments.bnt`, `acceptance/fmt_comments_check.bnt` |
