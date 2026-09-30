# D04 ゴールデンテストの `fmt`・`fmt-check` の方式と、フォーマッタの性質の確かめ

- 依存する作業: [D03](D03-fmt-command.md), [C10](C10-golden-runner.md), [C15](C15-fuzz.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。テストのデータを含む）
- ブランチ: impl/D04-fmt-golden

## 目的

ゴールデンテストの実行器（C10。C05 の後は `tests/golden.rs`）に、`fmt` と `fmt-check` の方式を加える（ADR 0224 の決定 2、07-03「ゴールデンテストの形式（初回リリース版）」）。あわせて、`check` と `run` のすべてのゴールデンテストで、整形の冪等性と、整形の前後で `check` の診断が変わらないことを自動で確かめる（ADR 0224 の決定 4）。fuzzing にフォーマッタの対象を加える（07-03「fuzzing」）。`fmt` の区分のゴールデンテストを置く。

## 読む設計書の節

- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md): 「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」「fuzzing」
- [フォーマッタ](../../design/06-tooling/06-03-formatter.md): 「テスト」
- [CLI](../../design/06-tooling/06-01-cli.md): 「`fmt` のコマンドライン（初回リリース版）」
- [ADR 0224](../../design/decisions/0224-golden-test-format-for-first-release.md)
- インターフェース: [10-17](../10-interfaces/10-17-formatter.md)、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「テストの実行器とゴールデンテストの実行器が使う口」
- 作業の文書: [C10](C10-golden-runner.md) の「期待値のファイル」「実行の手順」「書き直しの指定」、[C15](C15-fuzz.md)

## 作るもの

パスは、`tests/`・`testdata/` は処理系のクレートから、`fuzz/`・`scripts/` はリポジトリの根からの相対パスである。

- `tests/golden.rs` と `tests/golden/` の下: `fmt`・`fmt-check` の方式、フォーマッタの性質の確かめ。C10 が「U4 の方式」として失敗させていた `.mode` の値のうち、`fmt`・`fmt-check` を扱う（`test` は D12）。
- `testdata/fmt/`: `fmt` の区分のゴールデンテスト（後述の「受け入れテスト」）。
- `fuzz/fuzz_targets/format.rs`、`fuzz/Cargo.toml` の `[[bin]]`、`scripts/fuzz-short.sh`（対象を加える）、`scripts/fuzz-seed.sh`（`fmt` の区分のスクリプトと、ほかの区分のスクリプトを種の入力にする）、`fuzz/README.md`。

## 手順の要点

### `fmt` と `fmt-check` の方式

1. `fmt`: スクリプト（`<名前>.bnt` か `<名前>/`）を、テストごとの一時ディレクトリに写す。コマンドライン `["fmt", "--diagnostics=json", <.options の行>…, <写したパス>]` を `cli::parse_args` で解釈し、`cli::execute` で実行する（`--diagnostics` の扱いは C10「実行の手順」の 1 と同じ）。写したファイルの内容を、`<名前>.formatted`（ディレクトリのときは `<名前>.formatted/` の同じ構成のファイル）とバイト列で比べる。終了状態を `.exit` と、標準エラー出力を C10「実行の手順」の 4 と同じく JSON の行（`.diag.json`）とそれ以外（`.stderr`）に分けて比べる。元のファイルは変えない。
2. `fmt-check`: 同じく写したものに `["fmt", "--check", "--diagnostics=json", …]` を実行し、終了状態と標準エラー出力を比べる。写したファイルが変わっていないことも確かめる。
3. 標準エラー出力と診断の中のパスは、一時ディレクトリのパスをテストのパス（`testdata/fmt/<名前>.bnt`）に置き換えてから比べる。一時ディレクトリの名前が実行ごとに変わるからである。
4. 書き直しの指定（`BENITOITE_BLESS=1`）では、`fmt` の方式の `.formatted` を実際の結果で書き直す（C10「書き直しの指定」）。

### フォーマッタの性質の確かめ

`.mode` が `check` か `run` のすべてのテストについて、次を行う（ADR 0224 の決定 4）。

1. スクリプトの各 `.bnt`（ディレクトリのテストでは中のすべて）を `format_source`（`SourceKind::User`）で整形する。構文の誤り（`FormatError::Syntax`）のファイルを含むテストは、この確認から除く。`FormatError::Verify` は処理系の不具合として失敗させる。
2. 整形の結果をもう一度整形し、`changed` が偽であることを確かめる（冪等性）。
3. 整形の前と後のそれぞれで `pipeline::check_files`（`require_main` は真、`.options` の `--deny-warnings` に従う）を行い、診断のコードと文言の並びが同じであることを確かめる。位置は比べない（07-03）。
4. 除いた数と、性質の食い違いを、テストの失敗の一覧に区別して示す。

### fuzzing

`format` の対象は、入力を一つのファイルとして `format_source` にかけ、次を確かめる（07-03「fuzzing」）。

- 処理系の不具合（Rust の panic、`FormatError::Verify`）が起きない。
- 構文の誤りがなければ、整形の結果を整形しても変わらない。
- 構文の誤りがなければ、整形の前と後で `check_text` の診断のコードと文言の並びが同じである。

## 受け入れテスト

`testdata/fmt/` に次のテストを置く。どれも `// spec:` の行に確かめる 06-03 の節を書く（07-03「ゴールデンテスト」）。

| テスト | 方式 | 確かめること |
|---|---|---|
| `example` | `fmt` | 06-03「整形の例」の整形の前のソースが、整形の後のソースになる |
| `spaces`・`indent`・`comments`・`blank_lines`・`line_ends`・`multiline_string` | `fmt` | 06-03 の各節の規則の代表の場合（単体テストと重ねず、ファイル全体の結果で確かめる例を各一つ） |
| `directory` | `fmt` | ディレクトリのテストで、中の二つのファイルがどちらも整形される |
| `syntax_error` | `fmt` | 構文の誤りのファイルが書き換わらず、診断と終了状態 2 |
| `check_changed`・`check_canonical` | `fmt-check` | 変わるファイルで終了状態 1 と `would reformat` の行、正規形のファイルで終了状態 0 と空の標準エラー出力 |

あわせて、次を確かめる。

- 実行器の検出力: `.formatted` を 1 バイト変えるとテストが失敗する（手で確かめ、完了の報告に書く）。
- フォーマッタの性質の確かめが、`check` と `run` のすべてのテストに対して実行されている（除いた数と確かめた数を完了の報告に書く）。
- `scripts/fuzz-short.sh` で `format` の対象が 60 秒動き、不具合を見つけない。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストか確認の記録がある
- `scripts/fuzz-short.sh` の結果を完了の報告に書いている

## 難易度の理由

C10 の実行器に方式を足し、公開の関数を呼んで比べるだけである。判断が要るのは、一時ディレクトリのパスの置き換えと、性質の確かめから除く条件である。
