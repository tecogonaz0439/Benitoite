# L41 map と http のベンチマーク

- 依存する作業: [L02](L02-map-and-set-functions.md)、[L31](L31-http-serve-and-helpers.md)、[L32](L32-http-client.md)、[C16](C16-bench.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L41-map-and-http-bench

## 目的

[性能](../../2026-10-09-design-first-release/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」のベンチマークのうち、C16 が U3 に回した `map` と `http` を `tools/bench/` に加える（C16「目的」）。測定そのもの（静かな計算機での本測定と所見）は、U3・U4 を終えた後に、スキル `benchmark` の手順で行う（[完了後の作業](../90-after-completion.md)の「U3・U4 を終えた後に行うこと」）。本作業では、道具が動き、出力が期待どおりであることを確かめる。

メモリの管理の方式の決着（[OPEN-036](../../2026-10-09-design-first-release/open-issues.md#open-036)）は、HTTP と map を加えた後の測り直しを待つ（ADR 0268 の決定 5、README の「U3・U4 で決めたこと」の 11）。map と http の本測定は、[完了後の作業](../90-after-completion.md)の「U3・U4 を終えた後に行うこと」で行い、[R33](R33-memory-management-remeasure.md) の結果に加えて OPEN-036 を決着させる。

注記（オーケストレータへ）: http のベンチマークはループバックで待ち受けと接続を行うので、Codex はネットワーク（ループバックのソケット）を使える設定で起動する。

## 読む設計書の節

- [性能](../../2026-10-09-design-first-release/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」（map と http の行、http の比較対象の扱い、要求の処理の量と待ち時間の項目、呼び出しの回数の予算）、「比較対象」「測定の環境と記録」
- [ロードマップ](../../2026-10-09-design-first-release/00-overview/00-03-roadmap.md)の「初回リリース版」の並行処理の水準（スクリプトで簡易な HTTP サーバを動かせる、待ち受けや計算を続けているタスクがほかのタスクを止めない）
- ADR: [0103](../../2026-10-09-design-first-release/decisions/0103-map-and-set-ordered-by-key.md)、[0162](../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0268](../../2026-10-09-design-first-release/decisions/0268-staged-runtime-rebuild.md)

インターフェース・作業の文書:

- C16 の作業の文書（ベンチマークのプログラムの置き方、`.args.small`、開発用の例 `bench_run`、`run.py` と記録の書式）
- スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）と `tools/bench/README.md`

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `tools/bench/programs/map.bnt` と比較対象の版（`python/`・`ruby/`・`lua/`・`ocaml/`・`rust/`） | 引数で与えた数の鍵を `Map` に挿入し、探索し、削除する。`Set` も同じく行う。鍵は決まった種の擬似乱数で作る（式は「手順の要点」）。比較対象は、それぞれの言語の順序付きのマップ（OCaml の `Map`、Rust の `BTreeMap`）か、標準の辞書（Python の `dict`・Ruby の `Hash`・Lua の表）で書き、順序の有無の違いを README に書く |
| `tools/bench/programs/http.bnt` | スクリプトで書いた HTTP サーバだけを置く（`Http.listen("127.0.0.1", 0)` と `Http.listenerPort` で待ち受けてポートを知り、ポートを標準出力に一行で書き、要求の数だけ `Http.accept` を繰り返して終わる形）。クライアントはスクリプトに書かない。引数で、受け付ける要求の数と、計算を続けるタスクを同時に動かすかを切り替える（07-02 の二つの形）。Benitoite だけ |
| `map` の `.args.small` | 差分テストで数十ミリ秒で終わる入力。`http` には `.args.small` を置かない（`scripts/check.sh` の中でサーバを動かさない。タスクと IO を使うので差分テストからも外れる） |
| `tools/bench/run.py` | map と http を加える。http では、`run.py` が benitoite のサーバの起動、ポートの受け取り、終了を扱い、自分がクライアントとして要求を送り、要求の処理の量（一秒あたりの要求の数）と、要求ごとの応答までの時間の中央値と最大を取る（後述の「http の測り方」） |
| `tools/bench/results/TEMPLATE.md`・`tools/bench/report_html.py` | 追加の項目の表とグラフ |
| `tools/bench/README.md` | 追加のベンチマークと項目、測り方、近似であるものの説明 |

処理系の `src/` は変えない。

## 手順の要点

- `http.bnt` は `Http.serve` で書かない。`Http.serve` は自分からは終わらないので、ベンチマークの一回の実行が終わらない。要求を受け付けるタスクは、`Http.accept` を要求の数（引数で与える N）だけ繰り返して終わる。
- スクリプトでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Network.Http`・`import Benitoite.Unofficial.IO.Clock` など。[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-09 の例の `import Benitoite.Network.Http` の形をそのまま写すと、E0321 になる。
- map の鍵の擬似乱数は、`tools/bench/programs/listget.bnt` の式 `next = (seed * 48271 + 11) mod 2147483647`（種は 2147483647 未満に保ち、掛け算を Integer の範囲に収める）を使い回す。比較対象も同じ式と同じ種で鍵の列を作り、言語の間で出力を一致させやすくする。
- Rust の比較対象は `tools/bench/programs/rust/src/bin/map.rs` に置く。`tools/bench/programs/rust/Cargo.toml` は `[[bin]]` を書かずに `src/bin/` の自動の検出に任せているので、その形のままなら Cargo.toml への追記は要らない（`[[bin]]` を書く形に変わっていたら、map の行を足す）。
- 呼び出しの回数の予算を変えた http の実行を、C16 の `bench_run` の選択肢（`--call-budget`）で行えるようにする（07-02 の「tasks と http を、初めの値を変えて測り」）。
- map の比較対象の出力（最後に残った要素の数と、探索で見つかった数）が、Benitoite と一致することを確かめる。

### http の測り方

設計者の判断（2026-10-08）: 言語の時計（`Clock.monotonicMilliseconds`）はミリ秒までしか測れず、ループバックの要求の応答までの時間を測るには粗い。そこで、benitoite にはサーバだけを動かさせ、`tools/bench/run.py`（Python）がクライアントとして要求を送り、応答までの時間を処理系の外で測る。処理系の `src/` は変えない。07-02 の「要求を送る側の道具は、測定の手順を定めるときに選ぶ」の選択であり、この判断と理由を `tools/bench/README.md` に書く。

- `run.py` は、`bench_run`（呼び出しの回数の予算を変える実行では `--call-budget` を付ける）で `http.bnt` を起動し、標準出力の最初の行からポートを受け取る。それから、受け付ける要求の数（N）だけ要求をループバックの `127.0.0.1` へ送り、サーバのプロセスが終わるのを待って、`bench_run` の統計行（標準エラー出力）を読む。時間切れや失敗のときは、サーバのプロセスを止めてから誤りを報告する。
- 応答までの時間は、要求ごとに送る直前と応答を読み終えた直後を、マイクロ秒より細かい分解能の時計（`time.perf_counter_ns` など）で測る。要求の処理の量は、最初の要求を送ってから最後の応答を受け取るまでの時間と N から求める。中央値と最大は、すべての要求の応答までの時間から求める。
- 同時に要求を送るクライアントの数（例: 1 と 8）は、`run.py` の引数か `BENCH_INPUTS` の http の項目で決める。クライアントは Python の標準ライブラリ（`http.client`・`socket` と `threading` など）で書き、外部の道具（`wrk` など）を加えない。ほかの道具を使う形は、本測定のときに設計者と決める。
- 計算を続けるタスクの有無の二つの形と、クライアントの数の組ごとに記録する（07-02「要求の処理の量と待ち時間」）。

### run.py の直し

- `rust_missing`（`run.py` の 267 行付近）は `NAMES` の名前の release バイナリしか確かめない。map を `COMPARABLE_ADDITIONS` に入れると、map のない古い `rust/target` が残っている環境で、Rust が比較対象に入ったまま map のバイナリを呼んで、`--verify` が例外で止まる。`rust_missing` は、追加のベンチマークを走らせるとき（`additions` のとき）は `NAMES + COMPARABLE_ADDITIONS` の名前で確かめるように直す（後回しの項目 67 の前半）。
- `bench_sample` は `run_process` を標準出力を捨てる形で呼び、`measure_first_release` は並行処理の測定で tasks だけを回す。http の測定に要るなら、これらは `run.py` の中で直してよい（ポートを読むための標準出力の受け取り、http の測定の追加）。
- `--quick` と `--verify` で使う http の小さな入力は、`.args.small` を置かない代わりに `run.py` の中に持つ。`--verify` では、`http.bnt` の `benitoite check` も行う。

### BENCH_INPUTS の値

- `BENCH_INPUTS` の map と http の値は仮の値として置く。目標の時間（1〜10 秒）の 1/100〜1/10 の規模でまず時間を測り、それから見積もった値を置く。見積もりの計算と、測った時間を完了の報告に書く。
- 1〜10 秒への調整と、ほかの仮の値（後回しの項目 67 の後半: tasks・cycle・handler-saved）の直しは、本測定のときに行う。本作業では行わない。

## 受け入れテスト

- `run.py` で map と http を小さな入力で一回ずつ動かし、記録の雛形に値が入る。
- map の各比較対象の出力が、Benitoite の出力と一致する。
- http の二つの形（計算を続けるタスクの有無）で、すべての要求に応答が返る。
- `.args.small` の map が差分テスト（C10）で参照インタプリタと同じ結果になる。`http` に `.args.small` がない。

## 完了条件

- `scripts/check.sh` が通る
- 上のファイルがあり、`tools/bench/README.md` に使い方が書かれている
- `src/` を変えていない

## 確認の観点

- ベンチマークのプログラムが、07-02 の表の「何を測るか」に合っているか（map は平衡二分木の更新と探索、http はイベントループと待つタスクの切り替え）。
- 比較対象が同じ処理を行っているか（同じ数の操作、同じ鍵の列）。

## 難易度の理由

C16 が作った道具の形に二つのベンチマークを加えるだけであり、判断は要求を送る側の形に限られる。
