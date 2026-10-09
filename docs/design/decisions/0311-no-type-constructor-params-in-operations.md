# 0311. エフェクトの操作の型パラメータに、型構成子を表す型パラメータを書けなくする

- 状態: 採択
- 日付: 2026-10-04
- 関連章: [構文](../01-spec/01-02-syntax.md)、[型システム](../01-spec/01-06-type-system.md)
- 関連 ADR: [ADR 0118](0118-effect-handlers.md)、[ADR 0158](0158-type-classes-by-dictionary-passing.md)

## 背景

文法では、エフェクトの操作の宣言は関数の型パラメータの並び（`FnTypeParams`）を使う。そのため、`function make[F[_]]() -> F[Integer]` のように、型構成子を表す型パラメータ（`F[_]`）を書けた。01-06 は、`handle` の節の中で操作の型パラメータを「ほかの何とも等しくない型」として扱うと定める。値の型の型パラメータは、型検査器の `Rigid` の型で表せる。しかし、型構成子の位置に置く「ほかの何とも等しくない型構成子」は、型の内部の表現（実装プランの 10-05 の `Ty`・`TyHead` と推論の `IHead`）にない。実装プランの F09 の実装担当（Codex）が、この点を報告して止まった。

標準ライブラリのソースと仕様の例には、型構成子を表す型パラメータを持つ操作が一つもない。

## 決定

1. エフェクトの操作の型パラメータの並びに、型構成子を表す型パラメータ（`F[_]`）を宣言できない。エフェクト変数を宣言できないのと同じく、構文解析器が E0510 で報告する（鍵 `type_ctor` の注記）。
2. 操作の値の型の型パラメータ（`[T]`）と、その組み込みの制約・型クラスの制約は、これまでどおり書ける。

## 検討した代替案

- **型の内部の表現に「節に固有の型構成子」を加えて許す**: 言語の表現力は保てる。しかし、取り込み済みの型検査（F07・F08）、型の置換（F12）、コア IR の検査（F13）と、未実装の F10・F11 の作業の文書を直す必要があり、手戻りが大きい。使う例もない。設計者は禁止する本案を選んだ。禁止は後で緩めても既存のプログラムを壊さないので、必要になった時点で改めて検討できる。

他の言語の扱いを、2026-10-04 に一次資料で確かめた。エフェクトを言語の構文として持つ言語の多くは、操作の型パラメータを型構成子として宣言する手段を持たない。本案の制限は、これらの言語と同じ側にある。

- OCaml 5 は、エフェクトを拡張可能な GADT（`type _ Effect.t += Xchg: int -> int t`）で宣言する（[OCaml マニュアル「Effects」](https://ocaml.org/manual/5.3/effects.html)）。型の変数はすべて種 `*` であり、型構成子を抽象するにはファンクタを使う（[Yallop & White, Lightweight higher-kinded polymorphism, FLOPS 2014](https://www.cl.cam.ac.uk/~jdy22/papers/lightweight-higher-kinded-polymorphism.pdf) の要旨）。
- Eff の操作の宣言は `effect eff : t1 -> t2` の形で、操作独自の型パラメータの欄がない（公式リポジトリの文法 `grammar.mly`）。
- Effekt の操作は独自の型パラメータを持てるが、型パラメータは名前だけで、種を書く構文がない（公式リポジトリの構文解析器 `Parser.scala`）。
- Unison は高階の種を持つが、種を書く構文がない（[Unison の言語リファレンス「Kinds of types」](https://www.unison-lang.org/docs/language-reference/kinds-of-types/)）。ability の操作の型パラメータを高階にした例は確かめていない。
- Koka は高階の種を持ち、文法の上では操作の型パラメータに種の注釈（`<f :: V -> V>`）を書ける（[Koka の文書](https://koka-lang.github.io/koka/doc/book.html)の文法）。型検査がそれを受け付けるかは、使用例が見つからず確かめていない。
- Haskell のエフェクトのライブラリ（effectful など）は、操作を GADT の構成子として宣言し、エフェクトの種は `(Type -> Type) -> Type -> Type` である（[Hackage の effectful-core](https://hackage-content.haskell.org/package/effectful-core-2.7.1.2/docs/Effectful.html)）。構成子が自分で束縛する高階の型変数は GHC の一般の仕組みから書けると推論できるが、ライブラリでの実例は確かめていない。

## 帰結

- 01-02「エフェクトの宣言とハンドラ（初回リリース版）」と 01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」に制限を加える。
- 実装プランの 10-02 と `src/diag/codes.rs` の E0510 に鍵 `type_ctor` を加える。構文解析器（`syntax/parser/effects.rs` の `push_op`）の変更は F09 が行う。
