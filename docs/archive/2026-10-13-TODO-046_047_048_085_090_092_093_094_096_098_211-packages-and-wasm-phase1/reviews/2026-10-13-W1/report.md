# W1 のレビュー（f08567b2「Read the file header part and package.bnt (W1)」）

対象: `git show f08567b2`。検証は worktree（f08567b2 を detach）で `cargo build -p benitoite` した実行ファイルを、手で作った入力に対して走らせた。行番号は f08567b2 の時点のもの。パスは `crates/benitoite/` を省く。

## 総評

H（直さなければならない）に当たる所見はない。三つの形の構文、E0252 の検出、置き場所の規則（E0909〜E0915）、`ModuleKind::Config` によるファイル ID・モジュール ID・AST の添字のそろえ方、`test` の走査（Q9）、整形の往復と冪等性、版の比較は、decisions.md・plan.md・事前点検の補足に沿っている。凍結した型の変更は、了承の表の範囲（10-03 の AST の欄と型、10-04 の `ModuleKind::Config`）に収まる。本番のコードに `unwrap`・`expect`・添字はなく、コメントに作業の ID もない。

敵対的な入力で確かめて、既存のプログラムを壊す誤検出は見つからなかった。

- トップレベルは宣言しか書けないので、`function dependency()`、`function language(x: Integer)`、本体の中の `package` という名前（a2）、`import` で始まるファイル（a3）は、W1 の前と同じ結果になる。
- 関数の本体の中の行 `language "0.0.3"`（a9）は、先頭の部分の項目として読まない。
- シェバンや BOM の後に書いた `language` は読める。
- `///` を項目の前に書くと、既存の E0228 になる。
- `//!` を項目の後に書くと、既存の E0229 になる。
- Go の `package main`（a6）は E0201 になる。

直したほうがよい点（M）は四つある。診断の文言が二つ、ブロックの閉じ忘れからの回復が一つ、設計書の食い違いが一つである。

---

## M（直したほうがよい）

### M1. 取り込まれたモジュールの `package` に対する E0909 の文言が誤った書き方を勧める

- 場所: `src/modules/package.rs:44-50`（`check_header` の `ModuleKind::User` の枝）、`src/diag/codes.rs` の E0909。
- 問題: E0909 の文は "`{item}` can be written only at the start of the starting file or in `package.bnt`" である。`item` が `package` のときも同じ文になるので、「入口の先頭に書ける」と読める。しかし入口の先頭の `package` は E0910 の誤りである。利用者が文のとおりに入口へ移しても、E0910 で再び止まる。
- 再現: `testdata/packages/imported-header.diag.json` の 3 行目に、そのまま次の文が出ている。
  ```text
  "`package` can be written only at the start of the starting file or in `package.bnt`"
  ```
- 修正案（どちらか）: (a) `User` のモジュールの `HeaderItem::Package` には、E0909 の代わりに E0910（"a `package` block can be written only in `package.bnt`"）を出す。(b) E0909 を `language`・`dependency` だけに限ると説明に書く。(a) なら診断の表を増やさずに済む。ゴールデン `imported-header` を作り直す。

### M2. E0901 の注記が、使えない欄も「書ける欄」として並べる

- 場所: `src/syntax/parser/text.rs` の `DEPENDENCY_FIELDS`、`src/syntax/parser/header.rs:194-210`。
- 問題: 注記は "the fields of `dependency` are `path`, `hash`, `source`, `version`, `commit`" になる。decisions.md の R1 は「知らない欄の誤りは書ける欄の一覧を示す」と定めているが、`source`・`version`・`commit` は書くと E0903 になる。診断の第一の読み手は LLM なので、一覧のとおりに `source` を書いて、次の誤りを招きうる（設計原則 1・4）。
- 再現:
  ```text
  dependency A
    path "a"
    bogus "x"
  end dependency
  ```
  を `check` すると、`note: the fields of \`dependency\` are \`path\`, \`hash\`, \`source\`, \`version\`, \`commit\`` が出る。
- 修正案: 欄を見分ける表（知らない欄かどうか）と、注記に並べる表（`path`・`hash`）を分ける。E0901 の説明の文には「`source`・`version`・`commit` は読むがこの版では使えない」とすでに書いてあるので、そのままでよい。

### M3. ブロックの閉じ忘れの後に次の項目を書くと、次の項目を欄として飲み込み、誤った E0902 が出る

- 場所: `src/syntax/parser/header.rs:112-143`（欄のループ）。ループを抜けるのは `is_decl_start` のときだけで、`dependency`・`language`・`package` の行では抜けない。
- 再現（a5）:
  ```text
  dependency Textkit
    path "../x"
  dependency Other
    path "../y"
  end dependency
  ```
  出る診断は次の二つである。
  - `E0201 expected a string without interpolation, found \`Other\``
  - `E0902 \`path\` is written more than once`（実際には別のブロックの `path`）

  本当の原因である「`dependency Textkit` を閉じていない」こと（E0214）は出ない。閉じ忘れの直後が `language "0.0.3"` の行なら、E0901 の "unknown field `language` in `dependency`" になり、その `language` の宣言は失われる。
- 修正案: 欄のループの先頭で、`header_ahead(p)` と同じ厳しい先読み（`language` の次が文字列、`dependency`・`package` の次が大文字の名前）が真なら、`is_decl_start` と同じく抜ける。そうすれば `close` が E0214（"expected `end dependency` before this"）を出し、外側の `parse_header` が次の項目を読む。単体テスト `malformed_headers_report_and_recover` に、この形（閉じ忘れの直後が `dependency B` と `language "…"` の二つ）を加え、E0214 だけが出ることを確かめる。
- 補足（L 相当）: `dependency A path "x"` のように一行に書くと、E0201 の後に、閉じの行で E0201 "expected a declaration, found `end`" が続く。この形を `end dependency` まで読み飛ばす回復は、必須ではない。

### M4. 02-01 の「import で辿れないものは読まない」が W1 で偽になった

- 場所: `docs/design/02-impl/02-01-pipeline.md:34`。
- 問題: 本文は「根のディレクトリの下のファイルのうち、import で辿れないものは読まない」と書いている。W1 からは、import で辿れない根の `package.bnt` も読む。02-02 と 02-04 は直したが、02-01 は残っている。plan.md は 02-01 を W2 の作業に挙げているが、AGENTS.md は設計書に今の実装だけを書くよう求めており、この文は W1 の時点で実装と食い違っている。
- 修正案: 「…import で辿れないものは、根の直下の `package.bnt`（[パッケージ](../06-tooling/06-09-packages.md)）を除いて読まない」とし、02-02 の手順 3 を参照する。

---

## L（小さな点）

### L1. E0907 の期待値に処理系の版が入り、版を上げるとゴールデンが変わる

- 場所: `testdata/packages/newer-language.diag.json`、`newer-config.diag.json`（"…but this is Benitoite 0.0.3"）。
- 事前点検の C4 は、`99.0.0` を使って「リリースで版を上げても期待値が変わらないようにする」と求めていた。宣言の側は `99.0.0` にしたが、文の `{current}` が `CARGO_PKG_VERSION` なので、版を上げると 2 件の期待値が変わる。
- 案: リリースの手順で作り直すと割り切るなら、そのことを報告に残す。期待値を固定したいなら、ゴールデンの比較で版を置き換える仕組みが要る。ただ、この 2 件のためだけに加えるほどではない。少なくとも、リリースの手順（`release-and-history-plan` など）に「版を上げたら `testdata/packages/newer-*` を作り直す」と書いておく。

### L2. 処理系の版が三つの数の形でなくなると、版の照合が黙って止まる

- 場所: `src/modules/package.rs:57-59`。`parse_version(env!("CARGO_PKG_VERSION"))` が `None` を返すと、E0907・E0908 の検査を何も言わずに飛ばす。
- 案: 単体テストを一つ加え、`parse_version(env!("CARGO_PKG_VERSION")).is_some()` を確かめる。`0.0.4-dev` のように前の版の印を付けたときに、テストで気付ける。

### L3. E0902 の主な位置が項目の種類で揃っていない

- 場所: `src/syntax/parser/header.rs:26-33`。主な位置は、`language` と `package` では項目の全体（`language "0.0.2"` の行の全体。a8 で確認）、`dependency` では別名だけである。
- 案: 02-03 の事前点検は「置き場所の誤りは語の span」としていた。二度書きもそれに揃え、`language`・`package` では語の span（`modules::package::keyword` と同じ形）を使う。

### L4. `test` の走査が `bnt_files` を写して作った別の関数になっている

- 場所: `src/cli/tools/test_runner/mod.rs:199-237` の `test_files`。中身は `src/cli/tools/args.rs` の `bnt_files` とほぼ同じである（シンボリックリンクを辿らないことも同じ）。
- 問題: 走査の規則（リンクを辿らない、並べる順）を変えるときに、二か所を直す必要がある。`test_files` には、リンクを辿らない理由のコメントもない。
- 案: `bnt_files` に「下りないディレクトリを決める」引数を加えて共有する。少なくとも、`test_files` に `bnt_files` と同じ規則であることと、根拠の節（06-01）をコメントで書く。

### L5. 文言と語の定数が重複し、本体に直接書いた文字列がある

- `LANGUAGE`・`DEPENDENCY`・`PACKAGE` を、`src/syntax/parser/text.rs` と `src/modules/text.rs` の両方で定義している。
- `header.rs` に、`"Benitoite"`（100 行）、`"sha256:"`（223 行）、`"source" | "version" | "commit"`（211 行）、`"path"`（145 行）、`"hash"`（219 行）を直接書いている。
- 案: 欄の名前は `text` の定数にまとめ、`DEPENDENCY_FIELDS` から引く。`modules` の側は `crate::syntax` の定数を使う。

### L6. 新しい診断の説明の文で、コードの語をバッククォートで囲んでいない

- 場所: `src/diag/codes.rs`。E0252・E0901・E0903・E0906・E0909・E0910・E0911・E0913・E0914・E0915 の説明の文で、`language`・`package.bnt`・`source`・`sha256:` などを地の文に書いている。既存の E0251 や E0325 は、"`function`"、"`Benitoite`" のように囲んでいる。
- 囲まないと、生成物の `skill/references/diagnostics.md` でも地の文に見える。E0905 の "u64" も、利用者向けの説明の文としては実装の語である（"numbers that fit in 64 bits" など）。

### L7. 01-02 の例が、W1 では解決できない import を含む

- 場所: `docs/design/01-spec/01-02-syntax.md` の「ファイルの先頭の部分」の例の `import Textkit.Slug`。
- W1 では依存の記述を import の解決に使わないので、この例を `check` すると E0318 になる（spec_examples は読み込みの誤りを除いて扱うので、テストは通る）。W2 で正しい例になるが、W1 の時点の設計書は、まだ実装していない振る舞いの例を載せている。W2 のレビューで、この例が実際に検査を通ることを確かめる。

### L8. CHANGELOG の一時的な一文

- 場所: `CHANGELOG.md` の "Dependency descriptions are validated but do not yet participate in import resolution."
- W2 でこの文は偽になる。W2 が消すことを、作業の文書に書いておく。

### L9. 02-03 の AST の表の文が読み違えやすい

- 場所: `docs/design/02-impl/02-03-frontend.md` の AST の表の「先頭の部分」の行、「項目はノード番号を持ち、欄（名前、文字列、span）は持たない」。
- この文は「欄が名前・文字列・span を持たない」とも読める。意図は「欄は名前・文字列・span を持ち、ノード番号を持たない」なので、そのように書き直す。

### L10. 大文字と小文字を区別しないファイルシステムで、E0913 を避けられる

- 場所: `src/modules/load.rs:80-91`。照合は `file_name() == "package.bnt"` の完全一致である。
- macOS で、根に `package.bnt` を置いたまま `benitoite run ./PACKAGE.BNT` とすると、E0913 にならない。同じファイルを入口として読み、さらに設定ファイルとしても読む。`language` を書いていれば E0911 になる。
- 害は小さく、設計書（01-03）は「大文字と小文字まで一致」と定めているので、実装は規範に合っている。直すなら、入口の正規化したパスが根の `package.bnt` の項目と同じファイルかを確かめる。今は記録だけでよい。

---

## 確かめて問題がなかった点

- **E0252 の検出**: `header_ahead` は、`language`＋文字列か、`dependency`／`package`＋大文字の名前のときだけ真になり、トップレベルの項目の始まりでだけ調べる。既存のトップレベルは宣言しか許さないので、誤検出の経路はない。誤った位置に書いた項目を AST に入れないことも確かめた。`first` には、最初の import か宣言の語の位置が入る（g4、late2）。
- **`package.bnt` の読み込み**: 次のことを、実行と単体テストで確かめた。
  - 根の項目の一覧での完全一致（`Package.bnt` は設定ファイルにならない）。
  - 親を遡らないこと（b5）。
  - 設定ファイルの宣言・import に対する E0912 と、そこにある遅い項目に対する E0252（b1・c4）。
  - 空の設定ファイル（c3。`run` で終了状態 0）。
  - ディレクトリという名前の `package.bnt` を無視すること。
  - リンクの `package.bnt` を、モジュールと同じく辿って読むこと。
  - 表示名（`./b2/../b2/package.bnt`、相対の入口では `package.bnt`）。
  - `run`・`test` に `package.bnt` を指定したときの E0913（終了状態 2）。
- **ID のそろえ方**: `Config` は入口の直後、prelude の前に、`modules`・`asts`・`comments`・`file_diagnostics`・`requests` のすべてへ同じ順で入る。番号 1 が prelude であることを仮定するコードはない（`ModuleId(1)` や `skip(1)` で探した）。`ModuleKind` の網羅の `match` は desugar の 3 か所で、宣言がないので `User` と同じ枝でよい。
- **整形**: コメント（行末、行の前、ブロックの中）、ブロックの中の空の行、項目の間と import の前の空の行、`end` の段を確かめた。二度目の整形で変わらない（f1）。E09 だけのファイルは整形し、E0252 のファイルは整形しない。
- **`test` の走査**: 下位のパッケージの根を除き（e3 も含む）、パッケージの根を直接指定したときはその中を集める。単体テストもこの両方を確かめている。
- **版の比較**: 数として比べる（`1.10.0 > 1.2.99`）。先頭の 0、桁あふれ、全角の数字、前の版の印は拒む。E0908 は最も古い該当の項目を選び、境界（宣言 < 変更 ≤ 処理系）も正しい。
- **ゴールデンと単体テスト**: パッケージの 11 ケースが通る。`syntax`・`modules`・`version` の単体テストも、1 件を除いて通る。除いた 1 件 `modules::tests::real_fs_matches_memory_for_files_imports_and_missing_modules` は、`CARGO_TARGET_DIR` を外に向けた worktree では `../../target` がないために失敗した。このテストが前から持つ前提によるもので、W1 とは関係しない。
- **テストの質（test-audit）**: 新しい振る舞いは、それぞれ一か所で確かめている。構文の誤りは単体テスト、置き場所の誤りはゴールデン、版の表の差し込みは単体テストである。重複は見当たらない。`// spec:` の印も付いている。足りないのは、M3 の回復の場合だけである。
