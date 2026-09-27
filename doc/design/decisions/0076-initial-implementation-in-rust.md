# 0076. 処理系は Rust で LLM が実装し、実装言語の見直しの段階を設けない

- 状態: 採択
- 日付: 2026-09-27
- 関連章: [全体像](../00-overview/00-02-architecture.md), [ロードマップ](../00-overview/00-03-roadmap.md), [実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md), [目的と設計原則](../00-overview/00-01-goals.md), [プラグイン基盤](../04-extensions/04-02-plugins-wasm.md), [配布形態](../05-platform/05-01-distribution.md), [モバイル・Android系](../05-platform/05-03-mobile.md), [性能](../07-quality/07-02-performance.md), [先行事例索引](../08-appendix/08-02-prior-art.md)
- 関連する未決事項: [OPEN-016](../open-issues.md#open-016), [OPEN-017](../open-issues.md#open-017), [OPEN-036](../open-issues.md#open-036), [OPEN-037](../open-issues.md#open-037)

## 背景

[ADR 0002](0002-initial-implementation-in-go-by-llm.md) は、初期実装を Go で行い、最小実行版の性能を測定した後に、Go を続けるか Rust・Zig などで再実装するかを決めるとしていた。Go を選んだ主な根拠は、言語の値の回収を Go の GC に任せられることと、v1 の go.* の層で Go の標準ライブラリを自動でラップできることだった（[実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md)）。

その後、次のことが分かった。

- 最小実行版の言語では、値どうしの参照が循環しない（値は変更できず、可変のセルと明示遅延は v1 から加わり、`let` は再帰的な束縛にならない）。このため、最小実行版では参照カウントだけで使わなくなった値を回収でき、GC を Go に任せる利点は最小実行版では決め手にならない。
- 処理系の権限制御を OS のサンドボックスでも強制する方針を採る（[セキュリティモデル](../07-quality/07-01-security-model.md)）。OS の隔離は Go でも使える（Landlock の Go 用ライブラリは、Go のランタイムが管理する全スレッドに設定を適用する）が、ランタイムがスレッドを持たない言語の方が手当ては少ない。
- 処理系は LLM が実装する。Go は直和型を持たず、`switch` の分岐の漏れを言語が検出しないので、構文木・値・命令の種類の扱いで漏れが残りやすい。Rust は列挙型と `match` の網羅の検査、`Option`・`Result` を持ち、これらの誤りの多くを型の検査で見つけられる。
- 処理系を WASM で動かす可能性（[OPEN-007](../open-issues.md#open-007)）がある。Rust は `wasm32-unknown-unknown`・`wasm32-wasip1`・`wasm32-wasip2` を、標準ライブラリを含む Tier 2 の対象として扱う（[Platform Support](https://doc.rust-lang.org/rustc/platform-support.html)、2026-09-27 に確認）。WASM の実行環境の wasmtime と wasmer も Rust で書かれている。
- 実装言語を変える費用は、処理系のコードがまだない今が最も小さい。測定の後に変えると、作った処理系を捨てることになる。

## 決定

1. 処理系は Rust で実装する。ADR 0002 を置き換える。
2. 処理系は LLM が実装プランに従って実装する。設計書と実装プランは Claude Code が作成する。どの LLM がどの部分を実装するかは、実装プランを作る中で決める（[OPEN-017](../open-issues.md#open-017)）。この点は ADR 0002 から変えない。
3. 最小実行版の性能を測定した後に実装言語を見直す段階は設けない。性能の測定は行い、その結果は最適化の要否を決める材料にする。[ADR 0038](0038-reimplementation-judgement-without-threshold.md) を置き換え、[OPEN-016](../open-issues.md#open-016) を決着させる。

## 検討した代替案

- **Go のまま実装し、測定の後に見直す**（ADR 0002）: GC を任せられ、go.* の層を設計どおり作れる。しかし、最小実行版では GC の利点が決め手にならず、go.* の層は権限の検査を漏れなく行うのが難しい（すべての Go の関数が触れる先を分類し続ける必要がある）。見直しで Rust に移るなら、今移る方が費用が小さい。
- **Zig で実装する**: GC を持たず、1.0 の前で言語と標準ライブラリが変わりうる（[実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md)）。

## 帰結

- 言語の値の管理を処理系が行う。最小実行版は参照カウントで行い、循環を回収する方式は v1 で決める（[ADR 0078](0078-reference-counting-in-minimal.md)、[OPEN-036](../open-issues.md#open-036)）。
- go.* の層とラッパー自動生成器は成り立たない（[ADR 0077](0077-abolish-go-layer.md)）。
- 処理系の設計のうち Go のランタイムを前提にした部分（値の表現、スタック、panic 境界、メモリが尽きたときの終わり方など）を、Rust に合わせて読み替える（[ADR 0079](0079-rust-readings-of-go-based-decisions.md)）。
- 実装を担う LLM が Rust で処理系を正しく書けるかは【要検証】であり、[OPEN-017](../open-issues.md#open-017) の試し実装で確かめる。所有権の検査を通すために `clone` を多用したり `unsafe` に頼ったりする誤りを防ぐ規則を、実装プランに入れる。
- ロードマップの「実装言語の見直し」の段階をなくす。
