# 他言語の名前付き引数

2026-10-14 に一次資料で以下の事実を確認した。各言語の便利さや LLM の成功率を測った結果ではない。Benitoite への提案は、確認した規則からの推論として分けて書く。

## 確認した規則

| 言語 | 確認した事実 | 一次資料 |
|---|---|---|
| Swift | 呼ぶときのラベルと本体のパラメータ名を区別し、既定では同じ名前になる。`_` でラベルを省く宣言もできる。引数は宣言の順で渡す | [The Swift Programming Language: Functions](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/Functions.md) の「Defining and Calling Functions」「Function Argument Labels and Parameter Names」 |
| Swift | 呼び出しのラベルは関数型の一部ではない。違うラベルを持つ関数も、引数型と戻り値型が合えば同じ関数型の変数へ入る | [The Swift Programming Language: Types](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Types.md) の「Function Type」 |
| Kotlin | 名前付き引数を任意の順で指定でき、位置指定と名前指定を混ぜる例がある。省略した既定値の後は名前を要する。最後の引数が関数ならラムダを括弧の外に置ける | [Functions](https://kotlinlang.org/docs/functions.html#named-arguments) の「Named arguments」と「Default arguments」 |
| Kotlin | 関数型の `(x: Int, y: Int) -> Point` のような名前は、引数の意味を説明するために付けられる。公式の型の例では型と戻り値をもとに関数型を説明する | [Higher-order functions and lambdas](https://kotlinlang.org/docs/lambdas.html#function-types)、[仕様の Function types](https://kotlinlang.org/spec/type-system.html#function-types) |
| OCaml | `~x` のラベルが型に現れる。ラベルで引数を対応付けるため指定順を変えられ、任意の引数で部分適用できる。同じラベルを持つ引数同士は順序で区別する | [OCaml 5.4 Manual: Labeled arguments](https://ocaml.org/manual/5.4/lablexamples.html) の冒頭 |
| OCaml | 未注釈の高階関数内で `g ~y:2 ~x:3` と呼ぶと、推論した型のラベル順が `y`・`x` になる。`x`・`y` 順の関数を渡すと不一致になる例があり、事前の型情報があれば扱えると説明される | [同章「Labels and type inference」](https://ocaml.org/manual/5.4/lablexamples.html#s%3Alabels-inference) |
| Python | 位置指定とキーワード指定を混ぜられる。未知の名前、同じ引数への二重指定、必要な引数の不足は呼び出しの誤りになる。`/` と `*` で位置指定だけ・名前指定だけのパラメータを定められる | [Python Tutorial: More Control Flow Tools](https://docs.python.org/3/tutorial/controlflow.html#keyword-arguments) の「Keyword Arguments」「Special parameters」 |
| Python | 式は左から右へ評価される。関数呼び出しも、関数の式、続く引数の式という順の例で説明される | [Python Language Reference: Evaluation order](https://docs.python.org/3/reference/expressions.html#evaluation-order) |

Swift の文書サイトは今回の閲覧では本文を取得できなかったため、公式の文書リポジトリの原文を確認した。Kotlin の名前が関数型に書けることだけを根拠に、Benitoite と同じ厳密な名前の適合を保証する仕組みだとは扱わない。Python の名前の誤りは、Benitoite が目指す静的な検出と同じ段階の検査ではない。

## 判断への示唆

名前で指定できることと、名前が関数型の契約に入ることは別の選択である。Swift の方式をそのまま根拠にして、Benitoite のラムダの名前の不一致を暗黙に許す案は出せない。TODO の了承済みの方針では、単一の引数も名前が契約に入るため、関数を別の用途へ渡すときの書き直しの負担が増える。この負担は、役割ごとの標準名と診断の具体的な例で減らす案になる。

OCaml の例は、呼び出しに書いた順から未知の関数型を推論すると、既知の契約の宣言順と衝突する場合があることを示す。Benitoite も契約の順序を一致させるため、Q4 では不明な関数の契約を使用順だけで確定しない案を推す。OCaml と Benitoite はカリー化の有無などが異なるので、OCaml の実装方式をそのまま採用する根拠にはしない。

Kotlin の末尾ラムダや Swift のラベル省略は、呼び出しの読みやすさのために例外を設ける選択肢の実例である。Benitoite では「複数引数はすべて名前付き、混在なし」が了承済みであり、例外を入れるならその方針を変更する判断になる。今回の推す案は、例を名前付きへ直して例外を増やさないものである。

Python の評価順の説明は、名前による対応と式の評価順を分けて仕様に書く際の参考になる。実行時に引数名を調べる方法や辞書を作る方法を Benitoite に導入する根拠にはしない。
