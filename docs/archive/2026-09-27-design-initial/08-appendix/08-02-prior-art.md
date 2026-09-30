# 先行事例索引

- 状態: 草稿
- 関連ADR: [0001](../decisions/0001-lazy-impatient-hubris-concept.md), [0009](../decisions/0009-typing-without-type-classes.md), [0027](../decisions/0027-register-bytecode.md), [0032](../decisions/0032-rust-style-text-and-json.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0076](../decisions/0076-initial-implementation-in-rust.md)
- 未決事項: [OPEN-013](../open-issues.md#open-013), [OPEN-014](../open-issues.md#open-014), [OPEN-018](../open-issues.md#open-018)
- 移行元: [設計メモ](../sources/fp-language-design.md) 付録B

## 目的と範囲

Benitoite の設計で参考にしたプログラミング言語と処理系を、参考にした理由とともに挙げる。設計書の主な目的は実装計画の根拠を示すことであり、本章はその補助として、各決定がどの言語のどの考え方に由来するかを記録する。

本章は、全章の仕様を検討し終えた後に完成させる。それまでは、会話と各章の検討で参考にした言語を随時書き足す。

## 前提

本章は次の三つに分けて記す。

1. **精神的な影響**: 言語の目指す方向そのものに影響した言語
2. **言語設計の参考**: 構文・型システム・エフェクト・データ構造など、言語仕様の個別の決定で参考にした言語
3. **処理系・基盤の先行事例**: 処理系の実装、Go との相互運用、プラグイン、配布で参考にした言語・ライブラリ

各言語の歴史や作者の発言などの外部の事実は、一次資料で確認するまで【要検証】とする（[OPEN-014](../open-issues.md#open-014)）。

## 仕様

### 精神的な影響

#### Perl

Perl は Benitoite の目指す方向（[目的と設計原則](../00-overview/00-01-goals.md)）に最も大きく影響した言語である。

Benitoite が受け継ぐのは次の二つの哲学である。

- **プログラマの三大美徳（怠惰・短気・傲慢）**: Benitoite の標語「怠惰・短気・傲慢を再び（Laziness, Impatience, and Hubris — Again）」の由来である（英語表記の出典は [OPEN-013](../open-issues.md#open-013)）。Perl の利用者は、三大美徳を発揮する前に、言語を学ぶ勤勉さ、デバッグに付き合う長気、自分のコードを疑う謙虚さを払う必要があった。Benitoite はこの負担を、処理系の検査とコードを書く LLM に負わせる（[ADR 0001](../decisions/0001-lazy-impatient-hubris-concept.md)）。
- **簡単なことは簡単に、難しいことも可能に**: 設計原則の一つとして採る。

あわせて、次の得意分野を受け継ぐ。

- テキスト処理を言語の第一級の機能として扱うこと（正規表現、行単位の処理、文字列補間）
- ワンライナーで実行できること
- Unix のコマンドをつなぐ接着剤として使えること

一方、次の性質は受け継がない。理由は [ADR 0001](../decisions/0001-lazy-impatient-hubris-concept.md) に記す。

- 文脈によって意味が変わる構文と意味論（スカラー文脈とリスト文脈、暗黙の `$_`）
- TMTOWTDI（やり方は複数ある）

Perl の成り立ちについては、1987年ごろ Larry Wall が業務で報告書を作るために、awk では足りない処理を補う道具として作った、と伝えられている【要検証】（[OPEN-014](../open-issues.md#open-014)）。

### 言語設計の参考

【方針】表は、全章の検討を終えた後に見直す。現時点で参考にしている、または候補に挙がっている言語は次のとおりである。

| 言語 | 参考にする点 | 関連章 |
|---|---|---|
| Python | 「やり方は一つ」、読みやすさの重視、文字列補間（f-string） | [目的と設計原則](../00-overview/00-01-goals.md) |
| Ruby | ブロックによる高階関数の日常的な利用、プログラマの楽しさの重視 | |
| ML / OCaml | HM 型推論、代数的データ型、パターンマッチ、非純粋・正格の実用路線 | [型システム](../01-spec/01-06-type-system.md) |
| Haskell | 副作用を型で表す考え方 | [エフェクト](../01-spec/01-07-effects.md) |
| Elm | 型クラスを持たずに演算子を型付けする閉じた制約（`number`・`comparable`）、親切なエラーメッセージ | [型システム](../01-spec/01-06-type-system.md)、[ADR 0009](../decisions/0009-typing-without-type-classes.md) |
| Rust | エラーメッセージの形式（span、ソースの抜粋、`help:`）、`Option`・`Result` をつなぐ関数の名前 | [診断エンジン](../02-impl/02-10-diagnostics.md)、[ADR 0032](../decisions/0032-rust-style-text-and-json.md)、[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md) |
| Lua 5 | レジスタ型のバイトコード VM | [バイトコードとコード生成](../02-impl/02-07-bytecode.md)、[ADR 0027](../decisions/0027-register-bytecode.md) |
| Clojure | 永続データ構造を標準とすること | [データ型](../01-spec/01-05-data-types.md) |
| Gleam | 小さく、主流の言語に近い見た目の型付き関数型言語 | [構文](../01-spec/01-02-syntax.md) |

### 処理系・基盤の先行事例

設計メモ付録Bから移した。このうち、yaegi、gopher-lua・Tengo・goja、HashiCorp go-plugin、wazero は、処理系を Go で実装する計画（[ADR 0002](../decisions/0002-initial-implementation-in-go-by-llm.md)）の下で参考にした事例である。処理系を Rust で実装することにした（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）ので、現在は経緯の記録として残す。

| 事例 | 参照理由 | 設計メモの章 |
|---|---|---|
| Babashka（Clojure） | シェルと協調するスクリプティング FP、SCI による部分集合、native-image の単一バイナリ、interop の絞り込み、pods | 15, 18 |
| F#（`dotnet fsi`） | ホスト stdlib との連携。ただし .NET API を自動で Option/Result 化しているわけではない。`MailboxProcessor` | 10, 5 |
| Scala（Ammonite / Scala CLI） | 非純粋 FP＋ホスト stdlib＋スクリプト | 1 |
| Haskell `turtle`/`shelly` | IO 内でのプロセス実行 DSL | 3, 16 |
| Racket / Janet | 高速起動・バッテリー同梱の stdlib 設計。Racket は threads/places に加え coroutine/parallel thread 系 API も持つ | 5 |
| Roc（platform） / Gleam | 正格な現代的 FP。platform は効果委譲の実例（一般化はしない） | 3 |
| Flix / Koka / Unison | 代数的エフェクト | 3 |
| OCaml 5 | エフェクトハンドラ、value restriction | 2.4, 5 |
| yaegi | Go 製 Go インタプリタ、`extract`、GC 委譲 | 7, 11 |
| gopher-lua / Tengo / goja | Go 製スクリプト言語（GC 委譲、性能の参考） | 7, 9 |
| HashiCorp go-plugin / Extism / CNI | プラグイン境界 | 18 |
| wazero | cgo 不要の WASM ランタイム | 19 |

### 権限制御と隔離の先行事例

スクリプトが触れる範囲を制限する方式の先行事例を挙げる。v1 の権限の宣言（[エフェクト](../01-spec/01-07-effects.md)の「権限の宣言（v1）」）と、外部に作用するすべての経路を同じ制御に通せるかという問題（[OPEN-018](../open-issues.md#open-018)、[セキュリティモデル](../07-quality/07-01-security-model.md)）を検討するときの参考にする。ここに挙げる事実は、2026-09-26 に各事例の公式の文書とリポジトリで確かめた。

方式は、次の三つに分かれる。

1. **OS の隔離で子プロセスを閉じ込める**: 処理を隔離した子プロセスで実行し、カーネルに範囲の外の操作を拒否させる。処理系の中の経路によらず効き、起動したコマンドにも及ぶ。
2. **言語から外部とのやり取りをなくす**: 言語そのものが IO を持たず、ホストが渡した関数や取り込み（import）だけで外部に触れる。
3. **ランタイムが権限を検査する**: 処理系が操作ごとに許可を確かめる。Benitoite の `permissions` はこの方式である（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)）。

| 事例 | 方式 | 参照理由 | 出典 |
|---|---|---|---|
| Nix | 1 | Nix 式で書いたビルドの手順を、隔離した環境で実行する。ビルドから見えるのは、ストアの中の依存と一時的なビルドディレクトリなどに限られる。Linux では PID・mount・network・IPC・UTS の名前空間を分ける（固定出力のビルドはネットワークを使えるよう network の名前空間を分けない）。macOS では Seatbelt のプロファイルを使う。既定で有効なのは Linux だけである。入力の宣言を隔離の設定に変える点が、権限の宣言を OS の制限に変える案に近い | [nix.conf の `sandbox`](https://nix.dev/manual/nix/latest/command-ref/conf-file.html)、[macOS の実装](https://github.com/NixOS/nix/blob/master/src/libstore/darwin/build/darwin-derivation-builder.cc) |
| GNU Guix | 1 | Scheme で書いたビルドの手順を、デーモンが特権のない chroot の中で実行する。chroot に入るのは、その手順が依存するストアの部分と限られたシステムのディレクトリだけである。GNU/Linux では、mount・PID・network などの名前空間を分けたコンテナになる | [Build Environment Setup](https://guix.gnu.org/manual/en/html_node/Build-Environment-Setup.html) |
| Bazel | 1 | 各手順を、Linux では名前空間で、macOS では `sandbox-exec` で隔離して実行する。作業ディレクトリに置くのは宣言した入力だけだが、絶対パスを知っていればほかのファイルも読める。隠れた依存を防ぐ仕組みであり、セキュリティの境界ではない。隔離の強さと目的を区別する例として参考にする | [Sandboxing](https://bazel.build/docs/sandboxing) |
| Codex（OpenAI のエージェントのハーネス） | 1 | エージェントが実行するコマンドを、macOS では Seatbelt、Linux では bubblewrap で隔離した子プロセスとして起動する。Linux では、ファイルシステム全体を読み取り専用にし、書き込んでよい範囲だけを書き込み可能にし、その中でも `.git` などを読み取り専用に戻す。隔離は起動したコマンドにも及ぶ。処理系が自分に制限を掛ける方式と、制限を掛けた子プロセスで実行する方式を比べるときの参考にする | [Sandboxing](https://learn.chatgpt.com/codex/sandboxing)、[Linux のサンドボックスの README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md) |
| Starlark | 2 | 言語は決定的で hermetic であり、既定ではユーザーのコードは環境とやり取りできない。ホストのアプリケーションが、副作用を持ちうる組み込み関数を追加で渡せる | [Starlark の仕様](https://github.com/bazelbuild/starlark/blob/master/spec.md) |
| Dhall | 2 | total な言語で、外部とのやり取りはファイル・HTTP(S)・環境変数からの取り込みの三つだけである。リモートから取り込んだ式は、ローカルのファイルと環境変数を取り込めない | [Safety guarantees](https://docs.dhall-lang.org/discussions/Safety-guarantees.html) |
| Deno | 3 | `--allow-read` などで許可した操作だけをランタイムが通す。起動したサブプロセスは Deno の権限に縛られず、特に `deno` の起動を許すと制限を抜けられる。信頼できないコードには、OS の隔離の併用を勧めている。Benitoite の `permissions` と同じ方式で、同じ弱点（起動したコマンドの先の操作）を持つ例として参考にする | [Security and permissions](https://docs.deno.com/runtime/fundamentals/security/) |

## 未決事項

- [OPEN-013](../open-issues.md#open-013): 標語で使う三大美徳の英語表記の出典
- [OPEN-014](../open-issues.md#open-014): 参考にした言語に関する外部の事実の確認
- [OPEN-018](../open-issues.md#open-018): 外部に作用するすべての経路を IO 実行器に通せるか
