# Lean 検査の記録

全検査に `-M 12288` を付け、独立した P3 のファイルを `formal` から検査した。一回10分の上限を設け、該当した検査はない。

`/usr/bin/time -l` は sandbox 内の `sysctl kern.clockrate` を拒否され、経過・user・sys を表示した後で終了1になった。要求された `maximum resident set size` は全回で取得できなかった。以下のRSSは Python `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` による **補助値**（macOS、bytesをMiBへ換算）であり、time -l の同名欄として報告しない。Lean 自体の終了値は別マーカー/子プロセスの終了状態から取得した。測定器の終了1とLeanの成功・失敗を分ける。

| 記録 | 対象 | Lean の終了 | 経過秒 | 補助最大RSS MiB | 外側timeの終了 | 生ログ |
|---|---|---:|---:|---:|---:|---|
| 001 | Syntax.lean | 1 | 3.849 | 804.16 | 1 | [001](checks/001.log) |
| 002 | Syntax.lean | 0 | 4.085 | 813.81 | 1 | [002](checks/002.log) |
| 003 | Syntax.lean | 1 | 4.651 | 818.56 | 1 | [003](checks/003.log) |
| 004 | Syntax.lean | 1 | 4.806 | 818.83 | 1 | [004](checks/004.log) |
| 005 | Syntax.lean | 1 | 4.341 | 822.06 | 1 | [005](checks/005.log) |
| 006 | Syntax.lean | 0 | 4.237 | 823.45 | 1 | [006](checks/006.log) |
| 007 | Syntax.lean | 1 | 4.379 | 825.50 | 1 | [007](checks/007.log) |
| 008 | Syntax.lean | 1 | 4.404 | 824.98 | 1 | [008](checks/008.log) |
| 009 | Syntax.lean | 1 | 4.408 | 826.88 | 1 | [009](checks/009.log) |
| 010 | Syntax.lean | 1 | 4.394 | 826.78 | 1 | [010](checks/010.log) |
| 011 | Syntax.lean | 1 | 4.660 | 836.78 | 1 | [011](checks/011.log) |
| 012 | Syntax.lean | 1 | 4.732 | 837.78 | 1 | [012](checks/012.log) |
| 013 | Syntax.lean | 0 | 4.566 | 837.39 | 1 | [013](checks/013.log) |
| 014 | Syntax.lean | 1 | 4.716 | 841.95 | 1 | [014](checks/014.log) |
| 015 | Syntax.lean | 0 | 4.744 | 841.59 | 1 | [015](checks/015.log) |
| 016 | Syntax.lean | 0 | 4.625 | 842.02 | 1 | [016](checks/016.log) |
| m6-01 | M6.lean | 1（構文エラーあり） | 4.640 | 取得なし | 1 | [m6-01](checks/m6-01.log) |
| m6-02 | M6.lean | 0 | 4.826 | 1489.39 | 1 | [m6-02](checks/m6-02.log) |
| m6-03 | M6.lean | 0 | 4.664 | 1486.78 | 1 | [m6-03](checks/m6-03.log) |
| m6-04 | M6.lean | 1 | 4.657 | 1490.34 | 1 | [m6-04](checks/m6-04.log) |
| m6-05 | M6.lean | 1 | 5.054 | 1492.92 | 1 | [m6-05](checks/m6-05.log) |
| m6-06 | M6.lean | 1 | 5.148 | 1491.91 | 1 | [m6-06](checks/m6-06.log) |
| m6-07 | M6.lean | 0 | 5.233 | 1495.91 | 1 | [m6-07](checks/m6-07.log) |

最終の検査は Syntax が016、M6がm6-07である。各回のコードは変更途中なので、途中で成功した回を最終版の証拠として代用しない。検査器のエラー出力や途中の `sorryAx` は失敗ログに残す。最終ログには `sorryAx` がなく、新規の独自公理はない。

再実行は `python3 spikes/P3/checks/run.py <未使用の番号>`（Syntax）又は `checks/lean-child.py` を `/usr/bin/time -l` の内側で呼ぶ（M6）。どちらも本番ファイルは変更しない。M6 の連結の一致と最終ファイルのSHA-256は `completion.json` へ記録する。
