# RV-II 段 II（表示の幅）のレビュー

2026-10-23、レビュー担当。対象は基準 `9c96dd9e35f5ade4b7ad1db592ddec6e45d54d33` から `849079b69c7ca28653e5071488c91efee8f7f574` まで（作業 W1 `a1f4fb5f`・W2 `849079b6` の 2 コミット）である。作業ツリーではなく `git show`・`git diff` で対象のコミットを読んだ。ビルドとテストは行っておらず、検査の成否は `w1/results.md`・`w2/results.md` の記録に依る。unicode-width 0.2.2 の挙動は、手元の cargo のレジストリにある同版のソース（`src/tables.rs`・`src/lib.rs`・`Cargo.toml`）で確かめた。

## 結論

重い指摘が 1 件（H1）、中の指摘が 1 件（M1）、軽い指摘が 5 件ある。六関数の意味、登録、版の表示、文書は決定 D10〜D14・D31 と一致している。H1 は、`HeapCore::alloc_str_parts` の `unsafe` の正しさが、汎用の引数の安全なトレイトの振る舞いに依存するようになった点である。今の呼び出し元はどれも決定的な反復子を渡すので、今の処理系で未定義動作は起きない。それでも、安全な関数が一部の安全な入力に対して健全でなく、`// SAFETY:` の根拠も成り立たないので、段 V（F3 以降が同じ確保の経路を使う可能性がある）へ進む前に直すことを勧める。M1 は、新しい経路を Miri が一度も通っていない点であり、H1 の修正と同じ作業でテストを加えれば解消する。

## 確かめたこと

### 1. ヒープの内部の層と公開の層（`core.rs`・`ctx.rs`）

- `HeapCore::alloc_str_parts` の引数が `&[&str]` から `impl Iterator<Item = &'s str> + Clone` に変わった。長さの照合は複製（`parts.clone()`）で行い、書き込みは元の反復子で行う（`core.rs` 397〜412 行）。この点は H1 で扱う。
- `unsafe` のブロックは 2 個とも操作を一つだけ含み、`// SAFETY:` は O2・O3 を名指ししている。ブロックの形は規約どおりである。ファイル先頭の不変条件の一覧（O1〜O9）は変わっていない。
- `ValueCtx::alloc_str_space_padded`（`ctx.rs` 466 行）は `pub(crate)` であり、言語の値を作る経路は公開の層の関数に限る規約に合う。全長を `u64` で求めて `CheckedLen::bytes` で論理上限（2^30 バイト）を検査し、その後 `usize::try_from` で変換してから確保する。`as` の変換、`unwrap`・`expect`・添字はない。`unwrap_or(u64::MAX)` は上限の検査で必ず断られる値への置き換えであり、問題はない。
- UTF-8（H12）: 部分はどれも `&str`（U+0020 と元の文字列）なので、正しく写す限り連結は正しい UTF-8 である。元の文字列はヒープの対象の中身の借用だが、確保が既存の対象の領域に書かないこと（O3）は既存の `+` の演算子と同じ前提である。
- 安全点: 純粋な組み込みの関数の中で回収は起きず、`Value<'e>` を区間の外へ持ち出していない。
- 検査の記録: W2 の work は heap_checks（Miri の通常確保 58 件・個別確保 51 件、到達可能性の比較 50 件）と doc_default（compile_fail 17 件）を含み、局所の heap_local・stress_local も runtime_builtins 17 件・golden 2 件が成功している。ただし Miri の対象は `runtime::heap::` と `vm::miri_tests::` の lib テストであり、新しい経路を通るテストがない（M1）。

### 2. 六関数の意味と登録

| 決定 | 実装 | 判定 |
|---|---|---|
| D11 既定と CJK の二モード、端末から自動検出しない | `WidthMode::{Default,Cjk}` が `UnicodeWidthStr::width`・`width_cjk` を呼ぶ。環境を読まない | 一致 |
| D12 U+0000〜001F・007F〜009F・2028・2029 を幅 0 の境界とし、境界間の最大の部分の幅を合計する。全入力に Integer | `is_boundary` と `str::split` による合計。境界の文字自体は幅に入らない。合計のあふれは `None` から `Stop::Internal`（幅は UTF-8 バイト数以下で 2^30 を超えないので到達しない） | 一致 |
| D13 名前と型、すべて純粋 | `displayWidth`・`displayWidthCJK`・`displayWidthPadStart`・`displayWidthPadEnd`・`displayWidthPadStartCJK`・`displayWidthPadEndCJK`。署名は `String.bnt` の宣言と一致し、`builtin!` の `pure fn` で登録した。表の検査は純粋な関数の数を 415 から 421 へ、State 16・IO 59 を保つ | 一致 |
| D13 U+0020 だけを補い、結果の幅は `max(W(s), width)`、0 以下や既に十分なら元の値を返す、内容を切らない | `space_padding` は目標が 0 以下か現在の幅以下なら 0 個を返し、`pad_display_width` は 0 個なら元の `Value` を返す。それ以外は片側に空白を加えるだけで、元の文字列を切らない | 一致 |
| D13 空白の加法性 | unicode-width 0.2.2 の `width_in_str`・`width_in_str_cjk` は U+00A0 以下の文字に `(1, WidthInfo::DEFAULT)` を返し（`tables.rs` 258〜262 行）、`str_width`・`str_width_cjk` は `rfold` で右から走査する。U+0020 は `starts_emoji_presentation_seq` に当たらないので、左右どちらに置いても隣の文字の状態を変えない。03-06 の理由の記述は一次資料と一致する | 一致 |
| D14 予算と検査済みの整数変換を介して確保 | 目標の幅は `i64` のまま `u64` で計算し、`usize` へ先に縮めない。論理上限は確保前に検査する。ネイティブのヒープに独立したメモリの予算はなく、新しい予算を加えていない（W2 の申し送り） | 一致 |

- unicode-width の文字列の算法には負の加算（Khmer の coeng、Tifinagh、地域指示子の ZWJ の列）があるが、どれも右側の文字が先に正の幅を加えた後に打ち消す形であり、部分ごとの合計は負にならない。境界での分割もこの性質を壊さない。
- 表への接続は `PARTS` の末尾に新しい部分 `string::DISPLAY_WIDTH_DECLS` を足す形であり、既存の番号を保つ。

### 3. 依存と版の表示

- `unicode-width = { version = "=0.2.2", default-features = false, features = ["cjk"] }` は D31 と一致する。0.2.2 の `Cargo.toml` は `default = ["cjk"]` であり、既定の機能を切って `cjk` を明示する形は意図を明記している。ライセンスは `MIT OR Apache-2.0` で、既存の許可名の範囲に収まる（W1 の licenses は成功）。
- クレートは常に `#![no_std]`・`#![forbid(unsafe_code)]` であり、大域の状態を持たない。03-01 の「通常構成で必須の依存を持たず、no_std で使える」は同版のソースと一致する。幅の本体 `base::display_width` は VM・値・Host・Wasmtime に依存せず、`u64` と検査付きの変換だけを使うので、64 ビットだけを前提にするコードも増えていない。組込み向けの構成の境界（AGENTS.md「改造の設計で守ること」）については L2 で触れる。
- `--version=json` は任意の欄 `displayWidthUnicodeVersion` を加え、`schemaVersion` は 1 のままである。人間向けの `--version` の処理は差分になく、二行を保つ。`cli_process` は期待値を `"17.0.0"` と直接書き、`unicode_width::UNICODE_VERSION` から作らないので、独立した期待値になっている。06-01 とリファレンスも「この版では常に出し、旧版では欠ける」と書いている。

### 4. 文書・生成物・テスト

- 03-06・00-04・06-01・07-04・英語リファレンス・`String.bnt` のドキュメントコメント・Skill の生成物（`references/stdlib/String.md`）は互いに一致している。用語集の「表示の幅」は 03-06「String」へリンクし、D12 の境界と「端末の移動量ではない」ことを書いている。07-04 は算法を形式化の対象外とする行を加えた。日本語訳と第三者表示は計画どおり Z1 に残っている。
- `String.bnt` の例（`"猫🐈"` の幅 4、CJK の `"·"` を幅 4 へ埋めた `"  ·"`）とリファレンスの例の期待出力は、手で計算した値と一致する。
- 実行境界のテスト `display_width_functions_preserve_content_and_pad_in_both_modes` は、`main` が `Result.Error` を返すと `EndKind::MainError` になり、差分比較器の `require_returned` で失敗する。資源の不足による除外も panic にしている。VM と参照評価の一致だけで通る空振りのテストではない。
- `display_width_padding_rejects_oversized_dynamic_targets` は、2^30＋1・2^32・`i64::MAX` と、UTF-8 バイト数を含めて初めて上限を超える `"\u{301}"` と 2^30 の組を、両実行器で R0902・関数名・サイズまで確かめており、表示の幅とバイト数の混同と `usize` への切り詰めを捕まえる。
- 単体テストは、文字ごとの幅の和への置換（U+17D8 の幅 3、合字、ZWJ の列）、制御境界の全 67 文字、CJK の取り違え（`·`・`=\u{338}`・`⌚\u{fe0e}`）、前後 0〜3 個の空白の加法性、一般の連結の非加法性の対照を含み、計画の W1・W2 の完了の条件を満たす。

## 指摘

### H1（重、読めば確定する）`alloc_str_parts` の `unsafe` が `Clone` と `Iterator` の振る舞いに依存している

- 場所: `crates/benitoite/src/runtime/heap/core.rs` 390〜414 行（特に 400 行の `parts.clone()` と、409 行・411 行の `unsafe`）。
- 問題: 長さの照合は `parts.clone()` を辿った合計で行い、書き込みは元の `parts` を辿って行う。`Iterator` と `Clone` は安全なトレイトであり、複製が元と同じ並びを返すことは型で保証されない。たとえば `Cell` で呼ばれた回数を数え、二度目の走査で長い部分を返す反復子を渡すと、照合を通った後に `copy_nonoverlapping` が確保した領域の外へ書く。短い部分を返せば未初期化のバイトが残り、H12（中身は確保の時点から正しい UTF-8）も破れる。`alloc_str_parts` は `unsafe fn` ではない `pub(super)` の関数なので、どの安全な入力に対しても健全でなければならない。409 行の `// SAFETY:` の「合計は size と等しく」は、複製と元が同じ並びを返すという書かれていない前提の上でしか成り立たず、AGENTS.md「`unsafe` の書き方」の、前提とする不変条件とそれが成り立つ理由を書く規約を満たさない。変更前の `&[&str]` は不変のスライスなので、二度辿っても同じ並びになることが型から言えた。
- 今の影響: 呼び出し元は `ctx.rs` の `parts.iter().copied()` と、`repeat_n`・`once`・`chain` の組だけであり、どちらも決定的である。今の処理系で未定義動作は起きない。
- 修正案（どれか一つ）:
  1. 内部の層を汎用にせず、具体的な形を受け取る。たとえば `alloc_str_parts(epoch, len, parts: &[&str])` を元に戻し、空白の追加には `alloc_str_space_padded(epoch, len, before: usize, s: &str, after: usize)` を内部の層に加え、`write_bytes(dst, b' ', before)`・`copy_nonoverlapping`・`write_bytes` で書く。長さの照合は `before + s.len() + after == size` の検査付きの和で行う。
  2. 汎用のまま残すなら、閉包の中で残りのバイト数を数え、`remaining.checked_sub(part.len())` が失敗したら書かずに止め、走査の後に残りがあれば 0 で埋めて初期化を保ち、確保の後に `Stop::Internal` を返す。この場合も `// SAFETY:` を「写す前に残りの長さで検査した」という根拠へ書き換える。
  3. 内部の層に私的な反復子の型（`StrParts` など）を置き、引数をその型に限る。この場合は、決定性がその型の実装から言えることを `// SAFETY:` に書く。
- 1 が最も単純で、`unsafe` の根拠が引数の値だけで閉じる。どの案でも、前提が変わるなら `core.rs` 先頭の O2 の説明か `// SAFETY:` に追記する。

### M1（中、読めば確定する）新しい確保の経路を Miri が通っていない

- 場所: `crates/benitoite/src/runtime/heap/ctx.rs` の `#[cfg(test)]` のテスト（913 行付近の `alloc_str_parts` のテスト）、`w2/results.md` の heap_checks の行。
- 問題: `scripts/check-heap.sh` の Miri は `runtime::heap::` と `vm::miri_tests::` の lib テストだけを走らせる。W2 は lib テストを加えておらず（lib は W1 と同じ 1,256 件、Miri も既存の 58 件・51 件）、`alloc_str_space_padded` と `repeat_n`・`chain` の反復子で `alloc_str_parts` を通るテストは Miri の対象にない。新しい経路は heap_local・stress_local の統合テストで実行されたが、heap-verify は世代の検査であり、確保した領域の外への書き込みや未初期化の読み出しは Miri でなければ検出できない。AGENTS.md「テストの運用」の、ヒープの不変条件に触れる作業で必要な `check-heap.sh` を通すという条件は、選ばれた単位としては満たしているが、変更した経路は覆っていない。
- 修正案: H1 の修正と同じ作業で、`runtime::heap::ctx` のテストに、先頭・末尾への空白の追加、空の元の文字列、多バイト文字を含む元の文字列、上限の直上での拒否を確かめるテストを 1 件加え、heap_checks を再実行する。期待値は結果の文字列のバイト列で直接書く。

### L1（軽、読めば確定する）論理上限の検査が二重にある

- 場所: `crates/benitoite/src/builtins/funcs/string.rs` 521 行の `CheckedLen::bytes(padding.byte_len, function)?`。
- 問題: 直後に呼ぶ `alloc_str_space_padded` が同じ全長で `CheckedLen::bytes` を再び検査する。結果は同じだが、どちらが規約上の検査の場所かが読み手に分かりにくい。
- 修正案: 公開の層（`ctx.rs`）の検査を正とし、`string.rs` の 521 行を消す。H1 の案 1 を採るなら、公開の層の関数が全長の検査を持つ形のまま揃える。

### L2（軽、読めば確定する）組込み向けの構成で外せない依存であることを 03-01 に書いていない

- 場所: `docs/design/03-interop/03-01-library-structure.md` の `unicode-width` の箇条。
- 問題: AGENTS.md「改造の設計で守ること」は、大きな依存を Cargo の機能で外せる境界に置くことを求める。D14 は「共通に含める」と決めており、unicode-width は `no_std`・`unsafe` なし・大域の状態なしの小さなクレートなので、機能で外さない判断自体は妥当である。ただし、03-01 にはなぜ機能で外さないかの理由（String の純粋な関数であり、構成で使える関数の集合を変えないため、など）が書かれていない。幅の表（既定と CJK の二組）がバイナリの大きさに与える影響は確かめていない（実行しないと分からない点）。
- 修正案: 03-01 の箇条の「理由:」に、組込み向けの構成でも外さない理由を一文加える。大きさの影響は、Z1 か組込み向けの構成の項目（docs/todo の TODO-263〜265）で測るなら、その項目に申し送る。

### L3（軽、読めば確定する）03-06 の二つの【決定】に「理由:」がない

- 場所: `docs/design/03-interop/03-06-stdlib.md` 317 行と 343 行。
- 問題: 間の 319 行の段落と 03-01 は「理由:」を持つが、317 行（境界と二モード）と 343 行（四関数の契約）は持たない。AGENTS.md「決定の書き方」は決定の直後に理由を書くとしている。
- 修正案: D12・D13 の理由（任意の String に幅を定義し端末の状態に依存しないため、切断や幅 0 の埋め文字の繰り返しを避けるため）を、それぞれ一文で写す。

### L4（軽、読めば確定する）テストの名前とコメントが確かめていないことを述べている

- 場所: `crates/benitoite/src/base/display_width.rs` 148 行の `padding_counts_bytes_without_allocating_the_output`、`crates/benitoite/tests/runtime_builtins.rs` 1145 行のコメント「GC の安全点を越えて元の文字列と結果を読み直す」。
- 問題: 前者は確保しないことを確かめていない（`space_padding` は戻り値の型から確保しないことが明らかであり、テストは個数とバイト数だけを比べている）。後者は、既定の構成では回収が起きる保証がなく、回収を越えることを確かめるのは stress_local の構成で走らせたときだけである。
- 修正案: 前者を `padding_counts_spaces_and_output_bytes` などに改める。後者のコメントに「gc-stress の構成では各安全点で回収する」と条件を書く。

### L5（軽、読めば確定する）03-01 の表の行だけが版を含む

- 場所: `docs/design/03-interop/03-01-library-structure.md` の表の `unicode-width` 0.2.2 の行。
- 問題: 表のほかの行はクレートの名前だけを書き、版は箇条や `Cargo.toml` に任せている。
- 修正案: 表の欄は `unicode-width` とし、版は直下の箇条（既に `=0.2.2` を書いている）に任せる。好みに近いので、直さなくてもよい。

## 実行しないと分からない点

- H1 の不健全さは、悪意のある反復子を渡すテストを書けば Miri で再現できるはずだが、確かめていない。今の呼び出し元では起きないので、修正は型と根拠の誤りに対して行い、再現のテストは要らない。
- 幅の表がバイナリの大きさに与える影響（L2）。
- 取り込み後の性能比較 short の結果（取りまとめが実施する）。

## 判定

H1 と M1 を直し、heap_checks（Miri）と、H1 で変えた経路に関わる局所の heap_local・stress_local を通してから、段 V で同じ確保の経路を使う作業に進むことを勧める。六関数の意味・登録・版の表示・文書は受け入れてよい。L1〜L5 は H1 の修正と同じ作業か Z1 で直せば足りる。
