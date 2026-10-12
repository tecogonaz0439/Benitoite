# 実装プラン

`decisions.md` の「決まったこと」に従って実装する。実装は Codex（GPT-6.1-Sol、推論の度合い high）、レビューは Claude（Opus）が行う。

## 進め方（直列の試行）

- 作業は、メインの作業ディレクトリ（リポジトリの根）で一つずつ行う。git worktree は作らない。作業ごとに `san_benito` から作業のブランチ（`impl/cleanup-<作業>`）を作り、Codex がそこにコミットする。
- 作業ごとに確かめるのは、関係するテスト、`cargo clippy --workspace --all-targets`、`cargo fmt --check` だけである。TCP を開くテストは Codex のサンドボックスで動かないので、オーケストレータが手元で走らせる。
- Opus のレビューはコミットを読むだけにし、次の作業と並べてよい。レビューの指摘の直しは、次の作業を始める前に同じブランチで行う。
- 作業を終えたら `san_benito` に `--no-ff` で取り込み、次の作業のブランチをそこから作る。
- `scripts/check.sh`（基準は改造の前の版 8ca4d47）と性能の短い測定は、すべての作業を取り込んだ後に一度だけ走らせる。落ちたら作業を切り分けて直す。
- Codex が動いている間、オーケストレータはメインの作業ディレクトリのファイルを書き換えない（本ディレクトリの文書を除く）。Codex は docs/todo に触れない。

## 作業の順序

| 順 | 作業 | 内容 | 主に触るところ |
|---|---|---|---|
| 1 | S | TODO-175 のスタックの消費 | `syntax/parser/`、`resolve/`、`typeck/`、`ir/desugar/`、`ir/decision.rs`、`bytecode/codegen/`、`pipeline.rs`、`cli/tools/formatter/`、`examples/stack_probe.rs` |
| 2 | R | TODO-180 の小さな誤り | `vm/`、`runtime/io/`、`runtime/heap/stats.rs`・`core/mark_sweep.rs`、`runtime/run.rs`、`builtins/funcs/random.rs` |
| 3 | C1 | TODO-174 の構造の片付けと第 1 段の退役 | `vm/stage1.rs`、`lib.rs`、`builtins/funcs/stage1_io.rs`、`examples/stage1_*`、`tools/bench/`、`runtime/heap/stats.rs`・`value.rs`、`bytecode/instr.rs`、AGENTS.md |
| 4 | C2a | TODO-174 のコメントの書き換え（`builtins/`・`runtime/`） | コメントだけ |
| 5 | C2b | TODO-174 のコメントの書き換え（残りのモジュールとテスト） | コメントだけ |
| 6 | D | 設計書・AGENTS.md・CHANGELOG への反映 | `docs/design/`、`AGENTS.md`、`CHANGELOG.md` |

コメントの書き換え（C2a・C2b）を最後に置くのは、全ファイルに広く触れるからである。先の作業 S・R・C1 は、新しく書くコメントに実装プランや作業の ID を引かない。

## 作業 S（TODO-175）

1. 測る道具を先に作る: `crates/benitoite/examples/stack_probe.rs`。構文の形・深さ・スタックの大きさ・段（parse・check・desugar・lower・codegen・all）を受け取り、指定の大きさのスレッドで、段を `on_large_stack` を通さずに順に行う。駆動する側が子のプロセスとして起こし、溢れない最小のスタックを二分探索する（駆動は同じ例の別の動き方でも、`tools/` の Python でもよい）。深さ N/2 と N の差から 1 段あたりのバイト数を出す。
2. 直す前に、debug と `--release` で、`study-175.md` の 4.4 の形（平らな文、リストの要素、呼び出しの引数、レコードのフィールド、`if` と `else if`、match の本体、ガード付きの分岐の並び、二項演算子、レコード式の入れ子と更新元、ラムダ、`with`・`lazy`・`handle`、単項、括弧、入れ子のリスト、型注釈）を測り、段ごとの値を記録する。
3. 直す: `study-175.md` の 3 章のとおり、再帰の振り分けの関数の大きな分岐を `#[inline(never)]` の補助の関数に分ける。診断の組み立てなど再帰の経路にない重い処理は `#[cold]` と `#[inline(never)]` の関数に出す。判定の木の `comp` は Let の本体の連なりをループで下る（Q7 の案 B）。整形も段のスレッドで行う（Q8）。補助の関数のコメントには、理由と設計書の節（02-01「関数の呼び出しと処理系のスタック」）を書く。
4. 直した後に同じ形を測る。debug で 2 MiB に収まれば、テストを 2 MiB にする。収まらない段が残れば、Q7 の案 C（脱糖の `statements`・コード生成の `let_` もループにする）を試し、それでも残れば値を記録して報告する（4 MiB を認めるかを設計者に尋ねる）。
5. 回帰テスト: `pipeline.rs` の `mod tests` に、明示した大きさのスレッドで構文解析からコード生成までを行い、結果をスレッドの中で捨てるテストを置く。深さは入れ子の上限（`syntax::parser::MAX_DEPTH`）ちょうどに置く。10 秒を超えるものは `#[ignore = "long: ..."]` にする。
6. `scripts/check.sh` の `--full` に、小さいスタックのテストを `--release` で走らせる段を加える（Q6）。
7. 測った値（直す前と後、debug と release）を、`stack-measurements.md` として本ディレクトリに置けるよう報告に書く。

完了の条件: 新しいテストが debug と `--release` の両方で通る。構文解析・型検査・IR・コード生成のテストが通る。clippy と fmt が通る。

## 作業 R（TODO-180）

`decisions.md` の Q9〜Q11 の「直す点」を行う。

1. `USE` が呼び出しの深さの上限で止まるときも解放の枠を積んでから止める。再現テスト（`vm/dispatch/resource/tests.rs`）で、直す前に書いた内容が捨てられ、直した後に書き出されることを確かめる。
2. セルの更新の呼び直しの呼び出し位置: 再現テスト（trace の更新の関数の段が `Reference.update` の行を指す）を先に書き、`CellUpdate` に UPDATE の位置の欄を加えて直す。
3. poll の失敗が続けて 1,000 回に達したら、`IdleWake` の失敗の値を返し、VM が処理系の不具合（`Stop::Internal`）にする（Q10）。計数の判定を小さな関数に分けて単体テストで確かめる。
4. 書き出し用のスレッドを起こせないときは、実行の前に処理系の不具合として止める（Q9、終了状態 3）。
5. 回収の停止時間の並びは `HeapConfig` の印を立てたときだけ記録し、件数・合計・最大はいつも保つ。`bench_run` は印を立てる。
6. 起動の履歴を、親へのつながりを持つ共有の鎖にする。深い鎖で失敗したときの `taskOrigins` の段の数と順序を確かめるテストを置く。直す前と後に、鎖の深さを変えて時間と最大の常駐メモリを一度だけ測り、報告に書く。
7. 小さな点: `poll_outputs` の頭で取り消しを反映する。`FORCE` の確かめを `host_mut` の前へ移す。`resume` の二段を一段にする。sched のテストのモジュールを末尾へ移す。lazy のテストに確かめを足す。乱数の種の計算を runtime の側へ移し、getrandom の失敗をスレッドを起こす前に確かめる。

完了の条件: 足したテストと、`vm`・`runtime`・`builtins` のテストが通る。`runtime::heap` を変えるので、`--features heap-verify` と `gc-stress` でも関係するテストが通る。clippy と fmt が通る。

## 作業 C1（TODO-174 の構造の片付け）

1. `vm/stage1.rs` と `pub mod stage1;` を消す。
2. `lib.rs` の `#![allow(dead_code)]` と理由のコメントを消す。出た警告は、使われない非公開の補助を消す、テストだけが使う項目を `#[cfg(test)]` にする、の順で直す。既定・`gc-mark-sweep,alloc-stats`・`gc-stress`・`heap-verify`・`heap-per-object`・`heap-verify,heap-per-object`・`bundled-licenses`・release の各組み合わせで `cargo clippy --all-targets` を通す。
3. 第 1 段の退役（Q2 の A）: `examples/stage1_bench.rs`・`stage1_heap_bench.rs`・`stage1_support/`、`tools/bench/stage1.py`・`remeasure.py`・`secb6.py`、`tools/bench/programs/stage1/`、`Opcode::in_stage1`、`FieldsKind::ListCell`、`HeapStats` の参照カウントの欄（`rc_increments`・`rc_decrements`・`rc_elided`・`reuses`）を消す。性能の関門の道具 `tools/bench/gate.py` は `bench_run` を使う形に改め、実行の段の時間（`run_nanos`）と経過時間を記録する。最小実行版の VM と比べる `--legacy` は残す。`tools/bench/README.md` を直す。`tools/bench/results/` の過去の記録は直さない。
4. `builtins/funcs/stage1_io.rs` を `fixed_io.rs` の `#[cfg(test)] pub(crate) mod` にし、`TestIo` を `FixedIo` に改める。`RealIo`・`Output` とそのテストは消す。`Stage1StateServices` を `#[cfg(test)]` にし、名前から Stage1 を外す。
5. 到達しない分岐（`syntax/parser/exprs.rs` の `else if p.at(TokenKind::Comma)`）を消す。`syntax/parser/traits.rs` の `all_standard_library_sources_parse_as_prelude` を、`crate::prelude::STDLIB` を回す形に書き換え、`items.rs` の `stdlib_modules_without_f04_syntax_parse_as_prelude` と一つにまとめる。`typeck/effects/tests.rs` の `entry_effects_and_uses_duplicates` を、実際のエフェクトの名前（`Assert.Check`・`Http.Connect`・`Http.Listen`）を書くソースに直す。
6. `testdata/C05-SWITCHOVER.md` を本ディレクトリへ `git mv` する。
7. AGENTS.md の `#[allow]` の表: `src/lib.rs` の行を消す。`BENITOITE_DEV_PANIC` の行を今の場所（`src/cli/mod.rs` と IO 実行器の `src/runtime/io/services.rs`）に直す。テストのモジュールの行を Q3 の A のとおりに改める。

完了の条件: 上の機能の組み合わせで clippy が通る。テストが通る。`python3 tools/bench/gate.py` を短い回数で一度動かし、出力を確かめる。

## 作業 C2a・C2b（TODO-174 のコメントの書き換え）

`src/` と `tests/` のコメントで、保管した実装プラン（`実装プラン nn-nn`、`10-xx`、`00-0x`）や作業の ID（R・F・L・D・C・U と 2 桁の番号）を引くもの、作業の途中の状態を述べるもの（「仮の本体」「後の作業」「担当」「U4 が書く」など）を、すべて直す（Q1）。

- 根拠の節が設計書にあれば、`（設計書 02-08「実行の手順」）` の形の引用に置き換える。設計書の見出しは、実際にある見出しだけを引く（`git grep` で確かめる）。
- 00-02 を引くものは「AGENTS.md「実装の規約」の「…」」の形にする。
- 「部分と番号」の定型文は、「番号は表の位置で決まるので、末尾以外に加えない」の趣旨の自足した文にする。
- 経緯だけを述べ今のコードを説明しないものは消す。今のコードの理由を述べているものは、作業の ID を外して理由だけを残す。
- テストの「テストの失敗は panic で表す（実装プラン 00-02…）」の定型文は、「テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。」に揃える。
- コードは変えない（コメントだけ）。

C2a は `src/builtins/` と `src/runtime/`、C2b はそれ以外の `src/` と `tests/` を受け持つ。終えたときに、`git grep -nE '実装プラン|\b(10|00)-[0-9]{2}\b|\b[RFLDCU][0-9]{2}\b' crates/benitoite/src crates/benitoite/tests` の残りを報告し、残したものには理由を添える（設計書の章の番号 `02-08` などは対象外）。

完了の条件: `cargo build --all-targets` と clippy と fmt が通る（コメントだけの変更なので、テストは最後の検査に任せる）。

## 作業 D（設計書などへの反映）

オーケストレータが行う。

- 02-01「関数の呼び出しと処理系のスタック」: 再帰の振り分けの関数の書き方、Let の連なりのループ、小さいスタックのテスト、整形を段のスレッドで行うこと。
- 02-08「呼び出しの入れ子の上限」「リソースの解放の枠」: `USE` が上限を超えるときの扱い。
- 02-09「IO 実行器」「出力のバッファ」「プログラムの実行の流れ」: poll の失敗の扱い、書き出し用のスレッドの起動の失敗。
- 06-03 の整形の流れ、07-02「測る項目」と「性能の関門」（`gate.py` が `bench_run` を使うこと、停止時間の並び）、07-03「実装の規約と静的な検査」（小さいスタックのテストと release での実行）。
- AGENTS.md「再帰の深さ」と「コメントと名前」。
- CHANGELOG の未リリースの節。

## 最後の検査

すべての作業を取り込み、D を終えた後に、オーケストレータが次を走らせる。走らせる前に、選ばれる検査と見込みの時間を設計者に知らせる。

- `scripts/check.sh --base 8ca4d47`（`runtime::heap` を変えるので `check-heap.sh` を含む）。
- 小さいスタックのテストを `--release` で一度。
- 性能の短い測定（fib と loop、基準 8ca4d47 と交互に）。
