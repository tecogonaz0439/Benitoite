# 名前・スコープ・モジュール

- 状態: 確定
- 関連ADR: [0004](../decisions/0004-surface-syntax-skeleton.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0010](../decisions/0010-shared-namespace-and-shadowing.md), [0047](../decisions/0047-parenthesized-types-and-uses-binding.md), [0053](../decisions/0053-private-by-default-with-pub.md), [0054](../decisions/0054-no-import-cycles.md), [0055](../decisions/0055-top-level-functions-and-types-only.md), [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0060](../decisions/0060-trait-and-impl-syntax.md), [0061](../decisions/0061-trait-coherence-orphan-and-overlap.md), [0077](../decisions/0077-abolish-go-layer.md), [0092](../decisions/0092-unabbreviated-keywords.md), [0099](../decisions/0099-qualified-option-result-constructors.md), [0102](../decisions/0102-pair-and-triple.md), [0118](../decisions/0118-effect-handlers.md), [0123](../decisions/0123-top-level-constants.md), [0124](../decisions/0124-type-aliases.md), [0126](../decisions/0126-import-by-module-name.md), [0127](../decisions/0127-directory-run-and-root.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0137](../decisions/0137-first-release-library-scope.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md), [0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md), [0206](../decisions/0206-test-command-line-and-exit-status.md), [0241](../decisions/0241-command-name-and-extension.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-048](../open-issues.md#open-048), [OPEN-049](../open-issues.md#open-049)
- 移行元: [設計メモ](../sources/fp-language-design.md) なし

## 目的と範囲

束縛、シャドーイング、可視性、モジュールと import。循環 import の可否と、トップレベルの初期化順序のうち利用者から観測できる規則も扱う。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲と、初回リリース版のモジュールと import を定める。最小実行版の範囲は、名前の種類、トップレベルの名前空間、修飾された名前の解決、局所の束縛の有効範囲とシャドーイングである。初回リリース版の範囲は、モジュールと import、標準ライブラリの名前空間と prelude、公開（`public`）、循環する import、実行を始めるモジュールと根のディレクトリ、レコード・型クラス・エフェクトの宣言を加えたことによる名前空間と名前の解決の拡張である。初回リリース版の節は見出しに「（初回リリース版）」と記す。パッケージの名前空間と取り込み方は [OPEN-049](../open-issues.md#open-049) で決める。トップレベルには値の定義を置けない（[構文](01-02-syntax.md)、[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)）。初回リリース版の定数は、値がプログラムの実行の前に定まる定数式に限る（[ADR 0123](../decisions/0123-top-level-constants.md)）ので、初期化順序の規則は要らない。設計メモの `go.*` の名前空間は、go.* の層とともに廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。初回リリース版には外部の関数を呼ぶ層を実装しない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。後の版の外部の関数は、利用者のモジュールの中で属性 `@external` を付けて宣言するので、専用の名前空間を持たない（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。

## 前提

識別子の字句の形（小文字識別子と大文字識別子）は[字句構造](01-01-lexical.md)で、宣言・式・パターンの文法は[構文](01-02-syntax.md)で定める。名前が指す束縛の型は[型システム](01-06-type-system.md)で定める。

本章で「束縛」と呼ぶのは、名前とそれが指すもの（関数、値、型、モジュール、構成子、型パラメータ、エフェクト）の組である。

## 仕様

### 名前の種類

【方針】名前は、識別子の先頭の文字の種類で次のように分かれる。

| 種類 | 指すもの | 束縛する構文 |
|---|---|---|
| 小文字の名前 | 値（関数を含む） | トップレベルの関数の宣言、関数とラムダの引数、`let`、パターンの変数。初回リリース版では、定数の宣言 |
| 大文字の名前 | 型、モジュール、エフェクト、データ構成子、型パラメータ、エフェクト変数、型クラス（初回リリース版） | 型の宣言、構成子の宣言、関数の型パラメータの並び、prelude。初回リリース版では、レコードの宣言、型クラスの宣言、実装の型パラメータの並び、import の宣言、エフェクトの宣言、型の別名の宣言、根のディレクトリの下のファイルとディレクトリ（モジュールの名前） |

`_` は名前ではなく、何も束縛しない（[構文](01-02-syntax.md)）。

### トップレベルの名前空間

【決定】トップレベルの大文字の名前（型、モジュール、エフェクトの名前）は、一つの名前空間を共有する（[ADR 0010](../decisions/0010-shared-namespace-and-shadowing.md)、[ADR 0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md)）。型の名前は、同じ名前のモジュールを兼ねる。

【決定】初回リリース版のエフェクトの名前は、モジュールを兼ねない。エフェクトは、宣言したモジュールの名前空間にある一つの名前であり、その操作は、宣言したモジュールの関数である（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。ほかのモジュールからは、エフェクトを `Logging.Log`、操作を `Logging.write` と、モジュールの名前で修飾して書く。一つの名前は、モジュール・型・エフェクトのどれか一つだけを指す。モジュールと同じ名前のエフェクト（モジュール `Log` の中の `effect Log`）は宣言できない。

- 利用者が宣言した型のモジュールには、その型の構成子が入る（`Shape.Circle`）。
- prelude の型のモジュールには、その型を扱う関数が入る（`List.map`、`Integer.toString`）。`Option` と `Result` のモジュールには、その型の構成子も入る（`Option.Some`・`Option.None`・`Result.Ok`・`Result.Error`。[ADR 0099](../decisions/0099-qualified-option-result-constructors.md)）。`List` は構成子を公開しない（[ADR 0007](../decisions/0007-constructors-and-list.md)）。
- 最小実行版の prelude は、型を持たないモジュール（`Console` など）と、エフェクトの名前（`IO`）も定める。初回リリース版の prelude と、IO を行うモジュールの置き場所は、後述の「標準ライブラリの名前空間と prelude（初回リリース版）」で定める。

【方針】初回リリース版では、この名前空間に、レコードの名前、型クラスの名前、型の別名、import で取り込んだモジュールに付けた名前が加わる。型の別名は、モジュールを兼ねない（[ADR 0124](../decisions/0124-type-aliases.md)）。モジュールの中身は次のように広がる。

- レコードの名前は、同じ名前のモジュールを兼ねる。そのモジュールには、フィールドを取り出す関数（`Person.name`）が入る（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。
- 型クラスの名前は、同じ名前のモジュールを兼ねる。そのモジュールには、型クラスのメソッド（`Show.show`）が入る（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。
- 初回リリース版で加える、構成子を公開する prelude の型（`IOErrorKind`・`NetworkErrorKind`・`ByteOrder`・`RoundingMode`）のモジュールには、その型の構成子が入る。これらの構成子は、利用者が宣言した型と同じく型名で修飾して書く（`IOErrorKind.NotFound`、`ByteOrder.BigEndian`、`RoundingMode.HalfToEven`。[基本型の意味論](01-04-types-basic.md)、[エラー処理](01-09-errors.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md)）。
- 組の型 `Pair` と `Triple` のモジュールには、要素を取り出す関数（`Pair.first` など）が入る。構成子は型と同じ名前なので、修飾せずに書く（次の方針。[ADR 0102](../decisions/0102-pair-and-triple.md)）。

prelude が定める名前の一覧は[標準ライブラリ](../03-interop/03-06-stdlib.md)と[エフェクト](01-07-effects.md)で定める。

【方針】トップレベルの名前については、次の場合を誤りとする。

- 二つの型の宣言に同じ名前を付けた場合。初回リリース版では、型・型の別名・レコード・型クラスの宣言と import の名前のどの二つに同じ名前を付けた場合も含む。
- 最小実行版で、型の名前が、prelude の型・モジュール・エフェクトの名前と同じ場合。初回リリース版では、利用者の名前が prelude の名前を隠すことを許す（後述の「標準ライブラリの名前空間と prelude（初回リリース版）」）。
- 二つのトップレベルの関数に同じ名前を付けた場合。初回リリース版では、トップレベルの関数、定数、エフェクトの操作のどの二つに同じ名前を付けた場合も含む。
- 初回リリース版で、トップレベルの大文字の名前（型・型の別名・レコード・型クラス・エフェクトの名前）を `Benitoite` とした場合。`Benitoite` で始まる名前が常に標準ライブラリを指すように、名前空間の根 `Benitoite` は利用者の名前で隠せない（後述の「モジュールと import（初回リリース版）」）。

【方針】最小実行版の prelude は、修飾せずに使える小文字の名前を定めない。prelude の関数は、すべてモジュールの名前で修飾して使う。したがって、トップレベルの関数の名前が prelude の名前と衝突することはない。

【方針】トップレベルの宣言は、宣言の順序によらず、プログラム全体（初回リリース版では、宣言したモジュールの全体）から参照できる。関数は、自分自身とほかのトップレベルの関数を呼び出せる（再帰と相互再帰）。

【決定】初回リリース版の定数も、宣言の順序によらず参照できる。定数の定数式が、直接またはほかの定数を通して自分自身を参照すると誤りとし、診断は循環する定数の並びを示す（[ADR 0123](../decisions/0123-top-level-constants.md)）。型の別名の循環は[型システム](01-06-type-system.md)の「型の別名（初回リリース版）」で定める。

### 修飾された名前の解決

【方針】最小実行版では、`A.b` と `A.B`（[構文](01-02-syntax.md)のドット記法）を、次のように解決する。

1. `A` をトップレベルの大文字の名前として引く。見つからなければ誤りとする。
2. `A` が指すモジュールの中で、ドットの右の名前を引く。見つからなければ誤りとする。

【決定】初回リリース版の修飾した名前は、大文字の名前をドットでいくつでも並べ、最後に大文字か小文字の名前を置いたものである。段の数は制限しない（[ADR 0126](../decisions/0126-import-by-module-name.md)）。修飾した名前は、左から順に一段ずつ解決する。

1. 最初の名前を、次の順に引く。その位置で有効な型パラメータとエフェクト変数（型と `uses` の位置だけ）、同じモジュールのトップレベルの大文字の名前、import で付けた名前、prelude の名前、名前空間の根 `Benitoite`。どれでもなければ誤りとする。利用者の名前には `Benitoite` を付けられない（前述の「トップレベルの名前空間」、後述の「型パラメータとエフェクト変数の有効範囲」と「モジュールと import（初回リリース版）」）ので、最初の名前が `Benitoite` なら、常に名前空間の根を指す。
2. 次の名前を、直前の名前が指すものの中で引く。

   | 直前の名前が指すもの | 中で引く名前 |
   |---|---|
   | 名前空間の根 `Benitoite` | prelude の名前（後述） |
   | モジュール | そのモジュールのトップレベルの関数・定数・型・型の別名・レコード・型クラス・エフェクト・エフェクトの操作。取り込んだモジュールでは `public` を付けたものだけ（後述の「公開（初回リリース版）」） |
   | 型 | その型の構成子 |
   | レコード | レコードの構築と、フィールドを取り出す関数（`Person.name`） |
   | 型クラス | メソッド（`Show.show`） |

3. 最後の名前が、その位置に書けるもの（式では値・構成子・レコードの構築、型の位置では型、`uses` ではエフェクト、パターンでは構成子とレコード）でなければ誤りとする。

したがって、`Geo.Shape.Circle` は、取り込んだモジュール `Geo` の型 `Shape` の構成子 `Circle` であり、`Benitoite.Option.Some` は prelude の `Option` の構成子 `Some` である。`M.R(...)` で `R` が `M` のレコードであれば、`M.R` をレコードの構築として解決する（[構文](01-02-syntax.md)の「レコード（初回リリース版）」）。

`A` を局所の束縛として引くことはない。ドットの右の名前を、値の型から引くこともない（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。

存在しない名前を引いたときの診断は、同じモジュールの中の綴りの近い名前を修正案として示す。初回リリース版で、最初の名前が、取り込んでいない標準ライブラリのモジュール（`Console` など）の名前であるときは、足りない import の宣言（`import Benitoite.IO.Console`）を修正案として示す。単位を持たない名前（`String.length` など）の修正案は[基本型の意味論](01-04-types-basic.md)で定める。

### 修飾しない名前の解決

【方針】式の中の修飾しない小文字の名前は、次の順に引く。

1. その位置で有効な局所の束縛のうち、最も内側のもの。
2. 同じモジュールのトップレベルの関数。初回リリース版では、定数と、そのモジュールで宣言したエフェクトの操作も含む。

どちらにもなければ誤りとする。

【方針】式とパターンの中には、修飾しない大文字の名前を書けない。ただし初回リリース版では、次の二つを修飾せずに書ける。

- レコードの型の名前。レコードの構築とレコードのパターン（[代数的データ型とパターンマッチ](01-05-data-types.md)）の形に限る。
- 構成子が一つだけで、その名前が型の名前と同じ型の構成子（`Pair(1, "one")`、`when Pair(a, b):`。[ADR 0102](../decisions/0102-pair-and-triple.md)）。利用者が宣言した同じ形の型も含む。

型の名前やモジュールの名前をドットなしで式に書くと誤りとする。`Option` と `Result` の構成子を修飾せずに書いたとき（`Some(x)`、`Ok(x)`、`Err(e)`）は、修飾した書き方（`Option.Some(x)`、`Result.Ok(x)`、`Result.Error(e)`）を修正案として示す。

【方針】型を書く位置の大文字の名前は、その関数で宣言した型パラメータ、次にトップレベルの型の名前の順に引く。`uses` の後の修飾しない名前は、その関数で宣言したエフェクト変数、次にエフェクトの名前の順に引く。初回リリース版のエフェクトの名前は、同じモジュールで宣言したエフェクトと、prelude のエフェクト（`State`）である。ほかのモジュールのエフェクトは、修飾した名前（`Console.Write`、`IO.All`）で書く。どちらでもない名前（`Integer` など）は名前解決の誤りとし、診断は関数の型を括弧で囲む書き方を修正案として示す（[ADR 0047](../decisions/0047-parenthesized-types-and-uses-binding.md)、[構文](01-02-syntax.md)）。

### 型パラメータとエフェクト変数の有効範囲

【方針】関数の宣言の型パラメータの並びで宣言した型パラメータとエフェクト変数（[型システム](01-06-type-system.md)、[ADR 0008](../decisions/0008-effect-variables.md)）は、その関数の引数の型、戻り値の型、`uses`、本体の中の型注釈で有効である。型の宣言の型パラメータは、その宣言の構成子の引数の型で有効である。

【方針】型パラメータとエフェクト変数の名前は、同じ並びの中で一意でなければならない。また、トップレベルの大文字の名前と同じであってはならない（`function f[List](...)` は誤り）。初回リリース版では、`Benitoite` であってもならない。

### 局所の束縛の有効範囲

【方針】局所の束縛の有効範囲は次のとおりである。

| 束縛 | 有効範囲 |
|---|---|
| 関数とラムダの引数 | その関数・ラムダの本体 |
| `let x = e` | 同じブロックの、この `let` の次の文からブロックの終わりまで。`e` の中は含まない |
| パターンの変数 | その分岐の本体（[代数的データ型とパターンマッチ](01-05-data-types.md)） |

`let` の右辺 `e` の中では、束縛しようとしている名前は、外側で有効な同じ名前を指す。したがって `let` は再帰的な束縛にならない。再帰する関数は、トップレベルの関数として宣言する。

```text
function f(x: Integer): Integer
  let x = x + 1     // 右辺の x は引数の x
  return x * 2             // 左辺で束縛した x
end function
```

【方針】一つの関数またはラムダの引数の並びに、同じ名前を二度書くと誤りとする。一つのパターンの中で同じ名前を二度束縛することも誤りとする（[代数的データ型とパターンマッチ](01-05-data-types.md)）。

### シャドーイング

【決定】局所の束縛は、その位置で見えている同じ名前（外側の局所の束縛、引数、トップレベルの関数）を隠してよい。同じブロックの中で、先の `let` と同じ名前を `let` で束縛してもよい（[ADR 0010](../decisions/0010-shared-namespace-and-shadowing.md)）。

```text
function normalize(text: String): String
  let text = String.trim(text)
  let text = String.replace(text, "\t", " ")
  return text
end function
```

この例のライブラリの関数（`String.trim` と `String.replace`）は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

隠された束縛の値は変わらない。隠した束縛の有効範囲の外では、隠された束縛が再び見える。

シャドーイングは誤りにも警告にもしない。

【決定】初回リリース版のトップレベルの定数も、局所の束縛で隠してよい。ただし、`case` の分岐のパターンの変数に、見えている定数と同じ名前を付けることは誤りとする（[代数的データ型とパターンマッチ](01-05-data-types.md)の「パターン」、[ADR 0123](../decisions/0123-top-level-constants.md)）。

### モジュールと import（初回リリース版）

【決定】一つのソースファイルを一つのモジュール（module）とする。モジュールの名前は、根のディレクトリからのパスで決まる。根の下の `Lib/Text.bnt` のモジュールの名前は `Lib.Text` である。ファイルの中でモジュールの名前を宣言しない（[ADR 0126](../decisions/0126-import-by-module-name.md)）。根のディレクトリは、実行を始めるファイルがあるディレクトリである（後述の「実行を始めるモジュール（初回リリース版）」）。スクリプトのファイルの拡張子は `.bnt` である（[ADR 0241](../decisions/0241-command-name-and-extension.md)）。

【決定】ほかのモジュールは、`import 名前` の形で名前を書いて取り込む（[ADR 0126](../decisions/0126-import-by-module-name.md)）。

```text
import Lib.Text
import Lib.Geometry.Shape as GShape
import Benitoite.IO.Console

function main(): Unit uses Console.Write
  Console.writeLine(Text.slug("Hello World"))
end function
```

- 取り込んだモジュールは、名前の最後の要素（`Text`）で使う。`as` を書けば、その名前（`GShape`）で使う。
- 取り込んだモジュールは、常に修飾して使う。モジュールの中の名前を修飾せずに使えるようにする取り込み方はない。
- 取り込めるのは、根のディレクトリとその下のファイルと、標準ライブラリのモジュール（後述の「標準ライブラリの名前空間と prelude（初回リリース版）」）だけである。
- 取り込むファイルとディレクトリの名前は、拡張子を除いて大文字で始まる識別子の形でなければならない。この形でない名前のファイル（`my-lib.bnt`、`lib/text.bnt`）は取り込めない。

【方針】import については、次の場合を誤りとする。

- 名前に当たるファイル（`Lib.Text` なら根の下の `Lib/Text.bnt`）がない、または読めない場合。ファイルの名前とモジュールの名前の照合は、大文字と小文字を区別する。
- 名前に当たるファイルのシンボリックリンクを解決した結果が、根のディレクトリの外にある場合。
- 実行を始めるファイルを取り込んだ場合。
- 根のディレクトリの直下の `Benitoite` という名前のファイルやディレクトリを取り込もうとした場合。`Benitoite` で始まる名前は、常に標準ライブラリを指す。
- `as Benitoite` と書いた場合。同じ理由で、取り込んだモジュールに `Benitoite` という名前を付けることはできない。
- 二つの import の最後の要素（`as` を書いたものはその名前）が同じ場合。少なくとも一方に `as` を書かなければならない。
- 取り込んだモジュールに付けた名前が、同じファイルの型・レコード・型クラス・エフェクト・型の別名の名前と同じ場合（トップレベルの大文字の名前の名前空間。[ADR 0010](../decisions/0010-shared-namespace-and-shadowing.md)）。
- 一つのファイルの中で、同じモジュールを二度取り込んだ場合。別々の名前を付けても誤りとする。

【決定】あるモジュールは、どこからどの名前で取り込んでも同じモジュールである。モジュールの同一性は、根のディレクトリからの名前で決まる。したがって、あるモジュールの型は、どこから取り込んでも同じ型である（[ADR 0126](../decisions/0126-import-by-module-name.md)）。

【方針】取り込んだモジュールが取り込んでいるモジュールの名前は、取り込んだ側からは見えない。モジュール `A` が `import Lib.B` と書いても、`A` を取り込んだ側は `A.B` とは書けない。

### 標準ライブラリの名前空間と prelude（初回リリース版）

【決定】標準ライブラリは、処理系と一緒に配るモジュールの全体であり、名前空間 `Benitoite` の下に置く。prelude は、標準ライブラリのうち import なしで使える部分である（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。関数を処理系の実装言語で実装するか、言語で書くかは、prelude かどうかと関係しない。

- prelude の名前 `X` は、import なしで `X` と書け、`Benitoite.X` とも書ける（`List.map` と `Benitoite.List.map`）。prelude に入る型・モジュール・エフェクトは[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。
- IO を行うモジュールは `Benitoite.IO` の下に置く（`Benitoite.IO.Console`・`Benitoite.IO.File`・`Benitoite.IO.Process` など）。これらと、prelude でない標準ライブラリのモジュールは、import しなければ使えない。import なしに完全な名前（`Benitoite.IO.Console.writeLine`）で書くこともできない。
- prelude のモジュール `IO`（`Benitoite.IO`）は、`State` と、`Benitoite.IO` の下のモジュールのエフェクトをまとめたエフェクト `IO.All` を持つ。`Benitoite.Network` の下のモジュールのエフェクト（ネットワークのエフェクト）と `Assert.Check` は、`IO.All` に含めない（[エフェクト](01-07-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。`IO.All` は import なしで書ける。
- 利用者のモジュールで、トップレベルの宣言の名前や import の名前が prelude の名前と同じときは、利用者の名前が優先し、prelude の名前を隠す。その名前を使った箇所の診断（型の誤りなど）には、同じ名前の prelude の名前を隠していることと、`Benitoite.X` で prelude の側を書けることを示す。
- 処理系は、組み込みの型・モジュール・エフェクトを、綴りではなく、`Benitoite` の名前空間のどの名前かで照合する。利用者が同じ綴りの名前を宣言しても、組み込みのものとしては扱わない。

### 公開（初回リリース版）

【決定】トップレベルの関数と型は、既定では宣言したモジュールの中からだけ使える。`public` を付けた関数と型だけを、そのモジュールを取り込んだ側から使える。`public type` は、型とそのすべての構成子を公開する（[ADR 0053](../decisions/0053-private-by-default-with-pub.md)）。

【方針】初回リリース版のレコードと型クラスの公開は、次のとおりとする。

- `public record` は、レコードの型と、構築、一部を変えた値の作成、パターン、フィールドを取り出す関数を公開する。フィールドごとに公開を分けることはできない。
- `public trait` は、型クラスとそのメソッドを公開する。
- `public effect` は、エフェクトとその操作を公開する（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。取り込んだ側は、エフェクトを `M.Log`、操作を `M.write` の形で書く。
- `public const` は、定数を公開する。取り込んだ側は `M.maxRetries` の形で参照し、自分の定数の定数式にも使える（[ADR 0123](../decisions/0123-top-level-constants.md)）。
- `public type 名前 = 型` は、型の別名を公開する。別名が指す型の構成子を公開するかは、元の型の宣言で決まる（[ADR 0124](../decisions/0124-type-aliases.md)）。
- `implement` には `public` を付けない。実装はプログラム全体で有効であり、型クラスや対象の型を公開しているかによらず、どのモジュールでの制約の解決にも使われる（[構文](01-02-syntax.md)の「型クラス（初回リリース版）」、[ADR 0061](../decisions/0061-trait-coherence-orphan-and-overlap.md)）。

【決定】`public` を付けた関数の引数の型と戻り値の型、`public` を付けた型の構成子の引数の型に、`public` を付けていない同じモジュールの型を使うと誤りとする（[ADR 0053](../decisions/0053-private-by-default-with-pub.md)）。

【方針】初回リリース版では、同じ規則を次のものにも当てはめる。`public record` のフィールドの型、`public trait` のメソッドの引数の型と戻り値の型、`public` を付けた関数と `public trait` のメソッドの型クラスの制約に使う型クラス、`public const` の型の注釈（[ADR 0123](../decisions/0123-top-level-constants.md)）、`public` を付けた型の別名の右辺（[ADR 0124](../decisions/0124-type-aliases.md)）。これらに、`public` を付けていない同じモジュールの型や型クラスを使うと誤りとする。

【決定】公開する契約（`public` を付けた関数、`public trait` のメソッド、`public effect` の操作の型）の検査には、次のものも含める（[ADR 0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md)）。これらに、`public` を付けていない同じモジュールの型・型クラス・エフェクトを使うと誤りとする。どの規則も、関数の型の内側（引数に渡す関数の型など）に現れるものを含む。

- `public` を付けた関数と `public trait` のメソッドの `uses` に書くエフェクト。
- `public effect` の操作の引数の型と戻り値の型。
- `public trait` の上位の型クラス。

非公開のエフェクトは、モジュールの中の関数で使い、公開する関数の外へ出る前にハンドラで処理する。

【方針】取り込んだ側が `public` を付けていない名前を引いたときの診断は、その名前が公開されていないことを示す。見つからない名前とは区別する。

### 循環する import（初回リリース版）

【決定】import が循環すると誤りとする。診断は、循環を作る import の並び（`Lib.A -> Lib.B -> Lib.A`）を示す（[ADR 0054](../decisions/0054-no-import-cycles.md)）。

### 実行を始めるモジュール（初回リリース版）

【決定】処理系に実行を指示したファイルを、実行を始めるモジュールとする。ディレクトリを指示したときは、そのディレクトリの `main.bnt` を実行を始めるモジュールとする。根のディレクトリは、実行を始めるファイルがあるディレクトリであり、処理系を起動したときの作業ディレクトリには依存しない（[ADR 0127](../decisions/0127-directory-run-and-root.md)）。実行を始めるモジュールは、ほかのモジュールから取り込めない。根のディレクトリを設定ファイルで指定する仕組みは設けない（[OPEN-048](../open-issues.md#open-048)）。テストの実行でディレクトリを指示したときは、その下のファイルをそれぞれ実行を始めるモジュールとし、根のディレクトリを指示したディレクトリとする（[ADR 0206](../decisions/0206-test-command-line-and-exit-status.md)、[CLI](../06-tooling/06-01-cli.md)）。

【方針】プログラムは、そのモジュールと、そこから import で辿れるすべてのモジュールからなる。プログラムの入口 `main`（[エフェクト](01-07-effects.md)）は、実行を始めるモジュールのトップレベルの関数でなければならない。ほかのモジュールの `main` という名前の関数は、普通の関数として扱う。

【決定】トップレベルの値の定義は、プログラムの実行の前に値の定まる定数に限るので、モジュールを取り込んでも何も計算しない。import は IO も実行時エラーも起こさない（[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)、[ADR 0123](../decisions/0123-top-level-constants.md)）。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（シャドーイングによる名前の取り違えの頻度）
- [OPEN-048](../open-issues.md#open-048): プロジェクトの設定ファイルと、根のディレクトリの指定
- [OPEN-049](../open-issues.md#open-049): パッケージの名前空間と取り込み方
