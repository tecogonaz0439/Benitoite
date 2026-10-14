# W1〜W3 の事前点検

対象: `san_benito`（a2dcd4fd）。`crates/` は 02b52fd7 から変わっていないので、調査 A の行番号はそのまま使える。パスは `crates/benitoite/` を省く。リポジトリのファイルは変えていない。

（全体の所見: 共通の補足。C1〜C6 は W1〜W3 のすべてに当てはまる）

### C1. 先頭の部分は `package.bnt` を含めて「モジュール」として読み込みの表に入れる（W1 で作る）

- 今の処理系は **モジュールの ID とファイル ID が同じ値**である（`src/base/mod.rs:28-37` の `ModuleId::of_file`、`src/modules/load.rs:129`、02-04「モジュールの表」の表の 1 行目）。`LoadOutput.asts` も添字がモジュールの ID である（`src/modules/mod.rs:103-115`）。`typeck/decls.rs:687`・`typeck/traits/collect.rs:101,138` は `asts.iter().enumerate()` を ID として使う。
- したがって `package.bnt` をソースの表に加える（診断の位置に要る）なら、モジュールの表にも 1 項目として入れないと ID がずれる。
- 推す形: `ModuleKind` に列挙子 `Config`（`package.bnt`）を足す。名前は `ModulePath(vec!["package.bnt".into()])`（根）、`[別名, "package.bnt"]`（依存のもの。W2）。小文字と `.` を含む段なので import の名前（大文字の識別子の段）と決して一致しない。AST は `header` だけを持ち、`imports`・`decls` は空（中身があれば誤り E0912 にし、AST からは除くか、名前解決に進まないので残してもよい）。
- **計画との食い違い**: plan.md の「凍結した型の変更」の表は 10-04（`ModuleKind` に列挙子を足す）を W2・W4 に割り当てている。W1 が `Config` を足すので、表の作業の欄に W1 を加えてから渡すこと（変更の種類は了承済みの範囲）。
- `ModuleKind` を網羅で `match` している箇所はコンパイルの誤りで分かる（`src/ir/desugar/decls.rs:78,99,111`）。`Config` は宣言を持たないので、そこでは `User` と同じ腕に入れてよい。`matches!(…, Entry | User)` の箇所（`resolve/lookup.rs:397,458`、`runtime/assert.rs:121,155`、`typeck/decls.rs:196`）は `Config` を含めなくてよい（宣言がない）。

### C2. 読む順とファイル ID（W1・W2）

- 今は入口を読んで解析した直後に、その import を `finder.find` で解決する（`load.rs:140-154`）。W2 では依存の表が入口の import の解決より前に要る。
- 推す順: (1) 入口、(2) 根の `package.bnt`（あれば）、(3) 依存ごとの `package.bnt`（記述の順。W2）、(4) prelude、(5) 以降は今のとおり import の順。(2)(3) は作業の一覧に積まず、入口の解析の直後に同じ反復の中で読む（入口の import の解決はその後）。`Finder::new` は今 `load.rs:93` で一覧の前に作るので、依存の表を受け取れるよう、作る位置を後ろに移すか `Finder` に設定の関数を足す（`Finder` は非公開。自由に変えてよい）。
- 根の `package.bnt` の有無は `fs.list_dir(&entry.root)` で、名前が `package.bnt` に**完全に一致**し `is_dir == false` の項目で決める（02-04 のモジュールの照合と同じ考え方。`Package.bnt` は設定ファイルとしない）。読むのは `ModuleFs::read_file`。`std::fs` を直接使わない（`pipeline::check_files` の `MemoryFs`、`pipeline.rs:325-360` で確かめられなくなる）。
- `package.bnt` がないときのファイル ID は今と同じなので、既存のテストの ID の前提（`modules/tests.rs:466,507` など）は壊れない。
- 02-02「ソースとファイル ID」の手順（読む順）と 02-04「モジュールの表」（種類の行）を直す。

### C3. 診断コード（全体の割り当て）

区分を一つ新設する: **`E09nn` 検査の誤り／パッケージと依存（ファイルの先頭の部分、`package.bnt`、依存の読み込み、中身のハッシュ）**。02-10「診断コード」の表に行を足す。W4 の外部の関数は `E08`（属性）と `E10nn`（新設）を使い、`E09` に混ぜないよう W4 の事前点検に伝える。

構文の位置の誤りだけは、`import` の位置の `E0219` と揃えて `E02` に置く（`fmt` は `E01`・`E02` のファイルを整形しない。`src/cli/tools/formatter/mod.rs:104-110`、06-03「構文の誤りがあるファイル」）。ブロックの閉じ方は既存の `E0213`・`E0214` を、`Benitoite` の別名は既存の `E0325` を使う。

文言の案（`diag_codes!` の型板の形。`{…}` は引数、`[...]` は注記の鍵）:

| コード | 作業 | 報告する段 | message / label / 注記 |
|---|---|---|---|
| E0252 | W1 | 構文 | "`{item}` must come at the start of the file, before `import` and declarations" / "written after an import or a declaration" / `first: "the first import or declaration is here"` |
| E0901 | W1 | 構文 | "unknown field `{field}` in `{block}`" / `fields: "the fields of `{block}` are {fields}"` |
| E0902 | W1 | 構文 | "{what} is written more than once" / "written again here" / `first: "first written here"`（同じ欄、`language` の二度、`package` のブロックの二度、同じ別名の `dependency`） |
| E0903 | W1 | 構文 | "the field `{field}` cannot be used in this version" / `local: "this version reads dependencies only from a local directory written with `path`"`（`source`・`version`・`commit`） |
| E0904 | W1 | 構文 | "the dependency `{alias}` has no `path`" / `path: "write the directory of the package, such as `path \"../textkit\"`"` |
| E0905 | W1 | 構文 | "malformed language version `{version}`" / `form: "write three numbers separated by `.`, such as `0.0.3`"` |
| E0906 | W1 | 構文 | "malformed hash `{hash}`" / `form: "write `sha256:` followed by 64 lowercase hexadecimal digits"` |
| E0325 | W1 | 構文 | 既存。注記 `dependency: "a dependency cannot be named `Benitoite`, which always refers to the standard library"` を足し、説明の文に依存の別名を加える |
| E0907 | W1 | 読み込み | "this file needs Benitoite {version} or later, but this is Benitoite {current}" |
| E0908 | W1 | 読み込み | "this file was written for Benitoite {version}, and the language changed incompatibly in {changed}" / `change: "{summary}"`（表が空なので今は出ない。単体テストで表を差し込んで確かめる） |
| E0909 | W1 | 読み込み | "`{item}` can be written only at the start of the starting file or in `package.bnt`"（取り込まれるモジュールとパッケージのモジュールに書いたとき） |
| E0910 | W1 | 読み込み | "a `package` block can be written only in `package.bnt`" |
| E0911 | W1 | 読み込み | "{what} is written both at the start of `{file}` and in `package.bnt`" / `other: "also written here"`（`what` は "`dependency`" か "`language`"） |
| E0912 | W1 | 読み込み | "`package.bnt` can contain only `language`, `dependency`, and `package`" / "not allowed in `package.bnt`" |
| E0913 | W1 | 読み込み | "`{path}` is a settings file and cannot be checked, run, or tested"（入口が `package.bnt`。主な位置なし） |
| E0914 | W1 | 読み込み | "the package `{package}` needs a `language` line" |
| E0915 | W1 | 読み込み | "a package cannot have dependencies in this version" / `package: "this `package.bnt` declares the package `{package}`"` |
| E0916 | W2 | 読み込み | "cannot read the dependency `{alias}` at `{path}`" / `reason: "{reason}"` |
| E0917 | W2 | 読み込み | "the dependency `{alias}` at `{path}` is not a Benitoite package" / `no_config: "the directory has no `package.bnt`"`, `no_block: "its `package.bnt` has no `package` block"` |
| E0918 | W2 | 読み込み | "`{module}` names both a module under the root directory and a module of the dependency `{alias}`" / `root_file: "under the root directory: `{root_path}`"`, `package_file: "in the package `{package}`: `{package_path}`"`, `rename: "rename the directory under the root directory, or the dependency"` |
| E0318 | W2 | 読み込み | 既存。注記 `package: "modules of the package `{package}` are imported by their path from the package root `{root}`"` を足す |
| E0919 | W3 | 読み込み | "the contents of the dependency `{alias}` do not match its `hash`" / `expected: "expected: {expected}"`, `computed: "computed: {computed}"`, `update: "if the change is intended, write the computed hash"` |
| E0920 | W3 | 読み込み | "cannot compute the hash of the dependency `{alias}`" / `symlink`, `case`, `name`, `too_many`, `too_large`, `read` の注記（W3 の節） |

- 番号は作業の順に振る。作業の途中で要らなくなった番号は詰めず、作業の中で使う前なら振り直してよい（公開前なので廃止の扱いは不要）。
- 構文の段のコード（E0252・E0901〜E0906）は構文解析器が出す。どれも「どのファイルか」に依らない。ファイルの種類に依る規則（E0909〜E0915）は読み込みの段で出す。理由: 構文解析器はファイルの種類を知らず（`parse` の引数、`src/syntax/parser/mod.rs:97-104`）、`spec_examples` と `fmt` は構文解析器だけを呼ぶ。
- 位置: 欄の誤りは欄の名前、版の誤りは文字列リテラル、置き場所の誤りは語（`language` など）の span。

### C4. テストの置き場所

- 新しい区分のディレクトリ `testdata/packages/` を作る（07-03「ゴールデンテストの形式」の区分は「など」で開いている）。
- 複数のファイルのケースは、ディレクトリ `<名前>/`（中に `main.bnt`）と隣の `<名前>.mode`・`.exit`・`.diag.json` など（例 `testdata/modules/c11-collision/`）。コマンドは `check <ディレクトリ>` なので根はケースのディレクトリ。
- 根の外の依存（`path "../…"`）を確かめるには、共有のパッケージを **`testdata/packages/libraries.files/`** に置く。`.files` で終わるディレクトリは発見の対象から外れ（`tests/golden.rs:349-352`）、spec-coverage も集計しない。`.files` は「同名のケースの作業ディレクトリへ写す入力」の印でもあるので、同じ名前のケース（`libraries`）を作らない。
- 根の下の依存は `<ケース>/deps/textkit/` のように置く（小文字のディレクトリは import で辿れない）。
- 診断の表示名は相対パス（`testdata/packages/<ケース>/main.bnt`）になる（例 `testdata/modules/c11-missing.text.stderr`）。
- ゴールデンは `check`・`run` のたびに、整形の前と後で `pipeline::check_files`（`MemoryFs`）の診断を比べる（`tests/golden/formatting.rs:303-371`）。ケースのディレクトリの外のファイルは `MemoryFs` にないので、両方で同じ誤りになり、比べる性質は壊れない。ケースのディレクトリの中の `package.bnt` と依存のファイルは `MemoryFs` に入る（`script_files` が `.bnt` をすべて集める）ので、読み込みは必ず `ModuleFs` を通す。
- 版の宣言の例には、処理系の版（`Cargo.toml` の `0.0.3`）以下の版を書く。「新しすぎる」の例は `99.0.0` にして、リリースで版を上げても期待値が変わらないようにする。

### C5. 設計書の章と見出し

- `docs/design/README.md` の 06 の部の欠番は 06-02・06-05・06-07・06-08 で、**06-09 は空いている**。新しい章 `06-tooling/06-09-packages.md` を W1 で作る（`# パッケージ` / `## 目的と範囲` / `## 前提` / `## 仕様`）。README の「ツールチェーン」の表に行を足す（範囲: `package.bnt`、依存の記述の読み込み、言語の版、依存のパッケージの構成、中身のハッシュ、`test`・`fmt` の扱い）。
- 新しい節の見出しには「（初回リリース版）」を付けない（初回リリースの後に加えた節）。既存の `###` の見出しは変えない。
- 文法の全体の節の見出し「初回リリース版の文法の全体」は `gen_skill` が名前で探す（`src/cli/tools/skill/generate.rs:129-169`、`text::GRAMMAR_HEADING`）。見出しを変えずにコードブロックに規則を足し、節の初めの文に「ファイルの先頭の部分の規則も含む」と書き足す。01-02「初回リリース版に含めない構文」の「初回リリース版の構文は…ですべて」の文は、先頭の部分の節を加えたことに合わせて直す。
- `spec_examples`（`tests/spec_examples.rs`）は 01-spec と 08-04 の ```text のブロックを、構文解析器（`SourceKind::User`）で読み、続けて `check_files` で名前解決まで進める。EBNF のブロックは除く（`is_ebnf_block`）。新しい例の注意:
  - 例は単独のファイルとして構文の誤りなく読めること（構文の段の E09 も「読めない」になる）。`package` のブロックの例は単独で構文は通るが、入口では E0910 になる。読み込みの段の E09 は `check_local_bindings` の「読み込みの誤り」（`spec_examples.rs:466-483`、E01・E02・E0318〜E0322）に入らないので、テストは失敗しない。ただし名前解決まで進まない。
  - `package.bnt` の例と依存のパッケージの構成の例は 06-09 に置く（06 の部は `spec_examples` が読まない）。
- `tools/spec-coverage` は 01-spec の `###`・`####` の見出しを集計する。新しい節には、ゴールデンのファイルの先頭のコメントに `// spec: 01-02 <見出し>` の印を付ける。印は先頭のコメントの並びの中でだけ読まれるので、`language` の行より前に置く。
- `CHANGELOG.md` には今 `## Unreleased` の節がない（先頭は `## 0.0.3 (San Benito)`）。W1 が `# Changelog` の説明の段落の後に `## Unreleased` を作る。新しい構文は今まで誤りだった書き方なので、互換性を壊す変更の表には載せない。

### C6. 計画と設計書・コードの食い違い（直してから渡す）

1. 06-01「ディレクトリの指定（初回リリース版）」の「処理系は、プロジェクトの設定ファイルを読まない」（`06-01-cli.md` の 47 行あたり）は W1 で偽になる。W1 の設計書の作業に加える。01-03「実行を始めるモジュール（初回リリース版）」の「根のディレクトリを設定ファイルで指定する仕組みは設けない」は、W1・W2 の後も正しい（`package.bnt` は根を決めない）ので残す。
2. 01-03「モジュールと import（初回リリース版）」の「取り込めるのは、根のディレクトリとその下のファイルと、標準ライブラリのモジュールだけ」と「モジュールの同一性は、根のディレクトリからの名前で決まる」は W2 で改める。W2 の設計書の作業に明記する。
3. 01-01「キーワード」の `as` の段落（`01-01-lexical.md:95`）と 02-03「字句」の文脈の語の段落（`02-03-frontend.md:53`）、02-03「AST」の表の「宣言」の行（228 行）にも、`language`・`dependency`・`package` と欄の名前を加える。plan.md の W1 の設計書の一覧にない。
4. plan.md W1 の手順 4「パッケージの `package.bnt` では必須（この必須の検査はパッケージを読む W2 で効く）」: 根の `package.bnt` に `package` のブロックがある場合（パッケージを開発しながら根として検査する場合）にも同じ規則を当てるほうが規則が一つで済む。推す案: **`package` のブロックを持つ `package.bnt` は、根として読んでも依存として読んでも、`language` が必須で（E0914）、`dependency` を書けない（E0915）**。W1 は根の `package.bnt` にこの規則を当て、W2 は同じ関数を依存の `package.bnt` に当てる。
5. 凍結した型の表の作業の欄（C1）。
6. W4 への申し送り: `@external` のコンポーネントのパスの基準（根かパッケージの根）を W4 の段で知るには、モジュールごとの根の実パスが要る。今 `CheckedProgram` に渡る情報は `ModuleTable`（名前と種類）と、表示名だけを持つ `SourceTable` である。W2 で `LoadOutput` と `CheckedProgram` に依存の表（別名・パッケージの名前・正規化した根のパス）を足すか、W4 で足すかを決める必要がある。どちらも凍結した型（10-04 の `LoadOutput`、10-13 の `CheckedProgram`）への欄の追加で、了承の表にない。W2 では足さず、W4 の事前点検で扱うのを推す。

## W1 への補足

### 構文解析（`src/syntax/parser/`）

- 入口は `decls::parse_module`（`decls.rs:10-74`）。`p.docs.module_doc` で先頭の `//!` を取り、`skip_newlines` の後にトップレベルのループに入る。コメントは字句の列に現れない（`ParseOutput.comments`）ので、「`//!` の後」は「最初の字句から」と同じ意味になる。シェバンとバイト順マークは `module_doc` が飛ばす（`items.rs:87-124`）。
- 語は今は小文字の識別子（`TokenKind::LowerIdent`、`TokenValue::Ident`）。`token.rs` のキーワードに `package`・`language`・`dependency` はない。字句解析器は変えない。`p.word("language")`（`mod.rs:732-735`）で見分ける。
- 今のトップレベルで小文字の識別子から始まる行は常に誤り（`parse_item` の最後の腕 → `try_foreign_decl_start` → `p.unexpected(text::DECLARATION)`、`decls.rs:154-168`）。他の言語の書き方の診断も `package`・`language`・`dependency` を扱っていない（`items.rs:521-581`）。したがって、ファイルの先頭で三つの語を特別に読んでも、今通るプログラムは変わらない。
- 改行の判定（`src/syntax/newline.rs`）は `end` の後がキーワードのときだけ閉じの扱いをする（`newline.rs:44-48,104-140`）。`end dependency` の `dependency` はキーワードでないので閉じの扱いは起きず、行末の NEWLINE は残る（`continues_after` に小文字の識別子は入らない）。字句の段は変えなくてよい。
- 新しいファイル `src/syntax/parser/header.rs` を推す:
  - `pub(super) fn parse_header(p: &mut Parser) -> Vec<HeaderItem>`: `parse_module` の `skip_newlines` の直後に呼ぶ。行頭の `language`・`dependency`・`package` が続く間、一つずつ読み、間の NEWLINE を飛ばす。**先頭の位置では、三つの語のどれかで始まる行は必ず先頭の部分の項目として読む**（後に続く字句が違えば `E0201` で「期待したもの」を示す）。
  - `pub(super) fn header_ahead(p: &Parser) -> bool`: 先頭の部分より後で見分けるための厳しい先読み。`language` の次が `StringLit`、`dependency`・`package` の次が `UpperIdent` のときだけ真。`parse_module` のループの先頭（`import` の判定の前）で真なら、`E0252`（`first` に最初の import か宣言の span）を報告し、`parse_header` と同じ関数で一つ読んで捨てる（回復のため。`end dependency` まで消費する）。
  - `language "X"`: 一行。値は補間のない文字列リテラル（`StrStart` なら `E0220` と同じ考えの誤り。既存の `E0201` の expected に「a version string」を入れる）。版の形の検査（E0905）もここで行う（`MAJOR.MINOR.PATCH`。各部は ASCII の数字の並びで、`0` 以外は `0` で始めない、`u64` に収まる）。
  - `dependency Alias` / `package Name`: 名前は大文字の識別子（`p.expect_name(TokenKind::UpperIdent, …)`）。NEWLINE の後、`end` が来るまで「欄の名前（小文字の識別子）＋文字列リテラル」の行を読む。閉じは `close_block` を使えない（`TokenKind` で比べる。`mod.rs:767-`）ので自前で `KwEnd` と `p.word("dependency")` を確かめ、食い違いは `E0213`、ファイルの終わりまで閉じなければ `E0214`（引数 `construct` に `dependency`／`package`）。
  - 欄の検査（構文の段）: 知らない欄 `E0901`、同じ欄の二度 `E0902`、`source`・`version`・`commit` は `E0903`（知らない欄と分ける）、`path` がない `dependency` は `E0904`（`E0903` の欄だけが書かれた場合も）、`hash` の形 `E0906`（`sha256:` と小文字の 16 進 64 文字）、別名 `Benitoite` は `E0325`、同じ別名の `dependency` と二つ目の `language`・`package` は `E0902`。
  - `package` のブロックの欄: **`license` だけ**を推す（値の中身は検査しない。空の文字列も許す）。欄のないブロック（`package Textkit` と `end package` だけ）も許す。理由: この改造で読むのは名前と `language`（ブロックの外の行）だけで、ほかの欄は使い道がまだない。例（`study/package-samples/proposed/packages/*/package.bnt`）の `language` をブロックの中に書く形は R1・Q4 で採らない（`language` は独立の行）ので、例を写すときに直す。
- 文言の呼び名（`expected` に入れる語）は `src/syntax/parser/text.rs` に定数で置く。
- `///` を先頭の部分の項目の前に書いたときは、宣言に結び付かないので既存の処理（`DocStore::finish`）の誤りになる。特別な扱いは要らない。

### AST（`src/syntax/ast.rs`。10-03 の変更は了承済み）

`Module`（`ast.rs:32-40`）に欄を一つ足す。`Module` を作るのは `parse_module` だけ（`grep 'Module {'`）なので影響は小さい。

```rust
pub struct Module { /* 既存の欄 */ pub header: Vec<HeaderItem> }   // ソースの順。誤りの位置に書いたものは入れない
pub enum HeaderItem { Language(LanguageDecl), Dependency(HeaderBlock), Package(HeaderBlock) }
pub struct LanguageDecl { pub id: NodeId, pub span: Span, pub version: StrArg }
pub struct HeaderBlock { pub id: NodeId, pub span: Span, pub name: Name, pub fields: Vec<HeaderField> }
pub struct HeaderField { pub span: Span, pub name: Name, pub value: StrArg }
```

`StrArg` は既存（`ast.rs:88-93`）。版の数の組は AST に入れず、読み込みの段で文字列から作り直す（同じ関数を使う）。02-03「AST」の表に行を足す。

### 読み込みの段（`src/modules/`）

- 新しい非公開のモジュール `src/modules/package.rs`（名前は任意）に、先頭の部分の検査を集める:
  - `Version`（三つの `u64`）と `parse_version(&str) -> Option<Version>`（構文の段と共有するなら `crate::syntax` 側に置き、こちらから呼ぶ）。処理系の版は `env!("CARGO_PKG_VERSION")` から作る（`runtime/report.rs:254` など既存の使い方と同じ）。
  - 互換性を壊した版の表 `const BREAKING_CHANGES: &[BreakingChange] = &[];`（`BreakingChange { version: Version, summary: &'static str }`）。比べる関数は表を引数に取り、単体テストで表を差し込んで E0908 を確かめる。宣言 < 項目の版 ≤ 処理系の版、の項目があれば E0908（最も古い項目を示す）。宣言 > 処理系の版なら E0907。
  - 置き場所の規則（E0909〜E0915）。
- `load_with_limits`（`load.rs:71-201`）への組み込み:
  - 入口の `pending.kind == Entry` で、入口のパスのファイル名が `package.bnt` なら E0913 を出し、根の `package.bnt` は読まない（同じファイルを二度読まない）。
  - 入口を解析した直後に根の `package.bnt` を読む（C2）。種類 `ModuleKind::Config`、表示名は入口の表示名のディレクトリ部分 + `package.bnt`（`find.rs:124-133` の作り方と同じ）。
  - 入口の `header` に `package` のブロックがあれば E0910。入口と根の `package.bnt` の両方に `dependency` があれば E0911（`what` = `dependency`、主な位置は入口の最初の `dependency`、`other` に `package.bnt` の最初のもの）。`language` も同じく **E0911**（推す案。理由: 二つの宣言が食い違いうる。一か所に書く規則を依存と揃える）。
  - `package.bnt` に `import` か宣言があれば E0912（最初のものに一つ）。
  - `package` のブロックを持つ `package.bnt` に `language` がなければ E0914、`dependency` があれば E0915（C6 の 4）。
  - 取り込まれたモジュール（`User`）の `header` が空でなければ E0909（項目ごとに一つ）。W2 の `Package` のモジュールも同じ。
  - `language` を書いたすべてのファイル（入口・根の `package.bnt`）で版を照合する（E0907・E0908）。
- 依存の記述は W1 では検査だけで、`import` の解決に使わない（plan のとおり）。パスの存在も確かめない（W2）。

### 整形器（`src/cli/tools/formatter/`）

- `format_source`（`mod.rs:66-102`）は構文解析の後、AST から役割の表を作る（`roles::build_roles`、`roles.rs:63-71`）。`roles/walk.rs:288-297` の `Walker::module` で `module.header` を先に辿る。
- 項目ごとに `self.top_range(span, TopKind::Other)` と `self.element(span, Place::Top)`。`TopKind::Other` にすると、項目どうしと、最後の項目と最初の import・宣言の間に、ちょうど一つの空の行を置く（`print.rs:300-318` の規則。例の `notes.bnt` の形と同じ）。新しい `TopKind` は要らない。
- ブロックは `record`（`walk.rs:498-510`）と同じ形: `self.keyword(span)`（先頭の字句。`walk.rs:395-402`）を開き、`self.open_end(open, span)`（`end_word` は最後の字句の一つ前の `end` も拾う。`walk.rs:189-196`。`end dependency` で動く）、欄ごとに `self.element(field.span, Place::Deeper(open))`。
- 06-03 の「字下げ」「空の行」に先頭の部分の規則を一文ずつ足し、「整形の例」に例を足すかは任意。
- 先頭の部分より後に書いた項目は E0252（E02）なので、`fmt` は整形しない。E09 の構文の段の誤り（知らない欄など）だけのファイルは整形する（06-03「構文の誤りがあるファイル」の第 2 段落に E09 の例を足す）。

### `test` と `fmt` のディレクトリの走査

- 集め方は `src/cli/tools/args.rs:113-134` の `bnt_files`（`test` と `fmt` が共有。`fmt` は `formatter/mod.rs:137`、`test` は `test_runner/mod.rs:173-197` の `test_entries`）。`bnt_files` は変えず、`test_entries` の側で除く。
- 除くもの（推す案）:
  - 名前が `package.bnt` に完全に一致するファイル（深さによらない）。
  - **指定したディレクトリより下のディレクトリで、直下に `package.bnt` を持つもの（その下全体）**。理由: そこはパッケージの根であり（例: Skill のディレクトリに写した `Textkit/`、`deps/textkit/`）、中のファイルを指定したディレクトリを根とする入口として検査すると、パッケージの中の `import` がパッケージの根から解決されず誤りになる。plan.md の Q3 の「`package.bnt` を入口として拾わない」より一歩広いので、オーケストレータが了承してから渡す。了承しないなら、パッケージを根の下に置いたゴールデン（C4）を `test` のケースにしない。
- `fmt` は `package.bnt` も整形する（plan のとおり。変更なし）。
- `run package.bnt`・`check package.bnt`・`test package.bnt`（ファイルを直接指定）は E0913（読み込みの段）。
- 06-01「ディレクトリの指定（初回リリース版）」の第 3 項目と 06-04「テストの実行」の第 1 段落に、除く規則を書き足す。

### 設計書（W1 が直す節）

| 章 | 節 | 内容 |
|---|---|---|
| 01-01 | キーワード（95 行の段落） | `language`・`dependency`・`package` と欄の名前は予約しない |
| 01-02 | 新しい節「ファイルの先頭の部分」（「モジュールと import（初回リリース版）」の後） | 位置（`//!` の後、最初の import・宣言の前）、三つの形、欄の一覧（`dependency`: `path`・`hash`、読むが使えない `source`・`version`・`commit`。`package`: `license`）、順は問わない、二度書き・知らない欄・後に書いた項目の誤り、`language` の版の形。EBNF は下 |
| 01-02 | 初回リリース版の文法の全体 | 下の規則を足す（見出しは変えない。C5） |
| 01-03 | 新しい節「依存の記述と `package.bnt`」 | 書ける場所（入口の先頭か根の `package.bnt`。両方は誤り）、`package.bnt` は根の直下だけを見て親を遡らない、`import` で取り込めない、`language` の意味（新しすぎる・互換性を壊した後の版）、必須の条件 |
| 02-02 | ソースとファイル ID | 読む順（C2） |
| 02-03 | 字句（53 行）、AST（228 行）、構文の規則に伴う診断 | 文脈の語、AST の欄 |
| 02-04 | モジュールの表 | 種類に「設定ファイル」 |
| 02-10 | 診断コード | `E09nn` の行 |
| 06-01 | ディレクトリの指定（初回リリース版） | 設定ファイルを読まない、の文を改め、`test` の除外 |
| 06-03 | 字下げ・空の行・構文の誤りがあるファイル | 上の規則 |
| 06-04 | テストの実行 | 除外 |
| 06-09（新） | 目的と範囲・前提・仕様 | `package.bnt` の例と役割（根の設定とパッケージの設定）、`fmt`・`test` の扱い。W2・W3 が節を足す |

EBNF の案（`as` と同じく、引用符の語は文脈で意味を持つ語であることを本文に書く）:

```text
Program     = [ NL ] [ Body [ NL ] ] .
Body        = Header [ NL Items ]
            | Items .
Header      = HeaderItem { NL HeaderItem } .
HeaderItem  = "language" StringLit
            | "dependency" UpperIdent NL { HeaderField NL } "end" "dependency"
            | "package" UpperIdent NL { HeaderField NL } "end" "package" .
HeaderField = LowerIdent StringLit .
```

01-02 の節の例（`spec_examples` で読める形）:

```text
language "0.0.3"

dependency Textkit
  path "../packages/textkit"
end dependency

import Textkit.Slug

function main() -> Unit
  ()
end function
```

### テスト

- 構文（単体。`src/syntax/parser/` の `#[cfg(test)]`、`test_support::{parse_source, codes}` を使う）: 三つの形が `header` に入ること、空のブロック、後に書いた項目の E0252 と回復、E0901〜E0906、E0325、閉じの誤り E0213・E0214。単体テストでよいものはゴールデンに重ねない（スキル `test-audit` の作成時の関門）。
- 版（単体。`modules::package`）: 形の受け入れと拒否、比較、差し込んだ表での E0908。
- 読み込み（ゴールデン `testdata/packages/`）: 入口の先頭の部分だけのケース（`check`、終了 0。印 `// spec: 01-02 ファイルの先頭の部分`）、根の `package.bnt` のケース、E0907（`99.0.0`）・E0909・E0910・E0911（`dependency` と `language` の 2 件）・E0912・E0913（`<ケース>/package.bnt` を直接指定する単一ファイルのケースは作れないので、`tests/` の CLI のテストか `modules` の単体テスト）・E0914・E0915。W1 のゴールデンの依存の記述の `path` は、W2 で読まれても壊れないよう、実在するパッケージ（`deps/textkit/`、`package.bnt` に `package` のブロックと `language`）を指す。
- 整形: `testdata/fmt/` に先頭の部分を含むケース（`.formatted` の期待値。字下げ・空の行）。
- 走査の除外: `tests/test_command.rs` の一時ディレクトリの形（`Directory::new`・`write`）で、`package.bnt` と、`package.bnt` を持つ下のディレクトリが入口にならないこと。`fmt` は `package.bnt` を整形すること（`tests/fmt_command.rs`）。

### 完了の条件（共通のものに加えて）

```sh
cargo test -p benitoite --lib syntax::parser
cargo test -p benitoite --lib modules
cargo test -p benitoite --lib cli::tools
cargo test -p benitoite --lib pipeline
cargo test -p benitoite --test test_command --test fmt_command
BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=testdata/fmt/ cargo test -p benitoite --test golden
python3 tools/spec-coverage/spec_coverage.py
```

## W2 への補足

### 依存の表と読む順

- 依存の表（非公開。`load.rs` か `modules/package.rs`）: 別名、記述の `path`（文字列）、正規化した根の実パス（`fs.canonicalize(root.join(path))`）、`hash`（W3）、パッケージの名前（`package` のブロックの名前）、その `package.bnt` の ID、記述の位置。
- 入口と根の `package.bnt` を読んだ直後に、記述の順に各依存の `package.bnt` を読む（C2。**すべての依存を、import の有無によらず読む**。推す案。理由: 記述の誤り（パスの書き間違い）を、取り込む前でも報告する。読むのは `package.bnt` だけで、モジュールは import で辿れたものだけを読む ADR 0156 の考えは保つ）。
  - ディレクトリが読めない・ない: E0916。`package.bnt` がない、または `package` のブロックがない: E0917。
  - 依存の `package.bnt` に、W1 の関数で E0912・E0914・E0915 と版の照合（E0907・E0908）を当てる。
  - 種類 `Config`、名前 `[別名, "package.bnt"]`。表示名は「入口の表示名のディレクトリ部分 + 記述の `path` + `/package.bnt`」（正規化しない。書いたとおり）。
- `path` は記述を書いたファイルのディレクトリ（＝根）からの相対パス。絶対パスを書いたら？ R2 は相対パスとだけ書く。推す案: 絶対パスも受け付け、そのまま使う（`Path::join` の振る舞い）と 06-09 に書く。拒むなら E0904 に注記を足す。オーケストレータが決める（小さい点）。

### `ModuleKind` と `ModulePath`（10-04 の変更は了承済み）

- `ModuleKind::Package` を足す。名前は **`[別名, パッケージの根からの段...]`**（`import Fuzzy.Distance` なら `["Fuzzy", "Distance"]`。取り込みの名前そのもの）。`ModulePath` の型は変えない。
- これで同一性が「別名 + パッケージの根からのパス」になる理由: 根の `Fuzzy/Distance.bnt` とパッケージの `Distance.bnt` が両方あるときの `import Fuzzy.Distance` は E0918 で止まり、パッケージの中の import は根を探さない（下）ので、同じ名前が別のファイルを指すことはない。脱糖の名前（`ir/desugar/decls.rs:111-112` の `"{dotted}.{name}"`）も `Fuzzy.Distance.distance` になり、診断に読みやすい。
- `Package` を `matches!(…, Entry | User)` の各箇所（`resolve/lookup.rs:397,458`、`runtime/assert.rs:121,155`、`typeck/decls.rs:196`）と網羅の `match`（`ir/desugar/decls.rs:78,99,111`）で `User` と同じに扱う。違うのは警告の扱いと探し方だけ。
- `Pending`（`load.rs:21-26`。非公開）に「どのパッケージのモジュールか」（依存の表の添字の `Option`）を足し、そのモジュールの import を解決するときに `Finder::find` へ渡す（`find` の引数を足すのは了承済み）。

### 探し方（`src/modules/find.rs:35-136`）

`find(import, from: Option<package>)` とし、次の順:

1. 先頭の段が `Benitoite` → 今のとおり（パッケージの中からも同じ）。
2. `from` がパッケージ P → P の根で今の手順（`find.rs:51-123`）を行う。根の外の判定（E0319）は P の正規化した根で行う。見つからなければ E0318 に注記 `package`。P の別名を通した `import P.X` も、ほかの依存の別名も、根のモジュールも探さない（R4）。名前は `[P の別名] + 段`、種類 `Package`、表示名は P の表示の根 + 相対パス。
3. `from` が根（入口・`User`）で、先頭の段が依存の別名 A と一致 → 残りの段（空なら下の「別名だけ」）で A の根を探す（パッケージ側）、同時に今の手順で根を探す（根の側。見つからないことを誤りにしない形で判定する。今の手順は誤りを返すので、「あるかどうか」だけを返す補助の関数に分ける）。
   - 両方にある → **両方の正規化したパスが同じファイルなら衝突としない**（パッケージとして読む）。推す案。理由: 根の下の `Textkit/` にパッケージを写して置き、`dependency Textkit path "Textkit"` と書く形（Skill のディレクトリ）で、すべての import が誤りになるのを避ける。違うファイルなら E0918。
   - パッケージ側だけ → パッケージのモジュール。根の側だけ → 今のとおり根のモジュール。どちらもない → E0318（注記 `package` を付ける）。
   - `import A`（別名だけ）→ パッケージ側はモジュールを指さないので、根の側の `A.bnt` があればそれ、なければ E0318 に注記 `package`。
4. それ以外 → 今のとおり。
- 実行を始めるファイルの取り込みの判定（E0320）はパッケージのモジュールにも当てる。
- `Benitoite` の前例の注記（`find.rs:219-230`）は変えない。

### 警告の扱い

- 推す案: **パッケージのモジュール（`Package`）と依存の `package.bnt` の中の警告は示さない**。誤りは示す。`--deny-warnings` もそれらの警告に効かない。理由: 標準ライブラリと同じく、利用者はパッケージのソースを直せず、依存の警告で `--deny-warnings` の検査が止まるのを避ける（02-10「警告の扱い」の最後の項目と揃える）。
- 実装: 今は `pipeline::append_stage`（`pipeline.rs:302-322`）が `SourceKind::Prelude` のファイルの警告を除く。`SourceKind`（`base/source.rs:11-14`）は変えず、`check_stages`（`pipeline.rs:249-300`）で読み込みの直後に「警告を示さないファイル ID の集合」（`Package` と依存の `Config` のモジュールの ID。ID はファイル ID と同じ）を作り、`append_stage` に渡す。`deny_warnings` の適用はその後なので、順は今のまま（`pipeline.rs:282-291`）。
- 02-10「警告の扱い」と 06-09 に書く。テストは `pipeline` の単体テスト（`pipeline.rs:662-` の既存のテストの隣）か、ゴールデン 1 件（パッケージの中に `W0401` を起こす定数式の除算を置き、終了 0 で何も出ないこと）。

### 設計書（W2 が直す節）

| 章 | 節 | 内容 |
|---|---|---|
| 01-03 | モジュールと import（初回リリース版） | 取り込める範囲に依存のパッケージを加え、同一性の文を「根のモジュールは根からの名前、依存のモジュールは別名とパッケージの根からの名前」に改める（C6 の 2） |
| 01-03 | 新しい節「依存のパッケージの取り込み」（W1 の節の後） | 取り込みの名前、パッケージの中の import、衝突（同じファイルなら衝突としない）、別名とパッケージの名前、依存の依存を許さない |
| 02-01 | 段と段の間のデータ | 依存の `package.bnt` とパッケージのモジュールを読み込みの段が読むこと |
| 02-02 | ソースとファイル ID | 依存の `package.bnt` の読む順 |
| 02-04 | モジュールの表、モジュールの探し方 | 種類に「依存のパッケージのモジュール」、探し方の手順に依存の別名の分岐 |
| 02-10 | 警告の扱い | パッケージの中の警告 |
| 06-09 | 新しい節（パッケージの構成、依存の解決） | 根の外を指せる `path`、パッケージに含めるものの説明（W3 の一覧を参照） |

### テスト（ゴールデン `testdata/packages/`）

- 形 1 の Textkit（`run`。`deps/textkit/` を根の下に置く）と、根の外の Textkit（`run`。`path "../libraries.files/textkit"`）。例の `Slug.bnt` を写す（日本語のコメントは英語にしなくてよいが、テストの入力は短くする）。
- Todo とハンドラ（`test`。ケースのディレクトリに `main.bnt` と `deps/todo/`。`File.readText` を `handle` で差し替える `runnable/tests.bnt` の `loadReadsTasks` を写す）。`test <ディレクトリ>` なので、W1 の「`package.bnt` を持つ下のディレクトリを除く」規則が要る（C6・W1）。
- 依存を根の `package.bnt` に書くケース（`run`）。
- 同じ名前のモジュールの区別: 根の `Slug.bnt` と依存の `Textkit.Slug` を `as` で両方取り込み、別の関数を呼べること（`run`）。
- 誤り: E0916・E0917（2 種）・E0918・E0318 の注記 `package`（パッケージから根のモジュールを取り込もうとした）・依存の `package.bnt` の E0914・E0915・E0907。
- 根の下に写したパッケージ（`Textkit/` と `path "Textkit"`）が衝突にならないこと（`run`）。
- 警告を示さないこと（上）。
- 印: `// spec: 01-03 依存のパッケージの取り込み` など、W1・W2 で作った見出しの名前に合わせる。

### 完了の条件（共通のものに加えて）

```sh
cargo test -p benitoite --lib modules
cargo test -p benitoite --lib pipeline
cargo test -p benitoite --lib resolve
cargo test -p benitoite --test test_command
BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=testdata/modules/ cargo test -p benitoite --test golden
python3 tools/spec-coverage/spec_coverage.py
```

## W3 への補足

### Go の dirhash（一次資料で確かめた事実）

出典: `golang.org/x/mod/sumdb/dirhash` の `hash.go`（https://github.com/golang/mod/blob/master/sumdb/dirhash/hash.go 、2026-10-13 に確かめた）。

- `Hash1` は `"h1:"` に、要約の SHA-256 を base64 で書いたものを続ける。要約は、ファイル名を `slices.Sort`（バイト列の順）で並べ、ファイルごとに「中身の SHA-256 の 16 進（小文字。`%x`）、空白二つ、ファイル名、改行（U+000A）」の一行を並べたもの。ドキュメントは `sha256sum $(find . -type f | sort) | sha256sum` と同じと説明する。改行を含むファイル名は誤り。
- `HashDir` はファイル名の前に `prefix`（モジュールのパスと版）を付ける。`DirFiles` はディレクトリの下のファイルをすべて集め、区切りを `/` にする。
- 同じリポジトリの `zip/zip.go`: モジュールの zip は「シンボリックリンクとほかの普通でないファイルを許さない」「二つのパスが Unicode の大文字小文字の畳み込み（`strings.EqualFold`）で等しくてはならない」。上限は `MaxZipFile = 500 << 20`（zip とその展開した中身）、`MaxGoMod = 16 << 20`、`MaxLICENSE = 16 << 20`。

### Benitoite の計算の形（06-09 にこのまま書ける案）

1. パッケージの根の下のファイルのうち、含めるもの（下の一覧）を集める。パスはパッケージの根からの相対パスを `/` で区切った UTF-8 の文字列とする。
2. パスを UTF-8 のバイト列の辞書順に並べる。
3. ファイルごとに「中身の SHA-256 を小文字の 16 進で書いた 64 文字、空白（U+0020）二つ、パス、改行（U+000A）」の一行を作り、この順につないだバイト列を要約とする。中身はバイト列のまま読み、改行を変換しない。
4. 要約の SHA-256 を小文字の 16 進で書いた 64 文字の前に `sha256:` を付けたものを、パッケージのハッシュとする。

Go の `h1:` との違いは、名前の前の `prefix` がないこと、要約のハッシュを base64 でなく 16 進で書くこと、接頭辞が `sha256:` であること、含めるファイルを許す一覧で決めることの四つだけである。理由: 同じ形にすると `sha256sum` で外から確かめられる（パッケージの根で `sha256sum <並べたパス…> | sha256sum` の出力の先頭 64 文字と一致する）。06-09 にこの確かめ方を書き、単体テストの固定値もこの方法で求めて、テストのコメントに手順を書く（実装で求めた値を期待値にしない）。

### 含めるファイルと誤り

- 含める（R10）: 名前が `.bnt` か `.wasm` で終わるファイル（大文字小文字を区別する。import と `@external` のパスが区別するため）、名前が `LICENSE`・`COPYING`・`README` で始まるファイル（ASCII の大文字小文字を区別しない。`License.md`・`readme.md` もよくあるため）。深さは問わない。`package.bnt` は `.bnt` に含まれる。
- 推す追加: 名前が `.` で始まる項目（`.git/` など）は辿らず含めない。R10 にないので、了承してから渡す。注意: `rust/target/` の下のビルドの生成物の `.wasm` も一覧に当たる。R10 は `rust/` を「パッケージの一部としない」と書くが、許す一覧の方式では除けない。(a) そのまま含め、06-09 に「ビルドの生成物はパッケージの外に置く」と書く、(b) 辿るディレクトリを、import で辿れる名前（大文字の識別子）のディレクトリと `wasm/` に限り、W4 の `@external` のパスもその範囲に限る、のどちらかを W3 の前に決める。(b) は「処理系が読みうるファイルだけを確かめる」と揃うが、W4 の規則が増える。
- 誤り（`hash` を書いた依存だけで起きる。E0920 の注記）:
  - `symlink`: シンボリックリンク（含めるか否かによらず、辿る範囲のすべての項目）。
  - `case`: 含めるファイルの二つのパスが、`str::to_lowercase` で同じになる（Go の `EqualFold` に近い。06-09 には「Unicode の小文字にした形が同じ」と書く）。
  - `name`: 改行を含むパス（UTF-8 でない名前は下の制約を参照）。
  - `too_many`・`too_large`: 上限（下）。
  - `read`: 読めないファイル、普通のファイルでないもの。
- 空のディレクトリは無視する。実行の属性は見ない。

### `ModuleFs` だけで書く方法と、その限界

- `ModuleFs`（`src/modules/mod.rs:121-157`。10-04 で凍結。メソッドを足すことは了承の表にない）は `read_file`・`list_dir`・`canonicalize` だけを持つ。ハッシュの計算もこれだけで書く（`check_files` の `MemoryFs` で単体テストもできる）。
  - シンボリックリンクの判定: パッケージの根を正規化したうえで、`fs.canonicalize(dir.join(name)) != 正規化した dir.join(name)` なら誤りとする（`RealFs::canonicalize` は `std::fs::canonicalize`）。
  - 中身: `fs.read_file`（`RealFs` は `read_regular_file` で普通のファイルだけを、1 ファイル 256 MiB（`MAX_SOURCE_BYTES`）までで読む。`base/file_read.rs:17-32`）。
- 限界: `RealFs::list_dir` は UTF-8 でない名前を黙って飛ばす（`mod.rs:139-141`）。このため R10 の「UTF-8 として正しくない名前は誤り」を実装できない。飛ばした名前のファイルは、import（大文字の識別子）でも `@external` のパス（文字列リテラル、UTF-8）でも読めないので、ハッシュに入らなくても確かめていない中身を処理系が読むことはない。推す案: R10 のこの項目を「処理系はそうした名前のファイルを読まず、ハッシュにも含めない」に改める（decisions.md の R10 を直してから渡す）。誤りにすることを保つなら、`ModuleFs` にメソッドを足す了承が要る。
- 読む中身とハッシュで確かめた中身の間で、ファイルが書き換えられうる（読み込みのモジュールは後でもう一度読む）。手元のパスの依存で、書き換えられる者は処理系の外で何でもできるので、この改造では扱わない。06-09 に一文書く。

### 上限

- 推す値: ファイルの数 10,000、含めるファイルの大きさの合計 128 MiB。1 ファイルは今の読み込みの上限（256 MiB）に従う。
- 理由: Go はモジュールの展開した中身を 500 MiB に限る。Benitoite は手元のパスの依存を検査のたびにハッシュするので、時間が検査の度に掛かる。パッケージの中身はスクリプトと小さなコンポーネント（例の Fuzzy は数百 KB と見込む。W4 で確かめる）なので、128 MiB でも十分に大きい。
- W3 の中で、128 MiB のパッケージのハッシュの時間を release のビルドで一度測り、報告と 06-09 に書く（値が大きすぎれば下げる）。`sha2` は `default-features = false, features = ["alloc"]`（`Cargo.toml:34`）で、速さは確かめていない。

### 置き場所と呼ぶ時点

- `src/modules/hash.rs`（非公開）: `pub(super) fn package_hash(fs: &dyn ModuleFs, root: &Path, limits: HashLimits) -> Result<String, HashError>`。走査は明示の積み重ね（AGENTS.md「再帰の深さ」）。`sha2::{Digest, Sha256}` は `builtins/funcs/hash.rs:3` と同じ使い方。
- 呼ぶ時点: W2 で依存の `package.bnt` を読んだ直後（モジュールを読む前）。`hash` を書いた依存だけ。食い違えば E0919（主な位置は記述の `hash` の値、注記に期待した値と計算した値、別名とパッケージの名前）。食い違ったパッケージのモジュールは読まない（誤りの後に名前解決へ進まないので、読んでも害はないが、無駄な誤りを増やさない）。
- `test <ディレクトリ>` では入口ごとに検査するので、ハッシュも入口ごとに計算し直す。この改造では覚えておかない（06-09 に書かなくてよい）。

### 設計書（W3 が直す節）

06-09 に新しい節「中身のハッシュ」（含めるファイル、計算の形、誤り、上限、`sha256sum` での確かめ方）。01-03 の W1 の節に「`hash` を書いた依存は読み込みのたびに中身を確かめる」の一文と 06-09 へのリンク。02-10 の E09 の行の例に加える。

### テスト

- 単体（`modules::hash` の `#[cfg(test)]`）: 固定の入力（`MemoryFs` か一時ディレクトリ）で値が変わらないこと（期待値は `sha256sum` で求める）、含める一覧（`.bnt`・`.wasm`・`LICENSE`・`readme.md`、含めない `wit/x.wit`・`rust/src/lib.rs`）、大文字小文字だけ違う二つのパス、シンボリックリンク（一時ディレクトリに `std::os::unix::fs::symlink`。ゴールデンにシンボリックリンクを置かない）、小さな上限を渡して `too_many`・`too_large`。
- ゴールデン（`testdata/packages/`）: 正しい `hash` で `run` が通るケース、食い違いの E0919 のケース。期待値のハッシュは、ゴールデンのファイルが変わると変わるので、パッケージのファイルを小さくし、`.gitattributes` の改行の変換の影響を受けないこと（今の対応環境は macOS と Linux だけ）を確かめる。

### 完了の条件（共通のものに加えて）

```sh
cargo test -p benitoite --lib modules::hash
cargo test -p benitoite --lib modules
BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden
cargo build --release -p benitoite   # 上限の大きさのハッシュの時間を一度測る
```

## 作業の間の依存

- W1 → W2 → W3 の順に直列に行う（plan のとおり）。
- W1 が作り、W2・W3 が使うもの: AST の `Module.header`、`ModuleKind::Config` と「入口の直後に `package.bnt` を読む」読み込みの形（C1・C2）、`modules/package.rs` の検査の関数（`package` のブロックを持つ `package.bnt` の規則は W2 で依存にもそのまま当てる）、E09 の区分と E0901〜E0915。
- W2 が作り、W3 が使うもの: 依存の表（正規化した根、`hash` の値、記述の位置）と、依存の `package.bnt` を読んだ直後の位置（ハッシュを確かめる時点）。
- W1 のゴールデンの依存の記述は、W2 で実際に読まれる。W1 の時点で実在するパッケージを指すように作っておく（W1 のテストの節）。W2 で E0916・E0917 が出るようになったゴールデンを書き直すことになったら、W2 の報告に差分を書く。
- 渡す前に決めること（オーケストレータ）:
  1. 凍結した型の表で、10-04 の `ModuleKind` の列挙子の追加に W1 を加える（C1）。
  2. `test <ディレクトリ>` で `package.bnt` を持つ下のディレクトリを除くか（W1）。
  3. `language` の二か所の誤り（E0911 に含める推す案）、`package` のブロックの欄を `license` だけにする推す案（W1）。
  4. 依存の `path` に絶対パスを許すか（W2）。根の下に写したパッケージで同じファイルなら衝突としない推す案（W2）。
  5. ハッシュで `.` で始まる項目を辿らないこと、`rust/target/` の `.wasm` の扱い（a か b）、UTF-8 でない名前の扱い（R10 の改め）、上限の値（W3）。
  6. モジュールごとの根の実パスを後の段へ渡す欄（W4 で扱う推す案。C6 の 6）。
- W4 との境界: E09 は W1〜W3 で使い切り、W4 は E08・E10 を使う。W4 は `ModuleKind::Package` のモジュールの `@external` のパスの基準に、W2 の依存の表を要する。
