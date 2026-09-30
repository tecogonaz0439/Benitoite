# 0128. 標準ライブラリを `Benitoite` の名前空間に置き、prelude を import なしで使える部分とし、IO のモジュールを `Benitoite.IO` の下に置く

- 状態: 採択（決定 3 の `Benitoite.IO.Network` を、[0140](0140-network-separated-from-local-io.md) で `Benitoite.Network.Http` に改めた）
- 日付: 2026-09-28
- 関連章: [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [エフェクト](../01-spec/01-07-effects.md), [名前解決とモジュール読込](../02-impl/02-04-resolver.md), [用語集](../00-overview/00-04-glossary.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-035](../open-issues.md#open-035), [OPEN-049](../open-issues.md#open-049)

## 背景

これまでの設計では、prelude を「処理系が最初から提供する型・モジュール・関数の集まり」とし、その中身を、Rust で実装する組み込みの表と、言語で書いた prelude のソースに分けていた（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)）。`List`・`String`・`Console`・`File`・`Process` などが、どれも import なしで修飾して使える。標準ライブラリの名前空間は決めておらず、後で加える JSON や HTTP を import なしで使わせるかも決めていない（[OPEN-035](../open-issues.md#open-035)）。利用者がモジュールを名前で取り込むようにした（[ADR 0126](0126-import-by-module-name.md)）ので、標準ライブラリと利用者のモジュールの名前が衝突しうる。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「prelude と標準ライブラリ」に記録した。要点は次のとおりである。

- Rust・Haskell・Koka・Gleam・Elm・Flix は、import なしで使える部分（prelude）を小さく保ち、そのほかは import させる。Rust と Flix は、よく使うものだけを入れる方針を文書に書いている。
- OCaml は標準ライブラリを `Stdlib` の下にまとめ直し、利用者が短い名前を使えるように大域の名前空間を空けた。`Stdlib.List` のように、根の名前から完全な名前で書ける。Elixir の `Elixir.List` も同じ働きをする。
- Roc と Gleam は、IO を prelude に入れない。
- Rust の prelude は、Rust で書いた標準ライブラリの一部である。prelude かどうかは、実装の言語ではなく、import なしで使えるかで決まる。

## 決定

1. 標準ライブラリは、処理系と一緒に配るモジュールの全体とし、名前空間 `Benitoite` の下に置く。prelude は、標準ライブラリのうち import なしで使える部分とする。関数を Rust で実装するか言語で書くかは、prelude かどうかと関係しない。
2. prelude は、基本型とその関数のモジュール（`Integer`・`String` など）、`List`・`Map`・`Set`・`Bytes`、`Option`・`Result`・`Pair`・`Triple`、`Reference`、`Lazy`、`Task`・`TaskGroup`、`Assert`、エフェクト `State`、およびモジュール `IO`（[ADR 0130](0130-builtin-effect-names-and-placement.md) のまとめたエフェクトを宣言する）からなる。prelude の名前 `X` は、import なしで `X` と書け、`Benitoite.X` とも書ける。
3. IO を行うモジュールは `Benitoite.IO` の下に置き（`Benitoite.IO.Console`・`Benitoite.IO.File`・`Benitoite.IO.Process`・`Benitoite.IO.Clock`・`Benitoite.IO.Random`・`Benitoite.IO.Network`）、import しなければ使えない。prelude でない標準ライブラリのモジュール（JSON などを加えるとき）も、import しなければ使えない。import なしに完全な名前で書けるのは prelude だけである。
4. 根のディレクトリの直下に `Benitoite` という名前のファイルやディレクトリを置き、それを取り込むことは誤りとする。
5. 利用者の宣言や取り込みの名前が prelude の名前と同じときは、利用者の名前が優先する。その名前を使った箇所の診断（型の誤りなど）には、同じ名前の prelude の名前を隠していることと、`Benitoite.X` で prelude の側を書けることを示す。
6. 処理系は、組み込みの型・モジュール・エフェクトを、綴りではなく、`Benitoite` の名前空間のどの名前かで照合する。

## 検討した代替案

- **根の名前を `Std` にする**: 短い。しかし、言語の名前（[ADR 0132](0132-language-name-benitoite.md)）を根にすると、どの処理系の標準ライブラリかが名前から分かり、利用者やパッケージのモジュールと取り違えにくい。
- **IO のモジュールを `Benitoite.Standard.Console` のように置く**: 標準ライブラリであることが名前から分かる。しかし、IO を行うモジュールを一か所にまとめると、スクリプトがどの種類の外部の操作に依存するかが import の並びから分かる。
- **IO のモジュールも prelude に入れる（Haskell・OCaml）**: 一行目から `Console.writeLine` と書ける。しかし、prelude が大きくなり、利用者が `File` や `Process` という名前のモジュールを作ると prelude の名前を隠すことになる。
- **標準ライブラリ全体を import なしで完全な名前で書けるようにする（Rust の `std::`、Elixir）**: import を書く手間が減る。しかし、スクリプトがどの IO のモジュールを使うかを、import の並びから読み取れなくなる。
- **利用者の名前が prelude の名前と同じときを誤りにする（これまでの規則）**: 取り違えは起きない。しかし、prelude に名前を加えるたびに、同じ名前を使っていた利用者のスクリプトが誤りになる。

## 帰結

- 用語を改める。「prelude のソース」は「標準ライブラリのソース」と呼び、「組み込みの表」は Rust で実装する組み込みの型・関数の表を指す（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)）。
- 最小実行版のスクリプトの `Console.writeLine` などは、初回リリース版では `import Benitoite.IO.Console` を加えないと誤りになる。診断は、足りない import を修正案として示す。
- パッケージの名前空間は [OPEN-049](../open-issues.md#open-049) で決める。どのライブラリを標準ライブラリに入れるかは、これまでどおり [OPEN-035](../open-issues.md#open-035) で決める。
