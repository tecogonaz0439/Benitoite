# D04 ゴールデンテストの `fmt`・`fmt-check` の方式と、フォーマッタの性質の確かめ

- 依存する作業: [D03](D03-fmt-command.md), [C10](C10-golden-runner.md), [C15](C15-fuzz.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。テストのデータを含む）
- ブランチ: impl/D04-fmt-golden
- 着手の時点: D03 の取り込みの後の `san_benito` から始める。D03 が `print.rs` と `formatter/tests.rs` を少し変えているからである。

## 目的

ゴールデンテストの実行器（C10。C05 の後は `tests/golden.rs`）に、`fmt` と `fmt-check` の方式を加える（ADR 0224 の決定 2、07-03「ゴールデンテストの形式（初回リリース版）」）。あわせて、`check` と `run` のすべてのゴールデンテストで、整形の冪等性と、整形の前後で `check` の診断が変わらないことを自動で確かめる（ADR 0224 の決定 4）。fuzzing にフォーマッタの対象を加える（07-03「fuzzing」）。`fmt` の区分のゴールデンテストを置く。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md): 「ゴールデンテスト」「ゴールデンテストの形式（初回リリース版）」「fuzzing」
- [フォーマッタ](../../2026-10-09-design-first-release/06-tooling/06-03-formatter.md): 規則のすべての節（「整形の考え方」「字句の間の空白」「字下げ」「コメント」「空の行」「行末と文字」「複数行の文字列」「整形の例」「入力表現」「整形後の検証」「構文の誤りがあるファイル」）と「テスト」
- [ADR 0323](../../2026-10-09-design-first-release/decisions/0323-with-binding-continuation-indent.md)、[ADR 0326](../../2026-10-09-design-first-release/decisions/0326-match-arm-and-handler-clause-head-continuation.md)（`.formatted` の字下げを読んで確かめるため）
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md): 「`fmt` のコマンドライン（初回リリース版）」
- [ADR 0224](../../2026-10-09-design-first-release/decisions/0224-golden-test-format-for-first-release.md)
- インターフェース: [10-17](../10-interfaces/10-17-formatter.md)、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「テストの実行器とゴールデンテストの実行器が使う口」
- 作業の文書: [C10](C10-golden-runner.md) の「期待値のファイル」「実行の手順」「書き直しの指定」、[C15](C15-fuzz.md)

## 作るもの

パスは、`tests/`・`testdata/` は処理系のクレートから、`fuzz/`・`scripts/` はリポジトリの根からの相対パスである。

- `tests/golden.rs` と `tests/golden/` の下: `fmt`・`fmt-check` の方式、フォーマッタの性質の確かめ。C10 が「U4 の方式」として失敗させていた `.mode` の値のうち、`fmt`・`fmt-check` を扱う（`test` は D12）。
- `testdata/fmt/`: `fmt` の区分のゴールデンテスト（後述の「受け入れテスト」）。
- `fuzz/fuzz_targets/format.rs`、`fuzz/Cargo.toml` の `[[bin]]`、`scripts/fuzz-short.sh`（対象を加え、結びの文の `All four fuzz targets` を `All five fuzz targets` に改める）、`scripts/fuzz-seed.sh`（`fmt` の区分のスクリプトと、ほかの区分のスクリプトを種の入力にする。`*.files/` と同じく `*.formatted/` の下も除く）、`fuzz/README.md`。
- 性質の確かめと fuzzing で見つけたフォーマッタの不具合は、D01・D02 のファイル（`src/cli/tools/formatter/` の `roles.rs`・`print.rs`・`verify.rs` など）を直してよい。再現するテストを加え、直した箇所を完了の報告に書く。
- あわせて、後述の「D02 の確認で見つかった直し」を行う。直してよいファイルは `print.rs`・`formatter/tests.rs`・`print/tests.rs` で、変えてよいのは非公開の関数だけである（10-17 の `sig=` に当たるものを変えない）。

## 手順の要点

### `fmt` と `fmt-check` の方式

1. `fmt`: スクリプト（`<名前>.bnt` か `<名前>/`）を、テストごとの一時ディレクトリの直下に同じ名前で写す。コマンドライン `["fmt", "--diagnostics=json", <.options の行>…, <写したパス>]` を `cli::parse_args` で解釈し、`cli::execute` で実行する（`--diagnostics` の扱いは C10「実行の手順」の 1 と同じ）。写したファイルの内容を、`<名前>.formatted`（ディレクトリのときは `<名前>.formatted/` の同じ構成のファイル）とバイト列で比べる。終了状態を `.exit` と、標準エラー出力を C10「実行の手順」の 4 と同じく JSON の行（`.diag.json`）とそれ以外（`.stderr`）に分けて比べる。元のファイルは変えない。`.formatted` がなければ（`syntax_error` など）、写したファイルが元と同じであることを期待する。ディレクトリのテストでは、`<名前>.formatted/` にないファイルについて、写したファイルが元と同じであることを期待する。
2. `fmt-check`: 同じく写したものに `["fmt", "--check", "--diagnostics=json", …]` を実行し、終了状態と標準エラー出力を比べる。写したファイルが変わっていないことも確かめる。
3. 標準エラー出力と診断の中のパスは、表示名のうち一時ディレクトリの部分を `testdata/fmt` に置き換えてから比べる。一時ディレクトリの名前が実行ごとに変わるからである。表示名は、ファイルを与えたときはそのパス、ディレクトリの下のファイルはディレクトリのパスに相対パスを続けたものである（10-17「`fmt` の実行」）。このため、`<一時ディレクトリ>/<名前>.bnt` は `testdata/fmt/<名前>.bnt` に、`<一時ディレクトリ>/<名前>/a.bnt` は `testdata/fmt/<名前>/a.bnt` になる。
4. `fmt` と `fmt-check` の方式では、C10「実行の手順」の 6（文章の形式での再実行と `.text.stderr`）を行わない。`fmt` の文章の形式の診断は、D03 の受け入れテスト（「構文の誤り」）が確かめる。
5. 書き直しの指定（`BENITOITE_BLESS=1`）では、`fmt` の方式の `.formatted` を実際の結果で書き直す（C10「書き直しの指定」）。整形の結果が元と変わらないファイルについては `.formatted` を作らず、あれば消す（ディレクトリのテストでは `<名前>.formatted/` の中のそのファイルを消し、中が空になれば `<名前>.formatted/` も消す）。手順 1 の「`.formatted` がなければ元と同じことを期待する」と揃えるためである。BLESS で作った `.formatted` は、06-03 の規則（と ADR 0323・0326 の字下げ）で読んで確かめる。

### フォーマッタの性質の確かめ

`.mode` が `check` か `run` のすべてのテストについて、次を行う（ADR 0224 の決定 4）。

ディレクトリのテストのうち `main.bnt` のないもの（`testdata/modules/c11-no-main` など）は、手順 3 の入口を決められないので、この確認から除き、除いた数に含める。

1. スクリプトの各 `.bnt`（ディレクトリのテストでは中のすべて）を `format_source`（`SourceKind::User`）で整形する。構文の誤り（`FormatError::Syntax`）のファイルを含むテストは、この確認から除く。`FormatError::Verify` は処理系の不具合として失敗させる。
2. 整形の結果をもう一度整形し、`changed` が偽であることを確かめる（冪等性）。
3. 整形の前と後のそれぞれで `pipeline::check_files`（ディレクトリのテストでは `main.bnt` を先頭の項目にして渡す。`check_files` は最初の項目を入口にする。`require_main` は真、`.options` の `--deny-warnings` に従う）を行い、診断のコードと文言の並びが同じであることを確かめる。位置は比べない（07-03）。
4. 除いた数と、性質の食い違いを、テストの失敗の一覧に区別して示す。

### fuzzing

`format` の対象は、入力を一つのファイルとして `format_source` にかけ、次を確かめる（07-03「fuzzing」）。

- 処理系の不具合（Rust の panic、`FormatError::Verify`）が起きない。
- 構文の誤りがなければ、整形の結果を整形しても変わらない。
- 構文の誤りがなければ、整形の前と後で `check_text` の診断のコードと文言の並びが同じである。

nightly の Rust と cargo-fuzz がない環境では、C15 と同じく、`fuzz-short.sh` が導入の案内で止まったことを報告し、`scripts/check.sh` の結果で判定する。

### D02 の確認で見つかった直し

D02 の確認で見つかった次の点を直す（`print.rs` の非公開の関数と、テストのファイルだけ）。

1. 文字列の字句ごとの後ろへの走査: `write_token` は、文字列の字句ごとに `line_start_of`・`out_line_start` で行の頭まで後ろへ走査する。このため 1 行に文字列が数万個あると、時間が二乗で増える。字下げの差（delta）の計算を、組（文字列の開始から終わりまでの字句の並び）のどれかの字句が `\n` を含むときだけ行う形にする。判定は字句の単位でなく組の単位で行う（`StrStart` に改行がなく、後の `StrMid` に改行がある組がある）。そのために、`string_groups` が字句の `text` も読む形にしてよい。
2. 線形探索: `next_code`・`top_ending_at`・`line_of_token` は線形に探すので、行の数×宣言の数の時間がかかり、長いコメントの並びで二乗になる。行ごとの「次のコードの行」「その行で終わる宣言」などの表を前もって作り、表を引く形にする。
3. 確かめ方: 時間を測るテストは置かない。1 行に文字列が 2 万個程度ある入力と、宣言が数千個ある入力を整形し、結果が冪等であることを確かめるテストを置いてよい（時間の上限は付けない）。直す前と後の整形の時間を計測し、完了の報告に書く。
4. テストの補い:
   - `places_comments` の「ファイルの終わりのコメントだけの行が段 0」の入力を、字下げしたもの（`    // end of file`）にする。
   - タブで字下げした複数行の文字列を深くする場合（加える文字は、閉じの `"""` の前の空白の最初の文字。06-03「複数行の文字列」）。
   - 複数行の文字列の中の CR LF。

## 受け入れテスト

`testdata/fmt/` に次のテストを置く。`// spec:` の行には 01-spec の節だけを書く。`tools/spec-coverage/spec_coverage.py` は見出しを `docs/archive/2026-10-09-design-first-release/01-spec/` からしか読まず、表にない章の印を誤りにするからである。確かめる 06-03 の節は、普通のコメント（例 `// 06-03「空の行」`）で示す。

ゴールデンの入力（`comments`・`blank_lines` など）には、次の二つの形を含めない。D02 の手順 2 の近似（凍結した `BlankBefore` が理由を持たないため。`print.rs` の `blank_rule`）により、06-03 と違う空の行の扱いになるからである。性質の確かめと fuzzing では、この形は冪等性を破らないので、扱いは要らない。

- 中身が空の構文の中のコメント
- 中身の最初の文が `with` の文で、その前にコメントだけの行がある場合

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
- 「D02 の確認で見つかった直し」の 1・2 の前後の整形の時間を完了の報告に書いている
- `scripts/fuzz-short.sh` の結果を完了の報告に書いている

## 難易度の理由

C10 の実行器に方式を足し、公開の関数を呼んで比べるだけである。判断が要るのは、一時ディレクトリのパスの置き換えと、性質の確かめから除く条件である。
