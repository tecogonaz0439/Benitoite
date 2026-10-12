# 測定の記録

## 性能の関門（fib・loop）

2026-10-12 に、arm64 の macOS で、リリースのビルドで測った。比べる前の版は 1ca0f7b（改造を始める前のコミット）で、`git archive` で取り出した場所でビルドした。後の版は X4 の直しを取り込んだ後の版（6e2ef504。その後の X5 の直しはコメントと文書だけ）である。`tools/bench/gate.py` で、二つの版の `examples/bench_run` を交互に 10 回走らせた。数字は実行の段の時間（`run`）。

| 版 | fib の最小 | fib の中央値 | loop の最小 | loop の中央値 |
|---|---:|---:|---:|---:|
| 1ca0f7b（前の版） | 1.839 秒 | 1.862 秒 | 0.951 秒 | 0.964 秒 |
| 6e2ef504（後の版） | 1.836 秒（−0.2 %） | 1.839 秒 | 0.952 秒（+0.1 %） | 0.957 秒 |

VM の振り分けのループは変えておらず、差は測りの揺れの範囲である。

## 作業ごとの関係するテストの時間

各作業の完了の報告から、回収の強制の構成（`gc-mark-sweep,heap-verify,gc-stress`）で走らせた関係するテストの時間（ビルドを含む）を写す。

| 作業 | 対象 | 時間 |
|---|---|---:|
| X1 | ライブラリのテスト（sched::parts、io::resources、refinterp、funcs::file・samples）と統合テスト 5 本 | 12.9 秒 + 11.7 秒 |
| X1 | `open_062` を 3 回続けて | 各 1.1 秒 |
| X2 | ライブラリのテスト（sched、dispatch::tasks）と `open_062` | 17.6 秒 + 4.4 秒 |
| X3 | ライブラリのテスト（funcs::file・console・process）と統合テスト 2 本 | 13.3 秒 + 11.2 秒 |
| X4 | ライブラリのテスト（funcs::file、io::resources）と `io_modes` | 12.6 秒 + 5.1 秒 |
| X5 | 統合テスト 2 本（`l32_http_client`、`network_faults`） | 8.4 秒 |

回収の強制の構成で `--lib builtins::funcs` の全体を走らせると約 11 分かかり、その大半は `regex_replacements_join_multiple_chunks` の 1 件だった（X1 の事前点検での実測）。作業ごとの検査は触れたモジュールに絞った。
