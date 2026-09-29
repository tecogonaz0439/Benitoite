# 処理系のテスト戦略

- 状態: 確定
- 関連ADR: [0003](../decisions/0003-license.md), [0006](../decisions/0006-basic-types-semantics.md), [0018](../decisions/0018-reference-interpreter.md), [0024](../decisions/0024-continue-after-type-errors.md), [0029](../decisions/0029-two-io-execution-modes.md), [0032](../decisions/0032-rust-style-text-and-json.md), [0037](../decisions/0037-exit-status-values.md), [0039](../decisions/0039-golden-test-files.md), [0040](../decisions/0040-single-repository.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md), [0080](../decisions/0080-test-design-principles-and-test-audit.md), [0085](../decisions/0085-review-assignment-for-minimal.md), [0088](../decisions/0088-keep-both-io-execution-modes.md), [0137](../decisions/0137-first-release-library-scope.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0084](../decisions/0084-implementer-assignment-for-minimal.md), [0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md), [0212](../decisions/0212-test-owner-boundaries-in-testing-chapter.md), [0213](../decisions/0213-formal-verification-stage-1-in-first-release.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md), [0206](../decisions/0206-test-command-line-and-exit-status.md), [0207](../decisions/0207-fmt-command-line.md), [0208](../decisions/0208-test-report-destination.md), [0222](../decisions/0222-http-tests-over-loopback.md), [0223](../decisions/0223-interrupt-tests-in-separate-process.md), [0224](../decisions/0224-golden-test-format-for-first-release.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md), [0245](../decisions/0245-perl-virtues-source-and-fact-check-timing.md)
- 未決事項: [OPEN-038](../open-issues.md#open-038), [OPEN-039](../open-issues.md#open-039), [OPEN-051](../open-issues.md#open-051), [OPEN-059](../open-issues.md#open-059), [OPEN-058](../open-issues.md#open-058), [OPEN-062](../open-issues.md#open-062)
- 移行元: [設計メモ](../sources/fp-language-design.md) 14

## 目的と範囲

テストの設計の原則、ゴールデンテスト、型検査器・VM のテスト、fuzzing、言語仕様の例の検査、実装の規約と静的な検査。ロードマップの完了条件として挙げた受け入れ例と、言語仕様の各項目とを対応づける方針も扱う。

現在の版は、最小実行版と初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。見出しに「（初回リリース版）」を付けた節と、本文で初回リリース版と示した記述が、初回リリース版で加えるものである。それ以外の記述は、最小実行版から初回リリース版まで変えずに使う。初回リリース版には外部の関数の層を実装しない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。外部の関数（WASM のモジュールの関数）のテストは、外部の関数を実装する版で定める（[OPEN-051](../open-issues.md#open-051)）。ランダムに生成した型の付くプログラムで反例を探すことは、形式検証の段階 1 として初回リリース版の実装の中で行う（[ロードマップ](../00-overview/00-03-roadmap.md)の「形式検証の時期」、[ADR 0213](../decisions/0213-formal-verification-stage-1-in-first-release.md)）。後述の「差分テスト」に、その要点だけを書く。

## 前提

処理系のテストは、Rust の標準のテストの仕組みで書き、`cargo test` で実行する。テストは、処理系を別のプロセスとして起動せず、処理系の Rust の API を直接呼んで検査と実行を行う。ただし、プロセス全体に関わる次の振る舞いは、API からは確かめられないので、CLI を別のプロセスとして起動するテストで確かめる。

- panic hook の設定と、処理系の不具合の報告が標準エラー出力に出る順序（[ランタイム](../02-impl/02-09-runtime.md)の「panic 境界」）。そのテストで panic を起こす手段は、実装プランで定める。
- 中断の要求（`SIGINT`・`SIGTERM`）を受けたときの振る舞い（初回リリース版。[ADR 0163](../decisions/0163-interrupt-releases-resources.md)、[ADR 0223](../decisions/0223-interrupt-tests-in-separate-process.md)）。後述の「中断の要求のテスト（初回リリース版）」で定める。

API を呼ぶテストの実行には、テスト用のハンドラ表を使う（[ランタイム](../02-impl/02-09-runtime.md)）。初回リリース版のテスト用のハンドラ表は、ネットワークの操作を実際に行う（後述の「HTTP のテスト（初回リリース版）」）。

## 仕様

### テストの設計の原則

【決定】処理系のテストは、Vladimir Khorikov『Unit Testing Principles, Practices, and Patterns』（邦訳『単体テストの考え方/使い方』）の考え方に沿った次の原則で書く。新しいテストは、プロジェクトのスキル `test-audit`（`.claude/skills/test-audit/`）の作成時の関門を通してから加える（[ADR 0080](../decisions/0080-test-design-principles-and-test-audit.md)）。同書の要約は、原典の該当箇所で確かめていない。正式リリース版の前に確かめる（[OPEN-038](../open-issues.md#open-038)、[ADR 0245](../decisions/0245-perl-virtues-source-and-fact-check-timing.md)）。

【方針】原則は次のとおりである。

- **テストの価値**: テストは維持の費用がかかる。退行を捕まえる力、振る舞いを変えない作り直しに耐えること、速いフィードバック、読みやすさの四つで価値を判断する。作り直しに耐えることは、ほかの性質と引き換えに手放さない。
- **確かめるもの**: 観察可能な振る舞い（observable behavior）を確かめ、実装の詳細（implementation detail）を確かめない。処理系では、観察可能な振る舞いは、各段の公開の関数と型が返す結果、診断、スクリプトの出力と終了状態である。段の中の非公開の関数や、中間のデータの並びの順序などは確かめない。
- **テストの単位**: テストの単位は、クラスや関数ではなく、振る舞いの単位である。処理系の中の段や型を、テストダブル（test double）で置き換えない。
- **テストダブルを使う範囲**: テストダブルは、処理系の外にあり、処理系が管理しない依存（ファイル・プロセス・標準出力・環境変数など）にだけ使う。処理系では、テスト用のハンドラ表がこれに当たる（[ランタイム](../02-impl/02-09-runtime.md)）。
- **確かめ方の優先順位**: 出力を確かめるテストを最も優先し、次に状態を確かめるテスト、最後に呼び出しのやり取りを確かめるテストとする。処理系の段の多くは外部に作用しない関数なので、出力を確かめるテストで書ける。
- **網羅率**: 網羅率を目標にしない。網羅率は、テストの足りない箇所を探す手がかりとしてだけ使う。
- **テストの形**: 準備・実行・確認（Arrange・Act・Assert）の三つの部分に分けて書く。似た場合は、表の形のテスト（パラメータを並べたテスト）の行として足す。
- **持ち主の境界**: 一つの契約は、最も適した境界の一つのテストで守る。別の層にテストを足すのは、その層に固有の危険があるときに限る。持ち主の境界は、次の三つである。
  1. 処理系の各段（モジュールの読み込み、字句解析、構文解析、名前解決、型検査、脱糖、判定の木への変換、コード生成、VM、VM のスケジューラ、ランタイム、フォーマッタ）の公開の関数と型。ランタイムには永続コレクションを含み、リストを単純なモデルと突き合わせるテストはその公開の関数を境界にする（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)）。段の中の非公開の関数は、境界ではない。
  2. CLI のゴールデンテスト。
  3. 言語仕様の例の検査と、参照インタプリタとの差分テスト。
- **退行テスト**: 不具合を直したときに足すテストは、直す前のコードで失敗し、直した後に通ることを確かめてから加える。

【決定】持ち主の境界は、前述の三つとする。持ち主の境界は本章で定め、スキル `test-audit` の「持ち主の境界」の節は本章と同じ内容を書く。二つが食い違ったときは本章を正とし、スキルを直す（[ADR 0212](../decisions/0212-test-owner-boundaries-in-testing-chapter.md)）。

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

### テストの種類（初回リリース版）

【方針】初回リリース版では、前述の種類を次のように広げ、種類を二つ加える。各行の詳細は、右の列に示した節で定める。

| 種類 | 初回リリース版で加えるもの | 詳細 |
|---|---|---|
| 段ごとの単体テスト | モジュールの読み込み（根のディレクトリの下のファイルの探索、循環する import の診断）、パターンの拡張を含む判定の木への変換、フォーマッタ、VM のスケジューラ、ランタイムの永続コレクション。スケジューラは、切り替える順序を指定できるスケジューラで確かめる（[仮想機械](../02-impl/02-08-vm.md)の「タスクの切り替え」）。リストは単純なモデルと突き合わせる（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)） | 後述の「ほかの章が求めるテスト（初回リリース版）」 |
| ゴールデンテスト | 複数のモジュールからなるスクリプト、`test`・`fmt`・`fmt-check` の方式、CLI のオプション（[ADR 0224](../decisions/0224-golden-test-format-for-first-release.md)）。すべての `check` と `run` のテストで、フォーマッタの性質を確かめる | 後述の「ゴールデンテストの形式（初回リリース版）」 |
| 差分テスト | 無作為に生成した型の付くプログラム（[ADR 0213](../decisions/0213-formal-verification-stage-1-in-first-release.md)） | 後述の「差分テスト」 |
| IO の方式のテスト | タスクを待たせる操作を含むスクリプト | 後述の「IO の方式のテスト」 |
| コア IR の検査 | コア計算の初回リリース版の拡張（[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の「初回リリース版の拡張」）の型付け規則 | 後述の「コア IR の検査」 |
| fuzzing | モジュールの読み込み（複数のファイルからなる入力）とフォーマッタ | 後述の「fuzzing」 |
| 中断の要求のテスト（新たに加える） | CLI を別のプロセスとして起動し、シグナルを送る（[ADR 0223](../decisions/0223-interrupt-tests-in-separate-process.md)） | 後述の「中断の要求のテスト（初回リリース版）」 |
| HTTP のテスト（新たに加える） | 同じスクリプトの中のループバックの通信（[ADR 0222](../decisions/0222-http-tests-over-loopback.md)） | 後述の「HTTP のテスト（初回リリース版）」 |

### ゴールデンテスト

【決定】ゴールデンテストは、スクリプトのファイルと、期待する結果のファイルを並べて書く。実際の結果で期待値のファイルを書き直す指定を用意する（[ADR 0039](../decisions/0039-golden-test-files.md)）。

【方針】テストは、処理系のソースの `testdata/` の下に、区分ごとのディレクトリ（`lexical`、`syntax`、`names`、`types`、`effects`、`patterns`、`eval`、`io`、`acceptance` など）を作って置く。一つのテストは、同じ名前で拡張子の違う次のファイルからなる。

| ファイル | 内容 | 必須 |
|---|---|---|
| `<名前>.bnt` | スクリプト | 必須 |
| `<名前>.mode` | `check` か `run` か | 必須 |
| `<名前>.exit` | 期待する終了状態（[ADR 0037](../decisions/0037-exit-status-values.md)） | 必須 |
| `<名前>.stdout` | 期待する標準出力 | `run` のとき |
| `<名前>.stderr` | 期待する、スクリプトが書いた標準エラー出力と `main` の `Result.Error` の文字列 | `run` で書くとき |
| `<名前>.diag.json` | 期待する診断、実行時エラー、資源の不足の報告。JSON の形式（[ADR 0032](../decisions/0032-rust-style-text-and-json.md)）で、一行に一つ | 報告があるとき |
| `<名前>.args` | スクリプトに渡すコマンドライン引数。一行に一つ | 任意 |
| `<名前>.files/` | `File.readText` で読めるファイル。テスト用のハンドラ表に与える | 任意 |
| `<名前>.text.stderr` | 期待する、文章の形式の診断 | 任意。文章の体裁を確かめるテストだけに置く |

診断は JSON の形式で比べ、文言・コード・位置・補助の位置・注記・修正案がすべて一致することを求める。文章の形式の体裁は、少数のテストの `.text.stderr` で確かめる。

スクリプトの先頭のコメントに、そのテストが確かめる仕様の項目を書く（`// spec: 01-05 網羅性の検査` など）。一つのテストが複数の項目を確かめてよい。

### ゴールデンテストの形式（初回リリース版）

【決定】初回リリース版では、ゴールデンテストの置き方と方式を次のように広げる（[ADR 0224](../decisions/0224-golden-test-format-for-first-release.md)）。前述の表のファイルは、そのまま使う。

| ファイル | 内容 | 必須 |
|---|---|---|
| `<名前>/` | `<名前>.bnt` の代わりに置くディレクトリ。実行を始めるファイル `main.bnt` と、それが取り込むモジュールを入れる。処理系にはディレクトリを与える（[ADR 0127](../decisions/0127-directory-run-and-root.md)）。期待値のファイルはディレクトリの隣に置く | `<名前>.bnt` かこのディレクトリのどちらか |
| `<名前>.mode` | `check`・`run` に加えて、`test`・`fmt`・`fmt-check` のどれか | 必須 |
| `<名前>.options` | CLI のオプション（`--deny-warnings` など）。一行に一つ | 任意 |
| `<名前>.formatted` | 期待する整形の結果。スクリプトがディレクトリのときは、同じ構成のディレクトリ `<名前>.formatted/` | `fmt` のとき |

方式ごとに確かめるものは、次のとおりである。

| 方式 | 確かめるもの |
|---|---|
| `test` | 終了状態（[ADR 0206](../decisions/0206-test-command-line-and-exit-status.md)）、`.stdout` のテストの結果の報告と集計（[ADR 0208](../decisions/0208-test-report-destination.md)。形の細部は [OPEN-058](../open-issues.md#open-058)）、検査の誤りの診断 |
| `fmt` | 整形の結果が `.formatted` と一致すること。整形は、テストの一時ディレクトリに写したものに対して行い、元のファイルを変えない（[ADR 0207](../decisions/0207-fmt-command-line.md)） |
| `fmt-check` | `--check` を指定したときの終了状態と標準エラー出力（[ADR 0207](../decisions/0207-fmt-command-line.md)） |

【決定】`check` と `run` のすべてのゴールデンテストについて、テストの実行器が次の二つを自動で確かめる（[ADR 0224](../decisions/0224-golden-test-format-for-first-release.md)）。

- `fmt` の結果を `check` したときに、元のスクリプトと同じ診断が出る。
- `fmt` を二度適用しても、二度目で変わらない（冪等性）。

【方針】整形で位置が変わるので、同じ診断かどうかは、診断のコードと文言の並びで比べ、位置は比べない。構文の誤りがあるスクリプトは `fmt` が書き換えない（[ADR 0207](../decisions/0207-fmt-command-line.md)）ので、この二つの確認から除く。

【方針】初回リリース版では、区分のディレクトリに次のものを加える。

| 区分 | 主な内容 |
|---|---|
| `modules` | モジュールと import、公開、根のディレクトリ、ディレクトリを指定した実行 |
| `traits` | 型クラスの宣言と実装、制約、上位の型クラス |
| `handlers` | 利用者が定義するエフェクトとハンドラ、組み込みの操作の差し替え |
| `concurrency` | タスク、`TaskGroup`、取り消し、失敗の伝わり方 |
| `network` | HTTP のサーバとクライアント（後述の「HTTP のテスト（初回リリース版）」） |
| `stdlib` | 標準ライブラリのモジュールの関数 |
| `warnings` | 警告と `--deny-warnings`（後述の「警告のテスト（初回リリース版）」） |
| `test` | `test` の方式 |
| `fmt` | `fmt` と `fmt-check` の方式 |

【方針】`concurrency` と `network` のテストのスクリプトは、出力の順序がタスクを切り替える時機によらないように書く（`Task.all` の結果を受け取ってから書くなど）。タスクを切り替える順序そのものは、段ごとの単体テストで、切り替える順序を指定できるスケジューラを使って確かめる（[仮想機械](../02-impl/02-08-vm.md)の「タスクの切り替え」）。

### 差分テスト

【決定】同じプログラムを参照インタプリタと VM で実行し、結果を突き合わせる差分テストを行う（[ADR 0018](../decisions/0018-reference-interpreter.md)）。

【方針】差分テストの対象は、`run` のゴールデンテストと、[性能](07-02-performance.md)のベンチマーク（入力を小さくしたもの）のうち、タスクを起動する組み込みの関数を使わないものとする。タスクはコア計算に含まれず、参照インタプリタはタスクを起動する組み込みの関数を実行しない（[中間表現と脱糖](../02-impl/02-06-ir-and-lowering.md)の「参照インタプリタの範囲」、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)）。

【方針】比べるのは、IO の事象の列（書き込みの内容と順序、読んだファイル）、終わり方（値で終わったか、どの種類の実行時エラーで止まったか）、実行時エラーの位置である。資源の不足で止まるスクリプトは、比べる対象から外す（[ADR 0018](../decisions/0018-reference-interpreter.md)）。結果が食い違ったときは、[コア計算と脱糖](../01-spec/01-12-core-calculus.md)の規則に照らして、どちらが誤っているかを調べる。

【決定】初回リリース版では、差分テストの対象に、無作為に生成した型の付くプログラムを加える。これは形式検証の段階 1 であり、参照インタプリタを初回リリース版の範囲に広げたものを実行可能な意味論として使う。反例から 01-12 の規則の誤りが分かったときは、ADR を添えて規則を直す（[ADR 0213](../decisions/0213-formal-verification-stage-1-in-first-release.md)、[ロードマップ](../00-overview/00-03-roadmap.md)の「形式検証の時期」）。

### IO の方式のテスト

【方針】`run` のゴールデンテストのすべてを、IO の二つの方式（[ADR 0029](../decisions/0029-two-io-execution-modes.md)）で実行し、どちらの方式でも期待値と一致することを確かめる。

【方針】初回リリース版では、どちらの方式でも、組み込みの操作の応答に「待つ」があり、待つタスクはスケジューラの待ちの表に移り、操作が完了したら進められるタスクの待ち行列に戻る（[ランタイム](../02-impl/02-09-runtime.md)の「IO 実行器」、[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。この移り変わりも二つの方式で同じ結果になることを、`concurrency` と `network` の `run` のテストを両方の方式で実行して確かめる。

### コア IR の検査

【方針】ゴールデンテストと差分テストで脱糖を通るすべてのスクリプトについて、脱糖の結果をコア IR の検査器（[中間表現と脱糖](../02-impl/02-06-ir-and-lowering.md)）にかけ、型が付くことを確かめる。型が付かなければ、処理系の不具合としてテストを失敗させる。

### 派生した診断が出ないことのテスト

【方針】型検査は、関数の本体の中でも誤りの後に検査を続ける（[ADR 0024](../decisions/0024-continue-after-type-errors.md)）。これを確かめるために、次のゴールデンテストを置く。

- 一つの関数に、互いに独立した型の誤りが複数あるスクリプト。すべての誤りが報告されることを確かめる。
- 一つの誤りが、後の式の型に波及しうるスクリプト（誤った型の変数を、後で何度も使うなど）。最初の誤りだけが報告されることを確かめる。

期待値のファイルは診断の一覧すべてを持つので、余分な診断が出ればテストは失敗する。

### fuzzing

【方針】cargo-fuzz で、字句解析・構文解析・名前解決・型検査に任意のバイト列と、既存のテストのスクリプトを変形したものを与える。確かめる性質は次のとおりである。

- 処理系の不具合（Rust の panic、処理系の不具合の報告）が起きない。
- すべての診断の span が、ソースの範囲の中にある。
- 誤りがないと判定したスクリプトは、脱糖とコード生成を不具合なしに通る。

【方針】初回リリース版では、次の二つを fuzzing の対象に加える。

- モジュールの読み込み: 複数のファイルからなる入力（ファイルの名前と中身の組の並び）を、根のディレクトリの下に置いたものとして読み込み、型検査まで通す。確かめる性質は、前述の三つと同じである。
- フォーマッタ: 任意の入力に `fmt` を適用する。処理系の不具合が起きないこと、構文の誤りのない入力について冪等性が成り立つこと、整形の前後で `check` の診断が同じであること（前述の「ゴールデンテストの形式（初回リリース版）」と同じ比べ方）を確かめる。

【方針】fuzzing のクレートは、リポジトリの `fuzz/` に置く。cargo-fuzz は libFuzzer を使い、nightly の Rust のコンパイラを必要とする（[Rust Fuzz Book](https://rust-fuzz.github.io/book/cargo-fuzz/setup.html)）。ほかの検査は stable の Rust で行うので、`fuzz/` は Cargo のワークスペースから除き、fuzzing だけ nightly で実行する。

【方針】fuzzing は、後述の完了条件の検査には含めず、別に実行する。短時間の実行は `scripts/fuzz-short.sh` で行う。このスクリプトは、`scripts/fuzz-seed.sh` でゴールデンテストのスクリプトを変形の元の入力として写してから、各対象を短時間ずつ動かす。長時間の実行は、対象ごとに時間を指定して別に行う。

### ほかの章が求めるテスト（初回リリース版）

【方針】ほかの章が処理系のテストに委ねた確認を、次のテストで受け持つ。

| 確かめること | 求めた章 | テストの種類 |
|---|---|---|
| 標準ライブラリのソースのすべてのモジュールが、名前解決と型検査を誤りなしに通る。`@builtin` の名前がすべて組み込みの関数の表にあり、宣言の型が Rust の実装と合う | [名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」 | 段ごとの単体テスト（名前解決と型検査）。宣言の型と Rust の実装を突き合わせる方法は実装プランで定める |
| 組み込みの関数の実装が持つ構成子のタグの定数が、標準ライブラリのソースの型の宣言の順と一致する | [バイトコードとコード生成](../02-impl/02-07-bytecode.md)の「コンパイル済みプログラム」 | 段ごとの単体テスト（コード生成） |
| タスクの切り替え、待ち、取り消しの動き | [仮想機械](../02-impl/02-08-vm.md)の「タスクの切り替え」 | 段ごとの単体テスト（VM のスケジューラ）。切り替える順序を指定できるスケジューラで、切り替えの位置ごとにテストが与えた順序でタスクを選ぶ |
| IO の二つの方式で、タスクの待ちを含めて同じ結果になる | [ランタイム](../02-impl/02-09-runtime.md)の「IO 実行器」 | IO の方式のテスト |
| リストの操作の列が、単純なモデル（Rust の `Vec`）と同じ要素の並びと長さを作る。どの関数も引数のリストを変更しない | [標準ライブラリ](../03-interop/03-06-stdlib.md)の「List の内部の表現」（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)） | 段ごとの単体テスト（ランタイムの永続コレクション） |
| `Map` と `Set` の操作の列が、単純なモデル（Rust の `BTreeMap`・`BTreeSet`）と同じ内容と鍵の順序を作る。木の平衡の条件は、テストではなく `debug_assert!` で確かめる（[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md) と同じ扱い） | [標準ライブラリ](../03-interop/03-06-stdlib.md)の「Map と Set（初回リリース版）」 | 段ごとの単体テスト（ランタイムの永続コレクション） |
| 標準ライブラリのソースが正規形である（整形しても変わらない） | [フォーマッタ](../06-tooling/06-03-formatter.md)の「標準ライブラリのソース」 | 段ごとの単体テスト（フォーマッタ）。標準ライブラリのソースとして整形する |
| 整形後の検証（字句の並びとコメントの比較）が、整形の誤りを見つける | [フォーマッタ](../06-tooling/06-03-formatter.md)の「整形後の検証」 | 段ごとの単体テスト（フォーマッタ）。検証の関数に、字句やコメントを変えた出力を与える |

### 警告のテスト（初回リリース版）

【方針】警告は、`check` でも `run` でも報告し、`--deny-warnings` を指定したときは誤りとして扱う（[ADR 0166](../decisions/0166-warnings-reported-by-run-and-deny-option.md)）。これを `warnings` の区分のゴールデンテストで確かめる。同じスクリプトについて、`.options` のないテスト（警告を報告し、`check` は終了状態 0 で終え、`run` は実行する）と、`.options` に `--deny-warnings` を書いたテスト（終了状態 2 で終え、実行しない）を並べる。診断の件数の行が誤りと警告を分けて数えることは、`.text.stderr` で確かめる。

### HTTP のテスト（初回リリース版）

【決定】HTTP のテストの主な方法は、実際のループバックの通信とする。`network` の区分のゴールデンテストでは、一つのスクリプトが `Http.listen("127.0.0.1", 0)` で待ち受け、選ばれたポートを `Http.listenerPort` で調べ（[ネットワークのモジュール](../03-interop/03-09-network.md)の「サーバ」）、サーバをタスクで動かして、同じスクリプトからクライアントとして接続する。イベントループ、タスクの切り替え、HTTP の要求の解析と応答の生成を、外部のネットワークに出ずに一緒に確かめる（[ADR 0222](../decisions/0222-http-tests-over-loopback.md)）。

【決定】テスト用のハンドラ表のネットワークの項目は、ループバックでは起こしにくい失敗（名前の解決の失敗、接続の拒否、接続のリセット、時間切れ）を、決まった結果として作るためだけに使う（[ADR 0222](../decisions/0222-http-tests-over-loopback.md)、[ランタイム](../02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」）。失敗を指定する手段（期待値と並べたファイルに書くか、Rust のテストから与えるか）は、実装プランで定める。

【方針】`network` の区分のテストのスクリプトは、ループバックのアドレスにだけ接続する。

【決定】HTTPS のクライアントは外部に接続しなければ確かめられないので、証明書の検証を伴う接続は処理系のテストに含めない。手元で動かす TLS のサーバで TLS の組み立てを確かめるかは、初回リリース版の実装プランで決める（[ADR 0222](../decisions/0222-http-tests-over-loopback.md)）。

### 中断の要求のテスト（初回リリース版）

【決定】中断の要求のテストは、CLI を別のプロセスとして起動するテストで行う（[ADR 0223](../decisions/0223-interrupt-tests-in-separate-process.md)）。テストは次の手順で進める。

1. ビルドした `benitoite` の実行ファイルを、Cargo が統合テストのビルドのときに設定する環境変数 `CARGO_BIN_EXE_<name>` で見つけ（[The Cargo Book: Environment variables Cargo sets for crates](https://doc.rust-lang.org/cargo/reference/environment-variables.html#environment-variables-cargo-sets-for-crates)）、子プロセスとして起動する。
2. スクリプトは、準備ができたことを示す行を標準出力に書いてから待つ（標準入力を読む、または長く待つ）。
3. テストは、その行を読んだ後に `SIGINT` か `SIGTERM` を送る。
4. 終了状態が 130 であること、バッファに残っていた出力が書き出されたこと、`with` のリソースが解放されたこと（書き込みで開いたファイルの内容が書き出されていること）を確かめる（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)）。

【決定】解放の途中で二度目のシグナルを送り、解放を待たずに OS の既定の振る舞いで終えることを確かめる場合を一つ置く。これらのテストは Unix に限る。初回リリース版の対象の環境は、どれも Unix 系である（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)）。

【方針】`test` の実行中の中断（実行中のテストを止め、それまでの結果を報告して終了状態 130 で終える。[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)の「テストの実行」）も、同じ手順で一つ確かめる。

### 実装の規約と静的な検査

処理系は LLM が実装する（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。実装 LLM は、実装プランに書いた規約を読んでも守りきれないことがある。そこで、規約はできるだけ、型の定義、コンパイラと lint、テストで守らせ、文章で頼む規約は、それらで決めにくいものに限る。

【方針】実装プランは、処理系設計（`02-impl/`）が定めるデータ構造を、Rust の型の定義と、主要な関数のシグネチャとして示す。型には、構文木・値・命令・誤りの種類の列挙型と、意味の違う整数（ファイル ID、位置、レジスタの番号など）を取り違えないための専用の型を含める。実装 LLM は、示した型とシグネチャを変えずに中身を書く。型やシグネチャを変える必要が生じたときは、実装を進めずに報告し、実装プランを改めてから続ける。

【方針】規約のうち道具で確かめられるものは道具で確かめ、確かめた結果を各作業の完了条件にする。

【方針】実装プランの各作業の完了条件に、次の検査がすべて通ることを含める。検査は `scripts/check.sh` にまとめ、作業を取り込む前にこのスクリプトを通す。

| 検査 | 道具 | 確かめること |
|---|---|---|
| 書式 | `cargo fmt --check` | ソースが rustfmt の書式に従っている。書き換えずに確かめる（[rustfmt](https://github.com/rust-lang/rustfmt)） |
| lint | Clippy。警告を誤りとして扱う | 下の表の lint と、Clippy の既定の lint に違反しない |
| テスト | `cargo test` | 本章のテストが通る。テストを加える・変えた作業では、`test-audit` の作成時の関門を通している（前述の「テストの設計の原則」） |
| 言語仕様の例 | `tools/grammar-check/`（後述の「言語仕様の例の検査」） | 言語仕様の例が、初回リリース版の文法の全体で読める |
| 仕様の項目の集計の道具 | `tools/spec-coverage/` の自己テスト | ゴールデンテストと仕様の節の対応を集計する道具（後述の「受け入れ例と仕様の項目の対応」）が正しく動く |
| 依存のライセンス | cargo-deny の licenses の検査 | 依存するクレートのライセンスが、許可したライセンスの一覧に入っている（[ADR 0003](../decisions/0003-license.md)、[cargo-deny](https://embarkstudios.github.io/cargo-deny/checks/licenses/index.html)） |

【方針】警告を誤りとして扱う指定は、リポジトリの `.cargo/config.toml` に `[build] warnings = "deny"` と書く（Clippy が勧める `CARGO_BUILD_WARNINGS=deny` と同じ設定を、ファイルに置いたもの。[Clippy の README](https://github.com/rust-lang/rust-clippy/blob/master/README.md)）。コマンドの引数（`cargo clippy -- -D warnings`）に頼らないので、検査のコマンドを変えても警告は誤りのまま残る。

【方針】lint の水準は、コマンドの引数ではなくワークスペースの `Cargo.toml` の `[workspace.lints]` の表に書き、クレートの `Cargo.toml` の `[lints]` で引き継ぐ（[The Cargo Book: lints](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section)）。実装 LLM がコマンドの引数を変えて検査を緩められないようにするためである。次の lint を誤りの水準にする。Clippy の lint の意味は [Clippy の lint の一覧](https://rust-lang.github.io/rust-clippy/stable/index.html)による。

| lint | 検出するもの | 誤りにする理由 |
|---|---|---|
| `unsafe_code`（rustc。`forbid` にする） | `unsafe` のブロックなど | 値の表現とランタイムを作り直すまでは、`unsafe` を使わない（[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。`forbid` は、ソースの中の指定で緩められない（[rustc の lint の水準](https://doc.rust-lang.org/rustc/lints/levels.html)）。【方針】初回リリース版の実装プランを作るときの作り直しで `unsafe` を許す（[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)）。許す範囲は作り直しの設計で決め（[OPEN-039](../open-issues.md#open-039)）、水準を `forbid` から `deny` に改めて、指定したモジュールでだけ `#[allow(unsafe_code)]` を書く形などにする。許す箇所は `AGENTS.md` の `#[allow]` を書いてよい箇所の表に載せる |
| `wildcard_enum_match_arm` | 列挙型の `match` での `_` の分岐 | 構文木・値・命令の種類を加えたときに、処理の漏れを型の検査で見つけるため（[実装言語の比較](../08-appendix/08-01-implementation-language-comparison.md)） |
| `unwrap_used`・`expect_used` | `Option`・`Result` の `unwrap`・`expect` | 失敗を panic にせず、`Result` で扱うため |
| `panic`・`todo`・`unimplemented` | `panic!`・`todo!`・`unimplemented!` | panic は処理系の不具合に限る（[ランタイム](../02-impl/02-09-runtime.md)の「panic 境界」）。作りかけの箇所を残さない |
| `dbg_macro` | `dbg!` | デバッグの出力を残さない |
| `indexing_slicing` | panic しうる添字と範囲の指定 | 添字の誤りを panic にせず、`get` などで扱うため |
| `arithmetic_side_effects` | 溢れうる算術の演算 | 溢れを見落とさないため。言語の `Integer` の演算は、溢れを検査して実行時エラーにする（[ADR 0006](../decisions/0006-basic-types-semantics.md)） |
| `let_underscore_must_use` | `#[must_use]` の値を `let _ =` で捨てること | 失敗しうる呼び出しの結果を、黙って捨てないため（下の `unused_must_use` の抜け道を塞ぐ） |
| `clone_on_ref_ptr` | 参照カウントのポインタへの `.clone()` | 参照カウントの複製を `Rc::clone(&x)` の形で明示し、値の複製と見分けるため（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)） |

`Result` は `#[must_use]` を付けた型であり（[core::result のソース](https://github.com/rust-lang/rust/blob/master/library/core/src/result.rs)）、値を使わずに捨てると rustc の lint `unused_must_use` が警告する（[rustc の lint の一覧](https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#unused-must-use)）。警告を誤りとして扱うので、`Result` を捨てたコードはビルドが通らない。

これらの lint を個別に許す指定（`#[allow(...)]`）を書いてよい箇所と、許す lint は、リポジトリの AGENTS.md の「実装の規約」の表に定める。その箇所にも、許す理由をコメントで書く。テストのコードでは、`panic`・`unwrap_used`・`expect_used` などを許してよい。

【方針】リリースのビルドでも、整数の溢れの検査（Cargo のプロファイルの `overflow-checks`）を有効にする。既定では、dev のビルドでは有効、release のビルドでは無効である（[The Cargo Book: profiles](https://doc.rust-lang.org/cargo/reference/profiles.html#overflow-checks)）。有効にすると溢れで panic するので、処理系の内部の溢れは処理系の不具合として報告される。言語の `Integer` の溢れは、この検査に頼らず、演算の関数が検査して実行時エラーにする。

【方針】道具では確かめにくい規約は、実装プランに書き、実装を確かめるときに読む。

- 言語の値は、ランタイムの確保の処理を通して作る（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。
- 利用者のプログラムの大きさや深さに比例して、処理系の再帰を深くしない。構文解析器の入れ子の深さの上限（[字句解析器と構文解析器](../02-impl/02-03-frontend.md)の「入れ子の深さ」）の内側で再帰するか、明示の積み重ねを使う（[仮想機械](../02-impl/02-08-vm.md)）。
- 依存するクレートは、実装プランに書いたものに限る。外部のコードを写さない。使う場合は出典とライセンスを記録する（[ADR 0003](../decisions/0003-license.md)）。

【方針】実装を確かめるときは、道具で確かめにくい点を、決まった観点の一覧で読む。一覧には、`#[allow]` とその理由、`as` による数値の変換、誤りを文字列で表している箇所、実装プランの型から外れた箇所を含める。最小実行版では、オーケストレータの Claude Code がすべての作業を確かめ、Opus が実装した作業は Codex も確かめる（[ADR 0085](../decisions/0085-review-assignment-for-minimal.md)。実装の割り当ては [ADR 0084](../decisions/0084-implementer-assignment-for-minimal.md)）。初回リリース版の実装と確認の分担は【未決】である（[OPEN-059](../open-issues.md#open-059)）。最小実行版と同じく、初回リリース版の実装プランを作るときに、各作業の難しさを見積もってから決める。

【方針】命名、コメント、モジュールの分け方など、型と道具とテストで決めにくい書き方の規約は、リポジトリの AGENTS.md の「実装の規約」の節に書く。会話ごとのプロンプトに頼らず、どの LLM とハーネスも同じ規約を読むようにするためである。

### 受け入れ例と仕様の項目の対応

【方針】ロードマップの最小実行版の完了条件（[ロードマップ](../00-overview/00-03-roadmap.md)の「完了条件」）の各行に、`testdata/acceptance/` のゴールデンテストを一つ以上対応させる。対応は、完了条件の行ごとに、テストの名前を並べた一覧として、テストのディレクトリに置く。

【方針】仕様の各章（`01-spec/`）の節のうち、最小実行版の範囲の節ごとに、それを確かめるテストがあるかを、テストの先頭のコメント（前述の `// spec:`）から集計できるようにする。確かめるテストのない節は、一覧として出力する。

【方針】初回リリース版では、ロードマップの初回リリース版の完了条件（[ロードマップ](../00-overview/00-03-roadmap.md)の「初回リリース版」の「完了条件」）の各行を、次のように確かめる。前述の一覧には、処理系のテストで確かめる行だけを載せる。

| 完了条件の行 | 確かめ方 |
|---|---|
| 同梱の Agent Skill だけを与えた LLM が、JSON ファイルを読んで集計するスクリプトを書く | LLM を動かす試行は処理系のテストに含めず、完了の判定のときに別に行う。試行で得たスクリプトを、`acceptance` の `run` のテストとして残す |
| `Process.run` と `Process.shell` のスクリプト | `acceptance` の `run` のテスト。処理系のテストは外部コマンドの起動をテスト用のハンドラ表で置き換えうるので、実際の起動は、最後の行の各環境での確認で確かめる |
| 影響の大きい操作をテストのコードのハンドラで差し替えて `test` を実行する | `acceptance` の `test` の方式のテスト |
| コメントを含むスクリプトに `fmt` を適用する | `acceptance` の `fmt` の方式のテストと、前述のフォーマッタの性質の確認 |
| 処理系の単一バイナリを各環境で実行する | 配布する実行ファイルを各環境で動かし、上の各行のスクリプトを CLI で実行して同じ結果になることを確かめる。手順は実装プランで定める |

【方針】初回リリース版では、仕様の節の集計の対象を、見出しに「（初回リリース版）」を付けた節にも広げる。

### 言語仕様の例の検査

【方針】言語仕様（`01-spec/`）に載せたコードの例が、[構文](../01-spec/01-02-syntax.md)の「初回リリース版の文法の全体」で読めるかを、道具で確かめる。構文の章や例を変えたときに、例が文法と食い違ったまま残ることを防ぐためである。

- 初回リリース版の文法の全体に照らす検査は、Python で書いた道具（`tools/grammar-check/`）で行う。この道具は、字句構造の規則を手で実装した字句解析器と、01-02 の EBNF の文字列をそのまま読み込む照合器からなる。
- 最小実行版の構文解析器は初回リリース版の構文を読めない（[構文](../01-spec/01-02-syntax.md)の「最小実行版に含めない構文」）ので、例を最小実行版の範囲と初回リリース版の範囲に分ける。最小実行版の範囲の例は、見出しに「（初回リリース版）」を付けていない節の例のうち、初回リリース版の構文を含まないものである。初回リリース版の構文を含むのに「（初回リリース版）」の節にない例は、処理系で読む検査（次項）の側で、初回リリース版の構文に固有の字句（`import`、`trait` など）を含むかで見分け、最小実行版の範囲から除く。
- 最小実行版の範囲の例は、処理系の字句解析器と構文解析器で読む Rust のテスト（処理系のクレートの `tests/spec_examples.rs`）でも検査する。この検査は、処理系の構文解析器が最小実行版の文法と一致しているかも確かめる。
- 文法で読めなくて正しい例（字句の一覧、誤りの例、本体を省略した宣言など）は、Python の道具と Rust のテストの両方に、同じ一覧として登録する。
- 初回リリース版の構文解析器を実装するときに、すべての例を処理系で読む形に移し、Python の道具を削除する。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-038](../open-issues.md#open-038): テストの設計の原則と、Khorikov の書籍の対応の確認
- [OPEN-039](../open-issues.md#open-039): 初回リリース版の値の表現と、その実装に `unsafe` を使うか（値の表現とランタイムの作り直しで決める。[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)）
- [OPEN-059](../open-issues.md#open-059): 初回リリース版の実装と確認の分担
- [OPEN-058](../open-issues.md#open-058): テストの結果の報告の形の細部（`test` の方式のゴールデンテストの期待値の形）
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R13）
