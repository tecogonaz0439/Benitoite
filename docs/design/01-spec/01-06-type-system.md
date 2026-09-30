# 型システム

- 状態: 確定
- 関連ADR: [0004](../decisions/0004-surface-syntax-skeleton.md), [0005](../decisions/0005-direct-style-effects.md), [0008](../decisions/0008-effect-variables.md), [0009](../decisions/0009-typing-without-type-classes.md), [0046](../decisions/0046-effect-subsumption-at-all-flow-positions.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0055](../decisions/0055-top-level-functions-and-types-only.md), [0058](../decisions/0058-string-interpolation-of-base-types.md), [0059](../decisions/0059-higher-kinded-traits-without-prelude-monad.md), [0060](../decisions/0060-trait-and-impl-syntax.md), [0061](../decisions/0061-trait-coherence-orphan-and-overlap.md), [0062](../decisions/0062-operators-stay-outside-traits.md), [0063](../decisions/0063-ref-cells-with-io-effect.md), [0066](../decisions/0066-explicit-laziness-pure-body.md), [0082](../decisions/0082-equality-type-by-declaration-summary.md), [0092](../decisions/0092-unabbreviated-keywords.md), [0094](../decisions/0094-return-type-after-colon.md), [0096](../decisions/0096-explicit-return.md), [0098](../decisions/0098-constraints-joined-by-ampersand.md), [0103](../decisions/0103-map-and-set-ordered-by-key.md), [0105](../decisions/0105-byte-type.md), [0113](../decisions/0113-div-and-mod-operators.md), [0114](../decisions/0114-decimal-type.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0118](../decisions/0118-effect-handlers.md), [0123](../decisions/0123-top-level-constants.md), [0124](../decisions/0124-type-aliases.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0133](../decisions/0133-builtin-equality-and-key-constraints.md), [0134](../decisions/0134-standard-type-classes.md), [0136](../decisions/0136-map-and-set-in-constants.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0155](../decisions/0155-resume-not-in-lazy.md), [0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0256](../decisions/0256-data-keyword-for-algebraic-types.md), [0257](../decisions/0257-match-with-case-arms.md), [0272](../decisions/0272-list-spread-in-list-literals.md), [0279](../decisions/0279-no-duplicate-method-names-in-trait.md), [0297](../decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-046](../open-issues.md#open-046), [OPEN-050](../open-issues.md#open-050)
- 移行元: [設計メモ](../sources/fp-language-design.md) 2.1–2.4

## 目的と範囲

型の種類と型の等しさ、型の推論と型注釈、関数の型が持つエフェクトとその多相、演算子と等値の型付け、型クラスを定める。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲と、初回リリース版の文字列補間の型付け、組み込みの制約、型クラスと標準の型クラス、可変状態を定める。レコードの型付けは[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

## 前提

型とシグネチャの文法は[構文](01-02-syntax.md)で、基本型の値と演算の意味は[基本型の意味論](01-04-types-basic.md)で、代数的データ型とパターンの型付けは[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。名前がどの束縛を指すかは[名前・スコープ・モジュール](01-03-names-modules.md)の規則で決まっているものとする。IO エフェクトを持つ組み込み関数と、IO エフェクトの意味は[エフェクト](01-07-effects.md)で定める。

本章では、型検査の誤りを単に「誤り」と書く。誤りを一つでも含むプログラムは実行しない。

## 仕様

### 型

【方針】型は次のいずれかである。

| 型 | 書き方 | 例 |
|---|---|---|
| 基本型 | 型の名前 | `Integer`、`String`、`Unit`、初回リリース版の `Byte`・`Decimal` |
| 代数的データ型（初回リリース版のレコードを含む） | 型の名前と型引数 | `Shape`、`Tree[Integer]`、`Option[String]` |
| リストとコレクション | `List[T]`、初回リリース版の `Map[K, V]`・`Set[T]`・`Bytes` | `List[Integer]`、`Map[String, Integer]` |
| 中身を見せない prelude の型（opaque type） | 型の名前と型引数 | `IOError`（[エフェクト](01-07-effects.md)）、初回リリース版の `Reference[Integer]`、`Lazy[String]` |
| 関数の型 | `function(引数の型, ...) -> 戻り値の型` と、任意の `uses` | `function(Integer) -> Integer`、`function(String) -> Unit uses Console.Write` |
| 型パラメータ | 関数の宣言または型の宣言（[代数的データ型とパターンマッチ](01-05-data-types.md)）で宣言した名前 | `T` |
| 型構成子を表す型パラメータの適用（初回リリース版） | 型構成子を表す型パラメータと型引数 | `F[A]`（後述の「高カインド型（初回リリース版）」） |

推論の途中では、まだ決まっていない型を表す型変数が現れる。型変数は利用者が書く型には現れない。

本章で多相な名前の型を示すときは、`function[T: Show](T) -> String` のように、`function` の後に型パラメータの並びを書く。これは多相な名前の型を説明するための記法であり、利用者が型として書くことはできない。

【方針】二つの型は、次の場合に等しい。

- 中身を見せない prelude の型と代数的データ型は、型の名前が同じで、対応する型引数がすべて等しいときに等しい（`Reference[Integer]` と `Reference[String]` は等しくない）。構成子が同じ形でも、名前の違う型は等しくない。初回リリース版のレコードの型も、代数的データ型と同じく扱う。
- 関数の型は、引数の個数が同じで、対応する引数の型、戻り値の型、エフェクトの集合がすべて等しいときに等しい。エフェクトの集合は、書く順序によらない。
- 型パラメータは、同じ宣言の同じ型パラメータとだけ等しい。
- 初回リリース版の型構成子を表す型パラメータの適用 `F[A1, ..., An]` は、`F` が同じ宣言の同じ型パラメータで、対応する型引数がすべて等しいときに等しい。

【決定】初回リリース版の型の別名は、右辺の型を型引数で置き換えて展開した型と等しい（[ADR 0124](../decisions/0124-type-aliases.md)）。二つの型を比べる前に、別名をすべて展開する。後述の「型の別名（初回リリース版）」を参照。

型のあいだにサブタイピングはない。関数の型のエフェクトについてだけ、後述の「エフェクトの包含」の規則が働く。

### 関数の型とエフェクト

【決定】関数の型は、呼び出したときに起こりうるエフェクトの集合を持つ（[ADR 0005](../decisions/0005-direct-style-effects.md)、[ADR 0008](../decisions/0008-effect-variables.md)）。集合の要素は、エフェクトの名前とエフェクト変数である。最小実行版のエフェクトの名前は `IO` だけである。初回リリース版のエフェクトの名前は、組み込みのエフェクト（`Console.Write`・`File.Read` など。[エフェクト](01-07-effects.md)）と、利用者が宣言したエフェクトである。初回リリース版の `IO.All` は、`State` と `Benitoite.IO` の下の組み込みのエフェクトをまとめた名前であり、型を比べる前に、まとめたエフェクトの名前の集合に置き換える（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。ネットワークのエフェクトと `Assert.Check` は `IO.All` に含まない（[エフェクト](01-07-effects.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。`uses` を書かない関数の型のエフェクトは空集合であり、そのような関数を純粋であるという。

【決定】初回リリース版のエフェクトの名前は、エフェクトを宣言したモジュールの中では修飾せずに（`Log`）、ほかのモジュールからはモジュールの名前で修飾して（`Logging.Log`、`Console.Write`）書く（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。二つのエフェクトの名前は、宣言したモジュールと名前の組が同じときに等しい。修飾に使った取り込みの名前が違っても、同じモジュールの同じエフェクトを指せば等しい。`uses` の後の修飾した名前の解決は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。

本章の例のうち、見出しに「（初回リリース版）」を付けていない節の例は、最小実行版の例であり、最小実行版の `uses IO` で書く。初回リリース版では `uses IO` は誤りになる（[エフェクト](01-07-effects.md)）ので、`uses IO.All` か細かいエフェクトの集まりと読み替え、`Console` や `File` のモジュールの import を加える。

【決定】エフェクト変数は、トップレベルの関数の型パラメータの並びで、`effect` を前に付けて宣言する（[ADR 0008](../decisions/0008-effect-variables.md)）。初回リリース版では、型クラスと実装のメソッドの型パラメータの並びにも宣言できる（後述の「型クラス（初回リリース版）」）。

```text
function map[T, U, effect E](xs: List[T], f: function(T) -> U uses E) -> List[U] uses E   // 本体は省略
function twice[effect E](act: function() -> Unit uses E) -> Unit uses E
  act()
  act()
end function
function logEach[T, effect E](xs: List[T], show: function(T) -> String uses E) -> Unit uses Console.Write, E   // 本体は省略
```

- エフェクト変数は `uses` の後にだけ書ける。型を書く位置にエフェクト変数を、`uses` の後に型パラメータを書くと誤りとする。
- 一つの `uses` に書けるエフェクト変数は一つまでである。二つの引数の関数に同じエフェクト変数を使えば、両方のエフェクトをまとめて表せる（後述の包含の規則による）。
- 宣言したエフェクト変数は、引数の型のどこかに現れなければならない。
- 同じ `uses` に同じ名前を二度書くと誤りとする。
- 型の宣言（`data`）の型パラメータにエフェクト変数は宣言できない。

### 式のエフェクト

【方針】式を評価したときに起こりうるエフェクトの集合を、式のエフェクトと呼ぶ。式のエフェクトは次のように決まる。

- 関数の呼び出し `f(a1, ..., an)` のエフェクトは、`f` と各引数の式のエフェクトに、`f` の型のエフェクトを加えた和集合である。
- ラムダの式そのもののエフェクトは空集合である。ラムダの本体のエフェクトは、ラムダの型のエフェクトになる。
- `if`・`match`・ブロック・演算子などの式のエフェクトは、それを構成する式（条件、対象、すべての分岐、すべての文、オペランド）のエフェクトの和集合である。
- 名前とリテラルのエフェクトは空集合である。

演算子自身はエフェクトを持たない。演算子の実行時エラー（[基本型の意味論](01-04-types-basic.md)）は、エフェクトとして扱わない（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

【決定】トップレベルの関数の本体のエフェクトは、その関数の `uses` に書いた集合に含まれなければならない。含まれないエフェクトがあれば誤りとする（[ADR 0005](../decisions/0005-direct-style-effects.md)）。

【方針】関数の本体の中では、宣言したエフェクト変数は、ほかの何とも等しくない一つの要素として扱う。

```text
function greet(name: String) -> Unit
  Console.writeLine("Hello, " + name)    // 誤り: greet は純粋だが、本体が Console.Write を生じる
end function
```

ラムダに `uses` を書いた場合も、本体のエフェクトはその集合に含まれなければならない。ラムダに `uses` を書かない場合は、本体のエフェクトをそのままラムダの型のエフェクトとする。

誤りを報告するときは、宣言に含まれないエフェクトと、そのエフェクトを生じた呼び出しの位置を示す。

### エフェクトの包含

【決定】関数の型 `function(A1, ..., An) -> R uses X` を持つ式は、`X` を含む集合 `Y` について、型 `function(A1, ..., An) -> R uses Y` が求められる位置に使ってよい（[ADR 0008](../decisions/0008-effect-variables.md)）。

【決定】包含の規則は、値がある型の位置に流れ込む次のすべての箇所で働く（[ADR 0046](../decisions/0046-effect-subsumption-at-all-flow-positions.md)）。

- 関数の呼び出しの各引数
- リストリテラルの各要素
- `if` の各分岐と `match` の各分岐の本体。分岐全体の型は、各分岐の型を包含の規則で受け入れる一つの型とする。
- 束縛の文（`bind`・`shadow`）の型注釈
- ラムダの戻り値の型注釈
- `return` の式と、それを含む関数の宣言かラムダの戻り値の型
- 初回リリース版の `handle` の本体と各節の本体。`handle` の式の型は、本体と各節の型を包含の規則で受け入れる一つの型とする
- 初回リリース版の `resume` の引数と、節の操作の戻り値の型
- 初回リリース版のレコードの構築と一部を変えた値の作成の、各フィールドの式

```text
function runAll(actions: List[function() -> Unit uses Console.Write]) -> Unit uses Console.Write   // 本体は省略

runAll([lambda() Console.writeLine("a") end lambda, lambda() () end lambda])   // 純粋なラムダも要素にできる
bind f: function() -> Unit uses Console.Write <- lambda() () end lambda             // 型注釈にも包含が働く
```

- この規則は、式の型の最も外側の関数の型にだけ働く。引数の型、戻り値の型、型引数の中の関数の型には働かない。例えば、`List[function() -> Unit]` 型の変数を、`List[function() -> Unit uses Console.Write]` 型の引数に渡すと誤りとする。
- エフェクト変数を持つ関数の型（`uses E`）が求められる位置には、エフェクトが空集合の関数を使える。本体の中の `E` はほかの何とも等しくないので、`uses Console.Write` の関数は使えない。

### エフェクト変数の具体化

【方針】エフェクト変数を持つ関数を呼び出したり値として使ったりするたびに、その関数の各エフェクト変数を、エフェクトの集合で置き換える。置き換える集合は、引数の型とエフェクトの包含の規則を満たすように推論する。

```text
bind ys <- map(xs, lambda(x) return x + 1 end lambda)                 // E は空集合。この呼び出しは純粋
bind zs <- map(xs, lambda(x) return File.readText(x) end lambda)      // E は {File.Read}。呼び出しはファイルを読む
```

`uses Console.Write, E` の `E` を `{File.Read}` で置き換えた集合は `{Console.Write, File.Read}` である。置き換える集合が推論で一つに決まらない場合は、条件を満たす最小の集合をとる。

### 多相

【決定】最小実行版の多相な名前は、次のものに限る（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）。

- トップレベルの関数。型パラメータとエフェクト変数は、シグネチャで宣言したものである。
- データ構成子。型パラメータは、構成子が属する型の型パラメータである。
- prelude の関数。

【方針】初回リリース版では、次のものも多相な名前である。

- 型クラスのメソッド（後述の「型クラス（初回リリース版）」）。
- レコードの構築の形（`T(...)`）とフィールドを取り出す関数（`Box.value`）。型パラメータは、レコードの型パラメータである（[代数的データ型とパターンマッチ](01-05-data-types.md)の「レコード（初回リリース版）」）。

多相な名前は、使うたびに、型パラメータを型で、エフェクト変数をエフェクトの集合で置き換える。置き換える型は推論し、利用者が明示する構文はない。

【決定】局所の束縛（束縛の文（`bind`・`shadow`）、関数とラムダの引数、パターンの変数）の型は多相にならない（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）。局所の束縛の型は、その名前のすべての使用で同じである。

```text
function example() -> Unit
  bind id <- lambda(x) return x end lambda
  bind a <- id(1)
  bind b <- id("one")      // 誤り: id の型は function(Integer) -> Integer に決まっている
end function
```

関数の本体の中では、宣言した型パラメータは、ほかの何とも等しくない一つの型として扱う。型パラメータ `T` の値は、別の型の値として使えない。

### 型の推論と型注釈

【決定】トップレベルの関数の宣言は、すべての引数の型と戻り値の型、およびエフェクトを書く（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。

【方針】型検査は、すべてのトップレベルの関数とデータ構成子の型（初回リリース版では、定数の型も）を宣言から先に決め、そのうえで各関数の本体を一つずつ検査する。ある関数の本体の検査結果は、ほかの関数の本体の検査に影響しない。関数の本体の中の型は、HM 型推論（単一化による推論）で決める。

【方針】関数の本体の中では、次の型注釈を書ける。書いた型注釈は推論した型と等しくなければならず、等しくなければ誤りとする。ただし、束縛の文の型注釈とラムダの戻り値の型注釈には、エフェクトの包含の規則が働く（前述の「エフェクトの包含」）。

- `bind x: T <- e` と `shadow x: T <- e` の `T`
- ラムダの引数の型、戻り値の型、`uses`

型注釈には、その関数で宣言した型パラメータとエフェクト変数を使える。型注釈で新しい型パラメータを導入することはできない。

【方針】次の場合は誤りとする。

- 型の等しさの条件を満たさない二つの型を、等しくなければならない位置で使った場合。
- 型変数が、それ自身を含む型と等しくなる必要が生じた場合（`lambda(f) f(f) end lambda` など）。
- 呼び出しの引数の個数が、関数の型の引数の個数と違う場合。

【方針】関数の本体の検査を終えた時点で決まっていない型変数のうち、後述の制約を持たず、初回リリース版の `try` の対象の型（[エラー処理](01-09-errors.md)）でもないものは、そのままでよい。そのような型変数は、値の意味に影響しない（空のリスト `[]` の要素の型など）。

### 定数の型（初回リリース版）

【決定】トップレベルの定数の型は、宣言に書いた型である。定数式の型は、宣言の型と等しくなければならない。定数は多相な名前ではなく、型パラメータを持たない（[ADR 0123](../decisions/0123-top-level-constants.md)）。`const empty: List[Integer] = []` のように、型引数を含む型も具体的な型で書く。

- 定数式はエフェクトを持たない。定数式に書ける式の種類は[構文](01-02-syntax.md)の「定数（初回リリース版）」で定める。
- 定数式の計算が、実行時エラーの条件（`Integer` の範囲を超える、0 で割るなど。[基本型の意味論](01-04-types-basic.md)）に当たるときは、型検査の誤りとする。診断は、その条件と、計算が失敗した部分式の位置を示す。
- 定数式の `Map.fromList` と `Set.fromList` の引数に同じ鍵か同じ要素が二つ以上あるときは、型検査の誤りとする（[ADR 0136](../decisions/0136-map-and-set-in-constants.md)）。診断は、重なる鍵の位置を示す。

### 型の別名（初回リリース版）

【決定】型の別名 `type A[P1, ..., Pn] = T` の `A[U1, ..., Un]` は、`T` の中の `Pi` を `Ui` で置き換えた型を表す（[ADR 0124](../decisions/0124-type-aliases.md)）。次の場合を誤りとする。

- 別名が、直接または別の別名を通して、自分自身を参照する場合。再帰する型は、代数的データ型で宣言する。
- 別名の型パラメータを、右辺の型で使わない場合。
- 別名に与えた型引数の数が、型パラメータの数と違う場合。型引数を与えずに型パラメータを持つ別名を書くこと（型構成子として使うこと）もできない。

【方針】診断で型を示すときは、ソースに書いた型（別名を含む）を示す。別名を展開した型が書いた型と異なるときは、展開した型を添える。

### 式と文の型

【方針】式と文の型は次のように決まる。基本型の演算子の型は次節で定める。

| 式・文 | 型 |
|---|---|
| 整数リテラル | `Integer` |
| 浮動小数リテラル | `Float` |
| 文字列リテラル | `String` |
| 文字リテラル | `Character` |
| `true`、`false` | `Boolean` |
| `()` | `Unit` |
| リストリテラル `[e1, ..., en]` | `List[T]`。各要素の型は `T` と等しいか、包含の規則で `T` に受け入れられる。初回リリース版の展開の要素 `..e` は、`e` の型が `List[T]` と等しいか、包含の規則で `List[T]` に受け入れられる（[ADR 0272](../decisions/0272-list-spread-in-list-literals.md)） |
| 関数の呼び出し | 関数の型の戻り値の型。各引数の型は、対応する引数の型と等しいか、包含の規則で受け入れられる |
| ラムダ | 引数の型と戻り値の型からなる関数の型。戻り値の型は、本体の `return` の式の型を包含の規則で受け入れる一つの型である。本体の終わりに達しうるときは、戻り値の型は `Unit` と等しい（後述の「必ず抜ける文」） |
| `return e` | 任意の型（その位置で求められる型）。`e` の型は、最も内側の関数の宣言かラムダの戻り値の型と等しいか、包含の規則で受け入れられる |
| `try e`（初回リリース版） | [エラー処理](01-09-errors.md)で定める |
| `if c then ... else ... end if` | 二つの分岐の型を、どちらも包含の規則で受け入れる一つの型。`c` は `Boolean` |
| `else` のない `if` | `Unit`。分岐の型は `Unit` |
| `match` | 各分岐の本体の型を包含の規則で受け入れる一つの型（[代数的データ型とパターンマッチ](01-05-data-types.md)） |
| ブロック | 最後の文が式ならその型、そうでなければ `Unit` |
| 式文（最後の文でない式） | 型は `Unit` でなければならない（[構文](01-02-syntax.md)） |
| 関数の宣言とラムダの本体のブロック | 型は `Unit` でなければならない。最後の文が `return e` などの必ず抜ける文であれば、その文の型は任意なので、この条件を満たす |
| `a and b`、`a or b`、`not a` | `Boolean`。オペランドは `Boolean` |

パイプと部分適用のプレースホルダは、[構文](01-02-syntax.md)の規則で展開した式として型を決める。

### 必ず抜ける文

【方針】`return` の検査のために、「必ず抜ける」文とブロックを次のように定める（[ADR 0096](../decisions/0096-explicit-return.md)）。

- `return e` は、必ず抜ける。
- ブロックは、その文のどれかが必ず抜けるとき、必ず抜ける。
- `else` のある `if` は、すべての分岐のブロックが必ず抜けるとき、必ず抜ける。
- `match` は、すべての分岐の本体が必ず抜けるとき、必ず抜ける。
- 初回リリース版の `with` は、そのブロックが必ず抜けるとき、必ず抜ける。
- ほかの式と、束縛の文は、必ず抜けるとはみなさない。関数の呼び出しは、呼んだ関数が戻らない場合（プロセスを終える関数など）でも、必ず抜けるとはみなさない。

【方針】次の場合は誤りとする。

- 戻り値の型が `Unit` でない関数の宣言の本体のブロックが、必ず抜けない場合。診断は、本体の終わりに達しうる道筋と、`return` を書き足す箇所を示す。
- 同じブロックの中で、必ず抜ける文の後に文を置いた場合。後の文は実行されない。

戻り値の型注釈のないラムダの本体のブロックが必ず抜けないときは、ラムダの戻り値の型を `Unit` と等しくする。本体の `return` の式の型が `Unit` でなければ、型の誤りになる。

```text
function sign(x: Integer) -> Integer
  if x < 0 then
    return -1
  end if
  if x = 0 then return 0 else return 1 end if   // 両方の分岐が必ず抜けるので、本体は必ず抜ける
end function

function bad(x: Integer) -> Integer
  if x < 0 then
    return -1
  end if                                           // 誤り: x >= 0 のとき本体の終わりに達する
end function
```

### 演算子の型付け

【決定】算術演算子と順序の比較演算子のオペランドは、演算子ごとに決まった型の集まりのどれかでなければならない（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）。初回リリース版で型クラスを加えても、演算子は型クラスに移さない（[ADR 0062](../decisions/0062-operators-stay-outside-traits.md)）。

| 演算子 | 型 | オペランドの型の集まり |
|---|---|---|
| `+` | `(T, T) -> T` | `Integer`、`Float`、`String`、初回リリース版の `Decimal` |
| `-`、`*` | `(T, T) -> T` | `Integer`、`Float`、初回リリース版の `Decimal` |
| `/` | `(T, T) -> T` | `Float`、初回リリース版の `Decimal` |
| 単項の `-` | `(T) -> T` | `Integer`、`Float`、初回リリース版の `Decimal` |
| `div`、`mod` | `(Integer, Integer) -> Integer` | — |
| `<`、`<=`、`>`、`>=` | `(T, T) -> Boolean` | `Integer`、`Float`、`String`、`Character`、初回リリース版の `Byte`・`Decimal` |
| `=`、`<>` | `(T, T) -> Boolean` | 等値の型（次節） |

二つのオペランドの型は等しくなければならない。演算子の意味は、決まった型ごとに[基本型の意味論](01-04-types-basic.md)で定める。

【方針】オペランドの型がまだ型変数である場合、その型変数は「集まりのどれかである」という制約を持つ。制約は次のように扱う。

- 制約を持つ型変数が具体的な型と等しくなるとき、その型が集まりに含まれなければ誤りとする。
- 制約を持つ二つの型変数が等しくなるとき、制約は二つの集まりの共通部分になる。共通部分が空であれば誤りとする。
- 制約を持つ型変数が型パラメータと等しくなる場合は誤りとする。利用者の関数の型パラメータには、算術演算子と順序の比較演算子を使えない。
- 関数の本体の検査を終えた時点で、制約を持つ型変数が具体的な型に決まっていなければ誤りとする。診断は型注釈を書くよう示す。

```text
function f() -> Unit
  bind add <- lambda(a, b) return a + b end lambda      // 誤り: add の引数の型が決まらない。型注釈を書く
end function

function g() -> Integer
  bind add <- lambda(a, b) return a + b end lambda
  return add(1, 2)                          // よい: a と b は Integer に決まる
end function
```

利用者は、この制約を型注釈に書けない。

【決定】初回リリース版では、文字列補間 `${e}` の式 `e` は、`String`・`Integer`・`Float`・`Character`・`Boolean`・`Byte`・`Decimal` のどれかの型でなければならない。`e` の型が型変数のときは、この集まりのどれかであるという制約を持ち、演算子の制約と同じ規則で扱う（[ADR 0058](../decisions/0058-string-interpolation-of-base-types.md)、[ADR 0114](../decisions/0114-decimal-type.md)）。それ以外の型の式を書くと誤りとし、診断は文字列に変換する関数を修正案として示す。文字列補間の式全体の型は `String` である。

### 等値の型

【決定】`=` と `<>` のオペランドの型は、等値の型でなければならない（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）。型が等値の型であるとは、関数の型を含まないことである。

【決定】加えて、中身を見せない prelude の型（最小実行版では `IOError`）を含む型は、等値の型ではない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。`Result[String, IOError]` などを `=` と `<>` で比べると誤りとする。

【方針】初回リリース版では、`Reference`・`Lazy`・`Task`（[並行処理](01-11-concurrency.md)）・`NetworkError`（[エラー処理](01-09-errors.md)、[ADR 0145](../decisions/0145-network-error.md)）・リソースの型（[リソース管理](01-10-resources.md)）も中身を見せない prelude の型であり、これらを含む型は等値の型ではない。標準ライブラリのモジュールが宣言する中身を見せない型（`Regex.Pattern`・`Regex.Match`・`Random.Generator`。[標準ライブラリ](../03-interop/03-06-stdlib.md)）も、本章の規則では中身を見せない prelude の型と同じく扱う（[ADR 0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md)）。

【方針】型が関数の型または中身を見せない prelude の型を含むかは、次のように判定する。

- 基本型は含まない。
- 関数の型と、中身を見せない prelude の型は含む。
- `List[T]` は、`T` が含むときに含む。初回リリース版の `Set[T]` も同じである。`Map[K, V]` は、`K` か `V` が含むときに含む。`Bytes` は含まない。
- 代数的データ型 `D[A1, ..., An]` は、D の宣言から求めた後述の要約で判定する。要約は、D が型引数によらず含むかと、含むかどうかが型引数に依存する型パラメータの集合からなる。`D[A1, ..., An]` は、D が型引数によらず含むか、依存する型パラメータ αi について Ai が含むときに含む。初回リリース版のレコードは、フィールドの型を引数に持つ構成子が一つの代数的データ型として扱う。
- 関数の本体の中の型パラメータは、組み込みの制約 `equality` か `key` を付けたもの（後述の「組み込みの制約（初回リリース版）」）を等値の型として扱い、それ以外を等値の型ではないものとして扱う。

【決定】代数的データ型の要約は、すべての型の宣言について同時に、次の手順で求める（[ADR 0082](../decisions/0082-equality-type-by-declaration-summary.md)）。

1. はじめは、どの宣言も「型引数によらず含む」を偽、依存する型パラメータの集合を空とする。
2. 各宣言 D について、各構成子の引数の型 τ ごとに、τ が含む条件を求める。条件は、「無条件に含む」か、D の型パラメータの集合（そのどれかに与えた型引数が含むときに含む）である。基本型は空集合、関数の型と中身を見せない prelude の型は「無条件に含む」、D の型パラメータ αi は {αi}、`List[τ']` と初回リリース版の `Set[τ']` は τ' の条件、`Map[κ, τ']` は κ と τ' の条件を合わせたもの、`Bytes` は空集合とする。代数的データ型 `E[τ1, ..., τm]` は、E の現在の要約で E が型引数によらず含むなら「無条件に含む」とし、そうでなければ E の依存する各型パラメータ βj について τj の条件を合わせたものとする。D の構成子の引数の型の条件をすべて合わせたものを、D の新しい要約とする。
3. どの宣言の要約も変わらなくなるまで 2 を繰り返す。

要約は偽から真へ、集合は小さいほうから大きいほうへだけ変わり、型の宣言と型パラメータの数は有限なので、手順は必ず終わる。この手順は、`Nest[List[T]]` のように再帰の先で型引数が変わる型でも、具体的な型を展開せずに判定する。

オペランドの型がまだ型変数である場合、その型変数は「等値の型である」という制約を持ち、前節の制約と同じく扱う。`List[T]` か初回リリース版の `Set[T]` と等しくなったときは T に制約を移し、`Map[K, V]` と等しくなったときは K と V に制約を移す。`Bytes` と等しくなったときは制約を満たす。代数的データ型 `D[A1, ..., An]` と等しくなったときは、D が型引数によらず含むなら誤りとし、そうでなければ依存する型パラメータ αi に当たる Ai に制約を移す。

【方針】代数的データ型の値どうしの `=` は、構成子が同じで、対応する引数がすべて `=` で等しいときに `true` である。リストの値どうしの `=` は、長さが同じで、対応する要素がすべて `=` で等しいときに `true` である。初回リリース版の集合どうしは、要素の集まりが同じとき、マップどうしは、鍵の集まりが同じで、各鍵の値が `=` で等しいとき、`Bytes` どうしは、長さが同じで各バイトが等しいときに `true` である。`Float` の成分の比較は IEEE 754 に従う（`Option.Some(0.0 / 0.0) = Option.Some(0.0 / 0.0)` は `false`）。`a <> b` は `a = b` の否定である。

代数的データ型とリストには、順序の比較演算子を使えない。初回リリース版のマップ・集合・`Bytes` も同じである。

### 鍵の型（初回リリース版）

【決定】初回リリース版のマップの鍵と集合の要素の型は、鍵の型でなければならない（[ADR 0103](../decisions/0103-map-and-set-ordered-by-key.md)）。鍵の型とは、等値の型であって、`Float` を含まない型である。

- 型が `Float` を含むかは、前節の「関数の型または中身を見せない prelude の型を含むか」と同じ手順で判定する。ただし、「無条件に含む」とする型は `Float` だけとする。
- 鍵の型の制約は、`Map` と `Set` の標準ライブラリの関数の型が持つ。初回リリース版では、利用者も組み込みの制約 `key` として関数の型に書ける（次節）。まだ型変数である型は「鍵の型である」という制約を持ち、等値の制約と同じく扱う。
- `Float` を含む型を鍵にしたときの診断は、`Integer` や `String` に変換して鍵にする書き方を修正案として示す。`Float` を鍵にしないのは、NaN が自分自身と `=` で等しくないからである。
- 鍵の型の値には、全順序（鍵の順序）を定める。マップと集合は、この順序で要素を並べる。鍵の順序の定義は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。鍵の順序は、比較演算子には使わない。

### 組み込みの制約（初回リリース版）

【決定】利用者は、関数の型パラメータに、組み込みの制約 `equality`（等値の型である）と `key`（鍵の型である）を付けられる（`[T: equality]`、`[K: key]`。[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。構文は[構文](01-02-syntax.md)の「型クラス（初回リリース版）」で定める。

```text
function countBy[T, K: key](xs: List[T], keyOf: function(T) -> K) -> Map[K, Integer]
  return List.fold(xs, Map.empty(), lambda(m, x)
    bind k <- keyOf(x)
    return Map.set(m, k, Option.unwrapOr(Map.get(m, k), 0) + 1)
  end lambda)
end function
```

- 型が組み込みの制約を満たすかは、前節までの「等値の型」と「鍵の型」の判定で決める。`implement` は要らず、書けない。`key` を満たす型は `equality` も満たす。
- 関数の本体の中では、`equality` を付けた型パラメータを等値の型として扱い、`=` と `<>` に使える。`key` を付けた型パラメータを鍵の型として扱い、`Map` と `Set` の鍵と要素に使える。
- 制約を持つ関数を呼ぶと、型引数について「等値の型である」「鍵の型である」という制約が生じ、前節までと同じ規則で解く。型引数が制約を付けた型パラメータなら、同じ制約か、より強い制約（`equality` に対する `key`）を宣言していなければならない。宣言していなければ誤りとし、診断は制約を加える書き方を修正案として示す。
- 組み込みの制約を書ける位置は、関数・実装・メソッドの型パラメータである。型の宣言の型パラメータ、型構成子を表す型パラメータ（`F[_]`）、上位の型クラスの位置には書けない。
- 組み込みの制約は型検査だけで使い、実行時に辞書を渡さない（[コア計算と脱糖](01-12-core-calculus.md)）。

### 標準ライブラリの関数の型

【方針】標準ライブラリの関数は、多相な型を持ち、エフェクト変数を持ってよい。型パラメータには、組み込みの制約と型クラスの制約を付けてよい。加えて、前節の演算子の型の集まりのどれかであることを制約として持ってよい。演算子の型の集まりの制約は標準ライブラリの関数の型にだけ現れ、利用者は書けない（[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。初回リリース版の標準ライブラリのソースでは、順序の比較演算子の型の集まりの制約を、組み込みの制約 `ordered` として `[T: ordered]` と書く（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。`ordered` を利用者のソースに書くと誤りとする。標準ライブラリの関数の型は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

### 型クラス（初回リリース版）

【決定】型クラス（type class）は `trait` で宣言し、`implement` で型に実装する。メソッドは型クラスの名前で修飾して呼び、どの実装を使うかは引数の型から決まる。関数の型パラメータには、`[T: Show]` の形で型クラスの制約を付ける（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。構文は[構文](01-02-syntax.md)の「型クラス（初回リリース版）」で定める。

```text
trait Show[T]
  function show(x: T) -> String
end trait

implement Show[Person]
  function show(x: Person) -> String return "Person(${Person.name(x)})" end function
end implement

implement[T: Show] Show[Option[T]]
  function show(x: Option[T]) -> String
    return match x with
      case Option.Some(v) -> "Some(${Show.show(v)})"
      case Option.None -> "None"
    end match
  end function
end implement

function describeAll[T: Show](xs: List[T]) -> String
  return List.map(xs, Show.show) |> String.join(_, ", ")
end function
```

この例の `Show` は、利用者が宣言した型クラスであり、標準の型クラス `Trait.Show`（後述の「標準の型クラス（初回リリース版）」）とは別のものである。

【決定】型クラスの引数には、値の型を表す型パラメータ（`T`）か、型構成子を表す型パラメータ（`F[_]`）をとれる。prelude には、型構成子を引数にとる型クラス（`Functor`・`Monad` など）を入れない（[ADR 0059](../decisions/0059-higher-kinded-traits-without-prelude-monad.md)）。標準の型クラスは、import が要るモジュール `Benitoite.Trait` に置く（[ADR 0134](../decisions/0134-standard-type-classes.md)）。次の例の `Functor` は、利用者が宣言した型クラスである。

```text
trait Functor[F[_]]
  function map[A, B, effect E](x: F[A], f: function(A) -> B uses E) -> F[B] uses E
end trait

implement Functor[Option]
  function map[A, B, effect E](x: Option[A], f: function(A) -> B uses E) -> Option[B] uses E
    return Option.map(x, f)
  end function
end implement
```

#### 高カインド型（初回リリース版）

【方針】型構成子を表す型パラメータ（`F[_]`）は、型引数を一つとる型構成子を表す。このような型パラメータを持てることを、高カインド型（higher-kinded type）という。型構成子を表す型パラメータは、型クラスの引数と、関数の型パラメータにだけ宣言できる（[代数的データ型とパターンマッチ](01-05-data-types.md)）。型は次の規則で扱う。

- 型を書く位置には、値の型を書く位置と、型構成子を書く位置がある。型構成子を書く位置は、型構成子を引数にとる型クラスの引数（`implement Functor[Option]` の `Option`、制約 `[F: Functor]` の `F`）である。それ以外の位置は、値の型を書く位置である。
- 値の型を書く位置では、型構成子にすべての型引数を与える（`F[A]`、`Option[Integer]`）。型構成子を書く位置では、型引数を与えずに名前を書き、その型構成子がとる型引数の個数は、型構成子を表す型パラメータと一致しなければならない。一致しなければ誤りとする（`implement Show[Option]`、`implement Functor[Integer]`、`implement Functor[Result]` は誤り）。
- 推論では、`F[A]`（`F` は型構成子を表す型変数）と `D[B1, ..., Bn]` を等しくするとき、`D` のとる型引数の個数が `F` と一致する場合に限り、`F` を `D` に決め、対応する型引数を等しくする。型の部分適用はないので、`F[A]` と `Result[Integer, String]` は等しくできず、誤りとする。

【方針】型クラスの宣言には、次の規則がある。

- 型クラスは、一つの引数と、一つ以上のメソッドの宣言を持つ。メソッドの宣言は、本体のない関数の宣言である。
- 【決定】一つの型クラスの中で、二つのメソッドに同じ名前を付けると誤りとする。メソッドの型が違っても誤りとする。違う型クラスのメソッドは、それぞれの型クラスのモジュールに入るので、同じ名前でもよい（[ADR 0279](../decisions/0279-no-duplicate-method-names-in-trait.md)）。
- 【決定】各メソッドは、型クラスの引数を、引数の型か戻り値の型の少なくとも一つに含まなければならない。引数のないメソッド（`function empty() -> T`）も書ける。型クラスの引数をどこにも含まないメソッドは誤りとする（[ADR 0134](../decisions/0134-standard-type-classes.md)）。どの実装を使うかは、メソッドを使った位置の型から決まる（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。型クラスの引数を戻り値の型にだけ含むメソッドでは、呼び出した位置で求める型（型注釈や、値を渡す先の引数の型）から決まる。
- メソッドは、自分の型パラメータ、エフェクト変数、型クラスの制約、組み込みの制約を持ってよい。
- 初回リリース版の型クラスは、メソッドの既定の実装を持たない（[ADR 0134](../decisions/0134-standard-type-classes.md)）。

【決定】型クラスは、上位の型クラスを持てる（[ADR 0134](../decisions/0134-standard-type-classes.md)）。`trait Monoid[T: Semigroup]` は、`Semigroup` を上位の型クラスに持つ型クラス `Monoid` を宣言する。上位の型クラスには、次の規則がある。

- 型クラス `C` の上位の型クラスが `S` のとき、型 `T` についての `C` の制約は、`T` についての `S` の制約を含む。`[T: Monoid]` を宣言した関数の中では、`Semigroup.combine` を `T` の値に使える。上位の型クラスの上位の型クラスも同じく含む。
- `implement C[X]` を書くには、`S[X]` の制約が解けなければならない。実装の型パラメータの制約だけで解けない場合（`X` の `S` の実装がない場合など）は誤りとする。
- 上位の型クラスの関係が循環すると誤りとする（`trait A[T: B]` と `trait B[T: A]`）。
- `public trait` の上位の型クラスに、`public` を付けていない同じモジュールの型クラスを使うと誤りとする（[名前・スコープ・モジュール](01-03-names-modules.md)の「公開（初回リリース版）」、[ADR 0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md)）。
- 型構成子を引数にとる型クラスの上位の型クラスは、型構成子を引数にとる型クラスでなければならない（`trait Monad[F[_]: Applicative]`）。値の型を引数にとる型クラスも同じく、値の型を引数にとる型クラスだけを上位に持てる。
- 型クラスの名前は、型・モジュール・エフェクトと同じ大文字の名前空間に入り、同じ名前のモジュールを兼ねる。そのモジュールには、メソッドが入る。`Show.show` の型は `function[T: Show](T) -> String` である。

【方針】型クラスの実装には、次の規則がある。

- `implement` は、型クラスのすべてのメソッドを、一度ずつ定義しなければならない。宣言にないメソッドは定義できない。
- 各メソッドの型は、型クラスの宣言のメソッドの型の引数を、実装の対象の型で置き換えたものと等しくなければならない。ただし、エフェクトは包含の規則に従い、宣言より少なくてよい（[ADR 0046](../decisions/0046-effect-subsumption-at-all-flow-positions.md)）。
- 実装の対象は、型構成子に相異なる型パラメータを並べた形か、型パラメータを持たない型に限る（[ADR 0061](../decisions/0061-trait-coherence-orphan-and-overlap.md)）。型構成子を引数にとる型クラスの実装では、対象は引数の個数が合う型構成子の名前（`Option`）である。
- 実装の型パラメータは、`implement` の直後に宣言し、制約を付けてよい（`implement[T: Show] Show[Option[T]]`）。実装の型パラメータは、すべて実装の対象に現れなければならない（`implement[T, U] Show[Option[T]]` は誤り）。
- 関数の型は、実装の対象にできない。

【決定】型クラス `C` を型 `T` に実装する `implement` は、`C` を宣言したモジュールか、`T` を宣言したモジュールにしか書けない。それ以外のモジュールに書いた実装（孤立した実装、orphan instance）は誤りとする。標準ライブラリの型クラスを標準ライブラリの型に実装することは、利用者にはできない。プログラムの中で、同じ型クラスと型構成子の組に二つの実装を書くと誤りとする（[ADR 0061](../decisions/0061-trait-coherence-orphan-and-overlap.md)）。

【方針】標準ライブラリの型（中身を見せない型を含む）を宣言したモジュールは、標準ライブラリのモジュール（`Benitoite` の名前空間のモジュール。[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）である。したがって、利用者が標準ライブラリの型（`Integer`、`Reference`、`IOError` など）に書ける実装は、利用者が宣言した型クラスの実装に限る。

【方針】実装は、プログラム全体で有効である。制約を解くときは、プログラムを構成するすべてのモジュールの実装から探し、実装を書いたモジュールを取り込んでいるかは問わない。孤立した実装と重なる実装を誤りとするので、型クラスと型構成子の組ごとに、実装は高々一つに決まる。

【方針】型クラスの制約は、次のように扱う。

- メソッドや、制約を持つ関数を使うと、使った位置の型について「`C` を実装している」という制約が生じる。
- 関数の本体の検査を終えた時点で、制約の型が具体的な型構成子であれば、その型構成子の実装を探す。実装の型パラメータに制約があれば、それも同じように解く。実装がなければ誤りとする。
- 制約の型が関数か実装の型パラメータであれば、その型パラメータに同じ制約を宣言していなければならない（実装の中では、`implement` の直後の型パラメータの宣言）。宣言していなければ誤りとし、診断は制約を加える書き方を修正案として示す。
- 制約の型が関数か実装の型パラメータで、その型パラメータに宣言した制約の上位の型クラスに当たる制約は、宣言したものとみなす（`[T: Monoid]` を宣言していれば、`Semigroup` の制約を別に宣言しなくてよい）。
- 制約の型が具体的な型に決まらなければ、演算子の制約と同じく誤りとし、診断は型注釈を書くよう示す。戻り値の型にだけ型クラスの引数を含むメソッド（`Monoid.empty()` など）の結果を、型の決まらない位置で使ったときも同じである。局所の束縛は多相にならないので、局所の束縛は制約を持つ多相な型を持たない。

【方針】型クラスを使うプログラムの意味は、型クラスの制約ごとに、実装のメソッドの組（辞書）を関数の引数として渡すプログラムに変換して定める（辞書渡し、dictionary passing）。変換の規則は[コア計算と脱糖](01-12-core-calculus.md)で定める。

【決定】演算子と文字列補間は、型クラスに移さない。`=` と `<>` は等値の型の値を構造で比べ、ほかの演算子と文字列補間は、閉じた型の集まりの制約で型付けする（[ADR 0062](../decisions/0062-operators-stay-outside-traits.md)）。

#### 標準の型クラス（初回リリース版）

【決定】標準ライブラリは、標準の型クラスをモジュール `Benitoite.Trait` に置く（[ADR 0134](../decisions/0134-standard-type-classes.md)）。`Benitoite.Trait` は prelude に含まれないので、使うには `import Benitoite.Trait` と書く。型クラスは `Trait.Monad`、メソッドは `Trait.Monad.flatMap(x, f)` のように、モジュールの名前で修飾して書く。型クラスとメソッドの一覧、比較の結果の型 `Ordering`、標準ライブラリの型への実装は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

```text
import Benitoite.Trait

function combineAll[T: Trait.Monoid](xs: List[T]) -> T
  return List.fold(xs, Trait.Monoid.empty(), Trait.Semigroup.combine)
end function
```

`Trait.Monoid.empty()` の型は、`List.fold` の初期値の型として `T` に決まる。`T` の `Semigroup` の制約は、上位の型クラスの規則で `Monoid` の制約に含まれる。

標準の型クラスのメソッドは、既存の関数と同じ役割を持つ（`Trait.Functor.map` と `Option.map`・`List.map` など）。この重複は、学習の目的のための原則 5（同じ役割の構文を、必要な理由なく増やさない。[目的と設計原則](../00-overview/00-01-goals.md)）の例外である。重複する既存の関数を隠すかは、実装した後に評価して決める（[OPEN-050](../open-issues.md#open-050)）。

【決定】利用者の型への標準の型クラスの実装は、`implement` で書く。実装を導出する仕組みは初回リリース版にはない（[OPEN-046](../open-issues.md#open-046)）。演算子と文字列補間は標準の型クラスを使わない。`Order` を実装しても `<` は使えず、`Show` を実装しても文字列補間には埋め込めない（[ADR 0062](../decisions/0062-operators-stay-outside-traits.md)）。

### 明示遅延の型（初回リリース版）

【決定】`lazy b end lazy` の型は、`b` の型を `T` として `Lazy[T]` である。`b` はエフェクトを持たない式でなければならない。エフェクトを持つ式を書くと誤りとし、診断は引数のないラムダを使う書き方を修正案として示す（[ADR 0066](../decisions/0066-explicit-laziness-pure-body.md)）。`Lazy.force` の型は `function[T](Lazy[T]) -> T` であり、エフェクトを持たない。

【方針】`Lazy[T]` は中身を見せない prelude の型であり、等値の型ではない。

### 可変状態（初回リリース版）

【決定】可変状態は、値を一つ入れるセルの型 `Reference[T]` で表す。セルを作る・読む・書き換える関数は、prelude で宣言したエフェクト `State` を持つ（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md)、[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。操作の関数は[エフェクト](01-07-effects.md)の「可変のセル（初回リリース版）」で定める。

【決定】可変状態のための型付けの規則（value restriction など）は加えない。局所の束縛は多相にならず（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）、トップレベルに置ける値は、利用者の関数を呼べない定数式の定数に限る（[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)、[ADR 0123](../decisions/0123-top-level-constants.md)）ので、セルを多相な名前に束縛する手段がないからである（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md)）。

【方針】`Reference[T]` は中身を見せない prelude の型であり、等値の型ではない。二つのセルを `=` で比べると誤りとする。

### エフェクトの宣言とハンドラの型付け（初回リリース版）

【決定】利用者が宣言したエフェクトの操作と、ハンドラは次のように型付けする（[ADR 0118](../decisions/0118-effect-handlers.md)）。構文は[構文](01-02-syntax.md)の「エフェクトの宣言とハンドラ（初回リリース版）」で、意味は[エフェクト](01-07-effects.md)で定める。

- エフェクト `L` の操作 `function op[ᾱ](x1: A1, …, xn: An) -> B` は、`L` を宣言したモジュールの関数 `op` として、型 `function[ᾱ](A1, …, An) -> B uses L` を持つ（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。組み込みのエフェクトの操作は、標準ライブラリが定める関数の型をそのまま持つ。`State` は操作を持たず、`State` を型に持つ関数はハンドラで処理できない（[エフェクト](01-07-effects.md)）。
- `handle` の式を、本体 `b` と節の並びとする。`b` の型を `T`、エフェクトを `ε` とする。節の本体は、`T` 型でなければならない。節の本体の中の `resume(v)` は、`v` が節の操作の戻り値の型を持つときに型が付き、その型は `T` である。
- 操作が型パラメータを持つとき、節の中では、その型パラメータをほかの何とも等しくない型として扱う。したがって、`function fail[T](message: String) -> T` のように、T の値を引数に受け取らず、T の値を得るほかの手段もない操作の節は、`resume` に渡す値を作れず、`resume` を呼ばずに終わる。`function identity[T](value: T) -> T` のように T の値を引数に受け取る操作の節では、受け取った値を渡す `resume(value)` に型が付く。
- エフェクト `L` のすべての操作の節を持つ `handle` を、`L` を処理するハンドラと呼ぶ。`handle` の式のエフェクトは、`ε` から、処理する `L` をすべて除き、各節の本体のエフェクトを加えた集合である。一部の操作の節だけを持つエフェクトは、`ε` から除かない。
- `ε` のエフェクト変数は除かない。エフェクト変数 `E` の中身は関数の本体の中では分からないので、`E` が表すエフェクトを処理するハンドラを書けない。
- `resume` は、`handle` の節の中にだけ直接書ける（[構文](01-02-syntax.md)）。節の中のラムダの本体の中と `lazy` の本体の中には書けない（[ADR 0155](../decisions/0155-resume-not-in-lazy.md)）。

```text
effect Abort
  function fail[T](message: String) -> T
end effect

function parseAll(texts: List[String]) -> Result[List[Integer], String]
  return handle
    Result.Ok(List.map(texts, lambda(t)
      return match Integer.parse(t) with
        case Option.Some(n) -> n
        case Option.None -> fail("bad: " + t)
      end match
    end lambda))
  with
    case fail(message) ->
      Result.Error(message)
  end handle
end function
```

この例は、エフェクト `Abort` を宣言したモジュールの中で書いたものである。操作 `fail` は同じモジュールの関数なので、修飾せずに呼ぶ。

`parseAll` の本体の `handle` は `Abort` を処理するので、`parseAll` は純粋な関数である。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（エフェクト変数の書き方と、演算子の制約による誤りの頻度）
- [OPEN-046](../open-issues.md#open-046): プロパティベーステストと、入力の生成器の導出（標準の型クラスの実装の導出を含む）
- [OPEN-050](../open-issues.md#open-050): 標準の型クラスと重複する既存の関数を隠すか
