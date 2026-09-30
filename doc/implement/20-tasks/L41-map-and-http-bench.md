# L41 map と http のベンチマーク

- 依存する作業: [L02](L02-map-and-set-functions.md)、[L31](L31-http-serve-and-helpers.md)、[L32](L32-http-client.md)、[C16](C16-bench.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L41-map-and-http-bench

## 目的

[性能](../../design/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」のベンチマークのうち、C16 が U3 に回した `map` と `http` を `tools/bench/` に加える（C16「目的」）。測定そのもの（静かな計算機での本測定と所見）は、U3・U4 を終えた後に、スキル `benchmark` の手順で行う（[完了後の作業](../90-after-completion.md)の「U3・U4 を終えた後に行うこと」）。本作業では、道具が動き、出力が期待どおりであることを確かめる。

メモリの管理の方式の決着（[OPEN-036](../../design/open-issues.md#open-036)）は、HTTP と map を加えた後の測り直しを待つ（ADR 0268 の決定 5、README の「U3・U4 で決めたこと」の 11）。[R33](R33-memory-management-remeasure.md) は、本作業のベンチマークで測り直す。

## 読む設計書の節

- [性能](../../design/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」（map と http の行、http の比較対象の扱い、要求の処理の量と待ち時間の項目、呼び出しの回数の予算）、「比較対象」「測定の環境と記録」
- [ロードマップ](../../design/00-overview/00-03-roadmap.md)の「初回リリース版」の並行処理の水準（スクリプトで簡易な HTTP サーバを動かせる、待ち受けや計算を続けているタスクがほかのタスクを止めない）
- ADR: [0103](../../design/decisions/0103-map-and-set-ordered-by-key.md)、[0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0268](../../design/decisions/0268-staged-runtime-rebuild.md)

インターフェース・作業の文書:

- C16 の作業の文書（ベンチマークのプログラムの置き方、`.args.small`、開発用の例 `bench_run`、`run.py` と記録の書式）
- スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）と `tools/bench/README.md`

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `tools/bench/programs/map.bnt` と比較対象の版（`python/`・`ruby/`・`lua/`・`ocaml/`・`rust/`） | 引数で与えた数の鍵を `Map` に挿入し、探索し、削除する。`Set` も同じく行う。鍵は決まった種の擬似乱数で作る。比較対象は、それぞれの言語の順序付きのマップ（OCaml の `Map`、Rust の `BTreeMap`）か、標準の辞書（Python の `dict`・Ruby の `Hash`・Lua の表）で書き、順序の有無の違いを README に書く |
| `tools/bench/programs/http.bnt` | スクリプトで書いた HTTP サーバ（`Http.serve` の形）と、同じスクリプトの中から多数の要求をループバックで送るクライアントのタスク。引数で、要求の数と、計算を続けるタスクを同時に動かすかを切り替える（07-02 の二つの形）。Benitoite だけ |
| 各ベンチマークの `.args.small` | 差分テストで数十ミリ秒で終わる入力。`http` はタスクと IO を使うので差分テストから外れる（C10 の選び方） |
| `tools/bench/run.py` | map と http を加え、http の要求の処理の量（一秒あたりの要求の数）と、要求ごとの応答までの時間の中央値と最大を取る |
| `tools/bench/results/TEMPLATE.md`・`tools/bench/report_html.py` | 追加の項目の表とグラフ |
| `tools/bench/README.md` | 追加のベンチマークと項目、測り方、近似であるものの説明 |

処理系の `src/` は変えない。

## 手順の要点

- 要求を送る側の道具は、07-02 が「測定の手順を定めるときに選ぶ」とした。本作業では、外部の道具を加えず、同じスクリプトの中のクライアントのタスクで送る形にする。処理系の外の道具（`wrk` など）を使う形は、本測定のときに設計者と決める。この判断を README に書く。
- http の要求ごとの応答までの時間は、クライアントのタスクが `Clock.monotonicMilliseconds` で送る前と受け取った後を測り、スクリプトの出力に集計を書く形にする。`run.py` はその出力を読む。
- 呼び出しの回数の予算を変えた http の実行を、C16 の `bench_run` の選択肢（`--call-budget`）で行えるようにする（07-02 の「tasks と http を、初めの値を変えて測り」）。
- map の比較対象の出力（最後に残った要素の数と、探索で見つかった数）が、Benitoite と一致することを確かめる。

## 受け入れテスト

- `run.py` で map と http を小さな入力で一回ずつ動かし、記録の雛形に値が入る。
- map の各比較対象の出力が、Benitoite の出力と一致する。
- http の二つの形（計算を続けるタスクの有無）で、すべての要求に応答が返る。
- `.args.small` の map が差分テスト（C10）で参照インタプリタと同じ結果になる。

## 完了条件

- `scripts/check.sh` が通る
- 上のファイルがあり、`tools/bench/README.md` に使い方が書かれている
- `src/` を変えていない

## 確認の観点

- ベンチマークのプログラムが、07-02 の表の「何を測るか」に合っているか（map は平衡二分木の更新と探索、http はイベントループと待つタスクの切り替え）。
- 比較対象が同じ処理を行っているか（同じ数の操作、同じ鍵の列）。

## 難易度の理由

C16 が作った道具の形に二つのベンチマークを加えるだけであり、判断は要求を送る側の形に限られる。
