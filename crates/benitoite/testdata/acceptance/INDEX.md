# 完了条件と受け入れテスト

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
