# Y4 のレビュー

対象: 3750c8c6「Reduce the per-call cost of the reference interpreter's builtin bridge」（`crates/benitoite/src/refinterp/convert.rs` だけの変更）。`git show` で読んだ。背景は plan.md「作業 Y4」、decisions.md の Q8・R1、measurements.md、study.md「TODO-181 の調査」の 1・2 節（a5ff7165 の版）。

## 結論

要修正の指摘はない。根を取りこぼす経路も、ヒープが増え続ける新しい経路も見つからなかった。推奨 2 件と軽微 3 件を挙げる。

## 観点ごとの確かめ

### 根を要る番号だけ読む変更と、回収を条件付きにしたこと

- 回収のときに辿る根は、前と同じく `self.roots` の全体である（`self.heap.collect(&self.roots)`）。変わったのは、区間の中で引数を変換するときに `roots` を全部読んで `Vec` に写すのをやめ、`Value::Opaque(n)` に出会ったときだけ `roots.get(ctx, RootIdx(n))` で読む点だけである。辿る根の集合は変わらないので、回収の要求の有無にかかわらず、中身を見せない値を取りこぼさない。
- 区間（`heap.epoch`）の中には回収がない（`NoGcCtx` は回収の機能を持たない）。区間をまたいで持つ値は `roots` の `Slot` だけで、`references` は参照インタプリタの `Value` である。回収を飛ばした呼び出しで残る対象（引数の写し、`RefValue` の対象、結果の対象）は、次の区間では誰も読まない。根に積まれない対象が残っても、生きている時間が延びるだけで、読み違えは起きない。
- `roots` は `Drop` まで縮まないので、`RootIdx` は実行の間ずっと同じ値を指す。番号で読み直す方式はこの性質に頼っており、成り立っている。範囲外の番号は `roots.get` が `None` を返して `invalid_conversion()` になる。根の溢れのときの `RootIdx(u32::MAX)` は、`push` が不具合を記録し、区間の後の `take_fault` が停止に変える。
- `take_fault` は回収の有無にかかわらず毎回確かめる（study の (A) のとおり）。区間の中の読み出しの食い違いや確保の失敗は、従来どおりその呼び出しで停止になる。

### 回収を予算に従わせたことでヒープが増え続ける場合

- マーク・スイープの `State::allocated` は、すべての確保（`core.rs` の 339 行の共通の経路）で確保の量を足し、`live_bytes × trigger_factor_percent / 100`（下限 `trigger_min_bytes`）に達したら要求を立てる。要求は区間の後の `collect_requested()` で見え、回収が要求を下ろす。一つの呼び出しの中の確保が大きい場合は、前も呼び出しの後まで回収しなかったので変わらない。根に積まれない対象は、閾値を超えた後の呼び出しの終わりで回収されるので、増え続けない。
- 増え続けるのは、中身を見せない値の根が `Drop` まで減らないことだけで、これは変更の前からの弱さである。`call_decl` のコメントに書いた（study の (A) の指示のとおり）。
- 回収が検証の失敗や根の契約違反で途中で戻った場合は、要求が立ったままになり、次の呼び出しでも回収を試みる。不具合は `take_fault` で停止になるので、黙って増え続けることはない。

### RefValue の世代の照合と溢れ

- 世代は `call_decl` の初めに `checked_add(1)` で増やし、同じ呼び出しの `to_heap_with` が `RefValue { generation, index }` に入れ、結果を戻す閉包で一致を確かめる。一致しなければ `invalid_conversion()`（`Stop::Internal`）を返す。R1 の決定と study 2 節の案のとおりである。
- `RefValue` は根に積まれない（閉包は `RefValue` を先に判定し、それ以外だけを `roots.push` する）。古い世代の `RefValue` が結果に現れうるのは、中身を見せない値の中に保持された場合だけで、その場合を照合が拒む。回収を毎回しなくなっても、到達できない古い `RefValue` は誰も読まないので、照合の必要な範囲は広がらない。
- 溢れ（`u64` を使い切る）は `panic` にせず停止に変える。2^64 回の呼び出しは届かないので、規約（失敗を panic で表さない）を守るための形として妥当である。

### テストを stress のヒープにした変更

- 5 件のテストは、呼び出しの後に `bridge.heap.object_ids().is_empty()` を確かめる（`opaque_values_remain_rooted_across_builtin_calls` は回収を挟んで根が残ることを確かめる）。既定のヒープでは回収が起きなくなったので、stress にしないとこれらは偽になるか、根の検査が回収を経ずに通る空の検査になる。`HeapConfig::stress` は `collect_requested()` を常に真にするので、毎回の回収という前の前提を同じ形で再現しており、検査の意味を保つ。
- 一方で、既定の構成の分岐（要求がなければ回収しない）を確かめる単体テストはない。推奨 1 に書く。

### コメント

- 先頭の `//!` の「変換し終えた後、回収の予算に従って回収する」「次の区間では表から読み直し、終了時に根を手放す」は今の実装と一致する。
- `call_decl` のコメント「中身を見せない値の根は実行の終わりまで減らず、使い終えた値も保持する」は事実として正しい。軽微 1 に補足の案を書く。
- `RefValue` の上のコメントは世代に触れていない。軽微 2。

## 指摘

### 推奨 1: 既定の構成で、回収を飛ばすことと、閾値で回収することを確かめるテストがない

- 場所: `crates/benitoite/src/refinterp/convert.rs` の `mod tests`。
- 問題: 変更した 5 件のテストはすべて stress のヒープで走り、`gc-stress` の構成も stress を強いる。このため、`if self.heap.collect_requested()` の偽の分岐は単体テストで一度も通らない。条件を誤って常に偽にした退行（ヒープが増え続ける）も、常に真にした退行（今回の直しの効果が消える）も、どのテストも捕まえない。ゴールデンテストは既定の構成でこの分岐を通るが、結果が同じなので、どちらの退行も見えない。study の (A) は「振る舞いを変えない直しなのでテストを足さない」としたが、回収の時期は今回変えた振る舞いそのものである。
- 修正案: 既定の `HeapConfig`（`trigger_min_bytes` を小さくした構成でもよい）の `BuiltinBridge` で、文字列を返す見本（`samples::string_repeat` など）を繰り返し呼び、(a) 1 回目の後は `heap.stats().collections == 0` で対象が残ること、(b) 閾値を超える回数の後は `collections > 0` で、生きている対象の数が呼び出しの回数に比例して増えないこと、を確かめる。test-audit の関門 1 の答えは「回収の時期の条件を逆にした退行と、回収しなくなった退行を捕まえる」になる。`gc-stress` の構成では (a) が成り立たないので、`mark_sweep.rs` の既存のテストと同じく `cfg!(feature = "gc-stress")` で飛ばす。足さない判断をするなら、その理由を decisions.md に記録する。

### 推奨 2: stress にした理由をテストのコードに書いていない

- 場所: 5 件のテストの `bridge.heap = Heap::new(HeapConfig { stress: true, .. })`（`unsupported_and_malformed_values_are_internal_errors`、`samples_match_direct_bodies_and_preserve_stops`、`read_text_worker_finishes_synchronously_and_preserves_io_errors`、`exit_spawn_and_other_waits_remain_distinct`、`opaque_values_remain_rooted_across_builtin_calls`）。
- 問題: 理由（呼び出しごとの回収を前提に `object_ids().is_empty()` と根の保持を確かめるため）はコミットメッセージにしかない。後で誰かが既定の構成に戻すと、`opaque_values_remain_rooted_across_builtin_calls` は回収を経ずに通り、根の削除の退行を捕まえない空の検査になる。同じ 4 行が 5 回繰り返されている。
- 修正案: `mod tests` に `fn stress_bridge() -> BuiltinBridge` を置き、「呼び出しごとの回収を前提に、対象の残りと根の保持を確かめるので、回収を強制するヒープを使う。既定のヒープは予算に従い、回収を飛ばす」とコメントを付けて、5 件から呼ぶ。

### 軽微 1: `call_decl` のコメントが、番号で読み直せる理由を言っていない

- 場所: `call_decl` の「中身を見せない値の根は実行の終わりまで減らず、使い終えた値も保持する。」
- 問題: 文は残る弱さを書いているが、この性質が `Value::Opaque(n)` を区間ごとに `RootIdx(n)` で読み直せる前提でもあることは書いていない。将来、根を手放す仕組みを加える人が、番号の再利用で別の値を読む危険に気付きにくい。
- 修正案: 「中身を見せない値の根は実行の終わりまで減らない。このため `Value::Opaque` の番号は実行の間同じ根を指し、区間ごとに番号で読み直せる。使い終えた値も保持し続けることは残る弱さである（設計書 02-08「参照インタプリタ」）。」のように、前提と弱さの両方を書く。

### 軽微 2: `RefValue` のコメントが世代に触れていない

- 場所: `struct RefValue` の上のコメント「ヒープには呼び出し中の表の番号だけを置くので、…」。
- 問題: 欄に `generation` を加えたが、コメントは番号だけを置くと言っている。世代を持つ理由（中身を見せない値の中に残った古い呼び出しの値を、後の呼び出しの表で黙って引かないため）が書かれていない。
- 修正案: 「ヒープには呼び出しの世代と、その呼び出しの表の番号だけを置く。世代を照合して、中身を見せない値の中に残った別の呼び出しの値を拒む。」と改める。

### 軽微 3: ヒープの検証の不具合が、壊した呼び出しより後の呼び出しで報告されうる

- 場所: `call_decl` の `if self.heap.collect_requested() { self.heap.collect(&self.roots); }`。
- 問題: `heap-verify` の構成の検証は `collect` の中で走るので、回収を飛ばした呼び出しで起きた頭の破損は、閾値に達した後の呼び出しで報告される。報告する呼び出しと原因の呼び出しがずれるので、調べにくくなる。stress の構成（`gc-stress`）のテストでは毎回検証するので、検出力そのものは落ちない。
- 修正案: 変更は要らない。必要なら `//!` か `call_decl` のコメントに「ヒープの検証は回収のときに走るので、原因を探すときは `gc-stress` の構成で走らせる」と一文加える。
