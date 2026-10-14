# 作業 V6d のレビュー

- 対象: コミット `62157b9e`（`cli/mod.rs`・`cli/wasm.rs`・`cli/tools.rs`・`cli/tools/args.rs`・`test_runner/mod.rs`、`external/runtime.rs`・`stats.rs`・`typed.rs`・`convert.rs`、`runtime/run.rs`・`vm/`、`examples/wasm_cost.rs`、`tools/bench/wasm_bench.py`・`README.md`・`wasm/regex-*.bnt`、02-09・03-10・06-01・リファレンス・CHANGELOG）。
- 根拠: `decisions.md`（Q12〜Q14、R12、R13）、`plan.md`（作業 V6d、凍結の表）、`reviews/2026-10-13-V6c/report.md`、スキル benchmark、`tools/bench/README.md`、AGENTS.md、test-audit、実装担当の報告。
- 方法: `git show` でコードを読み、Wasmtime 49.0.2 のソース（`component/values.rs`・`func/options.rs`・`func/typed.rs`・`store.rs`）と突き合わせた。cargo・python は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

CLI の引数と値の受け渡しは R12 のとおりで、三つの経路と `test` の各 VM に同じ値が渡り、上限の意味も変わっていない。戻り値の受け渡しの量は Wasmtime 49.0.2 の `consume_fuel` の規則と一致する数え方になっている（UTF-16 の文字列では一致しない。R13 の「同じ規則で数える」を UTF-8 の場合に限ることは、設計者の了承が要る）。報告は、正常終了・誤り・中断・`Process.exit`・test の失敗のどの場合も一行だけ出て、指定しないときの出力は変わらない。High 1 件、Medium 1 件、Low 9 件。

## 指摘

### H1（High）計時する実行にも `--wasm-stats` を付けるので、C の時間に集計の費用が入る

- 場所: `tools/bench/wasm_bench.py:149`（`flags = ["--wasm-stats"]`）。
- 問題: 外部の関数を呼ぶのは C だけなので、集計の費用（関数名の String の確保と BTreeMap の探索、`get_fuel()`、動的な経路での戻り値の木の再走査）は C の時間にだけ入り、比較が C に不利な向きにずれる。単純な呼び出しで約 6.7 %（90→96 ms）増える。TODO-232 の呼び出し一回の費用そのものが偏る。
- 修正案: 計時の前の一回だけの検証の実行にだけ `--wasm-stats` を付け、その報告を組の記録に写す。較正と計時の標本では付けない。`record` は `get_mut` を先に試して確保を減らす。V8 の短い試行で、統計なしの経路を改造の前のバイナリ（`00e4fc49`）と比べる。

### M1（Medium）R0904・R0905 の説明が「固定の上限」のまま残り、上限を変えられることを示さない

- 修正案: 説明を「既定では … 実行する利用者が `--wasm-memory`・`--wasm-transfer`・`--wasm-fuel` で変えられる」の形に直す（LLM に上げるよう促す文にはしない）。R0905 の `linear_memory` の注記「per call」を、状態を持つインスタンスの寿命の合計にも合う形に直す。`gen_skill` で作り直す。

### L1（Low）使い方の文（`text::USAGE`）の桁がずれ、範囲も書いていない

### L2（Low）範囲の外の誤りの文言が、許す範囲を示さない

- 修正案: 範囲を示す型板（1MiB〜4GiB、燃料は 1〜18446744073709551615）を `cli::text` に加える。値のない指定で空の逆引用符が出ないようにする。

### L3（Low）ほかの章の記述が、上限を変えられることに追いついていない

- 00-04「燃料」、リファレンス 1085 行付近の「two 256 MiB host representations plus up to 64 MiB」、02-09 355 行付近の「既定」の差し込み、06-01 204 行（`run` の標準エラー出力の一覧に `--wasm-stats` の行）と 220 行（`Process.exit` の後も報告の行を書くこと）。

### L4（Low）関数ごとの集計の鍵が関数名だけで、`test` で複数のファイルの同名の関数が混ざる

- 修正案: 鍵にコンポーネントの表示名を含めるか、03-10 に「同じ名前は合算する」と書く。

### L5（Low）`reached_limits` の名前を、文言の定数の文字列で照合している

- 修正案: 資源の種類から決め、知らない名前は `Stop::Internal` にする。

### L6（Low）計時の途中で回数を較正し直すと、反復数の違う標本が一つの要約に混ざる。要約に反復数もない

- 修正案: 較正し直したら既存の標本を捨てて取り直すか、計時の前に較正を済ませる。`summary` に反復数を残す。

### L7（Low）テストの穴

- `test` の失敗のときの `--wasm-stats` の報告、状態を持つインスタンスが変えた `--wasm-memory` を寿命の合計に当てること、関数ごとの `reached_limits` を、既存のテストの一ケースとして足す。

### L8（Low）`WasmOptions`・`Limits` の公開の欄から、検査していない値を渡せる

- 修正案: 欄を `pub(crate)` にして読み出しの関数だけを公開するか、了承の範囲として残すなら 02-09 にこの経路を一文書く。

### L9（Low）ビルドの機能を自由な文字列で記録している

- 修正案: README に「`--benitoite` を変えたら `--build-features` も指定する」と書く。

## 確かめて問題がなかった点

- 引数の解析（単位、範囲、重複、`check`・`fmt` での拒否、`run` のパスより後の引数をスクリプトに渡すこと、終了状態 2）。
- 値の受け渡し（`RunState` を通って最初の外部の呼び出しで実行系に渡る、三つの経路で共通、`test` は `Rc` を共有する集計、参照インタプリタと埋め込みは既定の値、大域の状態なし）。
- 上限の意味（状態を持つインスタンスの寿命の合計）、燃料の `u64::MAX`。
- 戻り値の数え方は Wasmtime の規則と一致する。報告の時期と一行だけ出ること。指定しないときは集計を作らず、ゴールデンの作り直しは 0 件。
- 凍結の型は `Command::Run` の欄だけ。道具の V6c の指摘（較正、k 回の起動と回転、中央値と最小値、機械の記録、Markdown の欄、見込みの時間、合成したコンポーネント、Regex の find-all、C の浮動小数点数、期限切れ、`--probe`、README）は意図どおり。
