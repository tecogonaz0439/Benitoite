# 作業 Z1 のレビュー

- 対象: コミット `21c7949f`「Fix the findings of the V1-V3 reviews (Z1)」（san_benito へは `a8ebad9b` で取り込み済み）。
- 根拠: `reviews/2026-10-13-V1〜V3/report.md`、`decisions.md` の R9、オーケストレータの指示と実装担当の報告、AGENTS.md、スキル test-audit。
- 方法: `git show` で差分と周りのコード（`syntax/newline.rs`、`parser/mod.rs`、整形器の `roles/walk.rs`、`external/check.rs`）を読んだ。wasmparser 0.258.3 の `TypeInfo` の深さの数え方と、wasmtime-environ 49.0.2 の `NameMap::get` を確かめた。テストの節点数は手で計算した。cargo は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

指示の各項目（V1 の M1〜L4、V2 の M1〜L5、V3 の M1〜L4）は、どれも直されていた。新しい問題は Medium 1 件、Low 9 件。

## 指摘

### M1（Medium）予算の超過の E1010 が、宣言した型ではなく内側の型を名指しする

- 場所: `external/types.rs` の `Expansion::expand` の先頭と、`external/check.rs` の `unsupported`。
- 問題: `budget` の `Unsupported.ty` に上限に達した節点の型（多くは `Integer`）が入り、見出しが「`Integer` cannot be passed …」になって注記と食い違う。内側に利用者の `Option` があれば、関係のない `user_type` の注記も付く。テストは注記の文字列しか確かめない。
- 再現: `declaration_expansion_stops_at_depth_and_node_limits` の `(100, false)` の場合（`T0`〜`T99` の連なりを `f(v: T99)` に使う）。
- 修正案: `budget` のときは根の型で `Unsupported` を作る。テストに見出しの型を確かめる行を足す。

### L1（Low）予算が型ごとなので、宣言が多いと費用が 10 万倍で積み上がる

- 場所: `external/check.rs` の `declaration_plan`、03-10「型の対応」の「型ごとに … 上限とする」。
- 修正案: 予算を検査の全体で共有するか、型ごとの予算に加えて全体の上限（例: 10^6）を設け、03-10 を直す。

### L2（Low）`argN` が、WIT の別の引数の名前と重なる

- 再現: `(param "data" s64) (param "arg1" s64)` で注記が `function f(arg1: Integer, arg1: Integer) -> Integer` になる。
- 修正案: 決めた名前を集合に入れ、重なれば N を進める。規則を 03-10 に足し、テストに組を足す。

### L3（Low）注記 `budget` の文が、節点数の上限について言い過ぎている

- 問題: 節点数の上限 10 万は wasmparser の上限 100 万より小さいので、「どの WIT の型とも照合できない」は深さについてだけ正しい。
- 修正案: 深すぎて照合できないことと、大きすぎて検査しないことを分けて書く。参照の文書を作り直す。

### L4（Low）修飾が閉じないと、ファイルの終わりまで読み飛ばし、E0201 がファイルの終わりを指す

- 問題: 括弧の中の改行は捨てられるので、閉じない `public(crate` の後はファイルの終わりまで読み飛ばし、後ろの宣言の診断も失われる。
- 修正案: 宣言を始める予約語でも読み飛ばしを止め、E0201 をそこで報告する。テストを足す。

### L5（Low）`user_type` の注記を、型の一番外側でしか判定しない

- 再現: 利用者の `data Result` を `List[Result]` に使い `list<result<s64, string>>` に当てると、注記が付かない。
- 修正案: 最初の食い違いの位置の型で判定するか、外側に限ることを 03-10 に書く。

### L6（Low）整形器が `public⏎(package)` をどう扱うかを確かめていない

- 修正案: `testdata/fmt/` に一件足し、期待する結果を決めて 06-03 かリファレンスに書く。

### L7（Low）E0329 の文言のテストが、入力の文字列で分岐している

- 場所: `resolve/tests.rs` の `public_contracts_include_nested_types_effects_and_supertraits`。
- 修正案: 表に期待する見出しと help の列を足し、分岐を除く。

### L8（Low）`Trait.Ordering` の往復が恒等の関数なので、対称な取り違えを捕まえない

- 修正案: `color` と同じく番号を一つ進めて返し、`Less→Equal` などを期待する。

### L9（Low）予算の内側でも、照合の誤りの表示が数 MB になりうる

- 修正案: E1008・E1009 の型の表示に長さか節点数の上限を設け、超えたら省く。

## 確かめて問題がなかった点

- E0253 の読み飛ばしは毎回字句を進め、`Eof` で止まる。閉じない修飾には置き換えを付けない。
- `public⏎(package)` を受け付け、`public(package)⏎宣言` は誤りのまま。01-02・02-03・リファレンスと一致する。
- 深さ 100 の数え方は wasmparser と一致し、正しいコンポーネントに合う型を誤って拒まない。テストの節点数は計算と合う。展開の再帰と Drop は深さ 100 で抑えられる。
- 引数名の作り方、`user_type` の注記の範囲（標準ライブラリの型を除く）、`Level` の共有、コメント、設計書・用語集・`ExternalSpec.export` の説明・README・名前の表示のテスト・E1010 の文言・skill の生成物・CHANGELOG。
