# 先行事例索引

## 目的と範囲

Benitoite の設計で参考にしたプログラミング言語と処理系を、参考にした理由とともに挙げる。本章は、各決定がどの言語のどの考え方に由来するかを記録する。

## 前提

本章は次の三つに分けて記す。

1. **精神的な影響**: 言語の目指す方向そのものに影響した言語
2. **言語設計の参考**: 構文・型システム・エフェクト・データ構造など、言語仕様の個別の決定で参考にした言語
3. **処理系・基盤の先行事例**: 処理系の実装、プラグイン、配布で参考にした言語・ライブラリ

このほかに、スクリプトが触れる範囲を制限する方式の先行事例を「権限制御と隔離の先行事例」に挙げる。各言語の歴史や作者の発言などの外部の事実のうち、一次資料で確かめていないものは、文の中でそのことを書く（確認は docs/todo の TODO-009）。

## 仕様

### 精神的な影響

#### Perl

Perl は Benitoite の目指す方向（[目的と設計原則](../00-overview/00-01-goals.md)）に最も大きく影響した言語である。

Benitoite が受け継ぐのは次の二つの哲学である。

- **プログラマの三大美徳（怠惰・短気・傲慢）**: Benitoite の標語「怠惰・短気・傲慢を再び（Laziness, Impatience, and Hubris — Again）」の由来である。英語表記は、Perl の文書 `perlglossary`（『Programming Perl』第 4 版の用語集に基づく）が、laziness・impatience・hubris をプログラマの第一・第二・第三の美徳と定義していることに合わせた。Perl の利用者は、三大美徳を発揮する前に、言語を学ぶ勤勉さ、デバッグに付き合う長気、自分のコードを疑う謙虚さを払う必要があった。Benitoite はこの負担を、処理系の検査とコードを書く LLM に負わせる。
- **簡単なことは簡単に、難しいことも可能に**: 設計原則の一つとして採る。

あわせて、次の得意分野を受け継ぐ。

- テキスト処理を言語の第一級の機能として扱うこと（正規表現、行単位の処理、文字列補間）
- ワンライナーで実行できること
- Unix のコマンドをつなぐ接着剤として使えること

一方、次の性質は受け継がない。

- 文脈によって意味が変わる構文と意味論（スカラー文脈とリスト文脈、暗黙の `$_`）。理由: LLM にも人間にも誤りの原因になるからである。
- TMTOWTDI（やり方は複数ある）。理由: 書き手が LLM の場合、書き方の自由は出力の揺れになり、差分の確認と改造後の検査を難しくするからである。

Perl の最初の版 1.000 は、1987-12-18 に Larry Wall が公開した（Perl の文書 `perlhist`）。Perl の文書 `perl(1)` は、Perl はもともと任意のテキストファイルを走査して情報を取り出し、その情報に基づいて報告を出力することに最適化した言語であり、作者の意見として sed・awk・sh の優れた機能を組み合わせたものだと述べている。

### 言語設計の参考

言語仕様の個別の決定で参考にした言語は次のとおりである。個別の決定のために他の言語を調べた結果は、[他の言語の調査記録](08-03-language-surveys.md)に記す。

| 言語 | 参考にする点 | 関連章 |
|---|---|---|
| Python | 「やり方は一つ」、読みやすさの重視、文字列補間（f-string） | [目的と設計原則](../00-overview/00-01-goals.md) |
| Ruby | ブロックによる高階関数の日常的な利用、プログラマの楽しさの重視 | |
| ML / OCaml | HM 型推論、代数的データ型、パターンマッチ（`match 対象 with` の書き方を含む）、非純粋・正格の実用路線 | [型システム](../01-spec/01-06-type-system.md) |
| Haskell | 副作用を型で表す考え方 | [エフェクト](../01-spec/01-07-effects.md) |
| Elm | 型クラスを持たずに演算子を型付けする閉じた制約（`number`・`comparable`）、親切なエラーメッセージ | [型システム](../01-spec/01-06-type-system.md) |
| Rust | エラーメッセージの形式（span、ソースの抜粋、`help:`）、`Option`・`Result` をつなぐ関数の名前 | [診断エンジン](../02-impl/02-10-diagnostics.md) |
| Lua 5 | レジスタ型のバイトコード VM | [バイトコードとコード生成](../02-impl/02-07-bytecode.md) |
| Clojure | 永続データ構造を標準とすること | [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md) |
| Gleam | 小さく、主流の言語に近い見た目の型付き関数型言語 | [構文](../01-spec/01-02-syntax.md) |
| Koka | 組み込みの IO を細かいエフェクト（`console`・`fsys`・`net` など）に分け、`io` をそれらをまとめた名前とすること。利用者が定義するエフェクトとハンドラ | [エフェクト](../01-spec/01-07-effects.md) |
| Flix | 組み込みの IO を細かいエフェクト（`FileRead`・`FileWrite`・`Process` など）に分け、それぞれに既定のハンドラを持たせて、テストで別のハンドラに差し替えられること | [エフェクト](../01-spec/01-07-effects.md) |
| Pascal / Ada | 等しくないの `<>`、論理演算子の `and`・`or`・`not`、整数の除算と剰余の `div`・`mod`（Pascal）。ブロックを構文の名前で閉じる形（Ada の `end if` など。Ada の構文は一次資料で確かめていない） | [構文](../01-spec/01-02-syntax.md) |

### 処理系・基盤の先行事例

処理系の実装、プラグイン、配布で参考にした事例を挙げる。このうち、yaegi、gopher-lua・Tengo・goja、HashiCorp go-plugin、wazero は、処理系を Go で実装する計画だったときに参考にした事例である。

| 事例 | 参照理由 |
|---|---|
| Babashka（Clojure） | シェルと協調するスクリプティング FP、SCI による部分集合、native-image の単一バイナリ、interop の絞り込み、pods |
| F#（`dotnet fsi`） | ホスト stdlib との連携。ただし .NET API を自動で Option/Result 化しているわけではない。`MailboxProcessor`（この行の F# の事実は一次資料で確かめていない） |
| Scala（Ammonite / Scala CLI） | 非純粋 FP＋ホスト stdlib＋スクリプト |
| Haskell `turtle`/`shelly` | IO 内でのプロセス実行 DSL |
| Racket / Janet | 高速起動・バッテリー同梱の stdlib 設計。Racket は threads/places に加え coroutine/parallel thread 系 API も持つとされる（確かめていない） |
| Roc（platform） / Gleam | 正格な現代的 FP。platform は効果委譲の実例（一般化はしない） |
| Flix / Koka / Unison | 代数的エフェクト |
| OCaml 5 | エフェクトハンドラ、value restriction |
| yaegi | Go 製 Go インタプリタ、`extract`、GC 委譲 |
| gopher-lua / Tengo / goja | Go 製スクリプト言語（GC 委譲、性能の参考） |
| HashiCorp go-plugin / Extism / CNI | プラグイン境界 |
| wazero | cgo 不要の WASM ランタイム |

### 権限制御と隔離の先行事例

スクリプトが触れる範囲を制限する方式の先行事例を挙げる。初回リリース版は実行時の権限制御と OS のサンドボックスを含めない。ここに挙げる事例は、それらと、外部に作用するすべての経路を同じ制御に通せるかという問題（[セキュリティモデル](../07-quality/07-01-security-model.md)）を検討するときの参考である（docs/todo の TODO-141、TODO-148）。ここに挙げる事実は、2026-09-26 に各事例の公式の文書とリポジトリで確かめた。Claude Code のサンドボックス、Landlock、opencode のサーバの行は、2026-09-29 に確かめた。opencode のサーバは隔離の事例ではないので、方式の欄を「—」とする。

方式は、次の三つに分かれる。

1. **OS の隔離で子プロセスを閉じ込める**: 処理を隔離した子プロセスで実行し、カーネルに範囲の外の操作を拒否させる。処理系の中の経路によらず効き、起動したコマンドにも及ぶ。
2. **言語から外部とのやり取りをなくす**: 言語そのものが IO を持たず、ホストが渡した関数や取り込み（import）だけで外部に触れる。
3. **ランタイムが権限を検査する**: 処理系が操作ごとに許可を確かめる。

サーバモードの権限制御で方式 3 と方式 1 を組み合わせ、通信にはプロキシを加える案を検討するときに、これらの事例を参考にする（docs/todo の TODO-141、TODO-148）。初回リリース版はサーバモードを含めない。

| 事例 | 方式 | 参照理由 | 出典 |
|---|---|---|---|
| Nix | 1 | Nix 式で書いたビルドの手順を、隔離した環境で実行する。ビルドから見えるのは、ストアの中の依存と一時的なビルドディレクトリなどに限られる。Linux では PID・mount・network・IPC・UTS の名前空間を分ける（固定出力のビルドはネットワークを使えるよう network の名前空間を分けない）。macOS では Seatbelt のプロファイルを使う。既定で有効なのは Linux だけである。入力の宣言を隔離の設定に変える点が、許可した権限を OS の制限に変える案に近い | [nix.conf の `sandbox`](https://nix.dev/manual/nix/latest/command-ref/conf-file.html)、[macOS の実装](https://github.com/NixOS/nix/blob/master/src/libstore/darwin/build/darwin-derivation-builder.cc) |
| GNU Guix | 1 | Scheme で書いたビルドの手順を、デーモンが特権のない chroot の中で実行する。chroot に入るのは、その手順が依存するストアの部分と限られたシステムのディレクトリだけである。GNU/Linux では、mount・PID・network などの名前空間を分けたコンテナになる | [Build Environment Setup](https://guix.gnu.org/manual/en/html_node/Build-Environment-Setup.html) |
| Bazel | 1 | 各手順を、Linux では名前空間で、macOS では `sandbox-exec` で隔離して実行する。作業ディレクトリに置くのは宣言した入力だけだが、絶対パスを知っていればほかのファイルも読める。隠れた依存を防ぐ仕組みであり、セキュリティの境界ではない。隔離の強さと目的を区別する例として参考にする | [Sandboxing](https://bazel.build/docs/sandboxing) |
| Codex（OpenAI のエージェントのハーネス） | 1 | エージェントが実行するコマンドを、macOS では Seatbelt、Linux では bubblewrap で隔離した子プロセスとして起動する。Linux では、ファイルシステム全体を読み取り専用にし、書き込んでよい範囲だけを書き込み可能にし、その中でも `.git` などを読み取り専用に戻す。隔離は起動したコマンドにも及ぶ。制限を掛けた子プロセスでスクリプトを実行する方式の参考にした | [Sandboxing](https://learn.chatgpt.com/codex/sandboxing)、[Linux のサンドボックスの README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md) |
| Starlark | 2 | 言語は決定的で hermetic であり、既定ではユーザーのコードは環境とやり取りできない。ホストのアプリケーションが、副作用を持ちうる組み込み関数を追加で渡せる | [Starlark の仕様](https://github.com/bazelbuild/starlark/blob/master/spec.md) |
| Dhall | 2 | total な言語で、外部とのやり取りはファイル・HTTP(S)・環境変数からの取り込みの三つだけである。リモートから取り込んだ式は、ローカルのファイルと環境変数を取り込めない | [Safety guarantees](https://docs.dhall-lang.org/discussions/Safety-guarantees.html) |
| Deno | 3 | `--allow-read` などで許可した操作だけをランタイムが通す。起動したサブプロセスは Deno の権限に縛られず、特に `deno` の起動を許すと制限を抜けられる。信頼できないコードには、OS の隔離の併用を勧めている。方式 3 だけでは、起動したコマンドの先の操作を制御できない例として参考にした。この弱点を OS のサンドボックスで補う案の参考にする | [Security and permissions](https://docs.deno.com/runtime/fundamentals/security/) |
| Claude Code のサンドボックス（sandbox-runtime） | 1 | エージェントが実行するコマンドを、macOS では Seatbelt、Linux と WSL2 では bubblewrap で隔離する。通信は、サンドボックスの外に置いた HTTP と SOCKS5 のプロキシで接続先のドメインを判定する。Unix ソケットは、macOS ではパスごとに許し、Linux では seccomp で塞ぐ。TLS の中身を検査しないので domain fronting を防げないと文書が認めている。サーバモードで通信をデーモンのプロキシに通す方式の参考にする | [Sandboxing](https://code.claude.com/docs/en/sandboxing)、[sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) |
| Linux の Landlock | 1 | 特権のないプロセスが自分と子孫に掛けられる、ファイルシステムと TCP・UDP のポートの制限。重ねて掛けた制限は積集合になる。制限できる操作はカーネルの版で増える。サーバモードで Linux に使う仕組みの候補として参考にする | [Landlock](https://docs.kernel.org/userspace-api/landlock.html) |
| opencode のサーバ | — | TUI を、同時に起動するサーバのクライアントとして作る。`opencode serve` で画面なしのサーバを動かし、`attach` でつなぐ。サーバモードでデーモンとクライアントを分ける構成の参考にする。サンドボックスは文書にない | [Server](https://opencode.ai/docs/server/) |
