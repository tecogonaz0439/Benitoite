# 作業 R のコードレビュー

Opus のサブエージェントが行ったレビューである。サブエージェントがファイルを書けなかったので、返答の全文をオーケストレータが写した。

## 対象と方法

- 対象: ブランチ `impl/hardening-R` の、基準 375304c からコミット 43e942e までの差分（11 ファイル、377 行の追加と 53 行の削除）。
- 読んだもの: 依頼文（事前点検の補足 1〜13 を含む）、実装担当の報告、`decisions.md` の Q10〜Q12、AGENTS.md の実装の規約、regex 1.13.1 の `src/lib.rs` の「Iterating over matches」（1093〜1118 行）。
- 確かめた範囲: `allocate`・`free_object`・`with_host_mut`・新しい `recharge_host`・`verify_live_objects`・回収の方式（`core/mark_sweep.rs` の `State::allocated` と `collect`）を読み合わせた。`objects.push` と `swap_remove` は `allocate` と `free_object` に 1 か所ずつしかなく、`current_bytes` を書くのは `allocate`・`free_object`・`recharge_host` だけである（`grep` で確かめた）。
- 走らせた検査（TCP を使わないものだけ）:
  - `cargo test -p benitoite --lib --features heap-verify runtime::heap`: 40 件が成功、2 件が ignore。
  - `cargo test -p benitoite --lib --features gc-stress,heap-verify runtime::heap`: 40 件が成功、2 件が ignore。
  - `cargo test -p benitoite --lib builtins::funcs::regex`: 9 件が成功。
  - `cargo test --test golden --features gc-stress,heap-verify` を、`BENITOITE_GOLDEN_FILTER` で `stdlib`・`testdata/concurrency`・`testdata/handlers`・`testdata/effects` に絞って実行し、すべて成功した（回収のたびに走る検証が、`Match`・`TaskObj`・`ContState` を含む実行で新しい合計の検査を通ることを確かめるため）。
- 「直す前に落ちる」ことは、報告に書かれた修正前の値を読んで確かめた。差分を戻しての再実行はしていない。

## 所見

要修正の所見はない。

### 1. 記録の合計と `current_bytes` の一致を、不変条件の一覧に書いていない（望ましい）

- 場所: `crates/benitoite/src/runtime/heap/core.rs` 1〜20 行（先頭の `//!` の O1〜O8）、`core/verify.rs` 114〜151 行。
- 問題: この作業で、「生きている対象の記録の `charged_bytes` の合計は `current_bytes` と等しい」が不変条件になった。以前は記録を確保のときに一度書くだけだったので暗黙に成り立っていたが、今は `recharge_host` が記録と合計を後から動かす。内部の層は各ファイルの先頭の `//!` に不変条件の一覧を書き、`// SAFETY:` や検査がその項目を名指しする規約で保っている（AGENTS.md「`unsafe` の書き方」）。一覧にない不変条件は、後の改造で片方だけを動かす変更を見落とさせやすい。
- 直し方の案: 一覧に「O9: 生存対象の記録の `charged_bytes` の合計は `current_bytes` と等しい。両者は `allocate`・`free_object`・`recharge_host` だけが、同じ関数の中で揃えて直す」を加え、`recharge_host` のコメントと `verify.rs` の検査の前に `O9` と書く。

### 2. `HostData::heap_bytes` の値を変えてよい場面を文書にしていない（望ましい）

- 場所: `crates/benitoite/src/runtime/heap/value.rs` 218〜235 行。
- 問題: 数え直しは `host_mut` の閉包の前後だけで行う。将来、`host()` で得た共有の参照から内部の可変性で容量が変わる型を足すと、記録は次の `host_mut` まで実際の容量とずれ、回収の要求が遅れる（記録と合計の一致は保たれるので、安全性の問題ではない）。
- 直し方の案: `HostData::heap_bytes` の `///` に「値は `host_mut` の閉包の中でだけ変わってよい。数え直しはその前後だけで行う」と、`OpaqueData::heap_bytes` に「確保のときに一度だけ読む」と足す。

### 3. 確保のときのコメントの「一度だけ数える」が `Host` では誤読を招く（参考）

- 場所: `core.rs` 467 行・484 行、968 行（`recharge_host`）。
- 問題: `alloc_host` のコメント「この対象だけが所有する別領域を一度だけ数える」は、後で `with_host_mut` が数え直すことと食い違って読める。
- 直し方の案: 「確保のときの容量を数える。後の増減は `with_host_mut` が数え直す」などに改め、`recharge_host` にも役割と所見 1 の不変条件を保つことを一行書く。

### 4. 性能の関門の速い経路の費用は、測って確かめる必要がある（参考）

- 場所: `core.rs` 956〜965 行。
- 問題: `TaskObj` の `host_mut` では、動的に呼ぶ `heap_bytes()` が 2 回増える。`before == after` のときは記録の表にも `RefCell` にも触れず、形は妥当である。ただし間接の呼び出しは脱仮想化されず、1 回目は `downcast_mut` の型の比較より前に呼ぶ。
- 直し方の案: コードは変えず、オーケストレータの短い測定で退行がないことを確かめる。退行が見えたら、`before` の読み出しを型の確認の後へ移す。

### 5. 文書の一文目の後の「etc.」（参考）

- 場所: `crates/benitoite/src/prelude/stdlib/Regex.bnt` 1〜2 行、`skill/references/stdlib/Regex.md` 7〜8 行。
- 問題: 内容は regex 1.13.1 の記述と合うが、一回の照合に当たる関数は `isMatch`・`find`・`replaceFirst` の 3 つだけなので、「etc.」は要らない。`docs/reference/benitoite.md` 796 行と `docs/ja/reference/benitoite.md` 795 行に「linear」「線形」が残る（オーケストレータが直す）。
- 直し方の案: 列挙を閉じ、`gen_skill` で作り直す。

### 6. `host_shrinkage_does_not_reduce_allocations_since_collection` の最後の等式は、容量が要求どおりであることを前提にする（参考）

- 場所: `core/mark_sweep.rs` 540〜573 行。
- 問題: `assert_eq!(heap.stats().allocated_bytes, base + 8192)` は、`Vec::<u8>::with_capacity(4096)` の容量がちょうど 4096 であることを前提にする。標準ライブラリが保証するのは「少なくとも」だけである。
- 直し方の案: 閉包の中で `capacity()` を返し、その和で期待値を作る。

## 観点ごとの確かめの結果

- 数え直しと記録の一致: `recharge_host` は記録を頭の添字で引き、記録の番地が値の頭と一致することを確かめ、差の計算をすべて `checked_*` で終えてから記録と `current_bytes` を同じ関数の中で直す。途中で失敗すれば何も変えずに `CorruptHeader` を記録する。どの経路でも記録の合計と `current_bytes` は一致したままで、解放の `checked_sub` と食い違わない。閉包には `SlotOps` しか渡らないので、閉包の後の `objects.borrow_mut()` は二重の借用にならない。
- 増加の通知と借用の順: `stats` と `objects` の借用を落としてから `mode.allocated` を呼び、`allocate` と同じ順である。
- 減少: 記録と `current_bytes` だけから引き、統計の `allocated_bytes`、方式の A、L には触れない。
- heap-verify の合計の検査: 今の回収の方式はマーク・スイープだけで、`collect` は死んだ対象をすべて解放した後に `verify` を呼ぶ。`heap-per-object` で変わるのは確保器の容量の値だけで、記録と合計に足す値は同じなので、構成によらず成り立つ。
- `Match` の新しい形: `matchText`・`matchByteStart`・`matchByteEnd`・グループの値は以前と同じ。空の一致、一致の末尾で終わるグループ、参加しないグループも同じ。`Stop::Internal` にする条件は、regex 1.13.1 に後方参照も先読み・後読みもないので、正しいプログラムでは起きない。
- 名前の表: `compile` で一度作って `Pattern` に持たせ、各 `Match` が `Rc` で共有する。共有の表は数えない。
- 二度の走査: 補足 10 のとおり残り、停止の種類と報告の `size` は変わらない。
- 規約: 新しい `unsafe` はなく、テストを除くと `unwrap`・`expect`・添字・`as`・`+` の算術を使っていない。
- テスト: 加えた 6 件は作成時の関門のコメントを持ち、内部の欄を読む理由を書いている。公開の境界の 2 件は差し込み口を足さずに閾値で確かめ、`gc-stress` では先頭で戻る。

## 総評

実装は依頼文と補足のとおりで、正しさに関わる誤りは見つからなかった。取り込みの前に望ましいのは、記録の合計の一致を内部の層の不変条件の一覧に書くこと（所見 1）と、`HostData::heap_bytes` の値を変えてよい場面を文書にすること（所見 2）である。性能の関門の短い測定（所見 4）は、オーケストレータが予定どおり行えばよい。
