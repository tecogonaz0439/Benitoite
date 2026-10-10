# F06 名前解決の拡張

- 依存する作業: [F04](F04-parser-traits-effects.md), [F05](F05-module-loading.md), [R08](R08-builtin-table.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/F06-resolver

## 目的

読み込みの段（[F05](F05-module-loading.md)）が作ったすべてのモジュールの AST とモジュールの表を受け取り、プログラム全体を一つの単位として名前を解決する（02-04「解決の手順」、ADR 0156）。出力は 10-04 の `ResolveOutput`（束縛の表、参照の表、宣言の表、公開の表、prelude を隠した参照の表、標準ライブラリの名前の索引、組み込みの操作の表、`main`、診断）であり、型検査（F07〜F10）と脱糖（F11）が読む。名前と宣言の関係だけで判定できる誤り（見つからない名前、公開、import の誤り、`bind` と `shadow` の書き分け、型の別名と定数の循環など）と、`@deprecated` の警告を報告する。

標準ライブラリのソースも利用者のモジュールと同じく解決し、`@builtin` の名前と組み込みのエフェクトの操作を組み込みの関数の表（10-12。R08 が書く）で引く。標準ライブラリのソースと表の照合のテスト（10-12「確かめること」）も本作業が書く。

R08 に依存するのは、`builtins::lookup_builtin` と表の全体を R08 が書くからである。

## 読む設計書の節

- [名前解決とモジュール読込](../../2026-10-09-design-first-release/02-impl/02-04-resolver.md): 全体（特に「標準ライブラリのソースの持ち方」「束縛と表」「解決の手順」「import の宣言の誤り」「宣言の検査」「名前の引き方」「誤りと修正案」）
- [名前・スコープ・モジュール](../../2026-10-09-design-first-release/01-spec/01-03-names-modules.md): 全体
- [構文](../../2026-10-09-design-first-release/01-spec/01-02-syntax.md): 「ブロックと文」「組と `bind`・`shadow` のパターン（初回リリース版）」「属性（初回リリース版）」「定数（初回リリース版）」「型の別名（初回リリース版）」「型クラス（初回リリース版）」「エフェクトの宣言とハンドラ（初回リリース版）」「レコード（初回リリース版）」
- [代数的データ型とパターンマッチ](../../2026-10-09-design-first-release/01-spec/01-05-data-types.md): 「パターン」「パターンの拡張（初回リリース版）」「レコード（初回リリース版）」
- [型システム](../../2026-10-09-design-first-release/01-spec/01-06-type-system.md): 「型の別名（初回リリース版）」「型クラス（初回リリース版）」
- [エフェクト](../../2026-10-09-design-first-release/01-spec/01-07-effects.md): 「組み込みのエフェクト」「プログラムの入口」
- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md): 「修正案」
- ADR: [0010](../../2026-10-09-design-first-release/decisions/0010-shared-namespace-and-shadowing.md)、[0043](../../2026-10-09-design-first-release/decisions/0043-option-result-rust-names-no-unwrap.md)、[0047](../../2026-10-09-design-first-release/decisions/0047-parenthesized-types-and-uses-binding.md)、[0053](../../2026-10-09-design-first-release/decisions/0053-private-by-default-with-pub.md)、[0099](../../2026-10-09-design-first-release/decisions/0099-qualified-option-result-constructors.md)、[0119](../../2026-10-09-design-first-release/decisions/0119-attributes-test-and-deprecated.md)、[0121](../../2026-10-09-design-first-release/decisions/0121-pattern-extensions.md)、[0123](../../2026-10-09-design-first-release/decisions/0123-top-level-constants.md)、[0124](../../2026-10-09-design-first-release/decisions/0124-type-aliases.md)、[0126](../../2026-10-09-design-first-release/decisions/0126-import-by-module-name.md)、[0128](../../2026-10-09-design-first-release/decisions/0128-prelude-and-benitoite-namespace.md)、[0129](../../2026-10-09-design-first-release/decisions/0129-effects-declared-in-modules.md)、[0130](../../2026-10-09-design-first-release/decisions/0130-builtin-effect-names-and-placement.md)、[0148](../../2026-10-09-design-first-release/decisions/0148-keep-qualified-constructors-and-shared-namespace.md)、[0154](../../2026-10-09-design-first-release/decisions/0154-public-contract-includes-effects-and-supertraits.md)、[0156](../../2026-10-09-design-first-release/decisions/0156-module-loading-and-whole-program-checking.md)、[0157](../../2026-10-09-design-first-release/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[0255](../../2026-10-09-design-first-release/decisions/0255-bind-and-shadow.md)、[0279](../../2026-10-09-design-first-release/decisions/0279-no-duplicate-method-names-in-trait.md)
- インターフェース: [10-04](../10-interfaces/10-04-modules-and-resolve.md)「名前解決の表」、[10-03](../10-interfaces/10-03-syntax.md)「AST」（名前を使うノードと束縛を宣言したノードの表）、[10-05](../10-interfaces/10-05-types.md)「組み込みの型とエフェクトの表」、[10-12](../10-interfaces/10-12-builtin-table.md)「名前の付け方」「項目の種類」「構成子のタグ」「表を引く関数」「確かめること」、[10-11](../10-interfaces/10-11-builtin-interface.md) の `builtin_decl`・`lookup_builtin`、[10-14](../10-interfaces/10-14-prelude-and-stdlib-sources.md)「置き方」「モジュールの一覧」、[10-02](../10-interfaces/10-02-diagnostics.md)「E03 名前、import、公開」、E0431・E0437・E0603・E0604・E0703・E0707・E0708・W0301
- 共通の決まり: [実装の規約](../00-common/00-02-conventions.md)、[作業の進め方](../00-common/00-03-workflow.md)

## 作るもの

- `src/resolve/mod.rs`: 10-04 の `sig=src/resolve/mod.rs`（`resolve`、`ResolveOutput::stdlib`・`binding_of_ref`）の中身。C02 が置いた `file=` の部分は変えない。
- `src/resolve/` の下の非公開の子のモジュール。最小実行版の `src/legacy/resolve/` の `collect.rs`・`lookup.rs`・`walk.rs` を写して新しい AST と表に合わせて書き直し、`suggest.rs`（綴りの近い名前）と `text.rs`（種類の呼び名）は写してそのまま使ってよい（10-04「置く作業と既存のファイル」）。加える子のモジュールの例: `stdlib.rs`（組み込みの型・エフェクト、`@builtin`、組み込みの操作、標準ライブラリの名前の索引）、`imports.rs`（手順 2）、`checks.rs`（手順 4 と 6）、`shadow.rs`（束縛の書き分け）。分け方は本作業で決めてよい。
- `src/resolve/test_support.rs`: `#[cfg(test)] pub(crate) mod test_support;`。`modules::memfs::load_files` で読み込み、`LoadOutput::sources` を渡して `resolve` を呼ぶ補助の関数 `resolve_files(files: &[(&str, &str)]) -> (LoadOutput, ResolveOutput, IdGen)` を置く。型検査以降の作業の単体テストが使う。読み込みの段に誤りがあれば、名前解決を呼ばずにテストを失敗させる。
- 各ファイルの `#[cfg(test)] mod tests`。
- `testdata-next/names/` の下の、誤りのない例（後述の「受け入れテスト」）。

`src/diag/codes.rs` は、本作業が出すコード（後述の「出す診断」）の型板を 10-02「型板の直し方」の範囲で直してよい。ほかのファイル（`syntax`・`modules`・`typeck`・`builtins`・`prelude`・`src/legacy/`）は変えない。10-14 のソースか 10-12 の表に誤りを見つけたら、直さずに作業を止めて報告する。

## 手順の要点

### 全体の手順（02-04「解決の手順」）

モジュールはどの手順でもモジュールの ID の順に扱う。手順 3 と 5 は宣言ごとに独立に行い、ある宣言の誤りはほかの宣言の解決を妨げない。誤りがあっても出力を返す。

1. トップレベルの名前を集め、束縛を作り、モジュールごとのトップレベルの名前の表と公開の表を作る（後述の「束縛の番号の振り方」）。名前の重なり（E0305・E0306・E0309・E0327・E0328）、`Benitoite` という名前（E0325）、モジュールと同じ名前のエフェクト（E0326）を報告する。
2. import の宣言を解決する（後述の「import」）。
3. 宣言のシグネチャを解決する（02-04 の手順 3 の列挙のとおり）。
4. 宣言の検査を行う（後述の「宣言の検査」）。
5. 本体（関数、実装の中の関数、定数の定数式）を、有効範囲の積み重ねを持って解決する（後述の「名前の引き方」「束縛の書き分け」）。
6. 定数の循環を判定する（E0437）。

### 束縛の番号の振り方

束縛の番号は `ids.binding()` で振る。同じソースの集まりから同じ番号が振られるように、本プランは次の順に決める。

1. 名前空間の根 `Benitoite`（`NamespaceRoot`）、`Unit`（`BuiltinType`）、`State`（`BuiltinEffect`）。宣言した場所は `DeclSite::Table`、`module` は prelude の最初のモジュールの ID とする（10-04 の `Binding::module` のコメント）。
2. prelude のモジュールの `Module` の束縛（モジュールの ID の順）。名前はモジュールの名前の最後の段（`List`、`IO`）。
3. モジュールの ID の順に、各モジュールについて、(a) 組み込みの型の表（10-05 の `BUILTIN_TYPES`）のうち、そのモジュールに属する項目を表の順に（`BuiltinType`）、(b) `Benitoite.IO` なら `IO.All`（`BuiltinEffect`）、(c) トップレベルの宣言を宣言の順に。各宣言の束縛の直後に、その中の名前（構成子、フィールド、メソッド、操作）を宣言の順に振る。実装の中の関数（`ImplFn`）も、実装の宣言の位置でここに振る（トップレベルの名前の表と公開の表には入れない。02-04「束縛と表」）。
4. 手順 2 で import の宣言に付けた名前の `Module` の束縛（`decls` にも `refs` にも同じ番号を載せる。10-04 の参照の表）。
5. 手順 3 と 5 で出会った順に、型パラメータ・エフェクト変数・局所の束縛。

属するモジュールが読まれていない組み込みの型（`Bytes` など）とエフェクト（ネットワークのエフェクトなど）は、束縛を作らない（10-14「モジュールの一覧」の最後の段落）。組み込みの型の属するモジュールは、`BuiltinTypeDef::module` に `Benitoite` を付けた名前で `ModuleTable::find` で引く。

- 型パラメータとエフェクト変数の `owner` と `index` は、10-04「名前解決の表」の補足と 10-05「型パラメータの番号」のとおりに付ける。実装の中の関数では、`implement` の直後の型パラメータの `owner` は実装の宣言、関数自身の型パラメータの `owner` は関数の宣言である。
- `public` の欄は、構成子・フィールド・メソッド・操作では、それを含む宣言の `public` と同じにする。`deprecated` の欄は、`TopDecl::attrs` の `@deprecated` の文字列とする（属性の形の誤りは構文解析器が報告済み）。

### 標準ライブラリのソース（02-04「標準ライブラリのソースの持ち方」）

- `@builtin("名前")` を付けた本体のない関数（`SourceKind::Prelude` のソースだけにある）は、`builtins::lookup_builtin(名前)` で番号を引き、`BindingKind::BuiltinFn(id)` とする。
- ソースで宣言した組み込みのエフェクトの操作（`Console.writeLine` など。宣言したモジュールとエフェクトの名前が `types::builtin::find_builtin_effect` で見つかるエフェクトの操作）は、`Op` の束縛を作り、`Benitoite.` にモジュールの名前の残りの段と操作の名前をつないだ名前（`Benitoite.IO.Console.writeLine`）で `lookup_builtin` を引いて `builtin_ops` に載せる。
- 表にない名前は、標準ライブラリのソースの誤り（処理系の不具合）である。本プランの決定として、コードを持たない `Diagnostic`（`kind` は `ReportKind::Internal`、`severity` は `Error`、`code` は `None`、`message` は不具合を調べるための英語の文）を `diagnostics` に加える。この文は処理系の不具合の説明なので、診断の表にも `text` にも載せない（00-02「文言」）。
- `stdlib_names`: 読んだ標準ライブラリのモジュールの `public` を付けたトップレベルの名前と、その中の構成子・フィールド・メソッドを、`Benitoite.` から始まる完全な名前で載せる（`Benitoite.Option.Some`、`Benitoite.Map.fromList`、`Benitoite.IO.Console.Write`、`Benitoite.IO.Console.writeLine`、`Benitoite.Pair.Pair`）。組み込みの型も `Benitoite.List.List` の形で載せる。非公式のモジュールの名前も、取り込みの名前ではなく標準に加えた後の名前（`Benitoite.IO.Console.writeLine`）で載せる（[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
- 標準ライブラリのモジュール `Benitoite.X` が同じ名前の型 `X` を持つとき、名前 `X` は、型を書く位置ではその型、修飾の段ではそのモジュールを指す（02-04 の同節の最後の箇条）。

### import（02-04 の手順 2、「import の宣言の誤り」）

- import の宣言に付けた名前（最後の段か `as` の名前）の束縛を、モジュールの表の `ImportLink::target` のモジュールに結び付ける。`target` が `None`（読み込みの誤り）の import は、名前の束縛を作らず、その名前を使う箇所で派生の誤りを出さないように、名前の表に「決まらない import」として記録する（本プランの決定。その名前で始まる修飾した名前は、診断を出さずに参照の表に載せない）。
- 誤り: 同じ名前の二つの import（E0323。`alias` の修正案の `{suggestion}` はモジュールの名前の最後の二段をつないだ名前など、同じファイルで重ならない名前）、`as Benitoite`（E0325）、型と同じ名前空間の名前との重なり（E0305 の `import` の修正案）、同じモジュールの二度の取り込み（E0324。`remove` の置き換えは、二度目の import の行を行末の改行まで消す）。
- import の名前が prelude の名前と同じときは誤りにしない。利用者の名前が prelude の名前を隠す。

### 名前の引き方（02-04「名前の引き方」、01-03「修飾された名前の解決」「修飾しない名前の解決」）

- 修飾しない小文字の名前: 有効範囲の積み重ね（内側から）、同じモジュールのトップレベルの関数・定数・そのモジュールのエフェクトの操作の順に引く。
- 型を書く位置と `uses` の修飾しない大文字の名前: 有効な型パラメータとエフェクト変数、同じモジュールのトップレベルの名前、import の名前、prelude の名前の順。利用者の名前が見つかり、同じ綴りの prelude の名前もあれば、その参照を `prelude_shadowed` に載せる。
- 修飾した名前: 01-03 の表のとおり一段ずつ引く。ほかのモジュールでは公開の表を使う。`Benitoite` の中では prelude のモジュールだけを引く。途中の段の結果は参照の表に載せない。
- 式とパターンの修飾しない大文字の名前は、レコードの構築とレコードのパターンの形のレコードの名前と、構成子が一つで型と同じ名前の構成子（`Pair`）に限る。
- `OpRef`（`handle` の節の名前）は、式の小文字の名前と同じく引く。操作であるかは型検査が判定する。
- `ImplFn` は、実装の `ClassRef` が指す型クラスのメソッドを名前で引き、参照の表に載せる。`ImplFn::decl.id` は `decls` に関数自身の束縛を載せる。
- `FieldArg`・`FieldPat` は、`RecordExpr`・`RecordPat` のレコードのフィールドを名前で引いて参照の表に載せる。レコードにないフィールドは参照の表に載せず、診断は出さない。誤りは型検査が E0429 として報告する（10-02 の割り当て。本プランの決定）。
- 選択肢で同じ名前を束縛する `match` の分岐は、最初の選択肢の `VarPat` が束縛を宣言し、ほかの選択肢の同じ名前の `VarPat` は参照の表でその束縛を指す（10-04）。名前の集まりの違いは E0604、一つの選択肢の中の二度の束縛（`..rest` を含む）は E0311。
- 分岐のパターンの変数が、その位置で見えるトップレベルの定数と同じ名前なら E0603。`guard` の置き換えは、パターンがその変数だけで、ガードがなく、選択肢が一つのときだけ付け、変数を `n`（`n` が見えていれば付けない）に置き換え、パターンの後に ` if n = 定数の名前` を挿入する（本プランの決定）。

### 束縛の書き分け（01-03「シャドーイング」、02-04「名前の引き方」、ADR 0255）

- 「局所の名前として見えている」は、有効範囲の積み重ねのどれかの段にあることで判定する。トップレベルの関数と定数は数えない。
- 束縛を段に加える時点は 02-04 の箇条のとおりとし、検査は加える直前に行う。
- `bind` の左辺の変数がすべて見えている: E0334（置き換え `shadow` は `BindStmt::keyword_span` を `shadow` にする）。
- `shadow` の左辺の変数がどれも見えていない: E0335（置き換えは `bind` にする）。
- 見えている名前と見えていない名前が混ざる: E0336（置き換えなし）。
- `shadow` の左辺が変数を束縛しない: E0337（置き換えは `shadow` を `bind` にする）。
- キーワードを書けない束縛（ラムダの引数、分岐のパターンの変数、`handle` の節の引数、`with` の束縛）が見えている名前を隠す: E0338。`{binder}` は `resolve` の `text` の呼び名。分岐の名前の集まりについて一度だけ検査する。
- どの診断も、見つけた束縛の宣言の span を補助の位置（`visible`・`hidden`）に示す。

### 宣言の検査（02-04「宣言の検査」、手順 4 と 6）

- 公開する契約（E0329）: 01-03「公開（初回リリース版）」の規則と ADR 0154 の三つの箇条を、関数の型の内側も含めて調べる。`make_public` の置き換えは、使った非公開の宣言の項目の最初の字句（属性と説明の後）の前に `public ` を挿入する。
- 型の別名の循環（E0431）: 別名の右辺が、直接かほかの別名を通して自分を参照するか。循環ごとに一度、並びを補助の位置で示す。
- 上位の型クラスの循環（E0703）、一つの型クラスの中のメソッドの名前の重なり（E0328）、実装の中の関数が型クラスのメソッドでない（E0708。`similar` の候補が一つなら置き換え）、メソッドの欠けた実装（E0707）。これらは 02-04 が名前解決の検査としており、10-02 のとおり本作業が出す（型を比べる実装の検査は F08）。
- 定数の循環（E0437）: 手順 6 で、定数式が参照する定数の関係を辿る。循環ごとに一度報告する。
- 定数式の形（E0433）は、10-02 の割り当てに従い型検査（F07）が報告する。本作業は判定しない（02-04 の手順 6、02-05「定数の検査と評価」）。
- `main`: 実行を始めるモジュール（`ModuleKind::Entry`）のトップレベルの関数 `main` の束縛を `ResolveOutput::main` に入れる。ないときと形の誤りは型検査が報告する。
- 型パラメータの名前の検査（E0312・E0313）、引数の重なり（E0310）。

### 誤りと修正案（02-04「誤りと修正案」）

- 見つからない名前は、修飾しない名前が E0301、修飾した名前の最初の段が E0302、後の段が E0303。どの段で見つからなかったかを、その段の span で示す。`similar` の候補は編集距離 2 以下、距離の小さい順に最大 3 つ。候補が一つのときだけ名前の span を置き換える修正案を付ける。
- 最初の段が見つからず、標準ライブラリのモジュールの名前の最後の段（`prelude::STDLIB` の全項目の `path` の最後。読んでいないモジュールを含む）と一致するときは、E0302 の代わりに E0332 とし、`import` の置き換えは、ファイルの最初の `import` の行の前（`import` がなければ最初のトップレベルの宣言の行の前）に `import Benitoite.X.Y` と改行を挿入する（本プランの決定）。非公式のモジュール（`STDLIB` の項目の `unofficial` が真）では、`import Benitoite.Unofficial.X.Y` を挿入する（02-04「誤りと修正案」、[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
- `String.length` などの単位を持たない名前と `unwrap`・`expect` は、E0303 の `length`・`slice`・`index_of`・`unwrap` の注記を付ける（01-04、ADR 0043）。取り込んだモジュールが取り込んだ名前を通して引いたときは `not_reexported`。
- 公開していない名前は E0330（見つからない名前と区別する）。
- 種類の合わない名前は E0304（`{found_kind}`・`{expected_kind}` は `resolve` の `text` の呼び名）。
- `uses` の最初の要素がエフェクトでない: E0315。`uses IO` は E0333 とし、`IO` を `IO.All` に置き換える修正案を付ける。
- `uses` の後の要素がエフェクトでない: E0316。`paren` の置き換えは、その `uses` を持つ関数の型の開始の前に `(` を、エフェクトの最後の要素の後に `)` を挿入する（ADR 0047）。
- 修飾しない構成子（`Some(x)`、`Circle(r)`）: E0331。その位置から書ける修飾した名前が一つに決まれば `qualify` の置き換えを付ける。
- エフェクトを型の位置に書いた: E0314。

### `@deprecated` の警告（W0301）

属性を付けたトップレベルの宣言（中の構成子・フィールド・メソッド・操作を含む）を、その宣言の外（本体とシグネチャの外）から名前で参照したごとに W0301 を出す。`message` の注記に属性の文字列を、`declared` の補助の位置に宣言の名前を示す。標準ライブラリのソースの中の警告を除くのはパイプライン（F18）であり、本作業はすべて出す。

## 出す診断

E0301〜E0306、E0309〜E0316、E0323〜E0338、E0431、E0437、E0603、E0604、E0703、E0707、E0708、W0301（10-02「コードの一覧」。E0318〜E0322 は F05）。修正案の置き換えは、各コードの `fixes` の鍵について、置き換えが一つに決まるときに本作業が付ける。02-10「修正案」の表との最後の突き合わせは F16 が行う。

## 受け入れテスト

単体テストで確かめる。`test_support::resolve_files` で複数のファイルを与え、診断はコードと主な位置の span で、束縛は種類と宣言したノードで確かめる。

**標準ライブラリ**

- 標準ライブラリのすべてのモジュールを読む（prelude でないモジュールをすべて取り込む）プログラムの名前解決が、診断を出さない。
- ソースと表の照合（10-12「確かめること」の「ソースと表の照合」の全項目）: すべての `@builtin` の名前と組み込みのエフェクトの操作が表にあり、`@builtin` の名前が `Benitoite.`・`%` から始まらない。宣言の引数の数が `BuiltinDecl::arity` と一致する。操作の項目の権限が `Io`、`Declared` の項目の権限が `Io` でない。権限が `Pure` の項目の宣言の `uses` がエフェクトの名前を含まない。表の `Declared`・`EffectOp` の項目が、ソースのちょうど一つの宣言から参照される。
- `builtins::table::tags` の各定数が、`Option`・`Result`・`Pair`・`Triple`・`IOErrorKind`・`RoundingMode` のソースの構成子の宣言の順と一致する。
- `stdlib("Benitoite.Option.Some")` が構成子の束縛、`stdlib("Benitoite.Map.fromList")` が関数の束縛、`Benitoite.IO.Console` を取り込まないプログラムで `stdlib("Benitoite.IO.Console.Write")` が `None`。
- 組み込みの型の束縛: `Integer` は `Benitoite.Integer` の `BuiltinType`、`Unit` と `State` は prelude の名前、`IO.All` は `Benitoite.IO` の `BuiltinEffect`。`builtin_ops` に `Console.writeLine` の操作の束縛が載る。
- 同じ入力を二度解決すると、同じ束縛の番号が振られる。

**名前の引き方とモジュール**

| 場合 | 期待する結果 |
|---|---|
| 01-03「モジュールと import（初回リリース版）」の例（`Lib.Text`、`as GShape`、`Benitoite.IO.Console`。非公式のモジュールなので、import の行は `Benitoite.Unofficial.IO.Console` に置き換える） | 診断なし。`Text.slug` の参照が `Lib.Text` の関数の束縛 |
| `Geo.Shape.Circle`（取り込んだモジュールの型の構成子）、`Benitoite.Option.Some` | 参照の表が構成子を指す |
| 公開していない関数を取り込んだ側から使う | E0330（E0301 でない） |
| `A` が `import Lib.B` と書き、取り込んだ側が `A.B.x` と書く | E0303 と `not_reexported` の注記 |
| 取り込んでいない `Console.writeLine` | E0332。置き換えを当てると誤りがなくなる |
| 利用者の `data Option` が prelude の `Option` を隠す | 型の位置の参照が利用者の型を指し、`prelude_shadowed` に載る。`Benitoite.Option` は prelude の側を指す |
| `List.map` と型の位置の `List[Integer]` | 前者は `Benitoite.List` のモジュールの関数、後者は組み込みの型 |
| 名前の重なり（型とレコード、関数と定数、関数と同じモジュールの操作、import の名前と型） | それぞれ E0305、E0306、E0306、E0305（`import` の修正案） |
| `effect Log` をモジュール `Log` に書く | E0326 |
| 同じ名前の二つの import、同じモジュールの二度の取り込み、`as Benitoite` | E0323、E0324、E0325 |
| `uses IO`、`uses Integer`、`function(function() -> Unit uses Console.Write, Integer) -> Unit` | E0333（置き換え `IO.All`）、E0315、E0316（括弧の置き換え） |
| `Some(1)`、`Circle(1.0)` | E0331。置き換えが `Option.Some`、`Shape.Circle` |
| `String.length(s)`、`Option.unwrap(o)` | E0303 と `length`、`unwrap` の注記 |
| 型パラメータ `List`、`Benitoite`、同じ並びの `T` の二度 | E0313、E0313、E0312 |
| 公開する関数の引数、`uses`、`public trait` の上位の型クラスに非公開のもの | それぞれ E0329 |

**束縛の書き分けとパターン**（01-03「シャドーイング」の例を含む）

| 場合 | 期待する結果 |
|---|---|
| 01-03 の `normalize` | 診断なし |
| 01-03 の `total`（ラムダの引数 `sum`） | E0338、補助の位置は `bind sum` |
| 見えている `x` を `bind x` | E0334、置き換えは `shadow` |
| 見えていない `y` を `shadow y` | E0335、置き換えは `bind` |
| `shadow Pair(a, b) <- p`（`a` だけ見えている） | E0336 |
| `shadow _ <- e` | E0337 |
| トップレベルの関数と同じ名前を `bind` | 診断なし |
| `with` の二つの束縛が同じ名前 | E0338 |
| 右辺の名前 `shadow x <- x + 1` | 右辺の `x` は外側の束縛を指す |
| 選択肢 `case Option.Some(x), Option.None ->` | E0604 |
| 選択肢 `case Pair(x, 0), Pair(0, x) ->` | 診断なし。二つ目の `x` の `VarPat` が参照の表で最初の `x` の束縛を指す |
| `case [x, ..x] ->` | E0311 |
| 定数 `maxRetries` と同じ名前の分岐のパターンの変数 | E0603（置き換えは付かない。`n` が見えていないときは付く場合も確かめる） |
| 束縛の文と引数で定数と同じ名前 | 診断なし |
| ブロックの `shadow` の有効範囲の外 | 隠された束縛が再び見える |

**宣言の検査と警告**

- `type A = B`、`type B = List[A]`: E0431 が一つ。
- `const a: Integer = b`、`const b: Integer = a`: E0437 が一つ。
- 上位の型クラスの循環: E0703。型クラスの中の同じ名前のメソッド: E0328。実装の中の型クラスにない関数: E0708。メソッドの欠けた実装: E0707。
- `@deprecated("use g")` を付けた `f` を別の関数から呼ぶ: W0301 と `message` の注記。`f` 自身の本体の中の再帰の参照は警告しない。
- 誤りのあるプログラムでも、独立した誤りをすべて報告し、派生した誤りを出さない（見つからない import の名前で始まる参照、見つからない型の名前を使う箇所）。

ゴールデンテスト: `testdata-next/names/` に、誤りのない例（01-03「シャドーイング」の `normalize`、`shadow` の有効範囲、選択肢で同じ名前を束縛する分岐、prelude を隠す利用者の型と `Benitoite.X` の参照、`public` を付けた宣言を別のモジュールから使う例）を 07-03 の形式で置く（`.mode` は `check`、`.exit` は `0`、先頭に `// spec:` のコメント）。型検査も通る形で書く。期待値は C05 が確かめる。誤りの場合のゴールデンテストは C11 が書く。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 標準ライブラリのすべてのモジュールの名前解決が診断を出さず、ソースと表の照合のテストが通る
- 同じ入力から同じ束縛の番号が振られる
- 診断の文言を処理の中に直接書いていない（`DiagBuilder`、`resolve` の `text`、10-02 の鍵だけを使う。処理系の不具合の説明の文を除く）
- 完了の報告の「判断したこと」に、`codes.rs` の型板を直した箇所を挙げる

## 確認の観点

- 名前を引く順序が 01-03 と 02-04 の順と一致しているか。特に、`Benitoite` の中で prelude でないモジュールを引けないこと、取り込んだモジュールでは公開の表だけを使うこと。
- 組み込みの型・関数・エフェクトを綴りでなく束縛の番号と表で照合しているか（ADR 0128）。
- `bind` と `shadow` の判定が「積み重ねにあるか」だけで行われ、トップレベルの関数と定数を数えていないか。
- 選択肢の変数の束縛が一つにまとめられ、`VarPat` が `decls` か `refs` のどちらか一方にだけ載っているか。
- 派生した誤りを出していないか（読み込みの誤りの import、見つからない名前を使う箇所）。
- 置き換えを付ける条件が「当てれば誤りがなくなる」ときに限られているか。
- 本体の解決で、利用者のプログラムの深さに比例しない以上の再帰をしていないか（AST の辿りは再帰でよい。00-02「再帰の深さ」）。

## 難易度の理由

最小実行版の名前解決を写せるが、モジュールの表・公開・import・`Benitoite` の名前空間・prelude を隠す名前によって、名前を引く順序の場合が大きく増える。標準ライブラリのソースと組み込みの表の照合、束縛の番号を決まった順に振ること、`bind` と `shadow` の書き分け、選択肢の束縛の共有を、どれも派生した誤りを出さずに整合させる必要がある。
