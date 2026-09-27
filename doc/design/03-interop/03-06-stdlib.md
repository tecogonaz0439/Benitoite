# 標準ライブラリ

- 状態: 草稿
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0009](../decisions/0009-typing-without-type-classes.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0030](../decisions/0030-call-stack-size-limit.md), [0041](../decisions/0041-list-as-linked-list.md), [0042](../decisions/0042-minimal-prelude-scope.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) なし（10 の層1・層2）

## 目的と範囲

prelude の導入方法と初期版の API 範囲、std の API 設計、永続コレクション。永続コレクションは、公開 API と利用者向けの規則（等値比較、反復順序）に加え、実装設計（採用するデータ構造と内部表現、構造共有の規則、各操作の計算量の目標、テストする不変条件）も扱う。値を VM 上で保持・受け渡す表現は[仮想機械](../02-impl/02-08-vm.md)、メモリの生存管理は[ランタイム](../02-impl/02-09-runtime.md)が扱う。永続コレクションの実装設計が大きくなった場合は、`02-impl/` の独立章に分けることを検討する。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の prelude だけを定める。最小実行版のライブラリは prelude だけであり、std と永続コレクション（マップ、集合、ベクタ）はない。これらは v1 で加える。設計メモの go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。v1 のライブラリを prelude と std のほかにどう提供するかは【未決】である（[OPEN-035](../open-issues.md#open-035)）。

## 前提

基本型の演算子と、位置を扱う文字列の関数、型の変換の関数は[基本型の意味論](../01-spec/01-04-types-basic.md)（[ADR 0006](../decisions/0006-basic-types-semantics.md)）で、IO を行う関数は[エフェクト](../01-spec/01-07-effects.md)で定める。本章は、それらを含む prelude の関数の一覧と、残りの関数の意味を定める。prelude の名前はすべてモジュールの名前で修飾して使う（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)）。

prelude は、処理系の実装言語（Rust）で実装する組み込みの表と、言語で書いた prelude のソースから成る（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)）。関数を引数にとる関数は prelude のソースで定める（[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の Σ）。

## 仕様

### 範囲と名前の付け方

【決定】最小実行版の prelude には、仕様の各章・完了条件・ベンチマークが参照する関数に加え、文字列とリストのよく使う操作と、`Option`・`Result` をつなぐ関数を入れる。Unicode の文字の性質の規則に依る関数（大文字と小文字の変換、文字の分類）は v1 に回し、最小実行版で文字を分類する関数は ASCII の範囲だけを扱って名前にそれを示す（[ADR 0042](../decisions/0042-minimal-prelude-scope.md)）。

【方針】関数の引数は、操作の対象（文字列、リスト、`Option` など）を第 1 引数に置く。パイプ（`xs |> List.map(f)`）で対象を渡せるようにするためである。

【方針】以下の表の型の欄の `fn[T, effect E](A1, …) -> B uses E` は、型パラメータとエフェクト変数を持つ関数の型を表す本章の表記である。関数の宣言の型パラメータの並び（[構文](../01-spec/01-02-syntax.md)）と同じ意味を持つ。

【方針】以下の表の「実装」の欄は、関数を組み込みの表（Rust）で実装するか、prelude のソース（言語）で定めるかを示す。この区別は利用者からは見えない。「実行時エラー」の欄が空の関数は、実行時エラーを起こさない。

### 関数を引数にとる関数の共通の規則

【方針】関数を引数にとる関数は、次の規則に従う。

- 受け取った関数を、要素を先頭から順に一つずつ渡して呼ぶ。同じ要素について二度呼ばない。受け取った関数が IO を行うとき、その IO はこの順に起こる。
- `List.any`・`List.all`・`List.find` は、結果が決まった時点で残りの要素について関数を呼ばない。
- 受け取った関数の呼び出しで実行時エラーが起きたら、そこで止まる（[評価意味論](../01-spec/01-08-evaluation.md)）。
- 型は、受け取る関数のエフェクトをエフェクト変数 `E` で表し、同じ `E` を自身のエフェクトとする（[ADR 0008](../decisions/0008-effect-variables.md)）。

【方針】prelude のソースの関数は、リストの長さに比例する深さの末尾でない再帰を使わない。長いリストを処理しても、呼び出しの入れ子が深くならないようにするためである（[ADR 0030](../decisions/0030-call-stack-size-limit.md)）。

### 作る値の大きさの上限

【決定】文字列かリストを新しく作る組み込みの関数（`String.repeat`・`String.join`・`String.replace`・`String.fromChars`・`String.split`・`String.lines`・`String.chars`・`List.range`・`List.prepend`・`List.append`・`List.concat` など）と、`String` の `+` は、結果の大きさを値を作る前に計算し、処理系の上限を超えるときは、値を作らずに資源の不足で停止する（[ADR 0049](../decisions/0049-size-limit-for-built-values.md)、[評価意味論](../01-spec/01-08-evaluation.md)）。

【方針】上限は、文字列が 2^30 バイト、リストが 2^24 要素である。上限の値と、結果の大きさの計算の仕方は[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」で定める。

### Int

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Int.toString(n)` | `fn(Int) -> String` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「型の変換」 | | 組み込み |
| `Int.parse(s)` | `fn(String) -> Option[Int]` | 同上 | | 組み込み |
| `Int.toFloat(n)` | `fn(Int) -> Float` | 同上 | | 組み込み |
| `Int.floorDiv(a, b)` | `fn(Int, Int) -> Int` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「Int」 | 同左 | 組み込み |
| `Int.mod(a, b)` | `fn(Int, Int) -> Int` | 同上 | 同左 | 組み込み |
| `Int.abs(n)` | `fn(Int) -> Int` | `n` の絶対値 | `n` が −2^63 | 組み込み |
| `Int.min(a, b)` | `fn(Int, Int) -> Int` | 小さいほう | | 組み込み |
| `Int.max(a, b)` | `fn(Int, Int) -> Int` | 大きいほう | | 組み込み |

### Float

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Float.toString(x)` | `fn(Float) -> String` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「型の変換」 | | 組み込み |
| `Float.parse(s)` | `fn(String) -> Option[Float]` | 同上 | | 組み込み |
| `Float.truncate(x)` | `fn(Float) -> Option[Int]` | 同上 | | 組み込み |
| `Float.isNaN(x)` | `fn(Float) -> Bool` | `x` が NaN か | | 組み込み |
| `Float.abs(x)` | `fn(Float) -> Float` | 符号を正にした値。NaN は NaN | | 組み込み |
| `Float.floor(x)` | `fn(Float) -> Float` | `x` 以下の最大の整数値。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ | | 組み込み |
| `Float.ceil(x)` | `fn(Float) -> Float` | `x` 以上の最小の整数値。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ（`Float.ceil(-0.5)` は `-0.0`） | | 組み込み |
| `Float.round(x)` | `fn(Float) -> Float` | 最も近い整数値。ちょうど中間なら 0 から遠いほう。NaN・無限大・±0 はそのまま。結果が 0 のとき、符号は `x` と同じ（`Float.round(-0.4)` は `-0.0`） | | 組み込み |
| `Float.sqrt(x)` | `fn(Float) -> Float` | IEEE 754 の平方根。負の数は NaN | | 組み込み |

### Char

| 関数 | 型 | 値 | 実行時エラー | 実装 |
|---|---|---|---|---|
| `Char.toInt(c)` | `fn(Char) -> Int` | [基本型の意味論](../01-spec/01-04-types-basic.md)の「Char」 | | 組み込み |
| `Char.fromInt(n)` | `fn(Int) -> Option[Char]` | 同上 | | 組み込み |
| `Char.toString(c)` | `fn(Char) -> String` | 同上 | | 組み込み |
| `Char.isAsciiDigit(c)` | `fn(Char) -> Bool` | `c` が `'0'`〜`'9'` か | | 組み込み |
| `Char.isAsciiWhitespace(c)` | `fn(Char) -> Bool` | `c` が ASCII の空白（U+0020、U+0009、U+000A、U+000D）か | | 組み込み |

### String

位置と長さを扱う関数（`byteLength`・`byteSlice`・`charCount`・`charAt`・`charSlice`）は[基本型の意味論](../01-spec/01-04-types-basic.md)で定め、すべて組み込みで実装する。

| 関数 | 型 | 値 | 実装 |
|---|---|---|---|
| `String.isEmpty(s)` | `fn(String) -> Bool` | `s` が空文字列か | 組み込み |
| `String.contains(s, sub)` | `fn(String, String) -> Bool` | `s` が `sub` を部分文字列として含むか。`sub` が空なら `true` | 組み込み |
| `String.startsWith(s, prefix)` | `fn(String, String) -> Bool` | `s` が `prefix` で始まるか | 組み込み |
| `String.endsWith(s, suffix)` | `fn(String, String) -> Bool` | `s` が `suffix` で終わるか | 組み込み |
| `String.byteIndexOf(s, sub)` | `fn(String, String) -> Option[Int]` | `sub` が最初に現れるバイト位置。現れなければ `None`。`sub` が空なら `Some(0)` | 組み込み |
| `String.split(s, sep)` | `fn(String, String) -> List[String]` | 後述 | 組み込み |
| `String.lines(s)` | `fn(String) -> List[String]` | 後述 | 組み込み |
| `String.join(xs, sep)` | `fn(List[String], String) -> String` | `xs` の要素を、間に `sep` を挟んで順に連結した文字列。`xs` が空なら空文字列 | 組み込み |
| `String.trim(s)` | `fn(String) -> String` | 先頭と末尾の ASCII の空白（`Char.isAsciiWhitespace`）を取り除いた文字列 | 組み込み |
| `String.replace(s, old, new)` | `fn(String, String, String) -> String` | `s` の中の `old` の出現を、先頭から重ならないように順にすべて `new` に置き換えた文字列。`old` が空なら `s` | 組み込み |
| `String.repeat(s, n)` | `fn(String, Int) -> String` | `s` を `n` 回連結した文字列。`n` が 0 以下なら空文字列 | 組み込み |
| `String.chars(s)` | `fn(String) -> List[Char]` | `s` のスカラー値を順に並べたリスト | 組み込み |
| `String.fromChars(cs)` | `fn(List[Char]) -> String` | `cs` の文字を順に連結した文字列 | 組み込み |

【方針】`String.split(s, sep)` は次の値を返す。

- `sep` が空でなければ、`s` を `sep` の出現（先頭から重ならないように探す）で区切った部分文字列の並び。区切りの前後や連続する区切りの間は空文字列になる。要素は常に 1 個以上であり、`s` が空なら `[""]` である（`String.split("a,,b", ",")` は `["a", "", "b"]`）。
- `sep` が空なら、`s` の各スカラー値を 1 文字の文字列にした並び。`s` が空なら `[]` である。

【方針】`String.lines(s)` は、`s` を行に分けた並びを返す。行は LF（U+000A）で区切り、各行の末尾に CR（U+000D）が一つあれば取り除く。`s` が LF で終わるとき、その後の空の行は含めない。`s` が空なら `[]` である（`String.lines("a\r\nb\n")` は `["a", "b"]`、`String.lines("a\n\nb")` は `["a", "", "b"]`）。

### List

【決定】`List[T]` は構成子を公開しない型であり、リストはリストリテラルと `List` モジュールの関数だけで作り、分解する（[ADR 0007](../decisions/0007-constructors-and-list.md)）。`List[T]` は、長さを持つ単方向の連結リストで表す（[ADR 0041](../decisions/0041-list-as-linked-list.md)）。内部の表現は後述の「List の内部の表現」で定める。

| 関数 | 型 | 値 | 計算量 | 実装 |
|---|---|---|---|---|
| `List.length(xs)` | `fn[T](List[T]) -> Int` | 要素の数 | O(1) | 組み込み |
| `List.isEmpty(xs)` | `fn[T](List[T]) -> Bool` | 空か | O(1) | 組み込み |
| `List.head(xs)` | `fn[T](List[T]) -> Option[T]` | 先頭の要素。空なら `None` | O(1) | 組み込み |
| `List.tail(xs)` | `fn[T](List[T]) -> Option[List[T]]` | 先頭を除いたリスト。空なら `None` | O(1) | 組み込み |
| `List.get(xs, i)` | `fn[T](List[T], Int) -> Option[T]` | 位置 `i`（0 から数える）の要素。`i` が範囲の外なら `None` | O(i) | 組み込み |
| `List.prepend(xs, x)` | `fn[T](List[T], T) -> List[T]` | 先頭に `x` を加えたリスト | O(1) | 組み込み |
| `List.append(xs, x)` | `fn[T](List[T], T) -> List[T]` | 末尾に `x` を加えたリスト | O(n) | 組み込み |
| `List.concat(xs, ys)` | `fn[T](List[T], List[T]) -> List[T]` | `xs` の後に `ys` を続けたリスト | O(len xs) | 組み込み |
| `List.reverse(xs)` | `fn[T](List[T]) -> List[T]` | 逆順のリスト | O(n) | 組み込み |
| `List.take(xs, n)` | `fn[T](List[T], Int) -> List[T]` | 先頭から `n` 個。`n` が 0 以下なら `[]`、長さ以上なら `xs` | O(n) | 組み込み |
| `List.drop(xs, n)` | `fn[T](List[T], Int) -> List[T]` | 先頭の `n` 個を除いたリスト。`n` が 0 以下なら `xs`、長さ以上なら `[]` | O(n) | 組み込み |
| `List.range(start, end)` | `fn(Int, Int) -> List[Int]` | `start` 以上 `end` 未満の整数を昇順に並べたリスト。`end` が `start` 以下なら `[]` | O(end − start) | 組み込み |
| `List.contains(xs, x)` | `fn[T](List[T], T) -> Bool`。`T` は等値の型 | `x` と `==` で等しい要素があるか | O(n) | 組み込み |
| `List.sort(xs)` | `fn[T](List[T]) -> List[T]`。`T` は `Int`・`Float`・`String`・`Char` のどれか | 昇順に並べ替えたリスト（後述） | O(n log n) | 組み込み |
| `List.map(xs, f)` | `fn[T, U, effect E](List[T], fn(T) -> U uses E) -> List[U] uses E` | 各要素に `f` を適用した値のリスト | O(n) | ソース |
| `List.filter(xs, p)` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> List[T] uses E` | `p` が `true` を返す要素だけを、順序を保って並べたリスト | O(n) | ソース |
| `List.fold(xs, init, f)` | `fn[T, A, effect E](List[T], A, fn(A, T) -> A uses E) -> A uses E` | `init` から始め、先頭の要素から順に `f(acc, x)` で畳み込んだ値 | O(n) | ソース |
| `List.forEach(xs, f)` | `fn[T, effect E](List[T], fn(T) -> Unit uses E) -> Unit uses E` | 各要素に `f` を適用する | O(n) | ソース |
| `List.any(xs, p)` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Bool uses E` | `p` が `true` を返す要素があるか | O(n) | ソース |
| `List.all(xs, p)` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Bool uses E` | すべての要素で `p` が `true` を返すか。空なら `true` | O(n) | ソース |
| `List.find(xs, p)` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Option[T] uses E` | `p` が `true` を返す最初の要素 | O(n) | ソース |

計算量の n は `xs` の長さである。関数を引数にとる関数の計算量は、受け取った関数の呼び出しを 1 と数えたものである。

`List.contains` の「`T` は等値の型」と `List.sort` の型の制約は、利用者が関数の型に書けない制約であり、prelude の関数だけが持てる（[ADR 0009](../decisions/0009-typing-without-type-classes.md)）。

【方針】`List.sort` は安定な並べ替えであり、等しい要素の順序を保つ。順序は `<` に従う（[基本型の意味論](../01-spec/01-04-types-basic.md)）。ただし `Float` の NaN は、どの値よりも後に置き、NaN どうしは元の順序を保つ。`0.0` と `-0.0` は等しいものとして扱う。

`List.append` と `List.concat` は、`xs` のセルを写して新しいリストを作る。末尾に一つずつ加えてリストを作ると、要素の数の 2 乗の時間がかかるので、先頭に加えてから `List.reverse` するか、`List.map` などを使う。

### Option

`Option` の関数は、すべて prelude のソースで定める。

【決定】関数の名前は Rust の名前を lowerCamelCase にしたものに合わせ、`None` のときに実行時エラーになる `unwrap` などは設けない（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `Option.map(o, f)` | `fn[T, U, effect E](Option[T], fn(T) -> U uses E) -> Option[U] uses E` | `Some(x)` なら `Some(f(x))`、`None` なら `None` |
| `Option.andThen(o, f)` | `fn[T, U, effect E](Option[T], fn(T) -> Option[U] uses E) -> Option[U] uses E` | `Some(x)` なら `f(x)`、`None` なら `None` |
| `Option.unwrapOr(o, d)` | `fn[T](Option[T], T) -> T` | `Some(x)` なら `x`、`None` なら `d` |
| `Option.isSome(o)` | `fn[T](Option[T]) -> Bool` | `Some` か |
| `Option.isNone(o)` | `fn[T](Option[T]) -> Bool` | `None` か |
| `Option.okOr(o, e)` | `fn[T, X](Option[T], X) -> Result[T, X]` | `Some(x)` なら `Ok(x)`、`None` なら `Err(e)` |

### Result

`Result` の関数は、すべて prelude のソースで定める。名前の付け方は `Option` と同じである（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `Result.map(r, f)` | `fn[T, U, X, effect E](Result[T, X], fn(T) -> U uses E) -> Result[U, X] uses E` | `Ok(x)` なら `Ok(f(x))`、`Err(e)` なら `Err(e)` |
| `Result.mapErr(r, f)` | `fn[T, X, Y, effect E](Result[T, X], fn(X) -> Y uses E) -> Result[T, Y] uses E` | `Ok(x)` なら `Ok(x)`、`Err(e)` なら `Err(f(e))` |
| `Result.andThen(r, f)` | `fn[T, U, X, effect E](Result[T, X], fn(T) -> Result[U, X] uses E) -> Result[U, X] uses E` | `Ok(x)` なら `f(x)`、`Err(e)` なら `Err(e)` |
| `Result.unwrapOr(r, d)` | `fn[T, X](Result[T, X], T) -> T` | `Ok(x)` なら `x`、`Err` なら `d` |
| `Result.isOk(r)` | `fn[T, X](Result[T, X]) -> Bool` | `Ok` か |
| `Result.isErr(r)` | `fn[T, X](Result[T, X]) -> Bool` | `Err` か |
| `Result.ok(r)` | `fn[T, X](Result[T, X]) -> Option[T]` | `Ok(x)` なら `Some(x)`、`Err` なら `None` |

### IO を行う関数と IoError

【方針】IO を行う関数（`Console.print`・`Console.println`・`Console.eprintln`・`File.readText`・`Process.args`）と `IoError.message` は[エフェクト](../01-spec/01-07-effects.md)で定め、すべて組み込みで実装する。IO の失敗は `Result` の `Err` で返す（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。`File.readText` は、ファイルの内容が正しい UTF-8 でなければ `Err` を返す（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。

### List の内部の表現

【方針】リストは、次のセルの連なり（単方向の連結リスト、singly linked list）で表す。空のリストはセルを持たない一つの値である。

| 欄 | 内容 |
|---|---|
| 先頭 | 先頭の要素の値（[仮想機械](../02-impl/02-08-vm.md)の値） |
| 残り | 残りのリスト（空のリストか、次のセル）への参照 |
| 長さ | このセルから始まるリストの長さ |

- セルは、作った後に変更しない。したがって、複数のリストが同じセルを共有しても（構造共有、structural sharing）、一方の操作が他方に影響しない。
- 先頭への追加（`List.prepend`）は、新しいセルを一つ作り、残りに元のリストを共有する。`List.tail` と `List.drop` は、元のリストの途中のセルをそのまま返す。
- `List.append`・`List.concat`・`List.take`・`List.reverse` と関数を引数にとる関数は、新しいセルを作る。`List.concat(xs, ys)` は `xs` のセルを写し、`ys` を共有する。
- リストリテラル `[e1, …, en]` は、末尾の要素から順にセルを作る。
- リストどうしの `==` と `List.contains`、`List.sort` の比較は、処理系の再帰に頼らずに要素を辿る（[仮想機械](../02-impl/02-08-vm.md)）。

【方針】処理系のテストでは、リストについて次の不変条件を確かめる（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)）。

- 各セルの長さは、残りのリストの長さに 1 を加えた値である。
- どの関数も、引数のリストのセルを変更しない（関数を呼ぶ前後で、引数のリストの要素の並びが変わらない）。
- `List.prepend`・`List.tail`・`List.drop` は、セルを写さない。

### prelude のソースの書き方

【方針】prelude のソースは、[名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「prelude」に従って書く。prelude のソースで定める関数は、次の形で書く。

- モジュールの名前で修飾した関数（`fn List.map[...](...)`）が、利用者から見える関数である。
- 補助の関数は、修飾しない名前のトップレベルの関数として書く。修飾しない名前の関数は、prelude のソースの中からだけ参照でき、利用者のプログラムからは見えない。
- 組み込みの関数と、ほかのモジュールの公開の関数は、prelude のソースの中でもモジュールの名前で修飾して使う（`List.reverse` など）。
- リストを辿る処理は、累積の引数を持つ末尾再帰で書き、必要なら最後に `List.reverse` で順序を戻す。

```text
fn List.map[T, U, effect E](xs: List[T], f: fn(T) -> U uses E) -> List[U] uses E {
  List.reverse(mapInto(xs, f, []))
}

fn mapInto[T, U, effect E](xs: List[T], f: fn(T) -> U uses E, acc: List[U]) -> List[U] uses E {
  match List.head(xs) {
    None => acc
    Some(x) => {
      let y = f(x)
      mapInto(List.drop(xs, 1), f, List.prepend(acc, y))
    }
  }
}
```

この例は書き方を示すものであり、`List.head` と `List.drop` の代わりに、prelude のソースの中だけで使える組み込みの関数（`Option` を作らずに先頭と残りを取り出すもの）を使ってよい。prelude のソースの関数の定義そのものは、実装プランで与える。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（最小実行版の prelude の関数が、測定に足りるか）
- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
