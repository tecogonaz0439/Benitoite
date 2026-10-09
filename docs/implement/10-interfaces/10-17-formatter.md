# フォーマッタ

本章は、フォーマッタ（`benitoite fmt`）の型と関数のシグネチャを定める。字句の位置ごとの役割の表、整形の結果の書き出し、整形後の検証、ファイルを書き換える手順、`test` と `fmt` が共有するコマンドラインの解釈である。設計書の対応する章は[フォーマッタ](../../design/06-tooling/06-03-formatter.md)と、[CLI](../../design/06-tooling/06-01-cli.md)の「`fmt` のコマンドライン（初回リリース版）」であり、判断の根拠は [ADR 0207](../../design/decisions/0207-fmt-command-line.md)・[ADR 0225](../../design/decisions/0225-formatter-without-configuration.md)〜[ADR 0228](../../design/decisions/0228-formatter-comments-blank-lines-and-characters.md)・[ADR 0247](../../design/decisions/0247-fmt-write-failure-exit-status.md) である。

- 置く作業: D00

フォーマッタは構文だけを扱い、名前解決と型検査を行わない（02-01「検査と実行の経路」）。入力は、[字句と構文木](10-03-syntax.md)の `lex`・`resolve_newlines`・`parse` の出力だけである（10-13「テストの実行器とゴールデンテストの実行器が使う口」）。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

本章のコードは D00 が置く。D00 は F18 の後に行うので、10-13 の `src/cli/tools.rs` は F18 が仮の中身を書いた状態にある。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/cli/tools.rs` | 末尾に足す（`append=`）。U4 のモジュールの宣言 | — |
| `src/cli/tools/args.rs` | 置く（`file=` と `sig=`）。`test` と `fmt` のコマンドラインの解釈 | D03 |
| `src/cli/tools/formatter/mod.rs` | 置く（`file=` と `sig=`） | D02（`format_source`）、D03（`run_fmt`・`replace_file`） |
| `src/cli/tools/formatter/roles.rs` | 置く（`file=` と `sig=`） | D01 |
| `src/cli/tools/formatter/print.rs` | 置く（`file=` と `sig=`） | D01（字句と空白と字下げ）、D02（コメント・空の行・行末と文字・複数行の文字列） |
| `src/cli/tools/formatter/verify.rs` | 置く（`sig=`） | D02 |

U4 のモジュールは、10-13 の `cli::tools` の子のモジュールとする。10-01 の `lib.rs` は C01 の凍結したファイルなので変えず、U4 のモジュールの宣言は、`src/cli/tools.rs` の末尾に `append=` で足す（[README](../README.md) の「インターフェースの読み方」）。

U4 のモジュールの宣言は、本章・[10-18](10-18-test-runner.md)・[10-19](10-19-skill-and-distribution.md) がそれぞれ自分のモジュールの分を足す。

```rust append=src/cli/tools.rs
pub mod args;
pub mod formatter;
```

## `test` と `fmt` のコマンドライン

`test` と `fmt` は、どちらも `[オプション] <パス>...` の形をとる（06-01「`test` のコマンドライン」「`fmt` のコマンドライン」「オプション」）。解釈を一か所にまとめるため、本章で凍結し、D03 が書く。`test` の作業（D11）もこの関数を使う。

- 10-13 の `Command::Tool` の `args` は、サブコマンドの名前の前のオプションと、名前の後の引数を、この順に並べたものである。`parse_path_args` はそのすべてを解釈する。
- `fmt` が受け付けるオプションは `--diagnostics` と `--check`、`test` が受け付けるオプションは `--diagnostics`・`--max-call-stack`・`--deny-warnings` である（ADR 0206・0207）。受け付けないオプション、値の誤ったオプション、同じオプションの二度の指定、パスがないことは、使い方の誤りとする。誤りの文は 10-13 の `cli::text`（`UNKNOWN_OPTION`・`BAD_VALUE`・`DUPLICATE_OPTION`）と、本章の `args::text` の型板で作る。
- `-` で始まる引数はすべてオプションとして読む。`-` で始まる名前のファイルは `./-x.bnt` と書く。
- `bnt_files` は、ディレクトリの下のすべての `.bnt` のファイルを、パスの辞書順（`Path` の比較）に並べて返す。シンボリックリンクは辿らず、対象にもしない。辿らないのは、リンクの輪で止まらなくなることと、同じファイルを二度扱うことを避けるためである。
- コマンドラインで直接与えたパスがシンボリックリンクのときは、リンクを辿ってリンクの先のファイルを整形し、`replace_file` は一時ファイルをリンクの先のファイルと同じディレクトリに作って、リンクの先のファイルを置き換える。リンクそのものは変えない（06-01「`fmt` のコマンドライン（初回リリース版）」、[ADR 0327](../../design/decisions/0327-fmt-symlink-and-process-attached-details.md)）。

```rust file=src/cli/tools/args.rs
//! `test` と `fmt` のコマンドラインの解釈（設計書 06-01「`test` のコマンドライン（初回リリース版）」
//! 「`fmt` のコマンドライン（初回リリース版）」「オプション」、ADR 0206・0207）。

use std::path::PathBuf;

use crate::cli::DiagFormat;

/// 解釈した `test`・`fmt` のコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct PathArgs {
    pub diagnostics: DiagFormat,
    /// `--max-call-stack` の値（バイト。`test` だけ）。指定がなければ `None`
    pub max_call_stack: Option<u64>,
    /// `--deny-warnings`（`test` だけ）
    pub deny_warnings: bool,
    /// `--check`（`fmt` だけ）
    pub check: bool,
    /// 与えた順のパス（一つ以上）
    pub paths: Vec<PathBuf>,
}

/// 使い方の誤りの文（ADR 0033）。ほかの誤りの文は 10-13 の `cli::text` を使う。
pub mod text {
    /// パスが一つもない
    pub const MISSING_PATH: &str = "missing path";
    /// そのサブコマンドが受け付けないオプション。`{name}` はオプション、`{command}` はサブコマンドの名前
    pub const OPTION_NOT_FOR_COMMAND: &str = "option `{name}` is not accepted by `{command}`";
}
```

```rust sig=src/cli/tools/args.rs
use std::ffi::OsString;
use std::path::Path;

use crate::cli::ToolCommand;

/// `benitoite test|fmt` の後の引数を解釈する。`tool` は `Test` か `Fmt`（`Skill` を渡したら使い方の誤りの文を返す）。
/// 使い方の誤りは、10-13 の `cli::text::USAGE_ERROR` の `{detail}` に埋める 1 行を返す。
pub fn parse_path_args(tool: ToolCommand, args: Vec<OsString>) -> Result<PathArgs, String>;

/// ディレクトリの下のすべての `.bnt` のファイルを、パスの辞書順に並べて返す（06-01「ディレクトリの指定」）。
/// シンボリックリンクは辿らず、返す並びにも含めない。読めないディレクトリがあれば、そのパスと理由を返す。
pub fn bnt_files(dir: &Path) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)>;
```

## 整形の流れ

一つのソースの整形は、次の順に行う（06-03「入力表現」「整形後の検証」）。

1. `lex` で字句と改行の印の列とコメントを作る。字句の誤りがあっても、手順 2 の構文解析まで進める。
2. `resolve_newlines` と `parse` で AST を作る。字句の誤りか構文の誤り（診断コードが `E01nn`・`E02nn` のもの）があれば、字句解析の診断と構文解析の診断をこの順につないで `FormatError::Syntax` を返す（06-03「構文の誤りがあるファイル」）。構文解析器が報告するそのほかの診断（属性の E0801・E0803・E0804、`resume` の位置の E0509 など）だけなら、整形を続け、それらの診断は捨てる（[ADR 0333](../../design/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 1）。`IdGen` はソースごとに新しく作る。
3. `roles::build_roles` で、AST と手順 1 の字句の列から、字句ごとの役割の表を作る。
4. `print::print` で、手順 1 の字句の列とコメントと役割の表から、整形の結果のバイト列を作る。
5. `verify::verify` で、整形の前と後のソースを比べる。食い違えば `FormatError::Verify` を返す。
6. 整形の結果と元のバイト列が同じかを `Formatted::changed` に入れて返す。

整形の結果は、AST を出力し直さずに、字句の字面を元のソースからそのまま写して作る（ADR 0226・0227）。字句の間の空白・字下げ・空の行・コメントの置き方だけを、役割の表と 06-03 の規則で決める。

```rust file=src/cli/tools/formatter/mod.rs
//! フォーマッタと `benitoite fmt`（設計書 06-03、06-01「`fmt` のコマンドライン（初回リリース版）」、
//! ADR 0207・0225〜0228・0247）。整形は字句と改行の印の列を辿って字句の字面を写し、その間に空白・字下げ・
//! 空の行・コメントを置く。AST は字句の役割を決めるためだけに使う。

pub mod print;
pub mod roles;
pub mod verify;

use crate::diag::Diagnostic;

/// 字下げの一段の空白の数（06-03「字下げ」、ADR 0225）。
pub const INDENT_WIDTH: usize = 2;

/// 整形の結果。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Formatted {
    pub text: Vec<u8>,
    /// 整形の結果が元のバイト列と違うか
    pub changed: bool,
}

/// 整形できなかった理由。
#[derive(Clone, PartialEq, Debug)]
pub enum FormatError {
    /// 字句か構文の誤り（06-03「構文の誤りがあるファイル」）。ファイルを書き換えずに診断を書く
    Syntax(Vec<Diagnostic>),
    /// 整形後の検証の失敗（06-03「整形後の検証」）。処理系の不具合であり、文字列は調べるための説明
    Verify(String),
}

/// `fmt` が書く文と、報告の型板に埋める語（ADR 0033）。
pub mod text {
    /// `--check` で、整形で変わるファイル一つの行。`{path}` は表示名
    pub const WOULD_REFORMAT: &str = "would reformat {path}";
    /// 処理系の不具合の報告（10-13 の `internal_diagnostic`）の段の名前
    pub const STAGE_FMT: &str = "fmt";
}
```

```rust sig=src/cli/tools/formatter/mod.rs
use std::path::Path;

use crate::base::{FileId, SourceKind};
use crate::cli::CliEnv;
use super::args::PathArgs;

/// 一つのソースを整形する（本章「整形の流れ」）。`kind` が `SourceKind::Prelude` なら、標準ライブラリのソースの構文で解析する
/// （06-03「標準ライブラリのソース」）。`file` は診断の span に使うファイル ID である。
pub fn format_source(file: FileId, kind: SourceKind, text: &[u8]) -> Result<Formatted, FormatError>;

/// `benitoite fmt` を実行し、終了状態を返す（本章「`fmt` の実行」）。
pub fn run_fmt(args: PathArgs, env: CliEnv) -> u8;

/// 整形の結果でファイルを置き換える（06-01「`fmt` のコマンドライン」、ADR 0207・0247）。同じディレクトリの一時ファイルに書き、
/// 元のファイルの許可の設定を写してから、名前の変更で置き換える。失敗したら元のファイルを変えずに残し、一時ファイルを消して、
/// E0125 の診断を返す（`display` は診断に書く表示名）。
pub fn replace_file(path: &Path, display: &str, content: &[u8]) -> Result<(), Box<Diagnostic>>;
```

## 役割の表

役割の表は、`lex` が返した字句の列（改行の印 `LineBreak` と `Eof` を含む）と同じ添字で、字句ごとの役割を持つ（06-03「入力表現」）。書き手の改行の位置は保つ（ADR 0226）ので、行の区切りは整形の前後で変わらない。したがって、ある字句が行の最初の字句になるかは元のソースで決まり、D01 は、行の最初の字句の段を、06-03「字下げ」の規則 1〜4 で元のソースの行の並びから決めてよい。

| 欄 | 内容 | 使う規則 |
|---|---|---|
| `level` | 行の最初の字句のときの段。行の最初でない字句では使わない | 06-03「字下げ」の規則 1〜4 |
| `space_before` | 同じ行の直前の字句との間に空白を一つ置くか | 06-03「字句の間の空白」の表と、その後の段落 |
| `blank_before` | 行の最初の字句のときの、その前の空の行の扱い | 06-03「空の行」のうち、トップレベルの宣言の間を除く規則 |
| `inner_level` | 閉じの字句（`end`・`)`・`]`）のとき、閉じる構文の中の行の段 | 06-03「コメント」（閉じの字句の前のコメントだけの行の段） |

トップレベルの宣言の間の空の行（06-03「空の行」の最初の二つの規則）は、宣言の範囲（`top`）から決める。範囲は、属性を含めた宣言の最初の字句から最後の字句までである。ドキュメントコメントとコメントだけの行は字句でないので範囲に含めず、`print` が行の隣り合いで扱う。

構文の誤りを含む AST は、役割を決めるのに使えない（06-03「構文の誤りがあるファイル」）。`build_roles` は、誤りのない AST だけを受け取る。

```rust file=src/cli/tools/formatter/roles.rs
//! 字句の位置ごとの役割の表（設計書 06-03「入力表現」「字句の間の空白」「字下げ」「空の行」）。
//! 字下げと空白の規則に要る構文の情報（開き・区切り・閉じの字句、並びの要素、呼び出しの括弧、単項の `-`）は
//! 字句の列だけでは決まらないので、AST を辿って字句ごとに決める。

/// 行の最初の字句のときの、その前の空の行の扱い（06-03「空の行」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum BlankBefore {
    /// 書き手の空の行を一つまでにまとめて保つ（ブロックの中と括弧の中、`case` の前）
    #[default]
    KeepOne,
    /// 空の行を除く（構文の中身の最初の行、閉じの字句・`else`・節の並びを始める `with` で始まる行、
    /// 属性の行と宣言の間、`///` の行と属性の間）
    Remove,
}

/// 字句一つの役割。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct TokenRole {
    /// 行の最初の字句のときの段（字下げの空白は `level * INDENT_WIDTH`）
    pub level: u32,
    /// 同じ行の直前の字句との間に空白を一つ置くか。行の最初の字句では使わない
    pub space_before: bool,
    /// 行の最初の字句のときの、その前の空の行の扱い
    pub blank_before: BlankBefore,
    /// 閉じの字句のとき、閉じる構文の中の行の段。ほかの字句では `None`
    pub inner_level: Option<u32>,
}

/// トップレベルの宣言の種類（06-03「空の行」の、宣言の間の空の行の規則）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TopKind {
    Import,
    Const,
    Other,
}

/// トップレベルの宣言一つの範囲。`first`・`last` は字句の列の添字である。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TopRange {
    /// 属性を含めた最初の字句
    pub first: usize,
    /// 最後の字句（`end` のある宣言は `end` の後の語）
    pub last: usize,
    pub kind: TopKind,
}

/// 役割の表。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct RoleTable {
    /// `lex` の字句の列と同じ添字。`LineBreak` と `Eof` の項目は既定の値のまま使わない
    pub roles: Vec<TokenRole>,
    /// トップレベルの宣言（import の宣言を含む）の範囲。ソースの順
    pub top: Vec<TopRange>,
}
```

```rust sig=src/cli/tools/formatter/roles.rs
use crate::syntax::ast::Module;
use crate::syntax::token::Token;

/// AST と `lex` の字句の列から役割の表を作る（本章「役割の表」）。`module` は誤りのノードを含まない。
/// `text` はソースのバイト列で、複数行の文字列の字句の行を数えるために読む。
pub fn build_roles(module: &Module, tokens: &[Token], text: &[u8]) -> RoleTable;
```

## 書き出し

`print` は、字句の列を先頭から辿り、字句の字面（元のソースの span の範囲）を写し、その間に役割の表で決めた空白と字下げを置く。D01 と D02 が次のように分けて書く。

| 作業 | 受け持つ規則（06-03） |
|---|---|
| D01 | 「字句の間の空白」「字下げ」。コメント・空の行・複数行の文字列を含まない入力で、正規形を作る |
| D02 | 「コメント」「空の行」「行末と文字」「複数行の文字列」。シェバンの行、先頭の U+FEFF、CR LF、タブ、行末の空白、ファイルの終わりの改行 |

D01 は、コメント・空の行・複数行の文字列を含む入力を、中身を捨てずにそのまま写す形で通しておき、D02 が規則どおりに書き換える。D01 の単体テストの入力は、それらを含まないものに限る。

```rust file=src/cli/tools/formatter/print.rs
//! 整形の結果の書き出し（設計書 06-03「字句の間の空白」「字下げ」「コメント」「空の行」「行末と文字」
//! 「複数行の文字列」）。字句の字面は元のソースから写し、AST を出力し直さない（ADR 0226・0227）。

use super::roles::RoleTable;
use crate::syntax::token::{Comment, Token};

/// 書き出しの入力。
#[derive(Clone, Copy, Debug)]
pub struct PrintInput<'a> {
    /// 元のソースのバイト列
    pub text: &'a [u8],
    /// `lex` の字句と改行の印の列
    pub tokens: &'a [Token],
    /// `lex` のコメントの一覧（ソースの順）
    pub comments: &'a [Comment],
    pub roles: &'a RoleTable,
}
```

```rust sig=src/cli/tools/formatter/print.rs
/// 整形の結果のバイト列を作る（本章「書き出し」）。
pub fn print(input: &PrintInput<'_>) -> Vec<u8>;
```

## 整形後の検証

`verify` は、整形の前と後のソースをそれぞれ字句解析し、06-03「整形後の検証」の比較を行う。比べるのは、改行の判定の後の字句の列（NEWLINE を含む。種類と、文字列の字句では値、NEWLINE と `Eof` では種類だけ、ほかの字句では字面。`Eof` の直前の NEWLINE は比べない）と、コメントの並び（種類と、行末の空白を除いた本文）である。あわせて、整形の後のソースを `kind` の構文で解析し、字句の誤りと構文の誤り（`E01nn`・`E02nn`）がないことを確かめる。そのほかの診断は、整形の前のソースにもあったものなので、検証の失敗にしない（[ADR 0333](../../design/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 1）。

検証の関数は、整形の前のソースを受け取り直して字句解析し直す。字句の字面を比べるには両方のソースのバイト列が要り、`format_source` の途中の値に依存しない形にすると、単体テストで字句を変えた出力とコメントを落とした出力を与えやすいからである（07-03「ほかの章が求めるテスト（初回リリース版）」）。

```rust sig=src/cli/tools/formatter/verify.rs
//! 整形後の検証（設計書 06-03「整形後の検証」、ADR 0227）。

use crate::base::SourceKind;

/// 整形の前のソース `before` と後のソース `after` を比べる。一致して `after` に構文の誤りがなければ `Ok(())`、
/// そうでなければ、最初に見つけた食い違い（字句の添字と両方の字句、またはコメント、または構文の誤りの文言）を
/// 説明する文字列を返す。
pub fn verify(before: &[u8], after: &[u8], kind: SourceKind) -> Result<(), String>;
```

## `fmt` の実行

`run_fmt` は、06-01「`fmt` のコマンドライン（初回リリース版）」の規則で、与えたパスの順にファイルを整形する。ディレクトリは `bnt_files` で展開する。表示名は、ファイルを与えたときはそのパス、ディレクトリの下のファイルはディレクトリのパスに相対パスを続けたものとする（02-02「ソースとファイル ID」と同じ組み立て方）。

| 場合 | 振る舞い | 終了状態への寄与（06-01 の表） |
|---|---|---|
| ファイルを読めない、ディレクトリを読めない | E0101 の診断を書く。ほかのファイルは続ける（読めないディレクトリでは、ほかの引数のパスを続ける。そのディレクトリの下の残りのファイルは扱えなくてよい） | 2 |
| 字句か構文の誤り | `FormatError::Syntax` の診断を書き、書き換えない。ほかのファイルは続ける | 2 |
| 整形後の検証の失敗 | 書き換えず、10-13 の `runtime::report::internal_diagnostic`（段は `text::STAGE_FMT`、スレッドは `FaultThread::Stage`、`message` は `FormatError::Verify` の説明）を書く。ほかのファイルは続ける | 3 |
| 整形の処理の panic | `runtime::panic::catch` で捕らえ、同じく処理系の不具合として書く。ほかのファイルは続ける | 3 |
| 変わらない | 何も書かない | 0 |
| 変わる（`--check` なし） | `replace_file` で置き換える。失敗したら E0125 の診断を書く | 置き換えの失敗は 2 |
| 変わる（`--check`） | `text::WOULD_REFORMAT` の行を標準エラー出力に書く。書き換えない | 1 |

- 診断は、`--diagnostics` の形式で `env.stderr` に一件ずつ書く。文章の形式は 10-02 の `render_one_text`、JSON の形式は `render_json_line` に改行を続けたものである。検査の件数の行（`render_check_text`）は書かない。`fmt` は `run`・`check`・`test` の件数の行の動詞を持たないからである。
- 診断の位置のために、ファイルごとに `SourceTable` を一つ作り、そのファイルだけを入れる。
- `fmt` は標準出力に何も書かない。中断の要求を扱わない（06-01）。
- 終了状態は、06-01 の表の上の行を優先する（3、2、1、0 の順）。3 > 2 > 1 > 0 なので、当たる場合の寄与の最大の値と同じである。

一時ファイルは、元のファイルと同じディレクトリに、名前 `.<元の名前>.fmt-<プロセスの番号>` で作る。元のファイルの許可の設定（Unix のモード）を一時ファイルに写してから名前を変える。シェバンで実行するスクリプトの実行の許可を、整形で失わないためである。一時ファイルを消せなかったときは、E0125 の注記 `temp_left` を同じ診断に加える（ADR 0247）。

## 診断コード

`fmt` の書き換えの失敗（ADR 0247）に、E01 の区分の続きの番号 E0125 を割り当て、[10-02](10-02-diagnostics.md) の表と `codes.rs` に加えた（10-02「番号の付け方」の「本章の後に加えるコード」）。出す作業は D03 である。

| コード | 誤り | 出す作業 |
|---|---|---|
| E0125 | `fmt` が整形の結果でファイルを置き換えられない（一時ファイルを作れない・書けない、名前を変えられない）。`{path}` は表示名、`{reason}` は OS の誤りの文。一時ファイルを消せなかったときは注記 `temp_left`（`{temp}` は一時ファイルのパス） | D03 |

ファイルとディレクトリを読めないときは、E0101 を使う（`{reason}` に OS の誤りの文）。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| D00 | 本章の `file=`・`append=` と、`sig=` の `todo!()` の仮置きを置く |
| D01 | `roles::build_roles`、`print::print` の空白と字下げ |
| D02 | `print::print` のコメント・空の行・行末と文字・複数行の文字列、`verify::verify`、`format_source` |
| D03 | `args::parse_path_args`・`bnt_files`、`run_fmt`・`replace_file`、`cli::tools::run_tool` の `fmt` の振り分け |
| D04 | 本章の関数を使うゴールデンテストの方式と fuzzing の対象 |

## 未定のこと

- 06-03 は、行の長さの上限と行の結合を持たない（ADR 0226）。長い行の扱いは、初回リリース版の後の見直しに回す。
