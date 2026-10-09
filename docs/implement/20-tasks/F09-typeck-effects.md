# F09 型検査 3: エフェクトとハンドラ、`lazy`・`with`・`try`

- 依存する作業: [F07](F07-typeck-records-constants.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/F09-typeck-effects

## 目的

エフェクトにかかわる型検査のうち、F07 が骨組みに含めなかったものを書く。`handle` と `resume`（節の検査、末尾で再開する節の判定、`handled(H)`）、`lazy`、`with`、`try`、`TaskGroup.open` を書く位置、`main` とテストの関数のエフェクトの条件、`uses` の中の重なり、`uses IO.All` を狭められる警告である。脱糖（[F11](F11-desugar.md)）は、本作業が記録する「`try` の種類」（`try_kinds`）と「ハンドラの節」（`handlers`）の表を読むので、表の形は [10-05](../10-interfaces/10-05-types.md) の「型検査の出力」に正確に合わせる。

本作業は、F07 が置いたフック E1〜E7 の中身を書く。F08・F10 と並行して進める（F07 の文書の「F07〜F10 の分け方」）。組み込みのエフェクトの名前の移し替え、`IO.All` の展開、操作の宣言の型と操作の名前の具体化、含まれる制約の最小の解と E0501・E0502 は F07 が書いた。

## 読む設計書の節

- [型検査器](../../design/02-impl/02-05-typechecker.md)の「宣言の検査」の `main` の箇条「制約の生成」の `try`・`with`・`lazy`・`handle`・`resume`・ラムダの行と、表の後の `handled(H)` の段落「書く位置の検査」「制約の解決」の手順 3 と「試行」「リソース」の箇条「本体の後の検査」の最初の項目「警告」の最初の項目
- [型システム](../../design/01-spec/01-06-type-system.md)の「関数の型とエフェクト」「エフェクトの包含」「明示遅延の型（初回リリース版）」「可変状態（初回リリース版）」「エフェクトの宣言とハンドラの型付け（初回リリース版）」
- [エフェクト](../../design/01-spec/01-07-effects.md)の「組み込みのエフェクト」「プログラムの入口」「可変のセル（初回リリース版）」「利用者が定義するエフェクトとハンドラ（初回リリース版）」
- [エラー処理](../../design/01-spec/01-09-errors.md)の「`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`」
- [リソース管理](../../design/01-spec/01-10-resources.md)の「リソースの型」「`with` の構文」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクの集まり」「タスクとハンドラ」
- [評価意味論](../../design/01-spec/01-08-evaluation.md)の「末尾呼び出し」（末尾位置の定め方）
- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の「ハンドラ」の C-Handle・C-Resume と `handled(H)`
- [構文](../../design/01-spec/01-02-syntax.md)の「エフェクトの宣言とハンドラ（初回リリース版）」「明示遅延（初回リリース版）」「リソーススコープ（初回リリース版）」
- [利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md)の「テストの関数」のエフェクトの箇条
- ADR: [0063](../../design/decisions/0063-ref-cells-with-io-effect.md)、[0066](../../design/decisions/0066-explicit-laziness-pure-body.md)、[0067](../../design/decisions/0067-with-resource-scope.md)、[0097](../../design/decisions/0097-prefix-try.md)、[0116](../../design/decisions/0116-builtin-fine-grained-effects.md)、[0118](../../design/decisions/0118-effect-handlers.md)、[0120](../../design/decisions/0120-test-functions-and-assert-effect.md)、[0129](../../design/decisions/0129-effects-declared-in-modules.md)、[0130](../../design/decisions/0130-builtin-effect-names-and-placement.md)、[0140](../../design/decisions/0140-network-separated-from-local-io.md)、[0150](../../design/decisions/0150-resource-release-as-state.md)、[0151](../../design/decisions/0151-inherited-handlers-tail-resume-only.md)、[0153](../../design/decisions/0153-taskgroup-open-only-in-with.md)、[0155](../../design/decisions/0155-resume-not-in-lazy.md)
- インターフェース: [10-05](../10-interfaces/10-05-types.md) の「型パラメータの番号」の `Ty::Rigid` の段落「型検査の出力」の `TryInfo`・`ClauseInfo`・`HandleInfo`「推論の型と制約（F07〜F10 の境界）」の `Constraint::Try`・`Constraint::Resource`・`ReasonKind`（`Try`・`WithResource`・`WithState`・`LazyBody`・`HandleBody`・`HandleClause`・`Resume`）、[10-05](../10-interfaces/10-05-types.md) の「組み込みの型とエフェクトの表」（`BuiltinTypeClass::Resource`、`in_io_all`）、[10-02](../10-interfaces/10-02-diagnostics.md) の「コードの一覧」の E0415・E0419・E0440〜E0443・E05・W0501 の行
- 作業の文書: [F07](F07-typeck-records-constants.md) の「F07〜F10 の分け方」「本体の文脈」と、`src/typeck/mod.rs` の先頭の `//!` のフックの表

## 作るもの

- `src/typeck/effects/mod.rs`: F07 が置いたフック E1〜E7 の中身。子のモジュール（`handle`、`try`、`with` と `lazy`、宣言の検査など）に分けてよい。子のモジュールは `src/typeck/effects/` の下に置き、`effects/mod.rs` で非公開に宣言する。
- 上のファイルの `#[cfg(test)] mod tests` のテスト。
- `testdata-next/effects/` と `testdata-next/handlers/` の誤りのない例のゴールデンテスト（後述）。
- `src/diag/codes.rs`: 本作業が出すコードについて、10-02「型板の直し方」の範囲で直してよい。
- `src/syntax/parser/effects.rs` の `push_op`: 操作の型パラメータの並びの、型構成子を表す型パラメータ（`TypeParamKind::Ctor`）を、エフェクト変数と同じく E0510（`help` の鍵 `type_ctor`、主な位置は型パラメータ）で報告して捨てる（[ADR 0311](../../design/decisions/0311-no-type-constructor-params-in-operations.md)）。同じく、操作の型パラメータの型クラスの制約（`ConstraintRef::Class`）を E0510（`help` の鍵 `trait_constraint`、主な位置は制約の名前）で報告して捨て、組み込みの制約（`ConstraintRef::Builtin`）は残す（[ADR 0312](../../design/decisions/0312-no-trait-constraints-in-operations.md)）。本作業は、これらの変更に限って F04 のファイル `effects.rs` を直してよい。構文解析のテストも加える。この制限により、節の中の操作の型パラメータは、いつも値の型の `ITy::Rigid` で表せ、型クラスの辞書を持たない。
- 節の中の組み込みの制約（02-05「型とエフェクトの表現」の型パラメータの行、01-12 の Δ）: 組み込みの制約を付けた操作の型パラメータの `ITy::Rigid { clause, index }` は、等値・鍵の制約（と標準ライブラリの `ordered`）を宣言どおりに満たす。そのために、本作業は次の限られた変更に限って共有のファイルを直してよい。`context.rs` の `Body`（または `ClauseContext`）に、節のノード番号と操作の型パラメータの番号から宣言した組み込みの制約を引ける欄を加える。`solve.rs` の `Solver::bounds` の `ITy::Rigid` の分岐と、`traits/mod.rs` の `check_bound` を、その欄を引いて判定するように直す。ほかの判定と F07・F08 のテストの結果を変えない。直した箇所は完了の報告の「判断したこと」に挙げる。

- F07・F08 の既存のテスト（`src/typeck/tests.rs`・`src/typeck/traits/tests.rs`）のうち、フック E1〜E7 の仮の本体の振る舞い（警告を出さないなど）を前提にした期待値は、本作業の規則どおりの結果に直してよい。期待値を直したテストは、ほかの確かめ（宣言の型など）を保ち、完了の報告の「判断したこと」に挙げる。

`src/typeck/` の共有のファイル（`mod.rs`・`context.rs`・`decls.rs`・`generate.rs`・`solve.rs`・`consts.rs`・`records.rs`）と、`traits/`・`pattern_ext.rs`・`patterns.rs` は変えない。フックのシグネチャか本体の文脈の操作が足りないと分かったら、作業を止めて報告する（00-03「型やシグネチャを変える必要が生じたとき」と同じ扱い）。

## 手順の要点

以下、E は本体の文脈のエフェクトの受け先、R は最も内側の関数かラムダの戻り値の型である（02-05「制約の生成」の表の前の段落）。子を辿るときに E と R を差し替えるのは、F07 の本体の文脈の操作で行う。

### `uses` の重なり（E1）

一つの `uses` に同じエフェクトの名前（`IO.All` を含む）か同じエフェクト変数を二度書いたら E0419 とし、二つ目を消す置き換えを付ける。同じかどうかは、綴りでなく移した後のエフェクトの名前で比べる（`uses Console.Write, C.Write` で `C` が同じモジュールの別名なら重なる）。`IO.All` と、それに含まれる名前を並べたもの（`uses IO.All, Console.Write`）は、書いた名前が違うので重なりとしない。

### `main` とテストの関数のエフェクト（E2）

- `main`: エフェクトは、`IO.All` を展開した集合とネットワークのエフェクト（組み込みのエフェクトの表で `in_io_all` が偽で `Network` の下のもの）の和集合に含まれなければならない（02-05「宣言の検査」の `main`、01-07「プログラムの入口」）。本プランの決定: 利用者が宣言したエフェクトを `uses` に書いたときは、エフェクトごとに E0506（主な位置は `uses` のそのエフェクトの名前）とする。`Assert.Check` を書いたときは E0415 の注記 `assert`、エフェクト変数は F07 が E0415 の注記 `type_params` で報告済みである。F07 が同じ `main` に E0415 を出していれば、注記を同じ診断に加える形にできないので、別の E0415 の診断として出してよい（F07 の診断の組み立てを変えない）。
- テストの関数（`@test` を付けた関数）: エフェクトは組み込みのエフェクトと `Assert.Check` の任意の集まり（06-04「テストの関数」）。利用者が宣言したエフェクトは E0506。

### 書く位置の検査（E4）

`TaskGroup.open`（名前解決の `stdlib("Benitoite.TaskGroup.open")` の束縛と比べる。綴りで比べない）を、`with` の束縛の式として直接呼ぶ形（`with g = TaskGroup.open() do`）の外で使ったら E0505 とし、`with` で束縛する修正案を示す。呼び出し以外の参照（引数に渡す、`bind` で束縛する）も誤りである（ADR 0153）。`with` の束縛の式として直接呼ぶ形のときは、E3 の `with` の処理が E4 に印を付けて呼ぶ。

### 式（E3）

02-05「制約の生成」の表の行のとおりに書く。

- `lazy B end lazy`: B を E を空集合、R を「なし」として辿る。型は `Lazy[B のブロックの型]`（`BuiltinTypeId::LAZY`）。B のエフェクトの受け先が空集合であることは、含まれる制約（理由 `LazyBody`）で表し、解けなかったときの診断は E7 が E0503 にする（引数のないラムダを使う修正案。ADR 0066）。
- `with x1 = e1, …, xn = en do B end with`: 束縛を書いた順に辿る。`xi` は `ei` の後の束縛の式と B で見える。各 `ei` について `Constraint::Resource`（理由 `WithResource`）を加え、`xi` の型を `ei` の型とする（`expr_types` に `WithBind` のノード番号で記録する）。含まれる({State}, E)（理由 `WithState`）を加える。型は B のブロックの型。`ei` が `TaskGroup.open` の直接の呼び出しなら、E4 に印を付けて呼ぶ。
- `try e`: `Constraint::Try { target: e の型, ret: R, result: τ, node }`（理由 `Try`）を加える。型は τ（新しい型変数）。R が「なし」の位置の `try` は構文解析器が報告済みである。
- `handle B with case op(x̄) -> N … end handle`: 02-05「制約の生成」の `handle` の行のとおり。
  1. T・εM・εh を新しい変数にする。B を E を εM として辿り、流れ込む(B のブロックの型, T)（理由 `HandleBody`）。
  2. 各節の操作の名前（`OpRef`）の束縛を名前解決の参照の表で引く。束縛が `Op` でなければ E0507（`State` を型に持つ組み込みの関数のときは鍵 `state` の注記）とし、その節の本体は誤りの型の引数で辿る。同じ操作の束縛の節が二つあれば、後の節に E0508（補助の位置は先の節）。
  3. 各節の操作の宣言の型（F07 が入れた `decl_types`）の型パラメータを、節ごとの `Ty::Rigid { clause: 節のノード番号, index }` にする（`ITy::Rigid`）。節の引数をその引数の型に束縛し、`expr_types` に `ClauseParam` のノード番号でその型を記録する。`_` を書いた引数（`name` が `None`）も記録する（脱糖の F11 が、すべての節の引数の型をこの表から読むため）。引数の数が操作と違えば E0401 に当たる誤り（関数の型の引数の数の不一致として報告する）。
  4. 節の本体を E を εh として辿る。辿る間、囲む `handle` の節の情報（節のノード番号、操作の戻り値の型、T）を本体の文脈に積む。流れ込む(節の本体の型, T)（理由 `HandleClause`）。
  5. handled(H) を求める: 利用者と組み込みのエフェクト（`EffectDef`）のうち、一つ以上の操作を持ち、そのすべての操作の節をこの `handle` が持つものの集合。`State` は操作を持たないので入らない。
  6. 含まれる(εM, handled(H) と εh からなるエフェクト)（理由 `HandleBody`）と、含まれる(εh, E)（理由 `HandleClause`）を加える。型は T。
  7. `handlers` に `HandleInfo`（節の順の `ClauseInfo { op, tail_resumptive }` と `handled`）を記録する。
- `resume(v)`: 本体の文脈の囲む節の情報から、操作の戻り値の型と T を得る。流れ込む(v の型, 操作の戻り値の型)（理由 `Resume`）。型は T。`resume` を書ける位置（節の中に直接。ラムダと `lazy` の本体の中は不可）は構文解析器が E0509 で報告済みなので、囲む節の情報が必ずある。ない場合は処理系の不具合として扱う（誤りの型を返し、`debug_assert!` で止める）。

### 末尾で再開する節の判定

02-05「書く位置の検査」の最後の段落のとおり、節の本体のどの終わり方も末尾位置の `resume(v)` であり、節の中（内側のラムダの中を除く）に `return` と `try` がない節を、末尾で再開する節とする（ADR 0151）。末尾位置は 01-08「末尾呼び出し」の定め方に従う（ブロックの最後の文、`if` の各分岐の最後、`match` の各分岐の最後。`with` のブロックの中は末尾位置でない）。この判定は構文だけで行い、誤りを生じない。本プランの決定: 節の本体が必ず抜ける文（`return` など）で終わる道筋を持てば、末尾で再開する節としない。

### 試行とリソースの制約を解く（E5）

02-05「制約の解決」の「試行」「リソース」の箇条のとおり。

- 試行: 対象の型 A が決まったときに判定する。`Result[T, E1]` なら τ を T と等しくし、R を `Result[β, E1]`（β は新しい変数）と等しくする。`Option[T]` なら τ を T と、R を `Option[β]` と等しくする。`Result` と `Option` は標準ライブラリの束縛（`stdlib("Benitoite.Result.Result")` など）で照合する。それ以外の型なら E0440。R の形が合わない（`Result` に対して R が `Option` など）なら E0441（`Option.okOr`・`Result.toOption` の修正案）。R が `Result` で誤りの型が違うために単一化が失敗したら E0442（`Result.mapError` の修正案）。判定した種類と R（いまの単一化の状態で置き換えたもの）を、本体の後に `finalize` して `try_kinds` に `TryInfo` として記録する。R がラムダの戻り値の型注釈のない型変数なら、上の単一化で `Result[β, E1]` か `Option[β]` に決まる（01-09 の 2 番目の箇条）。
- A が本体の後まで決まらなければ E0407（F07 の本体の後の検査が、試行の制約を持つ型変数として報告する。本作業は、試行の制約を型変数に付ける操作を F07 の文脈で行う）。
- リソース: A が決まったときに、組み込みの型で `BuiltinTypeClass::Resource` の型でなければ E0443。

### 警告と診断のコード（E6・E7）

- E6: `uses` に `IO.All` を書いた（`Scheme::wrote_io_all` が真の）本体を持つ関数（実装のメソッドを含む）について、本体が生じるエフェクトの集合（含まれる(X, 宣言した `uses`) の X の現在の要素の和集合）と、`IO.All` を展開した集合との共通部分が展開した集合より小さければ W0501 とし、生じるエフェクトの並びを `uses` の書き方で示す置き換え（`IO.All` の字句を並びに置き換える。並びが空なら `uses` ごと消す）を付ける（02-05「警告」の最初の項目、ADR 0116）。本体が生じるエフェクトの集合は、F07 の解決の状態から得る。得る手段が本体の文脈にないときは、作業を止めて報告する。
- E7: 理由が `LazyBody` の含まれる制約が解けなかったとき、E0503 とし、そのエフェクトを生じた呼び出しを主な位置、引数のないラムダを使う修正案を示す。

### 可変状態とタスクの関数

`Reference`・`TaskGroup`・`Task` の関数と、リソースを解放する関数（`File.closeReader`）は、標準ライブラリのソースの宣言の型（`uses State` など）で F07 がそのまま型付けする。本作業が書くものはないが、受け入れテストで `State` のエフェクトの検査と、`State` を型に持つ関数を節に書いた誤り（E0507）を確かめる。

## 受け入れテスト

テストは F07 の `typeck::test_support` で検査し、診断をコードと主な位置で確かめる。表の値は `try_kinds`・`handlers`・`expr_types` を直接確かめる。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 操作の型パラメータの制約 | `effect Compare` の `function same[T: equality](a: T, b: T) -> Boolean` と、節 `case same(a, b) -> resume(a = b)`。`function show[T: Trait.Show](x: T) -> String` を持つ操作 | 前者は診断なし。後者は構文解析の E0510（`trait_constraint` の注記、主な位置は `Trait.Show`） |
| 操作の型構成子の型パラメータ | `effect Make` の `function make[F[_]]() -> F[Integer]` | 構文解析の E0510（`type_ctor` の注記、主な位置は `F[_]`）。宣言の残りは読む |
| 01-07 の `Log` の例 | `effect Log`、`process`、`main` の `handle` | 診断なし。`handlers` の節の操作が `write` の束縛、`tail_resumptive` が真、`handled` が {Log} |
| 節の引数の型 | `case Logging.write(_) ->` と名前を書いた引数の節 | どちらの `ClauseParam` のノード番号も `expr_types` に操作の引数の型で入る |
| 01-06 の `parseAll` の例 | `effect Abort` の `fail[T]` と、`resume` を呼ばない節 | 診断なし。`tail_resumptive` が偽。`parseAll` は純粋 |
| 組み込みの操作の差し替え | 01-07 の `portIsRead` | 診断なし。`handled` は空（`File.Read` のすべての操作の節はない）で、`portIsRead` の `uses File.Read` が要る |
| 一部の操作の節 | `portIsRead` の `uses File.Read` を除いたもの | E0501 |
| 操作の型パラメータ | `fail[T]` の節で `resume(message)`（`message: String`） | E0401（`Ty::Rigid` は `String` と等しくない）。`identity[T](value: T) -> T` の節の `resume(value)` は診断なし |
| 節の誤り | 節に普通の関数を書く、`Reference.set` を書く、同じ操作の節を二つ | E0507、E0507（注記 `state`）、E0508 |
| `lazy` | `lazy 1 + 2 end lazy` と `lazy Console.writeLine("a") end lazy` | 前者は型 `Lazy[Integer]` で診断なし、後者は E0503 と修正案 |
| `with` | `File.openReader` を `try` で取り出して `with` で束縛し、`File.readLine` を使う | 診断なし。関数の `uses` に `State` がなければ E0501 |
| リソースでない値 | `with x = 1 do … end with` | E0443 |
| `TaskGroup.open` | `with g = TaskGroup.open() do … end with` と、`bind g <- TaskGroup.open()`、`List.map(xs, TaskGroup.open)` の形 | 前者は診断なし、後の二つは E0505 |
| `try`（`Result`） | 01-09 の `loadConfig` の形 | 診断なし。`try_kinds` が `Result` と戻り値の型 |
| `try`（`Option`） | `Option[Integer]` を返す関数の中の `try Integer.parse(s)` | 診断なし。`try_kinds` が `Option` |
| `try` の誤り | `try 1`、`Integer` を返す関数の中の `try` の `Result`、誤りの型の違う `Result` | E0440、E0441、E0442 と修正案 |
| ラムダの中の `try` | 戻り値の型注釈のないラムダの中の `try` | 診断なし。ラムダの戻り値の型が `Result[β, E1]` に決まる |
| `try` の対象が決まらない | 型の決まらない値への `try` | E0407 |
| `main` のエフェクト | `uses Log` の `main`、`uses Assert.Check` の `main`（`Assert` がないので、組み込みのエフェクトの表の番号で作った単体テストの型で確かめてよい）、`uses IO.All, Http.Connect` に当たる形（ネットワークのモジュールがないので同上） | E0506、E0415（注記 `assert`）、診断なし |
| `uses` の重なり | `uses Console.Write, Console.Write` | E0419 と二つ目を消す置き換え |
| `IO.All` の警告 | `uses IO.All` の関数の本体が `Console.writeLine` だけを呼ぶ | W0501 と `uses Console.Write` への置き換え。本体がすべてのエフェクトを生じれば警告なし |
| 可変のセル | 01-07 の `countNonEmpty` | 診断なし。`uses State` を除けば E0501 |
| 利用者の操作のエフェクト | `write` を `uses Log` のない関数から呼ぶ | E0501 |
| 節の外のエフェクト | 節の本体が呼ぶ操作が `handle` の外の `uses` に含まれない | E0501（εh が E に含まれない） |

ゴールデンテスト: 上の表の診断なしの例（01-07 の `Log`、01-06 の `parseAll`、`portIsRead`、`countNonEmpty`、`with` と `try` の例）を、`testdata-next/handlers/`（ハンドラ）と `testdata-next/effects/`（そのほか）に `check` の方式のテスト（`.bnt`、`check` を書いた `.mode`、`0` を書いた `.exit`。`.bnt` の先頭に `// spec:` の行）として置く。期待値は C05 が確かめ、誤りの診断のゴールデンテストは C11 が書く。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 標準ライブラリのソースを検査して、診断が出ない
- `src/typeck/effects/` の外の型検査のファイルを変えていない（`src/diag/codes.rs` の型板の直しを除く）

## 確認の観点

- 00-04 の「型検査（F07〜F10）」の行（エフェクトの検査が 02-05 の順序のとおりか）。
- `handle` の含まれる制約が C-Handle の前提 `εM ⊆ ε ∪ handled(H)` を表しているか。エフェクト変数を handled(H) で除いていないか。
- 節の中の操作の型パラメータを `Ty::Rigid` にして、節の外に漏らしていないか（`handlers` と `expr_types` に型変数を残していないか）。
- 末尾で再開する節の判定が 01-08「末尾呼び出し」の末尾位置と一致しているか（`with` の中の `resume` を末尾位置としていないか）。
- `TaskGroup.open`・`Result`・`Option` を綴りでなく束縛で照合しているか（ADR 0128）。

## 難易度の理由

`handle` は、二つの新しいエフェクトの変数と handled(H) を含む制約、節ごとの型パラメータの扱い、`resume` の型、末尾で再開する節の判定が組み合わさり、誤りはハンドラの実行（R20）の段で初めて現れることがある。`try` の判定は型変数が決まる時点に依存し、ラムダの戻り値の型の推論とも結び付く。
