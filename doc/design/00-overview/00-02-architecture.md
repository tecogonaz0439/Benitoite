# 全体像

- 状態: 確定
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0018](../decisions/0018-reference-interpreter.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0175](../decisions/0175-script-embedded-binary-before-stable-release.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0196](../decisions/0196-os-sandbox-mechanisms.md), [0239](../decisions/0239-cycle-collection-for-reference-cells.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)
- 未決事項: [OPEN-007](../open-issues.md#open-007), [OPEN-015](../open-issues.md#open-015), [OPEN-036](../open-issues.md#open-036), [OPEN-051](../open-issues.md#open-051), [OPEN-055](../open-issues.md#open-055)
- 移行元: [設計メモ](../sources/fp-language-design.md) 0.3（決定事項サマリ）, 付録A, 3.2, 6, 8.1, 10, 19.3, 20, 23.3, 23.4

## 目的と範囲

Benitoite を構成する要素（言語仕様・処理系・ライブラリ・ツールチェーン・配布物）と、それらの関係を定める。各要素の中身は個別の章で定め、本章はどの要素がどの要素に依存し、どの情報がどこからどこへ渡るかだけを扱う。

## 前提

[目的と設計原則](00-01-goals.md)で定めた分担を前提とする。利用者は作業と許可する操作を決め、処理系は型とエフェクトの規則への適合を検査し、LLM はコードの作成・修正と診断の説明を担う。

## 仕様

### 構成要素

【方針】Benitoite は次の要素から成る。

| 要素 | 内容 | 定める章 |
|---|---|---|
| 言語仕様 | 正しいプログラムの条件と、その実行の意味。処理系の実装方式に依存しない | `01-spec/` |
| 処理系 | 言語仕様に従ってスクリプトを検査・実行するプログラム。Rust で書く | `02-impl/` |
| ライブラリ | core（prelude）と std。外部のライブラリを呼ぶ層を設けるかは未決 | `03-interop/` |
| 拡張 | 外部の関数（WASM のモジュールの関数）と、WASM によるプラグイン。言語の表面だけを初回リリース版で定め、実装は後の版で行う（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)） | `04-extensions/` |
| ツールチェーン | CLI・MCP サーバ・LSP サーバ・フォーマッタ・テストランナー・パッケージ管理・同梱の Agent Skill | `06-tooling/` |
| 配布物 | 上記を利用者の環境に届ける形態（単一バイナリなど） | `05-platform/` |

言語仕様だけが規範であり、他の要素は言語仕様に従う側に立つ。処理系の振る舞いと言語仕様が食い違うときは、言語仕様を正として処理系を直す。

### 言語仕様と処理系の境界

【決定】処理系は Rust で書き、LLM が実装する。性能を測定した後に実装言語を見直す段階は設けない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。【方針】実行方式の基準案は、自作のバイトコード VM（JIT なし）とする（[設計メモ](../sources/fp-language-design.md) 6）。処理系コアの WASM 化は代替案として残す。言語の値の回収は処理系が行う。【決定】最小実行版は言語の値を参照カウントで管理する（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。初回リリース版で循環する値を回収する方式は【未決】であり、初回リリース版の実装プランを作るときに、値の表現とランタイムの作り直しで決める（[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)、[OPEN-036](../open-issues.md#open-036)）。それまでの暫定の方式は [ADR 0239](../decisions/0239-cycle-collection-for-reference-cells.md) とする。WASM 化の採否は [OPEN-007](../open-issues.md#open-007) で扱う。

実行方式を差し替えても、処理系を別の言語で書き直しても言語仕様を変えずに済むように、`01-spec/` には VM・バイトコード・実装言語の型など実装方式に依存する記述を置かない。例えば、末尾呼び出しの保証は `01-spec/` で「深い末尾再帰でもスタックを使い果たさない」という観測可能な性質として定め、それを VM でどう実現するかは `02-impl/` で定める。

### 処理系の段

【方針】処理系は、スクリプトを次の段で順に処理する。

```text
ソースの読み込み ─ ファイル ID を付けたソースのバイト列
  │
  ▼
字句解析・構文解析 ─ span 付きの AST
  │
  ▼
名前解決・モジュール読込 ─ 依存グラフ、束縛の解決
  │
  ▼
型検査（型推論・型クラス解決・エフェクト検査）
  │                              ┌──────────────┐
  ├─ 各段が出す診断 ─────────────▶│ 診断エンジン │──▶ CLI / MCP / LSP
  ▼                              └──────────────┘
中間表現への脱糖・パターンマッチのコンパイル
  │
  ▼
バイトコード生成
  │
  ▼
VM とランタイム（IO 実行器・リソース追跡・権限の確認）
```

型検査までの段を「検査」、それ以降を「実行」と呼ぶ。検査だけを行う経路（`check`）と、検査の後に実行まで行う経路（`run`）があり、実行は検査を通ったスクリプトに対してだけ行う。これは設計原則 1（静的に検出できる誤りを実行前に報告する）を処理系の構造で担保するためである。REPL で定義の途中の状態を評価する場合などを例外とするかは、REPL を加えるとき（初回リリース版の後）に [CLI](../06-tooling/06-01-cli.md) で定める。処理系のテストでは、バイトコード生成と VM の代わりに、参照インタプリタ（reference interpreter）で中間表現を実行する経路も使う（[ADR 0018](../decisions/0018-reference-interpreter.md)）。

【方針】span（ソース上の位置）は、字句解析器・構文解析器の最初の版から、すべての AST ノードの必須フィールドとする（[設計メモ](../sources/fp-language-design.md) 8.3）。脱糖（desugaring）で生成したノードにも由来位置を持たせ、どの段で出た診断もソース上の位置を示せるようにする。位置情報の扱いは[ソース管理と位置情報](../02-impl/02-02-source-and-spans.md)で定める。

各段の間で受け渡すデータ構造と、VM を複数のスレッドから使えるようにするか（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md)）は、[パイプライン](../02-impl/02-01-pipeline.md)で定める。

### 診断の流れ

【方針】診断は、プロトコルに依存しない内部の表現として診断エンジンに集め、CLI・MCP サーバ・LSP サーバの各アダプタがそれぞれの形式に変換する（[設計メモ](../sources/fp-language-design.md) 8.1, 8.2）。内部の表現は LSP の `Diagnostic` をそのまま使わず、ファイル ID・span・診断コード・補助位置・修正案を持つ。

診断の第一の読み手は LLM なので、MCP サーバを LSP サーバより先に用意する。MCP サーバは[サーバモード](../06-tooling/06-07-server.md)で、LSP サーバは[LSP サーバ](../06-tooling/06-02-lsp.md)で定める。

### スクリプトの作成から実行までの流れ

【方針】利用者・LLM・処理系は、次の順に関わる。

1. 利用者が、行いたい作業を LLM に指示する。
2. LLM がスクリプトを書き、処理系で検査する。検査に失敗したら、LLM は診断を読んでスクリプトを直し、再び検査する。
3. 処理系が、検査を通ったスクリプトの行いうる操作（エフェクト）と、実行に必要な権限を、利用者が読める形で示す。以前に確認した版からの変更があれば、契約の変更と権限の変更を区別して示す。
4. 利用者が権限を確認して実行を許可する。
5. 処理系がスクリプトを実行する。実行中は、許可された権限の範囲外の操作を拒否する。
6. 処理系が、実行結果と失敗の理由を利用者に示す。

手順 3 の示し方は [OPEN-015](../open-issues.md#open-015) で扱う。手順 2 と 3 はツールチェーン（CLI または MCP サーバ）を通じて行い、手順 5 は処理系のランタイムが行う。

【決定】手順 3 のうち権限の表示と、手順 4、手順 5 の拒否は、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-055](../open-issues.md#open-055)）。初回リリース版では、処理系は権限を示さず、実行の許可も求めず、実行中の操作も拒否しない。MCP サーバもサーバモードとあわせて加える。

手順 5 の拒否が実効性を持つのは、外部に作用するすべての経路が権限制御を通るようになってからである（後述の「エフェクトと権限の置き場所」）。初回リリース版には外部の関数の層がなく、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけである（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。後の版で加える外部の関数も、WASM のモジュールに限り、外部に作用する経路をホストの関数に限る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。各マイルストーンでどこまで拒否できるかは[ロードマップ](00-03-roadmap.md)で定める。

### エフェクトと権限の置き場所

【方針】エフェクトの静的な追跡、エフェクトの意味を与えるハンドラ、実行時に許可する操作の制御（権限）は、別々の機構として扱う（[設計メモ](../sources/fp-language-design.md) 3.2）。三つは処理系の中で置かれる場所も異なる。

| 機構 | 置き場所 | 定める章 |
|---|---|---|
| エフェクトの静的な追跡 | 型検査器 | [エフェクト](../01-spec/01-07-effects.md), [型検査器](../02-impl/02-05-typechecker.md) |
| ハンドラ | VM とランタイム | [エフェクト](../01-spec/01-07-effects.md), [仮想機械](../02-impl/02-08-vm.md) |
| 実行時の権限制御 | ランタイム | [セキュリティモデル](../07-quality/07-01-security-model.md), [ランタイム](../02-impl/02-09-runtime.md) |

実行時の権限制御が実効性を持つには、プラグインを含む、外部に作用するすべての経路が同じ制御を通らなければならない（[設計メモ](../sources/fp-language-design.md) 3.2）。外部のライブラリを直接呼ぶ経路が制御を迂回できるうちは、権限制御は迂回可能である。

【方針】言語の権限制御は、スクリプトが意図せず危険な操作をしないための防壁と位置付ける。敵対的なコードからの隔離は、Agent Skills を実行するハーネス側のサンドボックス（コンテナや OS の権限）が担い、言語側だけでセキュリティ境界を完結させる前提は置かない（[設計メモ](../sources/fp-language-design.md) 23.4）。初回リリース版は実行時の権限制御を持たず、隔離をハーネス側に委ねる（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版の後にサーバモードとあわせて実行時の権限制御を加え、それを OS のサンドボックスでも強制することを方針とする。方式は [ADR 0196](../decisions/0196-os-sandbox-mechanisms.md) で決め、[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)で定める。分担の詳細は[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。

### ライブラリと処理系の関係

【方針】ライブラリは次の層で構成する。設計メモの3層のうち、Go の API へ直接届く go.* の層とラッパー自動生成器は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。初回リリース版には外部の関数を呼ぶ層を実装しない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。後の版の外部の関数は、WASM のモジュールの関数に限る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。標準ライブラリの作り方（言語で書く部分、Rust の組み込みの関数、クレートを包む関数）は[ライブラリの構成](../03-interop/03-01-library-structure.md)で、使うクレートは [ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) で定める。

| 層 | 内容 | 処理系との関係 |
|---|---|---|
| core / prelude | 言語独自の型と永続コレクション（Option・Result・ADT など） | 一部はコンパイラが特別扱いする |
| std | ファイル・プロセス・テキスト処理などを慣用的な API で提供するもの | Rust で実装した関数として VM から呼ぶ |

コンパイラが特別扱いする型・演算（Result・Option・IO など）と、ライブラリとして書く部分との境界は [ライブラリの構成](../03-interop/03-01-library-structure.md)で定める。

【方針】外部に作用する処理は、std・プラグインのどれを経由しても、ランタイムの IO 実行器を通す。これは、前節の権限制御の条件（すべての経路が同じ制御を通る）を満たすための構造上の要請である。初回リリース版では、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけであり、どれも処理系の一部として IO 実行器を通す（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。後の版の外部の関数とプラグインは WASM のモジュールに限り、ホストの関数を通じてだけ OS の資源に触れさせるので、ホストの関数を IO 実行器に通せば同じ条件を保てる（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)、[設計メモ](../sources/fp-language-design.md) 19.3）。その方法は [OPEN-051](../open-issues.md#open-051) で決める。

### ツールチェーンと処理系の関係

【方針】ツールチェーンの各ツールは、処理系の同じ検査の段（字句解析から型検査まで）と同じ診断エンジンを共有する。ツールごとに別の解析器を持たない。ツールごとに解析器を持つと、同じスクリプトに対する診断がツールによって食い違い、LLM と利用者がどちらを信じればよいか判断できなくなるからである。この方針により、構文解析器には、フォーマッタのためにコメントを保持することと、LSP サーバのために編集途中のソースからも回復して解析を続けることが求められる。どちらも span と同じく後付けしにくいので、最初の版から備える。詳細は[字句解析器と構文解析器](../02-impl/02-03-frontend.md)で定める。

| ツール | 使う段 |
|---|---|
| CLI の `check` | 検査 |
| CLI の `run`、MCP の `run`（サーバモード） | 検査と実行 |
| CLI の `test` | 検査と実行（テスト用のハンドラを差し替える） |
| CLI の `fmt` | 字句解析・構文解析（コメントを保持する） |
| MCP サーバ（サーバモード） | 検査と実行 |
| LSP サーバ | 検査（編集途中の文書を扱う） |

### 配布物

【方針】依存のない単一バイナリを配布できるように、言語仕様の策定時から考慮する。基準案は、VM とスクリプトを一つの実行ファイルに埋め込む形である（[設計メモ](../sources/fp-language-design.md) 20）。【決定】これは初回リリース版に含めず、正式リリース版の前までに実装する（[ADR 0175](../decisions/0175-script-embedded-binary-before-stable-release.md)）。埋め込みの方法と、C のライブラリへの依存を避けるビルドの方針は、配布形態を設計するときに Rust に合わせて決める（[配布形態](../05-platform/05-01-distribution.md)）。

【方針】言語仕様・std のリファレンス・イディオム集を専用の Agent Skill にまとめ、言語の公式配布物に同梱する（[設計メモ](../sources/fp-language-design.md) 23.3）。Agent Skills を実行する環境に処理系を入れる経路は[配布形態](../05-platform/05-01-distribution.md)で定める。

## 未決事項

- [OPEN-007](../open-issues.md#open-007): WASMコア化の採否
- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-036](../open-issues.md#open-036): 初回リリース版で循環する値を回収する方式
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
