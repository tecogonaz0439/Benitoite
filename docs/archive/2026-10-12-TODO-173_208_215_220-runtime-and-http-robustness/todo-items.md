# 扱う項目の写し

改造を始めた時点（2026-10-12、docs/todo の c516817）の項目の本文を写したものである。

## TODO-173 ヒープの安全の範囲の文書と、heap-verify なしの構成での回収のテスト

- 状態: 要検証
- 出どころ: [later-issues の 42・43・44・111](sources/later-issues.md)、[取り込み漏れの調査の C-3](sources/2026-10-09-todo-gap/C-orch-notes-and-memory.md)、[ADR 0281](../archive/2026-10-09-design-first-release/decisions/0281-heap-number-in-slot-and-contract-safety.md)

ヒープ（`runtime::heap`）の安全について、文書に書いていない範囲と、`scripts/check.sh` の構成では見つからない不具合の疑いを扱う。check.sh はテストを機能 `gc-mark-sweep,heap-verify` 付きでしか走らせない（`scripts/check.sh:54-55`）ので、配布物の構成（heap-verify なし。`Cargo.toml` の既定の機能は `gc-mark-sweep` だけ）のテストの失敗に気付けない。関連: TODO-161（Miri で動かせる範囲）。

- 回収のテストが番地から作る `ObjId` で判定する（later-issues の 42、43 の (c)、44 の最後。取り込み漏れの調査の C-3）。`ObjId` は対象の番地から作る（`crates/benitoite/src/runtime/heap/value.rs:226-228`、`core.rs:166-176`）。`dead_large_list_is_reclaimed_after_its_last_use`（`crates/benitoite/src/vm/tests.rs:1277`）と `suspended_callers_release_old_arguments_and_results_before_collection`（同 1533 行）などは、「古い id が残っていない」を番地で判定し、`cfg(feature = "heap-verify")` の限定もない。heap-verify なしの構成では、解放した番地の再利用で失敗しうる。作業 R18 と R32 の報告では、この 2 件が heap-verify なしの構成で失敗し、R32 の報告では 1 件が本番の構成でも再現した。今も失敗するかは確かめていない（要再現）。テストの前提（ヒープの検証器が対象の ID を整理すること）と、heap-verify なしでの回収の振る舞いのどちらが誤りかを確かめたうえで、テストを heap-verify に限るか、番地に頼らない判定に改める。`heap_constants_keep_identity_when_only_the_cache_roots_them`（`vm/tests.rs:408`）は、heap-verify なしでは Trace の漏れを捕まえない。あわせて、テストの中で定数表を引く処理の重複（5 か所）を補助の関数にまとめる。
- 根に入れない `Slot` を回収の後に読むと、安全な関数だけで解放後の使用（UAF）になる範囲（ADR 0281）が、rustdoc に書かれていない（later-issues の 111 の E-1）。`runtime/heap/mod.rs` の `//!` と、`Heap::collect`・`NoGcCtx::load` の `///` に書く（`ctx.rs:334`・`362` にはない）。
- 印付けの途中で panic すると印が残り、次の回収が到達できる子を解放する（later-issues の 111 の E-2）。`core/mark_sweep.rs:148-180` は対象の頭の word を 0 か 0 でないかで印に使う。回収ごとの番号を印にする形に改める。
- 配布物の構成（heap-verify なし）でテストか Miri を走らせる（later-issues の 111 の E-3）。上の `ObjId` のテストの件と近い論点である。
- `Decimal: Copy` の表明と、`allow(unsafe_code)` を書いた場所の検査がない（later-issues の 111 の E-4）。

## TODO-220 共有した構造を持つ等しい値の比較が指数時間になる

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/` の `study.md` の「TODO-186 の調査」の 9 節

`crates/benitoite/src/runtime/equal.rs` の `values_equal` は、同じ対象への参照でも成分を調べる（`[NaN]` を取りこぼさないため）。そのため、共有した構造を持つ等しい二つの値（同じ部分木を何度も参照する木など）の比較は、共有を展開した大きさに比例し、深さに対して指数時間になる。言語の `=`・`<>` も `Assert.equal` も同じである。`Assert` の報告の書き出しは 4 KiB で止めるようにしたが、比較の時間は抑えていない。対策の候補（同じ対象で `Float` を含まない型なら成分を調べずに等しいとする、比べた組を覚える、など）と、型の情報が実行時に要るかを検討する。

## TODO-208 HTTP サーバの要求の対象の文法の検査を広げる

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-11-TODO-185_201_202-regex-and-http-details/` の `study-202.md` の Q4、`decisions.md` の「推奨どおりとした問い」
- 関連: TODO-069

TODO-202 の改造で、要求の対象が `#` を含めば 400 にした。ほかの文法の外の対象は、今も受け付ける。起点形が `/` で始まらない対象（`OPTIONS` 以外の `*`、`CONNECT` 以外の authority 形）と、httparse が通す文法の外の文字（`"`・`<`・`>`・`\`・`^`・`` ` ``・`{`・`|`・`}`。httparse 1.10.1 の `URI_MAP` は `!` から `~` と 0x80 以上を通す）である。RFC 9112 §3.2 は、文法に合わない要求の行を 400 にし、直して処理しないことを勧める（SHOULD）。400 にすると利用者から見える変更が増え、既存のテスト（`CONNECT h:443`、`OPTIONS *`）との関係も整理が要る。

## TODO-215 HTTP サーバが 413・431 を返す接続の閉じ方

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-12-TODO-182_183_184-test-reliability-and-io-details/` の `study.md` の 1.6 節、`decisions.md` の R11
- 関連: TODO-208、TODO-216

HTTP サーバは、413・431 などを返して接続を閉じるとき、応答を書いた後に `shutdown(Both)` をしてから閉じる（`crates/benitoite/src/runtime/io/http.rs`。改造の時点で 604-615 行）。読まなかった要求の残りが受信のバッファにあると、閉じたときに TCP の RST を送り、OS によっては、クライアントがまだ読んでいない応答が RST で消えうる。今のテスト（`crates/benitoite/tests/l30_http_server.rs` の `request`）は、RST で終わっても先に応答を受けていれば通す。テストの要求は小さく（431 の 64 KiB の行の場合でも残りは数バイト）、落ちた記録はない。
