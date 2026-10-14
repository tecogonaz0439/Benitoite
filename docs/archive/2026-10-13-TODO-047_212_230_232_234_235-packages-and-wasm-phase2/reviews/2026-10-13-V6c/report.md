# 作業 V6c のレビュー

- 対象: コミット `9599b97d`。`tools/bench/wasm_bench.py`、`tools/bench/wasm/`（`Runner.bnt` と Json・Hash・Regex のプログラム 11 本）、`crates/benitoite/examples/wasm_cost.rs`、`tools/bench/README.md` の「WASM の比較」、ゴールデン `json-wasm-same`・`json-pure-same`・`json-pure-depth-array`・`json-pure-depth-object` と関係するパッケージの変更。
- 根拠: `decisions.md`（Q4、R6、R7、R11、Q12・R12）、`plan.md`、`reviews/preflight-V6V7.md`、`reviews/2026-10-13-V6a/report.md`（M1）、`reviews/2026-10-13-V6b/report.md`、`todo-items.md` の TODO-212・232・228、スキル `benchmark`、`tools/bench/README.md`・`run.py`、AGENTS.md、test-audit、実装担当の報告。
- 方法: `git show` でコードを読み、処理系の `src/external/runtime.rs`・`src/runtime/report.rs`・`src/diag/codes.rs`・`tools/bench/rss.py` と突き合わせた。cargo と python は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

道具の骨組みは計画どおりで、入力の生成は計時の外、測る前に A・B・C の出力の SHA-256 を比べ、R0905 の課題は記録して続ける。`wasm_cost.rs` は公開の API と依存の `wasmtime`・`wat` だけを使う。V6b の Low 4 件も扱っている。一方、測定の設計には TODO-212・232 の問いに答えられない箇所が残る。High 1 件、Medium 3 件、Low 7 件。

## 指摘

### H1（High）ミリ秒の時計と固定の 5 回では、1 KB の課題と空の Hash の呼び出しの費用が測れない

- 場所: `wasm_bench.py`（`--rounds` の既定 5 を全課題に一律に使う）、`tools/bench/wasm/Runner.bnt`（`Clock.monotonicMilliseconds` で `first_ms` と `rest_ms` を出す）。
- 問題: 1 KB の課題は数十マイクロ秒なので `rest_ms=0` になる。100 KB でも量子化の誤差が大きい。TODO-212 の 1 KB の段と、TODO-232 の呼び出し一回の費用（Benitoite の側）が得られない。
- 修正案: 反復の回数を課題と大きさごとに決める（`rest_ms` が 1 秒以上になるまで倍にしていく較正か、大きさごとの既定の表）。一回あたりの時間を記録する。

### M1（Medium）スキル `benchmark` と `tools/bench/README.md` の作法に合っていない

- 問題: 組ごとの標本が一つで中央値も最小値も取れない。A・B・C の交互の実行がない。機械の状態の記録（CPU、メモリ、`rustc --version`、コミット、機能）が足りない。`results/TEMPLATE.md` の形の Markdown を作らない。本測定の見込みの時間が README にない。
- 修正案: 計時するプロセスを組ごとに k 回起動し、回ごとに順を入れ替え、中央値と最小値を出す。`run.py` の `cpu_description` に倣って機械の情報を取り、コミットと `rustc` の版も記録する。V8 で使う Markdown の欄を README に書き、本測定の時間を見積もって書く。

### M2（Medium）B の `2^-24` の差は値の誤りで、`--quick` が通らないので V8 の前提が満たせない

- 問題: 正確な値は `5.9604644775390625e-8`。2 の冪なので下側の隣との間隔は上側の半分しかなく、B の `5.960464477539062e-8` を読み直すと下側の隣の値になる。最短表記の算法で 2 の冪の非対称な区間を扱い損ねた不具合であり、「書式の差」ではない。
- 修正案: V8 の前に B を直す（仮数が 2^52 ちょうどのときの下側の幅を半分にする）。README の記述を改める。

### M3（Medium）合成したコンポーネントが TODO-228 の「大きさごとのコンパイルの費用と最大 RSS」を代表しない

- 問題: 関数の本体が `nop` だけなので、命令の選択とレジスタの割り当ての費用を測れない。WAT の生成と符号化を同じプロセスで行うので、最大 RSS に生成の作業領域が入る。
- 修正案: 関数の本体を実際の命令の並び（局所変数、`i64` の算術、比較と分岐、呼び出し）にし、`nop` の形は対照として残す。生成とコンパイルを別のプロセスに分ける。小さい大きさでは数回の中央値も出す。

### L1（Low）Regex の count は A と C で仕事が違う

- 修正案: C の `findAll`・`findAllOnce` の長さを数える課題を足し、A の `findAll` と同じ仕事どうしで比べる。

### L2（Low）浮動小数点数の標本を A と B だけで比べ、C を比べていない

- 修正案: C も同じ標本で比べる。

### L3（Low）途中の失敗で残りの測定を捨てる箇所と、空の記録が残る箇所

- 修正案: 期限切れは `row["limit"] = "timeout"` として記録して続け、最後にまとめて失敗を返す。記録を作った後の `stat` を `try` の中に入れる。

### L4（Low）`wasm_cost` の `Store` が処理系の設定と違う

- 修正案: README を「処理系と同じ `engine_config()`。上限の数え方は処理系と違い、計測する関数はメモリを成長させない」と直す。`instantiate` に `Store` の作成を含むと書く。上限の定数が処理系の写しであることをコメントで書く（V6d で処理系の値を使う形にする）。

### L5（Low）ゴールデンの時間の余裕と、深い値の書き出しの確かめが常設でないこと

- 修正案: V8 の `check.sh` で `json-wasm-same` の時間（gc-stress で 8.67 秒）を記録し、9 秒を超えたら B の比較の行を減らす。作業列の書き方の守りが `--quick` だけにあることを README か docs/todo に残す。

### L6（Low）V6a の M1 への備えは記録の側だけで、10 MB の C の短い試行がまだない

- 修正案: V8 の本測定の前に、10 MB の C の `verify` と各課題の一回だけの短い試行を行い、R0905 になる課題を設計者に知らせる。V6d で、上限の引数と使った値の記録を道具に足す。

### L7（Low）README の細部

- 修正案: 「リポジトリの根で実行する」と一行足し、`fuel` と `fuzzy` の値の読み分けを一文足す。

## 確かめて問題がなかった点

- 入力の生成（固定の種、文字列の多いレコード、計時の外）。同じ結果の確かめ（計時の前の `verify` と SHA-256、R0905 の実装の区別）。
- 計時の範囲（出力のハッシュは計時の外、C のコンパイルは最初の呼び出しで `first_ms` に入る、10 MB の document は一プロセスに一つ、Hash の大きさは予算の計算と合う）。
- `wasm_cost.rs` は公開の API と依存だけを使い、unsafe・unwrap・panic はない。`OutOfFuel` の確かめと消費量の算出は正しい。
- V6b の指摘の扱い、`json-wasm-same` の比較の行と注文データ、道具の置き場所、記録の排他的な作成、浮動小数点数の標本の数（2 の冪 2,046 個、合計 2,185 個）。
