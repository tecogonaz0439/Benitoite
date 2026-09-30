# 0286. 吟味を終えていない標準ライブラリのモジュールを `Benitoite.Unofficial` の下の名前で取り込ませ、吟味の後に標準に移す

- 状態: 採択
- 日付: 2026-09-30
- 関連章: [標準ライブラリ](../03-interop/03-06-stdlib.md), [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md), [名前解決とモジュール読込](../02-impl/02-04-resolver.md), [ライブラリの構成](../03-interop/03-01-library-structure.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [テキストとデータの処理](../03-interop/03-08-text-and-data.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [Agent Skills 対応](../06-tooling/06-06-agent-skills.md), [配布形態](../05-platform/05-01-distribution.md)
- 関連する未決事項: [OPEN-066](../open-issues.md#open-066)

## 背景

組み込みの関数は型付きの形で書く（[ADR 0261](0261-typed-builtin-interface.md)）。設計者は、この形で書いた関数をまず非公式のライブラリとして扱い、実装を吟味したものから標準ライブラリに加える方向を示した（[OPEN-066](../open-issues.md#open-066)）。初回リリース版の標準ライブラリの範囲は [ADR 0137](0137-first-release-library-scope.md) で決め、U2 が作る最小限の IO の関数がどちらに属するかは、[ADR 0273](0273-u2-u3-boundary-for-runtime-builtins.md) の決定 3 が U3 の実装プランに委ねた。

実装プランの骨子（`doc/implement/README.md` の「U3・U4 で決めたこと」）では、次の三案を比べた。(a) 吟味の前のモジュールを別の名前空間に置き、吟味の後に最終の名前へ移す。(b) 設計書の一覧をそのまま標準とし、非公式のライブラリはリリースに含めない試作だけを指す。(c) 名前は最終のままとし、モジュールごとの状態をドキュメントコメントと Skill で示す。骨子は (c) を推したが、設計者は (a) を選んだ（2026-09-30）。

設計者は、非公式から始める範囲を「言語の中核を除くすべて」とし、U3 が作る関数（162）と U2 が作る IO の関数（`Console`・`File`・`Process`・`Clock`）を非公式とした。言語の中核として初めから標準とするのは、基本型の演算、`List`・`Option`・`Result`・`Pair`・`Triple` の基本の関数、`Task`・`TaskGroup`・`Lazy`・`Reference`、そして 01-spec が規範として定めるものである。ただし、この二つの指示は、U3 の関数のうち prelude のモジュールに加える 51 の関数（`Character`・`String`・`Map`・`Set`・`Bytes`・`NetworkError` の関数）で重なる。これらは U3 の関数であり、同時に言語の中核のモジュールの関数でもある。

## 決定

1. 標準ライブラリのモジュールは、「標準」か「非公式」のどちらかの状態を持つ。状態はモジュールを単位に決め、一つのモジュールの関数を二つの状態に分けない。
2. 初回リリース版の状態を次のとおりとする。

   | 状態 | モジュール |
   |---|---|
   | 標準 | prelude のすべてのモジュール（基本型のモジュール、`List`・`Map`・`Set`・`Bytes`・`ByteOrder`、`Option`・`Result`・`Pair`・`Triple`、`IOError`・`IOErrorKind`・`NetworkError`・`NetworkErrorKind`、`RoundingMode`、`Reference`、`Lazy`、`Task`・`TaskGroup`、`Assert`、`IO`）と `Benitoite.Trait` |
   | 非公式 | `Benitoite.IO.Console`・`Benitoite.IO.File`・`Benitoite.IO.Process`・`Benitoite.IO.Clock`・`Benitoite.IO.Random`、`Benitoite.Network.Http`、`Benitoite.Path`・`Benitoite.Json`・`Benitoite.Regex`・`Benitoite.Csv`・`Benitoite.Time`・`Benitoite.Encoding`・`Benitoite.Hash` |

   U2 が作る IO の関数（`Console`・`File`・`Process`・`Clock` の 16 の関数）も、属するモジュールとともに非公式から始める。prelude のモジュールに U3 が加える 51 の関数は、決定 1 により標準とする。
3. 非公式のモジュール `Benitoite.X.Y` は、`import Benitoite.Unofficial.X.Y` と書いて取り込む。取り込んだ後は、標準のモジュールと同じく名前の最後の要素（`as` を書けばその名前）で修飾して使う（`Console.writeLine`、`uses Console.Write`）。非公式のモジュールは prelude に入らない。
4. 非公式のモジュールを `import Benitoite.X.Y` と書くこと、標準のモジュールを `import Benitoite.Unofficial.X.Y` と書くことは、どちらも標準ライブラリにないモジュールの取り込みの誤りとする。診断は、その版で正しい取り込みの名前を修正案として示す。
5. モジュールの同一性、組み込みの型とエフェクトの照合（[ADR 0128](0128-prelude-and-benitoite-namespace.md) の決定 6）、標準ライブラリのソースの置き場所、設計書の本文と例は、標準に加えた後の名前（`Benitoite.X.Y`）で表す。`Benitoite.Unofficial.X.Y` は、非公式の間の取り込みの名前である。
6. 非公式のモジュールも、設計書（01-spec と 03-06〜03-09）が定める意味に従う。非公式という状態は、設計者の吟味の結果で名前・型・振る舞いを改めうることを示す。互換性の方針は [ADR 0236](0236-compatibility-during-0x.md) のまま変えない。パッチの版では、非公式のモジュールも変えない。
7. 設計者が吟味を終えたモジュールは、マイナーの版で標準に移す。取り込みの名前が変わるので、移すことは互換性を壊す変更であり、`CHANGELOG` に移行の手順（import の行の書き換え）とともに記す。吟味で見つかった名前・型・振る舞いの変更は、同じ版で行ってよい。
8. 同梱の Agent Skill の標準ライブラリのリファレンスは、モジュールごとに状態と取り込みの名前を示す。`SKILL.md` の主な言語の規則の要約には、非公式のモジュールを `Benitoite.Unofficial` の下の名前で取り込むことを含める。

## 検討した代替案

- **(b) 設計書の一覧をそのまま標準とする**: 名前は変わらず、移す手間もない。しかし、U3 だけで 162 の関数があり、すべてをリリースの前に吟味しなければ、吟味の前の関数を標準として約束することになる。
- **(c) 名前は最終のまま、状態で区別する**: 標準に移しても import の行を書き換えずに済む。しかし、状態はドキュメントコメントと Skill にしか現れず、スクリプトを読む利用者と書く LLM が、吟味の前の関数に頼っていることを読み落としやすい。(a) なら、吟味の前のモジュールに頼っていることが import の行から分かる。
- **関数を単位に状態を決め、U3 の 162 の関数をすべて非公式にする**: 設計者の指示の字義に沿う。しかし、`Map.insert` などを非公式のモジュール `Benitoite.Unofficial.Map` に置くと、`import Benitoite.Unofficial.Map` が付ける名前 `Map` が prelude の `Map` を隠し（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「標準ライブラリの名前空間と prelude（初回リリース版）」）、`Map.empty` も型 `Map[K, V]` も書けなくなる。`as` で別の名前を付けさせれば避けられるが、同じ型の関数を二つの名前で呼び分けることになり、LLM が書き誤りやすい。`Map`・`Set` は永続コレクション、`Character`・`String` は基本型であり、ADR 0137 の決定 3 が言語の中核に数えたものである。
- **非公式のモジュールの同一性を `Benitoite.Unofficial.X.Y` とする**: 取り込みの名前と同一性が一致する。しかし、移すたびに、組み込みの型とエフェクトの表、組み込みの関数の表の名前、01-spec の例と本文を書き換えることになる。決定 5 の形なら、移すときに変わるのは状態の表と import の行だけである。
- **名前空間を `Benitoite.Experimental` とする**: 試作の段階であることが伝わる。しかし、設計書の一覧にあり、意味も設計書で定めたモジュールであって、試作ではない。設計者が示した「非公式のライブラリ」の語に合わせた。
- **IO のモジュールのエフェクトだけを標準のモジュールに残し、関数を非公式のモジュールに置く**: 01-07 が規範として定めるエフェクトを標準にできる。しかし、`Console.writeLine` を呼ぶスクリプトが、エフェクトのための `Benitoite.IO.Console` と関数のための `Benitoite.Unofficial.IO.Console` の二つを、最後の要素の重なりを避けて取り込むことになる。

## 帰結

- [OPEN-066](../open-issues.md#open-066) を決着とする。
- [ADR 0137](0137-first-release-library-scope.md) の決定 2 のモジュールは、どれも初回リリース版に入る。そのうち IO・ネットワーク・テキストとデータのモジュールは、非公式のモジュールとして入る。
- [ADR 0273](0273-u2-u3-boundary-for-runtime-builtins.md) の決定 3 が委ねた、U2 が作る関数の属し方は、決定 2 で決まった。
- [ADR 0261](0261-typed-builtin-interface.md) の決定 8 の【未決】は、本 ADR で決まった。
- [ADR 0128](0128-prelude-and-benitoite-namespace.md) の名前空間の根 `Benitoite` と prelude の規則は変えない。非公式のモジュールの取り込みの名前も `Benitoite` から始まるので、利用者の名前と取り違えない。
- prelude の `Task` の関数の型は、非公式のモジュール `Benitoite.IO.Clock` のエフェクト `Clock.Time` を含む（[並行処理](../01-spec/01-11-concurrency.md)）。標準のモジュールが非公式のモジュールに依存するのは、この一か所である。`Clock` を標準に移すときは、`Task` のソースの import の行も改める。
- 01-spec の例は `import Benitoite.IO.Console` の形で書いたままにする。処理系で例を検査するとき（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)の「言語仕様の例の検査」）は、非公式のモジュールの import を取り込みの名前に置き換えてから検査する。
- 標準に移すたびに、スクリプト・ゴールデンテスト・Skill のイディオム集の import の行を書き換える。処理系は決定 4 の修正案を示すので、古い名前を書いたスクリプトは実行の前に誤りとして見つかり、修正案を当てて直せる。
- 正式リリース版（`1.0.0`）で非公式のモジュールを残してよいかは、[OPEN-040](../open-issues.md#open-040) で決める。
