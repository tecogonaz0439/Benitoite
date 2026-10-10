# 他の言語の調査記録

- 状態: 草稿
- 関連ADR: [0112](../decisions/0112-pascal-style-operators.md), [0113](../decisions/0113-div-and-mod-operators.md), [0114](../decisions/0114-decimal-type.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0121](../decisions/0121-pattern-extensions.md), [0122](../decisions/0122-multiline-and-raw-strings.md), [0123](../decisions/0123-top-level-constants.md), [0124](../decisions/0124-type-aliases.md), [0125](../decisions/0125-doc-comments.md), [0126](../decisions/0126-import-by-module-name.md), [0127](../decisions/0127-directory-run-and-root.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0133](../decisions/0133-builtin-equality-and-key-constraints.md), [0134](../decisions/0134-standard-type-classes.md), [0135](../decisions/0135-shebang-line-and-implicit-run.md), [0136](../decisions/0136-map-and-set-in-constants.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0141](../decisions/0141-http-scope-in-stdlib.md), [0142](../decisions/0142-http-api-shape.md), [0143](../decisions/0143-http-and-tls-crates.md), [0144](../decisions/0144-ioerrorkind-constructors.md), [0145](../decisions/0145-network-error.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md)
- 未決事項: [OPEN-014](../open-issues.md#open-014), [OPEN-051](../open-issues.md#open-051), [OPEN-052](../open-issues.md#open-052), [OPEN-056](../open-issues.md#open-056)
- 移行元: なし

## 目的と範囲

構文と意味論を決めるために行った、他の言語の調査の結果を記録する。本章は事実だけを記録し、Benitoite としての決定は各節に挙げた ADR に書く。

各節の事実は、節に日付を記したものを除き、2026-09-28 に、各言語の仕様書・公式の文書・公式のソースなどの一次資料で確かめたものである。一次資料で確かめられなかった事項には【要検証】を付け、各節の末尾にまとめる。

## 前提

調査の対象は、決定の時点で参考になると考えた言語に限る。各言語の版は、調査した日の最新の文書に従う。言語の仕様や文書は改訂されるので、本章の記述は調査した日の時点のものである。

## 仕様

### Pascal 系の言語のパイプ・ドット記法と演算子

[ADR 0112](../decisions/0112-pascal-style-operators.md) と [ADR 0113](../decisions/0113-div-and-mod-operators.md) の判断に使った。

| 言語 | `\|>` に当たる演算子 | 利用者による新しい演算子の記号 | 後置の呼び出し |
|---|---|---|---|
| Ada 2022 | なし | 定義できない（RM 6.1 10/5: 演算子の記号は 4.5 節の演算子に当たるものに限る） | prefixed view（`X.Op(Y)`）。tagged 型か class-wide 型の値に限る（RM 4.1.3 9.2/3）。GNAT は、tagged でない型に広げる拡張を持つ（Curated extension。`-gnatX` で有効にする） |
| Free Pascal | なし | 定義できない（多重定義できる記号を構文図で列挙する） | helper（class helper・record helper・type helper）でドットで呼べる |
| Oberon-07 | なし | 定義できない（演算子は文法で固定） | なし |
| Nim | なし（組み込みには） | 定義できる（`= + - * / < > @ $ ~ & % \| ! ? ^ . : \` の組み合わせ） | method call syntax（`e.m(args)` は `m(e, args)`） |

比較・論理・算術の演算子は次のとおりである。

| 演算 | ISO 7185 Pascal | Free Pascal | Ada 2022 | Oberon-07 |
|---|---|---|---|---|
| 等しくない | `<>` | `<>` | `/=` | `#` |
| 論理積・論理和・否定 | `and`・`or`・`not` | `and`・`or`・`not` | `and`・`or`・`not`（短絡は `and then`・`or else`） | `&`・`OR`・`~` |
| 実数の除算 | `/` | `/`（常に実数を返す） | `/` | `/` |
| 整数の除算 | `div` | `div` | `/` | `DIV` |
| 剰余 | `mod` | `mod` | `rem`（符号は被除数と同じ）、`mod`（符号は除数と同じ） | `MOD` |

- 優先順位: ISO 7185 Pascal・Free Pascal・Oberon-07 は、論理積を乗算と、論理和を加算と同じ強さに置く。Ada は論理演算子を最も弱く置く。
- 短絡評価: Oberon-07 は `p & q` を「if p then q, else FALSE」と定める。Free Pascal は既定で短絡評価する。Ada は、短絡を `and then`・`or else` に分ける。ISO 7185 は、短絡するかを定めない。
- Ada の整数の除算は、`(-A)/B = -(A/B) = A/(-B)` を満たす（RM 4.5.5）。
- Free Pascal の `div` と `mod` は、整数のオペランドだけを受け付ける。

【要検証】

- Delphi の演算子の多重定義の範囲と helper。公式の docwiki を読めなかった。
- Modula-2 の演算子。

出典

- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-4-1-3.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-6-1.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-4-5.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-4-5-1.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-4-5-5.html
- https://docs.adacore.com/gnat_rm-docs/html/gnat_rm/gnat_rm/gnat_language_extensions.html
- https://www.freepascal.org/docs-html/ref/refse103.html
- https://www.freepascal.org/docs-html/ref/refch12.html
- https://www.freepascal.org/docs-html/ref/refsu44.html
- https://www.freepascal.org/docs-html/ref/refsu46.html
- https://wiki.freepascal.org/Helper_types
- https://www.standardpascal.org/iso7185.html
- https://people.inf.ethz.ch/wirth/Oberon/Oberon07.Report.pdf
- https://nim-lang.org/docs/manual.html

### 関数型言語の実数の型と、10 進の小数の型

[ADR 0114](../decisions/0114-decimal-type.md) の判断に使った。

| 言語 | 2 進の浮動小数 | それ以外の実数の型 | 備考 |
|---|---|---|---|
| OCaml | `float`（倍精度、64 bit）だけ | 標準ライブラリにない | 標準ライブラリに `Float32` はない |
| Haskell 2010 | `Float`（単精度以上が望ましい）、`Double`（倍精度を覆う） | `Rational`（`Integer` の比） | 精度は処理系が定める |
| F# | `float`＝`double`（64 bit）、`float32`＝`single`（32 bit） | `decimal`（有効数字 28 桁以上。リテラル `1.0m`） | .NET の型を使う |
| Lean 4 | `Float`（binary64）、`Float32`（binary32） | — | |
| Roc | `F64`、`F32` | `Dec` | |
| Gleam | `Float`（Erlang と JavaScript のどちらでも 64 bit） | 標準ライブラリにない | 0 による除算は 0 を返す |
| Erlang | 64 bit の浮動小数 | — | Inf と NaN を持たず、それらになる演算は `badarith` の例外になる |

10 進の小数の実装は次のとおりである。

- .NET の `Decimal` は、96 bit の整数と、符号と小数の桁数（scaling factor、0〜28）を持つ 128 bit の値である。値の範囲は ±79,228,162,514,264,337,593,543,950,335 である。小数の桁数は末尾の 0 を保ち、末尾の 0 は値に影響しない。
- Rust のクレート `rust_decimal`（MIT License）は、`m / 10^e`（−2^96 < m < 2^96、0 ≤ e ≤ 28）の形の 128 bit の値を持つ。桁あふれを検出する演算を持つ。

【要検証】

- Roc の `Dec` の精度と、小数のリテラルの既定の型。
- `rust_decimal` の除算の既定の丸め方。

出典

- https://ocaml.org/manual/latest/api/Stdlib.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch6.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/basic-types
- https://lean-lang.org/doc/reference/latest/Basic-Types/Floating-Point-Numbers/
- https://www.roc-lang.org/builtins/Num
- https://gleam-stdlib.hexdocs.pm/gleam/float.html
- https://www.erlang.org/doc/system/data_types.html
- https://learn.microsoft.com/en-us/dotnet/api/system.decimal?view=net-8.0
- https://docs.rs/rust_decimal/latest/rust_decimal/

### 並行処理のモデル

[ADR 0115](../decisions/0115-structured-io-concurrency.md) の判断に使った。

| 言語 | モデル | 構文かライブラリか | 構造化された並行処理 | 子の失敗と取り消し | 複数のコア |
|---|---|---|---|---|---|
| Go | goroutine とチャネル | 構文（`go`・`select`・`chan`・`<-`） | なし。`go` で起動した関数の戻り値は捨てられる | 回復しない panic はプログラム全体を止める | 使う |
| Erlang | プロセスとメッセージ | `!` と `receive … after … end` は構文。`spawn`・`link`・`monitor` は組み込みの関数 | なし（リンク・モニタ・OTP のスーパーバイザ） | リンクで終了の信号を伝える。`receive … after` で時間切れ | 使う |
| Elixir | BEAM のプロセス | `receive` は特殊形式。`Task.async`・`await` は関数 | 一部（`Task.async` は呼び出し元とリンクする） | 呼び出し元とタスクの一方が落ちると他方も落ちる。`await` の既定の時間切れは 5000 ms | 使う |
| Gleam | BEAM のプロセス | ライブラリだけ | なし（スーパーバイザ） | `spawn` は既定でリンクする | 使う |
| Haskell（GHC） | 軽量スレッド、`MVar`、STM | ライブラリだけ（`atomically` も関数） | base にはない。`async` パッケージの `withAsync`・`concurrently`・`race` | `forkIO` のスレッドの例外は起動した側に伝わらない。`concurrently` は他方を取り消して再送出する | `-threaded` と `+RTS -N` で使う |
| OCaml 5 | `Domain`、エフェクトハンドラ、Eio のファイバ | ハンドラの構文は 5.3 から。Eio はライブラリ | Eio の `Switch.run` が持つファイバを待つ | 失敗したファイバは `Switch` を取り消す | `Domain` は OS のスレッドに 1 対 1 で対応する |
| Kotlin | コルーチン | キーワードは `suspend` だけ。`launch`・`async`・`coroutineScope` はライブラリ | `coroutineScope` | 子の例外は親と兄弟を取り消す。取り消しは協調的 | — |
| Swift | async/await、タスク、アクター | 構文（`async`・`await`・`async let`・`actor`）。TaskGroup はライブラリ | `async let` と TaskGroup | 親を取り消すと子も取り消す | — |
| Java | 仮想スレッド（JEP 444、JDK 21 で正式） | API だけ | `StructuredTaskScope`（JDK 21〜27 でプレビュー。JEP 543 が JDK 28 での正式化を提案） | 一方が失敗すると他方を中断する | 使う |
| Python | asyncio | 構文（`async def`・`await`）。`TaskGroup`（3.11）はライブラリ | `asyncio.TaskGroup` | 最初の失敗で残りを取り消し、`ExceptionGroup` にまとめる | asyncio は使わない |
| Trio | nursery | Python の構文とライブラリ | nursery | 子の例外で nursery を取り消す | 使わない |
| Koka | 代数的エフェクト | エフェクトの構文。async は、エフェクトで書いたライブラリ | — | — | — |
| F# | `async { }`、`task { }` | 計算式の構文（`let!`・`do!` など） | スコープの構文はない | `async` は取り消しの印を暗黙に渡す | 使う |
| Clojure | アトム、STM、core.async | マクロ（`dosync`・`go`・`alt!`・`thread`） | なし | STM は衝突すると再試行する | 使う |
| Rust | OS のスレッド、async/await | 構文（`async`・`.await`） | `std::thread::scope`（1.63 から） | 自動で合流したスレッドが panic すると `scope` も panic する | 使う |

- 構造化された並行処理のスコープは、Swift の `async let` を除き、どの言語でもライブラリの関数か型である。構文で並行処理を書く Go と Erlang は、構造化されていない。
- 「structured concurrency」の語は、Nathaniel J. Smith の文章（2018-04-25）が広めたが、同氏は Martin Sústrik の文章と libdill を先行として挙げている。
- Rust の `Rc` は、アトミックでない参照カウントなので、スレッドの間で送れない（`Send` でない）。複数のスレッドで使うには `Arc` を使う。
- OCaml のエフェクトハンドラは、静的なエフェクトの安全性を持たない。処理しないエフェクトは実行時に `Effect.Unhandled` になる。

【要検証】

- Swift の `withThrowingTaskGroup` で、子の誤りが自動で伝わるか。
- Kotlin の `Dispatchers.Default` の並列度。
- F# の `MailboxProcessor` と `Async.Parallel` の誤りの扱い。
- Clojure の core.async の `<!`・`>!`・`alts!`・`chan` が関数か。
- Koka の `std/async` の構成、取り消しと並列の扱い。
- Unison の並行処理の基本の操作。

出典

- https://go.dev/ref/spec
- https://pkg.go.dev/runtime
- https://www.erlang.org/doc/system/ref_man_processes.html
- https://www.erlang.org/doc/apps/erts/erl_cmd.html
- https://elixir.hexdocs.pm/Task.html
- https://elixir.hexdocs.pm/Kernel.SpecialForms.html
- https://gleam-otp.hexdocs.pm/
- https://gleam-erlang.hexdocs.pm/gleam/erlang/process.html
- https://hackage.haskell.org/package/stm/docs/Control-Monad-STM.html
- https://hackage-content.haskell.org/package/async-2.2.6/docs/Control-Concurrent-Async.html
- https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Control-Concurrent.html
- https://ocaml.org/manual/5.3/parallelism.html
- https://ocaml.org/api/Domain.html
- https://ocaml.org/p/eio/latest/doc/Eio/Switch/index.html
- https://ocaml.org/p/eio/latest/doc/Eio/Fiber/index.html
- https://github.com/ocaml-multicore/eio
- https://kotlinlang.org/docs/coroutines-basics.html
- https://kotlinlang.org/docs/exception-handling.html
- https://kotlinlang.org/docs/cancellation-and-timeouts.html
- https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Concurrency.md
- https://openjdk.org/jeps/444
- https://openjdk.org/jeps/505
- https://openjdk.org/jeps/543
- https://docs.python.org/3/library/asyncio-task.html
- https://peps.python.org/pep-0703/
- https://peps.python.org/pep-0779/
- https://trio.readthedocs.io/en/stable/reference-core.html
- https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/task-expressions
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/async-expressions
- https://clojure.org/reference/refs
- https://clojure.github.io/core.async/clojure.core.async.html
- https://doc.rust-lang.org/reference/expressions/await-expr.html
- https://doc.rust-lang.org/std/thread/fn.scope.html
- https://doc.rust-lang.org/std/rc/index.html
- https://ocaml.org/manual/5.3/effects.html

### エフェクトハンドラと、エフェクトの粒度と、権限の仕組み

[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0117](../decisions/0117-capabilities-as-effects.md)、[ADR 0118](../decisions/0118-effect-handlers.md) の判断に使った。

| 言語 | エフェクトの宣言 | ハンドラ | 型のエフェクト | IO の粒度 | 継続の再開 |
|---|---|---|---|---|---|
| Koka | `effect fun emit(msg : string) : ()` など。操作は `fun`・`ctl`・`val` | `with handler { … }`。`ctl` の中で `resume` | 推論する。行（`<console,exn> int`） | `console`・`fsys`・`net`・`ndet` などに分け、`io` はそれらをまとめた別名 | `ctl` は複数回。`fun` はちょうど一回 |
| Effekt | `interface Exc { def throw(msg: String): Nothing }`、`effect tell(): Int` | `try { … } with Eff { … resume(v) }` | 集合（`Double / { exc }`） | 組み込みの IO はエフェクトではなく、capture set で追跡する | 0 回・1 回・複数回 |
| OCaml 5 | `type _ Effect.t += …`、`perform` | `match … with effect E, k -> continue k v`（5.3 から） | なし（処理しないと実行時に `Effect.Unhandled`） | — | 一回だけ（二度目は `Continuation_already_resumed`） |
| Unison | `ability KVStore a b where …` | `handle e with h`（`resume` は慣習の名前） | `{IO, Exception}` | 粗い `IO` と、ライブラリの ability | — |
| Eff | `effect Select : bool`、`perform` | `with h handle e`（継続は `k` のように名付ける） | — | — | 複数回 |
| Flix | `eff Ask { def ask(): String }` | `run { … } with handler Ask { … }`（`resume` は引数の名前） | 集合（`\ {FsRead, FsWrite, IO}`） | `FileRead`・`FileWrite`・`Http`・`Console`・`Env`・`Exit`・`Process`・`Clock`・`Random` などに分け、それぞれに既定のハンドラ。`IO` と `NonDet` は処理できない | 複数回 |
| Ante | `effect Database with query : …`、`can Database` | `handle f () \| query _msg -> resume …`、`expr with h` | `can E` | — | — |
| Roc | 利用者のハンドラはない。エフェクトはプラットフォームが与える | — | 関数の型の `=>`（エフェクトのある関数） | プラットフォームが決める | — |

ハンドラの構文のキーワードは次のとおりである。

| 言語 | `with` | `handle` | `resume` |
|---|---|---|---|
| Koka | 使う | 現在の文書にない | 使う（`ctl` の中の関数） |
| Effekt | 使う | 使わない | 使う |
| OCaml 5 | 使う | 使わない | 使わない（`continue`・`discontinue`） |
| Unison | 使う | 使う | 慣習の名前だけ |
| Eff | 使う | 使う | 使わない |
| Flix | 使う | 使わない | 引数の名前だけ |
| Ante | 使う | 使う | 使う |

- Flix の文書は、すべてを `IO` にしたコードのテストの難しさを述べる。`@Test` の関数は、既定のハンドラを持つエフェクトを使える。ファイルシステムのハンドラには、メモリの上のものがある。
- Haskell の `effectful` は、ハンドラによって同じエフェクトを実行時に異なる形で解釈できる。`polysemy` は、`Teletype` を実際の入出力と、純粋な入出力の並びの両方で解釈する例を示す。
- Scala 3 の capture checking は実験的な機能であり、`T^{fs}` の形で捕捉する能力を型に書く。
- Brachthäuser・Schuster・Ostermann の "Effects as Capabilities"（OOPSLA 2020）は、エフェクトの型を計算が要するケーパビリティとして読み、ハンドラがケーパビリティを与えるとする。
- Ante の文書は、エフェクトを依存性の注入に使える例として、データベースの差し替えのハンドラを示す。

権限の仕組みは次のとおりである。

| 仕組み | 形 | 対象の指定 | 検査の時期 |
|---|---|---|---|
| Deno | `--allow-read`・`--allow-write`・`--allow-net`・`--allow-env`・`--allow-run`・`--allow-ffi`・`--allow-import`、`--deny-*` が `--allow-*` に優先 | `--allow-net=example.com`・`--allow-read=./data` など | 実行時。端末では実行時に尋ねる。拒否は `Deno.errors.NotCapable` |
| Node.js | `--permission` と `--allow-fs-read`・`--allow-fs-write`・`--allow-net`・`--allow-child-process` など（v23.5.0・v22.13.0 で安定） | パス | 実行時。拒否は `ERR_ACCESS_DENIED`。文書は悪意あるコードを防がないと明記する |
| WASI | 偽造できないハンドルなどのケーパビリティ | ハンドル | ambient authority を持たない |
| Roc のプラットフォーム | プラットフォームが IO の基本の操作をすべて持つ | プラットフォームが決める | プラットフォームが決める |

- Deno の文書は、`--allow-run` と `--allow-ffi` がサンドボックスの外に出られること、`--allow-write` と `--allow-run` の組み合わせを `--allow-all` と同じに扱うべきことを述べる。

【要検証】

- Koka の現在の文書に `handle` のキーワードがないこと。Koka・Effekt・Unison・Eff・Flix・Ante のうち、表で「—」とした欄。
- Unison の継続の再開の回数。
- Roc のテストでエフェクトを差し替える方法。
- Deno の `--allow-sys`。

出典

- https://koka-lang.github.io/koka/doc/book.html
- https://github.com/koka-lang/koka/blob/master/lib/std/core.kk
- https://effekt-lang.org/tour/effects
- https://effekt-lang.org/tour/captures
- https://effekt-lang.org/docs/concepts/effect-safety
- https://effekt-lang.org/docs/concepts/effect-handlers
- https://ocaml.org/manual/5.3/effects.html
- https://www.unison-lang.org/docs/fundamentals/abilities/writing-abilities/
- https://www.unison-lang.org/docs/fundamentals/abilities/faqs/
- https://www.unison-lang.org/docs/language-reference/abilities-and-ability-handlers/
- https://github.com/matijapretnar/eff/blob/master/examples/amb.eff
- https://doc.flix.dev/print.html
- https://antelang.org/blog/why_effects/
- https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
- https://hackage.haskell.org/package/effectful-core/docs/Effectful-Dispatch-Dynamic.html
- https://hackage.haskell.org/package/polysemy
- https://docs.scala-lang.org/scala3/reference/experimental/cc.html
- https://doi.org/10.1145/3428194
- https://docs.deno.com/runtime/fundamentals/security/
- https://nodejs.org/api/permissions.html
- https://github.com/WebAssembly/WASI/blob/main/docs/DesignPrinciples.md
- https://www.roc-lang.org/platforms

### テストの書き方

[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md) と [ADR 0120](../decisions/0120-test-functions-and-assert-effect.md) の判断に使った。

| 言語・道具 | 宣言 | 同じファイル | 期待の確認 | 失敗でテストを打ち切るか | 失敗の表示 | 名前 |
|---|---|---|---|---|---|---|
| Zig | キーワードのブロック `test "name" { }` | 書ける（`zig test` のときだけ含める） | `try std.testing.expect(b)`、`expectEqual` など | 打ち切る。実行器はほかのテストを続ける | `expectEqual` は期待と実際の値 | 文字列か識別子 |
| Rust | 属性 `#[test]` | 書ける（`use super::*` で非公開の項目にも届く） | マクロ `assert!`・`assert_eq!` | 打ち切る（panic） | `assert_eq!` は両辺の値 | 関数の名前 |
| Go | 命名規則 `func TestXxx(t *testing.T)`（`*_test.go`） | 別のファイル | 手で比べ、`t.Error`・`t.Fatal` を呼ぶ | `Error` は続ける、`Fatal` は打ち切る | 書いた文 | 関数の名前（サブテストは文字列） |
| D | キーワードのブロック `unittest { }` | 書ける | `assert` の式 | 処理系が定める | — | 名前なし |
| Roc | キーワード `expect`（トップレベル） | 書ける | 同じ `expect` | そのテストが失敗する | — | なし |
| Flix | 注釈 `@Test` | — | `Assert` エフェクトの関数（`assertEq` など） | — | 成否と時間 | 関数の名前 |
| Elixir ExUnit | マクロ `test "name" do … end` | 別のファイル（`test/`） | マクロ `assert` | 打ち切る | 演算子、コード、両辺 | 文字列 |
| Gleam（gleeunit） | 命名規則（`test/` の `_test` で終わる公開の関数） | 別のディレクトリ | キーワード `assert`（v1.11 から） | 打ち切る | アサーションのコード、`==` の両辺、呼び出しの引数の値 | 関数の名前 |
| pytest | 命名規則（`test_` で始まる関数など） | どちらの配置も文書にある | `assert` 文（pytest が書き換える） | そのテストだけ打ち切る | 部分式の値、型ごとの差分 | 関数の名前 |
| Deno | ライブラリの呼び出し `Deno.test("name", fn)` | ファイル名の規則で集める | `@std/assert` の関数 | 打ち切る | — | 文字列 |
| Nim | テンプレート `test "name":` | 書ける | `check`・`require` | `check` は続ける | — | 文字列 |
| OCaml（ppx_inline_test） | 構文の拡張 `let%test "name" = …` | 書ける（通常のビルドでは外す） | 真偽値か例外 | 偽か例外で失敗 | — | 文字列（省略可） |
| OCaml（Alcotest） | ライブラリの `test_case` | 別の実行ファイル | `Alcotest.(check int) "msg" expected actual` | 打ち切る | 期待と実際の値 | 文字列 |
| Haskell（Hspec） | ライブラリの DSL（`describe`・`it`） | 別のファイル | `shouldBe` など | 打ち切る | 期待と実際の値 | 文字列 |
| Free Pascal（FPCUnit） | `TTestCase` の published の手続き | 別のファイル | `AssertEquals`・`CheckEquals` | 打ち切る（例外） | `Check*` は期待と実際の値 | 手続きの名前 |

- 表形式のテスト: Go は `t.Run` のサブテストで書く。Zig・Rust・Roc・D は、テストの中でループを書く。
- プロパティベーステスト: Go は組み込みの fuzzing（`FuzzXxx`）を持つ。Hspec は QuickCheck と連携する。
- テストの切り離し: Rust はテストごとのスレッド、ExUnit はテストごとのプロセスで動かし、一つの panic で全体を止めない。Zig の既定の実行器は、失敗したテストの後も続ける。Go は、一つのテストの panic でテストのプログラム全体が止まる（golang/go#47525）。
- Roc のトップレベルの `expect` は `roc test` で動かす。ブロックの中の `expect` は、`--opt=speed` のビルドでは取り除かれる。
- Flix は、期待の確認をエフェクトにし、テストの実行器をそのハンドラとする。

【要検証】

- `roc test` が失敗したときに示す内容。
- Flix の失敗の表示の内容と、確認の失敗でテストを打ち切るか。
- D の既定の実行器が、失敗の後も続けるか。D の `unittest` から非公開の項目に届くか。
- Zig で panic が実行全体を止めるか。
- Deno の `assertEquals` が差分を示すか。
- ppx_inline_test の失敗の表示。
- Nim の `check` の出力の形と、`require` がプログラムを止めるのかテストだけを止めるのか。

出典

- https://ziglang.org/documentation/master/
- https://codeberg.org/ziglang/zig/raw/branch/master/lib/std/testing.zig
- https://doc.rust-lang.org/book/ch11-01-writing-tests.html
- https://doc.rust-lang.org/book/ch11-03-test-organization.html
- https://pkg.go.dev/testing
- https://pkg.go.dev/cmd/go#hdr-Test_packages
- https://github.com/golang/go/issues/47525
- https://dlang.org/spec/unittest.html
- https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
- https://doc.flix.dev/test-framework.html
- https://api.flix.dev/Assert.html
- https://ex-unit.hexdocs.pm/ExUnit.html
- https://ex-unit.hexdocs.pm/ExUnit.Case.html
- https://ex-unit.hexdocs.pm/ExUnit.Assertions.html
- https://gleeunit.hexdocs.pm/
- https://gleam.run/news/gleam-javascript-gets-30-percent-faster/
- https://docs.pytest.org/en/stable/how-to/assert.html
- https://docs.pytest.org/en/stable/explanation/goodpractices.html
- https://docs.deno.com/runtime/fundamentals/testing/
- https://jsr.io/@std/assert/doc/~/assertEquals
- https://nim-lang.org/docs/unittest.html
- https://ocaml.org/p/ppx_inline_test/latest
- https://github.com/mirage/alcotest
- https://hspec.github.io/
- https://wiki.freepascal.org/fpcunit

### 関数型言語の属性の構文

[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md) の判断に使った。

| 言語 | 属性の構文 | 形 | 主な用途 | キーワードで表すもの |
|---|---|---|---|---|
| Haskell（GHC） | あり（プラグマ） | `{-# INLINE f #-}`、`{-# DEPRECATED f "…" #-}` | インライン化、非推奨、言語拡張など | 導出は `deriving` 節。Haskell 2010 は、知らないプラグマを処理系が無視してよいとする |
| OCaml | あり | `[@attr]`・`[@@attr]`・`[@@@attr]`、拡張ノード `[%ext]` | 警告、非推奨、インライン化、末尾呼び出し、C との連携 | `[@@deriving]` は処理系の組み込みではなく ppx が実装する |
| F# | あり（.NET の属性） | `[<Name(args)>]` | 非推奨（`Obsolete`）、外部の関数（`DllImport`）など | テストの印はライブラリの属性 |
| Scala | あり | `@name(args)` | `@deprecated`、`@tailrec`、`@inline`、`@main` | Scala 3 の導出は `derives` |
| Elixir | あり（モジュール属性） | `@name value` | `@moduledoc`・`@doc`・`@spec`・`@behaviour`、定数 | — |
| Erlang | あり（モジュール属性） | `-Tag(Value).` | `-module`・`-export`・`-spec` など。任意の名前を書け、コンパイルした結果に残る | — |
| Gleam | あり | `@name(args)` | `@external`、`@deprecated("…")`、`@internal`（v1.1）、`@target`（非推奨） | 導出もテストの属性もない |
| Elm | なし | — | — | 外部との連携は `port` |
| Roc | 見つからない | — | — | テストは `expect`、`dbg` |
| PureScript | 文書にない | — | — | `derive instance` |
| Lean 4 | あり | `@[attr]`、`attribute [simp] foo` | `simp`・`instance`・`ext` など、拡張できる | `deriving` |
| Clojure | あり（メタデータ） | `^{:k v}`、`^:kw` | `:private`・`:doc`・`:test`・`:tag`・`:dynamic` | — |
| Flix | あり | `@Name` | `@Test`・`@Parallel`・`@Lazy` など | `flix test` が `@Test` の関数を集める |
| Koka | なし | — | — | `inline`・`noinline`・`fip`・`extern` などのキーワード |
| Unison | なし | — | — | テストは `test>` の式 |
| Idris 2 | あり（プラグマ） | `%name …` | `%inline`・`%deprecate`・`%foreign` など | — |
| Racket | なし | — | — | テストは `(module+ test …)` |

- 属性の主な用途は、非推奨、インライン化、外部の関数の呼び出しである。
- 導出は、Haskell・PureScript・Lean・Scala 3 がキーワードで表す。OCaml だけが、前処理器による属性で表す。

【要検証】

- GHC の `deriving instance` の形と、DerivingStrategies・DeriveAnyClass。
- Elixir の予約された属性の全体（`@deprecated`・`@impl`・`@compile`）と、ExUnit の `test` がマクロであること。
- Erlang の `-deprecated` の構文。
- Lean 4 の `@[inline]`・`@[extern]`・`@[specialize]`・`@[deprecated]` など、個々の属性の名前。
- F# の `[<EntryPoint>]`・`[<Literal>]`、NUnit・xUnit の属性。
- Elm に属性がないこと（公式の構文の頁を読めなかった）。
- Roc の ability の導出の書き方と、ドキュメントコメント。
- PureScript にプラグマの構文がないこと。
- Flix の注釈の一覧のうち、`@Test`・`@Parallel`・`@Lazy` 以外（コンパイラのソースから得た）。
- Unison の文書の構文、Racket に属性に当たる形がないこと。

出典

- https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/pragmas.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch12.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch4.html
- https://ocaml.org/manual/5.3/attributes.html
- https://ocaml.org/docs/metaprogramming
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/attributes
- https://docs.scala-lang.org/tour/annotations.html
- https://docs.scala-lang.org/scala3/reference/contextual/derivation.html
- https://elixir.hexdocs.pm/module-attributes.html
- https://www.erlang.org/doc/system/modules.html
- https://tour.gleam.run/everything/
- https://github.com/gleam-lang/gleam/blob/main/changelog/v1.1.md
- https://github.com/gleam-lang/gleam/discussions/5192
- https://guide.elm-lang.org/interop/ports.html
- https://github.com/purescript/documentation/blob/master/language/Type-Classes.md
- https://lean-lang.org/doc/reference/latest/Attributes/
- https://lean-lang.org/doc/reference/latest/Type-Classes/Deriving-Instances/
- https://clojure.org/reference/reader
- https://doc.flix.dev/test-framework.html
- https://github.com/flix/flix/blob/master/main/src/ca/uwaterloo/flix/language/ast/shared/Annotation.scala
- https://koka-lang.github.io/koka/doc/book.html
- https://www.unison-lang.org/docs/usage-topics/testing/
- https://idris2.readthedocs.io/en/latest/reference/pragmas.html
- https://docs.racket-lang.org/guide/Module_Syntax.html

### パターンの拡張

[ADR 0121](../decisions/0121-pattern-extensions.md) の判断に使った。

| 言語 | ガード | or パターンと、選択肢での束縛 | リストのパターン | 範囲のパターン |
|---|---|---|---|---|
| Haskell 2010・GHC | `n \| n > 0 -> …` | Haskell 2010 にない。GHC 9.12.1 の `OrPatterns` 拡張は `(p1; p2)` で、選択肢は変数を束縛できない | `[]`、`[a, b]`、`(x:xs)` | なし |
| OCaml | `when` | `p1 \| p2`。すべての選択肢が同じ名前と型の変数を束縛する | `[]`、`[a; b]`、`h :: t` | 文字だけ（`'a'..'z'`） |
| F# | `when` | `p1 \| p2` | `[a; b]`、`h :: t`、配列 `[\| a; b \|]` | なし |
| Rust | `if` | `A(a) \| B(a)`。すべての選択肢が同じ名前・型・束縛の仕方を持つ。ガードは選択肢ごとに評価されうる | `[]`、`[a, b]`、`[head, tail @ ..]`、`[first, .., last]`（`..` は一つまで、どこにでも置ける） | `1..=5`、`'a'..='z'`、`5..`、`..=5`。末尾を含まない `a..b` は 1.80 で安定 |
| Scala 3 | `if` | `p1 \| p2`。ワイルドカード以外の変数を束縛できない | `List(a, b)`、`a :: rest`、`List(a, rest*)`（残りは最後だけ） | なし |
| Elixir | `when`（複数の `when` は `or` に当たる） | — | `[a, b]`、`[h \| t]`、文字列の先頭 `"a" <> rest` | — |
| Gleam | `if`（ガードの中で関数を呼べない） | `2 \| 4 \| 6`。束縛するなら、すべての選択肢が同じ名前と型を束縛する | `[]`、`[_, _]`、`[x, ..rest]`（残りは最後だけ）、文字列の先頭 `"Hello, " <> name` | なし |
| Swift | `where` | コンマ（`case 1, 2, 3:`）。束縛するなら、すべての選択肢が同じ名前と型を束縛する | なし | `1..<18`、`18...65` |
| Kotlin `when` | 対象を持つ `when` のガード（2.2.0 で安定） | コンマ（条件の並びで、束縛はしない） | なし | `in 1..10`、`!in 10..20` |
| Python 3.10 以降 | `if` | `p1 \| p2`。すべての選択肢が同じ名前の集合を束縛する | `[x, *rest]`、`[first, *mid, last]`（`*` は一つまで） | なし |
| Free Pascal | なし | コンマ（`'a','e','i':`） | — | `1..5:`、`else`・`otherwise`。重複と重なりは誤り |
| Ada | なし | `when 0 \| 360 =>` | — | `when 1 .. 89 =>`、`when others =>`。網羅をコンパイルの時点で確かめる |

- or パターンの束縛: OCaml・Rust・Python・Gleam・Swift は、すべての選択肢に同じ名前の束縛を求める。Haskell（GHC 9.12）と Scala は、束縛を禁じる。
- ガードと or パターンを組み合わせると、ガードは分岐全体にかかる。Rust は、ガードが選択肢ごとに評価されうると文書に書く。

【要検証】

- Elixir に or パターンと範囲のパターンがないこと、ガードで `x in 1..5` を書けること。
- F# の or パターンでの変数の束縛の規則。
- Kotlin で、対象を持たない `when` にガードを書けるか。
- ISO 7185 Pascal に `otherwise` があるか。
- Ada の事実は learn.adacore.com によった。Ada RM の 5.4 節は読めなかった。

出典

- https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/or_patterns.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch3.html
- https://ocaml.org/manual/5.3/patterns.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/pattern-matching
- https://doc.rust-lang.org/reference/patterns.html
- https://doc.rust-lang.org/reference/expressions/match-expr.html
- https://blog.rust-lang.org/2024/07/25/Rust-1.80.0/
- https://docs.scala-lang.org/scala3/reference/syntax.html
- https://scala-lang.org/files/archive/spec/2.13/08-pattern-matching.html
- https://elixir.hexdocs.pm/patterns-and-guards.html
- https://tour.gleam.run/everything/
- https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/
- https://kotlinlang.org/docs/control-flow.html
- https://kotlinlang.org/docs/whatsnew22.html
- https://peps.python.org/pep-0634/
- https://docs.python.org/3/reference/compound_stmts.html
- https://www.freepascal.org/docs-html/ref/refsu56.html
- https://learn.adacore.com/courses/intro-to-ada/chapters/imperative_language.html

### 複数行の文字列と raw 文字列

[ADR 0122](../decisions/0122-multiline-and-raw-strings.md) の判断に使った。

| 言語 | 区切り | インデントの除き方 | 最初と最後の改行 | エスケープ | 文字列補間 | raw の形 |
|---|---|---|---|---|---|---|
| Python | `"""…"""`、`'''…'''` | 除かない | 書いたとおり | 処理する | `f"""…"""` | `r"…"` |
| Java（JEP 378） | `"""` と改行 … `"""` | 共通のインデントを除く。単独の行に置いた閉じる `"""` も数える | 開く側の改行は含めない。閉じる `"""` が単独の行なら最後の改行を含める | 除いた後に処理する。`\<改行>` と `\s` を加えた | なし | なし |
| Kotlin | `"""…"""` | 組み込みでは除かない。`trimIndent()`・`trimMargin("\|")` | 関数で除く | 処理しない | `$x`、`${e}`。`$$"""…"""`（2.2.0 で安定） | `"""` 自体が raw |
| Swift | `"""` と改行 … `"""` | 閉じる区切りの位置で除く | 開く側の直後と閉じる側の直前の改行を含めない | 処理する | `\(e)` | `#"…"#`、`#"""…"""#` |
| C# 11 | `"""`（三つ以上） | 閉じる区切りの左の空白を全行から除く（一致しなければならない） | 閉じる側の直前の改行を含めない | 処理しない | `$"""…{x}…"""`、`$$"""…{{x}}…"""` | 内容より長い引用符の並びで囲む |
| Rust | 普通の `"…"` が改行を含められる | 除かない | 書いたとおり | `"…"` は処理する、`r"…"` は処理しない | なし（`format!` のマクロだけ） | `r"…"`、`r#"…"#` |
| Go | `` `…` `` | 除かない | 書いたとおり（CR は捨てる） | 処理しない | なし | バッククォートを含められない |
| Scala | `"""…"""` | `.stripMargin` | 書いたとおり | `"""` では処理しない | `s"""…$x…"""` | `"""` 自体が raw、`raw"…"` |
| Elixir | ヒアドキュメント `"""` と改行 … `"""` | 閉じる `"""` のインデントで除く | 結果は常に改行で終わる | 処理する | `#{}` | 大文字のシジル（`~S"""…"""`） |
| Gleam | 普通の `"…"` が複数行にわたれる | 除かない | 書いたとおり | 処理する | なし | なし |
| OCaml | `{\|…\|}`、`{id\|…\|id}` | 除かない | 書いたとおり（5.2 から改行を LF にそろえる） | 処理しない | なし | `\|id}` が現れない `id` を選ぶ |
| Haskell（GHC 9.12.1 以降の `MultilineStrings`） | `"""…"""` | 最初の行と空白だけの行を除いて、共通の空白を除く | 先頭と末尾の改行を除く | 除いた後に処理する | なし | なし |
| F# | `"""…"""`、逐語的な `@"…"` | 除かない | 書いたとおり | `"""` では処理しない | `$"""…{e}…"""`、`$$"""…{{e}}…"""`（F# 8） | `"""` は `"` を含められる |
| Zig | 各行を `\\` で始める | インデントは `\\` の前にあり、内容に入らない | 最後の行の後の改行を含めない | 処理しない | なし | もともと raw |
| Delphi 12 | `'''` と改行 … 単独の行の `'''` | 閉じる `'''` の位置で除く | 【要検証】 | 【要検証】 | なし | 奇数個（5・7 …）の引用符で `'''` を含める |
| Julia | `"""…"""` | 開く `"""` の次の行と空白だけの行を除いて、共通の空白を除く。閉じる行も数える | 開く側の直後の改行を除く | 処理する | `$x`、`$(e)` | `raw"…"` |
| Nim | `"""…"""` | 除かない | `"""` の直後の改行を除く | 処理しない | なし（`fmt` はライブラリ） | `r"…"` |
| Lua | `[[…]]`、`[==[…]==]` | 除かない | 開く括弧の直後の改行を飛ばす | 処理しない | なし | `=` の数を変える |

- インデントの除き方は三通りである。閉じる区切りの位置で除く（Swift・C#・Elixir・Delphi）、共通の先頭を除く（Java・Julia・Haskell）、明示の関数や記号で除く（Kotlin・Scala・Zig）。
- 閉じる区切りが単独の行にあるとき、最後の改行を内容に含めるのは Java・Python・Elixir、含めないのは Swift・C#・Haskell である。

【要検証】

- Roc の複数行の文字列の構文。
- Delphi 12 の最初と最後の改行とエスケープの扱い。Delphi の事実は、公式の docwiki を読めなかったので、Embarcadero の公式ブログによった。
- Free Pascal の複数行の文字列（バッククォートと `'''`）が、リリースされた版に含まれるか。
- Rust の `\` と改行が、次の行の先頭の空白も除くか。

出典

- https://docs.python.org/3/reference/lexical_analysis.html
- https://openjdk.org/jeps/378
- https://kotlinlang.org/docs/strings.html
- https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.text/trim-indent.html
- https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/
- https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/raw-string
- https://doc.rust-lang.org/reference/tokens.html
- https://go.dev/ref/spec
- https://docs.scala-lang.org/scala3/book/string-interpolation.html
- https://elixir.hexdocs.pm/syntax-reference.html
- https://tour.gleam.run/everything/
- https://ocaml.org/manual/5.3/lex.html
- https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/multiline_strings.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/strings
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/interpolated-strings
- https://ziglang.org/documentation/master/
- https://blogs.embarcadero.com/yukon-beta-blog-delphi-language-modernizing-string-literals/
- https://www.mail-archive.com/fpc-pascal@lists.freepascal.org/msg57756.html
- https://docs.julialang.org/en/v1/manual/strings/
- https://nim-lang.org/docs/manual.html
- https://www.lua.org/manual/5.4/manual.html

### トップレベルの定数

[ADR 0123](../decisions/0123-top-level-constants.md) の判断に使った。

| 言語 | 書き方 | 初期化の式 | 計算する時点 | 多相 | 型の注釈 | 順序と循環 |
|---|---|---|---|---|---|---|
| ISO Pascal（ISO 7185） | `const N = 定数;` | 符号付きの数、ほかの定数の名前、文字列だけ。式は書けない（6.3） | 翻訳時 | なし | 書かない | 定義の中で自分の名前を使えない（6.3） |
| Free Pascal | `N = 式;`、型付きの `N : T = 値;` | 普通の定数は、`+ - * / not and or div mod ord chr sizeof pi int trunc round frac odd` などを使うコンパイル時の式に限り、順序型・集合・実数・文字・文字列などの型に限る。型付きの定数は配列・レコードなども持てる | 普通の定数はコンパイル時。型付きの定数はプログラムの開始時に初期化し、`{$J+}`（既定）では実行中に書き換えられる | なし | 普通の定数は省略できる。型付きの定数は必須 | — |
| Ada | 名前付きの数 `N : constant := 静的な式;`、定数のオブジェクト `C : constant T := 式;` | 名前付きの数は静的な式に限り、型は universal_integer か universal_real になる（RM 3.3.2）。定数のオブジェクトは任意の式（RM 3.3.1） | 名前付きの数は静的。定数のオブジェクトは elaboration の時点 | なし | 名前付きの数は書かない。オブジェクトは必須 | 【要検証】 |
| OCaml | 構造の中の `let x = e` | 任意の式（作用を含む） | モジュールの初期化の時点で、構造の中に書いた順に計算する | value restriction の下で多相になる | 省略できる | 後の定義だけが前の定義を参照できる |
| F# | `let x = e`、`[<Literal>] let X = e` | `let` は任意の式で、実行時に計算する。`[<Literal>]` はコンパイル時の定数で、関数を使えない。大文字で始めればパターンに書ける | `let` は実行時、`[<Literal>]` はコンパイル時 | 【要検証】 | 省略できる | 【要検証】 |
| Haskell 2010 | `x = e`（`x :: T` を添えられる） | 任意の純粋な式 | 非正格（必要になったとき） | 多相になる。型の注釈のないパターン束縛には単相性制限が働く（4.5.5） | 省略できる | 順序によらない。依存の解析で相互再帰する束縛をまとめる（4.5.1） |
| Elm | `x = e` | 任意の式（作用はない） | 【要検証】 | 【要検証】 | 省略できる | 値の再帰は、自分に戻るまでにラムダを挟まない限り誤り |
| Gleam | `const x = …`、`pub const` | リテラルの値に限り、関数を使えない | 文書に定めがない | 【要検証】 | 【要検証】 | 【要検証】 |
| Rust | `const N: T = e;`、`static N: T = e;` | 定数式 | コンパイル時。自由な `const` は、panic を見つけるために必ずコンパイル時に計算する。`const` は使う箇所ごとに埋め込み、`static` は一つの番地を持つ | 自由な `const` は総称にできない | 必須 | 【要検証】 |
| Go | `const X [T] = e`、`var x = e` | `const` は定数式（リテラル、定数、変換、`len`・`min`・`max` などの一部の組み込み関数）。`var` は任意の式 | `const` はコンパイル時。パッケージの `var` はパッケージの初期化の時点 | 総称の定数はない | 省略できる（型のない定数になる） | `var` は依存の順に初期化し、初期化が循環すると誤り |
| Kotlin | `const val X = e`、`val x = e` | `const val` はトップレベルか `object` の中に置き、String と基本型の値に限り、値はコンパイル時に決まる | `const val` はコンパイル時で、使う箇所に埋め込む | なし | 省略できる | 【要検証】 |
| Swift | グローバルな `let x[: T] = e` | 任意の式。宣言で値を与えなければならない | グローバルな定数と変数は、初めて使うときに計算する（`lazy` を付けなくてよい） | なし | 推論できれば省略できる | 【要検証】 |
| Zig | コンテナの `const x = e;` | コンパイル時に計算できる式（名前空間の変数の初期化は暗黙にコンパイル時） | コンパイル時 | 型や値を返すコンパイル時の関数で総称にする | 省略できる | 順序によらず、使われたものだけを解析する |
| Roc | トップレベルの `x = e` | 【要検証】 | 新しいコンパイラは、トップレベルの定数をコンパイル時に計算する | 【要検証】 | 省略できる | 【要検証】 |
| Elixir | モジュールの属性 `@name 値` | 関数の呼び出しを含む任意の式。同じモジュールの関数は呼べない | コンパイル時。関数の中で読むと、その時点の値が埋め込まれる | —（動的型付け） | — | 書いた順。設定の前に読むと警告 |

- 値をコンパイル時に計算できる式に限る言語（Pascal・Free Pascal の普通の定数、Rust、Go の `const`、Kotlin の `const val`、F# の `[<Literal>]`、Gleam、Zig）と、任意の式を読み込みの時点か初めて使うときに計算する言語（OCaml、Go の `var`、Ada の定数のオブジェクト、Swift、Haskell）に分かれる。

【要検証】

- Delphi の定数。公式の docwiki を読めなかった。検索結果の抜粋では、真の定数はプログラムを実行せずに計算できる式に限り、型付きの定数は配列・レコードを持てるが定数式には書けない。
- Ada のライブラリの定数の elaboration の順序。
- F# のトップレベルの `let` の多相と、モジュールの初期化の順序。
- Elm のトップレベルの値を計算する時点。
- Gleam の定数が、ほかの定数・レコード・リストを参照できるか。型の注釈の書き方。
- Rust の `const` と `static` の循環の扱い。
- Kotlin の JVM でのトップレベルの `val` の初期化の時点。
- Swift の `main.swift` のトップレベルのコードの扱いと、循環の扱い。
- Roc のトップレベルの定義の順序と作用。

出典

- https://www.standardpascal.org/iso7185.html
- https://www.freepascal.org/docs-html/ref/refse9.html
- https://www.freepascal.org/docs-html/ref/refse10.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-3-1.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-3-2.html
- https://ocaml.org/manual/5.2/modules.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/literals
- https://www.haskell.org/onlinereport/haskell2010/haskellch4.html
- https://github.com/elm/compiler/blob/master/hints/bad-recursion.md
- https://tour.gleam.run/basics/constants/
- https://doc.rust-lang.org/reference/items/constant-items.html
- https://doc.rust-lang.org/reference/items/static-items.html
- https://go.dev/ref/spec
- https://kotlinlang.org/docs/properties.html
- https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Declarations.md
- https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/Properties.md
- https://ziglang.org/documentation/master/
- https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
- https://github.com/elixir-lang/elixir/blob/main/lib/elixir/pages/getting-started/module-attributes.md

### 型の別名

[ADR 0124](../decisions/0124-type-aliases.md) の判断に使った。

| 言語 | 別名の書き方 | 元の型と置き換えられるか | 型パラメータ | 再帰 | 元の型と区別する型の作り方 |
|---|---|---|---|---|---|
| ISO Pascal | `type T = Integer;` | 型の名前を右辺に書いた定義は、同じ型を表す（6.4.1） | なし | 右辺に自分の名前を書けない（ポインタの指す型を除く） | 新しい構造の型は、ほかのどの型とも別の型になる |
| Ada | `subtype S is T [制約];` | subtype は新しい型を定義しない（RM 3.2.2） | — | — | `type D is new T;`（派生型。明示の変換が要る。RM 3.4） |
| Haskell 2010 | `type T a = t` | 完全に置き換えられる | 持てる。部分適用はできない | 代数的データ型を挟まない限り禁じる（4.2.2） | `newtype N = N t`（表現を変えずに別の型を作る。4.2.3） |
| OCaml | `type t = int` | 略記であり、型付けで置き換えられる | 持てる | 【要検証】 | 【要検証】 |
| F# | `type A = T` | 置き換えられ、CIL には残らない | 持てる | 【要検証】 | 【要検証】 |
| Elm | `type alias A = …` | 置き換えられる | 【要検証】 | 禁じる（展開が終わらないため。`type` を使うよう示す） | カスタムの `type`。レコードの別名は構成子の関数も作る |
| Gleam | `type A = B`、`pub type A = B` | 新しい型を作らず、同じ型である。使いすぎないよう勧めている | 【要検証】 | 【要検証】 | カスタムの型。`pub opaque type` は構成子を隠す |
| Rust | `type A<T> = …;` | 同じ型の別の名前 | 持てる | 【要検証】 | 構造体で包む（newtype）。タプル構造体の別名を通して構成子を呼べない |
| Go | `type A = B` | 同じ型 | Go 1.24 から持てる。`type A[P any] = P` は書けない | 【要検証】 | `type A B`（定義型。元の型と別の型で、メソッドを引き継がない） |
| Kotlin | `typealias A<T> = …` | 新しい型を作らず、置き換えられる。トップレベルと入れ子に書け、局所には書けない | 持てる | 【要検証】 | 【要検証】 |
| Swift | `typealias A<T> = …` | 新しい型を作らない | 持てる。制約は元の型と一致しなければならない | 【要検証】 | 【要検証】 |
| Scala 3 | `type A = …`、`opaque type L = Double` | `type` は置き換えられる（詳細は【要検証】） | 【要検証】 | 【要検証】 | `opaque type` は、定義した範囲の中だけで別名として扱い、外からは中身を見せない |
| TypeScript | `type A = …` | 別名は別名にすぎず、元の型を書いたのと同じ | 【要検証】 | 【要検証】 | 名前で区別する型はない |

- 誤りの表示に別名を示すかを文書で定めていたのは TypeScript だけであり、別名は誤りの表示に「出ることも出ないこともある」とする。
- Delphi は `type T = Integer;` を同じ型、`type T = type Integer;` を別の型とする（公式の docwiki の検索結果の抜粋による。【要検証】）。

【要検証】

- Delphi の型の別名（上記）。公式の docwiki を読めなかった。
- OCaml・Rust・Go・Kotlin・Swift・TypeScript・F#・Gleam の別名の再帰の扱い。
- OCaml の private 型と抽象型、F# の単一の構成子の共用体、Kotlin の value class、Swift の構造体で包む書き方を、元の型と区別する型の作り方として文書が勧めているか。
- Elm・Gleam・Scala 3・TypeScript の別名の型パラメータ。

出典

- https://www.standardpascal.org/iso7185.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-2-2.html
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-4.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch4.html
- https://ocaml.org/manual/5.2/typedecl.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/type-abbreviations
- https://guide.elm-lang.org/types/type_aliases.html
- https://github.com/elm/compiler/blob/master/hints/recursive-alias.md
- https://tour.gleam.run/everything/
- https://doc.rust-lang.org/reference/items/type-aliases.html
- https://go.dev/ref/spec
- https://kotlinlang.org/docs/type-aliases.html
- https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/ReferenceManual/Declarations.md
- https://docs.scala-lang.org/scala3/reference/other-new-features/opaques.html
- https://www.typescriptlang.org/docs/handbook/2/everyday-types.html

### ドキュメントコメント

[ADR 0125](../decisions/0125-doc-comments.md) の判断に使った。

| 言語 | 書き方 | 置く位置 | 説明する宣言のない位置 | 中身の書式 | 例をテストとして実行するか | 構造化した項目 | コンパイラが読むか |
|---|---|---|---|---|---|---|---|
| Rust | `///`・`/** */`（外側）、`//!`・`/*! */`（内側）。`#[doc]` の属性に移す | 宣言の前。内側の形は囲む項目の説明 | 誤り（E0585 など）か、位置によって警告（`unused_doc_comments`） | Markdown | する（`cargo test --doc`） | なし（`# Examples` の見出しの慣習） | 読む（属性として）。表示は rustdoc |
| Gleam | `///`（宣言）、`////`（モジュール） | `///` は型か関数の直前、`////` はモジュールの先頭 | 【要検証】 | 【要検証】 | 【要検証】 | 【要検証】 | 【要検証】 |
| Elm | `{-\| … -}` | モジュールの説明は `module` の行の後、宣言の説明は宣言の前。`@docs` で項目を並べる | 【要検証】 | Markdown | 【要検証】 | `@docs` | 公開するパッケージは、説明のないモジュールを登録できない |
| Haskell（Haddock） | `-- \|`（前）、`-- ^`（後） | 宣言の前か後 | GHC の `-Winvalid-haddock`（9.0 から）が、`-haddock` を付けたときに、無効な位置のコメントを捨てたと警告する | Haddock の記法 | Haddock は実行しない | `@since` など | `-haddock` を付けると GHC が読む |
| OCaml | `(** … *)` | 項目の直前か直後。前後に空行を置いたものは独立の説明 | 警告 50 | odoc の記法 | odoc は実行しない | `@param`・`@return`・`@raise`・`@since`・`@deprecated`・`@see` | 読む（構文解析で `ocaml.doc` の属性に移す） |
| Go | 普通の `//` のコメント | パッケージ・定数・関数・型・変数の宣言の直前に、空行を挟まずに置く | 普通のコメントとして扱う | 見出し、箇条書き、字下げしたコード、`[Name]` のリンク。gofmt が整える | `_test.go` の `ExampleXxx` 関数。`// Output:` を比べ、それがなければコンパイルだけする | なし | go/doc と gofmt が読む |
| Kotlin | `/** */`（KDoc） | 宣言の前 | 【要検証】 | Markdown、`[name]` のリンク | 【要検証】 | `@param`・`@return`・`@throws`・`@property`・`@see`・`@since` など | 別の道具（Dokka）が読む |
| Swift | `///`・`/** */` | 宣言の前。最初の行を要約とする | 【要検証】 | Markdown | 【要検証】 | `- Parameters:`・`- Returns:`・`- Throws:` の箇条書き | 表示は DocC。コンパイラが読むかは【要検証】 |
| Zig | `///`（ちょうど三つ）、`//!`（トップレベル） | `//!` は名前空間の先頭 | コンパイルの誤り | 【要検証】 | する（名前を付けた `test` のブロックを doctest として示し、`zig test` で確かめる） | なし | 読む（パッケージの文書を作る） |
| Elixir | `@moduledoc`・`@doc`・`@typedoc` | `def` の前 | 非公開の関数の `@doc` は警告（中身は捨てる） | Markdown | する（ExUnit.DocTest が `iex>` の例を実行する） | `## Examples` の慣習 | 読む（バイトコードに保存し、`Code.fetch_docs/1` で読める） |
| Python | 最初の文に置いた文字列リテラル（docstring） | モジュール・関数・クラス・メソッド | ほかの位置の文字列は `__doc__` にならないだけ | 慣習による | する（`doctest` のモジュールが `>>>` の対話を実行する） | 慣習による | 読む（`__doc__`） |
| Julia | 対象の前の文字列リテラル | 空行やコメントを挟まない | 【要検証】 | Markdown | ` ```jldoctest ` のブロックを Documenter.jl（別のパッケージ）が実行する | `# Arguments`・`# Examples` の慣習 | 実行時に説明を対象に結び付ける |
| D | `///`・`/** */`・`/++ +/` | 宣言の前、または同じ行の右。`module` の前はモジュールの説明 | 宣言に結び付かない説明は無視する | Ddoc のマクロと Markdown に似た記法 | `///` を付けた `unittest` のブロックを例として文書に入れる | `Params:`・`Returns:`・`Throws:`・`Examples:` など | 読む（`dmd -D`） |

- 宣言の前の `///` を説明とするのは Rust・Swift・Zig・Gleam・D である。モジュールの説明は、Rust と Zig が `//!`、Gleam が `////` で書く。
- 説明する宣言のない位置の説明を、Zig は誤りに、Rust は位置によって誤りか警告に、OCaml と Haskell（GHC）は警告にする。Go・D は普通のコメントとして扱うか無視する。

【要検証】

- Delphi の XML の説明のコメント（`///` と `<summary>`・`<param>`・`<returns>`）。公式の docwiki を読めず、検索結果の抜粋では、警告 W1207・W1208 が引数の説明の過不足を示す。
- Free Pascal の説明の書き方（fpdoc の別ファイルの XML か）。
- Haskell の `>>>` の例を別の道具（doctest）が実行すること。
- Gleam の置く位置を誤った説明の扱い、中身の書式、例の実行、コンパイラが読むか。
- Elm の説明の例を実行するか。
- Kotlin・Swift の置く位置を誤った説明の扱いと、例の実行。Kotlin の `@sample` を実行するか。
- Julia の対象のない説明の扱い。
- Zig の説明の中身の書式。

出典

- https://doc.rust-lang.org/reference/comments.html
- https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html
- https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html
- https://github.com/rust-lang/rust/tree/master/compiler/rustc_error_codes/src/error_codes
- https://tour.gleam.run/everything/
- https://raw.githubusercontent.com/elm/package.elm-lang.org/master/assets/help/documentation-format.md
- https://haskell-haddock.readthedocs.io/latest/markup.html
- https://downloads.haskell.org/ghc/latest/docs/users_guide/using-warnings.html
- https://ocaml.org/manual/5.2/doccomments.html
- https://ocaml.github.io/odoc/odoc/odoc_for_authors.html
- https://go.dev/doc/comment
- https://pkg.go.dev/testing
- https://kotlinlang.org/docs/kotlin-doc.html
- https://github.com/swiftlang/swift-docc/blob/main/Sources/docc/DocCDocumentation.docc/writing-symbol-documentation-in-your-source-files.md
- https://ziglang.org/documentation/master/
- https://elixir.hexdocs.pm/writing-documentation.html
- https://peps.python.org/pep-0257/
- https://docs.python.org/3/library/doctest.html
- https://docs.julialang.org/en/v1/manual/documentation/
- https://dlang.org/spec/ddoc.html

### ソースファイルの配置と起動

[ADR 0126](../decisions/0126-import-by-module-name.md)、[ADR 0127](../decisions/0127-directory-run-and-root.md)、[ADR 0131](../decisions/0131-script-directory-and-permission-base.md) の判断に使った。

| 言語 | 一つのファイルの実行と入口 | 手元のファイルの取り込みの基準 | ディレクトリの実行と入口 | 設定ファイル | 一つのファイルに依存を書く仕組み |
|---|---|---|---|---|---|
| Python | `python f.py`。スクリプトのディレクトリを `sys.path` の先頭に置く（`-m`・`-c` では作業ディレクトリ） | `sys.path` を探す。相対の import はパッケージの中だけ | `python dir/` は `__main__.py` を実行する。`python -m pkg` は `pkg.__main__` | `pyproject.toml` | あり（PEP 723 のインラインのメタデータ。`uv run` は周りのプロジェクトの依存を使わない） |
| Node | 入口のパスは作業ディレクトリから解決する | CJS は呼ぶ側のファイルのディレクトリから。ESM は取り込む側のモジュールから、拡張子が必須で、ディレクトリは取り込めない | `package.json` の `main`、次に `index.js`。ディレクトリをモジュールとする形は「Legacy」 | `package.json`。権限はコマンドラインのオプション | 見つからなかった（【要検証】） |
| Deno | `deno run main.ts`（URL・`npm:` も可） | 取り込む側のモジュールから。拡張子は必須 | 【要検証】 | `deno.json`。作業ディレクトリとその親を探す。名前付きの `permissions` の組を書ける | あり（import に `npm:`・`jsr:`・URL を書く） |
| Ruby | `ruby f.rb` | `require_relative` は取り込む側のファイルのディレクトリから。`./` で始まる `require` は作業ディレクトリから | なし | `Gemfile` | あり（`bundler/inline`） |
| Perl | `perl f.pl` | `@INC` を探す。5.26 で作業ディレクトリ `.` を外した。`FindBin` でスクリプトのディレクトリを得る | なし | — | 見つからなかった（【要検証】） |
| Lua | `lua script.lua` | `package.path`。既定は作業ディレクトリの `./?.lua` | なし | LuaRocks の `.rockspec` | なし |
| Go | `go run f.go`。一つのファイルの操作は勧めない | モジュールのパスとディレクトリ。パッケージはディレクトリ | `go run .`。入口は `package main` の `func main` | `go.mod`。作業ディレクトリを含むモジュールが主モジュール | なし |
| Rust | `cargo -Zscript f.rs` は不安定（Cargo 1.98 でも `-Zscript`） | `mod foo;` は宣言したモジュールの隣の `foo.rs` | `cargo run`。`src/main.rs`、`src/bin/*`、`default-run` | `Cargo.toml`（作業ディレクトリかその親） | 不安定な `---cargo` の前書き |
| Julia | `julia f.jl`。1.11 から `@main` | `include` は取り込む側のファイルのディレクトリから | `julia -m Package` | `Project.toml` | 見つからなかった（【要検証】） |
| Elixir | `elixir f.exs` | `Code.require_file` は作業ディレクトリから | `mix run` | `mix.exs` | あり（`Mix.install`。Mix のプロジェクトの中では呼べない） |
| Gleam | 一つのファイルは実行できない | `src/` の下のパスがモジュールの名前 | `gleam run` はパッケージと同じ名前のモジュールの `main` | `gleam.toml` | なし |
| Kotlin | `kotlin f.main.kts` | `@file:Import` はスクリプトのディレクトリから | —（Gradle は調べていない） | — | あり（`@file:DependsOn`） |
| Swift | `swift f.swift`（インタプリタのモード） | ファイルの import はない。同じモジュールのファイルは互いに見える | `swift run`。`main.swift` か `@main` | `Package.swift` | なし |
| Dart | `dart run tool/debug.dart` | 相対パス、`package:`、`dart:` | パッケージの `bin/<パッケージ名>.dart` | `pubspec.yaml` | なし |
| Racket | `racket f.rkt`。`main` の下位モジュールがあれば実行する | 取り込む側のファイルから | なし | 【要検証】 | なし |
| PowerShell | `pwsh -File f.ps1` | `using module ./x` はスクリプトから。`$PSScriptRoot` でスクリプトのディレクトリを得る | — | — | `#Requires` は導入済みのものを読むだけで、取得しない |
| Roc | `roc main.roc`。引数がなければ `main.roc`。入口はヘッダの `app [main!]` | 基準のディレクトリから（下の注） | 同左 | 設定ファイルはない。依存はアプリケーションのヘッダに書く | あり（ヘッダが設定ファイルを兼ねる） |

Roc の取り込みとパッケージは、次のとおりである。

- 取り込みの対象は、修飾しない名前と `./` で始まるものが基準のディレクトリを、`../` がパッケージの根の方向を、先頭の `/` がパッケージの根を表す。ほかのパッケージの内部のパスは直接取り込めず、そのパッケージが公開した名前で使う。
- 型のモジュールはヘッダを持たず、ファイル名と同じ名前の名前付きの型をトップレベルに定義しなければならない（`Url.roc` には `Url :=` か `Url ::`）。
- パッケージは、`.tar.zst` に圧縮したものを指す HTTPS の URL で指定する。URL の最後の部分（`.tar.zst` の直前）は中身のハッシュであり、取得した後に照合して、一致しなければ使わない。HTTP は `localhost` に限る。置き場所は、HTTPS で静的なファイルを配信できる場所ならどこでもよく、公式の例は GitHub のリリースを使う。中央のレジストリはない。URL に `MAJOR.MINOR.PATCH` の版を含められる。取得したものは保存し、二度目は取得しない。手元のパッケージの `main.roc` へのパスも書け、パスは依存を宣言したモジュールから辿る。
- 新しいコンパイラの組み込みのモジュールは、一つのファイル `src/build/roc/Builtin.roc` にまとまっている。ファイルは `Builtin :: [].{` で始まり、`Str`・`List`・`Dict` などを入れ子の型として定義する。

Agent Skills の文書は、次のとおりである。

| 事項 | 文書の記述 |
|---|---|
| 構成 | `SKILL.md`（必須）と、任意の `scripts/`・`references/`・`assets/` |
| スクリプト | 依存を自分の中に持つか、依存を明記する。対応する言語はエージェントの実装による |
| 起動の作業ディレクトリ | agentskills.io は、エージェントは Skill のディレクトリから実行するとする。Claude Code の文書は、セッションのシェルの作業ディレクトリで実行するとし、`${CLAUDE_SKILL_DIR}` で絶対パスを作ることを勧める |
| スクリプトの書き方 | 対話で入力を求めない、`--help` を持つ、出力を構造化し診断は標準エラー出力に書く、終了状態に意味を持たせる |
| 依存と環境 | Claude API ではネットワークがなく、実行時にパッケージを導入できない。Claude Code ではネットワークを使える |

- 取り込みを取り込む側のファイルから解決する言語が多い（Node、Deno、Ruby の `require_relative`、Julia、Racket、Kotlin、PowerShell、Roc）。作業ディレクトリに依存する取り込みは、問題として扱われている（Perl の `.` の除去、Ruby の `require_relative`）。
- ディレクトリの入口は、決まった名前のファイル、設定ファイルの欄、名前の規則のどれかで決める。
- 設定ファイルを作業ディレクトリから親へ辿って探す言語（Deno、Rust、Go）では、起動した場所によって効く設定が変わりうる。
- 一つのファイルに依存を書く仕組みは、周りのプロジェクトの設定を使わないか、同時に使うことを禁じることが多い。

【要検証】

- `deno run` と `bun run` にディレクトリを渡したときの振る舞い。
- Node・Perl・Lua・Julia・Swift・Dart・Racket に、一つのファイルに依存を書く仕組みがないこと。
- Racket の `info.rkt`、PowerShell の `.psd1` の欄。
- Nushell の `use` の「current directory」が作業ディレクトリかスクリプトのディレクトリか。
- Roc の取り込みの基準のディレクトリが、取り込む側のファイルのディレクトリであること。Roc の文書は新しいコンパイラのもので、変わりうる。
- Agent Skills で、Skill が自分の実行ファイル（処理系）を同梱して実行できるか。

出典

- https://docs.python.org/3/using/cmdline.html
- https://docs.python.org/3/library/sys_path_init.html
- https://packaging.python.org/en/latest/specifications/inline-script-metadata/
- https://docs.astral.sh/uv/guides/scripts/
- https://nodejs.org/api/esm.html
- https://nodejs.org/api/modules.html
- https://nodejs.org/api/cli.html
- https://docs.deno.com/runtime/fundamentals/modules/
- https://docs.deno.com/runtime/fundamentals/configuration/
- https://docs.deno.com/runtime/reference/deno_json/
- https://docs.ruby-lang.org/en/master/Kernel.html
- https://guides.rubygems.org/bundler_in_a_single_file_ruby_script/
- https://perldoc.perl.org/perlvar
- https://perldoc.perl.org/FindBin
- https://www.lua.org/manual/5.4/manual.html
- https://pkg.go.dev/cmd/go
- https://go.dev/ref/mod
- https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#script
- https://doc.rust-lang.org/cargo/commands/cargo-run.html
- https://docs.julialang.org/en/v1/manual/command-line-interface/
- https://mix.hexdocs.pm/Mix.html
- https://gleam.run/documentation/command-line-reference
- https://kotlinlang.org/docs/custom-script-deps-tutorial.html
- https://www.swift.org/getting-started/cli-swiftpm/
- https://dart.dev/tools/dart-run
- https://docs.racket-lang.org/guide/module-paths.html
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables
- https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
- https://github.com/roc-lang/roc/blob/main/docs/langref/modules.md
- https://github.com/roc-lang/roc/blob/main/docs/langref/packages.md
- https://github.com/roc-lang/roc/blob/main/src/build/roc/Builtin.roc
- https://agentskills.io/specification
- https://agentskills.io/skill-creation/using-scripts
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- https://code.claude.com/docs/en/skills

### import の書き方

[ADR 0126](../decisions/0126-import-by-module-name.md) の判断に使った。

| 言語 | 取り込む対象 | 使う側の名前を決める側 | 既定の修飾 | 拡張子と基準 | ファイルが自分の名前を宣言するか |
|---|---|---|---|---|---|
| Python | ドットで区切ったモジュールの名前 | モジュール（`as` は任意） | 修飾する。`from m import x` | 書かない。`sys.path` | しない |
| JavaScript（ESM） | 文字列（相対パス、パッケージ名、`node:`） | 取り込む側（`* as ns`） | `* as ns` は修飾。`{a}` は修飾しない | 相対パスは拡張子が必須。取り込む側から | しない |
| Deno | 相対パス・URL・`jsr:`・`npm:` | 取り込む側 | ESM と同じ | 拡張子は必須 | しない |
| Ruby | パスの文字列 | 名前を束縛しない。ファイルが定数を定義する | — | `require` は拡張子を省ける | モジュールはファイルと独立 |
| Perl | `Foo::Bar`（`Foo/Bar.pm`） | ファイルの `package` の名前 | 修飾する。何を修飾せずに使えるかは取り込まれる側が決める | `@INC` | `package` を宣言する |
| Lua | 文字列のモジュール名 | 取り込む側（`local m = require "a.b"`） | 修飾する | `package.path` | しない |
| Go | import パスの文字列 | `package` の名前。別名は任意 | 修飾する | ディレクトリを指す。相対パスは不可 | `package` を宣言する。パスと一致しなくてよい |
| Rust | `mod` と `use` のパス | `mod` の名前 | 修飾する | `foo.rs` か `foo/mod.rs` | しない |
| Zig | 文字列（ファイルのパスかモジュールの名前） | 取り込む側（必ず `const m = @import(...)`） | 修飾する | 拡張子を書く。取り込む側から | しない |
| Nim | パスのような名前（`std/`・`pkg/`） | ファイル名 | **修飾しない** | 書かない | しない |
| Julia | モジュールの名前。`include` はパス | 宣言した名前 | `using` は修飾しない | `include` は取り込む側から | `module` を宣言する |
| Elixir | モジュールの名前 | `alias` の最後の要素 | 修飾する | — | `defmodule` を宣言する。ファイル名は慣習 |
| Gleam | パスのような名前（`gleam/io`） | 最後の要素。`as` は任意 | 修飾する | `src/` から | しない |
| Elm | モジュールの名前 | 宣言した名前。`as` は任意 | 修飾する | `src/A/B.elm` | `module` を宣言し、パスと一致させる |
| Haskell | モジュールの名前 | モジュールの名前。`as` は任意 | **修飾しない**（修飾も可） | GHC の探索のパス | `module` を宣言する。GHC は一致を求める（`Main` を除く） |
| OCaml | モジュールの名前。import の文はない | ファイル名 | 修飾する。`open` で省ける | 探索のパス | しない |
| F# | 名前空間とモジュールの名前 | 宣言した名前 | 修飾する。`open` で省ける | プロジェクトのファイルの順序 | 宣言する。一致しなくてよい |
| Dart | URI の文字列（`dart:`・`package:`・相対パス） | 取り込む側（`as`） | **修飾しない** | 拡張子を書く | しない |
| Swift | モジュール（ビルドの単位）の名前 | モジュールの名前 | **修飾しない** | ビルドの単位 | しない |
| Racket | 文字列（ファイル）と名前（ライブラリ） | 公開した名前 | **修飾しない** | 文字列は取り込む側から | しない |
| Roc | モジュールの名前。パッケージはヘッダの URL の略称 | パス。`as` は任意 | 修飾する。ワイルドカードは意図して設けない | 書かない | しない |
| Free Pascal | ユニットの名前 | ユニットの名前 | **修飾しない**。名前が重なると `uses` の最後のユニットが勝つ | 探索のパス | `unit` を宣言する |
| Delphi | ユニットの名前（ドットを含められる） | ユニットの名前 | **修飾しない**。最後のユニットが勝つ | 探索のパス。`in 'パス'` はプログラムのファイルでだけ書ける | 宣言し、ファイル名と一致させる |
| Ada | ライブラリの単位の名前 | 単位の名前 | `with` だけなら修飾する。`use` で重なった名前は見えなくなる | 処理系が定める | 宣言する |
| Oberon-07 | モジュールの名前 | 取り込む側の別名は任意（`IMPORT M := M1`） | **常に修飾する** | 定めない | `MODULE M;` を宣言する |

- 対象をパスの文字列で書く言語（JavaScript、Deno、Zig、Ruby、Racket の文字列の形、Dart の相対の形）と、名前で書く言語（Python、Perl、Lua、Rust、Go、Nim、Julia、Elixir、Swift、Gleam、Elm、Haskell、OCaml、F#、Roc、Pascal 系、Ada、Oberon）に分かれる。接頭辞で種類を区別する言語もある（Dart の `dart:`・`package:`、Deno の `jsr:`・`npm:`、Nim の `std/`・`pkg/`）。
- 拡張子を書くのは、パスの文字列で書く言語だけである。
- 修飾しない取り込みで名前が重なったとき、Pascal・Delphi・F# の `open` は後の名前が黙って勝ち、Ada は見えなくなり、Racket・Julia・Nim は誤りにする。
- Gleam・Elm・Elixir・OCaml の文書は、修飾して使うことを勧める。

【要検証】

- PHP の `use` がファイルを読まないこと。
- Perl のパッケージ名とファイル名の一致が強制されないこと。
- Free Pascal が `unit Foo;` とファイル名の一致を求めるか。Delphi の `in` の相対パスの基準。
- Elm がパスと一致しないモジュールの名前を誤りにするか。
- Dart の相対の URI が、取り込む側のライブラリを基準にすること。
- Swift に取り込みの別名がないこと。
- Roc の手元の取り込みの基準のディレクトリと、標準ライブラリの取り込み方。
- Ada の `package X renames Y` による別名。

出典

- https://docs.python.org/3/reference/import.html
- https://nodejs.org/api/esm.html
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import
- https://docs.deno.com/runtime/fundamentals/modules/
- https://ruby-doc.org/3.4.1/Kernel.html
- https://perldoc.perl.org/perlmod
- https://www.lua.org/manual/5.4/manual.html
- https://go.dev/ref/spec#Import_declarations
- https://doc.rust-lang.org/reference/items/modules.html
- https://ziglang.org/documentation/master/#import
- https://nim-lang.org/docs/manual.html#modules
- https://docs.julialang.org/en/v1/manual/modules/
- https://hexdocs.pm/elixir/alias-require-and-import.html
- https://tour.gleam.run/basics/modules/
- https://guide.elm-lang.org/webapps/modules.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch5.html
- https://downloads.haskell.org/ghc/latest/docs/users_guide/separate_compilation.html
- https://ocaml.org/manual/latest/compunit.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/import-declarations-the-open-keyword
- https://dart.dev/language/libraries
- https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/Declarations.md
- https://docs.racket-lang.org/reference/require.html
- https://www.roc-lang.org/faq
- https://www.freepascal.org/docs-html/current/ref/refse111.html
- https://www.learndelphi.org/wp-content/uploads/2020/03/DelphiLanguageGuide-10.3-Rio-CreativeCommons-LearnDelphi.org_.pdf
- https://www.adaic.org/resources/add_content/standards/22rm/html/RM-8-4.html
- https://people.inf.ethz.ch/wirth/Oberon/Oberon07.Report.pdf

### 組み込みのエフェクトの名前

[ADR 0129](../decisions/0129-effects-declared-in-modules.md) と [ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md) の判断に使った。

| 言語 | 組み込みのエフェクトの名前の定義 | 処理系の照合の仕方 | 特別な扱い | 注釈の書き方 |
|---|---|---|---|---|
| Haskell（GHC） | `IO` は内部ライブラリの普通の newtype（中身は基本の型 `State# RealWorld`）。予約語ではない | 内部の識別子（known-key） | `main` は `IO τ` でなければならない（仕様書 5 章） | 普通の型 `IO a` |
| PureScript | `Effect` は別パッケージの型 | 最適化のためだけにモジュール `Effect` を名指しする | 型検査は `main` の型を強制しない。`main :: Effect Unit` は道具の慣習 | 普通の型 |
| Idris 2 | `IO` は prelude の普通のデータ型（基本の型は `%World`）。キーワードではない | — | 入口を `unsafePerformIO main` として展開するので、`main` は `IO a` | 普通の型 |
| Lean 4 | `IO` は標準ライブラリの普通の定義（`abbrev IO := EIO Error`） | 根の定数 `IO` | `main` の型を `IO Unit` などに限る | 普通の型 |
| Koka | `div`・`ndet`・`console`・`exn`・`io` などを標準ライブラリで宣言する。予約語は `effect`・`handle` など宣言の語 | 修飾名（`std/core/types/div` など） | 再帰する関数に `div` を付ける。`io = <exn, ioc>` などは普通の `alias`。`main` に残ったエフェクトに既定のハンドラを差し込む | エフェクトの行 `<a,b\|e>` |
| Flix | `IO`・`Chan`・`NonDet` を prelude で `pub eff` として宣言する。`Console` などは操作を持つ普通のエフェクト | 根の名前空間の記号 | 基本のエフェクトはハンドラで処理できない。入口には基本のエフェクトと既定のハンドラを持つエフェクトだけを書ける | `\ IO` の形の式 |
| OCaml 5 | 組み込みの名前はない。エフェクトは `Effect.t` を拡張した構成子。`effect` は 5.3 からキーワード | — | 型付けはない。処理しないエフェクトは実行時の例外 | なし |
| Unison | `IO` は実行時の組み込み。`Exception` はハッシュで識別する組み込みの宣言 | ハッシュ | `run` で起動する関数は `{IO, Exception}` に収まらなければならない | `{IO, Exception}` |
| Roc | 名前の付いたエフェクトはない。IO はプラットフォームが提供する | — | 入口はヘッダの `app [main!]` | 純粋なら `->`、作用があれば `=>` |
| F\* | `Tot`・`GTot` は Prims で、`Div`・`ML` などは標準ライブラリで宣言する。予約語は `effect` など宣言の語 | 修飾名 | Prims 自体を検査するときだけ `Tot`・`GTot` を名前で扱う | 計算の型 `Tot int` |

- エフェクトの名前をキーワードや文法の規則にした言語はない。予約語は、エフェクトを宣言する語（Koka と F\* の `effect`、Flix の `eff`、OCaml の `effect`）だけである。
- 名前は prelude や標準ライブラリで宣言し、処理系は綴りではなく、修飾名・内部の識別子・ハッシュで照合する。
- 特別な扱いは、入口の型、ハンドラで処理できない基本のエフェクト、推論の規則に集まる。複数のエフェクトをまとめた名前は、ライブラリの普通の別名である（Koka の `io`、F\* の `ML`）。

【要検証】

- 利用者が同じ名前のエフェクトや型を定義したときの、GHC・Koka・Flix・F\*・Idris 2 の振る舞い（修飾名と内部の識別子での照合からの推定で、試していない）。
- Roc の処理系が `!` の付け方を検査するか。
- Eff・Frank・Scala 3・ZIO は調べていない。

出典

- https://www.haskell.org/onlinereport/haskell2010/haskellch2.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch5.html
- https://github.com/ghc/ghc/blob/master/libraries/ghc-internal/src/GHC/Internal/Types.hs
- https://github.com/ghc/ghc/blob/master/compiler/GHC/Tc/Module.hs
- https://github.com/purescript/purescript-effect/blob/master/src/Effect.purs
- https://github.com/purescript/spago/blob/master/README.md
- https://github.com/idris-lang/Idris2/blob/main/libs/prelude/PrimIO.idr
- https://github.com/leanprover/lean4/blob/master/src/Init/System/IO.lean
- https://github.com/leanprover/lean4/blob/master/src/Lean/Compiler/LCNF/Main.lean
- https://github.com/koka-lang/koka/blob/dev/lib/std/core.kk
- https://github.com/koka-lang/koka/blob/dev/lib/std/core/types.kk
- https://github.com/koka-lang/koka/blob/dev/src/Syntax/Lexer.x
- https://github.com/flix/flix/blob/master/main/src/library/Prelude.flix
- https://github.com/flix/flix/blob/master/main/src/ca/uwaterloo/flix/language/phase/Safety.scala
- https://github.com/ocaml/ocaml/blob/trunk/stdlib/effect.mli
- https://github.com/unisonweb/unison/blob/trunk/parser-typechecker/src/Unison/Builtin.hs
- https://github.com/unisonweb/unison/blob/trunk/parser-typechecker/src/Unison/Codebase/MainTerm.hs
- https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md
- https://github.com/FStarLang/FStar/blob/master/ulib/Prims.fst
- https://github.com/FStarLang/FStar/blob/master/src/parser/FStarC.Parser.Const.fst

### prelude と標準ライブラリ

[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md) の判断に使った。

| 言語 | import なしで使えるもの | IO を含むか | import が要るものと範囲 | 根の名前 | prelude を外す手段 |
|---|---|---|---|---|---|
| Haskell | `Prelude` の修飾しない名前 | コンソールもファイルも含む | `Data.List` など。`Data.Map` は別パッケージ | `Data.`・`Control.`・`System.` | `NoImplicitPrelude` |
| Elm | `Basics`・`List`・`Maybe`・`Result`・`String` などのモジュール | 含まない | `Dict`・`Set` など。最小限 | 平ら | 【要検証】 |
| Gleam | 型と構成子だけ。関数はない | 含まない | すべての関数（`gleam/list` など）。標準ライブラリは別のパッケージで、版を持つ | `gleam/` | 標準ライブラリは使わなくてよい |
| Roc | 組み込みのモジュール（例から推定） | 含まない（プラットフォームが提供） | プラットフォームとパッケージ | 平ら | 【要検証】 |
| OCaml | `Stdlib` を自動で開く。`List.map` のように修飾して使う | コンソールもファイルも含む | 約 70 のモジュール | `Stdlib.` | `-nopervasives`・`-nostdlib` |
| F# | `FSharp.Core` などを自動で開く | コンソール（printf）だけ | .NET のライブラリ | `FSharp.` | 【要検証】 |
| Rust | 型・トレイトなどの修飾しない名前。`std::` は完全な名前で使える | マクロだけ | `std::collections`・`std::fs` など。正規表現・JSON・HTTP は含めない | `core`・`alloc`・`std` | `no_implicit_prelude`、`no_std` |
| PureScript | 何もない | — | prelude も別のパッケージ | `Data.`・`Control.` | — |
| Idris 2 | `Prelude` | コンソールだけ | base・contrib | Haskell に近い | `--no-prelude` |
| Lean 4 | `Init` | コンソールもファイルも含む | `Std`（HTTP・非同期を含む）、Batteries | `Std.` | `prelude` の語（処理系の実装用） |
| Koka | `std/core` の名前 | コンソールだけ | `std/os/file` など | `std/` | 【要検証】 |
| Flix | 小さな Prelude。`List.map` などは修飾して使える（明文は【要検証】） | コンソールだけ | 小さいが一通りそろう | 平ら | 標準ライブラリを差し替えられる |
| Elixir | `Kernel`。すべてのモジュールを完全な名前で使える | `IO.puts`・`File.*`（import 不要） | 何でもそろう（1.18 から `JSON`） | `Elixir.` | `import Kernel, except:` |
| Scala 3 | `java.lang._`・`scala._`・`Predef._` | コンソールだけ | JVM のライブラリ | `scala.` | `-Yno-imports`・`-Yno-predef` |
| Clojure | `clojure.core` | コンソールもファイルも含む | `clojure.string` など。JSON は含めない | `clojure.` | `:refer-clojure :exclude` |
| Unison | import の段がない。`base` をプロジェクトに入れ、名前の末尾で引く | 【要検証】 | ライブラリを導入する | `base.` | 【要検証】 |

- 小さな prelude と、import する標準ライブラリを組み合わせる言語が多い（Haskell、Rust、Idris、Koka、Gleam、Elm、Flix）。Rust は「ほとんどすべてのプログラムが使うものに限り、できるだけ小さく保つ」、Flix は「非常によく使うものだけを入れる」と書く。
- 標準ライブラリを使う形は、修飾して使うときにも import を要する形（Haskell、Gleam、Idris、Koka、Clojure、Lean）と、import なしに完全な名前で使える形（OCaml、F#、Elixir、Scala、Rust の `std::`、Roc、Flix）に分かれる。
- 根の名前を予約する言語が多い。OCaml は標準ライブラリを `Stdlib` の下にまとめ直し、その理由を、利用者やほかのライブラリのために大域の名前空間を空けることとしている。`Stdlib.List`、`Elixir.List`、Rust の `::std` は、名前が重なったときの抜け道になる。
- prelude かどうかは、実装の言語ではなく、import なしで使えるかで決まる。Rust の prelude は、Rust で書いた標準ライブラリの一部である。

【要検証】

- Haskell の base が GHC の版に結び付くこと。
- Elm の elm/json・elm/http が別のパッケージであること。
- Gleam の `gleam/` の名前が利用者のモジュールに対して予約されているか。
- Roc の組み込みを import なしで使えるという明文の規則。
- 利用者のモジュールが標準ライブラリと同じ名前を持つときの、OCaml・Elm・Elixir・Koka・Flix の振る舞い。
- Flix の標準ライブラリの名前空間を import なしで修飾して使えるという明文の規則。

出典

- https://www.haskell.org/onlinereport/haskell2010/haskellch5.html
- https://github.com/elm/core/blob/master/README.md
- https://github.com/gleam-lang/gleam/blob/main/compiler-core/src/type_/prelude.rs
- https://tour.gleam.run/everything/
- https://github.com/gleam-lang/stdlib/blob/main/gleam.toml
- https://www.roc-lang.org/builtins
- https://ocaml.org/manual/5.3/stdlib.html
- https://github.com/ocaml/ocaml/blob/trunk/Changes
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/import-declarations-the-open-keyword
- https://doc.rust-lang.org/std/prelude/index.html
- https://doc.rust-lang.org/reference/names/preludes.html
- https://github.com/purescript/documentation/blob/master/language/Differences-from-Haskell.md
- https://github.com/idris-lang/Idris2/blob/main/src/Idris/CommandLine.idr
- https://lean-lang.org/doc/reference/latest/Source-Files-and-Modules/
- https://github.com/koka-lang/koka/blob/dev/lib/std/core.kk
- https://flix.dev/principles/
- https://elixir.hexdocs.pm/Kernel.html
- https://www.scala-lang.org/files/archive/spec/3.4/09-top-level-definitions.html
- https://clojure.org/reference/namespaces
- https://www.unison-lang.org/docs/language-reference/name-resolution-and-the-environment/

### 等値と順序の制約

[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md) の判断に使った。

| 言語 | 等値の制約の書き方 | 順序の制約の書き方 | 制約を満たす方法 | 関数の型の扱い | 等値を独自に定められるか |
|---|---|---|---|---|---|
| SML'97 | 等値型変数 `''a`、`eqtype` | なし（順序は型ごとの関数） | 型の構造から自動で満たす。datatype の等値は推論する | 静的に除く。`real` も等値を許さない | できない（`=` は再束縛できない） |
| OCaml | なし（`=` は `'a -> 'a -> bool`） | なし（`compare : 'a -> 'a -> int`） | 常に構造で比べる | 実行時に `Invalid_argument` | `Map.Make` に `compare` を渡す |
| Elm | なし（`==` は `a -> a -> Bool`） | 名前が `comparable` で始まる型変数 | 組み込みの型とそのリスト・タプルに限る。独自の型とレコードは comparable ではない | `==` は実行時に落ちる。comparable は静的に判定する | できない |
| F# | `when 'T : equality` | `when 'T : comparison` | 型の構造から自動で満たす。型引数への依存も推論する。属性で変えられる | 静的に除く（関数の型は equality を満たさない） | `[<CustomEquality>]`・`[<CustomComparison>]` |
| Go | `[K comparable]` | `[T cmp.Ordered]` | 型の構造から自動で満たす | 静的に除く（interface の鍵は実行時に panic） | できない |
| Haskell | `Eq a =>` | `Ord a =>` | 明示の `deriving`。構成要素に実装を要する | インスタンスがなく、静的に誤り | instance を手で書く |
| Roc（現行） | メソッドの制約 `where [a.is_eq : a, a -> Bool]` | `is_lt` などのメソッドの制約 | 構造の型は自動で得る。名前の付いた型は `is_eq : _` で選ぶ。順序は導出しない | 関数は等値を持たない（検査の時点は文書に書かれていない） | メソッドの本体を書く |
| Gleam | なし（どの型でも `==`） | なし（比べる関数を渡す） | 常に構造で比べる | 除かない | できない |
| Flix | `with Eq[t]` | `with Order[t]` | 明示の `with Eq, Order` で導出する | 【要検証】 | instance を書く |
| Swift | `T: Equatable` | `T: Comparable` | 準拠を宣言すると合成する（Comparable の合成は enum だけ） | 関数の型は準拠しない（【要検証】） | `==` を書く |
| Rust | `T: PartialEq`・`Eq` | `T: PartialOrd`・`Ord` | 明示の `#[derive]` | 関数ポインタは `Eq`・`Ord` を実装する（比較は信頼できないと文書が注記する） | impl を書く |
| Koka | 暗黙の引数 `?(==)` | 暗黙の引数 `?cmp` | 名前で静的に解決する | 【要検証】 | 同じ名前の関数を定義する |

- SML'97 の初期基底で等値を許さない型は `real` と `exn` である。§G.21 は「real is no longer an equality type」と書く。datatype は「as many of these new names as possible admit equality」の規則で等値を推論する。
- F# の `=`・`compare`・`hash` は、型クラスではなく `equality`・`comparison` の制約で型付けされる（`(=) : 'T -> 'T -> bool (requires equality)`）。`Map` と `Set` は鍵に `comparison` を求める。F# の設計者は、関数の型を「no equality」とし、`id = id` を静的な誤りにすると説明する。
- Elm の comparable は、`String`・`Char`・`Int`・`Float` と、comparable の値を含むリスト・タプルに限る。`Dict` の鍵と `Set` の要素にもこれを求める。制約付きの型変数は `number`・`appendable`・`comparable`・`compappend` の四つに固定されている。コンパイラは型変数の名前の接頭辞で制約を判定する。
- Go の `comparable` は Go 1.18 で、`cmp.Ordered` は Go 1.21 の `cmp` パッケージで加わった。マップの鍵の型は、関数・マップ・スライスであってはならない。
- Haskell の導出した `Ord` は、宣言で前に書いた構成子を小さいとし、辞書式に比べる。Rust の導出した `PartialOrd` も、enum は判別子（既定では宣言の順）、struct はメンバの宣言の順に辞書式に比べる。Swift の enum の `Comparable` の合成も宣言の順に比べる。
- Rust の `f64` は `PartialEq`・`PartialOrd` だけを実装し、`Eq`・`Ord`・`Hash` を実装しない。`BTreeMap` の鍵は `Ord` を要する。
- Roc の現行の文書は、abilities（`implements`）の代わりにメソッドと `where` 節を説明する。`Dict` の鍵は `is_eq` と `to_hash` を要する。導出できるのは `is_eq`・`to_hash`・`parser_for`・`encoder_for`・`map`・`map!` である。
- Koka は型クラスを持たず、暗黙の引数を名前で解決する（v3.2.3 の「No more qualified types but we use instead implicit phantom parameters」）。
- 傾向は四つに分かれる。構造で比べる等値を常に許す言語（OCaml、Elm の `==`、Gleam）は、関数を静的に除かない。専用の組み込みの制約を持つ言語（SML、F#、Go、Elm の comparable）は、型の構造から自動で満たし、関数を静的に除く。このうち等値を利用者が変えられるのは F# だけである。型クラスの言語（Haskell、Rust、Swift、Flix）は、明示の導出か準拠の宣言を要する。Roc の現行版は、構造の型では自動、名前の付いた型では明示である。

【要検証】

- Roc の旧版の abilities（`Eq`・`Hash`・`Inspect`、`where a implements Eq`）の仕様の全体。
- Roc で関数の等値を静的に除くか。
- Gleam の `==` に関数を渡したときの公式の説明と、Erlang の出力での振る舞い（JavaScript の出力では参照が同じときだけ等しい）。
- Flix の導出した `Order` が宣言の順に比べるか。Flix で関数が `Eq` を持たないか。
- Swift で関数の型が `Equatable` に準拠しないこと。
- Rust のクロージャの型が `PartialEq` などを実装しないこと。
- Koka に利用者の型の `==`・`cmp` を導出する仕組みがあるか。

出典

- https://smlfamily.github.io/sml97-defn.pdf
- https://ocaml.org/manual/5.2/api/Stdlib.html
- https://ocaml.org/manual/5.2/api/Map.OrderedType.html
- https://raw.githubusercontent.com/elm/core/master/src/Basics.elm
- https://raw.githubusercontent.com/elm/core/master/src/Dict.elm
- https://raw.githubusercontent.com/evancz/guide.elm-lang.org/master/book/types/reading_types.md
- https://raw.githubusercontent.com/elm/compiler/master/compiler/src/Data/Name.hs
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/generics/constraints
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/records
- https://fsharp.github.io/fsharp-core-docs/reference/fsharp-core-operators.html
- https://fsharp.github.io/fsharp-core-docs/reference/fsharp-core-noequalityattribute.html
- https://learn.microsoft.com/en-us/archive/blogs/dsyme/equality-and-comparison-constraints-in-f
- https://go.dev/ref/spec
- https://pkg.go.dev/cmp
- https://go.dev/doc/go1.21
- https://www.haskell.org/onlinereport/haskell2010/haskellch6.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch11.html
- https://hackage-content.haskell.org/package/containers-0.8/docs/Data-Map-Strict.html
- https://github.com/roc-lang/roc/tree/main/docs/langref
- https://tour.gleam.run/everything/
- https://raw.githubusercontent.com/gleam-lang/gleam/main/compiler-core/templates/prelude.mjs
- https://doc.flix.dev/traits.html
- https://doc.flix.dev/automatic-derivation.html
- https://api.flix.dev/Map.html
- https://github.com/swiftlang/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md
- https://github.com/swiftlang/swift-evolution/blob/main/proposals/0266-synthesized-comparable-for-enumerations.md
- https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/Protocols.md
- https://doc.rust-lang.org/std/cmp/trait.PartialOrd.html
- https://doc.rust-lang.org/std/primitive.f64.html
- https://doc.rust-lang.org/std/collections/struct.BTreeMap.html
- https://doc.rust-lang.org/std/primitive.fn.html
- https://koka-lang.github.io/koka/doc/book.html
- https://raw.githubusercontent.com/koka-lang/koka/master/lib/std/core/list.kk

### 標準の型クラス

[ADR 0134](../decisions/0134-standard-type-classes.md) の判断に使った。表の `A ⊂ B` は、A が B の上位の型クラスであることを表す。

| 言語 | 文字列への変換 | 等値・順序 | 連結 | map・連鎖の抽象 | 畳み込み | ハッシュ | 数 | 導出 | 戻り値の型で実装を選ぶメソッド |
|---|---|---|---|---|---|---|---|---|---|
| Haskell 2010 | `Show`（と `Read`） | `Eq` ⊂ `Ord` | なし | `Functor`、`Monad`（互いに独立） | なし | なし | `Num` ⊂ `Real` ⊂ `Integral` など | `deriving`（`Eq`・`Ord`・`Enum`・`Bounded`・`Show`・`Read`） | `return`・`minBound`・`fromInteger`・`toEnum`・`read`・`pi` |
| GHC の base の Prelude | `Show`、`Read` | `Eq` ⊂ `Ord` | `Semigroup` ⊂ `Monoid` | `Functor` ⊂ `Applicative` ⊂ `Monad`、`MonadFail` | `Foldable`、`Traversable` | なし | Report と同じ | `deriving` と拡張（`DeriveFunctor` など） | 上に加えて `pure`・`mempty` |
| PureScript | `Show` | `Eq` ⊂ `Ord` ⊂ `Bounded` | `Semigroup` ⊂ `Monoid` | `Functor` ⊂ `Apply` ⊂ `Applicative`、`Apply` ⊂ `Bind`、`Monad` | 別のパッケージ | なし | `Semiring` ⊂ `Ring` など | `derive instance`（`Show` は `Generic` 経由） | `pure`・`mempty`・`top`・`bottom`・`zero`・`one` |
| Flix | `ToString`（文字列補間が使う） | `Eq` ⊂ `Order` | `SemiGroup` ⊂ `Monoid` | `Functor` ⊂ `Applicative` ⊂ `Monad` | `Foldable`、`Traversable` | `Hash` | `Add`・`Sub`・`Mul`・`Div`・`Neg` | `enum T with Eq, Order, ToString, Hash, Coerce` | `point`・`empty`・`minValue`・`maxValue`・`fromString` |
| Lean 4 | `ToString`、`Repr` | `BEq`・`Ord`・`LT` は互いに独立 | `Append` だけ | `Functor` ⊂ `Applicative` ⊂ `Monad` | なし | `Hashable` | `Add` など、`OfNat` | `deriving`（`ToString` は導出できない） | `pure`・`default`・`OfNat.ofNat`・`zero`・`one` |
| Idris 2 | `Show` | `Eq` ⊂ `Ord` | `Semigroup` ⊂ `Monoid` | `Functor` ⊂ `Applicative` ⊂ `Monad` | `Foldable`、`Traversable` | なし | `Num` ⊂ `Neg` など | `%runElab derive`（`Functor`・`Foldable`・`Traversable`・`Show`） | `pure`・`neutral`・`fromInteger` |
| Scala 3 | なし（`toString` は `Object` のメソッド） | `Ordering`、`CanEqual` | なし | なし（cats は別のライブラリ） | なし | なし | `Numeric` | `derives`（標準では `CanEqual`） | 求める型の暗黙の実装で選ぶ（`zero`・`one`） |

- 既定の実装は、Haskell・Flix・Lean・Idris が持つ。Haskell は各型クラスに最小の定義を注記する（`Eq` は `==` か `/=`、`Monad` は `>>=` と `return`）。PureScript は既定の実装を持たず（「it is not possible to declare default member implementations」）、型クラスを小さく保ち、派生の操作を普通の関数にする。
- `Applicative` か `Monoid` を置く言語は、どれも `pure`・`mempty` のように戻り値の型だけで実装を選ぶメソッドを持つ。Flix は、型クラスの引数を戻り値の型だけに含むメソッドを許す（「every signature must mention that type parameter」）。
- 演算子は、Haskell・Idris・PureScript では型クラスのメソッドである。Flix と Lean は、演算子を一つのメソッドの型クラスに脱糖する（Flix の `+` は `Add.add`、`<` は `Order.less`、`==` は `Eq.eq`。Lean の `+` は `HAdd.hAdd`、`==` は `BEq.beq`）。
- Lean を除くどの言語も、`Eq` を `Ord` の上位の型クラスにする。
- Lean 4 の核は `Semigroup`・`Monoid`・`Foldable`・`Traversable` を持たない。Scala 3 の標準ライブラリは `Functor`・`Monad`・`Semigroup`・`Monoid` を持たない。

【要検証】

- GHC の `{-# MINIMAL #-}` の定義（`Foldable` は `foldMap` か `foldr` など）と、`Applicative`・`Foldable`・`Traversable`・`Semigroup`・`MonadFail` が Prelude に入った base の版。
- Lean 4 の `Semigroup`・`Monoid` が Batteries と Mathlib にあること。
- Scala 3 の標準ライブラリが `derives Ordering` を扱わないこと。

出典

- https://www.haskell.org/onlinereport/haskell2010/haskellch6.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch9.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch11.html
- https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Prelude.html
- https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/deriving_extra.html
- https://github.com/purescript/purescript-prelude/blob/master/src/Prelude.purs
- https://github.com/purescript/documentation/blob/master/language/Type-Classes.md
- https://github.com/purescript/documentation/blob/master/language/Differences-from-Haskell.md
- https://doc.flix.dev/
- https://github.com/flix/book
- https://github.com/flix/flix/tree/master/main/src/library
- https://api.flix.dev/
- https://github.com/leanprover/lean4
- https://github.com/idris-lang/Idris2
- https://idris2.readthedocs.io/en/latest/tutorial/interfaces.html
- https://www.scala-lang.org/api/current/scala/math/Ordering.html
- https://www.scala-lang.org/api/current/scala/math/Numeric.html
- https://docs.scala-lang.org/scala3/reference/contextual/derivation.html

### シェバン

[ADR 0135](../decisions/0135-shebang-line-and-implicit-run.md) の判断に使った。

OS の扱いは次のとおりである。

| OS | シェバンの行の引数 | 行の長さの上限 | `#!` の位置 |
|---|---|---|---|
| Linux | インタプリタの名前より後を、空白で分けずに一つの引数として渡す | 255 文字（Linux 5.1 より前は 127 文字） | ファイルの 0 バイト目 |
| macOS（XNU） | 空白で分けて、別々の引数として渡す。`#` から行末までを除く | 512 バイト | ファイルの 0 バイト目 |
| FreeBSD | 分けずに一つの引数として渡す | ページの大きさ | ファイルの 0 バイト目 |
| Windows | OS は解釈しない。Python のランチャー（`py.exe`）は自分でシェバンの行を読む | — | — |

- Linux の man ページは、移植性のためには引数を書かないか、一語だけにするよう書く。
- 空白で分けて渡す `env -S` は、GNU coreutils 8.30（2018 年）、FreeBSD 6.0 で加わった。現在の macOS の `env` も `-S` を持つ。BusyBox の `env` は `-S` を持たない。
- Linux と XNU のカーネルは 0 バイト目と 1 バイト目が `#!` であることを調べるので、先頭に UTF-8 の BOM があるファイルはシェバンとして実行されない。

各言語の扱いは次のとおりである。

| 言語 | シェバンの扱い | 書けるファイルと位置 | シェバンから起動する書き方 | サブコマンド |
|---|---|---|---|---|
| ECMAScript（ES2023）・Node | 専用の字句規則（Hashbang Comment） | Script と Module の先頭 | `env node` | 不要 |
| Deno | ECMAScript と同じ | 先頭 | `env -S deno run` | `run` は省ける（`deno main.ts`） |
| Bun | ECMAScript と同じ | 先頭 | 【要検証】 | 不要（`bun file`） |
| Rust | 専用の字句規則。`#!` の後に `[` が続くもの（内部属性）は除く | どのファイルでも、先頭か BOM の直後 | （rustc の範囲外） | — |
| Python | 普通のコメント | 任意の行 | `env python3` | 不要 |
| Ruby | コメント。主スクリプトの 1 行目の `ruby` を含む行のスイッチを解釈する | 1 行目 | `env ruby` | 不要 |
| Perl | 行のスイッチを解釈する。`perl` を含まない行なら、書かれたプログラムを起動する | 1 行目 | `/usr/bin/perl -w` など | 不要 |
| Lua | `#` で始まる 1 行目を読み飛ばす。BOM の後でもよい | 読み込むすべてのファイル | `env lua` | 不要 |
| Julia・Elixir・Roc | 普通の `#` のコメント | 任意の行 | `env -S julia …`・`env elixir`・`env -S roc --` | 不要 |
| Haskell（GHC） | `#!` で始まる行を空白として扱う | 任意の行 | 【要検証】 | — |
| OCaml | スクリプトモードで、`#!` で始まる 1 行目を読み飛ばす | 主スクリプトの 1 行目 | `ocamlrun …/ocaml` | 不要 |
| Swift | 専用の字句規則 | 主ファイルの先頭だけ。ほかのファイルでは誤り | `/usr/bin/swift` | 不要 |
| Kotlin | 文法の `shebangLine` | ファイルの先頭 | `env kotlin`（`.main.kts`） | 不要 |
| Dart | 文法の `scriptTag` | どのライブラリの先頭でも。空白やコメントより前 | `env dart` | 不要（公式は `dart run` を勧める） |
| Go | 対応しない。提案は何度も却下された | — | 非公式の `//usr/bin/env go run` | — |
| Scala（scala-cli） | 専用のサブコマンド `shebang` | 先頭 | `env -S scala-cli shebang` | 必要 |
| uv（Python） | 普通のコメント | 先頭 | `env -S uv run --script` | 必要 |
| F# | 公式の文書が `#!` の実行を案内する | 先頭 | `env -S dotnet fsi` | 必要 |
| Gleam | 対応しない（`#` は字句 `Hash`） | — | — | — |

- 確かめた実装（Rust、Swift、Lua、Ruby）は、シェバンの行の改行を残すか補い、行の番号を 1 行目から数える。
- Rust・Swift・Lua の字句解析器は、BOM の後のシェバンの行を受け付ける。
- Deno・Bun・Dart のように `<コマンド> <ファイル>` で実行できる処理系は、`env -S` なしの一語のシェバンで起動できる。サブコマンドやオプションを書く処理系（scala-cli、uv、F#、Julia）は、`env -S` を使う形を案内する。
- Roc は、`#!/usr/bin/env roc` ではスクリプトの引数が `roc` 自身の引数として解釈されるので、`env -S roc --` で回避している。`roc fmt` がシェバンの行を壊さないようにする修正も入っている。

【要検証】

- macOS の `env` に `-S` が加わった版（Julia の FAQ は macOS Sierra とするが、Apple の一次資料では確かめていない）。Julia の FAQ は、macOS のカーネルもシェバンの行を分けないと書くが、XNU のソースは分けている。本節は XNU のソースに従った。
- Bun の公式の文書のシェバンの例。
- Deno のシェバンの行で権限のフラグ（`--allow-env` など）を渡す例（公式の文書の本文で確かめていない）。
- runghc をシェバンで使う書き方（慣習であり、公式の文書に記述がない）。
- Node.js が Hashbang に対応した版。
- F# の字句規則の中での `#!` の扱い。

出典

- https://man7.org/linux/man-pages/man2/execve.2.html
- https://github.com/torvalds/linux/blob/master/fs/binfmt_script.c
- https://github.com/torvalds/linux/blob/master/include/uapi/linux/binfmts.h
- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_exec.c
- https://man.freebsd.org/cgi/man.cgi?query=execve&sektion=2
- https://git.savannah.gnu.org/cgit/coreutils.git/plain/NEWS
- https://www.gnu.org/software/coreutils/manual/html_node/env-invocation.html
- https://man.freebsd.org/cgi/man.cgi?query=env&sektion=1
- https://github.com/apple-oss-distributions/shell_cmds/blob/main/env/env.c
- https://github.com/mirror/busybox/blob/master/coreutils/env.c
- https://docs.python.org/3/using/windows.html
- https://tc39.es/ecma262/#sec-hashbang
- https://doc.rust-lang.org/reference/shebang.html
- https://github.com/rust-lang/rust/blob/master/compiler/rustc_lexer/src/lib.rs
- https://docs.deno.com/examples/hashbang_tutorial/
- https://docs.deno.com/runtime/reference/cli/run/
- https://bun.com/docs/runtime
- https://docs.python.org/3/reference/lexical_analysis.html
- https://github.com/ruby/ruby/blob/master/ruby.c
- https://perldoc.perl.org/perlrun
- https://www.lua.org/manual/5.4/manual.html
- https://www.lua.org/source/5.4/lauxlib.c.html
- https://docs.julialang.org/en/v1/manual/faq/
- https://github.com/elixir-lang/elixir/blob/main/lib/elixir/src/elixir_tokenizer.erl
- https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/whitespace.html
- https://ocaml.org/manual/5.3/toplevel.html
- https://github.com/swiftlang/swift/blob/main/lib/Parse/Lexer.cpp
- https://kotlinlang.org/spec/syntax-and-grammar.html
- https://github.com/Kotlin/kotlin-script-examples/blob/master/jvm/main-kts/MainKts.md
- https://github.com/dart-lang/language/blob/main/specification/dartLangSpec.tex
- https://dart.dev/tools/dart-tool
- https://github.com/golang/go/issues/24118
- https://scala-cli.virtuslab.org/docs/guides/scripting/shebang/
- https://docs.astral.sh/uv/guides/scripts/
- https://learn.microsoft.com/en-us/dotnet/fsharp/tools/fsharp-interactive/
- https://github.com/roc-lang/roc/issues/7405
- https://github.com/gleam-lang/gleam/blob/main/compiler-core/src/parse/lexer.rs

### Map と Set の値の書き方

[ADR 0136](../decisions/0136-map-and-set-in-constants.md) の判断に使った。

| 言語 | マップのリテラル | 集合のリテラル | 関数で作る形 | 同じ鍵を重ねたとき | 定数にできるか | 空の値 |
|---|---|---|---|---|---|---|
| Haskell | なし（OverloadedLists 拡張で `[(k, v)] :: Map` と書ける） | なし（同左） | `Map.fromList`・`Set.fromList` | 後の値 | トップレベルの値（遅延して計算） | `Map.empty` |
| Elm | なし | なし | `Dict.fromList`・`Set.fromList` | 後の値（ソースによる） | トップレベルの値 | `Dict.empty` |
| OCaml | なし | なし | `M.of_list`（5.1）・`M.of_seq` | 後の値 | トップレベルの `let` だけ | `M.empty` |
| F# | なし | なし | `Map [...]`・`Map.ofList`・`set [...]` | 後の値（`add` による） | `[<Literal>]` は基本型と文字列だけ | `Map.empty` |
| Gleam | なし | なし | `dict.from_list`・`set.from_list` | 後の値 | できない（`const` はリテラルに限る） | `dict.new()` |
| Roc | なし | なし | `Dict.from_list` | 【要検証】 | 【要検証】 | `Dict.empty` |
| Elixir | `%{k => v}`・`%{a: 1}` | なし（`MapSet.new`） | — | 後の値。コンパイラが警告する | モジュールの属性（コンパイル時の値） | `%{}` |
| Clojure | `{:a 1}` | `#{1 2}` | `hash-map`・`hash-set` | リテラルは誤り（鍵がすべて定数ならコンパイル時）。関数は後の値 | `def` | `{}`・`#{}` |
| Scala 3 | なし（`Map("a" -> 1)`） | なし（`Set(1, 2)`） | `Map(...)`・`Set(...)` | 【要検証】 | できない | `Map()` |
| Kotlin | なし | 実験中（2.4 の `[1, 2]` を `Set` の型で受ける） | `mapOf("a" to 1)`・`setOf` | 後の値。指定した順に反復する | できない（`const val` は文字列と基本型だけ） | `mapOf()` |
| Swift | `["a": 1]` | 配列のリテラルに `Set` の型注釈 | `Dictionary(uniqueKeysWithValues:)` | 実行時に停止する。リテラルの鍵が重なるとコンパイラが警告する | 大域の `let` | `[:]`・`[]` |
| Python | `{"a": 1}` | `{1, 2}` | `dict(...)`・`set(...)` | 後の値 | 定数の仕組みがない | `{}` は辞書、空の集合は `set()` |
| JavaScript | オブジェクト `{x: 1}`（鍵は文字列） | なし | `new Map([[k, v]])`・`new Set([...])` | 後の値 | 束縛だけが定数 | `new Map()` |
| Rust | なし | なし | `HashMap::from([(k, v)])`・`BTreeMap::from` | 一つを残し、ほかを捨てる（どれを残すかは定めない） | 空のものだけ（`BTreeMap::new` は const fn） | `HashMap::new()` |
| Go | `map[K]V{k: v}` | なし | — | 定数の鍵が重なると誤り | できない（package の `var`） | `map[K]V{}` |
| Dart | `{'a': 1}` | `{1, 2}` | `Map.fromEntries` など | `const` のマップでは誤り。ほかは警告して後の値 | できる（`const {...}`） | `{}` は Map、空の集合は `<T>{}` |
| Julia | なし（`Dict("a" => 1)`） | なし（`Set([...])`） | `Dict(pairs...)` | 【要検証】 | `const` は束縛だけ | `Dict()` |
| Ruby | `{"a" => 1}`・`{a: 1}` | なし（`Set[1, 2]`） | `Set.new` | 後の値。警告がある | 定数は束縛だけ | `{}` |
| Perl | リストの代入 `(a => 1)`、無名のハッシュ `{...}` | なし | — | 後の値 | — | `()` |
| Lua | 表の構築子 `{k = v, [e] = v}` | なし | — | 定めない（構築子の代入の順序を定めない） | `<const>` は束縛だけ | `{}` |

- 関数型の言語（Haskell、Elm、OCaml、F#、Gleam、Roc）は、どれもマップのリテラルを持たず、`fromList` の形で作る。Kotlin の実験中のコレクションのリテラル（KEEP-0416）は、Java との相互運用、`Map.Entry` の箱詰め、作る実装の曖昧さを理由に、マップを明示で外した。
- 同じ鍵を重ねたときの扱いは、静的な誤り（Go の定数の鍵、Dart の定数のマップ、Clojure のリテラル）、実行時の停止（Swift）、後の値を使う（そのほか。Elixir・Dart・Ruby・Swift は警告を出す）に分かれる。
- マップを定数にできるのは Dart の `const` だけで、Elixir のモジュールの属性がこれに近い。Go・Kotlin・Gleam・F# の `[<Literal>]` は明示で禁じ、Rust は空のマップだけを許す。
- 空の `{}` の曖昧さを、Python と Dart は `{}` をマップと決めて解き、Swift は `[:]`、Clojure と Elixir は別の記号（`#{}`・`%{}`）で避ける。

【要検証】

- Roc の `Dict.from_list` の重なる鍵の扱いと順序、定数にできるか。
- Scala 3 の `Map(...)` の重なる鍵の扱いと、定数にできないこと。
- Julia の `Dict` の重なる鍵の扱い。
- PureScript（`Data.Map.fromFoldable`）と Idris 2（`Data.SortedMap.fromList`）の形。
- Python の辞書が挿入の順に反復すること（本節の出典の節には記述がない）。

出典

- https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/overloaded_lists.html
- https://hackage-content.haskell.org/package/containers-0.8/docs/Data-Map-Strict.html
- https://github.com/elm/core/blob/master/src/Dict.elm
- https://github.com/ocaml/ocaml/blob/trunk/stdlib/map.mli
- https://fsharp.github.io/fsharp-core-docs/reference/fsharp-collections-fsharpmap-2.html
- https://fsharp.github.io/fsharp-core-docs/reference/fsharp-collections-mapmodule.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/literals
- https://gleam-stdlib.hexdocs.pm/gleam/dict.html
- https://tour.gleam.run/everything/
- https://www.roc-lang.org/builtins/Dict
- https://elixir.hexdocs.pm/Map.html
- https://github.com/elixir-lang/elixir/blob/main/lib/elixir/src/elixir_map.erl
- https://clojure.org/reference/reader
- https://github.com/clojure/clojure/blob/master/changes.md
- https://docs.scala-lang.org/scala3/book/collections-classes.html
- https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/map-of.html
- https://kotlinlang.org/docs/properties.html
- https://github.com/Kotlin/KEEP/blob/main/proposals/KEEP-0416-collection-literals.md
- https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/CollectionTypes.md
- https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Dictionary.swift
- https://docs.python.org/3/reference/expressions.html
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Object_initializer
- https://doc.rust-lang.org/std/collections/struct.BTreeMap.html
- https://go.dev/ref/spec
- https://dart.dev/language/collections
- https://dart.dev/tools/diagnostics/equal_keys_in_const_map
- https://github.com/JuliaLang/julia/blob/master/base/dict.jl
- https://docs.ruby-lang.org/en/master/Hash.html
- https://perldoc.perl.org/perldata
- https://www.lua.org/manual/5.4/manual.html

### 標準ライブラリの範囲

[ADR 0137](../decisions/0137-first-release-library-scope.md) の判断に使った。

凡例: ✓ は言語か標準ライブラリにある。inst は処理系と一緒に入るが中核の外にある（Ruby の同梱の gem、GHC の同梱のパッケージ、OCaml の `str`・`unix`、Elixir から使う OTP、Kotlin から使う JDK）。pkg は別にパッケージを入れる。~ は一部だけある。基盤は Roc のプラットフォーム（basic-cli）が提供する。

| 言語 | 正規表現 | JSON | CSV | パス | ディレクトリ | 日時 / タイムゾーン | HTTP クライアント | HTTP サーバ | Base64・16 進数 | SHA-256 | プロセス | 環境変数 | 標準入力の行 | URL | gzip |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Python | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ / ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ruby | ✓ | ✓ | inst | ✓ | ✓ | ✓ / pkg | ✓ | pkg | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Perl | ✓ | ✓ | pkg | ✓ | ✓ | ✓ / pkg | ✓ | pkg | ✓ | ✓ | ✓ | ✓ | ✓ | pkg | ✓ |
| Go | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ / ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Deno（実行環境） | ✓ | ✓ | ✗ | ✗ | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Node.js | ✓ | ✓ | pkg | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Elixir | ✓ | ✓ | pkg | ✓ | ✓ | ✓ / pkg | inst | 【要検証】 | ✓ | inst | ✓ | ✓ | ✓ | ✓ | inst |
| Gleam | pkg | pkg | pkg | pkg | pkg | pkg | pkg | pkg | ✓ | pkg | pkg | pkg | pkg | ✓ | pkg |
| Roc | ✗ | 【要検証】 | ✗ | 基盤 | 基盤 | 基盤 / ✗ | 基盤 | ✗ | ~ | 【要検証】 | 基盤 | 基盤 | 基盤 | 基盤 | ✗ |
| OCaml | inst | pkg | pkg | ✓ | ✓ | inst（書式なし） | pkg | pkg | pkg | pkg | ✓ | ✓ | ✓ | pkg | pkg |
| Haskell（base） | pkg | pkg | pkg | inst | inst | inst / pkg | pkg | pkg | pkg | pkg | inst | ✓ | ✓ | pkg | pkg |
| Lua | ~ | ✗ | ✗ | ✗ | ✗ | ~ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ |
| Rust | pkg | pkg | pkg | ✓ | ✓ | pkg | pkg | pkg | pkg | pkg | ✓ | ✓ | ✓ | pkg | pkg |
| Kotlin（JVM） | ✓ | pkg | pkg | ✓ | ✓ | inst | inst | inst | ✓ | inst | inst | inst | ✓ | inst | inst |
| Julia | ✓ | pkg | pkg | ✓ | ✓ | ✓ / pkg | ✓ | pkg | ✓ | ✓ | ✓ | ✓ | ✓ | pkg | pkg |
| Nushell | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ / ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |

- Ruby は 3.4 で `csv` と `base64` を既定の gem から同梱の gem に移し、3.0 で WEBrick を標準ライブラリから外した。
- Deno の `@std` は実行環境に組み込まれておらず、JSR に置いた、版を別に持つパッケージ群である。
- Gleam の標準ライブラリ（`gleam_stdlib`）自体が Hex のパッケージであり、正規表現は v0.50 で `gleam_regexp` に移した。
- Julia は v1.9 で `DelimitedFiles` を別のパッケージに移した。

標準ライブラリの範囲についての公式の見解は次のとおりである。

- Python PEP 206 は「batteries included」の方針を「a rich and versatile standard library which is immediately available, without making the user download separate packages」と書く。PEP 594 は、PyPI で導入が容易になったこと、保守の費用を理由に、古いモジュールを外した（3.13 で実施）。
- Go の FAQ は、標準ライブラリの目的を、ランタイムの支え、OS との接続、書式付きの入出力とネットワーク、HTTP・JSON・XML などの標準の支持とする。「New additions to the standard library are rare and the bar for inclusion is high.」とし、保守の費用、Go 1 の互換性の約束、リリースの周期を理由に挙げる。
- Deno の std の FAQ は、実行環境と別に版を付ける理由を、Deno 以外の実行環境でも使え、二つを独立に進められることとする。
- Gleam は、組み込み機器やブラウザでも動くので、コマンドライン引数や環境変数の読み取りのような機能を標準ライブラリに入れないと書く。
- Rust の標準ライブラリの文書は、自らを「minimal and battle-tested shared abstractions」と書く。

【要検証】

- Roc の組み込みの `Crypto`・`Encoding` の内容（要約で確かめただけで、新しいコンパイラの版では変わりやすい）。
- Node.js と Deno の `Temporal` の安定性、`Intl` によるタイムゾーンの扱い。
- Ruby の `tzinfo`、Perl の `DateTime`、Julia の `TimeZones.jl`、Gleam の代わりのパッケージ（`gleam_json` など）の名前。
- Elixir から OTP の `:httpd` を使うこと。
- Kotlin から使う JDK の `Base64`・`HexFormat`・`MessageDigest` など。
- Rust の標準ライブラリの範囲の考え方を述べた API Guidelines やブログの文。

出典

- https://docs.python.org/3/py-modindex.html
- https://peps.python.org/pep-0206/
- https://peps.python.org/pep-0594/
- https://docs.ruby-lang.org/en/master/standard_library_md.html
- https://github.com/ruby/ruby/blob/v3_4_0/NEWS.md
- https://perldoc.perl.org/modules
- https://pkg.go.dev/std
- https://go.dev/doc/faq
- https://docs.deno.com/api/deno/
- https://jsr.io/@std
- https://github.com/denoland/std/blob/main/.github/FAQ.md
- https://nodejs.org/api/index.html
- https://elixir.hexdocs.pm/api-reference.html
- https://gleam-stdlib.hexdocs.pm/
- https://tour.gleam.run/standard-library/standard-library-package/
- https://gleam.run/writing-gleam/
- https://github.com/gleam-lang/stdlib/blob/main/CHANGELOG.md
- https://www.roc-lang.org/builtins
- https://roc-lang.github.io/basic-cli/0.23.0/
- https://ocaml.org/manual/latest/stdlib.html
- https://hackage.haskell.org/package/base
- https://downloads.haskell.org/ghc/latest/docs/users_guide/9.14.1-notes.html
- https://www.lua.org/manual/5.4/contents.html
- https://doc.rust-lang.org/std/
- https://kotlinlang.org/api/core/kotlin-stdlib/
- https://docs.julialang.org/en/v1/
- https://github.com/JuliaLang/julia/blob/master/HISTORY.md
- https://www.nushell.sh/commands/

### Rust のクレートのライセンス

[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) の判断に使った。ライセンスは crates.io に登録された Cargo.toml の値（2026-09-28 の最新の安定版）であり、推移的な依存は既定の機能で `cargo tree --target all` を使って調べた。

| クレート | ライセンス | 注意の要る依存 | C・アセンブリ |
|---|---|---|---|
| `regex` | MIT OR Apache-2.0 | `aho-corasick`・`memchr`（Unlicense OR MIT） | なし |
| `regex-lite` | MIT OR Apache-2.0 | なし | なし |
| `fancy-regex` | MIT | `regex` と同じ | なし |
| `serde` | MIT OR Apache-2.0 | `unicode-ident`（(MIT OR Apache-2.0) AND Unicode-3.0。手続きマクロ） | なし |
| `serde_json` | MIT OR Apache-2.0 | `serde_core`・`itoa`（MIT OR Apache-2.0）、`memchr`、`zmij`（MIT） | なし |
| `csv` | Unlicense OR MIT | `serde`、`ryu`（Apache-2.0 OR BSL-1.0） | なし |
| `csv-core` | Unlicense OR MIT | なし | なし |
| `jiff` | Unlicense OR MIT | 同じ作者のクレート（Unlicense OR MIT） | なし |
| `time`・`chrono`・`chrono-tz` | MIT OR Apache-2.0 | 手続きマクロの `unicode-ident` | なし |
| `base64` | MIT OR Apache-2.0 | なし | なし |
| `hex` | MIT OR Apache-2.0 | なし（最後の版は 2021 年） | なし |
| `sha2`・`md-5` | MIT OR Apache-2.0 | なし | なし |
| `flate2` | MIT OR Apache-2.0 | `miniz_oxide`（MIT OR Zlib OR Apache-2.0） | 既定ではなし |
| `ureq` | MIT OR Apache-2.0 | `ring`（Apache-2.0 AND ISC）、`webpki-roots`（CDLA-Permissive-2.0）、`subtle`（BSD-3-Clause） | `ring` を通してあり |
| `reqwest` | MIT OR Apache-2.0 | `aws-lc-sys`（ISC・BSD-3-Clause などの AND）、ICU4X のクレート（Unicode-3.0）など、推移的な依存は 173 | `aws-lc-sys` を通してあり |
| `hyper`・`tokio`・`mio` | MIT | なし | なし |
| `rustls` | Apache-2.0 OR ISC OR MIT | 既定の `aws-lc-rs`・`aws-lc-sys` | 既定の暗号の実装を通してあり |
| `ring` | Apache-2.0 AND ISC | `untrusted`（ISC） | あり（BoringSSL 由来の C と perlasm） |
| `url` | MIT OR Apache-2.0 | `idna` を通して ICU4X のクレート（Unicode-3.0） | なし |
| `walkdir`・`globset` | Unlicense OR MIT | なし | なし |
| `glob`・`tempfile`・`percent-encoding`・`unicode-normalization`・`unicode-segmentation` | MIT OR Apache-2.0 | なし | なし |
| `icu_*` | Unicode-3.0 | ICU4X のクレート（Unicode-3.0） | なし |
| `getrandom`・`rand` | MIT OR Apache-2.0 | — | — |

- `webpki-roots` は 0.2.0（2016 年）から MPL-2.0 であり、0.26.9（2025-04-27）で CDLA-Permissive-2.0 に変わった。
- `ring` は 0.17.10-alpha1（2025 年 2 月）から SPDX の `Apache-2.0 AND ISC` を記す。それより前は独自のライセンスのファイルを指していた。
- TLS の既定: `rustls` 0.23 の既定の暗号の実装は `aws-lc-rs` である。`ureq` 3 の既定は `ring` と `webpki-roots`、`reqwest` 0.13 の既定は `aws-lc-rs` と OS の検証器である。`aws-lc-sys` のビルドには C のツールチェーンが要り、構成によって CMake や NASM も要る。
- `cargo-deny` の `[licenses]` の検査は、`allow` に並べた SPDX の識別子だけを許し、ほかを拒む。式の `OR` はどれか一つ、`AND` はすべてが許可されていれば通る。クレートごとの例外は `exceptions`、SPDX の式を持たないクレートは `[[licenses.clarify]]` で扱う。
- Unicode-3.0 は許容的なライセンスであるが、写しか付属の文書に著作権と許諾の表示を含めることを条件とする。
- `rand` の `StdRng` のソースのコメントは、「non-portable」「any future library version may replace the algorithm」と書き、種を固定しても出力は移植できないとする。

【要検証】

- 各クレートの unsafe の使用は、ソースの検索による目安である。
- 実際のワークスペースでは、機能の統合によって依存の集合がこの調査と変わりうる。

出典

- https://crates.io/crates/regex
- https://crates.io/crates/serde_json
- https://crates.io/crates/csv-core
- https://crates.io/crates/jiff
- https://crates.io/crates/base64
- https://crates.io/crates/sha2
- https://crates.io/crates/getrandom
- https://crates.io/crates/zmij
- https://crates.io/crates/webpki-roots
- https://crates.io/crates/ring
- https://embarkstudios.github.io/cargo-deny/checks/licenses/cfg.html
- https://spdx.org/licenses/Unicode-3.0.html
- https://github.com/rust-random/rand/blob/master/src/rngs/std.rs

### 外部の関数の宣言

[ADR 0139](../decisions/0139-external-functions-via-wasm.md) の判断に使った。

| 言語・仕組み | 宣言の形 | キーワードか属性か | 対象 | 型とエフェクトの扱い | 権限との関係 |
|---|---|---|---|---|---|
| Gleam | `@external(erlang, "m", "f")` を本体のない関数に付ける。Gleam の本体を代わりに持てる | 属性 | Erlang の関数、JS のモジュール | 型は信用する | なし |
| PureScript | `foreign import f :: T` | キーワード | JS のモジュール | エフェクトのある関数は `Effect` を返すと宣言する。宣言は信用する | なし |
| Haskell 2010 | `foreign import ccall "h f" f :: T` | キーワード（`foreign`） | C | `IO` か純粋（純粋な宣言は「true function」であると主張する） | なし |
| OCaml | `external f : T = "c_name"` | キーワード | C のスタブ | 信用する | なし |
| Idris 2 | `%foreign "C:fn,lib"` | 指示子 | C の共有ライブラリなど | `PrimIO` ならエフェクトあり、ほかは純粋と信用する | なし |
| Koka | `extern f(x : T) : eff R { c "…"; js "…" }` | キーワード | C・C#・JS | 宣言のエフェクトを信用する | なし |
| Rust | `unsafe extern "C" { safe fn f(); }` | キーワード | C の ABI | エフェクトはない。2024 版から `unsafe extern` が必須 | なし |
| Roc | アプリケーションには外部の関数がない | — | プラットフォームのホスト | 効果はすべてプラットフォームが与える | プラットフォームが拒否や確認を行える |
| Flix | `import java.lang.Math` | import | JVM | Java の呼び出しには必ず `IO` が付き、`unsafe` で外す | なし |
| Deno | `Deno.dlopen(path, {…})` | 実行時の API | C の ABI | — | `--allow-ffi` が要る |
| Node.js | ネイティブのアドオン、WASI、FFI | 実行時の API | C・C++ | — | `--permission` の下では `--allow-addons` などが要る |
| Extism | `#[host_fn] extern "ExtismHost" { … }` | 属性（マクロ） | ホストの関数 | 呼び出しは `unsafe` | マニフェストの `allowed_hosts`・`allowed_paths`（既定は拒否） |
| Wasmtime・WASI | WIT の `world` の `import`・`export` | IDL | ホストが与える関数 | — | 能力に基づく。与えたディレクトリにだけ触れる |
| Elm | `port f : T -> Cmd msg` | キーワード（`port`） | JS とのメッセージ | `Cmd`・`Sub` だけ | パッケージでは使えない |

- Gleam は v0.30 で `external fn`・`external type` のキーワードの形を非推奨にし、v0.31 で削除した。属性の形にした理由を、宣言の見出しが一つにまとまって対象ごとの定義が揃うこと、文書を一箇所に書けること、コンパイラが対象を推論できることとする。命名について、保守者は「Attribute is the name for metadata attached to code in all the languages I checked」と書く。
- Rust の言語リファレンスは、`extern "Rust"` について「The Rust ABI offers no stability guarantees.」と書く。
- Rust 2024 は `unsafe extern` を必須にした。理由を、宣言のシグネチャが正しいことは宣言を書いた者の責任であり、誤れば未定義の動作になりうることを示すためとする。
- Deno の文書は、ネイティブのコードは Deno のセキュリティのサンドボックスの外で動き、`--allow-*` の指定によらずシステムコールを直接出せると書き、`--allow-ffi` と `--allow-run` を、コードを信用するかの判断ではすべてを許すのと同じとする。
- Node.js の権限のモデルは、自らを「seat belt」と呼び、悪意のあるコードに対するセキュリティの保証を与えないとする。
- Roc の文書は、プラットフォームがすべての IO の基本の操作を独占して管理し、「There are no escape hatches」と書く。
- Wasmtime の文書は、WASM のインスタンスは明示に結び付けたインタフェースを通してしか外と関われず、システムコールに直接触れないと書く。

【要検証】

- PureScript・OCaml・Idris 2・Flix で、外部の関数の構文を導入した経緯。
- Koka で `extern` を予約した時期。
- Haskell 98 が `foreign` を予約していなかったこと。
- Extism のマニフェストの時間の上限の指定。

出典

- https://gleam.run/documentation/externals/
- https://tour.gleam.run/advanced-features/externals/
- https://raw.githubusercontent.com/gleam-lang/gleam/v0.31.0/CHANGELOG.md
- https://gleam.run/news/v0.30-local-dependencies-and-enhanced-externals/
- https://github.com/gleam-lang/gleam/discussions/2133
- https://github.com/purescript/documentation/blob/master/guides/FFI.md
- https://www.haskell.org/onlinereport/haskell2010/haskellch8.html
- https://ocaml.org/manual/5.2/intfc.html
- https://idris2.readthedocs.io/en/latest/ffi/ffi.html
- https://koka-lang.github.io/koka/doc/book.html
- https://doc.rust-lang.org/reference/items/external-blocks.html
- https://doc.rust-lang.org/edition-guide/rust-2024/unsafe-extern.html
- https://www.roc-lang.org/docs/main/langref/platforms/
- https://doc.flix.dev/calling-methods.html
- https://docs.deno.com/runtime/fundamentals/ffi/
- https://docs.deno.com/runtime/fundamentals/security/
- https://nodejs.org/api/permissions.html
- https://extism.org/docs/concepts/manifest
- https://docs.wasmtime.dev/security.html
- https://component-model.bytecodealliance.org/design/wit.html
- https://guide.elm-lang.org/interop/limits.html

### ネットワークの操作と IO の区分

[ADR 0140](../decisions/0140-network-separated-from-local-io.md) の判断に使った。

| 言語 | ネットワークの操作の型・エフェクト | ファイルの操作との関係 | 名前空間 |
|---|---|---|---|
| Haskell | `IO`（`connect :: Socket -> SockAddr -> IO ()`） | 同じ `IO` | `Network.*`（`network` パッケージ。`System.IO` と別） |
| Koka | `net` | `fsys` と別のエフェクト。`io` は `net`・`fsys`・`console` などをまとめた別名 | `std/core` |
| Flix | `IO`。ライブラリのエフェクト `Http` | `IO` の説明に「accessing the network」を含める。ファイルは `FileSystem` | `Net.Http` |
| OCaml Eio | 権限の値 `env#net` | ファイルシステムの `env#fs` と別の値 | `Eio.Net` |
| Unison | `{IO, Exception}` | 同じ `IO` | `io.clientSocket`（`io` の下） |
| Idris 2 | `HasIO io => … -> io ResultCode` | 同じ `HasIO` | `Network.Socket` |
| Lean 4 | `IO`・`Async` | 同じ `IO` | `Std.Net`・`Std.Async.TCP` |
| Effekt | `Exception[IOError]` | 同じ形 | `io/network`（`io/filesystem` と並ぶ） |
| Scala（fs2） | `F[_]` の型クラス `Network` | `Files` と並ぶ型クラス | `fs2.io.net`（`fs2.io.file` と並ぶ） |
| PureScript | `Effect` | 同じ `Effect` | Node の束縛のパッケージ |
| Roc（basic-cli） | 作用を持つ関数の矢印 `=>` | 同じ `=>` | `Http`・`Tcp`・`File` が同じ階層 |
| Elm | `Cmd`・`Task` | ファイルの操作を持たない | `Http` |

- Flix の文書は「The `IO` effect represents any action that interacts with the world outside the program. Such actions include printing to the console, creating, reading, and writing files, accessing the network, and more.」と書く。
- Koka の `std/core` は「The `:net` effect signifies a function may access the network」と書き、`pub alias ioc-total = <ndet,console,net,fsys,ui,st<global>>`、`pub alias io = <exn,ioc>` と定める。
- Haskell の base は、`IO a` を「a computation which, when performed, does some I/O before returning a value of type `a`」と書く。
- OCaml Eio の README は「Only `env`'s network access is used, so we know this program doesn't access the filesystem」と書く。

出典:

- https://hackage-content.haskell.org/package/network-3.2.9.0/docs/Network-Socket.html
- https://hackage-content.haskell.org/package/base-4.22.0.0/docs/System-IO.html
- https://github.com/koka-lang/koka/blob/master/lib/std/core.kk
- https://doc.flix.dev/primitive-effects.html
- https://doc.flix.dev/http.html
- https://ocaml.org/p/eio/latest/doc/Eio/Stdenv/index.html
- https://github.com/ocaml-multicore/eio
- https://github.com/unisonweb/base/issues/10
- https://github.com/idris-lang/Idris2/blob/main/libs/network/Network/Socket.idr
- https://github.com/leanprover/lean4/blob/master/src/Std/Async/TCP.lean
- https://github.com/effekt-lang/effekt/tree/main/libraries/common/io
- https://github.com/typelevel/fs2/blob/main/io/shared/src/main/scala/fs2/io/net/Network.scala
- https://github.com/roc-lang/basic-cli/tree/main/platform
- https://github.com/elm/http/blob/master/src/Http.elm

【要検証】

- Flix の基本のエフェクトに `Net` があるか（検索の抜粋にはあるが、取得した文書の版には見当たらない）。
- Koka の別名の名前（現在の `master` は `ioc-total`・`ioc`。以前の版は `io-total`・`io-noexn`）。
- PureScript の Node の束縛のパッケージが `Effect` を使うこと（ソースで確かめていない）。

### 標準ライブラリの HTTP

[ADR 0141](../decisions/0141-http-scope-in-stdlib.md) と [ADR 0142](../decisions/0142-http-api-shape.md) の判断に使った。

凡例: ✓ は標準ライブラリにある。pkg はパッケージに任せる。

| 言語 | サーバ | クライアント | HTTPS のクライアント | TCP | サーバの形 | 経路の振り分け |
|---|---|---|---|---|---|---|
| Go（`net/http`） | ✓ | ✓ | ✓ | ✓ | 一つの要求ごとの関数が `ResponseWriter` に書く | ✓（1.22 から方法と `{名前}` の型板） |
| Python | ✓（`http.server`） | ✓（`urllib.request`） | ✓ | ✓ | 要求の方法ごとのメソッドが書き込む | なし |
| Java | ✓（`jdk.httpserver`） | ✓（11 から `java.net.http`） | ✓ | ✓ | `HttpExchange` に書き込む | パスの前方一致だけ |
| Dart（`dart:io`） | ✓ | ✓ | ✓ | ✓ | 要求の流れを繰り返し、書き込む | なし |
| Erlang/OTP（`inets`） | ✓（`httpd`） | ✓（`httpc`） | ✓ | ✓ | コールバックのモジュール | なし |
| Ruby | pkg（3.0 で WEBrick を外した） | ✓（`Net::HTTP`） | ✓ | ✓ | — | — |
| Deno | ✓（`Deno.serve`） | ✓（`fetch`） | ✓ | ✓ | 要求から応答への関数 | なし（`URLPattern`） |
| Bun | ✓（`Bun.serve`） | ✓（`fetch`） | ✓ | ✓ | 要求から応答への関数 | ✓（1.2.3 から `routes`） |
| Racket | ✓（本体の配布に含む） | ✓ | ✓ | ✓ | 要求から応答への関数 | なし |
| Roc（basic-webserver） | 基盤 | 基盤 | 基盤 | 基盤 | 要求から応答への関数 | なし |
| Julia | pkg | ✓（`Downloads`） | ✓ | ✓ | — | — |
| Gleam・Haskell・OCaml・Rust | pkg | pkg | pkg | Haskell 以外は ✓ | Gleam の Wisp は要求から応答への関数 | — |

- Python の文書は「`http.server` is not recommended for production. It only implements basic security checks.」と書く。
- Java の文書は、`SimpleFileServer` を「intended for testing, development and debugging purposes only」と書く。
- Ruby 3.0 のリリースの告知は、WEBrick を標準ライブラリから外したと書く。
- JSON の応答を作る補助の関数は、Web の標準の `Response.json`（Deno・Bun）にある。

出典:

- https://pkg.go.dev/net/http
- https://go.dev/blog/routing-enhancements
- https://docs.python.org/3/library/http.server.html
- https://docs.python.org/3/library/urllib.request.html
- https://docs.oracle.com/en/java/javase/21/docs/api/jdk.httpserver/com/sun/net/httpserver/package-summary.html
- https://docs.oracle.com/en/java/javase/21/docs/api/java.net.http/java/net/http/HttpClient.html
- https://api.dart.dev/stable/dart-io/HttpServer-class.html
- https://www.erlang.org/doc/apps/inets/httpd.html
- https://www.ruby-lang.org/en/news/2020/12/25/ruby-3-0-0-released/
- https://docs.deno.com/runtime/fundamentals/http_server/
- https://bun.sh/docs/api/http
- https://docs.racket-lang.org/web-server/run.html
- https://github.com/roc-lang/basic-webserver
- https://docs.julialang.org/en/v1/stdlib/Sockets/
- https://github.com/gleam-wisp/wisp

【要検証】

- Deno の `Deno.listen`・`Deno.connect` による TCP。
- Julia の `Downloads` の HTTPS。
- Elixir の標準ライブラリ自体に HTTP がないこと。
- Racket の `net/url` のクライアントの細部。

### ネットワークの権限

[OPEN-045](../open-issues.md#open-045) の検討に使った。OPEN-045 は権限の宣言の構文を削除して決着し（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）、ネットワークの操作の権限は [OPEN-052](../open-issues.md#open-052) に引き継いだ。その後、許可の単位を組み込みのエフェクトとし、待ち受け（`Http.Listen`）と接続（`Http.Connect`）を別の許可にした（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。対象の書き方と判定の時点は、[OPEN-052](../open-issues.md#open-052) で決める。

| 実行環境・仕組み | 待ち受けと接続 | 指定の単位 | 判定の時点 |
|---|---|---|---|
| Deno 2 | `--allow-net` の一つで両方 | ホストの名前か IP アドレス、ポートは省ける（省くとすべてのポート）。サブドメインは明示しない限り含めない | 書かれた名前で許可を判定する。名前解決の後は拒否の規則だけで判定する |
| Node.js | `--allow-net`（v25 から。開発中） | すべてか無しか | — |
| Java の `SocketPermission`（JDK 24 で廃止） | `connect`・`listen`・`accept`・`resolve` を分ける | ホストとポートの範囲。`*.` の前置のワイルドカード | — |
| Linux Landlock | バインドと接続を分ける（ABI 4、Linux 6.7） | TCP のポートだけ（アドレスを指定できない） | カーネル |
| OpenBSD の `pledge` | `inet` で両方 | すべてか無しか | カーネル |
| macOS の sandbox のプロファイル | `network-bind`・`network-inbound`・`network-outbound` | ローカルとリモートのアドレスとポート | カーネル |
| wasmtime | CLI は `inherit-network` などすべてか無しか。埋め込み API は `TcpBind`・`TcpListen`・`TcpConnect` を分ける | 埋め込み API はソケットのアドレス | ホスト |
| Roc（basic-webserver） | 許可の仕組みはない | — | — |

- Deno の `Deno.serve` の既定の待ち受けは `0.0.0.0` の 8000 番である。Roc の basic-webserver の既定は `127.0.0.1:8000` だけである。
- Deno のソースの許可の判定には、名前解決の後の IP アドレスについて「Only checks deny rules — the allow check has already been performed against the original hostname.」とある。
- macOS の `sandbox-exec` のマニュアルは、このコマンドを「DEPRECATED」と書く。

出典:

- https://github.com/denoland/docs/blob/main/runtime/reference/permissions.md
- https://github.com/denoland/deno/blob/main/runtime/permissions/lib.rs
- https://github.com/denoland/deno/blob/main/ext/net/ops.rs
- https://nodejs.org/api/cli.html#--allow-net
- https://docs.oracle.com/javase/8/docs/api/java/net/SocketPermission.html
- https://openjdk.org/jeps/486
- https://man7.org/linux/man-pages/man7/landlock.7.html
- https://man.openbsd.org/pledge.2
- https://github.com/bytecodealliance/wasmtime/blob/main/crates/cli-flags/src/lib.rs
- https://github.com/roc-lang/basic-webserver/blob/main/README.md

【要検証】

- Deno の CIDR と Unix ソケットの指定（ソースにはあるが、利用者向けの文書になく、対応した版が分からない）。
- Landlock の UDP の規則（ABI 10）が入った Linux の版。

### HTTP と TLS のクレート

[ADR 0143](../decisions/0143-http-and-tls-crates.md) の判断に使った。ライセンスは crates.io に登録された値（2026-09-28 の最新の版）である。

| クレート | 版 | ライセンス | C・アセンブリ | 注意 |
|---|---|---|---|---|
| `hyper` | 1.11.1 | MIT | なし | `tokio` に必ず依存する |
| `tiny_http` | 0.12.0 | MIT OR Apache-2.0 | なし | 最後の版は 2022 年 |
| `httparse` | 1.10.1 | MIT OR Apache-2.0 | なし | 依存がなく、入出力を持たない |
| `mio` | 1.2.3 | MIT | なし | `tokio` に依存しない |
| `ureq` | 3.4.2 | MIT OR Apache-2.0 | 既定の機能では `ring` を通してあり | 同期の API。既定の機能は `webpki-roots` を使う |
| `reqwest` | 0.13.5 | MIT OR Apache-2.0 | 既定の機能ではあり | `tokio` を使う |
| `attohttpc` | 0.31.0 | MPL-2.0 | — | コピーレフトのライセンス |
| `rustls` | 0.23.45 | Apache-2.0 OR ISC OR MIT | 既定の provider（`aws-lc-rs`）を通してあり | provider を選べる |
| `ring` | 0.17.14 | Apache-2.0 AND ISC | あり（C コンパイラを要する） | 耐量子の鍵交換を持たない |
| `aws-lc-rs` | 1.18.1 | ISC AND (Apache-2.0 OR ISC) | `aws-lc-sys` を通してあり | rustls の推奨 |
| `aws-lc-sys` | 0.45.0 | ISC AND (Apache-2.0 OR ISC) AND Apache-2.0 AND MIT AND BSD-3-Clause AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR ISC OR MIT-0) | あり（C コンパイラを要する） | AWS-LC の C のソースを同梱する |
| `graviola`・`rustls-graviola` | 0.4.1・0.4.0 | Apache-2.0 OR ISC OR MIT-0 | Rust の中のアセンブリだけ（C コンパイラを要しない） | x86_64 と aarch64 だけ。新しいクレート |
| `rustls-rustcrypto` | 0.0.2-alpha | MIT OR Apache-2.0 | なし | alpha 版 |
| `native-tls` | 0.2.18 | MIT OR Apache-2.0 | Linux では OpenSSL | OS の TLS を使う |
| `webpki-roots` | 1.0.9 | CDLA-Permissive-2.0 | なし | 許可の一覧にないライセンス |
| `rustls-native-certs` | 0.8.4 | Apache-2.0 OR ISC OR MIT | なし | OS のルート証明書を読む |
| `rustls-platform-verifier` | 0.7.1 | MIT OR Apache-2.0 | なし | OS の検証を使う。`webpki-root-certs` は wasm32 のときだけ |

- AWS-LC の LICENSE は、BoringSSL（ISC か Apache-2.0）、OpenSSL と SSLeay（Apache-2.0）、Fiat Cryptography（MIT）、乱数の部分（BSD-3-Clause）、s2n-bignum（Apache-2.0 OR ISC OR MIT-0）の出所ごとに、元のライセンスを残す。
- aws-lc-rs の README は「This library is licensed under the Apache-2.0 or the ISC License.」と書く。これは `aws-lc-rs` のクレートの記述であり、`aws-lc-sys` は上の表のライセンスを持つ。
- rustls の README は、`aws-lc-rs` の provider を推奨し、`ring` の provider は「does not support post-quantum algorithms」と書く。
- graviola の README は「no C compiler, assembler or other tooling needed: just the Rust compiler」「This project is very new, so exercise due caution.」と書く。x86_64 では `aes`・`ssse3`・`avx`・`avx2`・`adx`・`bmi2`・`pclmulqdq` の CPU の機能を、aarch64 では `aes`・`sha2`・`pmull`・`neon` を要する。
- `rustls-rustcrypto` の README は「USE THIS AT YOUR OWN RISK! DO NOT USE THIS IN PRODUCTION」と書く。
- `ureq` の README は、`rustls-no-provider` の機能を使うとき、ルート証明書と provider を agent に設定する必要があると書く。

出典:

- https://crates.io/api/v1/crates/（各クレートの登録情報）
- https://github.com/aws/aws-lc/blob/main/LICENSE
- https://github.com/aws/aws-lc-rs
- https://github.com/rustls/rustls/blob/main/README.md
- https://github.com/ctz/graviola
- https://github.com/RustCrypto/rustls-rustcrypto
- https://github.com/algesten/ureq
- https://github.com/rustls/rustls-platform-verifier/blob/main/rustls-platform-verifier/Cargo.toml
- https://github.com/briansmith/ring/blob/main/BUILDING.md

【要検証】

- `ureq` に `rustls-graviola` の provider を与えて動くか。
- `may_minihttp` の依存と、コルーチンの切り替えにアセンブリを使うか（採らなかったので確かめていない）。

### IO の失敗の種類

[ADR 0144](../decisions/0144-ioerrorkind-constructors.md) と [ADR 0145](../decisions/0145-network-error.md) の判断に使った。

| 言語 | 表し方 | 種類の数 | ネットワークの失敗 | 種類を加えたときの扱い |
|---|---|---|---|---|
| Rust | 列挙 `std::io::ErrorKind` | 安定版で 40 近く（1.0 で 16。1.83 で 15、1.85 で 2、1.87 で 1 を加えた） | ConnectionRefused・ConnectionReset・ConnectionAborted・TimedOut・AddrInUse・HostUnreachable など。名前解決の失敗の種類はない | `#[non_exhaustive]` で、定義したクレートの外の `match` に `_` を必須にする |
| Python | `OSError` のサブクラス（PEP 3151） | 15 ほど | ConnectionRefusedError・ConnectionResetError・TimeoutError など。名前解決の失敗は `socket.gaierror` | サブクラスの階層を `except` で捕らえるので、網羅性はない |
| Go | 番兵の値（`io/fs`）と `errors.Is` | 5（ErrInvalid・ErrPermission・ErrExist・ErrNotExist・ErrClosed） | `net.Error` の `Timeout()`、`DNSError` の `IsNotFound` | 判定の関数なので、網羅性はない |
| Deno | `Deno.errors` のクラス | 25 | ConnectionRefused・ConnectionReset・TimedOut・AddrInUse など | クラスなので、網羅性はない |
| Haskell | 見せない型 `IOErrorType` と判定の関数 | 9 の判定の関数 | — | 構成子を見せないので、加えても壊れない |
| Node.js | `error.code` の文字列 | 開いた集合 | ECONNREFUSED・ECONNRESET・ETIMEDOUT・ENOTFOUND など | 文字列なので、網羅性はない |
| Gleam（simplifile） | 列挙 `FileError` | POSIX のエラー番号ごとの 51 と `NotUtf8`・`Unknown` | — | 網羅性の検査があり、加えると互換性を壊す（推定） |
| Java | 例外のサブクラス | NIO のファイルの例外が 8 | ConnectException・SocketTimeoutException・UnknownHostException | 例外の階層なので、網羅性はない |
| Flix | 列挙 `IoError.ErrorKind` | 18 | ConnectionFailed（まとめて一つ）・Timeout・UnknownHost | 普通の列挙 |
| Swift | 凍結しない列挙 | — | — | `@unknown default` を必須にし、既知の構成子を扱い漏らすと警告する（Swift 5.0、SE-0192） |

- Rust の文書は、`ErrorKind` について「This list is intended to grow over time and it is not recommended to exhaustively match against it.」と書く。`Other` は標準ライブラリが使わず、分類していない OS の誤りは隠れた `Uncategorized` に入り、ソースのコメントは「It is not recommended to match an error against `Uncategorized`; use a wildcard match (`_`) instead.」と書く。
- PEP 3151 は、エラー番号をすべて写すことを「Trying to map all errno mnemonics, indeed, seems foolish, pointless, and would pollute the root namespace.」と書く。
- Deno は、実行環境の権限による拒否（`NotCapable`）を、OS による拒否（`PermissionDenied`）と分ける。
- どの言語も「その他」を持つ（Rust の `Other`・`Uncategorized`、simplifile の `Unknown`、OCaml の `EUNKNOWNERR`、Flix の `Other`）。

出典:

- https://doc.rust-lang.org/std/io/enum.ErrorKind.html
- https://github.com/rust-lang/rust/blob/master/library/core/src/io/error.rs
- https://doc.rust-lang.org/reference/attributes/type_system.html
- https://peps.python.org/pep-3151/
- https://docs.python.org/3/library/exceptions.html
- https://pkg.go.dev/io/fs
- https://pkg.go.dev/net
- https://docs.deno.com/api/deno/~/Deno.errors
- https://hackage-content.haskell.org/package/base-4.22.0.0/docs/System-IO-Error.html
- https://nodejs.org/api/errors.html
- https://simplifile.hexdocs.pm/simplifile.html
- https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/FileSystemException.html
- https://github.com/flix/flix/blob/master/main/src/library/IoError.flix
- https://github.com/swiftlang/swift-evolution/blob/main/proposals/0192-non-exhaustive-enums.md
- https://ocaml.org/manual/api/Unix.html

【要検証】

- simplifile の `FileError` の構成子の正確な数と、Gleam で構成子を加えることの扱い。
- Rust で名前解決の失敗が、どの種類になるか。
- OCaml・Haskell・Elm に、型ごとに `_` を必須にする仕組みがないこと。

### 算術の失敗の扱い

[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md) の判断に使った。

| 言語 | 整数 | 溢れ | 0 による除算 | 型・エフェクトへの表れ | 失敗を値で返す版 |
|---|---|---|---|---|---|
| Koka | 任意精度 | 起きない | 0 を返す（`D/0 == 0`） | 算術には `exn` を付けない。明示的に部分的な関数（`unjust` など）に `exn` | — |
| Flix | 固定幅 | 文書に記載なし | 0 を返す | なし | 変換だけ `Option` |
| Gleam | Erlang では任意精度、JavaScript では倍精度の浮動小数 | Erlang では起きない | 0 を返す（`Int` と `Float`） | なし | `int.divide` などが `Result` |
| Elm | 32 bit の範囲で定義 | 実行環境による | `//` は 0 を返す。`modBy 0` は止まる | なし | — |
| Roc | 固定幅 | 止まる | — | なし | `plus_try` などが `Try`。回り込みと飽和の版もある |
| Pony | 固定幅 | 回り込む | 0 を返す | 部分的な演算子 `+?`・`/?` は `?` で型に現れる | `addc` などが組を返す |
| Swift | 固定幅 | 止まる（trap） | 止まる | なし | `&+` は回り込み |
| Rust | 固定幅 | デバッグでは panic、リリースでは回り込み | panic | なし | `checked_*`・`wrapping_*`・`overflowing_*`・`saturating_*` |
| Zig | 固定幅 | 不正な振る舞い（安全検査で止まる） | 不正な振る舞い | なし | `+%`（回り込み）・`+\|`（飽和） |
| Haskell | `Int` は固定幅、`Integer` は任意精度 | 報告書は未定義とする | 例外 `DivideByZero` | なし | — |
| OCaml | 63 bit | 回り込む | 例外 `Division_by_zero` | なし | — |
| Lean 4 | `Nat` は任意精度、固定幅の型もある | 固定幅は回り込む | `Nat` は 0 を返す | なし | — |
| Idris 2 | `Nat` | — | 除数が 0 でない証明を要する関数と、`partial` の関数がある | 証明と全域性の検査 | — |
| Python | 任意精度 | 起きない | 例外 `ZeroDivisionError` | なし | — |

- Koka の文書は、効果を持たない関数を `total` とし、「a `total` function is truly total in the mathematical sense」と書く。例外を投げうる関数を `exn`、停止しないかもしれない関数を `div` とする。
- Rust の RFC 560 は、整数の溢れを「a program error (but not undefined behavior in the C sense)」とし、溢れの扱いを型で区別する案を「Vec<u8> and Vec<u8c> are incompatible」として退けた。
- Flix の文書は、0 で割った値を 0 と定めたことを「Controversial」と書く。Pony の文書は「might lead to silent errors」と書く。
- Gleam の文書は「Gleam does not have partial functions and operators in core so instead division by zero returns zero.」と書く。

除数がリテラルの 0 の除算と、範囲を超える整数リテラルを、実行の前に報告するかは次のとおりである。

| 言語 | リテラルの 0 による除算 | 範囲を超える整数リテラル |
|---|---|---|
| GHC（Haskell） | 報告しない | 警告（`-Woverflowed-literals`） |
| OCaml | 報告しない | 誤り |
| Scala 3 | 報告しない（定数の畳み込みで例外が起きても黙る） | 【要検証】 |
| Erlang・Elixir | 警告（定数の畳み込みの副産物。「will fail with a 'badarith' exception」） | 整数は任意精度 |
| Elm・PureScript・Lean・Gleam・Koka | 0 で割った値を 0 と定めるので、該当しない | — |
| Rust | 誤り（既定で拒否する lint `unconditional_panic`） | 誤り（`arithmetic_overflow`） |
| Swift | 誤り | 誤り |
| Go | 誤り（仕様「If the divisor is a constant, it must not be zero.」） | 誤り |
| C# | 誤り（CS0020） | 【要検証】 |
| Kotlin | 警告 | 誤り |
| Java（javac） | 警告（`-Xlint:divzero`） | 【要検証】 |

- Scala 3 のコンパイラのソース（`ConstFold.scala`）は、定数の畳み込みで `ArithmeticException` が起きたときの扱いに「the code will crash at runtime, but that is better than the compiler itself crashing」と書く。

出典:

- https://koka-lang.github.io/koka/doc/std_core_int.html
- https://koka-lang.github.io/koka/doc/std_core_exn.html
- https://github.com/flix/flix/blob/master/docs/DIDYOUKNOW.md
- https://gleam-stdlib.hexdocs.pm/gleam/int.html
- https://tour.gleam.run/basics/ints/
- https://raw.githubusercontent.com/elm/core/master/src/Basics.elm
- https://www.roc-lang.org/builtins/Num
- https://tutorial.ponylang.io/expressions/arithmetic.html
- https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/AdvancedOperators.md
- https://doc.rust-lang.org/reference/expressions/operator-expr.html
- https://rust-lang.github.io/rfcs/0560-integer-overflow.html
- https://ziglang.org/documentation/master/
- https://www.haskell.org/onlinereport/haskell2010/haskellch6.html
- https://ocaml.org/manual/5.3/api/Stdlib.html
- https://lean-lang.org/doc/reference/latest/Basic-Types/Natural-Numbers/
- https://raw.githubusercontent.com/idris-lang/Idris2/main/libs/base/Data/Nat.idr
- https://docs.python.org/3/library/stdtypes.html
- https://downloads.haskell.org/ghc/latest/docs/users_guide/using-warnings.html
- https://ocaml.org/manual/latest/comp.html
- https://github.com/scala/scala3/blob/main/compiler/src/dotty/tools/dotc/typer/ConstFold.scala
- https://github.com/erlang/otp/blob/master/lib/compiler/src/sys_core_fold.erl
- https://doc.rust-lang.org/rustc/lints/listing/deny-by-default.html
- https://github.com/swiftlang/swift/blob/main/include/swift/AST/DiagnosticsSIL.def
- https://go.dev/ref/spec
- https://learn.microsoft.com/en-us/dotnet/csharp/misc/cs0020
- https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html

【要検証】

- Flix の整数の溢れの扱い（JVM の上で回り込むと見込まれる）。
- Roc の `div_trunc_by` の 0 による除算の扱い。
- Swift の 0 による除算の trap と `addingReportingOverflow`、Zig の `@addWithOverflow`。
- GHC の `Int` が回り込むこと。
- Unison の整数の溢れと 0 による除算の扱い。

### 構成子の修飾と名前空間

[ADR 0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md) の判断に使った。

| 言語 | Option・Result の書き方 | ほかの型の構成子 | 型と構成子の名前空間 | 期待される型から構成子を補うか |
|---|---|---|---|---|
| Rust | `Some`・`Ok`（prelude が再輸出する） | `Enum::V`（修飾する） | 分ける（型と値） | 補わない（RFC 3444 は未採択） |
| Swift | `.some`・`.success`、`nil` | `.case` か `Type.case` | 構成子は型のメンバー | 補う（先頭の `.`） |
| OCaml | `Some`・`Ok` | 修飾しない（モジュールでは修飾できる） | 分ける | 補う（型で決まらなければ最後に定義した型を選ぶ） |
| Haskell | `Just`・`Right` | 修飾しない | 分ける | 補わない |
| F# | `Some`・`Ok` | 修飾しない（`RequireQualifiedAccess` で修飾を必須にできる） | 分ける | 【要検証】 |
| Elm | `Just`・`Ok`（既定の import） | 修飾しない（モジュールでは修飾できる） | 分ける | 補わない |
| Gleam | `Ok` は組み込み、`Some` は import するか `option.Some` | 修飾しない（モジュールでは修飾できる） | 分けると見られる | 補わない |
| Roc | `Ok`・`Err`（Option はない） | `Red` か `Color.Red` | 修飾しない名前は構造的なタグ | 補う（期待される型で名前付きの型に決まる） |
| Scala 3 | `Some`・`Left`（パッケージ `scala`） | enum は `Color.Red`（`import Color.*` で省ける） | 分ける（型と項） | 補わない（提案は閉じられた） |
| Lean 4 | `some`（prelude が export する）、`Except.ok` | `T.c` | 階層を持つ一つの名前空間 | 補う（先頭の `.`） |
| Kotlin | `Result.success(..)`（関数で作る） | `Sealed.Sub` | ─ | 試験的に補う（2.2 以降。通常の解決が失敗したときだけ） |
| Koka | `Just`・`Ok` | 修飾しない | 型は小文字、構成子は大文字 | 【要検証】 |

- Rust の RFC 390 は、列挙の構成子を修飾する理由を「Enums are the odd one out」と、手で名前に接頭辞を付ける慣習の解消に求めた。prelude の文書は、`Option` について「its variants are also exported」と書く。
- OCaml のマニュアルは、型の分からない構成子を最後に定義した型から選ぶ規則について、型の定義の追加や移動、モジュールを開いたことで「may change surreptitiously」と警告する。
- Scala 3 の先頭の `.` の提案（PR #23801）に、Odersky は「code writers will use it and most likely abuse it, whereas code readers will hate it」と書いた。
- Kotlin の KEEP は、Swift のような先頭の `.` を「Code that compiled perfectly may now have an ambiguous reading」として採らなかった。
- Haskell 2010 の報告書は「`Int` may simultaneously be the name of a module, class, and constructor within a single scope」と書く。OCaml のマニュアルは、名前空間を「distinguished both by the context and by the capitalization」とする。
- Java の言語仕様 7.1 は「A package may not contain two members of the same name, or a compile-time error results.」と書き、パッケージ `mouse` にクラス `Button` があれば `mouse.Button` という名前のパッケージは置けないとする。Rust の Reference は、モジュールの宣言と構造体・列挙などを同じ型の名前空間に入れる。

出典:

- https://doc.rust-lang.org/std/prelude/index.html
- https://doc.rust-lang.org/reference/names/namespaces.html
- https://rust-lang.github.io/rfcs/0390-enum-namespacing.html
- https://github.com/rust-lang/rfcs/pull/3444
- https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/Expressions.md
- https://ocaml.org/manual/5.3/names.html
- https://ocaml.org/manual/5.3/coreexamples.html
- https://www.haskell.org/onlinereport/haskell2010/haskellch1.html
- https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/discriminated-unions
- https://raw.githubusercontent.com/elm/core/master/README.md
- https://tour.gleam.run/data-types/results/
- https://raw.githubusercontent.com/roc-lang/roc/main/docs/langref/tag-unions.md
- https://docs.scala-lang.org/scala3/reference/enums/enums.html
- https://github.com/scala/scala3/pull/23801
- https://lean-lang.org/doc/reference/latest/Terms/Identifiers/
- https://github.com/Kotlin/KEEP/blob/main/proposals/KEEP-0379-context-sensitive-resolution.md
- https://raw.githubusercontent.com/koka-lang/koka/master/lib/std/core/types.kk
- https://docs.oracle.com/javase/specs/jls/se21/html/jls-7.html

【要検証】

- F# と Koka で、期待される型から構成子を補う仕組みがないこと。
- Gleam で、型と構成子の名前空間が分かれていること（import の書き方からの推定）。
- Rust で、同じモジュールに同じ名前のモジュールと型を宣言すると誤りになること。
- F#・Scala 3・TypeScript・C# などで、同じ場所に同じ名前の型とモジュール（またはコンパニオンオブジェクト、名前空間）を置けるか。

### 権限の対象の範囲を型や値で表す仕組み

[OPEN-052](../open-issues.md#open-052) の、操作の対象（パス、ホスト、ポート）の範囲を型の側で表す候補と、[OPEN-051](../open-issues.md#open-051) の、外部の関数のエフェクトを WASM のモジュールが取り込む関数から求める候補の検討に使う。本節の事実は、2026-10-01 に一次資料で確かめた。

| 系 | 権限やエフェクトを表す場所 | 具体的な対象を名指せるか | 強制の時期 |
|---|---|---|---|
| Scala 3 の capture checking | 型（捕捉する能力の集合）と、能力の値 | 型では名指せない（型が追跡するのは、どの変数の能力を捕捉するか）。TACIT（次節）はパスやホストを実行時の値として渡す | 能力の寿命と純粋性は静的。範囲は実行時 |
| Effekt | 型（計算が文脈から要求する能力）と、第二級の能力の受け渡し | 名指す仕組みは見当たらない | 静的 |
| Koka | 型（エフェクトの行） | 名指せない。`net`・`fsys` などのエフェクトは引数をとらず、引数をとるのはヒープの `alloc`・`read`・`write`（ヒープの添字）だけ | 静的 |
| Unison | 型（ability）。組み込みの `IO` は粗い一つの ability | 名指す仕組みは見当たらない | 静的 |
| Roc | 型は純粋な `->` と作用のある `=>` の区別だけ。I/O の基本の操作はすべて platform が持つ | 型では名指せない。platform の実装で制限できる | 純粋性は静的。範囲は platform が実行時に決める |
| Austral | 線形型の能力の値。型は種類だけ（`Path` など） | 値で名指せる（根の `Filesystem` から下位のディレクトリやファイルへ降りる。親へは上がれない） | 線形性は静的。範囲は値の作り方による |
| Pony | 権限の証票の型（`AmbientAuth` から `NetAuth`・`TCPAuth`・`TCPConnectAuth` へ段階的に作る）と、`FilePath` の値 | `FilePath` で名指せる（base の内側だけを作れ、権限は積集合になる）。ホストを絞る型はない | 証票の有無は静的。パスの包含は実行時 |
| E・Joe-E | オブジェクトの参照 | 値で名指せる（ファイルか上位のディレクトリへの参照を持つときだけ、ファイルを扱える） | Joe-E は検査器が、ambient authority を与える API を除いた部分集合を静的に検査する。範囲は参照の到達可能性 |
| Capsicum（FreeBSD） | OS のファイルディスクリプタと、その権利 | ディスクリプタ単位で名指せる（`openat` 系は渡したディレクトリの下に限る） | 実行時（カーネル） |
| WASI・Component Model | 取り込み（リンクのとき）とハンドル（値） | 実行時の設定で名指せる（wasmtime の `preopened_dir`・`socket_addr_check`） | リンクのとき（取り込みを与えなければリンクに失敗する）と実行時 |
| Deno（型ではない参考） | 実行時のフラグ | 名指せる（`--allow-net=github.com,jsr.io`、`"*.example.com"`、ホストにポートを付けてよい、パス） | 実行時 |
| Extism（型ではない参考） | manifest | 名指せる（`allowed_hosts`、`allowed_paths`） | 実行時 |

- 調べた範囲では、エフェクトや能力の型に具体的なパス・ホスト・ポートを書き、その包含を静的に判定する言語と研究はなかった。対象の範囲は、能力の値の中に持たせる（Austral、Pony、E・Joe-E、TACIT、WASI のハンドル）か、実行時の設定で絞る（Deno、Extism、wasmtime、Roc の platform）かのどちらかである。
- Scala 3 の capture checking は、型 `T^{c1, …}` で値が参照する能力の集合を追跡し、純粋な関数 `A -> B` と、何でも捕捉してよい関数 `A => B` を区別する。Xu・Bračevac・Pham・Odersky の "What's in the Box"（arXiv 2509.07609）は、その計算体系 System Capless の型の健全性の証明を Lean で機械化したと述べる。Pham ほかの "Classifying Capabilities"（arXiv 2607.24504）は、能力を役割で分類する木を導入する。分類の対象は能力の種類であり、資源の場所ではない。
- Brachthäuser・Schuster・Ostermann の "Effects as Capabilities"（OOPSLA 2020）は、エフェクトの型を、計算が文脈から要求する能力として読む（要旨は "In Effekt, effect types express which _capabilities_ a computation requires from its context."）。Effekt は、コンソールへの出力などの組み込みの副作用を、エフェクトではなく第二級の資源として追跡する。
- Koka の `io` は別名 `<exn,ioc>` である。
- Roc の文書は、platform が I/O の基本の操作をすべて持つので、platform が保証を与えられると述べる（"There are no escape hatches..."）。例として、開いたディレクトリの外のファイルの I/O の前に利用者に確認を求めるプラグインの platform を挙げる。
- Austral の仕様は、ファイルシステム全体の能力の下に、特定のディレクトリやファイル、特定のホストへの能力を持てると述べる。能力を何もないところから作らないという制約は、言語ではなくライブラリの作者が守る（"The fourth restriction must be implemented manually by the programmer."）。
- Pony のコンパイラは、`--safe` で C の FFI を使えるパッケージを制限できる。
- Miller の博士論文 "Robust Composition"（2006）は、名前で対象を指す方式（`cp foo.txt bar.txt` は文字列を受け取るので、ファイルシステム全体の権限が要る）と、鍵で指す方式（`cat < foo > bar` は開いたディスクリプタを受け取る）を対比し、参照で指す言語は、指すことと使う権限を束ねる後者に立つと述べる。
- Joe-E（Mettler・Wagner・Close、NDSS 2010）は Java の部分集合で、可変な大域の状態を禁じ、`File(String)` のように ambient authority を与える API を除く。
- Capsicum は `cap_enter(2)` で能力モードに入ると、大域の名前空間（ファイルシステム、PID など）を使えなくなり、元に戻せない。ディスクリプタごとの権利は `cap_rights_limit(2)` で絞る。
- WASI の設計原則は、WASI に ambient authority がなく、実行時の大域の名前空間とリンクのときの大域の関数がないと述べる。ハンドルを取らない関数は、差し替えで機能を弱められる（attenuation）。Component Model の world は、部品が提供するもの（export）と要求するもの（import）の契約であり、取り込むインターフェースは外のコードが満たす。
- wasmtime の `Linker` は、既定では定義されていない取り込みがあるとインスタンス化に失敗し、`UnknownImportError` を返す。`define_unknown_imports_as_traps`（呼ぶと trap する関数で埋める）などで、欠けた取り込みを埋めて続けることもできる。`WasiCtxBuilder` は、既定ではファイルシステムを与えず、`preopened_dir` で与えるディレクトリを指定し、`socket_addr_check` でソケットのアドレスごとに判定する関数を指定する。
- モジュールの取り込みの集合から、そのモジュールの権限やエフェクトを自動で求めて示す道具や実行環境は、見つからなかった。

【要検証】

- Unison で、利用者が細かい ability を定義して `IO` のハンドラで解釈する書き方を公式が推奨しているか。
- F\* と Liquid Haskell に、パスやホストで添字付けした権限の例があるか。"Controlling File Access with Types"（ENTCS 332、2017）の内容（要旨しか読めなかった）。
- エージェント向けの言語 ETAS（arXiv 2607.17780）が、操作の対象を型の引数にとるか（要旨しか読めなかった）。
- Extism の `allowed_hosts` のワイルドカードの書式。
- "What's in the Box" の採録先（DOI 10.1145/3763112）。

出典

- https://docs.scala-lang.org/scala3/reference/experimental/cc.html
- https://docs.scala-lang.org/scala3/reference/experimental/capture-checking/classifiers.html
- https://arxiv.org/abs/2509.07609
- https://arxiv.org/abs/2607.24504
- https://pl.cs.uni-tuebingen.de/publications/brachthaeuser20effects/
- https://effekt-lang.org/docs/concepts/effect-handlers
- https://raw.githubusercontent.com/koka-lang/koka/master/lib/std/core/types.kk
- https://www.unison-lang.org/docs/fundamentals/abilities/using-abilities-pt2
- https://www.roc-lang.org/platforms
- https://austral-lang.org/spec/spec.html
- https://stdlib.ponylang.io/files-FilePath/
- https://tutorial.ponylang.io/object-capabilities/trust-boundary.html
- https://www.ndss-symposium.org/wp-content/uploads/2017/09/met.pdf
- https://man.freebsd.org/cgi/man.cgi?query=capsicum&sektion=4
- https://github.com/WebAssembly/WASI/blob/main/docs/DesignPrinciples.md
- https://component-model.bytecodealliance.org/design/worlds.html
- https://docs.wasmtime.dev/api/wasmtime/struct.Linker.html
- https://docs.wasmtime.dev/api/wasmtime_wasi/struct.WasiCtxBuilder.html
- https://extism.org/docs/concepts/manifest/
- https://docs.deno.com/runtime/reference/permissions/

### AI エージェントの権限制御の研究

[OPEN-052](../open-issues.md#open-052) の検討に使う。LLM エージェントが行う操作を、OS のサンドボックスではなく、能力・エフェクト・情報フローのラベル・権限の方針で制御する研究を調べた。本節の事実は、2026-10-01 に各論文の原典（arXiv の本文。読んだ範囲は各項に記す）で確かめた。

| 研究 | 方式 | 強制の時期 | 具体的な対象 | 人間の承認 | 形式的な結果 |
|---|---|---|---|---|---|
| TACIT（"Tracking Capabilities for Safer Agents"） | Scala 3 の capture checking で能力を型で追跡する。エージェントはツールを直接呼ばず、能力を安全に扱う部分集合の Scala でコードを書く | 静的（能力の寿命と純粋性）と実行時（範囲） | ディレクトリの根、コマンドの名前、ホストの名前（ポートの記述はない） | 実行環境を、エージェントを起動する前に人間が確かめるとする一文がある | 新しい定理はない。基盤の capture checking の機械化された健全性の証明に拠る |
| PORTICO（"Lingering Authority"） | エージェントとツールの間の参照モニタ。小目標ごとに与えた権限を、信頼できる事象で閉じる | 実行時 | パス単位の許可と拒否、ホスト（ポートの記述はない） | 人間の承認は、権限の付与と閉鎖を起こせる信頼できる事象の一つ | 保証を定義し、散文で論証する。機械化はない |
| λ_A | エージェントの構成を表す型付きのラムダ計算 | 権限の制御はしない | なし | なし | 型安全性と停止性などを Coq で機械化（エフェクトの型は将来の課題） |
| Governed Execution | Rocq の Interaction Trees で、すべての外部の作用が統治の境界を通ることを形式化する | 能力の集合は静的、検査は実行時 | なし（能力は種類の粒度） | 記述はない | Rocq で証明。モジュールの数は要旨と本文で食い違う |
| APPA | 情報フローのラベルの束と、ツールの契約。汚染を子の分岐に閉じ込める | 実行時（ツールを呼ぶ前の検査） | 読み手の集合（宛先）とツール単位の契約。パスやホストの記法はない | 強い制限の解除は、承認する部品の裁定を要する | 命題と定理を付録で証明する。機械化はない |
| IntentCap | 利用者の意図などの情報源ごとに、決定する欄の所有者を一つに定めた権限の lease を作り、決定的な検査器で検査する | 実行時（MCP の gateway と、eBPF による OS の方針） | 利用者が選んだファイル、名指しの宛先 | 利用者が構造化した入力で権限の上限を与える | 定理はない |
| CaMeL | 二つの LLM を分け、独自の Python のインタプリタがデータフローと値ごとのタグを追跡する | 実行時（ツールを実行する前） | 値の読み手の集合。方針は任意の Python の関数 | 方針に反する実行は利用者の確認を求める想定 | 形式検証は今後の課題 |
| FIDES | エージェントの計画器が、機密性と完全性のラベルを動的に追跡する | 実行時 | 受信者の集合 | 記述はない | 非干渉などを紙の上で示す |
| Progent | ツールの名前と引数に対する記号的な方針の言語。拡大は SMT ソルバで判定し、承認を要する | 実行時 | 引数への条件（正規表現、集合の要素）で宛先やパスを縛れる | 方針を広げる更新は承認を要する（自動の拒否・承認、人間のレビューなどを設定できる） | 承認なしに許可が増えない性質を主張する。機械化はない |

- TACIT（Odersky・Zhao・Xu・Bračevac・Pham。arXiv 2603.00991、ACM CAIS 2026、DOI 10.1145/3786335.3813127）
  - エージェントは、能力を `requestFileSystem(root){ fs => … }` のような形で受け取り、ブロックの外へ持ち出せない。純粋な関数だけを受け取る `Classified[T].map` で、機密のデータを漏らせないようにする。エージェントに見える出力では `Classified` の中身を伏せ、利用者の端末にだけ実際の内容を出す。root の外のパスは実行時に例外にする（"Paths outside root are rejected at runtime with a SecurityException."）。
  - 実装は MCP のサーバ（Scala 3 のコンパイラ、REPL、ライブラリ）である。外部のプロセスは境界の外にあり、そこでの保証は許可の一覧の水準に下がるので、サンドボックスとの併用を勧める。
  - 評価では、独自の安全性のベンチマーク（AgentDojo の攻撃の手法を使う）で、機密のデータを `Classified` にした設定の安全性が二つのモデルで 100% だった。
  - 実装は、EPFL の研究室が GitHub の `lampepfl/TACIT` で Apache-2.0 のライセンスで公開している。ビルド済みの JAR と CLI（`tacit`）があり、MCP に対応したエージェント（Claude Code、OpenCode、GitHub Copilot など）から接続できるとする。リポジトリは、safe mode と capture checking が実験的な機能であり（"Safe mode is an experimental feature still under active development."、"Capture checking is experimental."）、Scala 3 の nightly 版を使うのでコンパイラの振る舞いが版ごとに変わりうると述べる。論文は、safe mode が約束を満たすことの意味論的な健全性の論証を、今後の課題とする。
  - パスやコマンドのパターンによる許可の規則を、文脈に応じた方針を表せない粗い仕組みとして評する（"Pattern-based permission rules (allowlists or blocklists over paths or commands) are coarse-grained and cannot capture context-sensitive policies."）。サンドボックスは、許可した操作の中の情報フローを制御できないと述べる。
- PORTICO（Santos-Grueiro。arXiv 2606.22504、2026-06）
  - 一つの小目標のために与えた一時的な権限が、小目標を終えた後も残る問題（lingering authority）を扱う。権限の付与は世代に結び付いた不透明なハンドルとして発行し、テストの成功、小目標の完了、取り消しなどの信頼できる事象で閉じる。閉じたハンドルは計画器の次のインターフェースから消え、再利用は副作用の前に拒否する。
  - シェルの呼び出しは、ツールの表で操作の対象と効果を取り出して検査し、分類できないコマンドは明示の承認を求めるか拒否する。
  - 取り消しはモデルの記憶を消さず、変わるのは呼び出せる能力の一覧だけであると述べる。
- λ_A（Liu。arXiv 2604.11767、2026-04）
  - エージェントの構成ファイル（YAML）をラムダ計算に翻訳して検査する。エフェクトは暗黙に扱い（LLM とツールの呼び出しを IO、記憶を状態とする）、型とエフェクトの体系は将来の課題として素描する。
- Governed Execution（McCann。arXiv 2605.01032、2026-05）
  - 外部の作用（LLM の呼び出し、HTTP の要求、ファイルの操作など）を 14 種の指令で表し、各 I/O の前に統治の検査を挿入するハンドラの変換を定める。能力の集合が空のプログラムは、観測のための指令しか出せないことを示す。能力の集合は作用を静的に限り、統治はすべての作用が検査を通ることを動的に保証すると述べる。
- APPA（Kravchenko ほか、Archestra AI。arXiv 2607.24625、2026-07）
  - 動的な情報フローの追跡では、制限されたデータを一度読むと文脈のラベルが恒久的に下がり、以降のツールを使えなくなる（label creep）。APPA は、一回の呼び出しだけを許す裁定と、汚染を子の分岐に閉じ込めて検査済みの値だけを親に戻す仕組みで、これを避ける。
  - 評価は独自のベンチマーク（14 の場面、4 つのモデル）で、攻撃の成功率は防御のない基準の 31〜50% から 0〜7% に下がった。
- IntentCap（Zheng・Zhang・Mao。arXiv 2609.14631、2026-09。短い論文）
  - 利用者の要求、ツールの結果、文書、Skill や MCP の指示がすべて同じ経路で計画に入ると、どの情報源も宛先などの決定する欄を埋められる、という問題を扱う。LLM を信頼しないコンパイラとして権限の lease を提案させ、決定的な検査器が欄ごとの所有者と、権限が狭まる向きにだけ変わることを検査する。
  - 能力は実行時に複数の情報源から合成しなければならず、合成を静的に宣言するプログラマはいない、という立場をとる（"no programmer exists to declare the composition statically."）。
- CaMeL（Debenedetti ほか。arXiv 2503.18813、2025）
  - 信頼できる利用者の問い合わせだけを見てコードを書く LLM と、ツールを持たず構造化した出力だけを返す LLM を分ける。独自のインタプリタが値の出どころと読み手を追跡し、方針に反するツールの呼び出しを実行の前に止める。AgentDojo の課題の 77% を、証明できる安全性のもとで解いたと報告する。プロンプトインジェクションが完全に解決したわけではないと述べる。
- FIDES（Costa ほか、Microsoft。arXiv 2505.23643、2025）
  - 計画器が機密性と完全性のラベルを追跡し、ツールと引数ごとの方針と比べる。制限の強い結果は変数に隠して文脈を汚さない。ツールの呼び出しにだけ方針を強制するので、テキストからテキストへの攻撃は止められないと述べる。
- Progent（Shi ほか。arXiv 2504.11703、2025〜2026）
  - ツールの名前と引数に対する許可・禁止の規則を書く言語で、どの規則にも当たらない呼び出しは拒否する。LLM が利用者の課題から初期の方針を作り、実行中の更新は SMT ソルバで狭める向きか広げる向きかを判定し、広げる向きは承認を要する。

【要検証】

- TACIT の ACM 版の本文と、arXiv の v2 との差（ACM のページを読めなかった）。TACIT で、ハーネスがエージェントの要求できる対象の上限を外から縛る仕組みがあるか。
- IntentCap と CaMeL の採録先。
- Governed Execution の Rocq のモジュールの数（要旨は 32、本文の結論は 36）。

出典

- https://arxiv.org/html/2603.00991
- https://github.com/lampepfl/TACIT
- https://dl.acm.org/doi/10.1145/3786335.3813127
- https://arxiv.org/html/2606.22504
- https://arxiv.org/html/2604.11767
- https://arxiv.org/html/2605.01032
- https://arxiv.org/html/2607.24625v1
- https://arxiv.org/html/2609.14631v1
- https://arxiv.org/html/2503.18813
- https://arxiv.org/html/2505.23643
- https://arxiv.org/html/2504.11703

## 未決事項

- [OPEN-014](../open-issues.md#open-014): 参考にした言語に関する外部の事実の確認（本章の【要検証】の事項）
- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細（取り込む関数からエフェクトを求める候補）
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の対象の書き方と判定の時点、対象の範囲を型の側で表す候補）
- [OPEN-056](../open-issues.md#open-056): 自前のコーディングエージェントの設計（エージェントの操作を Benitoite のスクリプトに限る候補）
