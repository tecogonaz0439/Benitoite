# 0043. Option と Result をつなぐ関数は Rust の名前に合わせ、中身を無理に取り出す関数は設けない

- 状態: 採択（`Err` を含む名前を [0099](0099-qualified-option-result-constructors.md) で改めた）
- 日付: 2026-09-26
- 関連章: [標準ライブラリ](../03-interop/03-06-stdlib.md), [目的と設計原則](../00-overview/00-01-goals.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-029](../open-issues.md#open-029)

## 背景

`Option` と `Result` をつなぐ操作は、最小実行版から提供する（[ADR 0005](0005-direct-style-effects.md)）。関数の名前は言語によって異なる（Rust の `and_then`・`unwrap_or`、Elm の `andThen`・`withDefault` など）。構文と名前は、LLM による生成・修正の成功率と、人間による読みやすさで選ぶ（[目的と設計原則](../00-overview/00-01-goals.md)）。

Rust の `unwrap` のように、`None` や `Err` のときに実行を止めて中身を取り出す関数は、LLM が書きやすい一方で、実行時エラーの経路を増やす。実行時エラーを起こしうることは、関数の型に現れない（[OPEN-026](../open-issues.md#open-026)）。

## 決定

`Option` と `Result` をつなぐ関数の名前は、Rust の名前を lowerCamelCase にしたものに合わせる（`map`、`andThen`、`unwrapOr`、`mapErr`、`isSome`、`okOr` など）。

`None` や `Err` のときに実行時エラーになる、中身を無理に取り出す関数（`unwrap`、`expect` など）は設けない。中身は、`match` か `unwrapOr` で取り出す。`Option.unwrap` などの存在しない名前を使ったときは、`unwrapOr` と `match` を修正案として示す（[診断エンジン](../02-impl/02-10-diagnostics.md)）。

## 検討した代替案

- **Rust の名前で、`unwrap` も設ける**: LLM が書きやすい。しかし、`None` や `Err` になりうる値を検査なしに取り出すコードが増え、静的に扱える誤りが実行時エラーになる（原則 1）。
- **Elm の名前（`withDefault` など）**: 関数型言語ではよく見る名前である。しかし、LLM の学習データでは Rust の名前より少ないと見込む（確かめていない）。

## 帰結

- 最小実行版のスクリプトでは、`Option` と `Result` の中身を取り出す箇所で、`None` と `Err` の場合の扱いが必ず書かれる。
- OPEN-012 の測定で、LLM が `unwrap` を書いて検査で誤りになる頻度が高ければ、`unwrap` を加えるかを見直す。関数を加えることは、既存のスクリプトの意味を変えない。一方、名前を変えることは既存のスクリプトを壊すので、初回リリース版を利用者に提供した後は、古い名前を残す期間を設けて行う。
- `Err` を呼び出し元へ伝える構文（[OPEN-029](../open-issues.md#open-029)）を設けるかは、別に決める。
