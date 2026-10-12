# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` と性能の短い測定は最後に一度だけ行う。設計書・言語リファレンス・CHANGELOG の未リリースの節は、各作業が同じ変更で直す。

## 作業 X1: Regex の照合のループ（TODO-201、TODO-185 の Regex の点）

内容（判断は `decisions.md` の Q1 と「推奨どおりとした問い」、詳細は `study-201.md` の 3.1 節・4 節・6 節の W1・W2）:

- `crates/benitoite/src/builtins/funcs/regex.rs` に非公開の組み込みの関数 `Regex.findAt`（捕獲グループつき、`captures_at`）と `Regex.spanAt`（範囲だけ、`find_at`）を加える。開始の位置を受け取り、直前の一致の後（`afterMatch`）で開始の位置ちょうどの空の一致を捨てて探し直す規則を、regex の反復と同じに Rust の中で行う。開始の位置が範囲の外か文字の境目でなければ `Stop::Internal`。入力を写さない。
- `findAll`・`replaceAll`・`split` の組み込みの関数を消し、`crates/benitoite/src/prelude/stdlib/Regex.bnt` のループ（末尾呼び出し）で `findAll`・`replaceAll`・`replaceAllWith`・`split` を書く。新しい宣言に `public` を付けない。置き換えの文字列は今のとおり展開せず、書いたとおりにつなぐ（03-08「Regex」）。結果の組み立てを 2 乗にしない。
- `Regex.compile` の誤りの文面を、4 KiB を超えたら切り詰める。
- 組み込みの表の数を固定するテストを直す。消した関数を直接呼ぶ単体テストを、スクリプトのテストかゴールデンテストに移し、今の期待値（`study-201.md` の 1.4 節）を保つ。`findAt`・`spanAt` の単体テストに、途中の位置からの `\b`・`^`（`(?m)`）と、空の一致の探し直し（多バイト文字の前後、入力の終わり）を含める。
- 中断の確かめ: `tests/interrupt_process.rs` に、病的な `findAll` の照合の途中で SIGINT を送ると 130 で終わるテストを足す。`Task.withTimeout` が照合を期限で取り消して `Option.None` を返すテストを足す。
- 文書: 03-08「Regex」、言語リファレンス、CHANGELOG（Fixed）。同梱の Skill の生成物を `gen_skill` で作り直す。

完了の条件: 上のテストが通る。`cargo test -p benitoite regex`、`--lib builtins::table`、`--test golden`、`--test skill_docs`、`--test reference_examples`、`--test interrupt_process`、clippy、fmt が通る。

## 作業 X2: 実行の終わりの中断の印（decisions.md の Q2）

内容（`study-201.md` の 3.2 節、6 節の W3）:

- `crates/benitoite/src/runtime/run.rs`（とテストの実行器の対応する箇所）で、`main` が値で終わった後、出力の最後の転送の前に中断の印を一度読み、立っていれば中断の要求として終了状態 130 で終わる。実行時エラーと資源の不足で止まったときは変えない。
- 長い純粋な組み込みの関数の途中で SIGINT を送り、その後に呼び出しを通らずに `main` が終わる場合に 130 になるテストを足す。
- 文書: 02-09「中断の要求」・「プログラムの実行の流れ」、07-03 の中断のテストの節、CHANGELOG（Fixed）。

完了の条件: `cargo test --test interrupt_process`、`--test test_command`、`--lib runtime::run`、clippy、fmt が通る。

## 作業 X3: HTTP サーバの細部（TODO-202）

内容（判断は `decisions.md` の Q3・Q4 と「推奨どおりとした問い」、詳細は `study-202.md` の 3 節・5 節）:

- 応答から除くヘッダを広げる（`connection` に挙げた名前を含む）。
- パスもクエリも空の `OPTIONS` の絶対形を `*` にする。
- 要求の対象が `#` を含めば 400 にする。
- `100-continue` の 100 を書き切れず、書き込みの準備を待つ経路を通るテストを、送りのバッファを埋める形で足す。
- 文書: 03-09、言語リファレンス、CHANGELOG（`#` の 400 は Incompatible changes、除くヘッダは Fixed）。

完了の条件: `cargo test -p benitoite --lib runtime::io::http`、`--test l30_http_server`、`--test l31_http_serve_and_helpers`、`--test golden`、clippy、fmt が通る。

## 最後に行うこと

1. `scripts/check.sh --base <改造を始めたコミット>`。走らせる前に `--dry-run` の結果と見込みの時間を設計者に知らせる。
2. 性能の短い測定: 一致の多い普通の入力で `Regex.findAll`・`replaceAll`・`split` の時間を、改造の前と後のビルドで交互に比べる（`study-201.md` の 3.1 節「遅れの見込み」）。記録は `tools/bench/results/`。VM は変えないので、07-02「性能の関門」の fib・loop は要らない見込みだが、X2 が実行の終わりを変えるので fib・loop も短く確かめる。
3. docs/todo: TODO-201・202 を閉じ、TODO-185 から `Regex` の点を除く。要求の対象の文法の検査を広げる項目を加える。
4. 本ディレクトリを `docs/archive/` へ移す。
