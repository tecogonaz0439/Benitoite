# 0134. 標準の型クラスを `Benitoite.Trait` に置き、上位の型クラスと戻り値の型で実装を選ぶメソッドを加える（原則 5 の例外）

- 状態: 採択（派生の関数を置かないことを [0171](0171-map-set-higher-order-functions.md) で定めた）
- 日付: 2026-09-28
- 関連章: [型システム](../01-spec/01-06-type-system.md), [構文](../01-spec/01-02-syntax.md), [コア計算と脱糖](../01-spec/01-12-core-calculus.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [目的と設計原則](../00-overview/00-01-goals.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-050](../open-issues.md#open-050), [OPEN-046](../open-issues.md#open-046), [OPEN-035](../open-issues.md#open-035), [OPEN-012](../open-issues.md#open-012)

## 背景

初回リリース版には型クラスがあり、型構成子を引数にとる型クラスも利用者が定義できる（[ADR 0060](0060-trait-and-impl-syntax.md)、[ADR 0059](0059-higher-kinded-traits-without-prelude-monad.md)）。しかし、標準ライブラリには型クラスが一つもない。ADR 0059 は、prelude に `Functor`・`Monad` を入れると、同じ操作に `Option.map` と `Functor.map` の二つの書き方ができ、原則 5（同じ役割の構文を、必要な理由なく増やさない）に反するとした。

型クラスの宣言には、次の制限がある（[型システム](../01-spec/01-06-type-system.md)の【方針】）。

- 上位の型クラスを持たない。
- メソッドの既定の実装を持たない。
- 型クラスの引数を戻り値の型にだけ含むメソッドと、引数のないメソッドを禁じる。

`Monoid` の `empty` と `Applicative` の `pure` は、戻り値の型だけで実装を選ぶメソッドなので、この制限の下では書けない。

言語の実質的な目的は、設計者が関数型プログラミングを学ぶことである（[目的と設計原則](../00-overview/00-01-goals.md)）。`Functor`・`Applicative`・`Monad` の階層、`Semigroup`・`Monoid`、`Foldable`・`Traversable` は、関数型プログラミングの標準の抽象である。これらが標準ライブラリにあれば、設計者は、処理系の実装（辞書渡し、上位の型クラスの辞書、戻り値の型による実装の選択）と、標準の型への実装を読んで学べる。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「標準の型クラス」に記録した。要点は次のとおりである。

- Haskell（GHC の base）・PureScript・Flix・Idris 2 は、`Show`、`Eq` ⊂ `Ord`、`Semigroup` ⊂ `Monoid`、`Functor` ⊂ `Applicative` ⊂ `Monad` を標準に置く。Lean 4 は `Monoid` を核に置かない。Scala 3 の標準ライブラリは `Functor`・`Monad` を持たない。
- `Applicative` か `Monoid` を置く言語は、どれも `pure`・`empty` のように戻り値の型だけで実装を選ぶメソッドを持つ。
- PureScript は既定の実装を持たず、型クラスを小さく保ち、派生の操作を普通の関数にしている。

## 決定

1. **原則 5 の例外とする。** 標準の型クラスのメソッドは、既存の関数（`Option.map` と `Trait.Functor.map` など）と同じ役割を持つ。学習の目的のために、この重複を例外として認める。原則そのものは変えない。重複する既存の関数を隠すかは、実装した後に評価して決める（[OPEN-050](../open-issues.md#open-050)）。
2. 標準の型クラスは、標準ライブラリのモジュール `Benitoite.Trait` に置く。prelude には入れない（ADR 0059 は変わらない）。使うには `import Benitoite.Trait` と書き、型クラスは `Trait.Monad`、メソッドは `Trait.Monad.flatMap(x, f)` と書く。
3. 置く型クラスは次の九つとする。比較の結果を表す型 `Ordering`（構成子は `Ordering.Less`・`Ordering.Equal`・`Ordering.Greater`）も `Benitoite.Trait` に置く。

   | 型クラス | メソッド | 上位の型クラス |
   |---|---|---|
   | `Show[T]` | `show(x: T): String` | — |
   | `Order[T]` | `compare(x: T, y: T): Ordering` | — |
   | `Semigroup[T]` | `combine(x: T, y: T): T` | — |
   | `Monoid[T]` | `empty(): T` | `Semigroup` |
   | `Functor[F[_]]` | `map(x: F[A], f: function(A) -> B uses E): F[B] uses E` | — |
   | `Applicative[F[_]]` | `pure(x: A): F[A]`、`apply(fs: F[function(A) -> B uses E], x: F[A]): F[B] uses E` | `Functor` |
   | `Monad[F[_]]` | `flatMap(x: F[A], f: function(A) -> F[B] uses E): F[B] uses E` | `Applicative` |
   | `Foldable[F[_]]` | `fold(x: F[A], initial: B, f: function(B, A) -> B uses E): B uses E` | — |
   | `Traversable[F[_]]` | `traverse[G[_]: Applicative](x: F[A], f: function(A) -> G[B] uses E): G[F[B]] uses E` | `Functor`、`Foldable` |

   表の `A`・`B` はメソッドの型パラメータ、`E` はメソッドのエフェクト変数である。等値の型クラス（`Equal`）は置かない。等値は組み込みの `=` と制約 `equality`（[ADR 0133](0133-builtin-equality-and-key-constraints.md)）で扱う。`Hash`、数の型クラス、`Read`・`Bounded`・`Enum` も置かない。
4. 型クラスは、上位の型クラスを持てる。`trait Monoid[T: Semigroup]` のように、型クラスの引数に制約の形で書く。`C` の上位の型クラスが `S` のとき、型 `T` についての `C` の制約は、`T` についての `S` の制約を含む。`implement C[X]` を書くには、`S[X]` の制約が（実装の型パラメータの制約の下で）解けなければならない。上位の型クラスの関係が循環すると誤りとする。
5. メソッドは、型クラスの引数を、引数の型か戻り値の型の少なくとも一つに含めばよい。引数のないメソッド（`empty()`）も書ける。戻り値の型だけに含むメソッドの実装は、呼び出した位置で求める型から選ぶ。型が決まらなければ、ほかの型クラスの制約と同じく誤りとし、診断は型注釈を書くよう示す。
6. メソッドの既定の実装は、初回リリース版では加えない。派生の操作は、`Benitoite.Trait` の普通の関数として置く。どの関数を置くかは、標準ライブラリの範囲とともに決める（[OPEN-035](../open-issues.md#open-035)）。
7. 標準ライブラリの型に、次の実装を置く。

   | 型クラス | 実装する型 |
   |---|---|
   | `Show`・`Order` | 基本型、`List`・`Option`・`Pair`・`Triple`（要素の型が実装を持つとき） |
   | `Show` | `Map`・`Set`（鍵・要素・値の型が実装を持つとき） |
   | `Semigroup`・`Monoid` | `String`・`List`・`Map`・`Set` |
   | `Functor`・`Applicative`・`Monad`・`Foldable`・`Traversable` | `Option`・`List` |

8. 利用者の型に実装を導出する仕組みは、初回リリース版では加えない。利用者の型の実装は `implement` で書く。導出は、プロパティベーステストの入力の生成器の導出と同じ仕組みで作れるので、[OPEN-046](../open-issues.md#open-046) で一緒に決める。
9. 演算子と文字列補間は、これまでどおり型クラスに移さない（[ADR 0062](0062-operators-stay-outside-traits.md)）。`Order` を実装しても `<` は使えず、`Show` を実装しても文字列補間には埋め込めない。

## 検討した代替案

- **標準の型クラスを置かない**: 原則 5 に反しない。しかし、設計者が標準の抽象とその実装を処理系の中で読んで学ぶ機会がなくなる。
- **prelude に置く**: import なしで使える。しかし、普段のスクリプトで LLM が `Option.map` と `Functor.map` のどちらを書くかがぶれる。`Order`・`Show` は、利用者の型の名前（注文の `Order` など）とぶつかりやすい。import を要すれば、重複が現れる範囲を、型クラスを使う場面に限れる。
- **型クラスごとにモジュールを分ける（`Benitoite.Trait.Monad`）**: import の粒度は細かくなる。しかし、型クラスの名前は同じ名前のモジュールを兼ねるので、`Monad.Monad.flatMap` のように名前が重なる。
- **既定の実装を加える**: `Foldable` に `length` などを既定の実装として持たせられる。しかし、型クラスの宣言と辞書の作り方の規則が増える。PureScript のように普通の関数で書けば、既定の実装は要らない。
- **`Result` の片方の引数を固定して `Functor` などを実装できるようにする**: `Result` のモナドを使える。しかし、型の部分適用か型の関数が要り、型推論の規則が大きく増える。

## 帰結

- 設計者は、`Benitoite.Trait` の型クラスと実装を使い、処理系の辞書渡しの実装を読んで学べる。
- 上位の型クラスと、戻り値の型で実装を選ぶメソッドは、利用者が定義する型クラスでも使える。
- `Result[T, X]` は型引数を二つとるので、`Functor` などの型構成子を引数にとる型クラスを実装できない（型の部分適用がない）。
- `Float` の `Order` は全順序とし、NaN をどの値よりも大きく、NaN どうしを等しく、`0.0` と `-0.0` を等しくする。`=` の結果（NaN は自分自身と等しくない）とは異なる。
- 標準の型クラスを使うコードの生成の成功率を [OPEN-012](../open-issues.md#open-012) の測定の対象に含める。
