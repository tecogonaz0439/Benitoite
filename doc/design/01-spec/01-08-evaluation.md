# 評価意味論

- 状態: 確定
- 関連ADR: [0004](../decisions/0004-surface-syntax-skeleton.md), [0005](../decisions/0005-direct-style-effects.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0013](../decisions/0013-evaluation-order-and-tail-calls.md), [0014](../decisions/0014-fine-grain-cbv-core.md), [0030](../decisions/0030-call-stack-size-limit.md), [0034](../decisions/0034-call-trace-in-runtime-errors.md), [0037](../decisions/0037-exit-status-values.md), [0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0055](../decisions/0055-top-level-functions-and-types-only.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0066](../decisions/0066-explicit-laziness-pure-body.md), [0068](../decisions/0068-release-resources-on-stop.md), [0096](../decisions/0096-explicit-return.md), [0097](../decisions/0097-prefix-try.md), [0102](../decisions/0102-pair-and-triple.md), [0114](../decisions/0114-decimal-type.md), [0113](../decisions/0113-div-and-mod-operators.md), [0115](../decisions/0115-structured-io-concurrency.md), [0118](../decisions/0118-effect-handlers.md), [0123](../decisions/0123-top-level-constants.md), [0136](../decisions/0136-map-and-set-in-constants.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md), [0272](../decisions/0272-list-spread-in-list-literals.md)
- 未決事項: なし
- 移行元: [設計メモ](../sources/fp-language-design.md) 1

## 目的と範囲

式と関数の値の計算方法。正格評価、評価順序、明示遅延、末尾呼び出しの保証に加え、関数の定義と適用、引数の個数と部分適用（カリー化するか）、再帰・相互再帰、条件分岐、局所束縛、トップレベルの評価とエントリポイント、実行時エラーによるプログラムの停止を扱う。文法上の形は[構文](01-02-syntax.md)、名前が参照できる範囲は[名前・スコープ・モジュール](01-03-names-modules.md)が扱う。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲と、初回リリース版の明示遅延と、初回リリース版で加える構文の評価の順序を定める。可変のセルの操作は[エフェクト](01-07-effects.md)で、リソーススコープの解放は[リソース管理](01-10-resources.md)で定める。

## 前提

【決定】表層のプログラムの意味は、[コア計算と脱糖](01-12-core-calculus.md)の規則で定める（[ADR 0014](../decisions/0014-fine-grain-cbv-core.md)）。本章の「正格評価」から「末尾呼び出し」までの節は、その規則を表層の構文に沿って文章で要約したものであり、食い違うときはコア計算を正とする。「プログラムの実行」以降の節は、コア計算の外にある規則を定める。

本章が扱うのは、型検査の誤りを含まないプログラムだけである。誤りを含むプログラムは実行しない（[型システム](01-06-type-system.md)）。基本型の演算の値と実行時エラーになる条件は[基本型の意味論](01-04-types-basic.md)で、IO が起きる時期と IO の関数の振る舞いは[エフェクト](01-07-effects.md)で定める。

## 仕様

### 正格評価

【決定】評価は正格である（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。関数を呼び出す前に、すべての引数を評価して値にする。束縛の文（`bind`・`shadow`）の右辺は、その文に来たときに評価する。

評価を遅らせる構文（明示遅延）は、最小実行版にはない。評価を遅らせたいときは、引数のないラムダで包み、必要になったときに呼び出す。

```text
bind later <- lambda() return expensive(x) end lambda   // expensive はまだ呼ばれない
later()                             // ここで呼ばれる
```

`and`・`or` の右のオペランド、`if` の選ばれない分岐、`match` の選ばれない分岐の本体は評価しない。

### 明示遅延（初回リリース版）

【決定】`lazy b end lazy` は、`b` を評価せずに `Lazy[T]` の値を作る。`Lazy.force(l)` は、`l` について最初の呼び出しで `b` を評価し、その値を覚えて返す。二度目以降の呼び出しは、`b` を評価せずに覚えた値を返す（[ADR 0066](../decisions/0066-explicit-laziness-pure-body.md)）。

- `b` はエフェクトを持たない（[型システム](01-06-type-system.md)）ので、いつ、何度 `Lazy.force` を呼んでも、値は同じである。
- `b` の評価で実行時エラーが起きたときは、最初の `Lazy.force` の呼び出しの時点でプログラムが止まる。
- `lazy` の値は、ラムダと同じく、作ったときに有効だった局所の束縛を参照できる。

```text
bind table <- lazy buildTable(rows) end lazy   // buildTable はまだ呼ばれない
Lazy.force(table)                              // ここで一度だけ呼ばれる
Lazy.force(table)                              // 覚えた値を返す
```

IO を遅らせるときは、最小実行版と同じく引数のないラムダを使う。

### 定数の値（初回リリース版）

【決定】トップレベルの定数の値は、その定数式を[基本型の意味論](01-04-types-basic.md)の演算の意味で計算した値である（[ADR 0123](../decisions/0123-top-level-constants.md)）。値はプログラムの実行の前に定まり、定数を参照する式は、どこで何度評価しても同じ値になる。定数式の計算が実行時エラーの条件に当たる定数は、型検査の誤りになる（[型システム](01-06-type-system.md)の「定数の型（初回リリース版）」）ので、定数の参照が実行時エラーを起こすことはない。

【決定】定数式の `Map.fromList`・`Set.fromList`・`Map.empty()`・`Set.empty()` の値は、[標準ライブラリ](../03-interop/03-06-stdlib.md)の同じ関数の値である。引数に同じ鍵（`Set.fromList` では同じ要素）が二つ以上あると、定数の検査の誤りとする（[ADR 0136](../decisions/0136-map-and-set-in-constants.md)）。鍵が同じかは鍵の順序で等しいかで判定するので、`1.0m` と `1.00m` も同じ鍵である。

### 評価順序

【決定】式は、ソースに書いた順に左から右へ評価する（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。

【方針】構文ごとの評価の順序は次のとおりである。

| 式 | 評価の順序 |
|---|---|
| 関数の呼び出し `e0(e1, …, en)` | `e0`、`e1`、…、`en` の順に評価し、その後で呼び出す |
| 構成子の呼び出し `T.C(e1, …, en)` | `e1`、…、`en` の順に評価し、その後で値を作る |
| レコードの構築 `T(f1: e1, …, fn: en)`（初回リリース版） | 書いた順に `e1`、…、`en` を評価し、その後で値を作る |
| 一部を変えたレコード `T(..e, f1: e1, …)`（初回リリース版） | `e`、`e1`、… の順に評価し、その後で値を作る |
| `return e` | `e` を評価し、最も内側の関数かラムダの呼び出しをその値で終える（[構文](01-02-syntax.md)の「`return`」） |
| `try e`（初回リリース版。[エラー処理](01-09-errors.md)） | `e` を評価し、`Result.Ok(v)`・`Option.Some(v)` なら `v` を値とし、`Result.Error`・`Option.None` なら最も内側の関数かラムダの呼び出しをその値で終える |
| 文字列補間 `"…${e1}…${en}…"`（初回リリース版） | `e1`、…、`en` の順に評価し、その後で文字列を作る |
| 二項演算子 `e1 ⊕ e2`（`and`・`or` を除く） | `e1`、`e2` の順に評価し、その後で演算する |
| `e1 and e2`、`e1 or e2` | `e1` を評価し、必要なときだけ `e2` を評価する（[基本型の意味論](01-04-types-basic.md)） |
| 単項の `-e`、`not e` | `e` を評価し、その後で演算する |
| リストリテラル `[e1, …, en]` | `e1`、…、`en` の順に評価する。初回リリース版の展開の要素 `..e` も、書いた位置の順に評価し、`e` の値のリストの要素をその位置に並べる（[ADR 0272](../decisions/0272-list-spread-in-list-literals.md)）。展開を含むリストリテラルは、`List.concatenate` と同じく、値を作る前に結果の長さを計算し、上限を超えるときは値を作らずに停止する（後述の「資源の不足」の「作る値が大きすぎる」） |
| パイプ `e1 \|> e2` | `e1` を評価し、その後で `e2` を展開した式（[構文](01-02-syntax.md)）を評価する。展開した式の中は、この表の規則に従う |
| プレースホルダを含む呼び出し | ラムダを作るだけで、何も評価しない。呼び出す関数とプレースホルダでない引数は、ラムダを呼び出すたびに評価する（[構文](01-02-syntax.md)） |
| ラムダ | 本体を評価しない。ラムダの値を作るだけである |
| `lazy b end lazy`（初回リリース版） | `b` を評価しない。`Lazy` の値を作るだけである |
| `with x1 = e1, …, xn = en do b end with`（初回リリース版） | `e1` を評価して `x1` に束縛し、…、`en` を評価して `xn` に束縛し、`b` を評価し、`xn`、…、`x1` の順に解放する（[リソース管理](01-10-resources.md)） |
| `handle b with case … end handle`（初回リリース版） | `b` を評価する。`b` の中で操作を呼んだときに節を評価する順序は、[エフェクト](01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」で定める |
| ブロック | 文を上から順に評価する。束縛の文（`bind`・`shadow`）は右辺を評価して名前に束縛する。`bind` と `shadow` の評価の意味は同じである。初回リリース版の束縛の文のパターンは、右辺を評価してパターンに照合し、パターンの変数に束縛する |
| `if` | 条件を評価し、選んだ分岐のブロックだけを評価する |
| `match` | 対象の式を一度だけ評価し、選んだ分岐の本体だけを評価する（[代数的データ型とパターンマッチ](01-05-data-types.md)） |
| 名前、リテラル、`()` | 名前が束縛する値、またはリテラルが表す値になる |

例えば、`f(Console.writeLine("a"), g(Console.writeLine("b")))` は、`a` の後に `b` を出力する。初回リリース版の可変のセル（[エフェクト](01-07-effects.md)）の読み書きも、この順序で起きる。`read() |> List.filter(nonEmpty)` は、`read()` を評価してから `List.filter` と `nonEmpty` を評価する。

評価の途中で実行時エラーが起きたときは、残りの部分を評価しない（後述の「実行時エラーによる停止」）。

処理系は、観測できる振る舞い（外部に作用する操作の順序と内容、終わり方）が変わらない場合に限り、評価の順序を変えてよい。

### 関数の呼び出し

【決定】関数はカリー化しない（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。呼び出しの引数の個数は、関数の引数の個数と同じでなければならず、これは型検査で検査する（[型システム](01-06-type-system.md)）。引数の一部だけを与えた関数は、プレースホルダで作る（[構文](01-02-syntax.md)）。

【方針】関数の呼び出しは、評価した引数の値を関数の引数の名前に束縛し、関数の本体のブロックを評価する。本体の中の `return e` を評価したときは、`e` の値が呼び出しの値になり、本体の残りは評価しない。`return` を評価せずに本体の終わりに達したときは、`()` が呼び出しの値になる（[ADR 0096](../decisions/0096-explicit-return.md)）。

- トップレベルの関数は、自分自身とほかのトップレベルの関数を呼び出せる（[名前・スコープ・モジュール](01-03-names-modules.md)）。再帰と相互再帰の深さに、言語としての上限はない。資源の上限は後述する。
- ラムダは、作ったときに有効だった局所の束縛を、本体の中で参照できる。束縛の値は変わらないので、ラムダの値は、それを作ったときの値を使う。
- ラムダは自分自身を名前で参照できない（束縛の文は再帰的な束縛にならない）。再帰する処理は、トップレベルの関数として書く。

### 末尾呼び出し

【決定】末尾位置にある関数の呼び出し（末尾呼び出し）は、何度続けても、呼び出しから戻った後に続ける計算を保持するための記憶域を増やさない（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。呼び出す関数の種類（自分自身、ほかのトップレベルの関数、ラムダ、関数の値、構成子、組み込みの関数）を問わない。

【方針】末尾位置は次のように決まる。

- トップレベルの関数とラムダの本体のブロックは、末尾位置にある。
- 末尾位置にあるブロックの最後の文が式であれば、その式は末尾位置にある。
- 末尾位置にある `return e` の `e` は、末尾位置にある。本体の途中の `return e`（末尾位置にない `return`）の `e` は、末尾位置にない。
- 末尾位置にある `if` の各分岐のブロックと、末尾位置にある `match` の各分岐の本体は、末尾位置にある。
- 末尾位置にある `e1 and e2` と `e1 or e2` の `e2` は、末尾位置にある。
- 末尾位置にある式が、括弧で囲んだ式 `(e)` であれば、`e` は末尾位置にある。
- 末尾位置にあるパイプ `e1 |> e2` は、[構文](01-02-syntax.md)の規則で展開した呼び出しが末尾位置にある。

これら以外の位置（呼び出しの引数、演算子のオペランド、束縛の文の右辺、最後でない文とその中の `return` の式、`if` の条件、`match` の対象、リストリテラルの要素、初回リリース版の `lazy` と `with` のブロックの中、`handle` の本体と節の中）にある呼び出しは、末尾呼び出しではない。

```text
function sumTo(n: Integer, acc: Integer) -> Integer
  return if n = 0 then acc else sumTo(n - 1, acc + n) end if   // 末尾呼び出し
end function

function isEven(n: Integer) -> Boolean
  return if n = 0 then true else isOdd(n - 1) end if           // 末尾呼び出し（相互再帰）
end function

function isOdd(n: Integer) -> Boolean
  return n <> 0 and isEven(n - 1)                             // 末尾呼び出し
end function

function length(n: Integer) -> Integer
  return if n = 0 then 0 else 1 + length(n - 1) end if          // 末尾呼び出しではない
end function

function countDown(n: Integer, acc: Integer) -> Integer
  if n = 0 then
    return acc                                                // 最後でない文の中の return
  end if
  return countDown(n - 1, acc + 1)                            // 末尾呼び出し
end function
```

### プログラムの実行

【方針】プログラムの実行は、[エフェクト](01-07-effects.md)の「プログラムの入口」に従い、トップレベルの関数 `main` を一度呼び出すことで行う。トップレベルには値の定義を置けない。置けるのは関数と型の宣言だけであり、初回リリース版では加えて import・`record`・`trait`・`effect`・`implement`・型の別名の宣言と、定数の宣言を置ける。定数の宣言のほかは評価する式を持たない。定数の定数式は、プログラムの実行の前に値が定まり、その計算は実行時エラーも IO も起こさない（[ADR 0123](../decisions/0123-top-level-constants.md)）。したがって、`main` の前に評価するものはない（[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)）。`main` の呼び出しが終わると、その戻り値によってプログラムが終わる（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）。

プログラムが停止することは保証しない。停止しない再帰を書けば、プログラムは終わらない。処理系は、停止しないことを実行前に検出しない。

### 実行時エラーによる停止

【方針】実行時エラーは、次の種類からなる。「（初回リリース版）」を付けた種類は初回リリース版で、「（サーバモード）」を付けた種類は初回リリース版の後にサーバモードとあわせて加わる。

| 種類 | 起きる操作 | 定める章 |
|---|---|---|
| 整数の溢れ | `Integer` の `+`・`-`・`*`・単項の `-` の結果が範囲を超える。`div` と `Integer.floorDivide` で −2^63 を −1 で割る。`Integer.absolute` に −2^63 を渡す | [基本型の意味論](01-04-types-basic.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md) |
| `Decimal` の溢れ（初回リリース版） | `Decimal` の `+`・`-`・`*`・`/` の結果を丸めても範囲に収まらない | [基本型の意味論](01-04-types-basic.md) |
| 0 による除算 | `div`・`mod`、`Integer.floorDivide`、`Integer.floorModulo`、初回リリース版の `Decimal` の `/` の除数が 0 | [基本型の意味論](01-04-types-basic.md) |
| 書き込みの失敗 | 標準出力と標準エラー出力への書き込みが失敗する | [エフェクト](01-07-effects.md) |
| リソースの解放の失敗（初回リリース版） | `with` のブロックを抜けるときの解放が失敗する。解放の失敗を実行時エラーにしないリソースの型（`Http.Exchange`）を除く | [リソース管理](01-10-resources.md)、[ネットワークのモジュール](../03-interop/03-09-network.md) |
| 解放したリソースの使用（初回リリース版） | 解放したリソースに操作を行う | [リソース管理](01-10-resources.md) |
| 権限の拒否（サーバモード） | 利用者が許可していない操作を行う。初回リリース版では起きない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） | [エフェクト](01-07-effects.md) |
| 継続の二度目の再開（初回リリース版） | ハンドラの一つの節の実行の中で、`resume` を二度呼ぶ | [エフェクト](01-07-effects.md) |
| 引き継いだハンドラの節の誤り（初回リリース版） | タスクの中で呼んだ操作を、そのタスクが引き継いだハンドラが処理するときに、その操作の節が末尾で再開する節でない | [並行処理](01-11-concurrency.md) |
| 引数が定義域の外（初回リリース版） | 標準ライブラリの関数に、その関数が受け付ける範囲の外の引数を渡す（`Decimal.round` の桁数、シフトの量、`File.readChunk` の大きさ、`Process.exit` の終了状態、`Random.integer` の範囲、地方時の UTC からの差、ポートの番号、応答の状態コード、時間切れの長さなど）。`Time.addMilliseconds` などの結果が `Time.Instant` の範囲を超える場合を含む。どの引数が範囲の外かは、各関数の章で定める | [基本型の意味論](01-04-types-basic.md)、[IO のモジュール](../03-interop/03-07-io-modules.md)、[テキストとデータの処理](../03-interop/03-08-text-and-data.md)、[ネットワークのモジュール](../03-interop/03-09-network.md) |
| 応答の二度目の送信（初回リリース版） | 一つの `Http.Exchange` に `Http.respond` を二度呼ぶ | [ネットワークのモジュール](../03-interop/03-09-network.md) |
| タスクの待ち合いの行き詰まり（初回リリース版） | 進められるタスクがなく、外部に作用する操作の完了を一つも待っていないときに、ほかのタスクの終わりなどを待つタスクがある（[ADR 0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)） | [並行処理](01-11-concurrency.md) |

初回リリース版の並行処理では、どのタスクで実行時エラーが起きても、プログラム全体を止める。止めるときのタスクごとのリソースの解放は、[並行処理](01-11-concurrency.md)で定める。

prelude の関数が起こす実行時エラーは、[標準ライブラリ](../03-interop/03-06-stdlib.md)の各関数の「実行時エラー」の欄にも示す。コマンドライン引数が正しい UTF-8 でない場合は、実行時エラーではなく、`main` を呼ぶ前に終わる（[エフェクト](01-07-effects.md)の「プログラムの入口」）。報告に使う診断コードは[診断エンジン](../02-impl/02-10-diagnostics.md)で定める。

【方針】実行時エラーが起きたときは、処理系は次のように振る舞わなければならない。この手順による終了を、プロセスの異常終了（クラッシュ）と呼ぶ。

1. 評価をただちにやめる。実行時エラーを起こした演算の後に来るはずだった評価と、外部に作用する操作は、一つも行わない。初回リリース版では、続けて、開いている `with` のリソースを内側のスコープから順に解放する（[リソース管理](01-10-resources.md)、[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。解放の失敗は、手順 3 の報告に加える。
2. それまでに書き込んだ出力を、すべて出力する（[エフェクト](01-07-effects.md)）。
3. 実行時エラーの種類と、実行時エラーを起こした式のソース上の位置を、標準エラー出力に書く。その時点で残っている呼び出しの履歴（call trace）も書く（[ADR 0034](../decisions/0034-call-trace-in-runtime-errors.md)）。実行時エラーを起こした式が 標準ライブラリのソースの中にあるときは、その式に至る呼び出しのうち、利用者のソースにある最も内側の呼び出しの位置を書く。
4. 失敗を表す終了状態で終わる。

資源の不足で停止するときも、手順 1 の解放を行う。

【決定】書き込みの失敗は、この手順の例外とする（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。処理系は書き込みの失敗を、書き込みの関数を呼び出した時点ではなく後で検出してよく、検出した時点で停止する。このとき、手順 1 に反して、失敗した書き込みの後に行った評価と外部に作用する操作は、検出するまでの分が行われたまま残る。手順 3 の報告は、ソース上の位置を持たない。検出は、遅くともプログラムを終える前の書き出しで行う（[エフェクト](01-07-effects.md)の「IO の失敗」）。

実行時エラーを捕捉する手段はない（初回リリース版でも設けない。[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。【決定】関数の型は、その関数が実行時エラーを起こしうるかを表さない。実行時エラーは、上の手順でプロセスを異常終了（クラッシュ）させる（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

標準エラー出力に書く内容の形式は[診断エンジン](../02-impl/02-10-diagnostics.md)で、終了状態の具体的な値は [CLI](../06-tooling/06-01-cli.md) で定める。

### 資源の不足

【方針】処理系は、次の資源に上限を持ってよい。上限に達したときは、実行時エラーと同じ手順で停止する。標準エラー出力には、資源が不足したこととその種類を書く。

| 資源の不足の種類 | 上限の対象 |
|---|---|
| 呼び出しの入れ子が深すぎる | 末尾位置にない呼び出しの入れ子の深さ |
| 作る値が大きすぎる | 一つの組み込みの関数の呼び出しで作る文字列の大きさ（バイト数）、リストの長さ、初回リリース版の `Bytes` の大きさ（バイト数。入力を読む操作が作るものを含む）（[ADR 0049](../decisions/0049-size-limit-for-built-values.md)）。組み込みの関数は、値を作る前に結果の大きさを計算し、上限を超えるときは値を作らずに停止する |
| メモリが足りない | メモリの使用量 |

資源の不足は、処理系と実行環境によって起こる条件が変わるので、[コア計算と脱糖](01-12-core-calculus.md)の実行の規則には現れない。上限を設けるかと上限の値は、処理系の設計（[ランタイム](../02-impl/02-09-runtime.md)など）で定める。末尾呼び出しを続けることは、呼び出しの入れ子を深くしない。

【決定】この手順で停止するのは、処理系が自ら設けた上限に達したときに限る。処理系が上限を設けていない資源が実行環境で尽きたとき（メモリが足りない場合など）は、処理系はこの手順によらずに終わってよい。このとき、出力の一部が書き出されないことがあり、終了状態は言語仕様では定めない（[ADR 0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md)）。

## 未決事項

なし。
