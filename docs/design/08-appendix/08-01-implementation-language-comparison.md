# 実装言語の比較

処理系の実装言語に Rust を選んだ根拠となる、Rust と他の言語（Go・Zig・Swift・Haskell）との比較である。

## 目的と範囲

本章は、比較の観点、観点ごとの各言語の事実、Rust を選んだ根拠を示す。実装言語は、処理系のコードを書く前に Go から Rust に改めた。性能を理由に実装言語を見直す段階は設けないので、再実装の候補で得るものと失うものの比較は扱わない。

## 前提

比較に使う外部の事実は、一次資料で確かめたものに出典を添えた。確かめていない事実は、文の中で「確かめていない」と書く（確認は docs/todo の TODO-010）。

処理系の性能は、測定するまで判断できない（[性能](../07-quality/07-02-performance.md)）。このため、実行速度の見込みは比較の観点に含めるが、選定の根拠にはしない。

## 仕様

### 比較の観点

処理系の性質から、比較の観点を次の八つとする。

| 観点 | 処理系の性質 |
|---|---|
| メモリの回収 | 言語の値（ラムダが捕捉した環境、永続データ構造、可変のセルと明示遅延の値）はヒープに置く。可変のセルを使えば、値どうしの参照が循環しうる。処理系は、循環する値の扱いを決める必要がある（初回リリース版はマーク・スイープで回収する） |
| 型システム | 処理系は、構文木・値・命令など、種類の決まったデータを多く扱う。種類を加えたときの処理の漏れを、実装言語の検査で見つけられるかが、LLM が書く処理系の堅牢さに関わる |
| ホストの標準ライブラリの利用 | Go で実装する計画のときは、Go の標準ライブラリの API を型の情報から自動でラップする層（go.* の層）を設ける予定だった。この層は廃止した |
| WASM | 処理系を WASM で動かす可能性がある |
| 並行処理 | 処理系は、並行処理をホストの仕組みの上に作る |
| OS のサンドボックス | 実行時の権限制御を OS のサンドボックスでも強制する案を検討している（docs/todo の TODO-148）。初回リリース版はこれを含めない |
| 配布 | 処理系を単一の実行ファイルとして、複数の OS に向けて配る（[配布形態](../05-platform/05-01-distribution.md)） |
| 実装を担う LLM の生成精度 | 処理系は設計者が手で書かず、LLM が書く |

### 比較の一覧

観点ごとの比較を次の表にまとめる。各欄の事実の出典は、次節の「各言語の性質」に示す。

| 観点 | Go | Rust | Zig | Swift | Haskell（GHC） |
|---|---|---|---|---|---|
| メモリの回収 | ランタイムの GC に任せられる | GC はない。`Rc` は循環を解放しない。GC を自作するか、外部のクレートに頼る | 言語はメモリを管理しない。GC をすべて自作する | ARC。強い参照の循環はリークする。処理系の側で循環に手当てが要る | ランタイムの世代別のコピー GC に任せられる。循環する値も回収される |
| 型システム | 直和型がなく、`switch` は分岐の網羅を求めない | 列挙型を持ち、`match` は網羅を求める | 確かめていない | 確かめていない | 代数的データ型を持つ。パターンの網羅の検査は警告（`-W` で有効）で、`-Werror` で誤りにできる |
| go.* の層（廃止） | `go/types` と `go/packages` を前提に作れた | 層を設計し直す必要があった | 同左 | 同左 | 同左 |
| 並行処理 | `go` 文とチャネルが言語に組み込まれている | 標準ライブラリに非同期処理の実行器がなく、Tokio などを選ぶ。処理系は、一つのスレッドで動く自作のスケジューラと `mio` のイベントループを採った | `async`・`await` は削除され、0.16.0 で `std.Io` を導入した | actor と構造化並行性が言語に組み込まれている | 軽量スレッド（`forkIO`）と STM を持つ。既定のランタイムは一つの OS のスレッドで軽量スレッドを動かす |
| OS のサンドボックス | Landlock の Go 用ライブラリが、Go のランタイムが管理する全スレッドに設定を適用する | ランタイムがスレッドを持たないので、スレッドを作る前に掛けられる（確かめていない） | 同左（確かめていない） | 確かめていない | 既定のランタイムは OS のスレッドが一つ。`-threaded` のランタイムは起動時にスレッドを持つとされ（確かめていない）、その場合に Landlock を全スレッドに掛けるには ABI 8 の `LANDLOCK_RESTRICT_SELF_TSYNC` が要る |
| WASM の対象 | 確かめていない | `wasm32-unknown-unknown`・`wasm32-wasip1`・`wasm32-wasip2` が、標準ライブラリを含む Tier 2 の対象 | 確かめていない | 確かめていない | `wasm32-wasi` のバックエンドがあるが、技術プレビューで公式の配布物に含まれない |
| 配布 | 既定で静的にリンクし、`GOOS`・`GOARCH` で対象を選ぶ | musl の対象は既定で C のランタイムを静的にリンクする | 多数の対象の libc を同梱し、クロスコンパイルを第一級の用途とする | Swift 6 から、Linux 向けに完全に静的にリンクできる | GHC は Alpine（musl）向けの配布物を持つ。完全に静的にリンクした実行ファイルを作る手順は確かめていない |
| 言語の版（2026-09-26 時点の最新） | go1.27.1 | 1.98.1 | 0.16.0（1.0 の前） | —（確かめていない） | GHC 9.14.1（2025-12-19。2026-09-29 に確認） |
| LLM の生成精度のベンチマーク | Aider polyglot、MultiPL-E | Aider polyglot、MultiPL-E | 見つからなかった | MultiPL-E | MultiPL-E（Aider polyglot は含まない） |
| 実行速度 | 測定するまで比べない | 同左 | 同左 | 同左 | 同左 |

ベンチマークの欄は、その言語を含む公開のベンチマークがあるかだけを示し、生成精度の高さを示すものではない（後述の「実装を担う LLM の生成精度」）。

### 各言語の性質

各言語について、観点ごとに確かめた事実を示す。

**Go**（最新の安定版は go1.27.1、2026-09-01。[リリース履歴](https://go.dev/doc/devel/release)）

- メモリの回収: Go の標準のツールチェーンは、すべてのアプリケーションに、GC を含むランタイムを同梱する（[GC ガイド](https://go.dev/doc/gc-guide)）。処理系は、言語の値の回収を Go の GC に任せられる。
- ホストの標準ライブラリの利用: 標準ライブラリの `go/types` は Go のパッケージを型検査し、パッケージの宣言と型の情報を取り出せる（[go/types](https://pkg.go.dev/go/types)）。`golang.org/x/tools/go/packages` はパッケージを読み込む（[go/packages](https://pkg.go.dev/golang.org/x/tools/go/packages)）。go.* の層の自動ラップは、この二つを前提に設計していた。
- 並行処理: goroutine を起動する `go` 文とチャネルの型が、言語に組み込まれている（[言語仕様](https://go.dev/ref/spec#Go_statements)）。
- 配布: gc ツールチェーンのリンカは、既定で静的にリンクした実行ファイルを作る。対象の環境は `GOOS` と `GOARCH` で選び、cgo は `CGO_ENABLED=0` で無効にできる（[Go の FAQ](https://go.dev/doc/faq)、[ソースからのインストール](https://go.dev/doc/install/source)、[cmd/cgo](https://pkg.go.dev/cmd/cgo)）。
- 型システム: 言語仕様に直和型はなく、`switch` 文は分岐を網羅することを求めない（[言語仕様](https://go.dev/ref/spec#Switch_statements)）。
- OS のサンドボックス: Landlock の Go 用ライブラリは、パスの制限を掛けるときに、Go のランタイムが管理する全スレッドに「新しい特権を得ない」の設定をする（[go-landlock](https://pkg.go.dev/github.com/landlock-lsm/go-landlock/landlock)）。
- 不利な点: `goto` の飛び先は同じ関数の中のラベルに限られ、飛び先を値として扱えない（[言語仕様](https://go.dev/ref/spec#Goto_statements)）。C で書いたインタプリタが使う computed goto によるディスパッチは書けない。これに加えて、配列の境界検査、interface を経由する値の表現、GC のライトバリアが評価の繰り返しの費用になり、Go で書いたインタプリタは C で書いた同種の処理系より遅い傾向があるという見込みがあるが、確かめていない。

**Rust**（最新の安定版は 1.98.1、2026-09-03。[リリースの告知](https://blog.rust-lang.org/2026/09/03/Rust-1.98.1/)）

- メモリの回収: Rust は GC を使わずにメモリの安全を保証する（[The Rust Programming Language 4 章](https://doc.rust-lang.org/book/ch04-00-understanding-ownership.html)）。参照カウントの `Rc` は、循環すると解放されない（[std::rc](https://doc.rust-lang.org/std/rc/index.html)）。循環しうる言語の値を回収するには、処理系が GC を自作するか、GC を提供する外部のクレートを使う必要がある。
- 並行処理: 標準ライブラリは非同期処理の実行器を提供せず、Tokio などを選んで使う（[Asynchronous Programming in Rust](https://rust-lang.github.io/async-book/part-guide/async-await.html)）。
- 型システム: `match` は網羅的であり、すべての場合を扱わないコードは正しいコードにならない（[The Rust Programming Language 6.2 章](https://doc.rust-lang.org/book/ch06-02-match.html)）。
- WASM: `wasm32-unknown-unknown`・`wasm32-wasip1`・`wasm32-wasip2` は、標準ライブラリを含む Tier 2 の対象である（[Platform Support](https://doc.rust-lang.org/rustc/platform-support.html)）。
- 配布: C のランタイムを静的にリンクするかは `crt-static` の設定で決まり、`x86_64-unknown-linux-musl` などの対象は既定で静的にリンクする（[The Rust Reference: Linkage](https://doc.rust-lang.org/reference/linkage.html)）。`x86_64-unknown-linux-musl` は Tier 2 の対象であり、Rust のプロジェクトが標準ライブラリのバイナリを提供する（[Platform Support](https://doc.rust-lang.org/rustc/platform-support.html)）。
- その他: WASM のランタイムの wasmtime と wasmer は、主に Rust で書かれている（各リポジトリの言語の集計）。

**Zig**（最新のリリースは 0.16.0、2026-04-13。1.0 に達していない。[ダウンロード](https://ziglang.org/download/)）

- メモリの回収: Zig はプログラマに代わってメモリを管理せず、ランタイムを持たない。既定のアロケータはなく、確保する関数はアロケータを引数で受け取る（[言語リファレンス 0.16.0](https://ziglang.org/documentation/0.16.0/#Memory)）。処理系は GC をすべて自作する必要がある。
- 並行処理: `async` と `await` のキーワードは 0.15.1 で削除され、I/O をインターフェースとして渡す `std.Io` が 0.16.0 で導入された（[0.15.1 のリリースノート](https://ziglang.org/download/0.15.1/release-notes.html)、[0.16.0 のリリースノート](https://ziglang.org/download/0.16.0/release-notes.html)）。1.0 の前なので、言語と標準ライブラリはまだ変わりうる。
- 配布: クロスコンパイルを第一級の用途として扱い、多数の対象に向けた libc を同梱する（[Zig の概要](https://ziglang.org/learn/overview/)）。

**Swift**

- メモリの回収: Swift は自動参照カウント（ARC）を使う。強い参照が循環するとリークし、`weak` か `unowned` の参照で循環を断つ（[The Swift Programming Language: ARC](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)）。循環しうる言語の値を回収するには、Rust と同じく処理系の側で手当てが要る。
- 並行処理: 非同期処理と並列処理を言語が組み込みで支援し、actor と構造化並行性を持つ（[The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)）。
- 配布: Swift 6 から、Linux 向けに完全に静的にリンクした実行ファイルを作れる。この SDK は musl の上に作られている（[Swift 6 の発表](https://www.swift.org/blog/announcing-swift-6/)、[Static Linux SDK](https://www.swift.org/documentation/articles/static-linux-getting-started.html)）。

**Haskell（GHC）**（最新のリリースは GHC 9.14.1、2025-12-19。[GHC のページ](https://www.haskell.org/ghc/)、[配布物の一覧](https://downloads.haskell.org/~ghc/)。2026-09-29 に確認）

- メモリの回収: GHC のランタイムは、既定で、すべての世代にコピー方式の世代別の GC を使う。最も古い世代には、並行に動くマーク・スイープの GC（`--nonmoving-gc`）も選べる（[GHC User's Guide: Running a compiled program](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/runtime_control.html)）。処理系は、言語の値の回収を GHC の GC に任せられ、循環する値も回収される。Go と同じ利点であり、循環する値を回収する仕組みを自作しなくて済む（Rust で書いた初回リリース版は、マーク・スイープを自作した）。
- 型システム: 代数的データ型とパターンマッチを持つ。パターンの網羅を確かめる警告 `-Wincomplete-patterns` は既定では有効でなく、`-W`（と `-Wall`）で有効になる（[GHC User's Guide: Warnings](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/using-warnings.html)）。警告を誤りにする指定（`-Werror`）を加えれば、Rust の網羅の検査に近い効果を得られる。ラムダとパターンの束縛には別の警告 `-Wincomplete-uni-patterns` がある（同）。
- 並行処理: 既定のランタイムは、一つの OS のスレッドの上で動く。この既定のランタイムでも、Haskell のスレッドどうしの並行処理は使える。複数の OS のスレッドを使うには `-threaded` でリンクする（[GHC User's Guide: Options related to a particular phase](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/phases.html)）。処理系の自作のスケジューラを GHC の軽量スレッドに置き換えるかは、言語処理系の主要部を自作する方針（[目的と設計原則](../00-overview/00-01-goals.md)）とあわせて判断が要る。
- OS のサンドボックス: Landlock の `landlock_restrict_self` は、既定では呼んだスレッド（と、その後に作るスレッド）だけを制限する。ABI の版 8 から、フラグ `LANDLOCK_RESTRICT_SELF_TSYNC` で、プロセスのすべてのスレッドに掛けられる（[Linux カーネルの文書: Landlock](https://docs.kernel.org/userspace-api/landlock.html)）。GHC の既定のランタイムは OS のスレッドが一つなので、子プロセスで自分に制限を掛ける方式と両立する。`-threaded` のランタイムが `main` の前に OS のスレッドを作るかと、それが古いカーネルで制限の漏れになるかは確かめていない。
- WASM: GHC は `wasm32-wasi` を対象とするバックエンドを持つ。ただし、技術プレビューの扱いで公式の配布物に含まれず、WASM を対象にビルドした GHC が別に要る。ランタイムは一つのスレッドで動く（[GHC User's Guide: WebAssembly backend](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/wasm.html)）。
- 配布: GHC 9.14.1 の配布物には、macOS（arm64・x86_64）と、Alpine Linux（musl。x86_64 と aarch64）向けのものがある。x86_64 の Alpine 向けには、GHC 自身を静的にリンクした配布物もある（[9.14.1 の配布物](https://downloads.haskell.org/~ghc/9.14.1/)）。処理系を完全に静的にリンクした実行ファイルとして作る手順、その実行ファイルが Alpine の外の Linux で動くか、GHC がリンクに C のツールチェーンを使うかは確かめていない。
- ライブラリ: HTTP のサーバ（`warp` 3.4.16）、HTTP のクライアント（`http-client-tls` 0.4.0）、JSON（`aeson` 2.3.2.0）、正規表現（`regex-tdfa` 1.3.2.6）が Hackage にある（2026-09-29 の最新版）。TLS の `tls`（2.4.8）は「Native Haskell TLS 1.2/1.3 protocol implementation」とする（[tls](https://hackage.haskell.org/package/tls)）。一方、暗号の `crypton`（2.1.2）は C のソース（`cbits`）を含むので、HTTP と TLS で C のコンパイラを避ける判断（[標準ライブラリ](../03-interop/03-06-stdlib.md)）とは合わない。各ライブラリの保守の状況とライセンスは確かめていない。
- 不利な点: computed goto に当たる書き方はなく、命令の振り分けの費用が Go と同じく気になりうる。遅延評価が既定なので、評価の繰り返しの中で評価の済んでいない値（サンク）が溜まり、処理系の内部で正格性の注釈（`BangPatterns` など）を注意深く付ける必要があるという見込みもあるが、確かめていない。どちらも実測していない。

### 実装を担う LLM の生成精度

五つの言語をそろえて、LLM によるコードの生成精度を比べた公開のベンチマークは見つからなかった。Aider の polyglot ベンチマークは Go と Rust を含み、Swift と Zig を含まない（[Aider polyglot](https://aider.chat/2024/12/21/polyglot.html)）。MultiPL-E は Go・Rust・Swift を含み、Zig を含まない（[MultiPL-E](https://github.com/nuprl/MultiPL-E)）。MultiPL-E のリポジトリには Haskell への変換器（`dataset_builder/humaneval_to_hs.py`）があり、Haskell も対象に含む。Aider の polyglot ベンチマークの 6 言語（C++・Go・Java・JavaScript・Python・Rust）に Haskell は入っていない（2026-09-29 に確認）。LLM が Haskell で処理系のような大きなプログラムを書く精度が、Rust と比べてどうかを示す資料は見つからなかった。

どちらも短い問題を解くベンチマークであり、処理系のような大きなプログラムを書く精度とは別のものである。

### Haskell を加えた場合の評価

Haskell を比較に加えても、Rust を選んだ四つの根拠（後述の「実装言語に Rust を選ぶ根拠」）の評価は次のとおりで、選び直す根拠にはならない見込みである。

1. **型システム**: Haskell も代数的データ型を持ち、警告を誤りにすれば網羅の漏れを検査で見つけられる。この観点では Rust とほぼ並ぶ。ただし、網羅の検査が既定で有効でないので、LLM が指定を外すと検査が緩む点で Rust より弱い。cabal の設定に `-Werror` を書けば、lint の水準をファイルに書いて緩められなくする方針（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)）と同じ手当てになる見込みだが、確かめていない。
2. **WASM**: GHC の WASM のバックエンドは技術プレビューで、公式の配布物にない。Rust の Tier 2 の対象と比べて、処理系を WASM で動かす可能性に備えにくい。
3. **メモリの回収**: Haskell は GC に任せられるので、この観点では Rust より有利である。可変のセルが作る循環の回収と、値の表現とランタイムのうちメモリの管理の部分は、GHC の GC に任せれば要らなくなる。一方、言語処理系のランタイム（値の表現と回収）を自作して学ぶ題材も失う。
4. **変える費用**: Rust で書いた処理系（`crates/benitoite`）があり、fuzzing の仕組みも Rust で作ってある。Haskell に変えれば、これらを書き直すことになる。ベンチマークの道具は Python と Benitoite のスクリプトで書いたので、実装言語によらない。

学ぶ目的（[目的と設計原則](../00-overview/00-01-goals.md)）の観点では、Haskell に固有の利点がある。設計者は、LLM が書いた処理系を読んで、関数型プログラミング（型クラス、モナド、代数的データ型）と言語処理系の両方を学ぶ。処理系を Haskell で書けば、処理系を読むこと自体が関数型プログラミングの実例を読むことになり、モナドを学ぶ場にもなる。Rust で書いた処理系から学べるのは、主に言語処理系の側である。

一方で、次の点は Haskell に不利か、確かめていない。

- 遅延評価によるメモリの使いすぎを、LLM が書くコードで避けられるか。
- LLM が Haskell で処理系の規模のコードを正しく書けるか。公開のベンチマークからは判断できない。
- 実行速度。Haskell で書いた処理系は測っていない。
- 自作のスケジューラと IO 実行器を、GHC のランタイムの上で自作する意味。GHC の軽量スレッドと IO マネージャを使えば実装は減るが、処理系の主要部を自作する方針との関係を決め直す必要がある。

Haskell は、メモリの回収と学ぶ目的では Rust より有利であり、WASM と変える費用と LLM の生成精度の見通しでは不利である。実装言語を Haskell に変える根拠にはなりにくい。

### 実装言語に Rust を選ぶ根拠

【決定】処理系は Rust で実装し、LLM が実装する。性能を理由に実装言語を見直す段階は設けず、性能の測定の結果は最適化の要否を決める材料にする。根拠は次のとおりである。

1. **型システム**: Rust の列挙型と網羅を求める `match` により、構文木・値・命令の種類を加えたときの処理の漏れを、実装言語の検査で見つけられる。Go では、この漏れを言語が検出しない。処理系は LLM が実装するので、誤りを実装言語の検査で捕まえられることを重く見る。
2. **WASM**: Rust は WASM の三つの対象を、標準ライブラリを含む Tier 2 として扱う。処理系を WASM で動かす可能性に備えやすい。
3. **メモリの回収**: Rust を選んだ時点の言語の範囲（可変のセルと明示遅延を含まない範囲）では、値どうしの参照が循環しないので、参照カウントだけで使わなくなった値を回収できた。このため、GC を Go に任せられる利点は決め手にならなかった。
4. **変える費用**: Rust を選んだ時点では処理系のコードがまだなく、実装言語を変える費用が最も小さかった。

OS のサンドボックスの掛けやすさも比べたが、決め手にはしない。Go でも Landlock の Go 用ライブラリが全スレッドに設定を適用するので、処理系が自分に制限を掛けられる。スクリプトを OS のサンドボックスを掛けた子プロセスで実行する方式は、実装言語に依存しない。

一方、Rust を選ぶことで次のものを失う。

- 言語の値の回収を任せられる GC。可変のセルを加えると値が循環しうるので、循環を回収する方式を処理系が持つ。初回リリース版は、マーク・スイープと改良した参照カウントを試作して比べ、マーク・スイープを採った（[ランタイム](../02-impl/02-09-runtime.md)）。
- go.* の層による、Go の標準ライブラリの自動のラップ。標準ライブラリは手で書く。
