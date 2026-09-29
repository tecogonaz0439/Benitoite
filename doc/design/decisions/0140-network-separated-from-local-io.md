# 0140. ネットワークの操作をローカルの IO と分け、`Benitoite.Network` の下に置き、`IO.All` に含めない

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [エフェクト](../01-spec/01-07-effects.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [コア計算と脱糖](../01-spec/01-12-core-calculus.md), [セキュリティモデル](../07-quality/07-01-security-model.md), [用語集](../00-overview/00-04-glossary.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045)

## 背景

IO を行うモジュールは `Benitoite.IO` の下に置き（[ADR 0128](0128-prelude-and-benitoite-namespace.md) の決定 3）、その中に `Benitoite.IO.Network` を挙げていた。prelude のモジュール `IO` は、`State` と `Benitoite.IO` の下のすべての組み込みのエフェクトをまとめたエフェクト `IO.All` を宣言する（[ADR 0130](0130-builtin-effect-names-and-placement.md) の決定 4）。したがって、これまでの規則では、ネットワークのエフェクトも `IO.All` に含まれる。

初回リリース版の標準ライブラリに、HTTP のサーバとクライアントを入れる（[ADR 0141](0141-http-scope-in-stdlib.md)）。HTTP の操作は、スクリプトを動かす機械の外の資源に触れ、その機械の中の操作（コンソール、ファイル、プロセス、環境変数、時計、乱数）とは影響の及ぶ範囲が異なる。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「ネットワークの操作と IO の区分」に記録した。要点は次のとおりである。

- Haskell・Idris 2・Lean 4・Unison・Effekt・PureScript・ZIO は、ネットワークの操作をファイルと同じ IO の型で表す。Flix は `IO` の説明に「accessing the network」を含める。Koka は `net` と `fsys` を別のエフェクトにしたうえで、`io` をそれらをまとめた名前とする。OCaml Eio は、ネットワークとファイルシステムを別の権限の値（`env#net` と `env#fs`）として渡す。
- 名前空間は、IO の下に置くもの（Effekt の `io/network`、Scala fs2 の `fs2.io.net`）と、別の最上位に置くもの（Haskell の `Network.*`、Idris 2 の `Network.Socket`、Flix の `Net.Http`）に分かれる。

## 決定

1. ネットワークの操作を行うモジュールは、`Benitoite.IO` ではなく `Benitoite.Network` の下に置く。初回リリース版では `Benitoite.Network.Http` だけを置き、import しなければ使えない。ADR 0128 の決定 3 の `Benitoite.IO.Network` を、これに改める。
2. `Benitoite.Network.Http` は、待ち受けのエフェクト `Listen` と接続のエフェクト `Connect` を宣言する。取り込んだ側からは `Http.Listen`・`Http.Connect` と書く。
3. `IO.All` は、`State` と `Benitoite.IO` の下のモジュールのエフェクトだけをまとめたものとし、ネットワークのエフェクトを含めない。ネットワークのエフェクトをまとめたエフェクトは、初回リリース版では設けない。
4. 本文で「IO」と書くときは、`IO.All` に含まれるエフェクトの操作（スクリプトを動かす機械の中の、プログラムの外部の状態を読むか変える操作）を指す。ネットワークの操作は、これと区別して「ネットワークの操作」と呼ぶ。二つを合わせて「外部に作用する操作」と呼ぶ。
5. ネットワークのエフェクトも組み込みのエフェクトである。ネットワークの操作も、IO と同じく IO 実行器を通し、ハンドラで処理でき、実行時の権限制御の対象になる。`main` のエフェクトには、`IO.All` に含まれるエフェクトに加えて、`Http.Listen`・`Http.Connect` を含められる（ADR 0130 の決定 5 を改める）。

## 検討した代替案

- **`Benitoite.IO.Network.Http` に置く**: ADR 0128 の決定 3 をそのまま保て、Effekt や fs2 と同じ形になる。しかし、ローカルの機械の中の操作と、機械の外に作用する操作が、名前空間の上で区別できない。import の行から、スクリプトがネットワークに触れるかを見分けやすくするため、分ける。
- **`Benitoite.IO.Http` に置く**: 最も短く書ける。しかし、上と同じく、ネットワークの操作を IO の中に置く。後の版で TCP を加えるときの置き場所も定まらない。
- **ネットワークのエフェクトを `IO.All` に含める**: `uses IO.All` で、外部に作用するすべての操作を書ける。しかし、名前空間を分けても、`uses IO.All` と書いた関数がネットワークに触れうることになり、エフェクトの上でローカルとネットワークを分けたことにならない。
- **`Network.All` を設ける**: 後の版で TCP などを加えたときに一度に書ける。しかし、初回リリース版のネットワークのエフェクトは二つだけであり、並べて書いても長くならない。まとめる名前は、モジュールが増えたときに改めて検討する。

## 帰結

- import の行（`import Benitoite.Network.Http`）と関数の型（`uses Http.Connect`）から、スクリプトがネットワークに触れるかが分かる。`uses IO.All` と書いた関数は、ネットワークに触れない。
- IO とネットワークの両方を使う関数は、`uses IO.All, Http.Connect` のように書く。
- `Benitoite` の直下の名前空間は、prelude と純粋なモジュール（`Benitoite.Json` など）のほかに、`Benitoite.IO` と `Benitoite.Network` を持つ。外部に作用するモジュールは、この二つの下にだけ置く。
- 「IO 実行器」は、処理系の部品の名前として残し、ネットワークの操作も扱う。
- ADR 0128 の決定 3、ADR 0130 の決定 1・4・5、ADR 0137 の決定 2 の表の `Network` の行を、この ADR で読み替える。
