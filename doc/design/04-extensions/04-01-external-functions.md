# 外部の関数

- 状態: 草稿
- 関連ADR: [0077](../decisions/0077-abolish-go-layer.md), [0093](../decisions/0093-no-reserved-words-for-absent-constructs.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0126](../decisions/0126-import-by-module-name.md), [0137](../decisions/0137-first-release-library-scope.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0254](../decisions/0254-return-type-after-arrow.md)
- 未決事項: [OPEN-051](../open-issues.md#open-051), [OPEN-052](../open-issues.md#open-052), [OPEN-012](../open-issues.md#open-012)
- 移行元: [設計メモ](../sources/fp-language-design.md) 17, 0.2

## 目的と範囲

標準ライブラリにない機能を、利用者が外部の関数として呼ぶための言語の表面（宣言の書き方、外部の関数の型とエフェクト、権限との関係）を定める。外部の関数の層は、初回リリース版の後に実装する（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。本章は、後から加えたときにそれまでのスクリプトを壊さないように、言語の表面を先に定める。WASM の実行環境と、ホストの関数の呼び出しの規約は[プラグイン基盤](04-02-plugins-wasm.md)で扱う。

## 前提

設計メモの外部 Go ライブラリの層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。外部に作用する経路は、処理系の IO 実行器を通らなければならない（[ライブラリの構成](../03-interop/03-01-library-structure.md)の「外部に作用する関数の規則」、[セキュリティモデル](../07-quality/07-01-security-model.md)）。

## 仕様

### 対象

【決定】外部の関数の対象は、WASM のモジュールの関数だけとする。C の ABI の共有ライブラリを呼ぶ経路は設けない（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。ネイティブのコードは IO 実行器を通らずに外部に作用できるので、実行時の権限制御が保証として成り立たなくなるからである。

Rust のクレートの機能は、クレートを WASM のモジュールにビルドすれば、外部の関数として使える。Rust の関数の呼び出し規約は安定していない（Rust の言語リファレンスは「The Rust ABI offers no stability guarantees.」と書く）ので、別にビルドしたクレートを処理系が直接読み込むことはしない。

### 宣言

【決定】外部の関数は、本体のない関数の宣言に属性 `@external("wasm", "モジュールのパス", "関数の名前")` を付けて宣言する（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。

```text
@external("wasm", "Lib/markdown.wasm", "render")
function renderMarkdown(source: String) -> String
```

- 最初の引数は対象の種類であり、`"wasm"` だけを書ける。後の版で対象を加えられるように、引数として残す。
- モジュールのパスは、根のディレクトリからのパスとし、根のディレクトリの下に限る（import と同じ。[ADR 0126](../decisions/0126-import-by-module-name.md)）。
- 関数の型の注釈（引数の型、戻り値の型、エフェクト）は省略できない。

### エフェクトと権限

【決定】WASM のモジュールが外部に作用できるのは、処理系が与えるホストの関数だけである。ホストの関数は標準ライブラリの IO の操作であり、IO 実行器と実行時の権限制御を通る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。

- 外部の関数の型のエフェクトは、そのモジュールが取り込むホストの関数のエフェクトを含まなければならない。
- ホストの関数を取り込まないモジュールの関数は、純粋な関数として宣言できる。上の例の `renderMarkdown` はこれに当たる。
- 外部の関数のために、新しいキーワード、エフェクト、権限の種類は設けない。ホストの関数が行う操作は、実行時の権限制御で許可したものに限られる。許可の与え方は、実行時の権限制御の方式とあわせて [OPEN-052](../open-issues.md#open-052) で決める。

### 初回リリース版での扱い

【決定】初回リリース版の処理系は、`@external` を知らない属性として誤りにする（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。書ける属性は ADR で定めたものに限られ（[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md)）、本体のない関数の宣言は、初回リリース版では標準ライブラリのソースの `@builtin` を付けた宣言に限られ、利用者のソースでは誤りである（[構文](../01-spec/01-02-syntax.md)、[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。したがって、後の版で外部の関数の層を加えても、それまでのスクリプトの意味は変わらない。予約語は加えない（[ADR 0093](../decisions/0093-no-reserved-words-for-absent-constructs.md)）。

【未決】WASM の値と言語の値の対応、外部の関数の失敗と `Result` の対応、与えるホストの関数の範囲、ホストの関数の操作と言語のハンドラの関係、WASM の実行とタスクの切り替え・中断の要求の関係、WASM の実行環境の選定、実行の資源の上限、処理系に機能を組み込んでビルドし直す経路は、[OPEN-051](../open-issues.md#open-051) で決める。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ホストの関数の許可の与え方）
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（外部の関数の宣言の書き方）
