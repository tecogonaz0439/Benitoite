# 実装言語の比較

- 状態: 草稿
- 関連ADR: [0002](../decisions/0002-initial-implementation-in-go-by-llm.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0084](../decisions/0084-implementer-assignment-for-minimal.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0196](../decisions/0196-os-sandbox-mechanisms.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)
- 未決事項: [OPEN-007](../open-issues.md#open-007), [OPEN-009](../open-issues.md#open-009), [OPEN-036](../open-issues.md#open-036)
- 移行元: [設計メモ](../sources/fp-language-design.md) 付録A、9

## 目的と範囲

処理系の実装言語に Rust を選んだ根拠となる、Rust と他の言語（Go・Zig・Swift）との比較。

初期実装の言語は、いったん Go に決めた（[ADR 0002](../decisions/0002-initial-implementation-in-go-by-llm.md)）。その後、最小実行版の前に Rust に改め、性能を理由に実装言語を見直す段階は設けないことにした（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。このため、再実装の候補で得るものと失うものの比較は扱わない。

## 前提

設計メモ 付録A は、Go と Rust・Zig・Swift を比較しているが、ベンチマークも試作も経ていない定性評価である。本章では、比較に使う外部の事実を一次資料で確かめ直した（2026-09-26）。確かめた事実には出典を添え、確かめられなかったものには【要検証】を付ける。

処理系の性能は、測定するまで判断できない（[OPEN-009](../open-issues.md#open-009)、[性能](../07-quality/07-02-performance.md)）。このため、実行速度の見込みは比較の観点に含めるが、選定の根拠にはしない。

## 仕様

### 比較の観点

処理系の性質から、比較の観点を次の八つとする。

| 観点 | 処理系の性質 |
|---|---|
| メモリの回収 | 言語の値（ラムダが捕捉した環境、永続データ構造、初回リリース版の可変のセルと明示遅延の値）はヒープに置く。可変のセルを使えば、値どうしの参照が循環しうる。処理系は、循環する値の扱いを決める必要がある（[OPEN-036](../open-issues.md#open-036)） |
| 型システム | 処理系は、構文木・値・命令など、種類の決まったデータを多く扱う。種類を加えたときの処理の漏れを、実装言語の検査で見つけられるかが、LLM が書く処理系の堅牢さに関わる |
| ホストの標準ライブラリの利用 | 設計メモは、初回リリース版の go.* の層で、Go の標準ライブラリの API を型の情報から自動でラップするとしていた（設計メモ 10、11）。この層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)） |
| WASM | 処理系を WASM で動かす可能性がある（[OPEN-007](../open-issues.md#open-007)） |
| 並行処理 | 設計メモ 5 は、並行処理をホストの仕組みの上に作る。最小実行版には並行処理はない |
| OS のサンドボックス | 実行時の権限制御を OS のサンドボックスでも強制する方針である。初回リリース版の後に、サーバモードとあわせて加える（[ADR 0196](../decisions/0196-os-sandbox-mechanisms.md)、[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） |
| 配布 | 処理系を単一の実行ファイルとして、複数の OS に向けて配る（[配布形態](../05-platform/05-01-distribution.md)） |
| 実装を担う LLM の生成精度 | 処理系は設計者が手で書かず、LLM が実装プランに従って書く（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)） |

### 比較の一覧

観点ごとの比較を次の表にまとめる。各欄の事実の出典は、次節の「各言語の性質」に示す。

| 観点 | Go | Rust | Zig | Swift |
|---|---|---|---|---|
| メモリの回収 | ランタイムの GC に任せられる | GC はない。`Rc` は循環を解放しない。GC を自作するか、外部のクレートに頼る | 言語はメモリを管理しない。GC をすべて自作する | ARC。強い参照の循環はリークする。処理系の側で循環に手当てが要る |
| 型システム | 直和型がなく、`switch` は分岐の網羅を求めない | 列挙型を持ち、`match` は網羅を求める | 確かめていない | 確かめていない |
| go.* の層（廃止） | `go/types` と `go/packages` を前提に作れた | 層を設計し直す必要があった | 同左 | 同左 |
| 並行処理 | `go` 文とチャネルが言語に組み込まれている | 標準ライブラリに非同期処理の実行器がなく、Tokio などを選ぶ。処理系は、一つのスレッドで動く自作のスケジューラと `mio` のイベントループを採った（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)、[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)） | `async`・`await` は削除され、0.16.0 で `std.Io` を導入した | actor と構造化並行性が言語に組み込まれている |
| OS のサンドボックス | Landlock の Go 用ライブラリが、Go のランタイムが管理する全スレッドに設定を適用する | ランタイムがスレッドを持たないので、スレッドを作る前に掛けられる（確かめていない） | 同左（確かめていない） | 確かめていない |
| WASM の対象 | 確かめていない | `wasm32-unknown-unknown`・`wasm32-wasip1`・`wasm32-wasip2` が、標準ライブラリを含む Tier 2 の対象 | 確かめていない | 確かめていない |
| 配布 | 既定で静的にリンクし、`GOOS`・`GOARCH` で対象を選ぶ | musl の対象は既定で C のランタイムを静的にリンクする | 多数の対象の libc を同梱し、クロスコンパイルを第一級の用途とする | Swift 6 から、Linux 向けに完全に静的にリンクできる |
| 言語の版（2026-09-26 時点の最新） | go1.27.1 | 1.98.1 | 0.16.0（1.0 の前） | —（確かめていない） |
| LLM の生成精度のベンチマーク | Aider polyglot、MultiPL-E | Aider polyglot、MultiPL-E | 見つからなかった | MultiPL-E |
| 実行速度 | 測定するまで比べない（[OPEN-009](../open-issues.md#open-009)） | 同左 | 同左 | 同左 |

ベンチマークの欄は、その言語を含む公開のベンチマークがあるかだけを示し、生成精度の高さを示すものではない（後述の「実装を担う LLM の生成精度」）。

### 各言語の性質

各言語について、観点ごとに確かめた事実を示す。

**Go**（最新の安定版は go1.27.1、2026-09-01。[リリース履歴](https://go.dev/doc/devel/release)）

- メモリの回収: Go の標準のツールチェーンは、すべてのアプリケーションに、GC を含むランタイムを同梱する（[GC ガイド](https://go.dev/doc/gc-guide)）。処理系は、言語の値の回収を Go の GC に任せられる。
- ホストの標準ライブラリの利用: 標準ライブラリの `go/types` は Go のパッケージを型検査し、パッケージの宣言と型の情報を取り出せる（[go/types](https://pkg.go.dev/go/types)）。`golang.org/x/tools/go/packages` はパッケージを読み込む（[go/packages](https://pkg.go.dev/golang.org/x/tools/go/packages)）。go.* の層の自動ラップは、この二つを前提に設計していた（層は [ADR 0077](../decisions/0077-abolish-go-layer.md) で廃止した）。
- 並行処理: goroutine を起動する `go` 文とチャネルの型が、言語に組み込まれている（[言語仕様](https://go.dev/ref/spec#Go_statements)）。
- 配布: gc ツールチェーンのリンカは、既定で静的にリンクした実行ファイルを作る。対象の環境は `GOOS` と `GOARCH` で選び、cgo は `CGO_ENABLED=0` で無効にできる（[Go の FAQ](https://go.dev/doc/faq)、[ソースからのインストール](https://go.dev/doc/install/source)、[cmd/cgo](https://pkg.go.dev/cmd/cgo)）。
- 型システム: 言語仕様に直和型はなく、`switch` 文は分岐を網羅することを求めない（[言語仕様](https://go.dev/ref/spec#Switch_statements)）。
- OS のサンドボックス: Landlock の Go 用ライブラリは、パスの制限を掛けるときに、Go のランタイムが管理する全スレッドに「新しい特権を得ない」の設定をする（[go-landlock](https://pkg.go.dev/github.com/landlock-lsm/go-landlock/landlock)）。
- 不利な点: `goto` の飛び先は同じ関数の中のラベルに限られ、飛び先を値として扱えない（[言語仕様](https://go.dev/ref/spec#Goto_statements)）。C で書いたインタプリタが使う computed goto によるディスパッチは書けない。設計メモ 9 は、これに加えて配列の境界検査、interface を経由する値の表現、GC のライトバリアが評価の繰り返しの費用になり、Go で書いたインタプリタは C で書いた同種の処理系より遅い傾向があるとしている。この見込みは【要検証】である（[OPEN-009](../open-issues.md#open-009)）。

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

### 実装を担う LLM の生成精度

四つの言語をそろえて、LLM によるコードの生成精度を比べた公開のベンチマークは見つからなかった。Aider の polyglot ベンチマークは Go と Rust を含み、Swift と Zig を含まない（[Aider polyglot](https://aider.chat/2024/12/21/polyglot.html)）。MultiPL-E は Go・Rust・Swift を含み、Zig を含まない（[MultiPL-E](https://github.com/nuprl/MultiPL-E)）。

どちらも短い問題を解くベンチマークであり、処理系のような大きなプログラムを実装プランに従って書く精度とは別のものである。

### 実装言語に Rust を選ぶ根拠

【決定】処理系は Rust で実装する（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。根拠は次のとおりである。

1. **型システム**: Rust の列挙型と網羅を求める `match` により、構文木・値・命令の種類を加えたときの処理の漏れを、実装言語の検査で見つけられる。Go では、この漏れを言語が検出しない。処理系は LLM が実装するので、誤りを実装言語の検査で捕まえられることを重く見る。
2. **WASM**: Rust は WASM の三つの対象を、標準ライブラリを含む Tier 2 として扱う。処理系を WASM で動かす可能性（[OPEN-007](../open-issues.md#open-007)）に備えやすい。
3. **メモリの回収**: 最小実行版の言語では、値どうしの参照が循環しないので、参照カウントだけで使わなくなった値を回収できる（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。GC を Go に任せられる利点は、最小実行版では決め手にならない。
4. **変える費用**: Rust を選んだ時点（最小実行版の実装の前）では、処理系のコードがまだなく、実装言語を変える費用が最も小さかった。

OS のサンドボックスの掛けやすさも比べたが、決め手にはしない。Go でも Landlock の Go 用ライブラリが全スレッドに設定を適用するので、処理系が自分に制限を掛けられる。サーバモードと、サーバモードを加えた後のスタンドアロンモードは、スクリプトを OS のサンドボックスを掛けた子プロセスで実行する（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0196](../decisions/0196-os-sandbox-mechanisms.md)、[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）。この方式は実装言語に依存しない。

一方、Rust を選ぶことで次のものを失う。

- 言語の値の回収を任せられる GC。初回リリース版で可変のセルを加えると値が循環しうるので、循環を回収する方式を決める必要がある。この方式は、初回リリース版の実装プランを作るときに、値の表現とランタイムの作り直しで決める（[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)、[OPEN-036](../open-issues.md#open-036)）。
- go.* の層による、Go の標準ライブラリの自動のラップ（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。初回リリース版の std を手で書く範囲が広がる。

実装を担う LLM が Rust で処理系を正しく書けるかは、試しの作業を設けず、最小実行版の各作業の確認で見た（[ADR 0084](../decisions/0084-implementer-assignment-for-minimal.md)）。Go の不利な点（computed goto がないことなど）が性能にどれだけ響くかを確かめる必要はなくなったが、Rust で実装した最小実行版の性能は 2026-09-27 に測定した（[性能](../07-quality/07-02-performance.md)の「最小実行版の測定の結果」、[OPEN-009](../open-issues.md#open-009)）。

## 未決事項

- [OPEN-007](../open-issues.md#open-007): WASMコア化の採否
- [OPEN-009](../open-issues.md#open-009): 実行性能
- [OPEN-036](../open-issues.md#open-036): 初回リリース版で循環する値を回収する方式
