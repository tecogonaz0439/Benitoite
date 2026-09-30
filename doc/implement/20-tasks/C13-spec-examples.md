# C13 言語仕様の例を処理系で検査する

- 依存する作業: [F18](F18-pipeline-cli.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/C13-spec-examples

## 目的

言語仕様（`doc/design/01-spec/`）と付録 08-04（[関数型言語の構文の比較](../../design/08-appendix/08-04-fp-syntax-comparison.md)）に載せた Benitoite のコードの例が、初回リリース版の文法で読め、局所の束縛の規則を守っていることを、処理系の構文解析器と名前解決で確かめる（[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「言語仕様の例の検査」）。07-03 は、初回リリース版の構文解析器を実装するときに、言語仕様と付録の両方の例を処理系で読む形に移し、両方を読めるまで Python の道具（`tools/grammar-check/`）を消さないとした。本作業はその移行を行う。

最小実行版の同じ検査（`tests/spec_examples.rs`）は、`legacy` の構文解析器で最小実行版の範囲の例だけを読んでいた。本作業は、このファイルを初回リリース版の検査に置き換える。

## 読む設計書の節

- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md): 「言語仕様の例の検査」「実装の規約と静的な検査」の検査の表
- [関数型言語の構文の比較](../../design/08-appendix/08-04-fp-syntax-comparison.md): Benitoite の例（`text` のコードブロック）がある箇所
- [構文](../../design/01-spec/01-02-syntax.md): 「EBNF の表記」「初回リリース版の文法の全体」
- [名前・スコープ・モジュール](../../design/01-spec/01-03-names-modules.md): 「シャドーイング」（[ADR 0255](../../design/decisions/0255-bind-and-shadow.md)、[ADR 0123](../../design/decisions/0123-top-level-constants.md)）
- `tools/grammar-check/README.md` と `grammar_check.py`・`scope_check.py`（例の取り出し方、`EXPECTED`、`is_source`、試す開始記号、確かめる局所の束縛の規則）
- インターフェース: [10-03](../10-interfaces/10-03-syntax.md) の `lex`・`resolve_newlines`・`parse`、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の `pipeline::check_text`・`CheckOptions`、[10-02](../10-interfaces/10-02-diagnostics.md) の E0334〜E0338

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/tests/spec_examples.rs` | 初回リリース版の検査に置き換える。先頭に、テストのコードに許す lint の `#![allow(...)]` を書く |
| `tools/grammar-check/` | 消す |
| `scripts/check.sh` | 言語仕様の例の二つの行（`language examples` と、C00 が加えた `language examples (appendix)`）を消す（検査は `cargo test` の行で走る）。冒頭のコメントの検査の一覧も直す |
| `AGENTS.md` | 「ディレクトリ構成」の `tools/grammar-check/` の行を消し、`crates/benitoite/` の行か「テストの運用」に、言語仕様の例の検査が `tests/spec_examples.rs` にあり、構文の章や例を変えたら `cargo test --test spec_examples` を実行することを書く |
| `.claude/skills/test-audit/SKILL.md` | 持ち主の境界の 3 の括弧書き（`tools/grammar-check/`）を `tests/spec_examples.rs` に改める。ほかは変えない（07-03 と同じ内容を保つ。[ADR 0212](../../design/decisions/0212-test-owner-boundaries-in-testing-chapter.md)） |
| `tools/syntax-measure/README.md` | `grammar-check` へのリンクを、消したことと、消す前のコミットを示す文に改める（測定の道具は grammar-check のファイルを読まないので、動作は変わらない） |

`tests/spec_examples.rs` は `legacy` を通して動くテストである。本作業は、07-03 が定めたこのファイルの名前を保つために、ファイルを初回リリース版の検査に置き換える（00-01「移行の間の配置」の表が、このファイルを変える作業に C13 を挙げている）。

## 手順の要点

### 例の取り出し

`grammar_check.py` と同じ規則で取り出す。

- 対象は `env!("CARGO_MANIFEST_DIR")` から `../../doc/design/01-spec/` の `*.md` を名前の順に読み、続けて `../../doc/design/08-appendix/08-04-fp-syntax-comparison.md` を読む。例は `` ```text `` の行から次の `` ``` `` の行までである。
- EBNF の規則のブロック（行頭の大文字の名前、省略できる `(X)`、空白、`=`、空白で始まる行を含み、最後が `.` で終わるもの）と、文字列リテラルとコメントを除いて ASCII でない文字が残るブロック（数式）は除く（`is_source` と同じ）。正規表現のクレートは使わず、行ごとの文字の検査で書く。
- 最小実行版の範囲と初回リリース版の範囲を分けない。すべての例を対象にする。
- 言語仕様の例は、非公式のモジュールも標準に加えた後の名前で import を書く（`import Benitoite.IO.Console`。01-03「標準ライブラリの名前空間と prelude（初回リリース版）」、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。読む前に、行頭が `import Benitoite.` の行のうち、名前の残りの段が `prelude::STDLIB` の `unofficial` が真の項目の `path` と一致するものを、`import Benitoite.Unofficial.` の形に置き換える（07-03「言語仕様の例の検査」）。置き換えないと、読み込みの段の誤り（E0321）で名前解決に進まず、局所の束縛の規則を確かめられない。
- 文法で読めなくて正しい例は、テストの中の定数の表（章のファイルの名前と、例の最初の空でない行の組）で除く。初めの表は `grammar_check.py` の `EXPECTED` のうち、いまの章の例に当たる 7 個と同じにする（2026-09-30 の時点で `EXPECTED` は 8 個あるが、01-01 の「予約語の一覧」の項は、01-01 がすべてキーワードとしたので当たる例がない。表に入れない）。付録 08-04 には除く例がない。表の先頭のコメントに、例を足したときにこの表を直すことを書く（Python の道具は消すので、この表が唯一の一覧になる）。

### 読み方

`grammar_check.py` の `check` は、例をプログラム・文の並び・型・パターンの順に試す。処理系の構文解析器はファイル一つのモジュールだけを読むので、同じ四つを次のように包んで試し、どれかが字句と構文の誤りなしに読めれば読めたとする。包み方は本プランで決めたものであり、`LineList` が空を許すこと（01-02「初回リリース版の文法の全体」）を使う。

| 試す形 | 包み方 |
|---|---|
| プログラム | そのまま |
| 文の並び | `function exampleWrapper() -> Unit` の行、例、`end function` の行 |
| 型 | `function exampleWrapper(x: ` 例 `) -> Unit` の行、`end function` の行（例が 1 行のときだけ） |
| パターン | `function exampleWrapper() -> Unit` の行、`match () with` の行、`case ` 例 ` -> ()` の行、`end match` の行、`end function` の行（例が 1 行のときだけ） |

各形について、`lex`（ファイル ID は `FileId(0)`）、`resolve_newlines`、`parse`（`SourceKind::User`）を順に呼ぶ。

### 局所の束縛の規則

プログラムか文の並びとして読めた例は、局所の束縛の規則（`scope_check.py` が確かめる規則）も確かめる。

- 包んだ形のソースを `pipeline::check_text`（`require_main` と `deny_warnings` は偽）で検査し、診断のうち局所の束縛の規則のコード（E0334〜E0338 と、分岐のパターンの変数に定数の名前を付けた誤り。コードは 10-02 で確かめる）だけを見る。例の中の名前は仮のものが多いので、ほかの名前解決と型検査の診断は見ない。
- 文の並びの断片では、断片の外の束縛が分からないので、E0335（`shadow` した名前が見えていない）を誤りにしない（`scope_check.py` の `fragment`）。
- 名前解決は、名前の誤りの後も続けて局所の束縛の規則を確かめる（F06）。そうでない場合があって、Python の道具が見つけた誤りを処理系が見つけられないと分かったら、報告する。

### 失敗の報告

読めない例と局所の束縛の規則に反する例があれば、すべての例を試した後にテストを失敗させる。失敗の文には、例ごとに章のファイル名と例の先頭の行番号、プログラムとして読んだときの最初の診断のコードと文言を並べる。最後に、読めた例・除いた例・読めなかった例の数を示す。

初めて通したときに読めない例が見つかったら、構文解析器の誤りか、例の誤りかを調べる。構文解析器の誤りなら、F02〜F04 の側の不具合として報告する。例の誤り（設計書の側）なら、作業を止めて報告する（設計書は本作業で変えない）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 現在の 01-spec の全章と付録 08-04 | 読めなかった例と規則に反する例が 0 個でテストが通る |
| Python の道具との一致 | 道具を消す前に、`python3 tools/grammar-check/grammar_check.py` と `python3 tools/grammar-check/grammar_check.py doc/design/08-appendix/08-04-fp-syntax-comparison.md` の `ok` と `expected-fail` と `skipped` の数と、この検査の数を、01-spec と付録に分けて比べ、差を完了の報告に書く（2026-09-30 の時点で、01-spec は `ok 62, expected-fail 7, skipped 38, fail 0`、08-04 は `ok 15, expected-fail 0, skipped 0, fail 0`） |
| 壊した例 | 01-02「例」のプログラムから `end function` を一行消したコピーを、例を取り出した後の判定の関数に与えると、読めない例として数えられる（テストで確かめる） |
| 局所の束縛 | `bind x <- 1` の後に `bind x <- 2` を書いた文の並びが規則に反する例として数えられ、`shadow y <- 1` だけの文の並びが断片として通る（テストで確かめる） |
| 道具の削除 | 01-spec と付録 08-04 の両方を処理系で読めたうえで、`tools/grammar-check/` がなく、`scripts/check.sh` が通る |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストか確認の記録がある
- 除いた例の表が、消す前の `grammar_check.py` の `EXPECTED` のうち当たる例のあるものと一致している

## 難易度の理由

処理系の関数を順に呼ぶだけで、アルゴリズムの難しさはない。Markdown からの例の取り出しと除く規則を Python の道具と揃える細かさと、局所の束縛の規則を名前解決の診断から取り出す規則が手間の中心である。読めない例が見つかったときに、構文解析器と設計書のどちらの誤りかを見分ける判断が要る。
