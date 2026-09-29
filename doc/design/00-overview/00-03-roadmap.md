# ロードマップ

- 状態: 確定
- 関連ADR: [0003](../decisions/0003-license.md), [0004](../decisions/0004-surface-syntax-skeleton.md), [0005](../decisions/0005-direct-style-effects.md), [0006](../decisions/0006-basic-types-semantics.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0009](../decisions/0009-typing-without-type-classes.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0013](../decisions/0013-evaluation-order-and-tail-calls.md), [0014](../decisions/0014-fine-grain-cbv-core.md), [0015](../decisions/0015-shared-program-per-execution-state.md), [0018](../decisions/0018-reference-interpreter.md), [0035](../decisions/0035-help-suggestions-without-rewriting.md), [0037](../decisions/0037-exit-status-values.md), [0040](../decisions/0040-single-repository.md), [0042](../decisions/0042-minimal-prelude-scope.md), [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0059](../decisions/0059-higher-kinded-traits-without-prelude-monad.md), [0063](../decisions/0063-ref-cells-with-io-effect.md), [0075](../decisions/0075-capability-guarantee-scope-and-test-substitution.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0084](../decisions/0084-implementer-assignment-for-minimal.md), [0085](../decisions/0085-review-assignment-for-minimal.md), [0090](../decisions/0090-version-numbers-and-codenames.md), [0114](../decisions/0114-decimal-type.md), [0115](../decisions/0115-structured-io-concurrency.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0120](../decisions/0120-test-functions-and-assert-effect.md), [0121](../decisions/0121-pattern-extensions.md), [0122](../decisions/0122-multiline-and-raw-strings.md), [0123](../decisions/0123-top-level-constants.md), [0124](../decisions/0124-type-aliases.md), [0125](../decisions/0125-doc-comments.md), [0126](../decisions/0126-import-by-module-name.md), [0127](../decisions/0127-directory-run-and-root.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0132](../decisions/0132-language-name-benitoite.md), [0133](../decisions/0133-builtin-equality-and-key-constraints.md), [0134](../decisions/0134-standard-type-classes.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0141](../decisions/0141-http-scope-in-stdlib.md), [0142](../decisions/0142-http-api-shape.md), [0143](../decisions/0143-http-and-tls-crates.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0174](../decisions/0174-mobile-as-dedicated-app-after-first-release.md), [0175](../decisions/0175-script-embedded-binary-before-stable-release.md), [0176](../decisions/0176-first-release-targets-and-static-linux-build.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0178](../decisions/0178-resolve-all-open-issues-before-stable-release.md), [0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md), [0213](../decisions/0213-formal-verification-stage-1-in-first-release.md), [0239](../decisions/0239-cycle-collection-for-reference-cells.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md), [0241](../decisions/0241-command-name-and-extension.md), [0242](../decisions/0242-copyright-notice-for-llm-generated-code.md), [0246](../decisions/0246-syntax-measurement-in-two-stages.md)
- 未決事項: [OPEN-007](../open-issues.md#open-007), [OPEN-009](../open-issues.md#open-009), [OPEN-012](../open-issues.md#open-012), [OPEN-015](../open-issues.md#open-015), [OPEN-021](../open-issues.md#open-021), [OPEN-036](../open-issues.md#open-036), [OPEN-040](../open-issues.md#open-040), [OPEN-044](../open-issues.md#open-044), [OPEN-051](../open-issues.md#open-051), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-056](../open-issues.md#open-056)
- 移行元: [設計メモ](../sources/fp-language-design.md) 0.2, 1, 3.3, 5, 8.4, 10, 12, 16, 19, 20, 21, 23.3, 25.2（ほかは各章に散在）

## 目的と範囲

処理系を作る順序を、マイルストーンに区切って定める。各マイルストーンについて、実装する機能の範囲、着手の前に必要な仕様の決定と試作、完了条件（実行できる代表的なスクリプトと、期待する出力・診断・終了状態）を示す。あわせて、各マイルストーンで利用者に宣言する保証の範囲、エフェクトを段階的に導入する区切り、自作する部分と既存の OSS を使う部分の区分、形式検証に着手する時期、設計から実装までの分担、利用する既存の OSS のライセンスを定める。

各機能の中身は個別の章で定める。本章が扱うのは、どの機能をどの順に、何を前提として作るかだけである。

## 前提

[目的と設計原則](00-01-goals.md)の二つの目的と、目的が衝突したときの判断基準を前提とする。特に、中核の自作に時間がかかる場合は提供する範囲と時期で調整し、提供済みの機能について宣言した保証は弱めない。

処理系の構成と段は[全体像](00-02-architecture.md)に従う。処理系は Rust で書き、LLM が実装する（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。

本章でいう「実装プラン」は、実装を担う LLM（以下「実装 LLM」）が設計書と合わせて読み、それだけで実装できるように作業を分割した文書を指す。

## 仕様

### マイルストーンの区分

【方針】処理系は、次の順に作る。

| マイルストーン | 位置付け | 利用者への提供 | バージョン |
|---|---|---|---|
| 最小実行版 | 言語の中核の小さな部分集合を、検査から実行まで一通り動かす版 | しない。設計者と LLM が、設計と実装の方式を確かめるために使う | `0.0.0` |
| 初回リリース版 | Agent Skills から実用的な作業を自動化できる最初の版 | する | `0.1.0` |
| 将来拡張 | 初回リリース版の後に、必要と判断したものから順に加える機能 | 機能ごとに判断する | `0.1.0` の後の版 |

最小実行版を利用者に提供しないのは、言語の範囲が小さく、実用的な作業を自動化できないからである。実行時の権限制御を持たないことは、提供しない理由にしない。初回リリース版も実行時の権限制御を持たず、静的検査だけを保証して利用者に提供する（次節、[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。[全体像](00-02-architecture.md)の「スクリプトの作成から実行までの流れ」のうち、利用者が権限を確認して実行を許可する手順は、初回リリース版の後にサーバモードとあわせて成り立たせる（[OPEN-055](../open-issues.md#open-055)）。

初回リリース版の範囲が大きいので、実装プランでは初回リリース版をさらに小さな単位に分けて進めてよい。その単位は本章では定めず、実装プランで定める。

### バージョンとコードネーム

【決定】処理系のバージョンは、メジャー・マイナー・パッチの三つの数を `.` でつないだ形（`1.2.3` など）で表す（[ADR 0090](../decisions/0090-version-numbers-and-codenames.md)）。

| バージョン | 版 | 意味 |
|---|---|---|
| `0.0.0` | 最小実行版 | 利用者に提供しない |
| `0.1.0` | 初回リリース版 | 利用者に提供する最初の版 |
| `0.x.y` | 初回リリース版の後の版 | メジャーバージョンが 0 の間は、マイナーバージョンを上げる版で、互換性を壊す変更をしてよい。破壊的な変更は頻繁に起こりうる |
| `1.0.0` | 正式リリース版 | 互換性を壊す変更を、メジャーバージョンを上げる版に限る最初の版 |

正式リリース版とする条件と、互換性を壊す変更に当たるものの範囲（言語のソース、標準ライブラリ、CLI、診断など）は【未決】である（[OPEN-040](../open-issues.md#open-040)）。互換性の方針の詳細は[配布形態](../05-platform/05-01-distribution.md)で定める。

コードネームは、メジャーバージョンが 1 の間まで `San Benito` とする。メジャーバージョン 2 からは新しいコードネームとし、候補は `Itoigawa` と `Okutama` である（[ADR 0090](../decisions/0090-version-numbers-and-codenames.md)）。

### 各マイルストーンで宣言する保証

【方針】各マイルストーンで、静的検査と実行時の権限制御について宣言する範囲は次のとおりとする。ここに書いていない保証を、そのマイルストーンの処理系が満たしていると宣言しない。

| マイルストーン | 静的検査が保証すること | 実行時の権限制御 |
|---|---|---|
| 最小実行版 | 型の規則への適合。エフェクトは、IO を行うか否かだけを区別する。関数を引数にとる関数は、エフェクト変数で多相にする（[ADR 0008](../decisions/0008-effect-variables.md)） | 行わない。スクリプトはすべての操作を行える |
| 初回リリース版 | 上記に加え、組み込みの細かいエフェクト（`File.Read`・`Process.Run` など）の区別。型のエフェクトに含まない組み込みの操作（プロセスの終了、外部コマンドの起動など）を行わないこと。利用者が定義するエフェクトが、どこかのハンドラで処理されること | 行わない。スクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行える。隔離は、処理系を起動する側（ハーネスのサンドボックス、コンテナ、OS の権限）に委ねる（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） |
| 将来拡張 | 機能ごとに定める | サーバモードとあわせて、利用者が許可した範囲の外の操作を拒否する仕組みと、OS のサンドボックスによる強制を加える。範囲はサーバモードの設計で定める（[OPEN-055](../open-issues.md#open-055)） |

【決定】初回リリース版には外部の関数の層を実装しないので、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけであり、どれも IO 実行器を通す（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。後の版で加える外部の関数は WASM のモジュールの関数に限り、外部に作用する経路を処理系が与えるホストの関数に限る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。

### 最小実行版

#### 範囲

【方針】最小実行版には、次のものを含める。

| 領域 | 含めるもの |
|---|---|
| 言語 | 単一ファイルのスクリプト、関数の定義と適用、局所束縛、条件分岐、代数的データ型とパターンマッチ（網羅性の検査を含む）、HM 型推論、末尾呼び出しの保証、IO エフェクトの注釈と検査（[ADR 0005](../decisions/0005-direct-style-effects.md)）、エフェクト変数（[ADR 0008](../decisions/0008-effect-variables.md)） |
| 基本型 | 整数・浮動小数・文字列・文字・真偽値・Unit（[ADR 0006](../decisions/0006-basic-types-semantics.md)） |
| ライブラリ | prelude の Option・Result・リスト、標準出力と標準エラー出力への書き込み、ファイルの読み取り、コマンドライン引数（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)） |
| 処理系 | 全体像の章の全段（字句解析から VM とランタイムまで）。span、コメントの保持、構文エラーからの回復は最初の版から備える |
| 診断 | 診断コード、span、ソースの抜粋を持つ診断。`help:` による修正案の簡易版（[ADR 0035](../decisions/0035-help-suggestions-without-rewriting.md)）。診断エンジンと CLI のアダプタ |
| ツール | CLI の `check` と `run` |
| 文書 | [OPEN-012](../open-issues.md#open-012) の測定で LLM に与える、最小限の言語リファレンス |

【方針】次のものは最小実行版に含めない。モジュールと import、型クラス、可変状態、明示遅延、リソーススコープ、組み込みの細かいエフェクト、エフェクトのハンドラ、権限の表示と権限制御、MCP サーバ、フォーマッタ、テストランナー、Agent Skill の同梱。

型クラスを含めない間、組み込み型の等値と比較は、演算子ごとに決まった型の集まりによる制約で型付けする（[ADR 0009](../decisions/0009-typing-without-type-classes.md)、[型システム](../01-spec/01-06-type-system.md)）。文字列化は、型ごとの関数（`Integer.toString` など）で行う（[基本型の意味論](../01-spec/01-04-types-basic.md)）。

【決定】言語の値は、最小実行版では参照カウントで管理する。最小実行版の言語では値どうしの参照が循環しないので、使わなくなった値はすべて回収される（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。

#### 着手の前に必要な決定

【方針】最小実行版の実装プランを作る前に、次の事項を決める。

| 事項 | 理由 |
|---|---|
| 表層構文（骨格は [ADR 0004](../decisions/0004-surface-syntax-skeleton.md) で決めた。[OPEN-001](../open-issues.md#open-001) は決着） | 構文解析器の前提になる。ただし、[OPEN-012](../open-issues.md#open-012) の測定の結果、初回リリース版までに変える可能性を残す |
| 文字列と整数の基本意味論（[ADR 0006](../decisions/0006-basic-types-semantics.md) で決めた。[OPEN-002](../open-issues.md#open-002) は決着） | 基本型の演算が決まる |
| IO の書き方（[ADR 0005](../decisions/0005-direct-style-effects.md) で決めた。[OPEN-003](../open-issues.md#open-003) は決着） | 最小実行版で IO エフェクトを利用者のコードに見せるので、後から内部表現を変えられるかがここで決まる |
| 外部から受け取る文字列が正しい UTF-8 でないときの扱い（[ADR 0012](../decisions/0012-invalid-utf8-input.md) で決めた。[OPEN-027](../open-issues.md#open-027) は決着） | 最小実行版のファイルの読み取りとコマンドライン引数が、この場合にどう振る舞うかが決まる |
| エフェクト多相（[ADR 0008](../decisions/0008-effect-variables.md) で決めた。[OPEN-022](../open-issues.md#open-022) は決着） | 最小実行版の高階関数（prelude のリストの操作など）の型が決まる |
| VM の再入可能性（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md) で決めた。[OPEN-005](../open-issues.md#open-005) は決着） | 後付けが難しい |
| 実装プランの置き場所（[ADR 0040](../decisions/0040-single-repository.md) で決めた） | 最初の実装プランを作る前に必要になる |
| 言語の名前、CLI のコマンドの名前、拡張子（[ADR 0132](../decisions/0132-language-name-benitoite.md) と [ADR 0241](../decisions/0241-command-name-and-extension.md) で、Benitoite、`benitoite`、`.bnt` に決めた。[OPEN-011](../open-issues.md#open-011) は決着） | コマンドの名前とスクリプトの拡張子が、処理系とテストに現れる。実装プランは仮の名前で作り、最小実行版は仮の名前のまま実装した（2026-09-27 に設計者が承認）。後に同じ名前で確定したので、置き換えは要らない |

【決定】最小実行版の実装 LLM と実装の確認の分担は、実装プランで分けた作業ごとの難易度を見積もってから決めた。Claude Code がオーケストレータとして作業を配り、難しい作業を Claude Opus 5.5 のサブエージェントに、それ以外を Codex と GPT-6-Luna の組み合わせに割り当てる（[ADR 0084](../decisions/0084-implementer-assignment-for-minimal.md)）。実装の確認はオーケストレータが行い、Opus が実装した作業は Codex も確かめる（[ADR 0085](../decisions/0085-review-assignment-for-minimal.md)）。実装プランは、特定の実装 LLM に頼らず、設計書と実装プランだけを読めば実装できる粒度で書く。

【方針】最小実行版の実装プランが依存する章は、[字句構造](../01-spec/01-01-lexical.md)、[構文](../01-spec/01-02-syntax.md)、[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)、[基本型の意味論](../01-spec/01-04-types-basic.md)、[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)、[型システム](../01-spec/01-06-type-system.md)、[エフェクト](../01-spec/01-07-effects.md)、[評価意味論](../01-spec/01-08-evaluation.md)、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)、`02-impl/` の各章、[標準ライブラリ](../03-interop/03-06-stdlib.md)、[CLI](../06-tooling/06-01-cli.md)、[性能](../07-quality/07-02-performance.md)、[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)である。いずれも、最小実行版の範囲に当たる節を先に書く。

#### 完了条件

【方針】最小実行版は、次のスクリプトがすべて期待どおりに振る舞ったときに完了とする。スクリプトの具体的な形は構文が決まってから書き、仕様の項目との対応を[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)で管理する。終了状態の具体的な値は [CLI](../06-tooling/06-01-cli.md) で定める。

| スクリプト | 期待する振る舞い |
|---|---|
| 固定の文字列を標準出力に書く | その文字列を出力し、成功を表す終了状態で終わる |
| 利用者が代数的データ型で定義したリストを、パターンマッチで集計して出力する（[ADR 0007](../decisions/0007-constructors-and-list.md)） | 期待する集計値を出力する |
| 十分に深い末尾再帰を行う | スタックを使い果たさずに終わる |
| 型の合わない式を含む | `check` と `run` のどちらでも実行せず、診断コード・span・ソースの抜粋を持つ診断を出し、失敗を表す終了状態で終わる |
| 網羅していないパターンマッチを含む | 実行前に、漏れているパターンを示す診断を出す |
| IO を行う関数を、IO を許さない文脈から呼ぶ | 実行前に、エフェクトの規則への違反として診断を出す |
| ファイルを読んで行数を数える | 行数を出力する。ファイルがなければ、失敗の理由を示して失敗を表す終了状態で終わる |
| 構文エラーを含む | 誤りの位置を示す診断を出す |

加えて、[性能](../07-quality/07-02-performance.md)で定めるベンチマークのうち、最小実行版の範囲で書けるものが実行できることを完了条件に含める。

### 性能の測定

【方針】最小実行版の完了後に性能を測定する。測定の結果は、初回リリース版に進む前に処理系の最適化が要るかを決める材料にする。性能を理由に実装言語を見直す段階は設けない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。測定の対象とベンチマークは[性能](../07-quality/07-02-performance.md)で定める（[OPEN-009](../open-issues.md#open-009)）。

### 初回リリース版

#### 範囲

【方針】初回リリース版には、最小実行版に加えて次のものを含める。

| 領域 | 含めるもの |
|---|---|
| 言語 | モジュールと import（名前で取り込み、根のディレクトリの下に限る。[ADR 0126](../decisions/0126-import-by-module-name.md)）、ディレクトリを指定した実行（[ADR 0127](../decisions/0127-directory-run-and-root.md)）、型クラス（辞書渡し。上位の型クラスを含む）、利用者が書ける組み込みの制約 `equality`・`key`（[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）、レコード、可変状態、明示遅延（`lazy`・`Lazy.force`）、リソーススコープ、文字列補間、複数行の文字列と raw 文字列、パターンの拡張（ガード・選択肢・範囲・リスト）、トップレベルの定数（[ADR 0123](../decisions/0123-top-level-constants.md)）、型の別名（[ADR 0124](../decisions/0124-type-aliases.md)）、ドキュメントコメント（[ADR 0125](../decisions/0125-doc-comments.md)）、エラー処理、属性（`@test`・`@deprecated`。[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md)）、構造化された IO の並行処理（[ADR 0115](../decisions/0115-structured-io-concurrency.md)） |
| エフェクトと権限 | 組み込みの細かいエフェクト、モジュールの中で宣言するエフェクト、利用者が定義するエフェクトとハンドラ（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0118](../decisions/0118-effect-handlers.md)、[ADR 0129](../decisions/0129-effects-declared-in-modules.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）、スクリプトのディレクトリを返す関数（[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)）、契約の変更の表示（[OPEN-015](../open-issues.md#open-015)）。権限の宣言の構文は設けない（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。実行時の権限制御、実行前の権限の表示、権限の変更の表示は含めない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） |
| ライブラリ | 名前空間 `Benitoite` の標準ライブラリ（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。prelude の永続コレクション、`Benitoite.IO` の下の IO を行うモジュール（外部コマンドの起動 `Process.run`・`Process.shell` を含む）、`Benitoite.Trait` の標準の型クラス（[ADR 0134](../decisions/0134-standard-type-classes.md)）。テキストとデータを処理する純粋なモジュール（`Benitoite.Path`・`Json`・`Regex`・`Csv`・`Time`・`Encoding`・`Hash`）。`Benitoite.Network.Http` の HTTP のサーバ（TLS なし）とクライアント（HTTPS を含む。[ADR 0140](../decisions/0140-network-separated-from-local-io.md)、[ADR 0141](../decisions/0141-http-scope-in-stdlib.md)）。範囲は [ADR 0137](../decisions/0137-first-release-library-scope.md)、実装に使うクレートは [ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) と [ADR 0143](../decisions/0143-http-and-tls-crates.md) で定めた |
| ツール | CLI の `run`・`check`・`test`・`fmt`、シェバンによる実行（いずれもスタンドアロンモード。[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）、同梱の Agent Skill |
| 診断 | `help:` による修正案を、検査の誤りの診断全般に広げる（[ADR 0035](../decisions/0035-help-suggestions-without-rewriting.md)） |
| 配布 | 処理系の単一バイナリ（macOS の arm64、Linux の x86_64・arm64。[配布形態](../05-platform/05-01-distribution.md)、[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)） |

並行処理は、スクリプトで簡易な HTTP サーバ（HTML を返す、REST API を提供する）を動かせる水準とする。一つのタスクが接続を待ち受けたり計算を続けたりしている間も、ほかのタスクを止めない。複数のコアでの並列化は含めない（[並行処理](../01-spec/01-11-concurrency.md)）。HTTP サーバの API は[ネットワークのモジュール](../03-interop/03-09-network.md)で定める（[ADR 0142](../decisions/0142-http-api-shape.md)）。ネットワークの操作の権限は、サーバモードの実行時の権限制御の方式とあわせて [OPEN-052](../open-issues.md#open-052) で決める。

go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。設計メモ 16 が std で優先するとした機能（ファイル、外部コマンド、パス、テキスト処理、JSON）は、どれも初回リリース版の標準ライブラリに入れる（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。

【方針】次のものは初回リリース版に含めない。JIT コンパイラ（[設計メモ](../sources/fp-language-design.md) 0.2 の非目標）、複数のコアでの並列化、LSP サーバ、パッケージ管理、外部の関数の実装（言語の表面だけを定める。[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）、WASM プラグイン、スクリプトを埋め込んだ実行ファイルの生成、処理系コアの WASM 化、モバイル向けの提供（[ADR 0174](../decisions/0174-mobile-as-dedicated-app-after-first-release.md)）、サーバモード、実行時の権限制御、OS のサンドボックスによる強制、MCP サーバ（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。

#### 着手の前に必要な決定と試作

【方針】初回リリース版の各機能の実装プランを作る前に、次の事項を決める、または確かめる。

| 事項 | 必要になる機能 |
|---|---|
| 初回リリース版のライブラリの提供方法（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0139](../decisions/0139-external-functions-via-wasm.md) で決めた。[OPEN-035](../open-issues.md#open-035) は決着） | 標準ライブラリ |
| 表層構文の確定（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md) の骨格を、[OPEN-012](../open-issues.md#open-012) の測定の第一段階（構文だけの測定）の結果を踏まえて見直し、キーワードと予約語を決める。[ADR 0246](../decisions/0246-syntax-measurement-in-two-stages.md)） | 言語の追加機能、フォーマッタ、Agent Skill |
| 可変状態と let 多相（[ADR 0063](../decisions/0063-ref-cells-with-io-effect.md) で決めた。[OPEN-004](../open-issues.md#open-004) は決着） | 可変状態 |
| レコードのフィールド参照（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md) で決めた。[OPEN-023](../open-issues.md#open-023) は決着） | レコード |
| 型クラスで高カインド型を扱うか（[ADR 0059](../decisions/0059-higher-kinded-traits-without-prelude-monad.md) で決めた。[OPEN-024](../open-issues.md#open-024) は決着） | 型クラス |
| エラーを呼び出し元へ伝える構文（[ADR 0097](../decisions/0097-prefix-try.md) で決めた。[OPEN-029](../open-issues.md#open-029) は決着） | エラー処理 |
| 契約の変更の示し方（[OPEN-015](../open-issues.md#open-015)。権限の差分の示し方はサーバモードとあわせて決める） | 契約の変更の表示 |
| 循環する値を回収する方式（[OPEN-036](../open-issues.md#open-036)。値の表現とランタイムの作り直しで決める。暫定の方式は [ADR 0239](../decisions/0239-cycle-collection-for-reference-cells.md)。[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)） | 可変状態 |

【決定】[OPEN-012](../open-issues.md#open-012) の測定は二段階で行う（[ADR 0246](../decisions/0246-syntax-measurement-in-two-stages.md)）。第一段階は、実装プランを作る前に、文法を確かめる道具（`tools/grammar-check/`）の文法と同梱の Skill の文法の参照の文書を構文の案ごとに差し替え、LLM が書いたスクリプトの構文の誤りの率と、診断を読んで 1 回で直せた率を比べる。型とエフェクトは測らない。第二段階は、初回リリース版の検査器ができた後、提供の前に、Skill の評価の仕組み（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)の「Skill の評価」）で期待結果まで測る。第二段階で構文を改めるのは、大きな問題が見つかったときに限る。どちらの段階でも OpenCode をハーネスの一つとして使い、使うモデルと LLM を呼ぶ回数は、測定を計画するときに設計者と相談して決める。

【方針】処理系コアを WASM 化するかは、初回リリース版で外部コマンドの起動（`Process.run`）とシェルによる実行（`Process.shell`）を実装した後に判断する（[OPEN-007](../open-issues.md#open-007)）。設計メモ 21 の「OS 連携を試作してから採否を決める」に当たる。採用すると判断しても、WASM 化は初回リリース版に含めない。

【決定】初回リリース版を利用者に提供する前には、初回リリース版の範囲にかかわる未決事項を決着させる。すべての未決事項を決着させるのは、正式リリース版を利用者に提供する前とする。正式リリース版で扱わない事項は、扱わないことを ADR に記録して決着させる。設計書の最終版は、この時点で発行する（[ADR 0178](../decisions/0178-resolve-all-open-issues-before-stable-release.md)）。

#### 完了条件

【方針】初回リリース版は、次の条件をすべて満たしたときに完了とする。

| 条件 | 期待する振る舞い |
|---|---|
| 同梱の Agent Skill だけを与えた LLM が、JSON ファイルを読んで集計するスクリプトを書く | 検査・診断・修正を繰り返して検査を通り、期待する出力を得る |
| 外部コマンドを引数の配列で起動するスクリプト（`Process.run`）と、シェルで実行するスクリプト（`Process.shell`）を実行する | どちらも期待する出力を得る |
| 影響の大きい操作（外部コマンドの起動、プロセスの終了、ファイルの書き込み）を、テストのコードのハンドラで差し替えて `test` を実行する（[ADR 0117](../decisions/0117-capabilities-as-effects.md)、[ADR 0118](../decisions/0118-effect-handlers.md)） | それらの操作を外部に行わずにテストが通る |
| コメントを含むスクリプトに `fmt` を適用する | コメントが保たれ、整形後も同じ検査結果になる |
| 処理系の単一バイナリを、[配布形態](../05-platform/05-01-distribution.md)で定める各環境で実行する | 上の各条件が同じ結果になる |

### 将来拡張

【方針】初回リリース版の後に、次の機能を検討する。順序は、初回リリース版を使った結果を見て決める。

| 機能 | 関連する章・未決事項 |
|---|---|
| LSP サーバ（診断から始め、ホバー・補完へ進める） | [LSP サーバ](../06-tooling/06-02-lsp.md) |
| 複数のコアでの並列化 | [並行処理](../01-spec/01-11-concurrency.md)、[OPEN-044](../open-issues.md#open-044) |
| パッケージ管理 | [パッケージ管理](../06-tooling/06-05-package-manager.md) |
| 外部の関数（WASM のモジュールの関数）の実装 | [外部の関数](../04-extensions/04-01-external-functions.md)（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)、[OPEN-051](../open-issues.md#open-051)） |
| WASM プラグイン | [プラグイン基盤](../04-extensions/04-02-plugins-wasm.md) |
| スクリプトを埋め込んだ実行ファイル（単一バイナリ）の生成。正式リリース版の前までに実装する | [スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)（[ADR 0175](../decisions/0175-script-embedded-binary-before-stable-release.md)） |
| 処理系コアの WASM 化 | [OPEN-007](../open-issues.md#open-007) |
| モバイル（処理系を組み込んだ専用のアプリ。検討は初回リリース版の後、実装は正式リリース版の時点かそれより後） | [モバイル・Android系](../05-platform/05-03-mobile.md)（[ADR 0174](../decisions/0174-mobile-as-dedicated-app-after-first-release.md)） |
| REPL | [CLI](../06-tooling/06-01-cli.md) |
| [サーバモード](../06-tooling/06-07-server.md)（スクリプトを実行するデーモン、スクリプトの登録と背景での実行、実行時の権限制御、OS のサンドボックスによる強制、認証と監査、MCP サーバ、TUI、自前のコーディングエージェント）。初回リリース版の後に実装する（[ADR 0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md)、[OPEN-056](../open-issues.md#open-056)） | [OPEN-055](../open-issues.md#open-055)（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-015](../open-issues.md#open-015)、[OPEN-052](../open-issues.md#open-052)） |
| 値の範囲を型で表す篩型（算術の実行時エラーを起こさないことを実行の前に証明する） | [形式意味論と検証](../07-quality/07-04-formal-semantics.md)（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)） |

並行処理は、初回リリース版で IO の並行を提供し、複数のコアでの並列化はその後に目指す（[ADR 0115](../decisions/0115-structured-io-concurrency.md)）。並列にしても、初回リリース版の並行処理の意味は変えない。

### エフェクトの段階導入

【方針】エフェクトは、設計メモ 3.3 の段階に沿って導入する。各段階とマイルストーンの対応は次のとおりである。

| 段階 | 内容 | マイルストーン |
|---|---|---|
| 1 | 外部に作用する処理を、一律に単一の粗い `IO` として扱う。IO の実行時期・順序・失敗時の扱いを定める | 最小実行版 |
| 2 | `IO` を組み込みの細かいエフェクトに分け、プロセスの終了・外部コマンドの起動など、影響の大きい操作をエフェクトで制限する（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)、[ADR 0117](../decisions/0117-capabilities-as-effects.md)） | 初回リリース版 |
| 3 | 外部の関数（WASM のモジュールの関数）を加えた後、設計者が確かめた機能を、標準ライブラリの組み込みの関数へ移す（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)） | 外部の関数を実装する版から随時 |
| 4 | 利用者が定義するエフェクトとハンドラ（代数的エフェクト）を導入する（[ADR 0118](../decisions/0118-effect-handlers.md)） | 初回リリース版 |

設計メモ 3.3 は、単一の IO、ケーパビリティ、代数的エフェクトを独立した軸とし、最終的な構成でも併用しうるとしていた。初回リリース版では、ケーパビリティの値を設けず、影響の大きい操作もエフェクトで制限する（[ADR 0117](../decisions/0117-capabilities-as-effects.md)）。最小実行版の `IO` は、初回リリース版で組み込みのエフェクトをまとめた名前として残す。

段階 2 のエフェクトによる制限が実行時の権限制御と合わせて実効性を持つのは、外部に作用するすべての経路が IO 実行器を通るようになってからである（[全体像](00-02-architecture.md)の「エフェクトと権限の置き場所」）。初回リリース版で宣言する範囲は、前述の「各マイルストーンで宣言する保証」に従う。

### 自作する部分と既存の OSS を使う部分

【方針】目的が衝突したときの判断基準（[目的と設計原則](00-01-goals.md)）に従い、処理系の各部分を次のように分ける。ここでいう自作は、既存の OSS を使わずにこのプロジェクトで設計・実装することであり、実装は LLM が行う。

| 部分 | 区分 | 理由 |
|---|---|---|
| 型検査器（HM 型推論・型クラス・エフェクト検査） | 自作 | 言語の中核 |
| 永続コレクション | 自作 | 言語の中核 |
| 字句解析器・構文解析器 | 自作 | 実質的な目的（言語処理系の学習）の対象 |
| 中間表現・バイトコード・VM | 自作 | 実質的な目的の対象 |
| 診断エンジン | 自作 | LSP の形式に依存しない独自の表現を持つ（[設計メモ](../sources/fp-language-design.md) 8.2） |
| WASM プラグインの ABI | 自作 | 型システムと一体で設計する（同 19.2） |
| 言語の値の回収 | 自作 | 最小実行版は参照カウントで行う（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。初回リリース版で循環を回収する方式は、既存のクレートを使う案を含めて、実装プランを作るときの値の表現とランタイムの作り直しで決める（[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)、[OPEN-036](../open-issues.md#open-036)） |
| 10 進の小数（`Decimal`）の算術 | 既存（使うクレートは初回リリース版の実装プランで選ぶ） | 言語の中核にも処理系の主要部にも当たらない（[ADR 0114](../decisions/0114-decimal-type.md)） |
| MCP のプロトコル処理 | 既存 | 同 8.1 |
| WASM の実行エンジン | 既存（どれを使うかは [OPEN-051](../open-issues.md#open-051) で決める） | 同 19.1 |

### 利用する既存の OSS のライセンス

利用を予定する既存の OSS のライセンスは次のとおりである。処理系を Rust で実装することにした（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）ので、標準ライブラリの実装に使うクレートと、依存に許可するライセンスは [ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) で定めた。MCP サーバに使う OSS は MCP サーバを設計するときに、WASM の実行エンジンは [OPEN-051](../open-issues.md#open-051) で選び、選んだ時点でライセンスを確かめる。

| OSS | 用途 | ライセンス | 使い始めるマイルストーン |
|---|---|---|---|
| Rust（標準ライブラリ） | 処理系と標準ライブラリの実装の基盤 | MIT と Apache-2.0 のどちらかを選べる（[ADR 0003](../decisions/0003-license.md) の表） | 最小実行版 |

性能の比較対象は測定に使うだけで、配布物には含めない。

いずれも許容型のライセンスであり、処理系のバイナリに含めて配布するときは、著作権表示とライセンス文を配布物に添える必要がある。Apache-2.0 のものは NOTICE ファイルの内容も添える。【方針】添える一覧は、手で管理せず、配布するバイナリが実際に含むモジュールから生成する。ライセンスはバージョンによって変わりうるからである。表示の方法は[配布形態](../05-platform/05-01-distribution.md)で定める。

【決定】処理系・標準ライブラリ・同梱の Agent Skill・言語の文書・設計書のリポジトリのライセンスは、MIT と Apache-2.0 のデュアルライセンス（`MIT OR Apache-2.0`）とする（[ADR 0003](../decisions/0003-license.md)）。`doc/design/sources/` は対象から外し、各資料の元のライセンスに従う。著作権表示は `Copyright (c) 2026 <設計者の名前> and Benitoite contributors` とし、処理系のコードの大部分を LLM が生成したことを README とライセンスのファイルの近くに書く（[ADR 0242](../decisions/0242-copyright-notice-for-llm-generated-code.md)、[配布形態](../05-platform/05-01-distribution.md)の「ライセンスの表示」）。設計者の名前の書き方は【未決】である（[OPEN-021](../open-issues.md#open-021)）。

### 形式検証の時期

【方針】形式検証は、設計メモ 25.2 の段階に沿って、次の時期に行う。

| 段階 | 内容 | 時期 |
|---|---|---|
| 0 | コア計算の構文・型付け規則・簡約規則を数学記法で書く | [コア計算と脱糖](../01-spec/01-12-core-calculus.md)を書くとき。最小実行版の実装プランより前 |
| 1 | 実行可能な意味論を用意し、ランダムに生成したプログラムで反例を探す（証明ではない） | 初回リリース版の実装の中（[ADR 0213](../decisions/0213-formal-verification-stage-1-in-first-release.md)） |
| 2 | 証明支援系で、選んだ性質を証明する | 初回リリース版の後 |

【決定】段階 1 は、初回リリース版の実装の中で行う。実行可能な意味論には、参照インタプリタ（[ADR 0018](../decisions/0018-reference-interpreter.md)）を初回リリース版の範囲に広げたものを使う。型の付くプログラムを無作為に生成し、VM と参照インタプリタの両方で実行して結果を比べ、反例を探す（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)の「差分テスト」）。反例から[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の規則の誤りが分かったときは、ADR を添えて規則を直す。01-12 は設計書のレビューの後に「確定」にし、確定の後も段階 1 の結果による修正は ADR を添えて行う（[ADR 0213](../decisions/0213-formal-verification-stage-1-in-first-release.md)）。

段階 2 の対象とツールは[形式意味論と検証](../07-quality/07-04-formal-semantics.md)で選ぶ。

### 設計から実装までの分担と進め方

【方針】各マイルストーン（初回リリース版は実装プランで分けた単位ごと）を、次の手順で進める。

1. Claude Code が、そのマイルストーンが依存する章の節を書き、設計者と合意する。
2. Claude Code が実装プランを作る。実装プランは作業ごとに、読むべき設計書の節、作るもの、受け入れテストを示す。各作業の完了条件には、[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)の「実装の規約と静的な検査」の検査を含める。実装プランは、処理系設計（`02-impl/`）が定めるデータ構造を、Rust の型の定義と主要な関数のシグネチャとして示す（同じ節）。依存する設計書の節には、実装プランの中で試作として扱うものを除き、【未決】【要検証】を残さない。
3. 実装 LLM が、実装プランに従って実装する（最小実行版の割り当ては [ADR 0084](../decisions/0084-implementer-assignment-for-minimal.md)）。
4. 受け入れテストと完了条件で実装を確かめる。設計書と実装が食い違ったら、言語仕様を正として実装を直すか、ADR を添えて設計書を改める。
5. 設計者は実装を読み、必要なときに実装の理由を LLM に質問する（[目的と設計原則](00-01-goals.md)）。

【決定】実装プランと処理系のソースコードは、設計書と同じ本リポジトリに置く（[ADR 0040](../decisions/0040-single-repository.md)）。最小実行版の手順 4 の確認は、オーケストレータの Claude Code が行い、Opus が実装した作業は Codex も確かめる（[ADR 0085](../decisions/0085-review-assignment-for-minimal.md)）。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-044](../open-issues.md#open-044): 複数のコアで並列に計算する方式
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式
- [OPEN-007](../open-issues.md#open-007): WASMコア化の採否
- [OPEN-009](../open-issues.md#open-009): 実行性能
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度
- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-021](../open-issues.md#open-021): 処理系・標準ライブラリ・文書・設計書のライセンス
- [OPEN-036](../open-issues.md#open-036): 初回リリース版で循環する値を回収する方式
- [OPEN-040](../open-issues.md#open-040): 正式リリース版とする条件と、互換性を壊す変更の範囲
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-056](../open-issues.md#open-056): 自前のコーディングエージェントの設計
