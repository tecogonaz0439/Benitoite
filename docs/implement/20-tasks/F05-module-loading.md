# F05 モジュールの読み込み

- 依存する作業: [F03](F03-parser-modules-records.md), [F04](F04-parser-traits-effects.md)（読み込みは、どの検査でも prelude と `Benitoite.IO.Clock` を構文解析する。これらのソースはエフェクトの宣言などの F04 の構文を含むので、F04 を待つ）
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/F05-module-loading

## 目的

実行を始めるファイルから import を辿ってプログラムのすべてのモジュールを読み、ファイルごとに字句解析と構文解析を行い、ソースの表・モジュールの表・モジュールごとの AST とコメント・読み込みの段の診断を作る（02-01「段と段の間のデータ」の読み込みの段、ADR 0156）。標準ライブラリのソースは、処理系に埋め込んだ表 `prelude::STDLIB`（10-14）から引く。すべてのファイルを読み終えた後、依存グラフの循環を明示の積み重ねで調べる。

出力は名前解決（[F06](F06-resolver.md)）とパイプライン（F18）が使う。本作業は、後の作業の単体テストが使う、ファイルシステムを使わない `ModuleFs` の実装（`memfs`）も置く。パイプラインの `check_files`・`check_text`（10-13）は F18 が書くので、F06〜F17 の単体テストはこちらを使う。

## 読む設計書の節

- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「ソースとファイル ID」「ソースの大きさの上限」「span」
- [名前解決とモジュール読込](../../design/02-impl/02-04-resolver.md): 「前提」「モジュールの表」「モジュールの探し方」「依存グラフと循環の検出」「標準ライブラリのソースの持ち方」
- [名前・スコープ・モジュール](../../design/01-spec/01-03-names-modules.md): 「モジュールと import（初回リリース版）」「標準ライブラリの名前空間と prelude（初回リリース版）」「循環する import（初回リリース版）」「実行を始めるモジュール（初回リリース版）」
- [パイプライン](../../design/02-impl/02-01-pipeline.md): 「段と段の間のデータ」「誤りが見つかったときの段の進め方」
- [字句解析器と構文解析器](../../design/02-impl/02-03-frontend.md): 「処理の流れ」「構文解析の結果」「標準ライブラリのソースの構文」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「文章の形式」の診断の並べ方の段落
- ADR: [0054](../../design/decisions/0054-no-import-cycles.md)、[0126](../../design/decisions/0126-import-by-module-name.md)、[0127](../../design/decisions/0127-directory-run-and-root.md)、[0128](../../design/decisions/0128-prelude-and-benitoite-namespace.md)、[0156](../../design/decisions/0156-module-loading-and-whole-program-checking.md)、[0157](../../design/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[0244](../../design/decisions/0244-import-name-matching-by-directory-listing.md)
- インターフェース: [10-04](../10-interfaces/10-04-modules-and-resolve.md)「読み込みの段」、[10-01](../10-interfaces/10-01-base.md)「意味の違う整数の専用型と span」「ソースの表」、[10-03](../10-interfaces/10-03-syntax.md)「字句の切り出しと改行の判定」「構文解析」、[10-14](../10-interfaces/10-14-prelude-and-stdlib-sources.md)「置き方」「モジュールの一覧」、[10-02](../10-interfaces/10-02-diagnostics.md)「E01 読み込みと字句」の E0101 と「E03 名前、import、公開」の E0318〜E0322
- 共通の決まり: [実装の規約](../00-common/00-02-conventions.md)、[作業の進め方](../00-common/00-03-workflow.md)、[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)「テストの設計の原則」

## 作るもの

- `src/modules/mod.rs`: 10-04 の `sig=src/modules/mod.rs`（`ModuleFs`、`RealFs`、`ModuleTable::get`・`find`・`iter`、`load_program`）の中身。C02 が置いた `file=` の部分は変えない。
- `src/modules/` の下の非公開の子のモジュール（本作業で分け方を決めてよい。例: `find.rs` がモジュールの探し方、`cycle.rs` が循環の検出、`text.rs` が理由の文）。子のモジュールの宣言は `mod.rs` の `sig=` の部分に加える。
- `src/modules/memfs.rs`: `#[cfg(test)] pub(crate) mod memfs;`。後述の「テスト用のファイルシステム」。
- 各ファイルの `#[cfg(test)] mod tests`。
- `testdata-next/modules/` の下の、誤りのない複数のモジュールの例（後述の「受け入れテスト」）。

`src/diag/codes.rs` は、E0101・E0318〜E0322 の型板を 10-02「型板の直し方」の範囲で直してよい。ほかのファイル（`syntax`・`resolve`・`prelude`・`base`・`src/legacy/`）は変えない。10-14 のソースに誤りを見つけたときは、直さずに作業を止めて報告する（10-14「置く作業と既存のファイル」）。

## 手順の要点

### 作業の一覧とファイル ID

`load_program` は、02-02「ソースとファイル ID」の 4 手順をそのまま実装する。

1. 作業の一覧の最初に実行を始めるファイル（`entry`）を、続けて `stdlib` のうち `prelude` が真の項目を表の順に積む。
2. 一覧の先頭から一つ取り出して読み、読めたら `SourceTable::add` でファイル ID を振る。続けて `syntax::lexer::lex`、`syntax::newline::resolve_newlines`、`syntax::parser::parse` を呼ぶ。`parse` の `text` には、`lex` に渡したのと同じバイト列（`Source::text()`）を渡す（10-04）。`parse` の `kind` は、標準ライブラリのソースでは `SourceKind::Prelude`、利用者のファイルでは `SourceKind::User` とする（10-01「ソースの表」）。
3. AST の `imports` を書いた順に見て、取り込むモジュールを決め（後述の「モジュールの探し方」）、まだ積んでいないモジュールを末尾に積む。モジュールは名前（`ModulePath`）で識別し、同じ名前は一度だけ積む。
4. 一覧が空になるまで繰り返す。

- `ModuleId` はファイル ID と同じ値である（`ModuleId::of_file`）。読めなかったファイルはソースの表に加えず、モジュールの表にも AST の並びにも加えない。こうすると `asts`・`comments` の添字がモジュールの ID の値と一致する（10-04「読み込みの段」）。
- モジュールの名前: 実行を始めるモジュールは空の並び `ModulePath(vec![])` とする（本プランの決定。実行を始めるモジュールは名前で取り込めない。01-03「実行を始めるモジュール」）。利用者のモジュールは根のディレクトリからの名前（`["Lib", "Text"]`）、標準ライブラリのモジュールは `["Benitoite", "IO", "Console"]` とする。
- 種類（`ModuleKind`）: 実行を始めるファイルは `Entry`、import で読んだ利用者のファイルは `User`、`prelude` が真の項目は `Prelude`、偽の項目は `Stdlib` とする。
- 表示名（02-02 の表示名の表）: 実行を始めるファイルは `entry.display_name`。利用者のモジュールは、`entry.display_name` のディレクトリの部分（最後の `/` までを含む。`/` がなければ空）に、根からの相対パスを `/` でつないで続ける（`./report/Lib/Text.bnt`）。標準ライブラリは `<benitoite>/` に `path` の段を `/` でつなぎ `.bnt` を付ける。相対パスの区切りを `/` に固定するのは本プランの決定である（表示名はソースの表示だけに使い、ファイルを開くのには使わない）。
- 読んだ内容は変換せずに `Source::new(name, kind, text)` に渡す。UTF-8 の検査は字句解析器が行う（02-02）。

### 大きさの上限

- ファイル一つが `base::source::MAX_SOURCE_BYTES` を超えたら E0101 とし、ソースの表に加えない。
- 読んだ順にファイルの大きさを足し、和が `MAX_TOTAL_SOURCE_BYTES` を超えることになるファイルで E0101 とし、加えない。標準ライブラリのソースも数える（02-02「ソースの大きさの上限」）。
- E0101 の `{reason}` の文（読めない理由、二つの上限の文）は `modules` の子のモジュール `text` の定数に置く（10-02 の E0101 の行、00-02「文言」）。OS の誤りの理由は `std::io::Error` の `Display` の文をそのまま埋める。

### モジュールの探し方（02-04「モジュールの探し方」）

import の宣言の名前の段（`ImportDecl::path`）から、次の順に決める。どの誤りも、主な位置は import の宣言のモジュールの名前の span（最初の段の開始から最後の段の終わりまで）とする。

1. 最初の段が `Benitoite` なら、残りの段で `stdlib` の表を引く。2 番目の段が `Unofficial` なら、それを除いた段と `path` が一致し `unofficial` が真の項目を、そうでなければ残りの段と `path` が一致し `unofficial` が偽の項目を引く（02-04「モジュールの探し方」、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。なければ E0321。状態だけが違う項目がある（`path` は一致するが `unofficial` が逆）ときは、`unofficial` か `standard` の注記を加え、名前の span を正しい取り込みの名前に置き換える修正案を付ける（`{suggestion}` は `Benitoite.Unofficial.IO.Console` か `Benitoite.Trait` の形）。この場合は `similar` の注記を付けない。`similar` の注記の候補は、表のすべてのモジュールの取り込みの名前（`Benitoite.` を付け、非公式のモジュールでは `Benitoite.Unofficial.` を付けた形）のうち編集距離 2 以下のもの（最大 3 つ、距離の小さい順）とし、候補が一つなら名前の span を置き換える修正案（`fix` の `similar`）を付ける。根のディレクトリの直下に `Benitoite` という名前の項目（ファイルかディレクトリ。`list_dir` で調べる）があれば、`root_file` の注記を加える。prelude のモジュールを明示して取り込んだ（`import Benitoite.List`）ときは、そのモジュールを取り込み先とする（誤りにしない。本プランの決定。同じモジュールの二度の取り込みなどの誤りは名前解決が報告する）。
2. それ以外の `A.B.C` は、根のディレクトリから `A`、`B` をディレクトリの項目として、最後に `C.bnt` をファイルの項目として、`list_dir` の一覧で名前が大文字と小文字まで一致する項目を選ぶ（ADR 0244）。ファイルを開けたかどうかでは照合しない。
   - 一致する項目がない段で E0318 とし、`{path}` には根からの相対パス（`Lib/Text.bnt`）を埋める。その段に大文字と小文字だけが違う項目があれば `case_only` の注記（`{actual}` は項目の名前）を加える。なければ、その段の項目のうち、編集距離 2 以下の名前の項目をモジュールの名前の形に直して `similar` の注記に並べる（置き換えは付けない。`fixes` にないため）。
   - `list_dir` そのものが失敗した段も E0318 とする。
3. 選んだファイルの `canonicalize` の結果が、根のディレクトリの `canonicalize` の結果の下（`Path::starts_with`）になければ E0319 とし、`resolved` の注記を加える。
4. 選んだファイルの `canonicalize` の結果が、実行を始めるファイルの `canonicalize` の結果と同じなら E0320 とする。
5. 読めない（`read_file` の失敗、上限）ときは E0101 とし、主な位置は同じく import の名前、`imported` のラベルの鍵で示す。

- 根のディレクトリの `canonicalize` は一度だけ求める。失敗したときは、根の中のモジュールの探索をすべて E0318 とする（本プランの決定）。
- 実行を始めるファイルを読めないとき（E0101）は、主な位置を持たない診断とし、prelude のモジュールの読み込みは続ける。
- import の宣言ごとに `ImportLink { decl, target }` を書いた順に並べる。誤りで決まらなかったものは `target` を `None` にする。二度目以降の同じモジュールへの import も、同じ `target` を持つ辺として並べる（同じモジュールを二度取り込む誤りは名前解決が報告する。10-04）。
- シンボリックリンクで二つの名前が同じファイルを指すときも、別のモジュールとして読む（02-02）。

### 依存グラフと循環の検出（02-04「依存グラフと循環の検出」）

- すべてのファイルを読んだ後、実行を始めるモジュールから、各モジュールの `imports` の順に深さ優先で辿る。明示の積み重ね（`Vec`）で書き、再帰を使わない。
- 辿っている道筋の上のモジュールに戻る辺を見つけたら、その辺を閉じる辺として E0322 を一つ報告する。主な位置は閉じる辺の import の名前、補助の位置（`member`）は循環の中のほかの import の名前、`chain` の注記は `Lib.A -> Lib.B -> Lib.A` の形（`ModulePath::dotted`）とする。
- 一度報告した循環（同じ辺の集まり）を重ねて報告しない。
- 構文の誤りのあるファイルがあっても、構文解析できた import の宣言について調べる（02-04）。
- 標準ライブラリのモジュールの間の循環は、処理系の不具合である。検出の対象を実行を始めるモジュールから辿れる範囲に限るので、prelude のモジュールから始まる循環は、本作業のテスト（標準ライブラリのソースのすべての import を辿る）で見つける。`Benitoite.Task` が `Benitoite.IO.Clock` を取り込むので、`Benitoite.IO.Clock` は prelude でなくても毎回読まれる（10-14「prelude と `Benitoite` の名前空間」）。

### 診断の順序

`LoadOutput::diagnostics` は、10-04 の欄のコメントのとおり、ファイル ID の順に並べる。本プランの決定として、次の順とする。

1. 実行を始めるファイルの E0101（位置を持たない）。
2. ファイル ID の順に、そのファイルの字句の誤り、構文の誤り、そのファイルの import の宣言の読み込みの誤り（E0101・E0318〜E0321。import を書いた順）。
3. E0322 を見つけた順。

### `RealFs`

- `read_file` は `std::fs::read`、`canonicalize` は `std::fs::canonicalize`。
- `list_dir` は `std::fs::read_dir` の項目の名前を返す。名前が UTF-8 でない項目は、モジュールの名前（ASCII の識別子）と一致しえないので除く。`is_dir` はシンボリックリンクを辿った種類（`std::fs::metadata`）で決める。

### テスト用のファイルシステム（`memfs`）

後の作業（F06〜F17）の単体テストが使う。`#[cfg(test)] pub(crate)` とし、`ModuleFs` を実装する。

- 仮の根 `/root` の下のファイルの内容の表を持ち、ディレクトリの項目は表のパスから作る。
- 大文字と小文字を区別しない振る舞いの切り替え: 真のときは、`read_file` が大文字と小文字の違うパスでも開け、`list_dir` は保存した名前を返す（ADR 0244 の状況の再現）。
- シンボリックリンクの表（パス → 指す先）を持ち、`canonicalize` がそれを解決する。根の外を指すリンクも作れる。
- 補助の関数 `load_files(files: &[(&str, &str)]) -> (LoadOutput, IdGen)`: 最初の要素を実行を始めるファイルとし、パスは `/root` からの相対パス、表示名はそのパスとして、`prelude::STDLIB` と新しい `IdGen` で `load_program` を呼ぶ。後の作業が名前解決と型検査を続けられるよう `IdGen` も返す。

## 受け入れテスト

単体テストで確かめる。診断はコードと主な位置の span（と、表にある場合は注記の鍵に当たる文）で確かめる。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 標準ライブラリだけ | 実行を始めるファイルが `function main() -> Unit … end function` だけ | 診断なし。ファイル ID 0 が実行を始めるファイル、1 から 10-14 の prelude のモジュールが表の順、その後に `Benitoite.IO.Clock`（`Stdlib`）。モジュールの表の種類と名前が一致する |
| 標準ライブラリのすべてのモジュール | prelude でないモジュールをすべて取り込む実行を始めるファイル | 読み込みと構文の誤りがなく、循環がない（標準ライブラリのソースの字句と構文の検査を兼ねる） |
| 表示名 | 表示名 `./app/main.bnt` の実行を始めるファイルが `Lib.Text` を取り込む | `Lib.Text` の表示名が `./app/Lib/Text.bnt`、`Benitoite.IO.Console` が `<benitoite>/IO/Console.bnt` |
| 読む順 | `import B`、`import A` の順に書き、`A` が `C` を取り込む | ファイル ID が 実行を始めるファイル、prelude、`B`、`A`、`C` の順。同じ入力で二度読むと同じ ID |
| 一度だけ読む | 二つのモジュールが同じ `Lib.Common` を取り込む | `Lib.Common` は一度だけ読まれる |
| 見つからない | `import Lib.Missing` | E0318（主な位置は `Lib.Missing`） |
| 大文字と小文字だけの違い | ファイルは `Lib/text.bnt`、大文字と小文字を区別しない `memfs` で `import Lib.Text` | E0318 と `case_only` の注記（`text.bnt`）。区別する設定でも同じ結果 |
| 根の外 | `Lib/Out.bnt` が根の外を指すシンボリックリンク | E0319 |
| 実行を始めるファイルの取り込み | `main.bnt` が `import Main` と書き、`Main.bnt` が `main.bnt` へのリンク | E0320 |
| 標準ライブラリにない名前 | `import Benitoite.Unofficial.IO.Consol` | E0321。候補 `Benitoite.Unofficial.IO.Console` と置き換え |
| 非公式のモジュールを最終の名前で取り込む | `import Benitoite.IO.Console` | E0321 と `unofficial` の注記。置き換え `Benitoite.Unofficial.IO.Console` |
| 標準のモジュールを非公式の名前で取り込む | `import Benitoite.Unofficial.Trait` | E0321 と `standard` の注記。置き換え `Benitoite.Trait` |
| 非公式のモジュールの取り込み | `import Benitoite.Unofficial.IO.Console` | 誤りなし。モジュールの表の名前は `Benitoite.IO.Console` |
| 根の直下の `Benitoite` | 根に `Benitoite/X.bnt` があり `import Benitoite.X` | E0321 と `root_file` の注記 |
| 循環 | `A` → `B` → `A`、さらに `C` → `C` | E0322 が二つ。一つ目の注記が `A -> B -> A` の形、主な位置が閉じる import |
| 深い依存 | 2000 個のモジュールが一列に取り込み合う（最後が最初を取り込む） | スタックを溢れさせずに E0322 を一つ報告する |
| 読めない実行を始めるファイル | 存在しないパス | 位置を持たない E0101。prelude のモジュールは読まれる |
| 大きさの上限 | 上限の定数を超える内容を持つ `memfs` のファイル（テストでは小さな上限で確かめられるよう、上限の比べ方を内部の関数に分けてよい） | E0101。ソースの表に加わらない |
| 構文の誤りと循環 | 構文の誤りを含む `A` が `B` を取り込み、`B` が `A` を取り込む | 構文の誤りと E0322 の両方が報告され、順序が「診断の順序」のとおり |
| `RealFs` | 一時ディレクトリに実際のファイルを置いて読む | `memfs` と同じ結果（ファイル一つ、import 一つ、見つからない import 一つ） |

ゴールデンテスト: `testdata-next/modules/` に、誤りのない複数のモジュールのプログラムを 07-03「ゴールデンテストの形式（初回リリース版）」のディレクトリの形で置く（`<名前>/main.bnt` と取り込むモジュール、`<名前>.mode` は `check`、`<名前>.exit` は `0`、各 `.bnt` の先頭に `// spec: 01-03 モジュールと import（初回リリース版）` などのコメント）。01-03「モジュールと import（初回リリース版）」の例（`Lib.Text`、`as` による名前、`Benitoite.IO.Console`）を、型検査も通る形で書く。期待値は C05 が初回リリース版の実行器で確かめる。誤りの場合のゴールデンテストは C11 が書く。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 標準ライブラリのすべてのモジュールを読み込んで、読み込みと構文の誤りが出ない
- 読み込みの段に大域の状態がなく、同じ入力から同じファイル ID と診断の並びが得られる
- 診断の文言を処理の中に直接書いていない（`DiagBuilder` と `modules` の `text` の定数だけを使う）

## 確認の観点

- 読む順がファイルシステムの項目の順に依存していないか（`list_dir` の結果は照合だけに使っているか）。
- import の照合を、ファイルを開けたかどうかでなく、ディレクトリの一覧で行っているか（ADR 0244）。
- 読めなかったファイルでファイル ID とモジュールの ID の対応が崩れていないか。
- 循環の検出と作業の一覧の処理が再帰を使っていないか。
- 読み込みの誤りがあっても、読めたものを結果に入れ、ほかのファイルの読み込みを続けているか。
- `memfs` が本番のコードから使われていないか（`#[cfg(test)]`）。

## 難易度の理由

手順そのものは 02-02 と 02-04 が一手順ずつ定めている。難しいのは、ファイルシステムの違い（大文字と小文字の区別、シンボリックリンク）を `ModuleFs` の上で再現してテストできるように作ることと、読めなかったファイル・構文の誤り・循環が重なったときに、ファイル ID の対応と診断の順序を保ったまま読み込みを続けることである。
