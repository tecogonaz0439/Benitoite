# 0077. go.* の層とラッパー自動生成器を廃止し、初回リリース版のライブラリの提供方法は改めて決める

- 状態: 採択（決定 2 の未決事項は [0137](0137-first-release-library-scope.md)・[0138](0138-crates-and-licenses-for-stdlib.md)・[0139](0139-external-functions-via-wasm.md) で決めた）
- 日付: 2026-09-27
- 関連章: [ロードマップ](../00-overview/00-03-roadmap.md), [全体像](../00-overview/00-02-architecture.md), [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [エラー処理](../01-spec/01-09-errors.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [セキュリティモデル](../07-quality/07-01-security-model.md), [用語集](../00-overview/00-04-glossary.md), [ランタイム](../02-impl/02-09-runtime.md), [ライブラリの構成](../03-interop/03-01-library-structure.md), [外部の関数](../04-extensions/04-01-external-functions.md), [配布形態](../05-platform/05-01-distribution.md), [性能](../07-quality/07-02-performance.md), [処理系のテスト戦略](../07-quality/07-03-compiler-testing.md), [実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md)
- 関連する未決事項: [OPEN-035](../open-issues.md#open-035), [OPEN-018](../open-issues.md#open-018)

## 背景

設計メモは、ライブラリを三層（prelude、std、go.*）に分け、go.* の層で Go の標準ライブラリを `go/types` による自動生成でラップして出すとしていた（[設計メモ](../sources/fp-language-design.md) 10、11）。処理系を Rust で実装する（[ADR 0076](0076-initial-implementation-in-rust.md)）と、この層は前提を失う。

また、go.* の層は、Go の関数が直接 OS に触れる経路を利用者に開く。実行時の権限制御が保証として成り立つには、外部に作用するすべての経路が同じ制御を通る必要がある（[セキュリティモデル](../07-quality/07-01-security-model.md)、[OPEN-018](../open-issues.md#open-018)）。

## 決定

1. go.* の層、ラッパー自動生成器、go.* の名前空間を廃止する。[ADR 0036](0036-no-go-layer-in-minimal.md) を置き換える。
2. 初回リリース版のライブラリの提供方法（std を手で書く範囲、処理系の実装で Rust のクレートを使う範囲、外部の関数を呼ぶ層を設けるか）は、初回リリース版のライブラリを設計するときに決める（[OPEN-035](../open-issues.md#open-035)）。
3. Go に依存する未決事項（[OPEN-008](../open-issues.md#open-008)、[OPEN-025](../open-issues.md#open-025)、[OPEN-028](../open-issues.md#open-028)）は、対象がなくなったので決着とする。外部のライブラリの誤りと `Result` の対応などは、OPEN-035 の中で扱う。

## 検討した代替案

- **Rust の標準ライブラリやクレートを自動でラップする層を設ける**: 設計メモの方針に近い。しかし、Rust の標準ライブラリは Go より小さく、型の情報から自動でラップする仕組みも前提にできない。触れる先を分類して権限の検査を漏れなく行う難しさは、go.* の層と同じである。今決めずに、OPEN-035 で比べる。

## 帰結

- 第3部（Go 相互運用）と第4部の Go を前提にした章は、初回リリース版のライブラリの提供方法を決めるときに、構成ごと見直す。それまでは、各章に見直しの対象であることを記す。
- 最小実行版の性能のベンチマークから、go.* の呼び出しの試作（gocall）を外す。
