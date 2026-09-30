# L01 `Character`・`String` の Unicode の関数

- 依存する作業: [L00](L00-u3-interfaces.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L01-unicode-functions

## 目的

Unicode の文字の性質による分類と、大文字・小文字の変換の 9 の組み込みの関数の本体を書く（[ADR 0169](../../design/decisions/0169-unicode-character-property-functions.md)）。10-15 の部分 22（`character::UNICODE_DECLS`）と部分 23（`string::UNICODE_DECLS`）であり、L00 が置いた仮の本体を置き換える。

| 部分 | 項目 | 権限 |
|---|---|---|
| 22 | `Character.isAlphabetic`・`isNumeric`・`isWhitespace`・`isUppercase`・`isLowercase`・`toUppercase`・`toLowercase` | `Pure` |
| 23 | `String.toUppercase`・`toLowercase` | `Pure` |

## 読む設計書の節

- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「Character」「String」の表の初回リリース版の行と、表の後の【決定】（地域に依らない変換、従う Unicode の版）、「作る値の大きさの上限」
- [基本型の意味論](../../design/01-spec/01-04-types-basic.md)の「Character」「String」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」
- ADR: [0169](../../design/decisions/0169-unicode-character-property-functions.md)、[0049](../../design/decisions/0049-size-limit-for-built-values.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「prelude の基本型」の表と、`Character.bnt`・`String.bnt` に加えた宣言
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `builtin!` と `pure` の関数の形
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「大きさを確かめる構築」（`StrBuf`・`alloc_str_buf`）

## 作るもの

- `src/builtins/funcs/character.rs` の `UNICODE_DECLS` の 7 項目の本体と単体テスト
- `src/builtins/funcs/string.rs` の `UNICODE_DECLS` の 2 項目の本体と単体テスト

## 手順の要点

- 分類は Rust の標準ライブラリの `char` の関数で行う。`isAlphabetic` は `char::is_alphabetic`（Alphabetic）、`isNumeric` は `char::is_numeric`（一般カテゴリ Nd・Nl・No）、`isWhitespace` は `char::is_whitespace`（White_Space）、`isUppercase`・`isLowercase` は `char::is_uppercase`・`is_lowercase`（Uppercase・Lowercase）である。対応を確かめ、各関数の `///` のコメントに書く。
- `Character.toUppercase`・`toLowercase` は `char::to_uppercase`・`to_lowercase` の文字を連結した文字列である。`String.toUppercase` は、各文字を `Character.toUppercase` で変換して連結する（03-06 の表）。`String.toLowercase` は `str::to_lowercase` を使う。語の終わりのシグマを `ς` にする規則（03-06）を、`str::to_lowercase` が満たすことを単体テストで確かめる。
- 変換で文字列が長くなる（`'ß'` が `"SS"` になるなど）ので、結果の大きさを確かめてから確保する。`StrBuf` に積み、上限（2^30 バイト）を超えたら資源の不足で止まる（03-06「作る値の大きさの上限」）。
- 処理系が従う Unicode の版は、Rust 1.98.1 の標準ライブラリの版である（03-06）。`benitoite --version` の出力に版を示すのは F18 の範囲であり、本作業は変えない。

## 受け入れテスト

- 項目ごとの単体テスト（10-12「確かめること」）: 分類の関数に、ASCII の文字、ASCII でない文字（`'é'`・`'Ω'`・`'中'`・`'٣'`（Arabic-Indic の 3）・`'Ⅻ'`（ローマ数字、Nl）・`'½'`（No）・U+3000（全角の空白）・U+00A0）を与え、03-06 の定義どおりの値を返す。
- 変換: `'ß'` の大文字が `"SS"`、`'İ'`（U+0130）の小文字が 2 文字の文字列、対応のない文字（`'1'`）がその文字だけの文字列。`String.toLowercase("ΣΑΣ")` が語の終わりのシグマを `ς` にした `"σας"`、`String.toUppercase("straße")` が `"STRASSE"`。
- 大きさの上限: 上限に近い長さの文字列を大文字にすると長さが上限を超える入力で、資源の不足（`ValueTooLarge`）になり、値を作らない。この入力は上限を小さくできないので、`StrBuf` の上限の判定を通る経路で確かめる（10-08「大きさを確かめる構築」のテストの形に合わせる）。
- 10-15 の宣言と項目の名前・権限・引数の数が一致し続ける（L00 の照合のテストが通る）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と、部分の中の位置を変えていない
- 分類の関数と Unicode の性質の対応を、完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、変換の結果の大きさを値を作る前に確かめているか。
- 分類の関数が、ASCII の範囲だけの関数（`isASCIIDigit` など）と混ざっていないか。

## 難易度の理由

Rust の標準ライブラリの関数を包むだけであり、判断は Unicode の性質との対応と、大きさの上限の確かめに限られる。
