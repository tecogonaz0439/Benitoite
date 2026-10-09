# 同梱の Agent Skill と配布

本章は、同梱の Agent Skill と配布の型と関数のシグネチャ、ファイルの置き場所を定める。`benitoite skill install`・`uninstall`、埋め込む Skill のファイル、Skill の参照の文書を生成する道具と、生成物が古くないことを確かめるテスト、`benitoite --licenses` と第三者のライセンスの表示の埋め込み、リリースのスクリプト `scripts/release.sh` の段と入出力である。設計書の対応する章は [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md)、[配布形態](../../design/05-platform/05-01-distribution.md)、[CLI](../../design/06-tooling/06-01-cli.md)の「`skill` のコマンドライン（初回リリース版）」「コマンドラインの形」であり、判断の根拠は [ADR 0229](../../design/decisions/0229-bundled-skill-contents-and-japanese-translations.md)〜[ADR 0235](../../design/decisions/0235-third-party-licenses-generated-and-shown-by-option.md)・[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)・[ADR 0288](../../design/decisions/0288-skill-documents-generated-by-tool-and-committed.md) である。

- 置く作業: D00

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは、見出しでは処理系のクレート `crates/benitoite/` からの相対パス、本文の表の `scripts/`・`docs/` などはリポジトリの根からの相対パスである。

## 置く作業と既存のファイル

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/cli/tools.rs` | 末尾に足す（`append=`）。モジュールの宣言 | — |
| `src/cli/tools/skill/mod.rs` | 置く（`file=` と `sig=`） | D22（導入と削除）、D20（`files`） |
| `src/cli/tools/skill/generate.rs` | 置く（`sig=`） | D20 |
| `src/cli/tools/skill/bundle.rs` | 道具が中身のないモジュールとして作る。生成の道具が書く | D20 |
| `src/cli/tools/licenses.rs` | 置く（`file=` と `sig=`） | D30 |

```rust append=src/cli/tools.rs
pub mod licenses;
pub mod skill;
```

## Skill のファイルの置き場所

同梱の Agent Skill のファイルは、処理系のクレートの `skill/` の下に置き、実行ファイルに埋め込む（ADR 0230）。クレートの中に置くのは、`cargo install --locked --path crates/benitoite`（05-01「ソースからのビルド」）でも同じファイルを埋め込むためである。

| 置き場所（`crates/benitoite/` から） | Skill の中のパス | 内容 | 作り方 |
|---|---|---|---|
| `skill/SKILL.md` | `SKILL.md` | 作業の手順、主な言語の規則の要約、実行の前の確認、参照の文書の一覧、版の確認（06-06） | 手で書く（D21） |
| `skill/references/grammar.md` | `references/grammar.md` | 01-02「初回リリース版の文法の全体」の EBNF。日本語の注釈 `(* … *)` を除く | 生成（D20） |
| `skill/references/diagnostics.md` | `references/diagnostics.md` | 診断コードごとの文言の型板と説明（10-02 の `codes::ALL` の順。廃止したコードを含めない） | 生成（D20） |
| `skill/references/stdlib/index.md` | 同じ | 標準ライブラリのモジュールの一覧（モジュールの名前、状態、取り込みの名前、一行の説明） | 生成（D20） |
| `skill/references/stdlib/<モジュール>.md` | 同じ | モジュール一つのリファレンス。名前は `Benitoite.` を除いた段をドットでつないだもの（`List.md`、`IO.Console.md`、`Network.Http.md`） | 生成（D20） |
| `skill/references/idioms.md` | 同じ | イディオム集 | 手で書く（D21） |
| `skill/references/common-mistakes.md` | 同じ | よくある誤り集 | 手で書く（D21） |
| `skill/references/language-comparison.md` | 同じ | 既知の言語との対応表 | 手で書く（D21） |
| リポジトリの根の `LICENSE-MIT`・`LICENSE-APACHE` | `LICENSE-MIT`・`LICENSE-APACHE` | Skill のライセンス文（06-06「同梱の Agent Skill の構成」の「ライセンス文」） | リポジトリのライセンス文を埋め込む（D30 が置く） |

- 標準ライブラリのリファレンスは、モジュールごとに一つのファイルとする（[README](../README.md) の「U3・U4 で決めたこと」の 15）。各ファイルの先頭に、モジュールの状態と取り込みの名前を書く（ADR 0286 の決定 8）。標準で prelude のモジュールは「import なしで使える」、標準で prelude でないモジュールは `import Benitoite.X`、非公式のモジュールは `import Benitoite.Unofficial.X.Y` を示す。
- モジュールのリファレンスは、10-14 の `STDLIB` の各ソースを `SourceKind::Prelude` で構文解析し、モジュールの `//!` の説明と、`public` を付けた宣言をソースの順に並べて作る。宣言ごとに、宣言の頭（関数は本体を除いた部分、型・エフェクト・型クラスは構成子・操作・メソッドの宣言を含む部分。`@builtin` の属性を除く）をソースのとおりにコードブロックへ写し、`///` の説明を続ける。組み込みの型（10-05 の組み込みの型の表）は、そのモジュールの説明の中で名前を挙げる。
- `SKILL.md` の前付けは、`name: benitoite`、`description`、`license: MIT OR Apache-2.0` と、`metadata` の欄 `benitoite-version` を持つ（06-06「同梱の Agent Skill の構成」）。版の値は、リポジトリのファイルでは型板 `{{benitoite-version}}` とし、`skill install` が書き出すときに処理系の版（`env!("CARGO_PKG_VERSION")`）で置き換える。生成物と手で書く文書をリポジトリに置いたまま、版の値を処理系と一致させるためである。
- 日本語の訳は Skill のディレクトリの外（`docs/ja/`）に置き、埋め込まない（ADR 0229 の決定 7）。

## 生成の道具と、生成物が古くないことのテスト

生成できる参照の文書（文法、標準ライブラリのリファレンス、診断コードの説明）は、処理系のクレートの関数で作り、生成物をリポジトリに置く。ビルドは埋め込むだけにする（ADR 0288 の決定 1）。

| もの | 置き場所 | 作業 |
|---|---|---|
| 生成の関数 | `src/cli/tools/skill/generate.rs`（本章の `sig=`） | D20 |
| 生成の道具 | `examples/gen_skill.rs`。`cargo run -p benitoite --example gen_skill` で、`skill/references/` の生成物と `src/cli/tools/skill/bundle.rs` を書き直す。構文の章は、リポジトリの `docs/design/01-spec/01-02-syntax.md` をクレートのディレクトリ（`env!("CARGO_MANIFEST_DIR")`）からの相対パスで読む | D20 |
| 埋め込みの一覧 | `src/cli/tools/skill/bundle.rs`。生成の道具が書く。Skill のすべてのファイルを `include_str!` で並べた定数 `FILES: &[SkillFile]` を持つ | D20 |
| 古くないことのテスト | `tests/skill_docs.rs`。生成の関数を呼び、`skill/references/` の生成物と `bundle.rs` のそれぞれと一致することを確かめる。`skill/references/stdlib/` に、生成しないファイルが残っていないことも確かめる。一致しないときは、生成の道具を実行するよう示す文で失敗させる（ADR 0288 の決定 2） | D20 |

開発の道具を処理系の実行ファイルに入れず、例（`examples/`）とする。利用者向けのサブコマンドを増やさないためと、テストと同じ関数を呼べば済むからである。構文の章を読むのは生成の道具とテストだけであり、ビルドは読まない（05-01「ソースからのビルド」）。

生成物のもとは、構文の章、標準ライブラリのソース（10-14・10-15・10-18）、診断の表（10-02）である。これらを変える作業は、生成の道具を実行し、生成物の変更を同じ変更に含める（ADR 0288 の帰結）。含め忘れは `scripts/check.sh` の中の上のテストが見つける。

```rust sig=src/cli/tools/skill/generate.rs needs=10-02,10-03,10-04,10-14
//! 同梱の Agent Skill の参照の文書の生成（設計書 06-06「同梱の Agent Skill の構成」、ADR 0229・0286・0288）。
//! 生成の道具（`examples/gen_skill.rs`）と、生成物が古くないことのテスト（`tests/skill_docs.rs`）が呼ぶ。

/// 生成する文書一つ。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct GeneratedFile {
    /// Skill の中のパス（`references/grammar.md` など）
    pub path: String,
    pub text: String,
}

/// 生成できる参照の文書をすべて作る。`syntax_chapter` は設計書の構文の章（01-02）の Markdown の全文である。
/// 章から文法の節のコードブロックを見つけられないとき、標準ライブラリのソースを構文解析できないときは、理由を返す。
pub fn generate_references(syntax_chapter: &str) -> Result<Vec<GeneratedFile>, String>;

/// 埋め込みの一覧 `bundle.rs` の Rust のソースを作る。`paths` は Skill の中のパスの並び（手で書く文書と生成物と
/// ライセンス文）で、この順に `FILES` に並べる。書く前に rustfmt の書き方に揃えた文字列を返す。
pub fn bundle_source(paths: &[String]) -> String;
```

## `skill install`・`uninstall`

`skill` のコマンドラインと振る舞いは 06-01「`skill` のコマンドライン（初回リリース版）」と 06-06「Skill の導入（初回リリース版）」のとおりである（ADR 0230）。本章は、次の細部を決める。

- 引数は `install` か `uninstall` の一つと、`--user`・`--project`・`--agent <名前>`（`--agent=<名前>` とも書ける）である。`--user` と `--project` を両方書く、同じものを二度書く、知らない `--agent` の名前、知らないオプション、`install`・`uninstall` がないことは、使い方の誤り（終了状態 2）とする。`test`・`fmt` のオプション（`--diagnostics` など）は受け付けない。
- 書き出す先は、`--user` なら利用者のホームのディレクトリ、`--project` なら `CliEnv::working_directory` を基準にする。ホームのディレクトリは、`run_tool` が環境変数 `HOME` から求めて `run_skill` に渡す。テストが環境変数を変えずに書き出す先を与えられるようにするためである（Rust 2024 では環境変数の書き換えが `unsafe` になり、`unsafe` は `runtime::heap` の外に書けない。00-01「`unsafe` を書いてよいモジュール」）。`--user` でホームのディレクトリが分からないときは、`text::NO_HOME` を書いて終了状態 1 で終える。
- 書き出す先の親のディレクトリ（`~/.claude/skills` など）がなければ作る。
- `install` は、同じ親のディレクトリに一時ディレクトリ `.benitoite.install-<プロセスの番号>` を作ってすべてのファイルを書き、次のどちらかを行う。書き出す先がなければ、一時ディレクトリの名前を `benitoite` に変える。書き出す先が `install` の書き出したもの（`SKILL.md` の前付けの `metadata` に `benitoite-version` の欄があるもの）なら、書き出す先の名前を `.benitoite.old-<プロセスの番号>` に変え、一時ディレクトリの名前を `benitoite` に変え、古いものを消す。一時ディレクトリの名前を `benitoite` に変える前の段（ファイルの書き出し、二つの名前の変更）で失敗したら、書き出す先を元の状態に戻し、一時ディレクトリを消し、理由を書いて終了状態 1 とする。名前を変えた後は置き換えが済んだものとし、古いものを消しきれなければ、新しいものを残し、消せなかった古いもののパスを `text::REMOVE_FAILED` の形で書いて終了状態 1 とする（古いものの名残が残ることを許す）。
- 書き出す先が `install` の書き出したものでなければ、書き出さずに `text::NOT_OURS` を書き、終了状態 1 とする。
- `uninstall` は、書き出す先がなければ何もしない（終了状態 0）。`install` の書き出したものなら消し、そうでなければ `text::NOT_OURS` を書いて終了状態 1 とする。
- 書き出した先・消した先のパスを、`text::INSTALLED`・`text::REMOVED` の形で `env.stdout` に一行ずつ書く。誤りの文は `env.stderr` に書く。
- 書き出す先が同じエージェント（`codex` と `opencode`）は一度だけ扱う。一つの書き出す先の失敗の後も、残りの書き出す先を続け、最後に終了状態を決める（失敗があれば 1）。

```rust file=src/cli/tools/skill/mod.rs
//! 同梱の Agent Skill の埋め込みと、`benitoite skill install`・`uninstall`（設計書 06-06「同梱の Agent Skill の構成」
//! 「Skill の導入（初回リリース版）」、06-01「`skill` のコマンドライン（初回リリース版）」、ADR 0229・0230・0288）。

pub mod bundle;
pub mod generate;

/// Skill の名前（書き出す先のディレクトリの名前。06-06、ADR 0241）。
pub const SKILL_NAME: &str = "benitoite";
/// `SKILL.md` の前付けの `metadata` の、処理系の版の欄の名前。この欄があれば `install` が書き出したものとみなす
pub const VERSION_KEY: &str = "benitoite-version";
/// リポジトリの `SKILL.md` の版の型板。`install` が処理系の版で置き換える
pub const VERSION_PLACEHOLDER: &str = "{{benitoite-version}}";

/// 埋め込んだファイル一つ。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct SkillFile {
    /// Skill の中のパス（`SKILL.md`、`references/grammar.md` など）
    pub path: &'static str,
    pub text: &'static str,
}

/// 書き出す先の単位（06-06「Skill の導入（初回リリース版）」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Scope {
    User,
    Project,
}

/// `--agent` の名前。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Agent {
    ClaudeCode,
    Codex,
    OpenCode,
}

/// 文（ADR 0033）。`{名前}` は埋める値。
pub mod text {
    pub const INSTALLED: &str = "installed {path}";
    pub const REMOVED: &str = "removed {path}";
    pub const NOT_OURS: &str = "error: `{path}` was not written by `benitoite skill install`; it was left unchanged";
    pub const WRITE_FAILED: &str = "error: cannot write `{path}`: {reason}";
    pub const REMOVE_FAILED: &str = "error: cannot remove `{path}`: {reason}";
    pub const NO_HOME: &str = "error: cannot find the home directory; set `HOME` or use `--project`";
    /// 使い方の誤りの `{detail}` に埋める文
    pub const MISSING_ACTION: &str = "missing `install` or `uninstall`";
    pub const UNKNOWN_AGENT: &str = "unknown agent `{name}`; expected `claude-code`, `codex`, or `opencode`";
    pub const USER_AND_PROJECT: &str = "`--user` and `--project` cannot be used together";
}
```

```rust sig=src/cli/tools/skill/mod.rs needs=10-13
use std::ffi::OsString;
use std::path::{Path, PathBuf};

use crate::cli::CliEnv;

/// 埋め込んだ Skill のファイル（`bundle::FILES`）。`SKILL.md` は版の型板を置き換える前の形である。
pub fn files() -> &'static [SkillFile];

/// 書き出す先の Skill のディレクトリ（`<base>/.claude/skills/benitoite` など）を、重複を除いて返す。
/// `agents` が空なら、すべてのエージェントとする。`base` は、`User` ではホームのディレクトリ、`Project` では作業ディレクトリ。
pub fn target_dirs(scope: Scope, agents: &[Agent], base: &Path) -> Vec<PathBuf>;

/// Skill を `dir` に書き出す（本章「`skill install`・`uninstall`」）。`version` で `SKILL.md` の版の型板を置き換える。
/// 失敗したら、`env.stderr` に書く誤りの文（`text` の型板を埋めたもの）を返す。
pub fn install_dir(dir: &Path, version: &str) -> Result<(), String>;

/// `dir` の Skill を消す。消したら `Ok(true)`、なければ `Ok(false)`。`install` の書き出したものでなければ誤りの文を返す。
pub fn uninstall_dir(dir: &Path) -> Result<bool, String>;

/// `benitoite skill` の後の引数を解釈して実行し、終了状態を返す（06-01「`skill` のコマンドライン（初回リリース版）」）。
/// `home` は利用者のホームのディレクトリ（`run_tool` が環境変数 `HOME` から求める）。
pub fn run_skill(args: Vec<OsString>, env: CliEnv, home: Option<PathBuf>) -> u8;
```

## 第三者のライセンスの表示

`benitoite --licenses` は、処理系自身のライセンスの文と、実行ファイルに埋め込んだ第三者のライセンスの表示 `THIRD_PARTY_LICENSES` を `env.stdout` に書き、終了状態 0 で終える（06-01「コマンドラインの形」、05-01「ライセンスの表示」、ADR 0235）。10-13 の `cli::tools::print_licenses` の仮の中身を、D30 が書き換える。

- `THIRD_PARTY_LICENSES` は、リリースのスクリプトが cargo-about で環境ごとに生成する（[README](../README.md) の「U3・U4 で決めたこと」の 16）。生成したファイルを `crates/benitoite/licenses/THIRD_PARTY_LICENSES`（`.gitignore` に加える）に置いてから、機能 `bundled-licenses` を有効にしてビルドする。`third_party_licenses` は、この機能のビルドでだけ `include_str!` でファイルを埋め込んで `Some` を返し、ほかのビルドでは `None` を返す。
- リリースのスクリプトを通さないビルド（開発のビルドと、ソースからのビルド）は、機能を有効にしないので、`text::NOT_BUNDLED` を書く（05-01「ライセンスの表示」の【方針】）。
- 機能 `bundled-licenses` は、00-01「機能（feature）」の表に加えた。`scripts/check.sh` はこの機能を有効にしない（ファイルがないとビルドできないため）。この機能のビルドは、リリースのスクリプトだけが行う。

cargo-about は、2026-09-30 に `cargo info cargo-about` と crates.io の配布物で確かめたところ、最新の版は 0.9.2、ライセンスは `MIT OR Apache-2.0`、`rust-version` は 1.88.0 である。実行ファイル `cargo-about` は機能 `cli` を要する（配布物の `Cargo.toml` の `[[bin]]` の `required-features`）ので、`cargo install cargo-about --locked --version 0.9.2 --features cli` で導入する。処理系の依存には加えない。出力は handlebars の型板で作り、型板には、ライセンスの一覧（`licenses`）ごとの名前・SPDX の識別子・ライセンス文と、それを使うクレート（`used_by` の `crate`。cargo の `Package` の名前と版）が渡る（配布物の `docs/src/cli/generate/output.md`）。設定の `targets` でビルド先を絞れる（同 `config.md`）。

次の点は【要検証】であり、D30 が作業の中で確かめる。確かめられなければ、作業を止めて報告する。

- クレートごとの著作権表示: cargo-about は、クレートの配布物にライセンスのファイルがあればその本文を使い、なければ SPDX の標準の文を使う（同 `generate/README.md` の `--offline` の説明）。標準の文には著作権表示が入らないので、クレートごとの著作権表示が、ライセンス文の中にどこまで残るかを、実際の依存で確かめる。
- Apache-2.0 の NOTICE: 配布物の `src/` を `notice` で検索しても処理がなかった（2026-09-30）。cargo-about は NOTICE ファイルの内容を載せない見込みである。D30 は、依存のクレートの配布物の根にある `NOTICE`・`NOTICE.txt`・`NOTICE.md` を `cargo metadata` のパッケージの場所から探し、`THIRD_PARTY_LICENSES` の末尾に、クレートの名前と版を添えて加える処理をリリースのスクリプトに書く。
- ライセンスの検査は、これまでどおり `cargo deny check licenses` で行う（[README](../README.md) の「U3・U4 で決めたこと」の 16）。cargo-about の設定の `accepted` は、`deny.toml` の許可の一覧と同じにする。

```rust file=src/cli/tools/licenses.rs
//! `benitoite --licenses` の表示（設計書 05-01「ライセンスの表示」、06-01「コマンドラインの形」、ADR 0235）。
//! 第三者のライセンスの表示は、リリースのスクリプトが生成し、機能 `bundled-licenses` のビルドでだけ埋め込む。

/// 表示の文（ADR 0033）。
pub mod text {
    /// 処理系自身のライセンス（ADR 0003）
    pub const OWN_LICENSE: &str = "benitoite is licensed under either of the MIT License or the Apache License, Version 2.0, at your option.\n";
    /// リリースのスクリプトを通さないビルドの文（05-01「ライセンスの表示」）
    pub const NOT_BUNDLED: &str = "This build does not include the list of third-party licenses.\nThe release archives built by scripts/release.sh include it.\n";
    /// 第三者のライセンスの表示の前に置く見出し
    pub const THIRD_PARTY_HEADER: &str = "\nThird-party licenses:\n\n";
}
```

```rust sig=src/cli/tools/licenses.rs
/// 埋め込んだ `THIRD_PARTY_LICENSES`。機能 `bundled-licenses` のないビルドでは `None`。
pub fn third_party_licenses() -> Option<&'static str>;
```

## リリースのスクリプト

`scripts/release.sh` は、配る実行ファイルのビルドと試験を、開発機（macOS の arm64）の上で一つのスクリプトから行う（ADR 0233・0234、05-01「リリースの試験（初回リリース版）」）。スクリプトは段に分け、段を名指しして一部だけを行えるようにする。コンテナと仮想機械の道具、x86_64 の模倣の方法、WSL2 への SSH の設定は、事実の確認（D32）の結果に従って D31 が決める。

```text
scripts/release.sh <版> [--stage <段>]... [--wsl2 <SSH の接続先>] [--https-url <URL>] [--publish]
```

| 段 | 行う場所 | 入力 | 出力と確かめること |
|---|---|---|---|
| `preflight` | 開発機 | `<版>`、作業ツリー | `<版>` が `crates/benitoite/Cargo.toml` の `version` と一致する。作業ツリーに変更がない。使う道具（cargo-about、コンテナの道具、`shasum`）がある |
| `licenses` | 開発機 | `Cargo.lock`、`scripts/release/about.toml`・`about.hbs` | ビルド先ごとに `dist/<版>/<ビルド先>/THIRD_PARTY_LICENSES`。NOTICE の追加（本章「第三者のライセンスの表示」） |
| `build-macos` | 開発機 | ソース、`THIRD_PARTY_LICENSES` | `aarch64-apple-darwin` の `dist/<版>/<ビルド先>/benitoite`。`cargo build --release --locked --target <ビルド先> --features bundled-licenses` |
| `build-linux-arm64`・`build-linux-x86_64` | 開発機の上の Linux のコンテナか仮想機械（x86_64 は模倣） | 同上 | `aarch64-unknown-linux-musl`・`x86_64-unknown-linux-musl` の実行ファイル。各環境の OS の上でビルドする（05-01「対応環境」） |
| `test-<環境>` | ビルドした環境 | 実行ファイル、リポジトリ | `scripts/check.sh` が通る。受け入れテスト（`testdata/acceptance/`）を配る実行ファイルで実行し、期待する結果になる（外部コマンドは実際に起動する）。`benitoite --licenses` が第三者のライセンスを含む。`benitoite skill install --project` を一時ディレクトリで行い、埋め込んだファイルがすべて書き出される |
| `static-linux` | glibc のない最小のコンテナ | Linux の実行ファイル | 実行ファイルだけを入れたコンテナで `benitoite --version` が動く（musl で静的にリンクしたことの確認） |
| `https`（任意） | 開発機 | `--https-url` の URL | 配る実行ファイルで、その URL へ一度接続するスクリプトを実行する。失敗しても止めず、警告として記録する（07-03「HTTP のテスト（初回リリース版）」、ADR 0287） |
| `wsl2` | 設計者の Windows の機械の WSL2（SSH） | `--wsl2` の接続先、`x86_64-unknown-linux-musl` の実行ファイル、受け入れテスト | 受け入れテストを実行する。初回リリース版の完了の判定とマイナーの版で行い、パッチの版では省く（05-01「リリースの試験」）。`--wsl2` がなければ、省いたことを記録する |
| `archive` | 開発機 | 実行ファイル、`THIRD_PARTY_LICENSES`、`LICENSE-MIT`・`LICENSE-APACHE` | `dist/<版>/benitoite-<版>-<ビルド先>.tar.gz`（三つ）と `dist/<版>/SHA256SUMS` |
| `publish` | 開発機 | アーカイブと `SHA256SUMS` | `--publish` を付けたときだけ、`gh release create` で GitHub Releases に上げる。上げる前に、試験の記録と上げるファイルの一覧を示し、確かめの入力を待つ |

- `--stage` を付けなければ、`publish` を除くすべての段を表の順に行う。段は、前の段の出力が `dist/<版>/` にあることを確かめてから始める。`dist/` は `.gitignore` に加える。
- 各段の記録（実行したコマンド、結果、かかった時間、使った道具の版）を `dist/<版>/release.log` に書く。
- 受け入れテストを配る実行ファイルで実行するために、統合テスト `tests/acceptance_binary.rs` を置く。環境変数 `BENITOITE_RELEASE_BIN` に実行ファイルのパスを与えて `cargo test --test acceptance_binary -- --ignored` で動かし、`testdata/acceptance/` の各テストを子のプロセスとして実行して、ゴールデンテストの期待値と比べる。テストには `#[ignore]` を付け、`scripts/check.sh` では動かさない。
- ビルド先の Rust の標準ライブラリは、`rust-toolchain.toml` の `targets` に三つのビルド先を加えて導入する（05-01「対応環境」の「ツールチェーンの版は `rust-toolchain.toml` で固定」）。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| D00 | 本章の `file=`・`append=` と、`sig=` の `todo!()` の仮置きを置く |
| D20 | `generate.rs`、`bundle.rs`、`skill::files`、`examples/gen_skill.rs`、`tests/skill_docs.rs`、生成物 |
| D21 | 手で書く Skill の文書、載せたコードの例の検査 |
| D22 | `skill::target_dirs`・`install_dir`・`uninstall_dir`・`run_skill`、`cli::tools::run_tool` の `skill` の振り分け |
| D30 | `licenses.rs`、`print_licenses` の中身、機能 `bundled-licenses`、`LICENSE-MIT`・`LICENSE-APACHE`、`scripts/release/about.toml`・`about.hbs`、`licenses` の段のスクリプト |
| D31 | `scripts/release.sh` の残りの段、`tests/acceptance_binary.rs`、`rust-toolchain.toml` の `targets`、`Cargo.toml` の `version`（`0.1.0`） |

## 未定のこと

- コンテナと仮想機械の道具、x86_64 の模倣の上で Rust のビルドとテストが動くか、WSL2 に SSH でログインする設定は、[OPEN-060](../../design/open-issues.md#open-060) の【要検証】であり、D32 が確かめてから D31 が段の中身を決める。

本章を書いた後に、次の点を設計者が決めた（2026-09-30）。

- 初回リリース版の版の番号は `0.1.0` とする（[ADR 0090](../../design/decisions/0090-version-numbers-and-codenames.md)）。`Cargo.toml` の `version`（いまは `0.0.0`）は D31 が初めに改める。リリースのスクリプトは版を書き換えず、一致を確かめるだけである。
- 著作権表示は `Copyright (c) 2026 tecogonaz and Benitoite contributors` とする（[ADR 0290](../../design/decisions/0290-copyright-holder-name-and-open-021.md)、05-01「ライセンスの表示」）。`LICENSE-MIT` は D30 が、README は D33 が書く。
