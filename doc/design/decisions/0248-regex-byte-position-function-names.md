# 0248. `Regex` の一致の位置を返す関数の名前を `matchByteStart`・`matchByteEnd` にする

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [テキストとデータの処理](../03-interop/03-08-text-and-data.md)
- 関連する未決事項: なし

## 背景

[テキストとデータの処理](../03-interop/03-08-text-and-data.md)の「共通の規則」は、文字列の位置の名前に単位を含め、バイト位置を返すものは名前に `byte` を含めると定める。`String` の文字の位置と取り違えないためである。一方、一致の全体の位置を取り出す関数は `Regex.matchStart`・`Regex.matchEnd` とした（[ADR 0168](0168-regex-match-and-stdlib-opaque-values.md) の決定 2）。この二つはバイト位置を返すが、名前に単位を含まない。

外部のレビュー（Codex による 2 回目の設計書のレビュー）で、この食い違いが指摘された。

## 決定

1. `Regex.matchStart` を `Regex.matchByteStart` に、`Regex.matchEnd` を `Regex.matchByteEnd` に改める。型と振る舞いは変えない。
2. ADR 0168 の決定 2 の関数の名前を、1 の名前に読み替える。

## 検討した代替案

- **今の名前のままにし、共通の規則に例外を書く**: 名前は短い。しかし、`Regex.Match` の位置を `String` の文字の位置の関数に渡す誤りを、名前から気付けなくなる。共通の規則は、この種の取り違えを防ぐために置いたものである。

## 帰結

- [テキストとデータの処理](../03-interop/03-08-text-and-data.md)の「Regex」の表、位置の説明、`Regex.replaceAllWith` の説明の名前を改める。
- Agent Skill のリファレンスなど、API の名前を示す文書は 1 の名前を使う。
