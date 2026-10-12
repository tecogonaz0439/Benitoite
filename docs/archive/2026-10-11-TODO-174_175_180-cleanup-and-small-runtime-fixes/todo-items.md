# 扱う TODO の項目（docs/todo からの写し、2026-10-11 の時点）

### TODO-174 初回リリース版の実装の後片付け（移行の締め、古いコメント、実装プランへの参照）

- 状態: 方針あり
- 出どころ: [初回リリース版の実装プランの完了後の作業](../archive/2026-10-09-implement-first-release/90-after-completion.md)（「移行の締めの残り」）、[later-issues の 14・31・39・45](sources/later-issues.md)、[取り込み漏れの調査の B-1](sources/2026-10-09-todo-gap/B-implement-archive.md)、[取り込み漏れの調査の D-1・D-2](sources/2026-10-09-todo-gap/D-repo-code-and-tools.md)

- 移行の締めの残り（取り込み漏れの調査の B-1・D-1）。作業 C18 が U1・U2 の後に回した次の三つを、まだ行っていない。(1) `crates/benitoite/src/vm/stage1.rs`（`//!` だけのモジュール。1〜2 行目が「U1・U2 の終了後に取り除く」と書く）と、`src/vm/mod.rs:8` の `pub mod stage1;` とその `///` を消す。(2) `src/lib.rs:7` の `#![allow(dead_code)]` とその理由のコメントを外し、出た警告の項目を消すか直す。どこからも使われない非公開の補助は消し、残す項目は許可を残すか項目を直すかを決めて記録する。(3) AGENTS.md の「`#[allow]` を書いてよい箇所」の表から、`src/lib.rs` の `dead_code` の行（「C01 で置き、U1・U2 を終えた後に外す」。今は事実と合わない）を消す。あわせて、どこからも使われない `builtins/funcs/stage1_io.rs` の `RealIo`（とその `Output`。1〜2 行目は「R26 が 10-10 の IoRuntime に置き換えて消す」と書く）を消し、テストと参照インタプリタのテストが使う `TestIo` の置き場所と名前を見直す。
- 作業の途中の状態を述べるコメントと、保管した実装プランへの参照（取り込み漏れの調査の D-2）。作業を終えた後も、仮の本体、担当の作業、後の作業が書き換える、と述べるコメントが残り、今のコードを説明していない。例は `builtins/funcs/{boolean,character,float,list,string,traits}.rs:2-3`（「仮の本体は、後の作業が本体と Rust の引数型だけを書き換える」。どれも本体を書き終えている）、`syntax/parser/mod.rs:10-57`（F03・F04 のフックの「仮の本体」と「担当」の表）、`typeck/mod.rs:8`、`builtins/funcs/time/tests.rs:11`（「未実装の Time」）、`syntax/parser/items.rs:177・675・850`、`exprs.rs:1017` などである。また、`src` のコメントが `docs/archive/` に移した実装プランの節（R26、F03、10-12 など）を根拠として指す箇所が約 725 ある。AGENTS.md の「コメントは設計書の章と節を示す」と「archive は現在の作業の根拠にしない」に合わない。古い記述を直すか消すか、実装プランへの参照を設計書の節へ置き換えるか残すかを、TODO-006（次の版の実装プランと規約の置き場所）とあわせて決める。
- bytecode の検証器の古いコメント（later-issues の 45）。`src/bytecode/mod.rs:3` は `verify.rs` を「読み込みのときの検証器」と書き、`src/bytecode/verify.rs:23` は「R32 の評価に使う」と書く。ADR 0315 の後、検証器はテストでコード生成の出力を確かめる道具であり、本番の読み込みの経路からは呼ばない（AGENTS.md「失敗を panic で表さない」）。コメントを今の用途に直す。関連: TODO-035。
- `typeck/effects/tests.rs:411` の「未提供の Assert と Network のソースの代わりに」のコメントが古い（later-issues の 31）。`prelude/stdlib/Assert.bnt` と `Network/Http.bnt` は今はある。コメントとテストの組み立てを見直す。
- `ir/desugar.rs:354` の `#[allow(clippy::panic)]`（later-issues の 14 の (a)）。この属性は `#[cfg(test)] pub(crate) mod test_support` に付いており、AGENTS.md の表の「テストのモジュール（`#[cfg(test)] mod tests`）」に当たるかを確かめる。当たらなければ、`let ... else` と `assert!` で書き直して許可を消す。
- 第 1 段の測定の道具 `tools/bench/stage1.py` を退役させて消す（later-issues の 39）。入力（28 行の shared=16 など）は回収 0 回で、roots・live の負荷も弱く、`write_report`（201〜253 行）は本測定でも雛形の固定文（「本測定後に埋める」など）を出す。値の表現と回収の方式を確定したので、第 1 段の比較に使う場面はないと設計者が決めた。
### TODO-175 処理系の段のスタックの消費（最適化したビルドと小さいスタック）

- 状態: 方針あり
- 出どころ: [later-issues の 20・F03・119・121](sources/later-issues.md)（20 は調査結果を含む）、[取り込み漏れの調査の C-11](sources/2026-10-09-todo-gap/C-orch-notes-and-memory.md)、[ADR 0087](../archive/2026-10-09-design-first-release/decisions/0087-pipeline-stages-on-large-stack-thread.md)（決定 3）

構文解析・脱糖・判定の木への変換などの段は、AST と中間表現を再帰で辿り、1 段あたりのスタックの消費が大きい関数がある。本番の経路は段を 64 MiB のスレッドで動かす（`pipeline::on_large_stack`）ので、利用者に害は見つかっていない。しかし、最適化したビルドや既定の大きさのスレッドで動かすテストと補助の関数では、構文の入れ子の上限（1000）の内側で溢れる。方針は ADR 0087 の決定 3 のとおり、大きな分岐を `#[inline(never)]` の補助の関数に分けて 1 段の枠を小さくすることである。

- 判定の木への変換と脱糖の 1 段が大きい（later-issues の 20 と、その調査結果）。最も重いのは `ir/decision.rs` の `Lowerer::comp`（debug のビルドで 1 段 19.6 KB）と、脱糖の `if_expr` で、上限 1000 の入れ子に debug のビルドで約 19 MiB 要る。`comp`（`decision.rs:198`）は一つの大きな `match` のままで、`ir/decision.rs` と `ir/desugar/` に `#[inline(never)]` は一つもない。`comp`・`match_comp`・`emit`・`leaf`・`if_expr` の大きな分岐を補助の関数に分け、run の経路を 2〜4 MiB のスタックで上限近くまで通す回帰テストを置く。今は小さいスタックで通すテストがない（`pipeline.rs:574` は check だけ、`decision.rs:3143` は 64 段。`stack_size` を指定するのは `pipeline.rs:225` とゴールデンテストの `STAGE_STACK_BYTES` だけ）。
- 構文解析の `parse_leaf` から分けた補助の関数（`parse_literal_or_error`・`parse_foreign_lambda`・`finish_name`。`crates/benitoite/src/syntax/parser/exprs.rs:325,345,364`）に `#[inline(never)]` が付いていない（later-issues の F03。`exprs.rs` に `inline(never)` は 0 個）。release や opt-level 1・2 でインライン展開されると、深いレコード式でスタックが溢れうる。補助の関数に `#[inline(never)]` を付けるか、最適化したビルドで深さの境界のテストを走らせる。次の事項と同じ原因である。
- opt-level 1・2 でビルドしたテストで、`syntax/parser/records.rs:440` の `records_obey_sequence_and_recursive_depth_limits` が既定のスタックを溢れる（later-issues の 121）。check.sh の既定の test のプロファイルでは落ちない。インライン展開で枠が膨らむ関数を調べ、1 段あたりの消費を絞る。
- フォーマッタ（`cli/tools/formatter`）は、構文解析を `pipeline::on_large_stack` で動かしていない（later-issues の 119）。check・run・test は使っている（`pipeline.rs:123・184・204`、`cli/mod.rs:490`、`cli/tools/test_runner/mod.rs:325`）ので、深い入れ子でのスタックの余裕が揃わない。
- テスト用の補助の関数が、深い入れ子で既定のスレッドを溢れる（取り込み漏れの調査の C-11）。match の本体を 300 段入れ子にすると `resolve::test_support::resolve_files` で溢れ（作業 F10 の報告）、`if` を 192 段入れ子にすると読み込みから脱糖までが 2 MiB のスレッドで溢れた（作業 F18 の記録）。どの段で溢れるかと、実装の規約の「スレッドのスタックの大きさを変えてテストを通さない」（AGENTS.md「再帰の深さ」）との関係を確かめる。

### TODO-180 VM とランタイムの小さな誤りと整理

- 状態: 未着手
- 出どころ: [later-issues の 40・46・48・49・50・52・59・60・84](sources/later-issues.md)

VM とランタイムの作業の確認で残した、不具合の疑いと小さな整理の点をまとめる。性能だけの点は TODO-035・TODO-031 で扱う。

- `pop_call` の片付けが、窓の範囲だけを clear し、残りを truncate で落とす（later-issues の 40）。`crates/benitoite/src/vm/dispatch.rs:1757-1778` の `pop_call` は `base..end` だけを `ctx.clear` し、`regs.truncate(base)` で残りを落とす。不具合の経路で「最も上の枠の終わり = `regs.len()`」が崩れると、片付けない Slot が出る。マーク・スイープでは観測できず、参照カウントを採らない限り実害は小さい（要確認）。
- 作業 R20 の確認で残した点（later-issues の 46 の (b)(c)。(a) は TODO-035）。(b) `fail_instruction`（`src/vm/dispatch/handlers.rs:162-179`）の作りが変わり、save_next の後の失敗で止まったときの記録の pc がどうなるかは、読んだだけでは確かめられなかった（要確認）。(c) handlers の find 系（L4・L6）を R21・R24 で見直すという申し送りが果たされたかは、記録がなく確かめられない（要確認）。
- 作業 R21 の確認で残した巻き戻しの点（later-issues の 48 の (a)(b)(d)。(c) は TODO-035）。(a) `clear_dead_registers` は Escaping のとき関数全体から早く返り、下の区画の分類済みの枠も整理しない（`src/vm/dispatch.rs:344-348`。保持が多くなるだけ）。(b) `resume` から `resume_return` への冷たい呼び出しが二段のままである（`src/vm/dispatch/unwinding.rs:9-18`、`src/vm/dispatch/handlers.rs:136-138`）。(d) `continue_return` の Traverse の分岐で空の区画を降ろす確かめを通らない点と、`unwinding/tests.rs` の `next_frame` が順序だけを確かめる点は、確かめられなかった（要確認）。
- 作業 R24 の確認で残した点（later-issues の 49）。(a) `src/runtime/sched/mod.rs:26-44` のテストのモジュールが `Waiting` と `Scheduler` の間にあるので、末尾へ移す。(b) `src/vm/unwind.rs:165` が、解放の状態によらず `new_ext_op_id` を消費する（実害なし）。(c) `USE` が呼び出しの深さの上限で止まると（`src/vm/dispatch/resource.rs:28-33`）、開いたリソースは解放の枠に入らず、実行の終わりに黙って閉じるだけになる。`FileWriter` ではバッファの書き出しが失われうる。02-08 は資源の不足で止めることだけを定め、そのときのリソースの扱いを定めていないので、扱いを決めて設計書に書く。関連: TODO-168。
- 作業 R22 の確認で残した `Lazy` の点（later-issues の 50）。(a) `FORCE` で `host_mut` により `Evaluating` にした後に、失敗しうる処理（`calls.last_mut()` の `ok_or_else`、`index(end)?`）が残る（`src/vm/dispatch/lazy.rs:141-168`）。不具合のときだけ、update の枠のない `Evaluating` が残る。確かめを `host_mut` の前へ移す。(b) `closure_value` に `#[inline(never)]` が付いており、CLOSURE の経路の呼び出しが一段多い（`src/vm/dispatch.rs:1025-1026`）。(c) `lazy/tests.rs` は、二度目の FORCE の後に `Done` のままであることを確かめていない（`src/vm/dispatch/lazy/tests.rs:185-204`）。
- セルの更新の呼び直しの呼び出し位置（later-issues の 52。要再現）。`retry` は `ReturnWork::at`（呼ばれた関数の RETURN）を `push_call` の呼び出し位置に渡す（`src/vm/dispatch/cell.rs:174`・`211`）ので、止まったときの記録の呼び出し位置が UPDATE の命令でなくなる。実行時エラーの報告の trace に出るかを再現テストで確かめてから、呼び出し位置を UPDATE の命令（更新の枠から引く）に直す。
- OS の待ち（poll）が失敗し続けても、不具合として報告されない（later-issues の 59 の 3 点目）。`src/runtime/io/event.rs:203-208` は、poll の失敗（EINTR 以外）のとき 1 ミリ秒眠って Progress を返すだけで、失敗が続いても VM は 1 ミリ秒ごとに戻る動きを続ける。凍結した戻り値（`IdleWake`）が IO の失敗を返せないためである。戻り値の形を変えて、続く失敗を処理系の不具合として報告する。
- 同じ境界の中で取り消されたタスクの、預けた書き込みが出力されうる（later-issues の 60。要再現）。`OutputPort::poll`（`src/runtime/io/output.rs:162-`）は、タスクの待ちを確かめる前に預けた書き込み（deferred）を受け付ける。`poll_outputs`（`src/vm/dispatch/tasks/io.rs:537-545`）は境界の終わり（同 708 行）で呼ばれ、頭で `reflect_cancellation` を呼ばない。境界の頭（同 601 行）の `reflect_cancellation` の後に取り消しが起きる経路で、取り消したタスクの書き込みが出力される余地がある。再現テストで確かめてから、`poll_outputs` の頭で `reflect_cancellation` を呼ぶ。関連: TODO-025。
- 書き出し用のスレッドの起動の失敗を、書き込みの失敗（`WriteFailure::Io`、R0201）として報告する（later-issues の 60）。`src/runtime/io/output.rs:83-91` は `Builder::spawn` の失敗を `WriteFailure::Io` にする。資源の不足か処理系の不具合かを決めて、報告を改める。
- 隠れた乱数の種を入れる処理の層の向きと、getrandom の失敗の終了の順（later-issues の 84）。`runtime/run.rs:278-279` の `seed_hidden_random` が `crate::builtins::funcs::random::seeded_state` を呼び、runtime が builtins に依存する向きになっている。xoshiro256** の一歩が `builtins/funcs/random.rs:27-32` と `runtime/io/services.rs:159-164` に重複している。getrandom が失敗したときの早期の終了（`run.rs:268`）は、出力の口の起動（`run.rs:231-240`）と `IoRuntime::new`（`run.rs:259`）の後にある。runtime の側に乱数の小さなモジュールを置き、種の取得を出力の口の起動の前へ移す案がある。
- 2026-10-10 の外部のセキュリティのレビュー（[外部のセキュリティのレビュー](sources/2026-10-10-security-review/README.md) の「その他の監査結果と分類」）が挙げた小さな点。(a) 回収の停止時間の記録 `pause_nanos: Vec<u64>`（`src/runtime/heap/stats.rs`）に、回収のたびに無条件に足す（`src/runtime/heap/core/mark_sweep.rs`）ので、長く動くサーバで記録が伸び続ける。増え方は回収 1 回に 8 バイトと小さい。固定の大きさの輪のバッファ、度数分布、合計と最大だけにする、測るときだけ記録する、のどれかにする。(b) 深いタスクの起動で、起動の履歴（SpawnHistory）を祖先ごとに写すので、履歴の総量が深さの 2 乗に増える可能性がある（要確認。レビューは再現していない）。

