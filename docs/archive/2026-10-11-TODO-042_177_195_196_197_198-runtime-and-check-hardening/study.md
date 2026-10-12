# 調査

2026-10-11 に、ブランチ `san_benito` の先頭（コミット 1f951aa）を、四つの観点に分けて調べた。各観点の調査は Opus のサブエージェントが行い、別々の文書に書いた。本書はその要点と、観点をまたぐ点をまとめる。再現のファイルはリポジトリの外に置き、重いテスト（`cargo test` の全体、`scripts/check.sh`、`scripts/check-formal.sh`）は走らせていない。

| 文書 | 扱う項目 |
|---|---|
| `study-http.md` | TODO-198（HTTP サーバの応答の組み立てと、要求の検査） |
| `study-runtime.md` | TODO-042（`Opaque`・`Host` の対象の別の領域の容量）、TODO-196（`Regex` の入力の写しと繰り返す照合の時間）、TODO-197（`Task.withTimeout` の期限を過ぎた完了） |
| `study-check.md` | TODO-195（型クラスの辞書の解決と網羅性の判定の資源消費）。あわせて判定の木の生成の増え方 |
| `study-uses.md` | TODO-177 の F-2（`uses` の表示の偽装） |

## 要点

- 外部のレビューの所見は、すべて今のコードでも成り立つ。実行して確かめたもの:
  - HTTP: 応答の `Transfer-Encoding` と `content-length` の両方、HEAD・204・205・304・1xx・CONNECT への応答の本体、Host のない要求や二つある要求への 200、トレーラの行の検査の甘さ。
  - ランタイム: `Regex.find` の入力の写しで回収が起きないままメモリが増えること（4 MiB の入力に 32 回で最大 RSS 161 MB、回収は 1 回）、繰り返す照合の 2 乗の時間、`Task.withTimeout(20, …)` が 1,106 ミリ秒かかった照合の結果を `Some` で返すこと。
  - 検査: 辞書の解決（深さ 20 の `check` が 3.26 秒・341 MiB）と網羅性の判定（n=9 が 1.57 秒）。どちらも大きさが一段増えるごとに約 4 倍になる。
  - `uses`: `import Benitoite.Unofficial.IO.File as Console` の後の `uses Console.Write` が `check` を通り、`run` でファイルを書いた。
- コードを読んで確かめたもの: `Http.respond` が再開のたびに応答を作り直すこと（HTTP-03）、取り消した readiness の待ちの記録が残ること（HTTP-04。02-09「タスクの待ちと取り消し」の「待ち受けの登録を外す」とも食い違う）、`accept` の警告が預かりの列に上限なく溜まりうること。
- 記述より広かったもの:
  - 判定の木の生成（`ir/decision.rs`）も指数的に増える。`check` は通るが、`run` と `test` が実行の前に時間とメモリを使い尽くしうる（2.4 KB のソースで `run` が 11.3 秒・656 MiB）。網羅性の判定に予算を設けても、この増え方は残る。
  - 辞書の木は、脱糖・コード生成・実行時の辞書の値でも節ごとに写されるので、`run` は `check` の 10〜14 倍かかる。
  - HTTP の要求の対象が絶対形（`GET http://evil/echo`）のとき、`Http.Request.path` に scheme と authority が混じる。`Expect: 100-continue` に 100 を送らない。Linux の `accept` が返す接続ごとの errno で `Http.serve` が終わる（読んだだけ）。
  - `uses` の偽装の経路は、エフェクトを宣言する標準ライブラリのモジュール（prelude の `Benitoite.IO` と `Benitoite.Assert` を含む）への `as` の一点である。`import Benitoite.IO as Pure` の後の `uses Pure.All` も W0501 の警告だけで通る。利用者のモジュールに組み込みの名前を付ける形は、E0506 になるので偽れない。
  - 別名があるとき、E0501 の修正案（`uses File.Write`）に従うと E0332 になり、その修正案に従うと E0324 になる。
- 付随して見つけたもの: 長い組み込みの関数（照合）の間に受けた SIGINT は、`main` が切り替えの位置を通らずに終わると読まれず、終了状態 0 になる。02-09「中断の要求」の決まりの範囲内の振る舞いである。

## 観点をまたぐ点

- 予算の診断: 辞書（E0715）・網羅性（E0609）・判定の木（L0112）・`uses` の別名（E0339）が、同じ `src/diag/codes.rs` の表に項目を足す。区分が違うので番号は衝突しない。
- 生成物: 診断の表と標準ライブラリのソース（`Regex.bnt`・`Network/Http.bnt`）を変えるので、`skill/references/` を作り直す。取り込みのたびに作り直し、最後にもう一度作り直す。
- `src/vm/dispatch/tasks/`: `Task.withTimeout`（`cancel.rs`・`tasks.rs` の `boundary`）と HTTP-04（`io.rs` の `reflect_cancellation`）が同じ下のファイルの近い位置に触れ、`vm/state.rs` の `scheduling` の欄を両方が足しうる。02-09「タスクの待ちと取り消し」の別々の箇条も両方が直す。取り込みの順を決めて順に行う。
- 性能の関門（07-02）: ヒープ（容量の計上）と VM のタスクの部分（`Task.withTimeout`）を変えるので、短い測定の対象になる。
- 形式化: 網羅性の判定の予算だけが、Lean の手順（`formal/Benitoite/Release/Coverage.lean`）と差分テストに関わる。辞書の解決・判定の木・名前解決は、形式化の範囲の外である。
