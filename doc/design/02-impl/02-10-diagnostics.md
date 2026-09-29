# 診断エンジン

- 状態: 確定
- 関連ADR: [0012](../decisions/0012-invalid-utf8-input.md), [0019](../decisions/0019-stop-after-failing-stage.md), [0024](../decisions/0024-continue-after-type-errors.md), [0025](../decisions/0025-columns-in-code-points.md), [0031](../decisions/0031-numbered-diagnostic-codes.md), [0032](../decisions/0032-rust-style-text-and-json.md), [0033](../decisions/0033-english-diagnostic-messages.md), [0034](../decisions/0034-call-trace-in-runtime-errors.md), [0035](../decisions/0035-help-suggestions-without-rewriting.md), [0037](../decisions/0037-exit-status-values.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0047](../decisions/0047-parenthesized-types-and-uses-binding.md), [0049](../decisions/0049-size-limit-for-built-values.md), [0068](../decisions/0068-release-resources-on-stop.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0093](../decisions/0093-no-reserved-words-for-absent-constructs.md), [0113](../decisions/0113-div-and-mod-operators.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0119](../decisions/0119-attributes-test-and-deprecated.md), [0123](../decisions/0123-top-level-constants.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0136](../decisions/0136-map-and-set-in-constants.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md), [0155](../decisions/0155-resume-not-in-lazy.md), [0156](../decisions/0156-module-loading-and-whole-program-checking.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0208](../decisions/0208-test-report-destination.md), [0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md), [0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)
- 未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-058](../open-issues.md#open-058)
- 移行元: [設計メモ](../sources/fp-language-design.md) 8.2, 8.3

## 目的と範囲

診断データモデル、エラーコード体系、各アダプタへの変換。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。対象は、診断の内部の表現、修正案とその置き換え、診断コードの体系と区分、警告の扱い、CLI への出力（文章と JSON）、実行時エラー・資源の不足・解放の失敗・処理系の不具合・処理系の制限の報告、MCP サーバと LSP サーバとテストの実行器への受け渡しである。MCP サーバの通信の形は[サーバモード](../06-tooling/06-07-server.md)で、LSP サーバの通信の形は[LSP サーバ](../06-tooling/06-02-lsp.md)で、テストの結果の報告の形は[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。

## 前提

各段は出力と診断の組を返し、誤りがあれば次の段に進まない（[ADR 0019](../decisions/0019-stop-after-failing-stage.md)）。初回リリース版のプログラムは複数のモジュールからなり、名前解決と型検査はプログラム全体を一つの単位として行う（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）。位置は内部ではバイトで持ち、行と列への変換は出力の直前に行う（[ソース管理と位置情報](02-02-source-and-spans.md)）。各段が出す診断の内容（どの誤りに何を示すか）は、仕様の各章と、各段の章で定める。実行時エラーの種類は[評価意味論](../01-spec/01-08-evaluation.md)で、実行時の報告の材料の集め方は[仮想機械](02-08-vm.md)と[ランタイム](02-09-runtime.md)で定める。

## 仕様

### 診断の内部の表現

【方針】診断は、プロトコルに依存しない次の表現で持つ（[設計メモ](../sources/fp-language-design.md) 8.2）。

| 項目 | 内容 |
|---|---|
| 重大度 | 誤り、または警告 |
| コード | 診断コード（後述） |
| 文言 | 誤りの内容を一文で表す |
| 主な位置 | span と、その位置に添える短いラベル（`expected Integer, found String` など） |
| 補助の位置 | span とラベルの組の並び（型を宣言した箇所、覆っている前の分岐など） |
| 注記 | 補足の文の並び（`note:`） |
| 修正案 | 修正案の並び（`help:`）。各修正案は、直し方を示す文と、置き換えの並び（後述の「修正案」）を持つ |

各段は、この表現で診断を作り、診断の一覧として返す。文言・ラベル・注記・修正案の文は、診断コードごとの文言の表（後述）の型板に、型の名前や識別子などの値を埋めて作る。

実行時エラー・資源の不足・解放の失敗の報告は、上の項目に加えて、呼び出しの履歴と、タスクの起動の履歴（後述の「実行時エラーと資源の不足の報告」）を持つ。

CLI の文章と JSON、MCP サーバ、LSP サーバ、テストの実行器は、どれもこの表現から出力を作る。

### 修正案

【決定】処理系は、ソースを直接修正しない。修正案を示すだけとし、ソースを修正するのは、利用者か、利用者から指示を受けた LLM である（[ADR 0035](../decisions/0035-help-suggestions-without-rewriting.md)）。

【決定】初回リリース版では、修正案を示す診断を検査の誤りの診断全般に広げる。利用者のソースの該当箇所を使って、書き換えた後のコードの例を組み立てて示す（[ADR 0035](../decisions/0035-help-suggestions-without-rewriting.md)）。

【方針】修正案は、直し方を示す文と、置き換えの並びからなる。置き換えは、ソースの範囲（ファイルと span）と、その範囲に入れる文字列の組である。範囲が空であれば挿入、入れる文字列が空であれば削除を表す。

- 置き換えは、それを当てれば誤りがなくなると処理系が決められるときだけ付ける（`uses IO` を `uses IO.All` にする、`;` を消す、`Tree.Leaf()` の括弧を消す、など）。直し方が一つに決まらないとき（綴りの近い名前が複数ある、型注釈に書く型が決まらないなど）は、文だけを示す。一つの修正案の置き換えは、互いに重ならない。
- 置き換えは、LSP サーバのコードアクションと、MCP サーバが返す修正案に使う。処理系は置き換えを当てない。CLI の文章の形式では、置き換えを当てた後の行を示す（後述の「文章の形式」）。
- 文は、置き換えを当てるかを判断するための説明であり、置き換えがなくても直し方が分かるように書く。

【方針】修正案を示す診断は、少なくとも次のものとする。いずれも、仕様の各章または処理系の各章が修正案を求めている。「置き換え」の欄は、置き換えを付けるかを示す。

| 誤り | 修正案 | 置き換え | 定める章 |
|---|---|---|---|
| キーワードを名前に使った | その語がキーワードであることと、別の名前を付けること | なし | [字句構造](../01-spec/01-01-lexical.md)、[字句解析器と構文解析器](02-03-frontend.md) |
| `;` を書いた | 文を改行で区切ること | あり | [字句構造](../01-spec/01-01-lexical.md) |
| 複数のスカラー値からなる文字を文字リテラルに書いた | 文字列リテラルを使うこと | あり | [字句構造](../01-spec/01-01-lexical.md) |
| `{` を次の行の先頭に書いた | `{` を前の行の末尾に書くこと | あり | [字句構造](../01-spec/01-01-lexical.md)、[字句解析器と構文解析器](02-03-frontend.md) |
| 比較演算子を連ねた | `a < b and b < c` の形 | あり | [構文](../01-spec/01-02-syntax.md) |
| 値に続けてドットを書いた | `\|>` を使った書き方 | なし | [構文](../01-spec/01-02-syntax.md) |
| `try` の直後に `{` を書いた | 例外がないことと、`Result` を返す書き方 | なし | [エラー処理](../01-spec/01-09-errors.md) |
| 見つからない名前 | 綴りの近い名前。単位を持たない `String.length` などには単位を持つ関数。`Option.unwrap` などには `unwrapOr` と `case`（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)） | 候補が一つのときだけ | [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)、[名前解決とモジュール読込](02-04-resolver.md)、[基本型の意味論](../01-spec/01-04-types-basic.md) |
| `Option` と `Result` の構成子を修飾せずに書いた | 修飾した書き方（`Option.Some(x)` など） | あり | [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md) |
| 取り込んでいない標準ライブラリのモジュールの名前を使った | その import の行 | あり | [名前・スコープ・モジュール](../01-spec/01-03-names-modules.md) |
| `Float` の位置に整数リテラルを書いた | `2.0` のような浮動小数リテラル | あり | [基本型の意味論](../01-spec/01-04-types-basic.md) |
| `String` と他の型を `+` でつないだ | `Integer.toString` などで変換すること、または文字列補間 | なし | [基本型の意味論](../01-spec/01-04-types-basic.md) |
| 型が決まらない、制約を持つ型変数が決まらない | 型注釈を書くこと | なし | [型システム](../01-spec/01-06-type-system.md) |
| `uses` の並びにエフェクトでない名前を書いた | 関数の型を括弧で囲むこと（[ADR 0047](../decisions/0047-parenthesized-types-and-uses-binding.md)） | あり | [構文](../01-spec/01-02-syntax.md)、[名前解決とモジュール読込](02-04-resolver.md) |
| 最小実行版の `uses IO` を書いた | `uses IO.All`（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)） | あり | [エフェクト](../01-spec/01-07-effects.md) |
| `TaskGroup.open()` を `with` の束縛の外に書いた | `with group = TaskGroup.open() do … end with` の形（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)） | なし | [並行処理](../01-spec/01-11-concurrency.md) |
| 引数のない構成子に括弧を付けた（`Tree.Leaf()`） | 括弧を取り除くこと | あり | [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)、[型検査器](02-05-typechecker.md) |
| 範囲のパターンを Rust などの形（`1..=9`）で書いた | `下端..上端` の形 | あり | [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md) |
| 必ず照合しないパターンを `let` の左辺に書いた | `case` で分岐する書き方 | なし | [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md) |
| `case` のパターンの変数に定数と同じ名前を付けた | ガードで比べる書き方（`when n if n = maxRetries:`。[ADR 0123](../decisions/0123-top-level-constants.md)） | あり | [代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md) |
| 書けない属性を書いた | 書ける属性の一覧（[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md)） | なし | [構文](../01-spec/01-02-syntax.md) |

この表にない検査の誤りにも、診断コードごとの型板で修正案を示す。どの診断に置き換えを付けるかは、実装プランの診断の表で定める。

### 診断コード

【決定】診断コードは、種類を表す英大文字 1 文字と 4 桁の番号で表す。番号の上 2 桁は区分を表す。一度公開したコードの意味は変えず、廃止したコードを別の意味で使わない（[ADR 0031](../decisions/0031-numbered-diagnostic-codes.md)）。

【方針】分類と区分は次のとおりとする。`E` の区分と `W` の区分は、上 2 桁が同じなら同じ区分を表す。初回リリース版で加える区分と、既存の区分に加える検査を「初回リリース版」の欄に示す。

| コード | 分類 | 区分 | 初回リリース版で加えるもの |
|---|---|---|---|
| `E01nn` | 検査の誤り | 読み込みと字句 | import で辿ったファイルの読み込みの誤り（[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)） |
| `E02nn` | 検査の誤り | 構文 | 初回リリース版の構文の誤り、`try` の直後の `{`、属性の書き方の誤り、`lazy` の本体とガードの中の `return`・`try`、制約の位置の書けない小文字の名前（利用者のソースの `ordered` を含む。[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）（[字句解析器と構文解析器](02-03-frontend.md)の「文脈の制限」） |
| `E03nn` | 検査の誤り | 名前、import、公開 | 最小実行版の `uses IO`（エフェクトの位置に書いたモジュールの名前。[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）、見つからないモジュール、同じモジュールの二度の取り込み、import の循環、実行を始めるモジュールの取り込み、公開する契約に非公開の型・型クラス・エフェクトを使った（[ADR 0154](../decisions/0154-public-contract-includes-effects-and-supertraits.md)）、`Benitoite` の名前空間の名前の宣言 |
| `E04nn` | 検査の誤り | 型（宣言、リテラルの範囲、`main` の条件を含む） | レコードの構築と更新のフィールドの誤り、型の別名の誤り、定数の宣言と定数式の誤り（定数式の算術の確実な誤り、定数の循環、定数式の `Map.fromList`・`Set.fromList` の重なる鍵。[ADR 0123](../decisions/0123-top-level-constants.md)、[ADR 0136](../decisions/0136-map-and-set-in-constants.md)） |
| `E05nn` | 検査の誤り | エフェクト、ハンドラ | `main` とテストの関数で処理していない利用者のエフェクト、エフェクトの宣言の誤り、`when` に操作でない関数（`State` を型に持つ関数など）を書いた、一つの `handle` の同じ操作の節、`resume` を書けない位置（節の外、節の中のラムダと `lazy`。構文解析器が報告する。[ADR 0155](../decisions/0155-resume-not-in-lazy.md)）、`TaskGroup.open` の位置（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)） |
| `E06nn` | 検査の誤り | パターン | 範囲のパターンの誤り、選ばれない選択肢、選択肢の束縛する名前の違い、必ず照合しない `let` のパターン、定数と同じ名前のパターンの変数 |
| `E07nn` | 検査の誤り | 型クラス（初回リリース版で新設） | 孤立した実装、重なる実装、上位の型クラスの循環、上位の型クラスの制約が解けない実装、解けない制約、メソッドの欠けた実装、型クラスの引数を含まないメソッド |
| `E08nn` | 検査の誤り | 属性（初回リリース版で新設） | 書けない属性、`@test` を付けた関数の型パラメータ・引数・戻り値の型の条件（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)）、`@deprecated` の引数の誤り、利用者のソースの `@builtin` と本体のない関数（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)） |
| `W03nn` | 警告 | 名前 | `@deprecated` を付けた宣言の参照（[ADR 0119](../decisions/0119-attributes-test-and-deprecated.md)） |
| `W04nn` | 警告 | 型と演算 | 除数が 0 の定数式の除算、引数がすべて定数式の演算の溢れ（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）、`Map.fromList`・`Set.fromList` の引数のリストのリテラルで重なる鍵（[ADR 0136](../decisions/0136-map-and-set-in-constants.md)） |
| `W05nn` | 警告 | エフェクト | `uses IO.All` と書いた関数の本体が `IO.All` の一部のエフェクトしか生じない（[ADR 0116](../decisions/0116-builtin-fine-grained-effects.md)） |
| `R01nn` | 実行時エラー | 基本型の演算 | `Decimal` の溢れ |
| `R02nn` | 実行時エラー | 標準出力と標準エラー出力 | なし |
| `R03nn` | 実行の開始前の誤り | コマンドライン引数（正しくない UTF-8） | なし |
| `R04nn` | 実行時エラー | リソース（初回リリース版で新設） | リソースの解放の失敗、解放したリソースの使用 |
| `R05nn` | 実行時エラー | ハンドラ（初回リリース版で新設） | 継続の二度目の再開、引き継いだハンドラの節の誤り |
| `R06nn` | 実行時エラー | 権限（サーバモードで新設。[ADR 0177](../decisions/0177-server-mode-after-first-release.md)） | 権限の拒否 |
| `R07nn` | 実行時エラー | 引数（初回リリース版で新設） | 引数が定義域の外 |
| `R08nn` | 実行時エラー | ネットワーク（初回リリース版で新設） | 応答の二度目の送信 |
| `R09nn` | 資源の不足 | 呼び出しの入れ子が深すぎる（[仮想機械](02-08-vm.md)）、一つの操作で作る値が大きすぎる（[ランタイム](02-09-runtime.md)の「一つの操作で作る値の大きさの上限」、[ADR 0049](../decisions/0049-size-limit-for-built-values.md)） | `Bytes` と、入力を読む操作の大きさの上限 |
| `R10nn` | 実行時エラー | 並行処理（初回リリース版で新設） | タスクの待ち合いの行き詰まり（`R1001`。[ADR 0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)） |
| `L01nn` | 処理系の制限 | コード生成の上限（[バイトコードとコード生成](02-07-bytecode.md)） | なし |

実行時エラーの種類と区分の対応は、[評価意味論](../01-spec/01-08-evaluation.md)の「実行時エラーによる停止」の表の種類ごとに一つのコードを割り当てる形とする。

区分の中の番号は、01 から順に振る。最小実行版で割り当てた番号（`E0101`〜`E0117`、`E0201`〜`E0210`、`E0301`〜`E0317`、`E0401`〜`E0419`、`E0501`・`E0502`、`E0601`・`E0602`、`R0101`・`R0102`、`R0201`・`R0202`、`R0301`、`R0901`・`R0902`、`L0101`・`L0102`）は意味を変えず、初回リリース版の検査は、各区分の続きの番号に割り当てる。最小実行版の診断のうち、初回リリース版で起きなくなるもの（最小実行版だけの書き方に対するもの）は廃止し、番号を使い回さない。個々のコードの割り当ては、処理系の中の診断の表で管理し、実装プランで一覧を定める。

【方針】処理系の中に、診断コード（diagnostic code）ごとに次のものを持つ表（診断の表）を置く。

- コード、重大度、区分
- 文言・ラベル・注記・修正案の型板（英語）
- 置き換えを付けるかどうか
- コードの説明（誤りの意味と、よくある直し方）。MCP の道具 `explain` で引く（[サーバモード](../06-tooling/06-07-server.md)の「MCP の道具」、[ADR 0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md)）

### 警告の扱い

【決定】警告は、`check` でも `run` でも、誤りと同じ形で標準エラー出力に書く。警告だけなら、`check` は終了状態 0 で終え、`run` は実行する。`check`・`run`・`test` のオプション `--deny-warnings` を指定したときは、警告を誤りとして扱い、検査の誤りと同じく終了状態 2 で終える（[ADR 0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md)）。

【方針】警告の扱いは次のとおりとする。

- 警告は、検査の段が誤りと一緒に診断の一覧に入れる。誤りのない段では、警告だけが一覧に入る。誤りがあって次の段に進まないときは、それまでの段の警告も誤りと一緒に書く。
- `run` では、警告をすべて書いてから実行を始める。スクリプトの出力は、警告の後に現れる。
- `--deny-warnings` を指定したときは、警告の重大度を誤りに変えて書き、「`--deny-warnings` によって誤りとして扱った」ことを注記に加える。コードは `W` のまま変えない。
- 警告を出さないようにするオプションと、ソースの中で警告を抑える書き方は設けない。
- 標準ライブラリのソースの中の警告は示さない。

### 文言の言語

【決定】診断と、実行時エラー・資源の不足・解放の失敗・処理系の不具合の報告の文言は、英語で書く。文言は診断の表の型板にまとめ、診断を出す処理と分ける（[ADR 0033](../decisions/0033-english-diagnostic-messages.md)）。

### 文章の形式

【決定】CLI は、既定では診断を Rust 風の文章で標準エラー出力に書く（[ADR 0032](../decisions/0032-rust-style-text-and-json.md)）。

【方針】一つの診断は次の形で書く。

```text
error[E0401]: mismatched types
  --> count.bnt:3:16
   |
 3 |   let n: Integer = "a"
   |                ^^^ expected `Integer`, found `String`
   |
  ::: count.bnt:1:10
   |
 1 | function f(x: Integer): Integer
   |         --- declared here
   |
   = note: ...
   = help: ...
```

- 1 行目は、重大度（`error` か `warning`）、角括弧に入れたコード、文言である。
- `-->` の行は、主な位置のファイルの表示名、行、列である。表示名は、import で読み込んだモジュールと標準ライブラリのファイル（`<benitoite>/X/Y.bnt`。[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）を含め、[ソース管理と位置情報](02-02-source-and-spans.md)で定める。
- ソースの抜粋は、主な位置を含む行を行番号付きで示し、span の下に `^` を並べ、ラベルを添える。span が複数行にわたるときは、最初の行を示し、`^` を行末まで並べる。
- 補助の位置は、主な位置と同じ行にあればその行に、別の行か別のファイルにあれば `:::` の行と抜粋を加えて示し、span の下に `-` を並べてラベルを添える。
- 注記と修正案は、`= note:` と `= help:` の行で示す。置き換えを持つ修正案は、`= help:` の行の後に、置き換えを当てた後の行を行番号付きで示し、変わった部分の下に `~` を並べる。

```text
error[E0315]: `IO` is not an effect
  --> report.bnt:4:28
   |
 4 | function main(): Unit uses IO
   |                            ^^ expected an effect name or an effect variable
   |
   = help: use `IO.All` to allow every effect in `Benitoite.IO`
   |
 4 | function main(): Unit uses IO.All
   |                            ~~~~~~
```

抜粋の中のタブは、`^`・`-`・`~` の位置を揃えるために、空白 4 つに置き換えて示す。本章の例の診断コードの番号と文言は、説明のためのものである。

【方針】標準エラー出力が端末であれば、重大度・コード・印に色を付けてよい。環境変数 `NO_COLOR` が設定されていれば、色を付けない。

【方針】検査の診断は、段の順に書く。同じ段の中では、ファイルを読み込みの段が読んだ順（実行を始めるファイルが最初。[ADR 0156](../decisions/0156-module-loading-and-whole-program-checking.md)）に、同じファイルの中ではソース上の位置の順に書く。型検査は、型の誤りの後も検査を続けて、互いに独立した誤りをすべて診断にする（[ADR 0024](../decisions/0024-continue-after-type-errors.md)）。文章の形式では、一回の検査で書く診断は、誤りと警告を合わせて 50 件までとし、それを超えた分は書かずに件数だけを示す。

【方針】最後に、件数を示す行を書く。件数は、誤りと警告を分けて数える（[ADR 0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md)）。`--deny-warnings` で誤りとして扱った警告は、誤りに数える。

| 場合 | 件数の行 |
|---|---|
| 誤りがある | `error: could not run count.bnt due to 3 previous errors; 2 warnings emitted`（警告がなければ `; …` を書かない） |
| 警告だけがある | `warning: 2 warnings emitted` |
| 誤りも警告もない | 書かない |

`check` では `could not run` を `could not check` に、`test` では `could not test` に変える。

### JSON の形式

【方針】CLI のオプション（[CLI](../06-tooling/06-01-cli.md)）を指定したときは、文章の代わりに、一つの診断を一行の JSON オブジェクトとして標準エラー出力に書く。オブジェクトは次の項目を持つ。

| 項目 | 内容 |
|---|---|
| `kind` | 報告の種類。後述の表の値 |
| `severity` | `"error"` か `"warning"` |
| `code` | 診断コード |
| `message` | 文言 |
| `primary` | 主な位置。後述の位置の形 |
| `secondary` | 補助の位置の配列 |
| `notes` | 注記の文字列の配列 |
| `helps` | 修正案の配列。各要素は、文 `message` と、置き換えの配列 `edits` を持つ。置き換えは、`file`、`start` と `end`（位置の形の `line`・`column`・`offset`）、入れる文字列 `replacement` を持つ。置き換えのない修正案の `edits` は空の配列 |

位置は、`file`（表示名）、`start` と `end`（それぞれ `line`・`column`・`offset`）、`label` を持つ。`line` と `column` は文章の形式と同じく 1 から数え（`column` はコードポイントの数。[ADR 0025](../decisions/0025-columns-in-code-points.md)）、`offset` はファイルの先頭からのバイトの位置である。位置を持たない報告では、`primary` を `null` にする。

【方針】`kind` の値は次のとおりとする。`severity` は、警告の診断だけを `"warning"` とし、ほかはすべて `"error"` とする。`--deny-warnings` で誤りとして扱った警告は `"error"` とする。

| `kind` | 報告 | `code` |
|---|---|---|
| `"check"` | 検査の誤りと警告の診断 | `E`・`W` のコード |
| `"limit"` | 処理系の制限 | `L` のコード |
| `"runtime"` | 実行時エラー | `R01nn`・`R02nn`・`R04nn`〜`R08nn` |
| `"resource"` | 資源の不足 | `R09nn` |
| `"release"` | `Process.exit` と中断の要求で止める途中の解放の失敗（後述） | `R04nn` |
| `"args"` | 実行の開始前の誤り（コマンドライン引数） | `R03nn` |
| `"internal"` | 処理系の不具合 | `null` |

JSON の形式では、診断の件数による打ち切りを行わず、件数を示す行も書かない。すべての報告を、一件ずつ一行の JSON オブジェクトとして書く。

次のものは、JSON の形式を指定しても JSON にしない。

- `main` が返した `Result.Error` の文字列。スクリプトの出力であり、処理系の報告ではないので、文章の形式のときと同じく、文字列と改行をそのまま書く（[ランタイム](02-09-runtime.md)の「プログラムの実行の流れ」）。
- 使い方の誤り（[CLI](../06-tooling/06-01-cli.md)）。オプションの指定そのものが誤っている場合があるので、常に文章で書く。
- ヒープの確保に失敗したときに Rust の標準ライブラリが書くメッセージ（[ランタイム](02-09-runtime.md)の「リソースの追跡」）。処理系の形式の外で書かれる。

文章の形式と JSON の形式は、同じ内部の表現から作り、内容を揃える。

### 実行時エラーと資源の不足の報告

【方針】実行時エラーと資源の不足は、検査の診断と同じ文章の形式で標準エラー出力に書く。重大度の位置には `runtime error` と書き、主な位置は実行時エラーを起こした式（資源の不足では、上限を超えた呼び出し、または大きすぎる値を作ろうとした操作）の位置とする（[評価意味論](../01-spec/01-08-evaluation.md)）。その式が標準ライブラリのソースの中にあるときの扱いは、[仮想機械](02-08-vm.md)の「実行時エラーの情報の記録」に従う。

【決定】報告には、残っている呼び出しの枠を内側から並べた履歴を含める。各段は関数の名前（ラムダは `<lambda>` とそれを書いた位置）と、その関数を呼び出した位置を示す。20 段を超えるときは内側の 10 段と外側の 10 段を示し、省いた段の数を示す。末尾呼び出しで通った関数が現れないことを注記する（[ADR 0034](../decisions/0034-call-trace-in-runtime-errors.md)）。

【方針】履歴の段、各段の名前と呼び出した位置、主な位置は、[仮想機械](02-08-vm.md)の「実行時エラーの情報の記録」に従って作る。各段は `名前` と `at 位置` を並べた一行で示す。名前は次のとおりとする。

- 利用者のトップレベルの関数: 関数の名前。実行を始めるモジュールでないモジュールの関数は、モジュールの名前で修飾する（`Report.format`）
- 利用者の実装のメソッド: 型クラスの名前、実装の型、メソッドの名前から作る名前（`Show[Person].show`）
- 利用者のラムダ: `<lambda ファイル:行:列>`（ラムダを書いた位置）
- 利用者の `handle` の本体と節、`lazy` の本体: `<handle ファイル:行:列>`、`<when 操作の名前 ファイル:行:列>`（`<when Log.write report.bnt:8:5>` など）、`<lazy ファイル:行:列>`（書いた位置）
- 標準ライブラリの公開の関数と実装のメソッド、値として使った組み込みの関数と操作: 修飾した名前（`List.map`、`Integer.floorDivide`、`Console.writeLine` など）。メソッドは利用者の実装のメソッドと同じ形
- 標準ライブラリの補助の関数（標準ライブラリのソースの中のラムダ・`handle` の本体と節・`lazy` の本体を含む）: 示さない

これらの名前は、原型の名前と由来の種類（[バイトコードとコード生成](02-07-bytecode.md)の「原型の名前と由来の種類」）から作る。

呼び出した位置を持たない段（タスクの最初の段、標準ライブラリのソースの中から呼ばれた段）は、名前だけを示す。

```text
runtime error[R0101]: division by zero
  --> count.bnt:10:11
   |
10 |   let q = a div b
   |           ^^^^^^^
   |
   = note: call trace (innermost first):
             ratio                    at count.bnt:22:33
             <lambda count.bnt:22:25>
             List.map                 at count.bnt:22:12
             main
   = note: functions left by tail calls are not shown
```

この例では、22 行目 `let rs = List.map(xs, lambda(x) ratio(x, n) + 1 end lambda)` の `List.map` が、標準ライブラリのソースの中からラムダを呼び、ラムダが `ratio` を呼んでいる。ラムダの中の `ratio` の呼び出しは、結果に 1 を加える前なので末尾呼び出しではなく、ラムダの段が履歴に残る。`lambda(x) ratio(x, n) end lambda` と書いた場合は末尾呼び出しになり、ラムダの段は現れない。

【方針】実行時エラーが `main` の呼び出しでないタスク（[並行処理](../01-spec/01-11-concurrency.md)）で起きたときは、呼び出しの履歴は、実行時エラーを起こしたタスクのものだけを示す。その後に、そのタスクを起動した位置を、内側のタスクから `main` のタスクまで並べたタスクの起動の履歴を示す。各段は、タスクを起動した関数（`TaskGroup.spawn`・`Task.all` など）の名前と、その呼び出しの位置である。起動した呼び出しが標準ライブラリのソースの中にあるとき（`Http.serve` の中の `TaskGroup.spawn` など）は、呼び出しの履歴の主な位置と同じく、利用者のソースにある最も内側の呼び出しの名前と位置を示す。ほかのタスクの呼び出しの履歴は示さない。材料は[仮想機械](02-08-vm.md)がタスクごとに記録する（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。

```text
runtime error[R0101]: division by zero
  --> server.bnt:10:11
   |
10 |   let q = a div b
   |           ^^^^^^^
   |
   = note: call trace (innermost first):
             ratio                    at server.bnt:18:9
             route
   = note: in a task started by (innermost first):
             Http.serve               at server.bnt:25:10
             main
   = note: functions left by tail calls are not shown
```

JSON の形式を指定したときは、診断と同じ項目に、呼び出しの履歴の配列 `trace` と、省いた段の数 `traceOmitted` と、タスクの起動の履歴の配列 `taskOrigins` を加えた一行を書く。`trace` と `taskOrigins` の各要素は、`function`（上の名前）と `location`（位置の形。持たない段では `null`）を持つ。`main` のタスクで起きたときは、`taskOrigins` を空の配列にする。

【方針】主な位置を持たない実行時エラーは、`-->` の行と抜粋を書かない。標準出力と標準エラー出力への書き込みの失敗（[ランタイム](02-09-runtime.md)の「出力のバッファ」、[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）は、主な位置も呼び出しの履歴も持たないので、一行目と、失敗した出力と理由を示す注記だけを書く。

```text
runtime error[R0201]: failed to write to standard output
   = note: broken pipe
```

【方針】一つの操作で作る値が大きすぎるときの資源の不足の報告は、文言に、値を作ろうとした関数（または `+`）、計算した結果の大きさ、上限を含める。入力を読む操作では、結果の大きさの代わりに、上限を超えたことを示す。

【方針】権限の拒否の報告は、実行時の権限制御とあわせて、初回リリース版の後にサーバモードで加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版の処理系は権限の拒否を報告しない。権限の拒否の報告は、文言に許可の単位（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）とスクリプトが渡した対象を含め、注記に、操作の名前と、解決した絶対パス（`run` では見つけた実行ファイルの絶対パス）を示す（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)、[ランタイム](02-09-runtime.md)の「実行時の権限制御の判定」）。主な位置と呼び出しの履歴は、ほかの実行時エラーと同じく作る。スクリプトは権限を宣言しない（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）ので、宣言を直す修正案はない。許可を与える方法を示す修正案は、許可の与え方（[OPEN-052](../open-issues.md#open-052)）を決めるときにあわせて定める。

```text
runtime error[R0601]: permission `write` is not allowed for `out/report.txt`
  --> report.bnt:12:3
   |
12 |   try File.writeText("out/report.txt", text)
   |       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = note: operation: File.writeText
   = note: resolved path: /home/user/work/out/report.txt
   = note: call trace (innermost first):
             main
```

【方針】タスクの待ち合いの行き詰まり（`R1001`。[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」、[ADR 0238](../decisions/0238-task-wait-deadlock-as-runtime-error.md)）は、止まった一つの式がないので、主な位置と呼び出しの履歴を持たず、`-->` の行と抜粋を書かない。代わりに、待つタスクごとに一行を注記に並べる。各行は、タスク（`main` のタスクは `main`、ほかのタスクは起動の履歴の最も内側の段の名前と位置）、待つ種類、待つ位置を示す。待つ位置は、[仮想機械](02-08-vm.md)の「実行時エラーの情報の記録」の材料から、主な位置と同じ規則で作る。タスクの並びは、起動した順とする。

```text
runtime error[R1001]: no task can proceed because tasks are waiting for each other
   = note: waiting tasks:
             main                                 waits for TaskGroup release   at pair.bnt:4:3
             TaskGroup.spawn at pair.bnt:6:13      waits for Task.await          at pair.bnt:7:5
             TaskGroup.spawn at pair.bnt:10:13     waits for Task.await          at pair.bnt:11:5
```

JSON の形式を指定したときは、`trace` と `taskOrigins` を空の配列にし、待つタスクの配列 `waitingTasks` を加える。各要素は、`task`（上のタスクの名前と位置）、`waitsFor`（待つ種類）、`location`（待つ位置。持たないときは `null`）を持つ。

コマンドライン引数が正しい UTF-8 でないときの報告（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）は、ソースの位置を持たないので、抜粋を書かず、何番目の引数かを文言に含める。


### 解放の失敗の報告

【方針】`with` を抜けるとき、タスクの取り消し、ハンドラが本体の続きを捨てるときの解放の失敗は、実行時エラー（リソースの解放の失敗）として報告する（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」）。主な位置は解放した `with` の束縛、または `resume` を呼ばずに終えた節と取り消したタスクを起動した呼び出しとし、失敗した解放ごとに、リソースの型、開いた位置、失敗の理由を注記で示す。複数の失敗があれば、すべてを注記に並べる。

【方針】実行時エラーか資源の不足で止める途中の解放の失敗は、その報告に注記として加え、先の実行時エラーを置き換えない（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。

```text
   = note: while stopping, failed to release `File.Writer` opened at count.bnt:5:8: no space left on device
```

【方針】`Process.exit` と中断の要求で止める途中の解放の失敗は、失敗ごとに次の形で書き、終了状態は変えない（[仮想機械](02-08-vm.md)の「止める手順」、[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。JSON の形式では `kind` を `"release"` とする。

```text
error[R0401]: failed to release `File.Writer` opened at count.bnt:5:8
   = note: no space left on device
   = note: the program was exiting by `Process.exit(2)`; the exit status is not changed
```

中断の要求のときは、最後の注記を `the program was interrupted; the exit status is not changed` とする。解放の失敗を実行時エラーにしないリソースの型（`Http.Exchange`。[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）の失敗は、どの時期にも報告しない。

### 処理系の不具合と処理系の制限の報告

【方針】処理系の不具合（脱糖・コード生成で処理を続けられない状態、表に結果がない、Rust の panic。[パイプライン](02-01-pipeline.md)、[ランタイム](02-09-runtime.md)）は、診断コードを持たない `internal error` として標準エラー出力に書き、終了状態 3 で終わる（[ADR 0037](../decisions/0037-exit-status-values.md)）。報告には、処理系の版、不具合が起きた段、Rust の panic であればその内容と起きたスレッド（VM のスレッドか作業用のスレッドか）、取得できれば処理系のバックトレースを含め、処理系の不具合として報告するよう求める文を添える。JSON の形式では、版・段・スレッド・panic の内容・報告を求める文を `notes` に、バックトレースを文字列の項目 `backtrace` に入れる。

処理系の制限（`L` のコード）は、プログラムの誤りではないが実行できないことを表す。検査の誤りと同じ文章の形式で書き、主な位置は、制限を超えた関数の宣言とする。

### 実行の外への受け渡し

【方針】MCP サーバ（初回リリース版の後にサーバモードとあわせて加える。[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）と LSP サーバ（初回リリース版の後）は、診断の内部の表現を受け取り、それぞれの通信の形に変える（[サーバモード](../06-tooling/06-07-server.md)の「MCP の道具」、[LSP サーバ](../06-tooling/06-02-lsp.md)、[ADR 0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md)）。

- MCP サーバは、JSON の形式と同じ項目を返す。道具 `explain` は、診断コードの説明を診断の表から引いて返す。実行の結果には、捕らえた標準出力と標準エラー出力と、実行時の報告を分けて含める（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)、[スクリプト実行と埋め込み](02-11-embedding.md)）。
- LSP サーバは、重大度・コード・文言・主な位置・補助の位置を LSP の診断に、置き換えを持つ修正案をコードアクションに変える。LSP の位置の数え方への変換は、[LSP サーバ](../06-tooling/06-02-lsp.md)で定める。

【決定】テストの実行器は、検査の診断と処理系の不具合の報告を、`check` と同じ形で標準エラー出力に書く。テストごとの結果と集計は標準出力に書き、`--diagnostics=json` を指定したときは、結果も JSON Lines の形で書く（[ADR 0208](../decisions/0208-test-report-destination.md)）。

【方針】失敗したテストの実行時エラーの報告は、本章の実行時エラーの報告と同じ内部の表現から作る。テストごとの結果の文章の形と JSON Lines の形は、[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)で定める。形の細部は【未決】である（[OPEN-058](../open-issues.md#open-058)）。

## 未決事項

- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（権限の拒否の報告に添える、許可の与え方の修正案）
- [OPEN-058](../open-issues.md#open-058): テストの結果の報告の形の細部
