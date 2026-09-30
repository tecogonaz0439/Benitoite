# 0169. Unicode の文字の性質に依る関数を初回リリース版の標準ライブラリに入れる

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [標準ライブラリ](../03-interop/03-06-stdlib.md)
- 関連する未決事項: なし

## 背景

最小実行版では、大文字と小文字の変換、文字の分類など、Unicode の文字の性質の規則に依る関数を初回リリース版に回し、文字を分類する関数は ASCII の範囲だけを扱った（[ADR 0042](0042-minimal-prelude-scope.md)）。ところが、初回リリース版の標準ライブラリの範囲（[ADR 0137](0137-first-release-library-scope.md)）と関数の一覧には、これらの関数が入っていなかった。この抜けは、03-interop の整合の確認で見つかった。大文字と小文字をそろえて比べる、英字だけを取り出すといった処理は、テキストを扱うスクリプトでよく行う。

## 決定

1. 初回リリース版の prelude に、次の関数を加える。どれも組み込みで実装し、Rust の標準ライブラリの `char` と `str` の対応する関数を使う。
   - `Character.isAlphabetic`・`Character.isNumeric`・`Character.isWhitespace`・`Character.isUppercase`・`Character.isLowercase`（文字の分類）
   - `Character.toUppercase`・`Character.toLowercase`（文字の変換。結果は `String`）
   - `String.toUppercase`・`String.toLowercase`（文字列の変換）
2. 分類は、Unicode の文字の性質（Alphabetic・White_Space・Uppercase・Lowercase の各性質と、一般カテゴリの Nd・Nl・No）で定める。変換は、Unicode の文字の対応（特殊な対応を含み、地域に依らないもの）で定める。一つの文字が複数の文字に変わることがある（`ß` の大文字は `SS`）ので、`Character` の変換の結果は `String` とする。
3. 従う Unicode の版は、処理系を作った Rust の標準ライブラリが従う版とする。処理系は、その版を `benitoite --version` の出力に示す。
4. 最小実行版の ASCII の関数（`Character.isASCIIDigit`・`Character.isASCIIWhitespace`、ASCII の空白を除く `String.trim`）は、そのまま残す。

## 検討した代替案

- **後の版に送る**: 標準ライブラリの範囲は小さく保てる。しかし、スクリプトで頻繁に使う処理を、正規表現や文字の番号の比較で書くことになる。LLM が書くコードは、他の言語にある `toUpperCase` などを前提にすることが多く、ない関数を呼ぶ誤りを招きやすい。
- **`Character` の変換の結果を `Character` にし、一つの文字への対応（単純な対応）だけを使う**: 型は簡単になる。しかし、`Character.toUppercase` と `String.toUppercase` の結果が食い違い（`ß` を含む文字列など）、利用者にとって分かりにくい。

## 帰結

- 分類と変換の結果は、処理系を作った Rust の版によって変わりうる（Unicode の版が上がり、新しい文字に性質が付いた場合）。最小実行版の関数の結果が Unicode の版に依らないこと（ADR 0042 の帰結）は、ASCII の関数についてだけ保つ。
- `String.toUppercase` と `String.toLowercase` は、結果の長さが元より長くなりうるので、作る値の大きさの上限（[ADR 0049](0049-size-limit-for-built-values.md)）の対象に含める。
