# 作業 Z5 のレビュー

- 対象: コミット `d8bc2e5b`「Fix the findings of the V7 review (Z5)」（11 ファイル、+30 / −42。san_benito へは `9f957ce9` で取り込み済み）。
- 根拠: `reviews/2026-10-13-V7/report.md`（M1〜M4、L1〜L7）、AGENTS.md の「設計書の規約」と「レビューの観点」。
- 方法: 差分を読み、変えた章の前後の文脈と CHANGELOG の Unreleased の全体を通読し、`typeck/decls.rs` の `summary`、`typeck/solve.rs`、`external/check.rs`、`diag/codes.rs` と照らした。用語の揺れは `git grep` で調べた。cargo と python は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

M1〜M4 と L1〜L7 はすべて指摘どおりに直り、直しが新しく生んだ食い違いはない。01-06 の判定と要約の手順は実装に一致する。Medium 1 件、Low 4 件（うち 2 件は実装の文言）。

## 指摘

1. N1（Medium）: 01-06「型」の表（19〜27 行）と型の等しさの規則（33〜37 行）が外部の型を挙げていない。表に「外部の型 | 型の名前 | `@external` で宣言した型（01-02「外部の関数の宣言」）」を加え、等しさの規則を「中身を見せない prelude の型、外部の型、代数的データ型は、型の名前が同じで…」とする。
2. N2（Low）: CHANGELOG の Added で、外部の関数を導入する項目より前に外部の型・速い経路・レコードの受け渡しが並ぶ。パッケージの項目、`@external`、実行、外部の型、速い経路、レコード、`--wasm-*`、Wasmtime、C コンパイラの順に並べ替える。
3. N3（Low）: CHANGELOG の「Check and prepare arguments before compiling or instantiating components and processing deferred destruction」を「… or processing deferred destruction」に、「Replace invalid effects with `uses State` in `E0812` repair edits.」を「When such a function declares other effects, the `E0812` repair edit replaces them with `uses State`.」にする。
4. N4（Low、実装の文言）: E0802 の説明「`@external` is written on top-level functions.」を「… on top-level functions and on `type` declarations without a right-hand side.」にし、`gen_skill` で作り直す。
5. N5（Low、実装の文言）: E0406 の説明「Equality is defined only for types without functions and opaque standard library types.」を「… opaque standard library types, and external types.」にする。

## 確かめて問題がなかった点

- M1（Fixed は 0.0.3 の直しの 1 件、最終の仕様は Added に溶け、値は 03-10 と一致）、M2（01-06 の手順は実装の `summary`・解決器・`contains_float` に一致、鍵の型にもならない）、M3（01-02 は 01-07・03-10 と一致）、M4（02-06 の語は 02-09 と同じ）、L1〜L7。
- 01-spec の ` ```text ` のブロックと `###` の見出しは変えていない。
