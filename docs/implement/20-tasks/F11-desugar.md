# F11 脱糖

- 依存する作業: [F07](F07-typeck-records-constants.md), [F08](F08-typeck-traits.md), [F09](F09-typeck-effects.md), [F10](F10-typeck-patterns.md), [F13](F13-core-check.md)（受け入れテストがコア IR の検査器を使う。後述の「受け入れテスト」）。R08 には F06 を通して依存する（組み込みの関数の表を引く関数の中身を R08 が書く）
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）（テストを含む Rust の行数の目安）
- ブランチ: impl/F11-desugar

## 目的

型検査を通ったプログラム全体（すべてのモジュールと標準ライブラリのソース）の AST を、初回リリース版のコア IR（10-06 の `CoreProgram`）に移す。01-12「表層からの脱糖」と「初回リリース版の拡張」の規則を、構文ごとに一つの Rust の関数として実装する（02-06「脱糖」）。読む表は、名前解決の `ResolveOutput` と型検査の `TypeckOutput` と、組み込みの関数の表（10-12）の関数だけである。各ノードに型・エフェクト・由来位置を付け、後の段（判定の木への変換 F12、検査器 F13、参照インタプリタ F14、コード生成 F15）がそのまま使える形にする。

最小実行版の脱糖（`src/legacy/ir/desugar.rs`）を写して始めてよい。ただし、IR の型、名前解決と型検査の表の形が変わったので、名前の引き方と型の付け方は本文書と 10-06 に合わせて書き直す。

## 読む設計書の節

- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md): 「構文」「表層からの脱糖」（全項）「初回リリース版の拡張」（全項。とくに「トップレベルの定数」「基本型とコレクションの型」「リストの展開」「レコード」「文字列補間」「型クラス」「ストア：可変のセルと明示遅延」「関数の境界と `escape`：途中の `return` と `try`」「解放の枠と実行時エラーの継続：`with`」「ハンドラ」）「置き換えてよい等式」
- [中間表現と脱糖](../../design/02-impl/02-06-ir-and-lowering.md): 「工程」「コア IR」（型とエフェクトの付け方の表を含む）「脱糖」「辞書の引数」「パターンの拡張」「下位 IR からコード生成へ渡すもの」
- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「合成ノードの由来位置」
- [構文](../../design/01-spec/01-02-syntax.md): 「パイプ」「部分適用のプレースホルダ」「文字列補間（初回リリース版）」「リストの展開（初回リリース版）」「レコード（初回リリース版）」
- [評価意味論](../../design/01-spec/01-08-evaluation.md): 「評価順序」「末尾呼び出し」
- [代数的データ型とパターンマッチ](../../design/01-spec/01-05-data-types.md): 「パターンの拡張（初回リリース版）」「レコード（初回リリース版）」
- [型検査器](../../design/02-impl/02-05-typechecker.md): 「出力」「型クラスの制約の解決」
- [バイトコードとコード生成](../../design/02-impl/02-07-bytecode.md): 「原型の名前と由来の種類」（定義の名前と由来の決め方）
- ADR: [0017](../../design/decisions/0017-ir-in-core-calculus-form.md)、[0050](../../design/decisions/0050-pipe-with-parenthesized-rhs.md)、[0096](../../design/decisions/0096-explicit-return.md)、[0097](../../design/decisions/0097-prefix-try.md)、[0123](../../design/decisions/0123-top-level-constants.md)、[0128](../../design/decisions/0128-prelude-and-benitoite-namespace.md)、[0133](../../design/decisions/0133-builtin-equality-and-key-constraints.md)、[0155](../../design/decisions/0155-resume-not-in-lazy.md)、[0158](../../design/decisions/0158-type-classes-by-dictionary-passing.md)、[0159](../../design/decisions/0159-pattern-extensions-in-decision-trees.md)、[0255](../../design/decisions/0255-bind-and-shadow.md)、[0272](../../design/decisions/0272-list-spread-in-list-literals.md)
- インターフェース: [中間表現](../10-interfaces/10-06-ir.md)の「値と計算を分ける形」「型、辞書、継続」「コア IR」「脱糖」「10-12 に求めるもの」、[型と型検査](../10-interfaces/10-05-types.md)の「型パラメータの番号」「型の表現」「型検査の出力」、[モジュールと名前解決](../10-interfaces/10-04-modules-and-resolve.md)の「名前解決の表」、[組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「項目の種類」「表を引く関数」「10-06 との対応」、[組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `builtin_decl`・`Capability`、[字句と構文木](../10-interfaces/10-03-syntax.md)の「AST」

## 作るもの

- `src/ir/desugar.rs`: 10-06 の `sig=src/ir/desugar.rs` の `desugar` の中身と、非公開の補助の関数。構文の種類が多いので、`desugar.rs` の下に非公開の子のモジュールを置いてよい（例: `desugar/exprs.rs`・`desugar/dicts.rs`・`desugar/patterns.rs`・`desugar/decls.rs`）。子のモジュールの分け方は実装 LLM が決める。
- `src/ir/desugar.rs` の中の `#[cfg(test)] pub(crate) mod test_support`: ソースの文字列の組（ファイルのパスと内容）から `CoreProgram` を作る補助の関数を一つ置く（後述の「テストの補助」）。後の作業（F14・F15 のテスト）が使う。
- `src/ir/check.rs`（F13 のファイル）の、ラムダの検査の修正（後述の「F13 の検査器のラムダの検査」）。
- 各ファイルの `#[cfg(test)] mod tests`。

これ以外のファイルは変えない。`src/ir/check.rs` は、次の「F13 の検査器のラムダの検査」の変更に限って直してよい。`src/legacy/` は読むだけにし、`crate::legacy` を参照しない。

### テストの補助

【本プランの決定】補助の関数は次の一つとする。

```rust
pub(crate) fn desugar_files(
    files: &[(&str, &str)],
    require_main: bool,
) -> (LoadOutput, ResolveOutput, TypeckOutput, CoreProgram)
```

- 引数は F07 の `typeck::test_support::check_files` と同じである。`files` の先頭の組が実行を始めるモジュールになる（F05 の `modules::memfs::load_files`）。`require_main` は `check_files` と `typecheck` にそのまま渡す。真なら `CoreProgram::main` は `Some` になり、F14・F15 のテストはその `main` を実行できる（F15 の `start_main`、F14 の開始状態）。偽なら `main` は `None` になる（F14 の「`main` のないプログラム」の場合）。
- 手順: `check_files` を呼び、返った診断に誤り（`Diagnostic::is_error`）が一つでもあれば、診断を並べた文でテストを失敗させる（panic）。警告だけなら続ける。続けて `desugar(&load.modules, &load.asts, &resolved, &types)` を呼び、`Err` ならテストを失敗させる。最後に `check_program` を当て、空でなければ誤りを並べた文でテストを失敗させる。後述の「受け入れテスト」の「すべてのテストで `check_program` を当てる」は、この補助を通すことで満たす。
- 戻り値は、`check_files` の戻り値の初めの三つ（読み込みの結果、名前解決の出力、型検査の出力）と、脱糖の結果である。F15 は読み込みの結果の `sources`（`SourceTable`）を `codegen` に渡し、本作業のテストは名前解決の出力で束縛を引いて結果と比べる。

### F13 の検査器のラムダの検査

02-06「コア IR」の表と本文書の「型とエフェクトの付け方」は、ラムダの型のエフェクトを `lambda_effects` の値とする。F07 は、`uses` を書いたラムダでは注釈の集合をそのまま `lambda_effects` に記録するので、本体が純粋な `uses` 付きのラムダでは、ラムダの型のエフェクトが本体のエフェクトより大きくなる。02-06「コア IR の検査器」と F13 の「包含を使う位置」は、ラムダの本体を包含を使う位置に挙げており、この形を正しいとする。ところが取り込み済みの検査器は、`Checker::lambda`（`src/ir/check.rs` の 446〜461 行）でラムダの型のエフェクトを本体の `body.eff` から作り、`Checker::value`（同 409〜411 行）でその型と `val.ty` の完全な一致を求めるので、この形を誤りにする。検査器のほうが設計書より厳しすぎる。

本作業は、検査器のラムダの検査を次のように直す。

- `Checker::lambda` は、ラムダの値の型 `val.ty`（`Ty::Fn`）のエフェクトをラムダの型のエフェクトとし、本体の `body.eff` がそれに含まれるかを `Checker::effects` で調べる。導いた型は、引数の型と本体の型と `val.ty` のエフェクトからなる関数の型とする。`val.ty` が関数の型でなければ、従来どおり `body.eff` から作り、`Checker::value` の一致の検査に誤りを報告させる。`val.ty` を渡すために `Checker::lambda` の引数を変えてよい（非公開の関数である）。
- F13 の既存のテストの結果を変えない。結果が変わるテストがあれば、02-06 のとおりの結果に直し、完了の報告に挙げる。
- 本体のエフェクトがラムダの型のエフェクトより大きいラムダを誤りにすること（包含を許しても甘くしすぎていないこと）と、本体が純粋な `uses` 付きのラムダを受け入れることを、`src/ir/check.rs` のテストに加える。

## 手順の要点

### 全体の流れと状態

1. `types.main` を写す。`Some` なら `Program::main` は `Some(MainInfo::binding)`、`main_returns_result` は `MainInfo::returns_result` とし、`None`（`require_main` が偽の経路）なら `Program::main` を `None`、`main_returns_result` を偽にする（10-06）。
2. モジュールを ID の順に、モジュールの中では宣言の順に辿り、定義を作る（後述の「定義の並びと名前」）。`Item::Error` と `Stmt::Error` と誤りのノードに出会ったら `InternalError` を返す（誤りのある AST は脱糖に渡らない）。
3. `Program::adts` は `types.adts`、`traits` は `types.traits`、`schemes` は `types.decl_types` を写す。`ops` は、`types.effects` のすべてのエフェクトの操作から作る（後述の「操作の表」）。
4. `BodyId` は、ラムダ（展開で作るラムダを含む）、`lazy` の本体、`handle` の本体、`handle` の節ごとに、プログラム全体で一つの数え上げから振り、最後の値を `body_count` に入れる。
5. `VarId` は定義（トップレベルの関数、フィールドを取り出す関数、実装のメソッド、定数）ごとに 0 から振る。辞書の引数、値の引数の順に振り、本体で作る変数は現れた順に振る。定義の最後の値を `var_count` に入れる。

脱糖の状態（`VarId`・`BodyId` の数え上げ、局所の束縛の番号から `VarId` への表、いま辿っている定義の辞書の引数と実装の制約の数、囲む `handle` の節の `ContVar` の積み重ね、末尾位置の印）は構造体にまとめて `&mut` で渡す。大域の状態にしない（ADR 0015）。

表を引いて結果がないとき（型検査の表にノード番号がない、束縛の種類が想定と違う、組み込みの表の関数が `None` を返す）は、引けなかった表とノード番号を `message` に書いた `InternalError` を返す。型検査を通ったプログラムでは起きないので、`unwrap` の代わりにこの形で返す。

### 表の引き方

| 知りたいもの | 引き方 |
|---|---|
| 表層の式・パターン・引数の型 | `types.expr_types.get(node)` |
| 名前を使う箇所の束縛 | `resolved.binding_of_ref(node)` |
| 宣言したノードの束縛 | `resolved.decls.get(node)` |
| 多相な名前の置き換え `[T̄; Ē]` | `types.type_args.get(node)`。定数と多相でない名前は空 |
| 演算子のオペランドの型 | `types.operand_types.get(node)` |
| `${e}` の e の型 | `types.interp_types.get(segment.expr.id())` |
| ラムダ・プレースホルダを含む呼び出しのエフェクト | `types.lambda_effects.get(node)` |
| 辞書の求め方 | `types.dicts.get(name_expr.id)` |
| `try` の種類 | `types.try_kinds.get(try_expr.id)` |
| `handle` の節の操作と末尾で再開するか | `types.handlers.get(handle_expr.id)` |
| リテラルの値 | `types.lit_values.get(node)`（`LitExpr`、リテラルに直接適用した単項の `-`、`LitPat`） |
| 範囲のパターンの両端 | `types.range_bounds.get(range_pat.id)` |
| 宣言の型 | `types.decl_types.get(binding)` |
| 標準ライブラリの名前 | `resolved.stdlib("Benitoite.List.concatenate")` など |

`ConstValue` の基本型の値は同じ名前の `Const` に移す（`Integer` は `Int`、`String` は `Str` など）。

### 定義の並びと名前

モジュールの種類（10-04 の `ModuleKind`）で由来（`DefOrigin`）を決める。`Entry` と `User` のモジュールの定義は `User`。`Prelude` と `Stdlib` のモジュールの定義は、トップレベルの関数とフィールドを取り出す関数なら、束縛の `public` が真のとき `StdlibPublic`、偽のとき `StdlibHelper`、実装のメソッドは `StdlibPublic` とする。

定義の名前（`Def::name`・`ImplDef::name`・`ConstDef::name`）は、02-07「原型の名前と由来の種類」の名前の表に従い、次のように作る。

| 定義 | 名前 |
|---|---|
| 実行を始めるモジュールのトップレベルの関数 | 関数の名前（`main`） |
| ほかの利用者のモジュールのトップレベルの関数 | モジュールの名前（`ModulePath::dotted`）と関数の名前を `.` でつないだもの（`Report.format`） |
| 標準ライブラリのソースの公開の関数 | `Benitoite` を除いたモジュールの名前と関数の名前（`List.map`、`IO.Console` の関数なら `IO.Console.f` ではなく最後の段だけの `Console.f`。02-07 の例 `Console.writeLine` に合わせる） |
| 標準ライブラリのソースの補助の関数 | 関数の名前 |
| フィールドを取り出す関数 | レコードの名前とフィールドの名前を `.` でつなぎ、トップレベルの関数と同じ規則でモジュールの名前を前に付ける（`Person.name`、`Lib.Person.name`） |
| 実装 | 型クラスの名前、`[`、対象の型の表示（10-05 の `Ty::show`。`TypeArg::Head` は型構成子の名前）、`]`（`Show[Person]`） |
| 実装のメソッド | 実装の名前と `.` とメソッドの名前（`Show[Person].show`） |
| 定数 | 定数の名前 |

【本プランの決定】標準ライブラリのモジュールの関数の名前を最後の段で修飾するのは、利用者がソースで書く形（`Console.writeLine`、`List.map`）と呼び出しの履歴の表示を一致させるためである。

並びは、`Program` のコメントのとおり、モジュールの ID の順、モジュールの中では宣言の順とする。

- `Item::Fn` のうち本体を持つものは `DefKind::Fn` の定義にする。`@builtin` の宣言（`body` が `None`）は定義を作らない（組み込みの関数の項目として `ValKind::Builtin` で指す）。
- `Item::Record` は、レコードの宣言の位置に、フィールドごとの `DefKind::FieldGetter { record, index }` の定義を宣言の順に置く。本体は `match r { C_R(_, …, zi, …, _) ⇒ return zi }`（01-12「レコード」。行は一つ、分岐は一つで、分岐の変数は zi だけ）とし、引数 `r` の型と戻り値の型は `types.decl_types` のフィールドの束縛の宣言の型から写す。`Def::span` と、本体の計算と値の由来位置は、フィールドの宣言（`FieldDecl::span`）とする。
- `Item::Impl` は `ImplDef` にする（後述の「実装」）。`Item::Const` は `ConstDef` にする（後述の「定数」）。`Item::Data`・`Alias`・`Trait`・`Effect` は定義を作らない。

関数の定義の欄は、`types.decl_types` の `Scheme` から写す。`type_params` は型パラメータの名前、`effect_params` はエフェクト変数の名前、`dict_params` は `Scheme::class_constraints` の制約ごとに新しい `VarId` を一つ振った `DictParam`（`constraint` はその制約）、`params` は引数ごとの `Var`（名前はソースの名前、型は `Scheme::params`。引数の宣言したノード `Param::id` の束縛を `VarId` に対応させる）、`ret`・`eff` は `Scheme` の値、`span` は関数の宣言の span である。

### 名前、リテラル、呼び出し、演算子

01-12 の表の各行を関数にする。値が要る箇所は、式を脱糖した計算を新しい変数に `Let` で束縛する。「計算を新しい変数に束縛して続きを作る」補助の関数を一つ作り、各規則で使う。

名前を使う箇所（`NameExpr`）は、最後の段の束縛の種類で分ける（修飾の段の数やモジュールの別名によらない）。

| 束縛の種類 | コア IR |
|---|---|
| `Local(_)` | `Return(Var)` |
| `Fn` | `Return(TopFn { def, targs })`。制約を持つ関数を呼ばずに値として使うときは、後述の「辞書」のラムダ |
| `BuiltinFn(id)` | `Return(Builtin { id, targs, info })`。`info` は後述の「組み込みの関数の `BuiltinInfo`」 |
| `ImplFn` | 型検査の出力の上では名前として使われない（メソッドは `Method` の束縛で使う）。現れたら `InternalError` |
| `Field { .. }` | `Return(TopFn { def: フィールドの束縛, targs })` |
| `Const` | `Return(ConstRef(束縛))`。由来位置は定数の名前の参照（02-02） |
| `Ctor { data, tag }` | 引数のない構成子は `Return(Ctor { adt: data, tag, tys, args: [] })`。引数を持つ構成子を呼ばずに使うときは、01-12 の表のとおり構成子を返すラムダ（`BodyId` を新しく振り、`span` は名前の式の span） |
| `Op { .. }` | `resolved.builtin_ops` にあれば組み込みのエフェクトの操作として `Builtin`（`info` の `class` は `Io`、`op`・`decl` はその操作の束縛）。なければ `Return(Op { op, targs })` |
| `Method { trait_, index }` | 後述の「辞書」 |

`tys`（構成子の型引数）は `type_args` の `tys` の各要素が `TypeArg::Ty` であることを確かめて取り出す。

- リテラル（`LitExpr`、単項の `-` を整数・浮動小数・`Decimal` のリテラルに直接適用した `UnaryExpr`）は、`lit_values` の値の `Return(Const)`。範囲は型検査が確かめてあり、脱糖は字面を読み直さない。括弧を挟んだ `-(5)` は `lit_values` にないので、一般の `neg_T` になる。
- 呼び出しは、呼ばれる式を見て次の順に分ける。パイプとプレースホルダの展開でできた呼び出しも同じ関数を通す。
  1. 呼ばれる式が、引数を持つ構成子を指す `NameExpr` なら、構成子の呼び出し（引数を書いた順に束縛し、`Return(Ctor)`）。
  2. 型クラスのメソッドを指す `NameExpr` なら、メソッドの呼び出し（後述の「辞書」）。
  3. 型クラスの制約を持つ関数（`Scheme::class_constraints` が空でない `Fn` と実装の外から見た関数）を指す `NameExpr` なら、`App { func: TopFn, dicts, args }`。
  4. そのほかは `let y ⇐ ⟦e0⟧ in let x̄ ⇐ ⟦ē⟧ in App { func: y, dicts: [], args: x̄ }`。ただし、呼ばれる式が `Fn`・`BuiltinFn`・`Op`・`Field` を指す `NameExpr` なら、新しい変数に束縛せず、その値を `func` に直接置く（値の計算が `Return` だけなので、01-12「置き換えてよい等式」の `let x ⇐ return V in M = M[V/x]` に当たる。コード生成が組み込みの関数を `PRIM`・`IO` に、操作を `PERFORM` に移すには `func` がその値である必要がある）。
- プレースホルダを含む呼び出しとパイプは、01-02 の規則と ADR 0050 で展開してから上の関数を通す（最小実行版の脱糖と同じ。規則 1 は右辺の呼び出しの直接の引数だけでプレースホルダの有無を判定し、括弧の右辺は規則 2）。展開で作ったラムダの引数の型はプレースホルダのノードの型、エフェクトは `lambda_effects` の呼び出しのノードの値、ラムダとその本体の呼び出しの由来位置はプレースホルダを含む呼び出しの式全体、パイプから作った呼び出しの由来位置はパイプの式全体とする（02-02）。
- 二項演算 `+ - * / div mod < <= > >=` と単項の `-` は、`operand_types` の型が `Ty::Con(TyCon::Builtin(t), [])` であることを確かめ、10-12 の `operator_builtin(op, t)` で項目を引いて `ValKind::Builtin` の適用にする。`BinOp::Div` は `OperatorKind::Div`、`IntDiv` は `IntDiv`、`Mod` は `Mod` である。`=`・`<>` は `equality_builtin(false)`・`equality_builtin(true)` の項目に、`targs` の `tys` を `[TypeArg::Ty(オペランドの型)]` にした適用にする（オペランドの型は基本型に限らない）。`and`・`or`・`not` は 01-12 の表のとおり `If` に移し、右のオペランドを `Let` の左側に移さない（末尾呼び出しを保つ）。演算子を適用する計算の由来位置は演算子の式全体（02-02）。

### 組み込みの関数の `BuiltinInfo`

`ValKind::Builtin` を作るたびに、次のように `info` を埋める（10-06「コア IR」の `BuiltinInfo`、10-12「10-06 との対応」）。

- `class`: `builtins::builtin_decl(id)` の `capability`。
- `op`: 組み込みのエフェクトの操作（`builtin_ops` で引いた項目）ならその操作の束縛、ほかは `None`。
- `decl`: `@builtin` の関数の束縛（`BindingKind::BuiltinFn`）なら、その束縛。組み込みのエフェクトの操作なら、操作の束縛。文字列補間の `str_T` と `List.concatenate` のように表から引いた `Declared` の項目なら、項目の名前（`BuiltinDecl::name`）の前に `Benitoite.` を付けた名前で `resolved.stdlib` から引いた束縛。演算子、`eq`・`ne`、`%` から始まる内部の項目は `None`。
- `intrinsic`: `builtin_intrinsic(id)`。

`targs` は、`decl` があればその束縛の宣言の型の型パラメータとエフェクト変数の数に、なければ `builtin_scheme(id)` の数に合わせる。名前を使う箇所から作る値では、`type_args` の値をそのまま使う。

### 型とエフェクトの付け方

02-06「コア IR」の表に従う。計算のエフェクトは、子の計算から下から求める。

- `TopFn`・`Builtin`・`Op` の値の型は、宣言の型（`TopFn` と `decl` のある `Builtin` と `Op` は `types.decl_types`、`decl` のない `Builtin` は `builtin_scheme`）の `fn_ty()` を `Ty::subst(&targs.tys, &targs.effects)` で置き換えた型。`Op` の型のエフェクトは、宣言の型のエフェクト（操作のエフェクト {L}）である。制約を持つ関数の `TopFn` の型は、値の引数だけからなる関数の型（10-06「型、辞書、継続」）。
- `App` の型とエフェクトは、`func` の型（関数の型）の戻り値の型とエフェクト。
- `Method` の型とエフェクトは、01-12 C-Meth の Bθ と εθ: メソッドの束縛の宣言の型（0 番の型パラメータが型クラスの引数）を、`[型クラスの引数に与えた型, S̄]` と Ē で置き換える。
- `If`・`Match`・`Escape`・`Handle` の型は、元の表層の式の `expr_types` の型。
- `Use` のエフェクトは本体のエフェクトと {`State`} の和集合、`Lazy` の型は `Lazy[本体の型]`（10-05 の `BuiltinTypeId::LAZY`）でエフェクトは空集合。
- `Handle` のエフェクトは、本体のエフェクトから `handled` を除いた集合と、各節の本体のエフェクトの和集合。節の本体のエフェクトは、節の中の `Resume` のエフェクトを除いて求める（02-06「コア IR」の表の後の段落）。
- `Resume` の型は、節を持つ `handle` の式の `expr_types` の型。エフェクトは、その `handle` のエフェクト ε である。ε は節を辿り終えるまで決まらないので、次の順に作る。(1) 節の本体を、`Resume` のエフェクトを空集合として脱糖する。(2) `Handle` のエフェクト ε を上の規則で求める。(3) 各節の本体を辿り直し、その節の `ContVar` を指す `Resume` のエフェクトを ε に置き換え、`Resume` を含む計算のエフェクトを下から求め直す。求め直しても ε は変わらない（02-06 の同じ段落）。(3) はラムダと `lazy` の本体の中に入らない（そこには `Resume` がない。ADR 0155）が、入れ子の `handle` の本体と節の中には入る。外側の節の `Resume` が入れ子の `handle` の本体にあると、そのエフェクトを ε に置き換えたことで、入れ子の `handle` のエフェクトも大きくなりうる。そこで (3) は、入れ子の `handle` に出会うたびに、その本体と節を辿り直した後で、入れ子の `handle` のエフェクトを上の規則で求め直す。変わったら、入れ子の `handle` の節の `Resume`（入れ子の節の `ContVar` を指すもの）のエフェクトも新しい値に置き換え、その節の本体のエフェクトを求め直してから、入れ子の `handle` を含む計算のエフェクトを外へ向かって求め直す。こうしないと、入れ子の節の `Resume` のエフェクトが入れ子の `handle` のエフェクトと食い違い、F13 の `Checker::resume` の等しさの検査が誤りを返す。
- ラムダの型は `function(引数の型) -> 本体の型`、エフェクトは `lambda_effects` の値。本体の型が型検査の表の型と違っても、本体の型を使う（違いがあれば F13 の検査器が見つける）。本体のエフェクトは `lambda_effects` の値に含まれればよく、等しいとは限らない（`uses` を書いたラムダ。前述の「F13 の検査器のラムダの検査」）。

### 文とブロック、`return`

- ブロックは 01-12「ブロック」の表で先頭の文から移す。`bind`・`shadow` は区別しない。左辺が `VarPat` なら `Let`（変数の型は束縛の文の `expr_types`）、`WildcardPat` なら新しい変数への `Let`。そのほかのパターンは、`let z ⇐ ⟦e⟧ in Match { scrutinee: z, rows: [p'], arms: [分岐（変数はパターンが束縛する変数、ガードなし、本体は残りの文の脱糖）] }`。最後の文なら本体は `Return(())`。この `Match` の由来位置は束縛の文全体（02-02）。
- 末尾位置は、脱糖の関数が引数として受け渡す（02-06「脱糖」の `return` の行）。関数とラムダの本体の最後の文、`if` の分岐と `match` の分岐の本体の最後の文、`and`・`or` の右のオペランドは、囲む位置が末尾位置なら末尾位置である。`with` と `lazy` のブロック、`handle` の本体と節、ガード、定数式の中は末尾位置でない。
- 末尾位置の `return e` は `⟦e⟧`、それ以外は `let x ⇐ ⟦e⟧ in Escape(x)`。

### レコード、文字列補間、リストの展開

- レコードの構築 `R(g1: e1, …)`: フィールドの式を書いた順に `Let` で束縛し、宣言の順に並べ替えた変数を引数とする `Return(Ctor { adt: レコードの束縛, tag: 0, tys, args })`。`tys` は `RecordExpr` の `type_args`。構成子の束縛は使わない（レコードは `AdtDef::record` を持つ構成子一つの型）。
- レコードの更新 `R(..e, g1: e1, …)`: 01-12「レコード」の表のとおり。`let r ⇐ ⟦e⟧`、書き換えるフィールドの式を書いた順に束縛し、1 行 1 分岐の `Match` で分解して作り直す。行のパターンは、書き換えるフィールドを `Wild`、書き換えないフィールドを新しい変数の `Var` にした構成子のパターンとし、分岐の変数はその変数を宣言の順に並べたもの。`tys` は e の型 `R[T̄]` の型引数。構成子の適用と分解の由来位置はレコードの式全体（02-02）。
- 文字列補間: 各 `${e}` の e を左から束縛し、`interp_types` の型が `String` でなければ `interpolation_builtin(型)` の項目で文字列にする（`String` は通さない）。続けて、部分の文字列と変換した値を左から `operator_builtin(Add, STRING)` の項目で連結する。【本プランの決定】空の部分の文字列（`"${a}${b}"` の間など）は連結に加えない。空の文字列との連結は値を変えないので、観測できる振る舞いは変わらない。変換の計算の由来位置は `InterpSegment::span`、連結の計算の由来位置は文字列リテラル全体（02-02）。
- リストの展開: 01-12「リストの展開」の表のとおり、要素と展開の式を書いた順に束縛し、`concat_T` でつなぐ。`concat_T` は `resolved.stdlib("Benitoite.List.concatenate")` の束縛が `BuiltinFn(id)` なら `ValKind::Builtin`、`Fn` なら `ValKind::TopFn` とし、`targs` の `tys` を `[TypeArg::Ty(要素の型)]`、エフェクトの置き換えは宣言の型のエフェクト変数の数だけの空集合にする。展開が先頭（k = 0）なら一つ目の `concat_T` を、末尾（k = n）なら二つ目を省く（01-12 が許す）。要素の型は `ListExpr` の `expr_types`（`List[T]`）から読む。

### 辞書

`types.dicts` の `DictExpr` を `DictVal` に移す関数を一つ作る。いま辿っている定義の文脈（関数の定義、実装のメソッドの定義、実装の頭部）を引数に取る。

- `DictExpr::Impl { impl_decl, type_args, args }` は `DictKind::Impl { impl_decl, tys: type_args, args: 子を移したもの }`。`class` は `types.impls` の実装の `class`、`arg` は実装の `target` の型パラメータを `type_args` で置き換えたもの。
- `DictExpr::Param { constraint: c, supers }` は、まず根を作る。実装のメソッドの本体の中で c が実装の制約の数 k' より小さければ `DictKind::ImplParam(c)`、実装の頭部（`ImplDef::supers`）の中でも `ImplParam(c)`、それ以外は定義の `dict_params` の c 番目（メソッドの本体では c − k' 番目）の変数の `DictKind::Param`（10-05「型パラメータの番号」、10-06「型、辞書、継続」）。根の `class` と `arg` は、その制約の型クラスと、制約を付けた型パラメータ（値の型なら `TypeArg::Ty(Ty::Param(i))`、型構成子なら `TypeArg::Head(TyHead::Param(i))`。形は `Scheme::type_params` の `kind`）である。続けて `supers` の型クラス S ごとに `DictKind::Super { of, index }` を重ねる。`index` は、直前の辞書の型クラスの `TraitDef::supers` の中の S の位置、`class` は S、`arg` は直前の辞書と同じ。
- 由来位置は、その制約を生んだ呼び出しか名前の参照の span（02-02）。

これを使って次の構文を移す（01-12「型クラス」の表）。

- メソッドの呼び出し `Cl.m(e1, …, en)`: 引数を書いた順に束縛し、`CompKind::Method`。`dict` は `dicts` の 0 番、`dicts` は 1 番から後、`method` は束縛の `Method { index }`、`targs` は `type_args` の 1 番から後の型と、エフェクトの置き換えのすべて（0 番は型クラスの引数に与えた型なので除く）。
- 制約を持つ関数の呼び出し: `App::dicts` に、`dicts` の値を制約の番号の順に移して並べる。
- メソッドを値として使う `Cl.m`、制約を持つ関数を呼ばずに値として使う `f`: `Return(Lambda)`。ラムダの引数は、置き換えた宣言の型の値の引数の型の新しい変数、本体は上の呼び出し。ラムダの `span` と由来位置は名前の参照の span、エフェクトは置き換えた宣言の型のエフェクト。
- 実装 `implement … end implement`: `ImplDef` の `class`・`type_params`・`target`（`types.impls` の `target`）・`dict_params`（`types.impls` の `class_constraints`）を写し、`origin` はメソッドの定義と同じ規則（`Entry`・`User` のモジュールなら `User`、`Prelude`・`Stdlib` のモジュールなら `StdlibPublic`。前述の「定義の並びと名前」）、`span` は実装の宣言（`ImplDecl::span`）とする。`supers` は `types.impls` の `supers` を実装の頭部の文脈で移す。`methods` は `TraitDef::methods` の順（`types.impls` の `methods` の束縛の順）に、実装の中の関数ごとに `DefKind::Method { impl_decl, index }` の定義を作る。【本プランの決定】メソッドの定義の `type_params` は、実装の型パラメータの後に関数自身の型パラメータを並べたもの（宣言の型の番号と同じ並び）、`dict_params` は関数自身の制約（`Scheme::class_constraints` の k' 番から後）だけとする（10-06 の `Def::dict_params` のコメント）。

### `try`、`with`、`lazy`、エフェクトの操作と `handle`

- `try e`: 01-12「関数の境界と `escape`」の表のとおり、`let x ⇐ ⟦e⟧ in Match { x; 行は成功の構成子と失敗の構成子 }`。分岐 0 は `Ok(y)`・`Some(y)` で本体 `Return(y)`、分岐 1 は `Error(z)` で本体 `Escape(Error[U, E](z))`、または `None` で本体 `Escape(None[U]())`。種類と U・E は `try_kinds` の `TryInfo`（`ret` が `Result[U, E]` か `Option[U]`）から読む。分岐の変数 y・z の型は、対象の式 e の型（`expr_types`。`Result[T, E1]` か `Option[T]`）の型引数から取る。y は T、z は E1 である。構成子の型の束縛とタグは、`resolved.stdlib("Benitoite.Result.Ok")` などで引いた束縛の `BindingKind::Ctor { data, tag }` から取る（綴りでなく名前空間の名前で照合する。ADR 0128）。`Match` と `Escape` の由来位置は `try e` 全体（02-02）。
- `with x1 = e1, … do B end with`: 01-12「解放の枠と実行時エラーの継続」の表のとおり、束縛の順に `Let` と `Use` を入れ子にする。`with` の束縛の変数の型は `WithBind` の `expr_types`。`Use` の由来位置は、その解放に当たる束縛 `x = e` の span（02-02）。
- `lazy B end lazy`: `CompKind::Lazy { id: 新しい BodyId, body: ⟦B⟧ }`。由来位置は `lazy` から `end lazy` まで。
- エフェクトの操作の呼び出し: 前述の名前の表のとおり、利用者の操作は `ValKind::Op` の適用、組み込みのエフェクトの操作は `ValKind::Builtin` の適用にする。
- `handle B with case … end handle`: `CompKind::Handle`。`id` は本体の新しい `BodyId`、`handled` は `handlers` の `HandleInfo::handled`。節ごとに、`id` は新しい `BodyId`、`op` と `tail_resumptive` は `HandleInfo::clauses` の同じ位置の値、`params` は `ClauseParam` ごとの新しい変数（名前を書いたものは束縛の `VarId`、`_` は名前のない変数。型はどちらも `ClauseParam` のノードの `expr_types`）、`cont` は新しい変数の `ContVar`、`node` は節（`case`）の AST のノード番号（`Ty::Rigid` の `clause` と同じ番号。10-06 の `Clause::node`）、`span` は節の `case` から本体の終わりまで。`ContVar::arg` は、節の操作の宣言の型の戻り値の型の型パラメータ i を `Ty::Rigid { clause: 節のノード番号, index: i }` に置き換えた型である（10-05「型パラメータの番号」）。
- `resume(v)`: `let x ⇐ ⟦v⟧ in Resume { cont, value: x }`。`cont` は、`resume` を囲む最も内側の節の `ContVar::id`（状態の積み重ねの一番上）。型とエフェクトは前述の「型とエフェクトの付け方」。

### `match` とパターン

02-06「パターンの拡張」のとおり、表層の分岐ごとに `MatchArm` を一つ、分岐の選択肢ごとに `MatchRow` を一つ、元の順に作る。

- 分岐の変数（`MatchArm::vars`）は、最初の選択肢が束縛する変数を、パターンの中で左から現れる順に並べたもの。最初の選択肢の `VarPat`（と名前のある `ListRest`）は束縛を宣言したノードであり、ほかの選択肢の同じ名前の `VarPat` は参照の表でその束縛を指す（10-04「名前解決の表」）ので、どちらも同じ `VarId` に移る。分岐の変数の型は、最初の選択肢の `VarPat` の `expr_types` の型、名前のある `ListRest` なら `ListRest` のノードの `expr_types` の型（`List[T]`）とする。
- パターンは `CorePat` に移す: `WildcardPat` は `Wild`、`VarPat` は `Var`、`LitPat` は `lit_values` の値の `Const`、`UnitPat` は `Const(Unit)`、`CtorPat` は型名の修飾を除いた `Ctor { adt, tag, args }`（束縛の種類 `Ctor { data, tag }`）、`RecordPat` はフィールドを宣言の順に並べ書かないフィールドを `Wild` にした `Ctor { tag: 0 }`、`RangePat` は `range_bounds` の値の `Range`、`ListPat` は `List { before, rest, after }`（`rest` は `..` を書いたときだけ `Some`、`..rest` の変数は `ListRest::var`）。
- ガードは、末尾位置でない計算として脱糖し、`MatchArm::guard` に入れる。本体は分岐ごとに一度だけ脱糖する。
- 対象の式は `let x ⇐ ⟦e⟧ in Match { scrutinee: x, … }` の形にし、`scrutinee` は常に変数にする（F12 はこれを前提にする）。行（`MatchRow`）と `CorePat` は由来位置を持たない（02-02 の表の `match` の選択肢の行）。`Match` の計算の由来位置は `match` の式全体とする。

### 定数

`Item::Const` ごとに `ConstDef` を作る。`body` は定数式を空の局所の束縛の表で脱糖した計算（変数は定数の定義の数え上げで振り、`var_count` に入れる）、`value` は `types.consts` の値、`ty` は宣言の型の `ret`、`span` は定数の宣言の span である。定数の参照は前述のとおり `ConstRef`。

### 操作の表

`types.effects` のエフェクトごとに、`ops` の束縛の順に `OpDef` を作る。`effect` は `EffectDef::name`、`arity` は操作の宣言の型の引数の数、`builtin` は `resolved.builtin_ops` の値。`name` は、利用者のエフェクトではエフェクトの名前と操作の名前を `.` でつないだもの（`Log.write`）、標準ライブラリのエフェクトでは宣言したモジュールの名前の最後の段と操作の名前をつないだもの（`Console.writeLine`）とする（10-06 の `OpDef::name` の例に合わせた本プランの決定）。並びはエフェクトの束縛の番号の順とする。

### 変えないこと

- `let` の右側が入れ子になった形をそのまま残す（02-06「脱糖」の最後の段落）。
- 最適化をしない（02-06「最適化」）。前述の「呼ばれる式の値を直接置く」と「空の部分の文字列を連結しない」「空のリストとの `concat_T` を省く」だけは、形の決まりとして行う。

## 受け入れテスト

テストは `test_support::desugar_files` でソースから `CoreProgram` を作り、結果の形を確かめる。利用者の定義の本体を、型と由来位置を省いた短い表記の文字列にする補助の関数をテストのモジュールに置き、期待する表記と比べてよい。

すべてのテストで、`desugar` の結果に F13 の `check_program` を当て、空の並びが返ることも確かめる（`desugar_files` が当てる。最小実行版で脱糖と検査器を組み合わせて確かめたのと同じ役割。本作業が F13 に依存するのはこのためである）。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 標準ライブラリのソース全体 | `main` だけの利用者のモジュールと、`import Benitoite.Trait`・`Benitoite.Unofficial.IO.Console` などすべての標準ライブラリのモジュールを取り込むモジュール（非公式のモジュールは取り込みの名前で書く） | `Ok`。検査器が空を返す |
| 定義の並びと名前 | 実行を始めるモジュールと `Lib/Text.bnt` の関数、標準ライブラリの公開の関数と補助の関数 | 並びがモジュールの ID の順。名前が `main`・`Lib.Text.trim`・`List.map`、由来が `User`・`User`・`StdlibPublic`・`StdlibHelper` |
| 演算子の項目 | `Integer`・`Float`・`Decimal` の `+`、`String` の `+`、`div`・`mod`、`Byte` の `<`、`Character` の `>=`、レコードの値の `=` と `<>` | それぞれ 10-12 の項目の `Builtin`、`intrinsic` が `Operator`。`=` は `%eq` で `tys` がレコードの型 |
| 負のリテラル | `-9223372036854775808` と `-(5)` と `-1.5m` | 一つ目と三つ目は定数、二つ目は `neg` の適用 |
| 呼ばれる値の直接の配置 | `Console.writeLine("a")`、`List.length(xs)`、利用者の操作 `write("a")` | `App` の `func` がそれぞれ `Builtin`（`class` が `Io`、`op` あり）・`Builtin`（`Pure`）・`Op` |
| パイプとプレースホルダ | `xs |> List.map(_, f)`、`x |> (g(1))`、`clamp(0, _, 100)` | 最小実行版と同じ形。展開で作ったラムダの `BodyId` が重ならない |
| レコード | フィールドを宣言と違う順に書いた構築、更新、フィールドを取り出す関数の定義 | 構築は書いた順の `Let` の後、宣言の順の引数の `Ctor`。更新は 1 行の `Match`。取り出す関数は `FieldGetter` の定義 |
| 文字列補間 | `"a${n}b${s}${c}"`（`n: Integer`、`s: String`、`c: Boolean`） | `Integer.toString` と `%Boolean.toString` の適用、`s` は変換しない、空の部分を連結しない |
| リストの展開 | `[..xs]`、`[a, ..xs]`、`[..xs, b]`、`[a, ..xs, b]` | `concat_T` の数がそれぞれ 0・1・1・2 |
| 定数 | 定数と、それを参照する関数 | `ConstDef` の `value` が型検査の値、参照が `ConstRef` |
| `return` | 末尾位置の `return f(x)`、`if` の中の途中の `return 0` | 前者は適用のまま、後者は `Escape` |
| `try` | `Result` と `Option` の `try` | 2 行 2 分岐の `Match`、失敗の分岐が `Escape` と、`TryInfo::ret` の型引数を持つ構成子 |
| `with` | 二つの束縛を持つ `with` | `Let`・`Use`・`Let`・`Use` の入れ子。`Use` の由来位置がそれぞれの束縛 |
| `lazy` | `lazy … end lazy` | `Lazy` の型が `Lazy[本体の型]`、エフェクトが空集合 |
| `handle` と `resume` | 01-02「エフェクトの宣言とハンドラ」の例（節の中の `resume(())`） | `Handle` の `handled` が {`Log`}、節の `tail_resumptive` が真、`Resume` の `cont` が節の `ContVar`、`Resume` のエフェクトが `handle` のエフェクト |
| 入れ子の `handle` の中の `resume` | 外側の `handle` の節の本体に内側の `handle` があり、外側の節の `resume(())` が内側の `handle` の本体にある形（内側の節も `resume` を呼ぶ） | 内側の `handle` のエフェクトが、外側の `Resume` のエフェクトを含めて求め直してある。内側の節の `Resume` のエフェクトが内側の `handle` のエフェクトと等しい |
| 組み込みの操作の節 | `Console.writeLine` の節を持つ `handle` | 節の `op` が操作の束縛、`OpDef::builtin` が組み込みの関数 |
| 辞書 | 上位の型クラスを持つ型クラス、制約を持つ関数、実装、実装のメソッドの中の実装の制約の辞書（10-14 の `Benitoite.Trait` を使う） | 呼び出しの `dicts` が `Impl`、制約を持つ関数の中の辞書が `Param`、上位の型クラスが `Super`、メソッドの本体が `ImplParam` を使う |
| メソッドを値として使う | `List.map(xs, Show.show)` と、制約を持つ関数を値として渡す | 辞書を渡すラムダ |
| 束縛の文のパターン | `bind Pair(a, b) <- p` と `bind Person(name: n, ..) <- q` | 1 行 1 分岐の `Match`。由来位置が束縛の文全体 |
| `match` の拡張 | 選択肢 `case 1, 2 ->`、ガード、範囲、`[first, ..rest]` | 行が選択肢ごと、同じ分岐の番号。選択肢の変数が同じ `VarId`。`CorePat` が `Range`・`List` |
| 変数と本体の番号 | 同じ名前を `shadow` で三度束縛する関数、ラムダを多く含むプログラム | `VarId` がすべて異なり `var_count` と一致する。`BodyId` がプログラム全体で重ならず `body_count` と一致する |

表の入力で標準ライブラリの非公式のモジュールを使うときは、`import Benitoite.Unofficial.IO.Console` のように取り込みの名前で書く（[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。01-02 の例の `import Benitoite.IO.Console` をそのまま写すと、今の版では E0321 になる。「`handle` と `resume`」と「組み込みの操作の節」の行がこれに当たる。

## 完了条件

- `scripts/check.sh` が通る（[実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがあり、すべてのテストの結果に `check_program` が空を返す
- 01-12「表層からの脱糖」と「初回リリース版の拡張」の表の各行に、それを実装する関数があり、関数の `///` のコメントがその行を示している
- 診断の文言を書いていない（脱糖は診断を出さない）。`InternalError` の説明だけを文字列で書いている

## 確認の観点

- 01-12 の脱糖の規則と 02-06 の表に一対一に対応しているか（[実装の確認の観点](../00-common/00-04-review-checklist.md)の「脱糖と変換」）。
- 評価の順序（書いた順）を保っているか。レコードの構築で、フィールドの式を宣言の順に評価していないか。
- 末尾位置の受け渡しが、`with`・`lazy`・`handle`・ガードの中で偽になっているか。
- 辞書の `ImplParam` と `Param` の使い分けが 10-05「型パラメータの番号」のとおりか。
- 組み込みの関数と操作を綴りで判定していないか（名前空間の名前、束縛の種類、10-12 の関数で引いているか）。
- 由来位置が 02-02「合成ノードの由来位置」の表のとおりか。

## 難易度の理由

規則の数が最小実行版の倍以上あり、名前解決の表、型検査の十数個の表、組み込みの関数の表を正しく組み合わせて引く必要がある。辞書の求め方の移し方（実装のメソッドの中の番号の読み替えと上位の型クラスの辿り方）と、`resume` のエフェクトが `handle` のエフェクトに依存する求め方は、誤っても型の付く IR になりうるので、検査器との組み合わせで確かめる。
