# W7 のレビュー（0012d2e9。改造全体の文書の差分 02b52fd7..6ceb6fb0 を対象）

対象: `docs/design/`・`docs/reference/benitoite.md`・`docs/reference/install.md`・`CHANGELOG.md` の改造全体の差分。実装との照合は san_benito の HEAD（6ceb6fb0）を `git archive` で取り出して読んだ。リポジトリのファイルと git の状態は変えていない。

## 確かめて問題がなかったこと

- 上限の値: `external/runtime.rs` の `FUEL = 10_000_000_000`・`MEMORY = 64 MiB`・`TRANSFER = 256 MiB`・`TABLE_ELEMENTS = 10_000`・`OBJECTS = 16`、`external/mod.rs` の `consume_fuel`・`epoch_interruption`・`max_wasm_stack(512 KiB)` は、02-09・03-10・リファレンス・CHANGELOG・用語集の記述と一致する。
- 失敗の分類: `failure()` は、メモリの上限と hostcall fuel の枯渇を R0905、表の要素数を R0902（`ExternalValueTooLarge`）、`OutOfFuel` を R0904、その他のトラップと誤りを R0601、`Trap::Interrupt` を中断に分ける。02-09・02-10・03-10・リファレンス・CHANGELOG と一致する。
- ハッシュ: `modules/hash.rs` の走査（根の直下のファイル、ASCII の大文字で始まるディレクトリ、根の直下の `wasm/` の下はすべて、`.` で始まる項目は飛ばす、辿る項目のリンクは拒否、壊れたリンクは `symlink`）、含める一覧（`.bnt`・`.wasm`・`LICENSE`/`COPYING`/`README` の ASCII の大文字小文字を区別しない接頭辞）、`to_lowercase` による `case`、改行の `name`、上限（10,000 ファイル・100,000 項目・128 MiB。上限ちょうどは許す）、要約の形（16 進 64 文字 + 空白二つ + パス + 改行、`sha256:` 接頭辞）は 06-09 とリファレンスの記述と一致する。
- `test` のディレクトリ走査（`cli/tools/args.rs` の `collect_bnt_files`）は、`package.bnt` に完全に一致するファイルを除き、指定したディレクトリより下で `package.bnt` を持つディレクトリを丸ごと飛ばす。06-01・06-04・06-09・リファレンス・CHANGELOG と一致する。
- 診断のコード: E0252、E0801〜E0814、E0901〜E0929、E1001〜E1011、R0601・R0902・R0904・R0905、E0126 は `diag/codes.rs` にあり、各章の割り当てと一致する（E0929 の置き場所は後述の M-4）。
- `benitoite package` の出力の形（`added dependency … (package …) to …`、`hash:`・`effects:`・`components:`、`(none)`・`(not recorded)`・`(no imports)`、`moved … from … to …`）は `cli/tools/package/mod.rs` の `text` と一致する。
- 相対リンクとアンカー: `docs/design/`・`docs/reference/`・`CHANGELOG.md` の全リンクを小さなスクリプトで調べ、切れたリンクはなかった（`#21-experimental-packages-and-external-functions`、06-01「`package` のコマンドライン」などのアンカーを含む）。
- `docs/design/` に【未決】【要検証】は増えていない（08-04 の既存の「未確認」だけ）。README の目次に 03-10 と 06-09 がある。
- リファレンスの 21 節は、冒頭で構文の見直しで綴りが変わりうることを書き、Compatibility に例外を設けないと明記している（R25 のとおり）。Skill の手書きの部分は変えていない（Q7 のとおり）。

## 所見

### H-1 リファレンス 2 節が「設定ファイルを読まない」「取り込めるのは根の下と標準ライブラリだけ」と書いたまま

- 場所: `docs/reference/benitoite.md` 98 行（「2. The command line」の `<script>` の説明）。
- 問題: 「the script can import modules from the root directory and below it, and from the standard library」「`benitoite` reads no configuration file.」が残っている。21 節と CHANGELOG の互換性を壊す変更（根の `package.bnt` を設定として読み、宣言を含めば E0912）と真っ向から食い違う。利用者向けの文書なので、LLM がこの一文を根拠に `package.bnt` という名前のスクリプトを置く誤りを招く。
- 修正案: 「… and from the standard library ([Modules](#12-modules)), and from declared local dependencies (see [section 21](#21-experimental-packages-and-external-functions)). `benitoite` reads `package.bnt` directly in the root as a settings file; it does not search parent directories or the working directory.」のように改める。

### H-2 02-11 が「処理系は、プロジェクトの設定ファイルを読まない」と【決定】で書いたまま

- 場所: `docs/design/02-impl/02-11-embedding.md` 29 行（【決定】`run`・`check` にディレクトリを指定したときは…）。
- 問題: 「処理系は、プロジェクトの設定ファイルを読まない（CLI の「ディレクトリの指定（初回リリース版）」）」が残り、参照先の 06-01 は既に「根の直下の `package.bnt` を設定ファイルとして読む」に改めてある。同じ段落の「`test` にディレクトリを指定したときは、その下のすべての `.bnt` のファイルを…」も、`package.bnt` とパッケージのディレクトリを除く規則（06-01・06-04・06-09）を反映していない。W7-6 の「古い記述」の一覧から漏れた箇所である。
- 修正案: 「処理系は、根の直下の `package.bnt` を設定ファイルとして読み、親のディレクトリを遡って探さない（[パッケージ](../06-tooling/06-09-packages.md)）。」に改め、`test` の文に「`package.bnt` と、`package.bnt` を持つ下のディレクトリを除く（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)の「テストの実行」）」を足す。

### M-1 06-01「ディレクトリの指定」の取り込める範囲が古い

- 場所: `docs/design/06-tooling/06-01-cli.md` 48 行（「ディレクトリの指定（初回リリース版）」の最初の箇条）。
- 問題: 「import で取り込めるのは、根のディレクトリとその下のファイルと、標準ライブラリだけである」が残る。01-03「モジュールと import（初回リリース版）」は「記述した依存のパッケージのモジュール」を加えてあり、同じ節の次の箇条（`package.bnt` を読む）とも食い違う。
- 修正案: 「…根のディレクトリとその下のファイル、記述した依存のパッケージのモジュール、標準ライブラリだけである」に揃える。

### M-2 02-03・02-05 が「本体のない関数の宣言は標準ライブラリのソースでだけ書ける」としている

- 場所: `docs/design/02-impl/02-03-frontend.md` 297 行（「標準ライブラリのソースの構文」の【決定】）、230 行（AST の「宣言」の行「本体を持たないもの（`@builtin`）を含む」）、`docs/design/02-impl/02-05-typechecker.md` 32 行（構文解析器が報告する誤りの箇条「利用者のソースの `@builtin`、本体のない関数の宣言」）。
- 問題: 利用者のソースでも `@external` を付けた本体のない関数を書ける（01-02「外部の関数の宣言」、E0808 と E0814 の区別）。02-03 の【決定】の文は今の実装と食い違う。
- 修正案: 02-03 297 行を「`@builtin` は標準ライブラリのソースでだけ書ける。本体のない関数の宣言は、`@builtin` か `@external`（[構文](../01-spec/01-02-syntax.md)の「外部の関数の宣言」）を付けたときだけ書ける」に改め、230 行を「本体を持たないもの（`@builtin`・`@external`）を含む」、02-05 32 行を「利用者のソースの `@builtin`、`@external` を付けない本体のない関数の宣言」とする。02-03 の「構文の規則に伴う次の診断」に E0809〜E0814 の扱いを一行足すとなおよい。

### M-3 リファレンス 2 節のコマンドの一覧に `package` がない

- 場所: `docs/reference/benitoite.md` 74〜95 行（使い方のブロックとコマンドの表）。
- 問題: 予約名の一覧からは `package` を外したが、使い方のブロックと表に `benitoite package add|update|move` がない。表の `test` の行の「all `.bnt` files under the given directories」も除外の規則を示さない。06-01 は `package` をサブコマンドの一覧に加えてある。
- 修正案: ブロックに `benitoite package add|update|move ...` を足し、表に「`package` | Experimental. Adds, updates, or moves local dependency declarations. See [section 21](#the-package-commands).」の行を足す。`test` の行に「except `package.bnt` and nested packages」を足す。

### M-4 E0929 の置き場所が章の間で食い違う

- 場所: `docs/design/02-impl/02-10-diagnostics.md`「パッケージ命令の診断」の表、`docs/design/02-impl/02-03-frontend.md` 157 行（構文解析器が出す診断の箇条）、`docs/design/01-spec/01-02-syntax.md` 406 行。
- 問題: E0929 は構文解析器（`syntax/parser/header.rs` 272 行）が読み込みのたびに出す。ところが 02-10 は「`benitoite package` の命令の前提の誤り」の表に入れ、02-03 の構文解析器の診断の列挙（E0901〜E0906）には入っていない。加えて 01-02 だけが診断コードを本文に書いており、ほかの言語仕様の章（コードを一つも書かない）と書き方が揃わない。
- 修正案: 02-03 157 行を「…版とハッシュの書式の誤りは E0901〜E0906、`effects` の記録の形の誤りは E0929 とする」に改める。02-10 の表から E0929 を外すか、表の前置きを「命令の前提の誤りと、命令が書く記録の形の誤り」に改める。01-02 は「形の誤りは誤りとする（診断は[字句解析器と構文解析器](../02-impl/02-03-frontend.md)）」として番号を外す。

### M-5 01-08 の資源の不足の表が、戻り値の受け渡し予算と表の要素数を落としている

- 場所: `docs/design/01-spec/01-08-evaluation.md`「資源の不足」の表の「外部の関数のメモリ」の行。
- 問題: 「外部の関数へ渡す引数の合計の大きさと、線形メモリの大きさ」としているが、03-10・02-09 は受け渡しの予算を引数と戻り値の両方向に設け、表の要素数の上限（R0902）も持つ。言語仕様の表だけを読む実装者は、戻り値の予算と表の上限を資源の不足と判断できない。
- 修正案: 「外部の関数のメモリ | 一回の呼び出しの線形メモリと表の大きさ、引数と戻り値として受け渡す値の大きさ」に改める（値は 02-09 に委ねたまま）。

### M-6 07-01 の主体の表に依存のパッケージがない

- 場所: `docs/design/07-quality/07-01-security-model.md`「主体と信頼」の表。
- 問題: 外部の関数のコンポーネントは「信頼しない」として足したが、依存のパッケージのソース（他人が書き、`hash` がなければ読み込みのたびに変わりうる）を足していない。保証の表の「パッケージ」の行の「`hash` のない依存の中身が変わっていないこと」を保証しない理由が、脅威モデルの側に現れない。
- 修正案: 「依存のパッケージ（手元のパスのディレクトリ） | 信頼しない | スクリプトと同じく、利用者の意図と違う操作を含みうる。`hash` を書かなければ、読み込みの間に中身が変わりうる」の行を足す。

### L-1 01-02 の「初回リリース版の文法の全体」と「初回リリース版に含めない構文」の言い方

- 場所: `docs/design/01-spec/01-02-syntax.md`「初回リリース版の文法の全体」の前置き、「初回リリース版に含めない構文」。
- 問題: 前置きは「初回リリース版の文法の全体は次のとおり…ファイルの先頭の部分の規則も含む」と、初回リリース版の後の規則を初回リリース版の文法に含めるように読める。「含めない構文」の節は「その後、『ファイルの先頭の部分』の構文を加えた」とだけ書き、同じく加えた `ExternalFnDecl`（「外部の関数の宣言」）に触れない。見出しは spec_examples などが引くので変えない。
- 修正案: 前置きを「…反映したものに、初回リリース版の後に加えたファイルの先頭の部分と外部の関数の宣言の規則を加えたものである」、含めない構文の節を「その後、『ファイルの先頭の部分』と『外部の関数の宣言』の構文を加えた」とする。

### L-2 01-03「依存の記述と `package.bnt`」の書ける場所の文

- 場所: `docs/design/01-spec/01-03-names-modules.md`「依存の記述と `package.bnt`」の最初の【決定】。
- 問題: 「`language` と `dependency` を書けるのは、実行を始めるファイルの先頭か、根のディレクトリの直下の `package.bnt` だけである」は、依存の `package.bnt`（パッケージの根の直下。`language` が必須）を除くように読める。用語集の「設定ファイル」の「根の直下だけを読み」も同じ。
- 修正案: 「…根のディレクトリかパッケージの根の直下の `package.bnt` だけである」とし、用語集も「根とパッケージの根の直下だけを読み」に揃える。

### L-3 失敗の種類の書き漏れ（01-09・02-10）

- 場所: `docs/design/01-spec/01-09-errors.md`「外部のライブラリの誤りとの対応」、`docs/design/02-impl/02-10-diagnostics.md` の区分の表の `R06nn` と `R09nn` の行。
- 問題: 01-09 は「トラップとコンポーネントの ABI 違反」を実行時エラーとし、インスタンス化の失敗を落としている（03-10・02-09・02-10 本文は R0601 に含める）。02-10 の `R06nn` の行は「コンポーネントの関数のトラップ」だけ、`R09nn` の行は「外部の関数の燃料とメモリの上限（R0904・R0905）」だけで、R0902 に入る表の要素数と戻り値の大きさを書いていない。
- 修正案: 01-09 に「インスタンス化の失敗」を足す。02-10 の `R06nn` を「コンポーネントのトラップ、ABI 違反、インスタンス化の失敗」、`R09nn` に「外部の関数の表の要素数と戻り値の大きさ（R0902）」を足す。

### L-4 章の「目的と範囲」に新しい対象が反映されていない

- 場所: `docs/design/02-impl/02-09-runtime.md`「目的と範囲」の対象の列挙、`docs/design/02-impl/02-02-source-and-spans.md`「目的と範囲」の検査で扱うソースの列挙。
- 問題: 02-09 の対象の列挙に「外部の関数の実行」がない（2 段落目で触れるだけ）。02-02 は「根の `package.bnt`」を足したが、依存の `package.bnt` と依存のモジュールを足していない（本文の表には両方ある）。
- 修正案: 02-09 の列挙に「外部の関数の実行（実行系、上限、中断）」を、02-02 に「依存の `package.bnt` と、import で辿れる依存のモジュールのファイル」を足す。

### L-5 用語の揃え

- 場所: `docs/design/00-overview/00-04-glossary.md` の「設定ファイル」の原語、`docs/design/02-impl/02-10-diagnostics.md` の見出し「パッケージ命令の診断」。
- 問題: 用語集の原語は `configuration file` だが、リファレンスと CHANGELOG と診断の文言は一貫して「settings file」と書く。02-10 の見出し「パッケージ命令」は、01-02 の「パッケージの命令」、06-09 の「`benitoite package`」と揺れている。
- 修正案: 原語を `settings file` に改める。見出しは「`benitoite package` の診断」とする（見出しを変えるときは `git grep` で参照を確かめる）。

### L-6 01-07 の追加文の言い方

- 場所: `docs/design/01-spec/01-07-effects.md`「外部のライブラリのエフェクトと権限の表示（初回リリース版の後）」の冒頭。
- 問題: 「外部の関数は純粋なものだけを検査する。」は、純粋でない外部の関数を検査せずに通すようにも読める。意図は「外部の関数は純粋なものに限る」である。
- 修正案: 「外部の関数は純粋なものに限る（前述の「外部の関数のエフェクト」）。」とする。

### L-7 03-10 の「根の作り直し」

- 場所: `docs/design/03-interop/03-10-external-functions.md`「照合」の 2 番目の【決定】。
- 問題: 「根の作り直しで I/O の失敗が起きた場合」の「根の作り直し」が何の処理を指すか、本文から読み取れない（照合の段がパスの基準の根を開き直すことを指すと思われる）。
- 修正案: 「照合の段がパスの基準の根を開き直すときに I/O の失敗が起きた場合（読み込みの後に根や依存のディレクトリが消えた場合など）」と具体的に書く。

### L-8 出典のリンクが版を固定していない

- 場所: `docs/design/06-tooling/06-09-packages.md`「中身のハッシュ」の Go の dirhash（`blob/master`）、`docs/design/03-interop/03-10-external-functions.md`「前提」の WIT 仕様（`blob/main`）。
- 問題: ほかの出典（Wasmtime・wit-bindgen・wasm-tools）は版のタグに固定しているのに、この二つは動く枝を指す。「2026-10-13 に確認」した内容と、リンク先の今の内容がずれうる。
- 修正案: 確認した時点のコミットかタグ（golang/mod のタグ、component-model のコミット）に固定する。

### L-9 リファレンス 21 節の細部

- 場所: `docs/reference/benitoite.md`「The package commands」。
- 問題: 「Run this addition with a starting file that does not already declare `Textkit`.」は、直前の「Local dependencies」の例の `main.bnt` が既に `Textkit` を宣言しているため E0923 になる、という注意だと思われるが、命令文として唐突で意図が伝わりにくい。
- 修正案: 例の直前に「If `main.bnt` does not declare `Textkit` yet, adding it prints:」と書き、命令文を削る。

### L-10 CHANGELOG の細部

- 場所: `CHANGELOG.md` の Unreleased。
- 問題 1: 「Recover missing header endings without treating `language` inside a closed block as a new header item.」は、レビューで直した構文解析の回復の内部の細部で、利用者に意味のある変更として読めない。
- 問題 2: 0.0.1〜0.0.3 はソースだけのリリースであり、すべての利用者がソースからビルドする。C コンパイラが新たに要ることは、Added の最後の項目の中に埋もれている。
- 修正案 1: 該当の一文を削る（必要なら「Report a missing `end dependency` or `end package` without cascading errors.」程度にする）。
- 修正案 2: 「Building from source now requires a C compiler (Xcode command line tools on macOS, `cc` on Linux).」を独立した項目にするか、Incompatible changes の前置きに一文で触れる。

### L-11 decisions.md の R11 と実装の食い違いを改造の記録に残す

- 場所: 改造のディレクトリの `decisions.md`「R11 形式化（D16）」。
- 問題: R11 は「`@external`（組み込みの関数と同じく仮定として与える関数）の行を『対象外』として加える」とするが、実装と 07-04 は外部の関数を含むプログラムを丸ごと書き出しから除く。W7 の報告と事前点検には書いてあるが、保管する判断の記録には残らない。
- 修正案: W8 で保管する前に、R11 に「実装は外部の関数を含むプログラムを丸ごと除いた（`excluded: ["external function"]`）。仮定の欄として与える形は採らなかった」と一文足す。

### L-12 書式の細部

- 場所: `01-03`「依存の記述と `package.bnt`」の後、`06-09`「`test` と `fmt` の扱い」と「中身のハッシュ」の後、`02-10`「パッケージ命令の診断」の前。
- 問題: 見出しの前後に空の行が二つ以上続く。
- 修正案: 空の行を一つにまとめる。

## 補足（文書の範囲の外）

- R0905 の文言は「needed more than the memory limit of {limit} bytes」で、受け渡し予算（256 MiB）の超過にも同じ文言を使う。設計書の分類（R0905 に含める）とは食い違わないが、利用者には線形メモリの上限と区別できない。直すなら診断の文言の変更になるので、W8 か docs/todo の項目で扱う。
