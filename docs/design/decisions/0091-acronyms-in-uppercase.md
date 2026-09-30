# 0091. 名前の中の頭字語は大文字のまま書き、小文字で始まる名前の先頭に置くときだけ小文字で書く

- 状態: 採択（`FSWriteCap` の例を [0101](0101-unabbreviated-names.md) で改めた）
- 日付: 2026-09-27
- 関連章: [標準ライブラリ](../03-interop/03-06-stdlib.md), [エフェクト](../01-spec/01-07-effects.md), [エラー処理](../01-spec/01-09-errors.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

prelude と、初回リリース版で加える型の名前には、頭字語（acronym。IO、UTF-8、ASCII、FS など、語の頭文字を並べた略語）を含むものがある。これまでの設計書では、頭字語の書き方が揃っていなかった。エフェクトの名前は `IO` と大文字のまま書き、型の名前は `IoError`・`IoErrorKind` と頭字語を一つの単語として先頭だけを大文字にしていた。構成子の `IoErrorKind.InvalidUtf8`、関数の `Char.isAsciiDigit`、ケーパビリティの型の `FsWriteCap` も、頭字語を一つの単語として書いていた。

既存の言語の慣習は二つに分かれる。Haskell は `IO`・`IOError`・`IORef` と頭字語を大文字のまま書く。Rust の命名の規約と Elm は、頭字語を一つの単語として扱う（`IoSlice`、`Html`）。これらの言語の慣習は、一次資料で確かめていない。

## 決定

1. 名前の中の頭字語は、すべて大文字で書く（`IO`、`IOError`、`IOErrorKind`、`IOErrorKind.InvalidUTF8`、`FSWriteCap`、`Char.isASCIIDigit`）。
2. 小文字で始まる名前（関数、引数、局所変数）の先頭に頭字語を置くときは、頭字語をすべて小文字で書く（`ioError`、`Caps.fsWrite`）。先頭の文字で名前の種類を分ける規則（[字句構造](../01-spec/01-01-lexical.md)）を守るためである。
3. この規則は、prelude と std の名前に適用する。利用者が付ける名前に対しては、処理系は規則を検査しない。

## 検討した代替案

- **頭字語を一つの単語として扱う（`Io`、`IoError`、`Json`）**: 規則が単純で、頭字語が続いても単語の切れ目が読める（`HttpUrl`）。しかし、エフェクトの宣言が `uses Io` になり、多くの言語で見慣れた `IO` と違う形になる。
- **2 文字の頭字語だけを大文字のまま書く（.NET の流儀。`IO`、`IOError`、`Json`）**: いまの `IO` を変えずに済む。しかし、頭字語の長さによって書き方が変わり、規則が一つ増える。

採った案の弱点は、頭字語が続くと単語の切れ目が読みにくくなること（`HTTPURL`）である。prelude と std に頭字語の続く名前が必要になったときは、名前を言い換えて頭字語が続かないようにする。

## 帰結

- 設計書の `IoError`・`IoErrorKind`・`InvalidUtf8`・`isAsciiDigit`・`isAsciiWhitespace`・`FsWriteCap` を、`IOError`・`IOErrorKind`・`InvalidUTF8`・`isASCIIDigit`・`isASCIIWhitespace`・`FSWriteCap` に改める。これらの名前を定めた ADR 0011・0042・0048・0065・0070 の本文は書き換えず、状態欄に本 ADR で改めたことを記す。
- 最小実行版の処理系（prelude の名前、ゴールデンテスト、診断の文面）と[言語リファレンス](../../reference/benitoite-minimal.md)は、旧い表記（`IoError`、`Char.isAsciiDigit` など）のままであり、設計の段階では直さない。初回リリース版の処理系は、設計書の表記に従う。処理系の Rust の識別子（Rust の型 `IoError` など）は Rust の命名の規約に従い、本 ADR の対象にしない。
- 頭字語の書き方で LLM の書き誤りの率が変わるかを、[OPEN-012](../open-issues.md#open-012) の測定の対象に含めるかは【未決】である。
