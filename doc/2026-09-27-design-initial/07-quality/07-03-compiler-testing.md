# 処理系のテスト戦略

- 状態: 草稿
- 関連ADR: [0003](../decisions/0003-license.md), [0006](../decisions/0006-basic-types-semantics.md), [0018](../decisions/0018-reference-interpreter.md), [0024](../decisions/0024-continue-after-type-errors.md), [0029](../decisions/0029-two-io-execution-modes.md), [0032](../decisions/0032-rust-style-text-and-json.md), [0037](../decisions/0037-exit-status-values.md), [0039](../decisions/0039-golden-test-files.md), [0040](../decisions/0040-single-repository.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md), [0080](../decisions/0080-test-design-principles-and-test-audit.md)
- 未決事項: [OPEN-011](../open-issues.md#open-011), [OPEN-019](../open-issues.md#open-019), [OPEN-035](../open-issues.md#open-035), [OPEN-038](../open-issues.md#open-038)
- 移行元: [設計メモ](../sources/fp-language-design.md) 14

## 目的と範囲

テストの設計の原則、ゴールデンテスト、型検査器・VM のテスト、interop の差分テスト、fuzzing、言語仕様の例の検査、実装の規約と静的な検査。ロードマップの完了条件として挙げた受け入れ例と、言語仕様の各項目とを対応づける方針も扱う。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲だけを定める。設計メモの interop の差分テスト（言語経由の呼び出しと Go の直接の呼び出しの比較。[設計メモ](../sources/fp-language-design.md) 14）は、go.* の層を廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）ので行わない。外部のライブラリを呼ぶ層を設ける場合のテストは、v1 のライブラリの提供方法（[OPEN-035](../open-issues.md#open-035)）とあわせて定める。ランダムに生成した型の付くプログラムで反例を探すことは、形式検証の段階 1（最小実行版の後）で行う（[ロードマップ](../00-overview/00-03-roadmap.md)の「形式検証の時期」）。

## 前提

処理系のテストは、Rust の標準のテストの仕組みで書き、`cargo test` で実行する。テストは、処理系を別のプロセスとして起動せず、処理系の Rust の API を直接呼んで検査と実行を行う。ただし、プロセス全体に関わる振る舞い（panic hook の設定と、処理系の不具合の報告が標準エラー出力に出る順序。[ランタイム](../02-impl/02-09-runtime.md)の「panic 境界」）は、API からは確かめられないので、CLI を別のプロセスとして起動するテストで確かめる。そのテストで panic を起こす手段は、実装プランで定める。実行には、テスト用のハンドラ表を使う（[ランタイム](../02-impl/02-09-runtime.md)）。

## 仕様

### テストの設計の原則

【決定】処理系のテストは、Vladimir Khorikov『Unit Testing Principles, Practices, and Patterns』（邦訳『単体テストの考え方/使い方』）の考え方に沿った次の原則で書く。新しいテストは、プロジェクトのスキル `test-audit`（`.claude/skills/test-audit/`）の作成時の関門を通してから加える（[ADR 0080](../decisions/0080-test-design-principles-and-test-audit.md)）。同書の要約は、原典の該当箇所で確かめていない（[OPEN-038](../open-issues.md#open-038)）。

【方針】原則は次のとおりである。

- **テストの価値**: テストは維持の費用がかかる。退行を捕まえる力、振る舞いを変えない作り直しに耐えること、速いフィードバック、読みやすさの四つで価値を判断する。作り直しに耐えることは、ほかの性質と引き換えに手放さない。
- **確かめるもの**: 観察可能な振る舞い（observable behavior）を確かめ、実装の詳細（implementation detail）を確かめない。処理系では、観察可能な振る舞いは、各段の公開の関数と型が返す結果、診断、スクリプトの出力と終了状態である。段の中の非公開の関数や、中間のデータの並びの順序などは確かめない。
- **テストの単位**: テストの単位は、クラスや関数ではなく、振る舞いの単位である。処理系の中の段や型を、テストダブル（test double）で置き換えない。
- **テストダブルを使う範囲**: テストダブルは、処理系の外にあり、処理系が管理しない依存（ファイル・プロセス・標準出力・環境変数など）にだけ使う。処理系では、テスト用のハンドラ表がこれに当たる（[ランタイム](../02-impl/02-09-runtime.md)）。
- **確かめ方の優先順位**: 出力を確かめるテストを最も優先し、次に状態を確かめるテスト、最後に呼び出しのやり取りを確かめるテストとする。処理系の段の多くは外部に作用しない関数なので、出力を確かめるテストで書ける。
- **網羅率**: 網羅率を目標にしない。網羅率は、テストの足りない箇所を探す手がかりとしてだけ使う。
- **テストの形**: 準備・実行・確認（Arrange・Act・Assert）の三つの部分に分けて書く。似た場合は、表の形のテスト（パラメータを並べたテスト）の行として足す。
- **持ち主の境界**: 一つの契約は、最も適した境界（処理系の段の公開の関数と型、CLI のゴールデンテスト）の一つのテストで守る。別の層にテストを足すのは、その層に固有の危険があるときに限る。
- **退行テスト**: 不具合を直したときに足すテストは、直す前のコードで失敗し、直した後に通ることを確かめてから加える。

【方針】テストが増えたときは、`test-audit` の監査の手順で、価値の低いテストを定期的に整理する。整理の時期は、マイルストーンの完了のときと、実装プランの区切りのときとする。

### テストの種類

【方針】最小実行版の処理系のテストは、次の種類からなる。

| 種類 | 内容 |
|---|---|
| 段ごとの単体テスト | 字句解析（改行の判定を含む）、構文解析（AST の形、誤りからの回復）、名前解決、型検査（制約と診断）、脱糖、判定の木への変換、コード生成、VM の命令、ランタイムを、段ごとに Rust のテストで確かめる |
| ゴールデンテスト（golden test） | スクリプトを `check` または `run` し、結果を期待値のファイルと比べる |
| 差分テスト | 同じスクリプトを、参照インタプリタと VM で実行して結果を比べる |
| IO の方式のテスト | 同じスクリプトを、IO の二つの方式で実行して結果を比べる |
| コア IR の検査 | 脱糖の結果に、コア計算の型付け規則で型が付くことを確かめる |
| fuzzing（ファジング） | 任意の入力で、処理系の検査の段が不具合を起こさないことを確かめる |

### ゴールデンテスト

【決定】ゴールデンテストは、スクリプトのファイルと、期待する結果のファイルを並べて書く。実際の結果で期待値のファイルを書き直す指定を用意する（[ADR 0039](../decisions/0039-golden-test-files.md)）。

【方針】テストは、処理系のソースの `testdata/` の下に、区分ごとのディレクトリ（`lexical`、`syntax`、`names`、`types`、`effects`、`patterns`、`eval`、`io`、`acceptance` など）を作って置く。一つのテストは、同じ名前で拡張子の違う次のファイルからなる。

| ファイル | 内容 | 必須 |
|---|---|---|
| `<名前>.bnt` | スクリプト（拡張子は仮のもの。[OPEN-011](../open-issues.md#open-011)） | 必須 |
| `<名前>.mode` | `check` か `run` か | 必須 |
| `<名前>.exit` | 期待する終了状態（[ADR 0037](../decisions/0037-exit-status-values.md)） | 必須 |
| `<名前>.stdout` | 期待する標準出力 | `run` のとき |
| `<名前>.stderr` | 期待する、スクリプトが書いた標準エラー出力と `main` の `Err` の文字列 | `run` で書くとき |
| `<名前>.diag.json` | 期待する診断、実行時エラー、資源の不足の報告。JSON の形式（[ADR 0032](../decisions/0032-rust-style-text-and-json.md)）で、一行に一つ | 報告があるとき |
| `<名前>.args` | スクリプトに渡すコマンドライン引数。一行に一つ | 任意 |
| `<名前>.files/` | `File.readText` で読めるファイル。テスト用のハンドラ表に与える | 任意 |
| `<名前>.text.stderr` | 期待する、文章の形式の診断 | 任意。文章の体裁を確かめるテストだけに置く |

診断は JSON の形式で比べ、文言・コード・位置・補助の位置・注記・修正案がすべて一致することを求める。文章の形式の体裁は、少数のテストの `.text.stderr` で確かめる。

スクリプトの先頭のコメントに、そのテストが確かめる仕様の項目を書く（`// spec: 01-05 網羅性の検査` など）。一つのテストが複数の項目を確かめてよい。

### 差分テスト

【決定】同じプログラムを参照インタプリタと VM で実行し、結果を突き合わせる差分テストを行う（[ADR 0018](../decisions/0018-reference-interpreter.md)）。

【方針】差分テストの対象は、`run` のゴールデンテストのすべてと、[性能](07-02-performance.md)のベンチマーク（入力を小さくしたもの）とする。

【方針】比べるのは、IO の事象の列（書き込みの内容と順序、読んだファイル）、終わり方（値で終わったか、どの種類の実行時エラーで止まったか）、実行時エラーの位置である。資源の不足で止まるスクリプトは、比べる対象から外す（[ADR 0018](../decisions/0018-reference-interpreter.md)）。結果が食い違ったときは、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の規則に照らして、どちらが誤っているかを調べる。

### IO の方式のテスト

【方針】`run` のゴールデンテストのすべてを、IO の二つの方式（[ADR 0029](../decisions/0029-two-io-execution-modes.md)）で実行し、どちらの方式でも期待値と一致することを確かめる。

### コア IR の検査

【方針】ゴールデンテストと差分テストで脱糖を通るすべてのスクリプトについて、脱糖の結果をコア IR の検査器（[中間表現と脱糖](../02-impl/02-06-ir-and-lowering.md)）にかけ、型が付くことを確かめる。型が付かなければ、処理系の不具合としてテストを失敗させる。

### 派生した診断が出ないことのテスト

【方針】型検査は、関数の本体の中でも誤りの後に検査を続ける（[ADR 0024](../decisions/0024-continue-after-type-errors.md)）。これを確かめるために、次のゴールデンテストを置く。

- 一つの関数に、互いに独立した型の誤りが複数あるスクリプト。すべての誤りが報告されることを確かめる。
- 一つの誤りが、後の式の型に波及しうるスクリプト（誤った型の変数を、後で何度も使うなど）。最初の誤りだけが報告されることを確かめる。

期待値のファイルは診断の一覧すべてを持つので、余分な診断が出ればテストは失敗する。

### fuzzing

【方針】Rust のファジングの道具（実装プランで選ぶ）で、字句解析・構文解析・名前解決・型検査に任意のバイト列と、既存のテストのスクリプトを変形したものを与える。確かめる性質は次のとおりである。

- 処理系の不具合（Rust の panic、処理系の不具合の報告）が起きない。
- すべての診断の span が、ソースの範囲の中にある。
- 誤りがないと判定したスクリプトは、脱糖とコード生成を不具合なしに通る。

fuzzing は通常のテストの実行では短時間だけ行い、長時間の実行は別に行う。

道具の候補の cargo-fuzz は、libFuzzer を使い、nightly の Rust のコンパイラを必要とする（[Rust Fuzz Book](https://rust-fuzz.github.io/book/cargo-fuzz/setup.html)）。ほかの検査を stable の Rust で行う場合は、fuzzing だけ nightly を使うかを、実装プランで決める。

### 実装の規約と静的な検査

処理系は LLM が実装する（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。実装 LLM は、実装プランに書いた規約を読んでも守りきれないことがある。そこで、規約はできるだけ、型の定義、コンパイラと lint、テストで守らせ、文章で頼む規約は、それらで決めにくいものに限る。

【方針】実装プランは、処理系設計（`02-impl/`）が定めるデータ構造を、Rust の型の定義と、主要な関数のシグネチャとして示す。型には、構文木・値・命令・誤りの種類の列挙型と、意味の違う整数（ファイル ID、位置、レジスタの番号など）を取り違えないための専用の型を含める。実装 LLM は、示した型とシグネチャを変えずに中身を書く。型やシグネチャを変える必要が生じたときは、実装を進めずに報告し、実装プランを改めてから続ける。

【方針】規約のうち道具で確かめられるものは道具で確かめ、確かめた結果を各作業の完了条件にする。

【方針】実装プランの各作業の完了条件に、次の検査がすべて通ることを含める。

| 検査 | 道具 | 確かめること |
|---|---|---|
| 書式 | `cargo fmt --check` | ソースが rustfmt の書式に従っている。書き換えずに確かめる（[rustfmt](https://github.com/rust-lang/rustfmt)） |
| lint | Clippy。警告を誤りとして扱う | 下の表の lint と、Clippy の既定の lint に違反しない |
| テスト | `cargo test` | 本章のテストが通る。テストを加える・変えた作業では、`test-audit` の作成時の関門を通している（前述の「テストの設計の原則」） |
| 言語仕様の例 | `src/tools/grammar-check/`（前述の「言語仕様の例の検査」） | 構文の章や構文解析器を変えた作業で、例が文法で読める |
| 依存のライセンス | cargo-deny の licenses の検査 | 依存するクレートのライセンスが、許可したライセンスの一覧に入っている（[ADR 0003](../decisions/0003-license.md)、[cargo-deny](https://embarkstudios.github.io/cargo-deny/checks/licenses/index.html)） |

警告を誤りとして扱う指定の方法（`cargo clippy -- -D warnings`、または Cargo 1.97 から Clippy が勧める `CARGO_BUILD_WARNINGS=deny`。[Clippy の README](https://github.com/rust-lang/rust-clippy/blob/master/README.md)）は、実装プランで使う Rust の版に合わせて選ぶ。

【方針】lint の水準は、コマンドの引数ではなく `Cargo.toml` の `[lints]` の表に書く（[The Cargo Book: lints](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section)）。実装 LLM がコマンドの引数を変えて検査を緩められないようにするためである。次の lint を誤りの水準にする。Clippy の lint の意味は [Clippy の lint の一覧](https://rust-lang.github.io/rust-clippy/stable/index.html)による。

| lint | 検出するもの | 誤りにする理由 |
|---|---|---|
| `unsafe_code`（rustc。`forbid` にする） | `unsafe` のブロックなど | `unsafe` を使わない（[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。`forbid` は、ソースの中の指定で緩められない（[rustc の lint の水準](https://doc.rust-lang.org/rustc/lints/levels.html)） |
| `wildcard_enum_match_arm` | 列挙型の `match` での `_` の分岐 | 構文木・値・命令の種類を加えたときに、処理の漏れを型の検査で見つけるため（[実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md)） |
| `unwrap_used`・`expect_used` | `Option`・`Result` の `unwrap`・`expect` | 失敗を panic にせず、`Result` で扱うため |
| `panic`・`todo`・`unimplemented` | `panic!`・`todo!`・`unimplemented!` | panic は処理系の不具合に限る（[ランタイム](../02-impl/02-09-runtime.md)の「panic 境界」）。作りかけの箇所を残さない |
| `dbg_macro` | `dbg!` | デバッグの出力を残さない |
| `indexing_slicing` | panic しうる添字と範囲の指定 | 添字の誤りを panic にせず、`get` などで扱うため |
| `arithmetic_side_effects` | 溢れうる算術の演算 | 溢れを見落とさないため。言語の `Int` の演算は、溢れを検査して実行時エラーにする（[ADR 0006](../decisions/0006-basic-types-semantics.md)） |
| `let_underscore_must_use` | `#[must_use]` の値を `let _ =` で捨てること | 失敗しうる呼び出しの結果を、黙って捨てないため（下の `unused_must_use` の抜け道を塞ぐ） |
| `clone_on_ref_ptr` | 参照カウントのポインタへの `.clone()` | 参照カウントの複製を `Rc::clone(&x)` の形で明示し、値の複製と見分けるため（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)） |

`Result` は `#[must_use]` を付けた型であり（[core::result のソース](https://github.com/rust-lang/rust/blob/master/library/core/src/result.rs)）、値を使わずに捨てると rustc の lint `unused_must_use` が警告する（[rustc の lint の一覧](https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#unused-must-use)）。警告を誤りとして扱うので、`Result` を捨てたコードはビルドが通らない。

これらの lint を個別に許す指定（`#[allow(...)]`）は、実装プランがその作業で認めた箇所に限り、許す理由をコメントで書く。テストのコードでは、`panic`・`unwrap_used`・`expect_used` などを許してよい。

【方針】リリースのビルドでも、整数の溢れの検査（Cargo のプロファイルの `overflow-checks`）を有効にする。既定では、dev のビルドでは有効、release のビルドでは無効である（[The Cargo Book: profiles](https://doc.rust-lang.org/cargo/reference/profiles.html#overflow-checks)）。有効にすると溢れで panic するので、処理系の内部の溢れは処理系の不具合として報告される。言語の `Int` の溢れは、この検査に頼らず、演算の関数が検査して実行時エラーにする。

【方針】道具では確かめにくい規約は、実装プランに書き、実装を確かめるときに読む。

- 言語の値は、ランタイムの確保の処理を通して作る（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。
- 利用者のプログラムの大きさや深さに比例して、処理系の再帰を深くしない。構文解析器の入れ子の深さの上限（[字句解析器と構文解析器](../02-impl/02-03-frontend.md)の「入れ子の深さ」）の内側で再帰するか、明示の積み重ねを使う（[仮想機械](../02-impl/02-08-vm.md)）。
- 依存するクレートは、実装プランに書いたものに限る。外部のコードを写さない。使う場合は出典とライセンスを記録する（[ADR 0003](../decisions/0003-license.md)）。

【方針】実装を確かめるときは、道具で確かめにくい点を、決まった観点の一覧で読む。一覧には、`#[allow]` とその理由、`as` による数値の変換、誤りを文字列で表している箇所、実装プランの型から外れた箇所を含める。誰が確かめるかは [OPEN-019](../open-issues.md#open-019) で決める。

【方針】命名、コメント、モジュールの分け方など、型と道具とテストで決めにくい書き方の規約は、処理系のソースコードを置くときに、リポジトリの AGENTS.md に実装の規約の節を設けて書く。会話ごとのプロンプトに頼らず、どの LLM とハーネスも同じ規約を読むようにするためである。

### 受け入れ例と仕様の項目の対応

【方針】ロードマップの最小実行版の完了条件（[ロードマップ](../00-overview/00-03-roadmap.md)の「完了条件」）の各行に、`testdata/acceptance/` のゴールデンテストを一つ以上対応させる。対応は、完了条件の行ごとに、テストの名前を並べた一覧として、テストのディレクトリに置く。

【方針】仕様の各章（`01-spec/`）の節のうち、最小実行版の範囲の節ごとに、それを確かめるテストがあるかを、テストの先頭のコメント（前述の `// spec:`）から集計できるようにする。確かめるテストのない節は、一覧として出力する。

### 言語仕様の例の検査

【方針】言語仕様（`01-spec/`）に載せたコードの例が、[構文](../01-spec/01-02-syntax.md)の「v1 の文法の全体」で読めるかを、道具で確かめる。構文の章や例を変えたときに、例が文法と食い違ったまま残ることを防ぐためである。

- 検査には、Python で書いた道具（`src/tools/grammar-check/`）を使う。この道具は、字句構造の規則を手で実装した字句解析器と、01-02 の EBNF の文字列をそのまま読み込む照合器からなる。
- 最小実行版の構文解析器は v1 の構文を読めない（[構文](../01-spec/01-02-syntax.md)の「最小実行版に含めない構文」）ので、例を最小実行版の範囲と v1 の範囲に分けて検査する。最小実行版の範囲の例は、見出しに「（v1）」を付けていない節の例のうち、v1 の構文を含まないものである。v1 の構文を含むのに「（v1）」の節にない例は、最小実行版の範囲の検査（次項）の側に、v1 の範囲の例として登録する。
- 最小実行版を実装するときに、最小実行版の範囲の例を、処理系の字句解析器と構文解析器で読む検査を Rust で加える。この検査は、処理系の構文解析器が最小実行版の文法と一致しているかも確かめる。v1 の範囲の例を含むすべての例は、引き続き Python の道具で v1 の文法の全体に照らして検査する。
- v1 の構文解析器を実装するときに、すべての例を処理系で読む形に移し、Python の道具を削除する。
- 文法で読めなくて正しい例（字句の一覧、誤りの例、本体を省略した宣言など）は、道具の側に一覧として登録する。

道具の置き場所は仮のものであり、リポジトリの中のディレクトリの配置（[ADR 0040](../decisions/0040-single-repository.md)）を最初の実装プランで決めるときに見直す。

## 未決事項

- [OPEN-011](../open-issues.md#open-011): 言語の正式名称（テストのファイル名の拡張子 `.bnt` は仮のもの）
- [OPEN-019](../open-issues.md#open-019): 実装プランと処理系のソースコードの置き場所、実装の確認の分担
- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
- [OPEN-038](../open-issues.md#open-038): テストの設計の原則と、Khorikov の書籍の対応の確認
