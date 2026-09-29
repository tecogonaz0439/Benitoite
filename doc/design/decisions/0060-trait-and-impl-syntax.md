# 0060. 型クラスは `trait` で宣言し、`impl` で実装し、メソッドは型クラスの名前で修飾して呼ぶ

- 状態: 採択（キーワードの綴りを [0092](0092-unabbreviated-keywords.md) で改めた。宣言の書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた）
- 日付: 2026-09-26
- 関連章: [型システム](../01-spec/01-06-type-system.md), [構文](../01-spec/01-02-syntax.md), [字句構造](../01-spec/01-01-lexical.md), [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

初回リリース版では、辞書渡しで実装する型クラスを加える（[ロードマップ](../00-overview/00-03-roadmap.md)）。`class`・`instance`・`trait`・`impl` は、いずれも最小実行版で予約語にしてある（[字句構造](../01-spec/01-01-lexical.md)）。`Option`・`Result` をつなぐ関数の名前は、Rust の名前に合わせた（[ADR 0043](0043-option-result-rust-names-no-unwrap.md)）。ドットは、モジュールと型名の修飾にだけ使う（[ADR 0004](0004-surface-syntax-skeleton.md)）。

## 決定

1. 型クラスは `trait Show[T] { fn show(x: T) -> String }` の形で宣言し、`impl Show[Person] { fn show(x: Person) -> String { ... } }` の形で実装する。`trait` と `impl` をキーワードにする。
2. メソッドは、型クラスの名前で修飾して呼ぶ（`Show.show(p)`）。どの実装を使うかは、引数の型から決まる。
3. 関数の型パラメータに型クラスの制約を付けるときは、`fn describe[T: Show](x: T) -> String` の形で書く。

## 検討した代替案

- **`class` と `instance`（Haskell 風）**: 型クラスの教科書と同じ語である。しかし、`class` はオブジェクト指向のクラスと読まれやすく、LLM がフィールドやメソッドを持つクラスを書く誤りを誘いやすい。
- **メソッドを修飾せずに呼ぶ**: 書く量は減る。しかし、名前がどこから来たかをその場で読み取れなくなり、prelude とモジュールを常に修飾して使う規則と揃わない。

## 帰結

- `impl Person { ... }` のように、型クラスなしでメソッドを定義する Rust の書き方を LLM が書いたときは、構文エラーとし、トップレベルの関数と型のモジュールで書く方法を修正案として示す。
- 型クラスの名前は、型・モジュール・エフェクトと同じ大文字の名前空間に入る（[ADR 0010](0010-shared-namespace-and-shadowing.md)）。
- `trait`・`impl` の書き方の生成の成功率を [OPEN-012](../open-issues.md#open-012) の測定の対象に含める。
