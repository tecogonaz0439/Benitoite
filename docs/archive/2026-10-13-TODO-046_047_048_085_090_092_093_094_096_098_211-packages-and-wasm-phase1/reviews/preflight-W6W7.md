# W6・W7 の事前点検

対象: `san_benito`（2770e321。W1〜W5 と Z1〜Z3 を取り込んだ時点。W5 のレビュー（Z4）はまだない）。パスは `crates/benitoite/` を省く。行番号はこの時点のもの。リポジトリのファイルは変えていない。

（共通の補足）

### C1. 前提として確かめた事実

| 項目 | 事実 |
|---|---|
| 先頭の部分の構文木 | `ast::Module.header: Vec<HeaderItem>`（ソースの順）。`LanguageDecl.span`（語から文字列の終わりまで）、`HeaderBlock.span`（`dependency` から `end dependency` まで。`p.span_from(start)`）、`HeaderBlock.name: Name`（span 付き）、`HeaderField.span`（欄の名前から文字列の終わりまで）、`StrArg { span, value }` を持つ（`src/syntax/ast.rs:39-76`）。コメントは構文木に入らず、字句解析の `lexed.comments`（`token::Comment { span, kind, text }`）にある。`Module.doc` は `//!` の span を持つ |
| 先頭の部分の語と検査 | `src/syntax/header.rs` に語の定数（`DEPENDENCY_FIELDS = [path, hash]` など）、`keyword()`、`valid_hash()` がある。`src/syntax/parser/header.rs` は欄の誤り（E0901〜E0906）を報告する |
| 整形器 | `cli::tools::formatter::format_source(file, kind, bytes) -> Result<Formatted, FormatError>` はバイト列全体を整形する。先頭の部分の役割は `roles/walk.rs:288-305`。規則は 06-03「字下げ」（欄は一段深く、`end` は開きと同じ段）と「空の行」（項目どうしと、最後の項目と最初の import・宣言の間に空の行をちょうど一つ）。改行は LF にする（06-03 の 129 行） |
| ファイルの置き換え | `formatter::replace_file(path, display, content)`（`formatter/mod.rs:291`）は、一時ファイル（0600、`create_new`）→ 許可の写し → rename を行うが、診断は **E0125 に固定**（文言 "cannot write formatted file"、説明も `benitoite fmt` 専用）、一時ファイルの名前も `.fmt-<pid>` に固定である |
| ハッシュ | `modules::hash` は非公開のモジュール（`mod hash;`）で、`package_hash(fs, root, HashLimits) -> Result<String, HashError>` は `pub(super)`。誤りから診断を作る処理は `modules::package::check_hash`（`package.rs:24-84`）が `hash` の欄の位置に結び付けて行う |
| 依存の根 | `modules::package::dependency_location(entry, fs, block)`（`pub(crate)`）が `path` を正規化し表示の根と組で返す |
| コンポーネントの検証 | `external::check_component(engine, bytes)`（`pub(crate)`。コメントに「検査とパッケージの報告で共有する」とある）と `external::path::resolve_path(fs, root, path, Some(package))`（`pub(crate)`）、`external::engine_config()` がある。W4 の時点で W6 から使う前提で作ってある |
| 文字列リテラルの書き出し | `base::literal::quoted(chars, '"')` が `\`・`"`・`$`・制御文字を逃がす（`src/base/literal.rs:28`）。依存の `path` を書くときに使える |
| 組み込みのエフェクトの表 | `types::builtin::BUILTIN_EFFECTS`（`module` は `Benitoite` を除いた段、`name`、`in_io_all`）。`State` と `IO.All` も表にある |
| 読み込み | 依存の読み込みと検査（E0914〜E0917・E0919・E0920・E0922）は `modules::load::load_with_limits` の中に直接書いてあり、関数に分かれていない。`ModuleFs` は公開のトレイトなので、呼び出し側で上書きの層を作れる |

### C2. どの作業にも当てはまる注意

- W5 のレビュー（Z4）が `CHANGELOG.md`・03-10・02-09 などを直すなら、W6 はその後に始める（下の「作業の間の依存」）。
- `docs/ja/` は直さない（リリースのときに訳し直す。AGENTS.md の表）。
- 新しいテストは test-audit の作成時の関門を通し、作業の ID を名前に付けない（plan.md の共通の決まり）。

## W6 への補足

### W6-1. 命令の形と名前（R13 の名前は仮）

06-01 の既存の形と比べた結果、次の形を推す。

```text
benitoite package add    [オプション] <別名> --path <ディレクトリ> [<根か入口>]
benitoite package update [オプション] [<別名>] [<根か入口>]
benitoite package move   [オプション] <入口>
```

- 動詞を第 2 引数に置く形は `skill install|uninstall` と同じである。名前は `add`・`update`・`move` のままでよい（既存の命令と衝突しない）。最終的な名前は設計者に確かめる（「設計者に尋ねること」の 6）。
- `--path <ディレクトリ>` と `--path=<ディレクトリ>` の両方を受け付ける（`skill` の `--agent` が両方を受け付ける。`skill/mod.rs:280-296`）。オプション `--diagnostics=text|json` も受け付ける（ソースと依存の診断を出すので、`fmt` と同じく JSON の形が要る）。
- `<根か入口>` は `run` と同じく、ファイルなら入口、ディレクトリなら根とする。ディレクトリのときは `main.bnt` があればそれを入口とし、なければ入口なし（根の `package.bnt` だけを扱う）とする。省けば作業ディレクトリを根とする。`package.bnt` そのものを指したら、そのディレクトリを根とする（`run` の E0913 とは違い、ここでは受け付ける）。
- `update` の引数が一つのときの見分け方: 大文字で始まる識別子（`/` も `.` も含まない）なら別名、ほかはパスとする。識別子の形のパスは `./Name` と書く。これは 06-01「`run` を省いた実行とシェバン」の `./check` と同じ決まりである。
- `move` の `<入口>` は必須にする（取り違えるとファイルを書き換えるため）。

### W6-2. CLI の解釈の置き場所

- `src/cli/mod.rs`: `ToolCommand` に `Package` を足す（10-13 の了承の範囲。`Command` は変えなくてよい。`Command::Tool { tool, args }` で運べる）。`parse_args` の `match name`（186 行付近）に `"package" => Some(ToolCommand::Package)` を足し、`RESERVED_COMMANDS`（74 行）から `"package"` を消す。モジュールの先頭の `//!`（1 行目の「初回リリース版のサブコマンドは…」）と `text::USAGE` に `package` の 3 行を足す。
- `src/cli/tools.rs`: `run_tool` に `ToolCommand::Package` の分岐を足し、`run_body(package::text::STAGE_PACKAGE, …)` で包む（panic 境界と `BENITOITE_DEV_PANIC=tool` の扱いが他の道具と揃う）。
- 新しいモジュール `src/cli/tools/package/`（`mod.rs` に引数の解釈・命令の本体・`text`、`edit.rs` に先頭の部分の書き換え、`effects.rs` にエフェクトとコンポーネントの集計、`tests.rs`）。引数の形が `PathArgs` と違うので、`args.rs` を広げず `skill` と同じく自分で解釈する。
- `parse_args` の単体テスト（`cli/mod.rs:925` 付近に予約の名前のテストがある）に、`package` が `Tool` に振り分けられることを足す。`server` のテストは残す。

### W6-3. 先頭の部分だけを書き換える方法（字句の位置で継ぎ合わせる）

構文木は先頭の部分の項目と欄の位置を持つので、**バイト列の範囲を置き換える**形で書き換える。整形器でファイル全体を整形し直さない（ほかの字句とコメントを保つため）。

1. 書き換える前に、対象のファイルを `lex` → `resolve_newlines` → `parse` で読む。字句か構文の誤り（`formatter::is_syntax_error`）があれば書き換えず、診断を出して終える（`fmt` と同じ扱い。06-01「`fmt` のコマンドライン」）。E0901〜E0906 だけなら書き換えてよい（`update` が E0906 の誤った `hash` を直せるように）。
2. 「先頭の部分の範囲」を次のように決める。
   - 項目があるとき: 始まりは最初の項目の行の頭。ただし、その直前に空の行を挟まずに続くコメントだけの行は範囲に含める（項目の説明のコメントを一緒に扱う）。終わりは最後の項目の `span.end` の行の末尾（同じ行の行末のコメントを含む。`lexed.comments` の span で見る）。項目の間にはコメントと空の行しかない（文法がそう決める）ので、範囲には項目とコメントと空の行だけが入る。
   - 項目がないとき: 挿入の位置は、シェバンの行と `//!` の行（`Module.doc`）とその後の空の行の後で、最初のコメント・import・宣言の前とする。
3. 範囲の文字列に変更を加えた後、**範囲だけを独立したソースとして** `format_source(file, SourceKind::User, 範囲)` で整形し、元の位置へ戻す。範囲には先頭の部分の項目とコメントしかないので、`package.bnt` と同じく単独で解析・整形できる。新しいブロックはこれで整形器の形（欄を 2 文字字下げ、項目の間に空の行一つ）になる。整形に失敗したら（`FormatError`）処理系の不具合として終了状態 3 にする。
4. 範囲の前後の空の行を整える: `//!` かシェバンと範囲の間は空の行一つ、範囲とその後の最初の行（コメント・import・宣言）の間は空の行一つ、後に何もなければ改行一つで終える（06-03「空の行」と同じ）。
5. ファイルが CR LF を使っていれば（範囲の外の最初の改行で判断）、戻す範囲の改行も CR LF にする。整形器は LF にするので、そのまま戻すと一つのファイルに二つの改行が混ざる。
6. 書いた後の文字列をもう一度 `parse` し、字句・構文の誤りがなく、先頭の部分の項目が期待どおり（加えた別名・書いた `hash`）であることを確かめる。合わなければ書かずに処理系の不具合とする。

新しいブロックの文字列は次の型板で作る（`text` に置く）。値は `base::literal::quoted(s.chars(), '"')` で逃がす。`path` が UTF-8 でなければ使い方の誤りにする。

```text
dependency {alias}
  path {path}
  hash {hash}
end dependency
```

`update` は `hash` の欄の `StrArg.span` だけを置き換える（欄がないときは、`end dependency` の前に `hash` の行を足して上の 3〜6 を通す）。`StrArg.span` が引用符を含むかは、実装の初めに単体テストで確かめる（字句の span は文字列の字句全体のはず）。

単体テスト（`tools/package/tests.rs`）で次を確かめる: 範囲の外のバイト列が変わらないこと、コメント（範囲の中・前・行末）が残ること、整形済みの入力から作った出力に `format_source` を当てても変わらないこと（整形済みのファイルは整形済みのまま）、CR LF の入力、`//!` だけのファイルと空のファイル。

### W6-4. 書き込み先と書き方

- `add` の書き込み先（R13）: 入口の先頭か `package.bnt` のどちらかに `dependency` があればそこ、どちらにもなければ `package.bnt` があればそこ、なければ入口とする。入口がなく `package.bnt` もなければ誤り（新しい診断。「入口を指定する」よう示す）。`package.bnt` に `package` のブロックがあるとき（パッケージの根）は、依存の依存を許さないので誤り（E0915 と同じ理由。読み込みで検証すれば E0915 が出る。下の W6-5）。同じ別名が既にあれば誤り。
- 書き込みは `replace_file` と同じ手順を使う。ただし今の関数は E0125（`fmt` 専用の文言と説明）に固定なので、**手順を共有の関数に切り出し、診断のコードと一時ファイルの接尾辞を引数にする**か、`package` 用に E01nn の新しいコード（例: E0126 "cannot write `{path}`"）を足して同じ手順を通す。E0125 の文言は変えない（ゴールデンと Skill の生成物が変わるのを避ける）。
- `move` で `package.bnt` を新しく作るときは、`replace_file` は元のファイルを前提にするので使えない。同じディレクトリに一時ファイルを書いてから `std::fs::hard_link(一時, package.bnt)`（既にあれば失敗する）→ 一時ファイルを消す、の形にすると、途中で止まっても壊れたファイルを残さず、並行して作られたファイルも上書きしない。許可は入口のファイルの許可を写す。
- `move` は二つのファイルを書く。順は `package.bnt` → 入口とし、入口の書き込みに失敗したら `package.bnt` を元のバイト列に戻す（新しく作ったなら消す）。戻せなかったときは、両方に記述がある（次の検査で E0911 になる）ことを診断に書く。
- 中断の要求は `fmt` と同じく特別に扱わない（06-01「終了状態」の最後の段落）。

### W6-5. 依存の検証（書く前に、読み込みと同じ検査を通す）

依存の読み込みの検査は `load_with_limits` の中に直接書いてあるので、検査を写さず、**書き換えた後のバイト列を見せる `ModuleFs` の上書きの層**を作って `modules::load_program` を通すことを推す。

- 上書きの層は、対象のファイル（入口か `package.bnt`）のパスにだけ新しいバイト列を返し、ほかは `RealFs` に委ねる。入口がないとき（根に `package.bnt` だけがある）は、根の下の使われていない名前の空の入口を仮に見せる（`package.bnt` は入口にできないため。E0913）。
- 出た診断のうち、主な位置が書き換えたファイルの新しいブロック（`add`）か対象の依存のブロック（`update`）の中にあるもの、または依存の `package.bnt` の中にあるものだけを見て、誤りがあれば書かずに終える。入口のほかのモジュールの誤りは見ない（依存と関係のない誤りで `add` を止めない）。
- これで E0914〜E0917・E0919・E0920・E0922（根や他の依存との重なり）と、`package` のブロックのある設定への依存（E0915）が、読み込みと同じ規則で確かめられる。

`--path` の値を何を基準に解くかは決まっていない（「設計者に尋ねること」の 3）。推す案は「記述の `path` と同じく根からの相対パスとし、書いた文字列をそのまま記述に写す」である。

### W6-6. ハッシュの計算の使い回し

- `modules::hash::package_hash` を `pub(crate)` の入口（例: `modules::package::compute_hash(fs, root) -> Result<String, HashError>`）から呼べるようにする。`HashError` から診断を作る部分（`check_hash` の `Err` の分岐）を関数に切り出し、`hash` の欄の位置がない場合（`add` の前）は主な位置なしの E0920 にする。
- 計算できない（シンボリックリンクなど）ときは、`add` も `update` も書かずに E0920 で終える。
- エフェクトの集計（W6-7）が読むファイルの一覧も、ハッシュと同じ辿り方（`hash.rs` の走査）から得る。走査を「含めるファイルの相対パスの一覧を返す関数」と「一覧からハッシュを計算する関数」に分ければ、ハッシュの対象と集計の対象が一致する（`package.bnt` と `wasm/` の下を除いた `.bnt` が集計の対象）。

### W6-7. エフェクトとコンポーネントの表示

R13 は「パッケージのすべての `.bnt` を読み、公開の関数の `uses` に現れるエフェクトの和」を示すとする。実装の方法は二つある。

| 方法 | 内容 | 評価 |
|---|---|---|
| A. 宣言を読む（推す） | 各 `.bnt` を字句解析・構文解析し、`public` のトップレベルの関数（`@external` を含む）と `public` の型クラスのメソッドの宣言の型から、`uses` と、引数・戻り値の関数の型の `uses` に書いたエフェクトの名前を集める。名前の修飾子（`File`）は、そのファイルの import（`as` の名前か最後の段）で引き、取り込んだモジュールの名前が `Benitoite.`（`Benitoite.Unofficial.` を含む）で始まり `BUILTIN_EFFECTS` の項目に当たれば組み込みのエフェクトとする。`State`・`IO.All` は import なしで当たる。エフェクト変数（`[effect E]`）と、利用者が定義したエフェクトは組み込みに数えない | トップレベルの関数の型は宣言に書く（推論しない）ので、型が持つエフェクトはこの集計と一致する（本体のエフェクトは型検査が宣言に含まれることを確かめる）。パッケージに型の誤りがあっても示せる。組み込みのエフェクトのモジュールは `as` で別名にできない（E0339）ので、修飾子から一意に決まる |
| B. 型検査する | 上書きの層で、パッケージのすべてのモジュールを import する仮の入口を作り、`pipeline::check` を通して型を読む | 名前解決の結果を使えるが、仮の入口が要り、パッケージに誤りがあると何も示せない。D15 の理由の文は B を想定していた |

A を推す。表示する名前は、利用者が `uses` に書く形（`Console.Write`・`File.Read`・`State`・`IO.All`）にし、`IO.All` は展開しない。どちらにするかは「設計者に尋ねること」の 4 で確かめる。

- 字句か構文の誤りのある `.bnt` がパッケージにあれば、集計が欠けるので、診断を出して書かずに終える（設計原則 2: 契約の見落としを作らない）。
- コンポーネントの一覧: すべての `.bnt` の `@external` の宣言のパスを集め（重複を除き、パスの辞書順）、各々を `external::path::resolve_path(fs, パッケージの根, path, Some(パッケージの名前))` で解き、`external::check_component(&Engine::new(&engine_config())?, bytes)` で取り込みが空かを確かめる。結果は「`wasm/fuzzy.wasm` (no imports)」か「`wasm/x.wasm`: <理由>」の行で示す。コンポーネントの誤りは `check` が使う側で報告するので、表示だけにして書き込みは止めない、を推す（止める案もある。設計者が決めてよい）。
- Cranelift でコンパイルするので、大きなコンポーネントでは時間がかかる（07-01 の 42 行の脅威と同じ）。

### W6-8. 出力の形と `update` の差

標準出力に、変えたファイルと結果を書く（`skill` が書き出した先を標準出力に書くのと同じ）。文はすべて `tools::package::text` の型板に置く。

```text
added dependency Fuzzy (package Fuzzy) to main.bnt
  hash: sha256:3f…
  effects: (none)
  components: wasm/fuzzy.wasm (no imports)
```

```text
updated dependency Todo (package Todo) in package.bnt
  hash: sha256:aa… -> sha256:bb…
  effects: + File.Write
           - Console.Write
  components: (none)
```

```text
moved language, dependency Textkit from main.bnt to package.bnt
```

- `update` で値が変わらなければ `unchanged` の行を書いて終了状態 0。
- **`update` の「前」のエフェクトを得る手段がない**。パッケージは手元のパスにあり、`update` を走らせる時点で中身は既に変わっている。前の中身もエフェクトもどこにも記録していない。ハッシュは同一性を示すだけで、前のエフェクトを復元できない。決め方は「設計者に尋ねること」の 1。
- パスに含まれる端末の制御文字は `escape_terminal_controls` で逃がす（`fmt` の `would reformat` と同じ）。
- `--json` は設けない（R13）。

### W6-9. `move` の意味

- 入口の先頭の部分の範囲（W6-3 の 2）を切り取り、同じディレクトリの `package.bnt` へ移す。`//!` の行は入口に残す。範囲の中のコメントは一緒に移る。
- 入口に先頭の部分の項目がなければ誤り（移すものがない）。
- `package.bnt` が既にあり、`language` か `dependency` を持つなら誤り（R13 と依頼のとおり。移すと E0911 になる）。`package` のブロックを持ち、移す項目に `dependency` があれば誤り（E0915 になる）。`package.bnt` にコメントや `package` のブロックだけがあるときは、その最後の項目の後（なければ先頭のコメントの後）に空の行一つを挟んで足す。
- 新しく作る `package.bnt` の中身は、範囲の文字列を W6-3 の 3 で整形したものに改行一つを足したものとする。
- 入口からは範囲とその後の空の行を除き、W6-3 の 4 で前後を整える。
- `package.bnt` を入口に指定したら誤り。

### W6-10. 終了状態と診断のコード

終了状態は `fmt` に揃えることを推す（06-01 に表を書く）。

| 値 | 場合 |
|---|---|
| 3 | 処理系の不具合 |
| 2 | 字句・構文の誤りのあるファイル、依存の検証の誤り、ファイルを読めない・書けない、使い方の誤り、命令の前提の誤り（別名の重複、別名がない、移すものがない、移す先に既に記述がある） |
| 0 | 上のどれでもない（`update` で変わらなかった場合を含む） |

診断のコード: 命令の前提の誤りは位置（別名・ブロック）を示せるものが多いので、診断にする。区分は 02-10 の `E09nn`（パッケージと依存）の空いた番号（E0923〜）を使い、02-10 の区分の表の説明に「`benitoite package` の命令の誤り」を足す。候補: 別名が既にある（前の記述の位置を示す）、別名がない（`update`）、`package` のブロックのある設定に依存を書けない（これは E0915 を使い回せるか確かめる）、移すものがない、移す先に記述がある、書き込み先を決められない。ファイルの書き込みの失敗は W6-4 のとおり。使い方の誤り（別名がない引数、`--path` がない、知らないオプション）は `usage_error`（文は `text` か `args::text`）。新しいコードを足したら `gen_skill` で Skill の診断の一覧を作り直す。

### W6-11. テスト

- ゴールデンの実行器（`tests/golden.rs`）の方式は `check`・`run`・`fmt`・`fmt-check`・`test` だけで（410 行）、ファイルを書き換える命令の結果を比べる仕組みは `fmt` 専用（`tests/golden/formatting.rs`。一時ディレクトリに写して `.formatted` と比べる）である。`package` の方式を足すより、**`tests/fmt_command.rs` と同じ形のプロセスのテスト `tests/package_command.rs`** を推す（`TestDirectory` で一時ディレクトリに根と依存を作り、`CARGO_BIN_EXE_benitoite` を起動して、標準出力・終了状態・書き換えた後のファイルの中身を文字列で比べる）。一時ディレクトリは Z3 の扱いに倣い `CARGO_TARGET_TMPDIR` の下に作るとよい。
- 確かめる場合: `add` で入口と `package.bnt` のそれぞれに書く・既にある記述の後に足す・コメントを保つ、`hash` の値が `sha256sum` の方法（06-09）で求めた値と一致する、エフェクトの表示（Todo の形: `File.Read`・`File.Write`。Fuzzy の形: コンポーネント 1 つ、取り込みなし）、`update` の差と変わらない場合、`move` の前と後で `check` の結果が同じ（往復）、各誤り（別名の重複、依存の `package.bnt` がない E0917、重なり E0922、構文の誤りのあるファイルを書き換えない、`move` の移す先に記述がある）、書き込みを拒む場合（読み取りだけのファイル）。
- 範囲の継ぎ合わせとエフェクトの集計は単体テスト（W6-3 の最後）。Fuzzy のコンポーネントは `testdata/` の既存のもの（W5）を写して使う。WAT から作るなら `wat`（テストだけの依存）を使える。

### W6-12. 文書

- 06-01: 新しい節「`package` のコマンドライン」（見出しに「（初回リリース版）」を付けない）に、形、書き込み先、標準出力、終了状態の表を書く。「コマンドラインの形」の箇条（`test`・`fmt`・`skill` の列挙）、「`run` を省いた実行とシェバン（初回リリース版）」のサブコマンドの名前の列挙、「標準入出力」と「終了状態」の冒頭の列挙に `package` を足す。「予約したサブコマンドの名前（初回リリース版）」は**見出しを変えず**（`cli/mod.rs:73` のコメントが引く）、本文から `package` を除き、「`package` は後に実装した」と一文で書く。
- 06-09: 新しい節「`benitoite package`」に、`add`・`update`・`move` の意味、書き込み先の選び方、ハッシュとエフェクトの表示、`move` の条件を書く。「目的と範囲」にも足す。
- 02-10: `E09nn` の区分の説明と、新しいコード。
- `docs/reference/benitoite.md` の 101 行「The names … `package` … are reserved」から `package` を除く（`reference_examples` の対象の文書なので、変えたら走らせる）。言語リファレンスの命令の説明は W7 で書く。
- `CHANGELOG.md` の Unreleased に一項目（英語）。

### W6-13. 完了の条件

```sh
cargo test -p benitoite --lib
cargo test -p benitoite --test package_command
cargo test -p benitoite --test fmt_command        # replace_file を切り出したとき
cargo test -p benitoite --test cli_process
cargo test -p benitoite --test verify
cargo test -p benitoite --test reference_examples # 101 行を直すので
python3 tools/spec-coverage/spec_coverage.py --self-test && python3 tools/spec-coverage/spec_coverage.py
# 以下、plan.md の共通の条件
cargo test -p benitoite --test golden
cargo test -p benitoite --test skill_docs
cargo test --test spec_examples
cargo run -q -p benitoite --example gen_skill && git status --porcelain -- crates/benitoite/skill
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
cargo fmt --all --check
```

## W7 への補足

### W7-1. 言語リファレンスの「実験的」の節

- 構成: `docs/reference/benitoite.md` は 1〜20 の番号付きの節と目次（22〜43 行）からなる。CHANGELOG が `#20-compatibility` を引くので番号を付け替えず、**「21. Experimental: packages and external functions」を末尾に足し、目次に一行足す**ことを推す。冒頭に、構文の見直しで書き方が変わること（Q7）を書く。12「Modules」の末尾に、依存の取り込みは 21 節を見るよう一文足す。
- 例の検査（`tests/doc_examples/mod.rs`）が受け付けるもの: `benitoite`（`run` して `output` と比べる）、`benitoite check`、`benitoite test`、`benitoite error`（`diagnostic` の各行を含むか）、`files`（例の前に置く。1 行目が `name: <名前>`、`/` を含めば途中のディレクトリを作る）。例は一時ディレクトリの `main.bnt` に書かれ、そこが根になる。`files` の中身は**文字列として書く**（`fs::write(path, content: String)`）ので、`.wasm` のバイナリは置けない。ほかの情報文字列（`text`・`sh`）は検査しない。
- したがって、パッケージの例は検査できる形で書ける。

  ````text
  ```files
  name: packages/textkit/package.bnt
  language "0.0.3"

  package Textkit
    license "MIT"
  end package
  ```

  ```files
  name: packages/textkit/Slug.bnt
  public function slug(text: String) -> String
    …
  end function
  ```

  ```benitoite
  dependency Textkit
    path "packages/textkit"
  end dependency

  import Benitoite.Unofficial.IO.Console
  import Textkit.Slug
  …
  ```
  ````

  - 依存のディレクトリは小文字の名前（`packages/textkit`）にする。大文字の `Textkit/` を根の下に置くと、`import Textkit.Slug` が根のモジュールとしても当たり、R16 の E0921 か E0918 になりうる（macOS の大文字と小文字を区別しないファイルシステムでも、探索は一覧の名前を比べるので `textkit` とは当たらない）。
  - `language` の値は処理系の版（`Cargo.toml` の `0.0.3`）以下にする。版を上げても古い宣言は通る（互換性を壊した版の表は空）。
  - `hash` は検査する例に入れない（例の文字列を直すたびに値が変わる）。`hash` の書き方は `text` のブロックで示す。
  - 根の `package.bnt` の例も `files` の `name: package.bnt` で書ける。
- `@external` の例は、`.wasm` を置けないので `text` のブロックにする（宣言と、対応する WIT の書き方の両方）。検査は `testdata/external/` のゴールデンが担う、と本文の外（先頭の HTML のコメントか、W7 の報告）に書く。`doc_examples` に WAT を変換する `files` の形を足す案もあるが、利用者の文書に WAT を載せることになり、W7 の範囲を超えるので推さない。
- `benitoite package` の使い方も `text` のブロックで書く（W6 の出力の形をそのまま写す）。
- 20「Compatibility」と実験的な機能の関係（パッチ版で変えてよいか）は決まっていない（「設計者に尋ねること」の 5）。
- Skill の手書きの部分（`SKILL.md`・`references/` の手書きの文書）には足さない（Q7）。生成物は `gen_skill` で作り直すだけ。

### W7-2. 00-03（ロードマップ）

- 「初回リリース版で宣言する保証」（27 行）は**見出しを変えない**（`docs/design/README.md:28` と 06-06 の 106 行が引く）。表の後に、R15 の文を【決定】で足す（例:「初回リリース版の後に実験的として加えたパッケージと外部の関数について、次の保証を加える。外部の関数は取り込みのない WASM のコンポーネントに限り、純粋な関数として型が付く。パッケージのエフェクトは公開の関数の型に現れる。手元のパスの依存は、`hash` を書いたときだけ中身を確かめる。操作の対象を実行時に絞る仕組みは持たない」）。
- 36 行の【決定】「初回リリース版には外部の関数の層を実装しないので…」は、外部の関数を実装した今は理由が成り立たない。「外部の関数は取り込みのないコンポーネントに限るので、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけであり、どれも IO 実行器を通す」に改める。
- 「自作する部分と既存の OSS を使う部分」: W4 が 89 行に【決定】の文を足してある。表に「WASM の実行系（Wasmtime）| 既存」「Benitoite の型と WIT の型の対応、境界の値の変換 | 自作」の 2 行を足し、89 行の文と重ねない形にする（どちらか一方でよい）。
- 「範囲」の表（「ツール」の行、「エフェクトと権限」の行の「契約の変更を処理系が表示する機能は含めず」）と 59 行の「含めない」の一覧は初回リリース版の記録である。01-02 の 927 行（「その後、「ファイルの先頭の部分」の構文を加えた」）と同じく、「初回リリース版の後に、実験的としてパッケージ（手元のパスの依存と `benitoite package`）と外部の関数を加えた」と一文で足す。
- 「#### 完了条件」の表は `tools/spec-coverage/spec_coverage.py` が読む（278 行）。形を変えない。00-03 を変えたら `spec_coverage` を走らせる（`check.sh` も 00-03 の変更でこれを選ぶ）。

### W7-3. 07-01（セキュリティモデル）

古い記述が三か所残っている。

- 7 行（目的と範囲）「外部の関数を呼ぶ層も、初回リリース版にはない」。
- 76 行（保証が成り立つ条件）「初回リリース版には、外部の関数を呼ぶ層も…ない」と、その後の「初回リリース版には、条件 3 が成り立たない経路はない」。
- 「各機構が保証すること」の表は「二つの行だけ」と書く。

R15 を受けて、表に「外部の関数」（保証: 取り込みのないコンポーネントに限り純粋な関数として型が付くので、外部に作用する操作を行わない。保証しない: 計算の結果の正しさ、停止（燃料の上限で止まる））と「パッケージ」（保証: パッケージのエフェクトは公開の関数の型に現れ、使う側の `main` の `uses` に現れる。`hash` を書いた依存は読み込みのたびに中身を確かめる。保証しない: `hash` のない依存の中身、操作の対象の絞り込み）の行を足し、「二つの行だけ」を直す。条件 3 については「外部の関数は取り込みを持たないので、IO 実行器を通らずに外部に作用する経路にならない」と書く。Wasmtime は「処理系が依存するクレート」（信頼する）に含まれる。

### W7-4. 00-04（用語集）

Z3 が足したのは「外部の関数」「コンポーネント」「WIT」「world」（160〜163 行）だけである。直すものと足すもの:

- 直す: 「外部の関数」の「呼び出しの経路は持たない」（W5 で呼べるようになった）。「根のディレクトリ」（175 行）の「import で取り込めるのはここより下のファイルと標準ライブラリに限る」（依存のパッケージも取り込める）。「モジュール、import」（174 行）の「名前は根のディレクトリからのパスで決まる」に、依存のモジュールは別名とパッケージの根からのパスで決まることを足す。
- 足す（依頼の語と、06-09・01-03・03-10 が使う語）: パッケージ、パッケージの根、依存（依存の記述）、依存の別名、設定ファイル（`package.bnt`）、言語の版（の宣言）、ファイルの先頭の部分、中身のハッシュ、実験的、燃料（fuel。03-10 と 02-09 が使う）。「実験的」の定義には、言語リファレンスでの扱い（構文の見直しで変わりうる）と、設計書でどの機能を指すかを書く。
- 置き場所は、構文に関わる語（ファイルの先頭の部分、依存の別名）を「構文と名前」、ほかを「全体」に置く。

### W7-5. 07-04「01-12 との対応」と形式化の検査（R11）

- 表に 2 行を足す（今はどちらの行もない）。
  - 「ファイルの先頭の部分（言語の版の宣言、依存の記述、`package` のブロック）と依存のパッケージのモジュール | 対象外（入力の時点で一意な名前に消えている。モジュールの行と同じ）」。
  - 「外部の関数（`@external`）| 対象外」。表現の違いの欄には、実装の事実を書く: W5 は `tests/desugar_export.rs:85-87` で、`resolved.externals` が空でないプログラムを**丸ごと**比較の入力から除き、`excluded: ["external function"]` とする（`tests/desugar_export/exchange.rs:1490,1616` も `ValKind::External` を未対応とする）。R11 が想定した「組み込みの関数と同じく仮定の欄として与える」形には**なっていない**ので、その文言を写さない。除いた入力は脱糖の差分・型検査の出力の検査（`surfaceCheckAll`）・網羅性の入力のどれにも入らない（`coverage_inputs` は除外の判定の後で積む）。
- `scripts/check-formal.sh` 自体は変える必要がない。R11 の「差分テストの入力の生成が壊れないこと」は、W7 で `cargo test -p benitoite --test desugar_export -- --include-ignored`（Rust の書き出しだけ。Lean は要らない。出力は `target/desugar-diff/`）を走らせて確かめることを推す。`testdata/packages/` のゴールデン（依存のパッケージのモジュールを含む）も書き出しの入力になるが、W2 以降 `desugar_export` は直していないので、ここで壊れないかを見る。Lean との比較は W8 の `check-formal.sh` で行う。
- `formal/` は変えない（R11）。

### W7-6. 目次、CHANGELOG、残っている古い記述

- `docs/design/README.md`: 03-10（75 行）と 06-09（91 行）の行はある。説明を、03-10 は「…取り込みと型の照合、実行と上限と失敗」、06-09 は「…依存の解決、パッケージの構成、中身のハッシュ、`benitoite package`」に直す。
- `CHANGELOG.md` の Unreleased: 先頭の 3 項目（Z1〜Z3 の直し）は、まだリリースしていない機能の直しなので、対応する機能の項目に溶かし込む。0.0.3 の節と同じく `### Added`・`### Incompatible changes`・`### Fixed` に分け、実験的な機能であることを明記する。**互換性を壊す変更**として次を書く: 根の直下の `package.bnt` を設定ファイルとして読むようになった（以前は無関係のファイルとして無視されたので、宣言を含む `package.bnt` がある根は E0912 になる）、`package.bnt` を `run`・`check`・`test` の入口にできない（E0913）、`test <ディレクトリ>` が `package.bnt` と、`package.bnt` を持つ下のディレクトリを除く。直し方も書く（ファイルの名前を変える）。`benitoite package` は以前は使い方の誤りだったので、互換性を壊さない。「A broken symbolic link…」は既存の振る舞いの直しなので `### Fixed` に置く。
- 初回リリース版の記録として正しいが、今の実装と食い違って読める記述（W7 で直すことを推す。どれも「初回リリース版は…含めない」の形。直し方は 00-03 と同じく「その後、実験的として加えた」と一文足すか、今の実装に合わせて書き換える）:
  - `docs/design/01-spec/01-03-names-modules.md:7`「初回リリース版は、外部の関数を呼ぶ層とパッケージを持たないので、それらの名前空間もない」（同じ章に「依存のパッケージの取り込み」がある）。
  - `docs/design/00-overview/00-02-architecture.md:27`・`:98`、`docs/design/03-interop/03-01-library-structure.md:9`、`docs/design/02-impl/02-04-resolver.md:5`、`docs/design/01-spec/01-09-errors.md:5`（W5 が外部の関数の失敗を足した章）。
  - `docs/design/07-quality/07-03-compiler-testing.md:8`「初回リリース版には外部の関数の層がないので、そのテストも持たない」（`testdata/external/`・`tests/external_signals.rs` がある）。
  - `docs/design/06-tooling/06-06-agent-skills.md:106`「処理系に、権限を表示する機能は加えない」と、00-03 の範囲の表の「契約の変更を処理系が表示する機能は含めず」: W6 の `package add`・`update` は依存のパッケージのエフェクト（とその差）を示す。権限の表示（`main` の `uses`）とは別のものだと分かるよう、06-09 への参照を一文足す。
- `docs/ja/` は直さない。

### W7-7. 完了の条件

```sh
cargo test -p benitoite --test reference_examples
python3 tools/spec-coverage/spec_coverage.py --self-test && python3 tools/spec-coverage/spec_coverage.py
cargo test -p benitoite --test desugar_export -- --include-ignored   # R11 の確かめ（Rust の書き出しだけ）
# 相対リンクの確かめ（設計書・リファレンスの新しいリンク）。既存の道具はないので、grep で張ったリンクの先があるかを見る
# 以下、plan.md の共通の条件
cargo test -p benitoite --test golden
cargo test -p benitoite --test skill_docs
cargo test --test spec_examples
cargo run -q -p benitoite --example gen_skill && git status --porcelain -- crates/benitoite/skill
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
cargo fmt --all --check
```

W7 がコードを変えないなら、clippy と fmt は省いてよい（変えたら走らせる）。

## 作業の間の依存

- W6 は W1（構文木の位置・整形器）、W3（ハッシュ）、W4（`check_component`・`resolve_path`）に依る。どれも取り込み済み。W5 のレビュー（Z4）が `CHANGELOG.md`・02-10・03-10 を直すなら、W6 はその後に始める（同じファイルを触るため）。
- W7 は W6 の後に行う。言語リファレンスの 21 節は W6 の命令の形と出力を写し、06-09・06-01・00-04 は W6 の文書を前提にし、CHANGELOG のまとめは最後の作業で行うのがよい。
- W8（`check.sh` と `check-formal.sh`）は W7 の後。W7 で `desugar_export` の書き出しが通ることを確かめておけば、W8 で Lean の側だけを見ればよい。
- W6 で「設計者に尋ねること」の 1（`effects` の欄を足す）を採ると、構文（01-02 の表）・06-09・Skill の文法の生成物も W6 で変わる。

## 設計者に尋ねること

1. **`update` の「前と後の差」の「前」をどこから得るか**（R13・Q6）。手元のパスのパッケージは、`update` を走らせる時点で既に変わっていて、前のエフェクトはどこにも残っていない。
   - A（推す）: `add`・`update` が依存の記述に欄 `effects "Console.Write, File.Read"` を書き、`update` はそれを「前」として差を示す。読み込みは欄を読むだけで照合しない（`hash` を書いた依存では、二つの欄を命令が同時に書くので食い違わない）。契約の変更が依存の記述の差分（git の差分）にも現れ、設計原則 2 に合う。欄を一つ足す（`DEPENDENCY_FIELDS`。構文木の型は変わらない）。
   - B: 差を示さず、`update` はハッシュの変化と今のエフェクトだけを示す（R13 を改める）。
   - C: 依存のブロックの中に命令がコメントで書き、`update` が読む。構文を変えないが、利用者が書き換えると壊れる。
2. **`update` を別名なしで走らせたとき、`hash` を書いていない依存をどうするか**。推す案: 別名なしでは `hash` を書いた依存だけを計算し直し、別名を指定したときは `hash` がなければ足す（Q5 で開発中の依存に `hash` を書かない使い方を認めたので、一括の更新でそれを壊さない）。
3. **`add` の `--path` の値の基準**。推す案: 記述の `path` と同じく根からの相対パス（または絶対パス）とし、書いた文字列をそのまま記述に写す。作業ディレクトリを基準にすると、根が作業ディレクトリでないときに相対パスを書き換えることになり、利用者の書いた形と変わる。
4. **エフェクトの集計の方法**（W6-7）。推す案は A（宣言を読む。型検査しない）。D15 の理由の文は型検査を想定していたが、トップレベルの関数の型は宣言に書くので結果は同じで、パッケージに誤りがあっても示せる。あわせて、利用者が定義したエフェクトを表示に含めるか（推す案: 含めない。組み込みのエフェクトだけを示す）。
5. **実験的な機能と言語リファレンスの 20「Compatibility」の関係**。今の方針は、パッチ版で言語を変えない、マイナー版の互換性を壊す変更は CHANGELOG に直し方とともに書く、である。推す案: 実験的な機能も同じ方針に従い（例外を作らない）、21 節の冒頭で構文の見直しで書き方が変わることを予告するだけにする。別案: 実験的な機能はどの版でも変えてよいと 20 に書く。
6. **命令の名前**。推す案は R13 の仮の名前のまま `add`・`update`・`move`。`move` は「パッケージを動かす」と読まれうるので、別の名前（例: `extract`）にするかを確かめたい。
