# T14 型検査 1: 制約を解く部分

- 依存する作業: [T01](T01-interfaces.md)
- 難易度: 5（1〜5。README の「難易度の目安」）
- 規模の見込み: 大（1500 行超）（テストを含む Rust の行数の目安）
- ブランチ: impl/T14-typeck-solver

## 目的

型検査のうち、制約を解く部分 `Solver` を書く。型変数の union-find、単一化と出現検査、流れ込む制約の解き方（後回しと解き直し）、集まりと等値の制約の判定、エフェクトの含まれる制約の最小解と検査を行い、解けなかった制約を診断にする。制約を生成する側（T15）とは、10-05 の `ITy`・`IEffect`・`Constraint`・`Reason` だけでつながるので、T15 より先に、手で組んだ制約でテストしながら進められる。

## 読む設計書の節

- [型検査器](../../2026-09-27-design-initial/02-impl/02-05-typechecker.md)の「型とエフェクトの表現」「制約の種類」「制約の解決」「誤りの報告と検査の継続」「本体の後の検査」の最初の項目
- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)の「型」（型の等しさ）、「エフェクトの包含」「エフェクト変数の具体化」「型の推論と型注釈」「演算子の型付け」「等値の型」
- [ADR 0023](../../2026-09-27-design-initial/decisions/0023-constraint-based-inference.md)、[ADR 0024](../../2026-09-27-design-initial/decisions/0024-continue-after-type-errors.md)、[ADR 0046](../../2026-09-27-design-initial/decisions/0046-effect-subsumption-at-all-flow-positions.md)、[ADR 0048](../../2026-09-27-design-initial/decisions/0048-ioerror-not-equality-type.md)、[ADR 0082](../../2026-09-27-design-initial/decisions/0082-equality-type-by-declaration-summary.md)
- [型](../10-interfaces/10-05-types.md)の「型の表現」「推論の型と制約（T14 と T15 の境界）」
- [診断](../10-interfaces/10-02-diagnostics.md)の「診断コードの初めの一覧」の E0401〜E0407、E0416、E0501、E0502

## 作るもの

- `src/typeck/solve.rs`: 10-05 の `sig=src/typeck/solve.rs` の `Solver` と `SolveEnv` と、そのすべての関数。`Solver` の欄は非公開にして自由に決める。
- `src/typeck/infer.rs`: T01 が置いた型はそのまま使う。`ITy` の表示など、T15 も使う補助の関数を加える場合は、この節の「表示」の関数だけを `impl ITy` として加えてよい。
- 両ファイルの `#[cfg(test)] mod tests`。

ほかのファイルは変えない。

## 手順の要点

### 状態

- 型変数は union-find で表す。各代表元は「決まった型（`ITy`）」か「決まっていない」のどちらかと、制約（なし／集まり `TySet`／等値）と、制約の理由（`Reason`）を持つ。
- エフェクトの変数（`EffInfer`）は、現在の要素の集合（`EffectSet`）と、要素ごとの由来（その要素を加えた制約の `Reason` の span）を持つ。
- 誤りの型になった型変数を記録する。`contains_error` と `undetermined` はこの記録を見る。
- 状態は本体ごとに作って捨てる（02-05「検査の手順」、ADR 0015）。大域の状態を持たない。

### 解く順序

`solve` は、受け取った制約を次の順に解く（02-05「制約の解決」）。同じ手順の中では、受け取った順に解く。

1. `Priority::Declared` の `Flow`。
2. 残りの型の制約（`Equal`、`Priority::Normal` の `Flow`、`OneOf`、`Equality`）。後回しにした `Flow` は、一通り解いた後に 02-05 の手順で解き直す（一つでも片付けば残りをもう一度解き直し、片付くものがなくなったら残りを等しいとして単一化する）。
3. `EffSub`。受け取った `EffSub` に加えて、手順 1・2 の単一化と流れ込む制約が作った `EffSub` をすべて解く。

`constrain_one_of` と `constrain_equality` は、`solve` より前に呼ばれる（組み込みの関数の型パラメータの制約を移すため）。型変数にその場で制約を付ける。

### 単一化

- 両辺を代表元で置き換えてから、形で分ける。`Error` はどの型とも等しいものとして成功させ、診断を出さない。
- 型変数と型: 出現検査を行い、失敗したら E0404（主な位置は `reason.span`）。成功したら型変数を決め、その型変数の制約を決まった型に対して判定する（後述）。
- 型変数どうし: 一方を他方に合わせる。両方が制約を持てば、集まりどうしは `TySet::intersect`（空なら E0405）、等値と集まりは両方を持つ（集まりの型はどれも等値の型なので、集まりだけを残してよい）。
- `Con` どうし: 名前と型引数の個数が同じなら型引数を単一化する。違えば E0401。
- `Fn` どうし: 引数の個数が違えば、理由が `ReasonKind::Call` なら E0402（`expected` は `Equal` の `expected` 側の引数の個数、`found` は `found` 側）、そうでなければ E0401。同じなら引数と戻り値を単一化し、エフェクトについて両方向の `EffSub` を加える（02-05「制約の解決」の「等しい」）。
- `Param(i)` は同じ `Param(i)` とだけ等しい。
- 形の違う組（`Con` と `Fn` など）は E0401。ただし理由が `ReasonKind::Call` で、`expected` 側（呼ばれる式の型）が関数の型でなく型変数でもないときは E0403（`found` の値は呼ばれる式の型の表示）。

### 流れ込む制約

02-05「制約の解決」の「流れ込む(A, B)」の場合分けをそのまま実装する。

- 両辺とも `Fn`: 引数の個数が違えば E0402／E0401（上と同じ規則）。引数どうしと戻り値どうしを単一化し、`EffSub(A のエフェクト, B のエフェクト)` を加える。
- `Fn` と型変数、型変数と `Fn`: 型変数を、同じ引数と戻り値の型を持ち、エフェクトを新しい変数 ρ とした関数の型に決め、ρ との `EffSub` を加える。
- 両辺とも型変数: 後回しにする。
- どちらかが `Error`: 満たされたものとする。
- それ以外: 等しいとして単一化する。

流れ込む制約と単一化から作った `EffSub` は、元の制約の `Reason` を引き継ぎ、加えて元の二つの関数の型（`from` 側と `to` 側）を内部に覚えておく（本作業で決める）。手順 3 でこの `EffSub` が満たされなかったときは、エフェクトの誤りではなく E0401 として、覚えた二つの型（`expected` は `to` 側、`found` は `from` 側）を示す。例えば純粋な関数の型を要求する引数に `uses IO` のラムダを渡すと、`expected fn() -> Unit, found fn() -> Unit uses IO` になる。

### 集まりと等値の判定

型変数が決まったとき、または制約を持つ型変数どうしが等しくなったときに判定する（02-05「制約の解決」の「集まり・等値」）。

- 集まり: 決まった型が `Con(c, _)` で `set.contains(c)` なら満たす。`Param` は満たさない（利用者の関数の型パラメータに演算子を使えない。01-06「演算子の型付け」）。関数の型も満たさない。満たさなければ E0405（`op` は理由の `OpName::symbol`。理由が `BuiltinParam { name }` なら `name`（`List.sort` など）、`ty` は型の表示、注記 `allowed` の `{allowed}` は集まりの型を「`` `Int`, `Float`, and `String` ``」の形に並べた文。二つなら「`` `Int` and `Float` ``」）。
- 等値: 01-06「等値の型」の判定を、型をたどって行う。基本型は満たす。関数の型、`IoError`、`Param` は満たさない。`List[T]` は T に等値の制約を移す（T が型変数なら制約を付け、決まっていれば判定する）。代数的データ型 `D[A1, …, An]` は `AdtTable` の `eq_summary` を引き、`always` なら満たさず、`depends_on` の各位置の型引数に等値の制約を移す。満たさなければ E0406（注記 `why`。`op` の値は E0405 と同じく、理由の演算子の記号か、`BuiltinParam` の `name`）。
- 型が `Error` を含むときは、判定せずに満たしたものとする。

### エフェクトの制約

02-05「制約の解決」のエフェクトの手順 1〜3 を実装する。

- 手順 2 は、どの変数の集合も増えなくなるまで繰り返す。要素を加えるときは、その要素を生じた位置（加えた `EffSub` の `reason.span`。要素が別の変数から来たときは、その変数でのその要素の由来）を記録する。
- 手順 3 で、`sup` が変数を持たない `EffSub` の `sub` の要素が `sup.fixed` に含まれなければ、次の診断を出す。要素ごとに一つ出す（`IO` と `E` の両方が漏れれば二つ）。
  - 理由が `ReasonKind::FnUses`: E0501。主な位置は、漏れた要素を生じた呼び出しの位置である。要素が `sub` の変数から来たものなら、手順 2 でその要素を加えたときに記録した由来の span、`sub.fixed` の要素なら `reason.span`（その呼び出し）とする（01-06「式のエフェクト」の「そのエフェクトを生じた呼び出しの位置」）。`effect` は漏れた要素の名前（`IO`、またはエフェクト変数の名前を `SolveEnv::effect_params` から引いたもの）、`reason.related` があれば補助の位置 `declared`、修正案 `add_uses`。
  - 理由が `ReasonKind::LambdaUses`: E0502。主な位置と補助の位置は E0501 と同じ。
  - 流れ込む制約・単一化から作った `EffSub`: 前節のとおり E0401。
  - そのほかの理由（`ReasonKind::CallEffect` など）: T15 は、`sup` が変数を持たない `EffSub` にこれらの理由を付けない。付いていたときも E0501 として報告する（診断を落とさないため）。
- 呼び出しの型が誤りの型のときは、T15 がその呼び出しの `EffSub` を作らない（02-05「誤りの報告と検査の継続」）。

### 診断の組み立て

- E0401 の `expected` と `found` は、診断を作る時点で `zonk` した型を表示したものである。表示は `Ty::show` と同じ形とし、`TyNames` を `SolveEnv` から作る。まだ決まっていない型変数は `_` と表示する（本作業で決める。`List[_]` のように示す）。`ITy` を表示する関数（`ITy::show` など）はこの作業で書く。
- 注記は、理由の種類から次のように選ぶ（10-02 の E0401 の `extras` の鍵）。

| `ReasonKind` | 注記の鍵 | 型板の値 |
|---|---|---|
| `CallArg { index }` | `because_call_arg` | `index` |
| `Call` | `because_call` | |
| `IfCondition` | `because_condition` | |
| `IfBranches` | `because_if_branches` | |
| `IfNoElse` | `because_if_no_else` | |
| `MatchArms` | `because_match_arms` | |
| `Pattern` | `because_pattern` | |
| `ListElement` | `because_list` | |
| `LetAnnotation` | `because_let_annotation` | |
| `LambdaReturn` | `because_lambda_return` | |
| `FnBody` | `because_fn_body` | |
| `Operands { op }` | `because_operands` | `op` |
| `Logic { op }` | `because_logic` | `op` |
| `Operator { op }`（`%` のオペランドを `Int` と等しくする `Equal`） | `because_int_operands` | `op` |

- 理由が `ReasonKind::Operator` の `Equal` が単一化で解けなかったとき（T15 が `%` のオペランドに付ける）は、E0401 に注記 `because_int_operands` を付ける。集まりの制約・等値の制約を満たさなかったときは、理由が同じ `Operator` でも E0405・E0406 である。
- `ReasonKind::ExprStmt` の `Equal` が解けなかったときは、E0401 ではなく E0416 とする（`found` は式の型、修正案 `discard`）。
- `reason.related` があれば、補助の位置 `declared` を加える（E0401、E0402）。
- 修正案 `float_literal`: E0401 で、期待した型が `Float`、実際の型が `Int`、`reason.int_literal` が `Some(digits)` のとき、`literal` に `digits` を入れて加える。
- `+` の文字列の修正案（02-05「誤りの報告と検査の継続」の 2 番目の項目）: 理由が `Operands { op: Bin(Add) }` の E0401、または `Operator { op: Bin(Add) }` の E0405 で、一方の型が `String` で他方が `String` でない（誤りの型を除く）とき、他方が `Int`・`Float`・`Char` なら `to_string`（`function` に `Int.toString` などを入れる）、それ以外なら `to_string_any` を加える。E0405 の場合、「他方」は集まりの制約を持つ型変数と等しくされようとした型であり、`String` が既に決まっている側である。
- 制約が解けなかったら、その制約の両辺に現れるまだ決まっていない型変数を、すべて誤りの型にする（02-05「誤りの報告と検査の継続」）。以後、誤りの型を含む制約は診断を出さずに満たしたものとする。

### 表に書く型

- `finalize` は、`zonk` した型の型変数のうち、決まっていないものを `Unit` に、誤りの型も `Unit` にする。
- `finalize_effect` は、`fixed` と、変数の現在の集合の和集合を返す。決まっていない変数は空集合とする。
- `undetermined` は、制約（集まり・等値）を持ち、`solve` の後も決まっていない、誤りの型になっていない型変数の、制約の理由を返す（T15 が E0407 を出す）。同じ型変数の理由は一つにする。

### 再帰の深さ

`ITy` の入れ子の深さは、AST の深さの定数倍に収まる（02-03「入れ子の深さ」）ので、単一化と表示を再帰で書いてよい。出現検査の失敗で無限の型を作らないことを確かめる。

## 受け入れテスト

テストは `Solver::new` で状態を作り、`fresh_ty` などで型変数を作って、手で組んだ `Constraint` の並びを `solve` に渡す。`Reason` の span は、テスト用の `FileId(0)` の適当な位置でよい。診断はコードと、`expected`・`found` などの主な値と、注記・修正案の鍵に当たる文で確かめる。

| 場合 | 制約 | 期待する結果 |
|---|---|---|
| 単一化の成功 | `Equal(α, Int)`、`Equal(List[α], β)` | 診断なし。`finalize(β)` は `List[Int]` |
| 型の不一致 | `Equal(Int, String)`、理由 `LetAnnotation` | E0401、`expected Int, found String`、注記 `because_let_annotation` |
| 出現検査 | `Equal(α, fn(α) -> Int)` | E0404 |
| 引数の個数（呼び出し） | `Equal(fn(Int) -> Int, fn(β, γ) -> ρ)`、理由 `Call` | E0402、`expected 1`、`found 2` |
| 関数でない値の呼び出し | `Equal(Int, fn() -> ρ)`、理由 `Call` | E0403 |
| 型パラメータの剛性 | `Equal(Param(0), Int)` | E0401 |
| 誤りの型の吸収 | `Equal(Error, Int)`、`Equal(α, Error)`、`OneOf(α, ADD)` | 診断なし |
| 誤りの後の派生の抑止 | `Equal(α, Int)`、`Equal(α, String)`、`Equal(α, Bool)` | 診断は一つだけ |
| 集まり | `OneOf(α, ARITH)`、`Equal(α, String)`、理由 `Operator { op: - }` | E0405、`allowed` に `` `Int` and `Float` `` |
| 集まりの共通部分 | `OneOf(α, ADD)`、`OneOf(β, ORD)`、`Equal(α, β)`、`Equal(β, Char)` | E0405（共通部分は ADD で `Char` を含まない） |
| 型パラメータへの演算子 | `OneOf(α, ADD)`、`Equal(α, Param(0))` | E0405 |
| `+` の修正案 | `Equal(α, String)`、`Equal(α, Int)`、理由 `Operands { op: + }` | E0401 と修正案 `to_string`（`Int.toString`） |
| `Float` の位置の整数リテラル | `Equal(Float, Int)`、`int_literal = Some("2")` | E0401 と修正案 `float_literal`（`2.0`） |
| 式文 | `Equal(Unit, Int)`、理由 `ExprStmt` | E0416、`found Int` |
| 等値の型 | `Equality(α)`、`Equal(α, fn() -> Unit)` | E0406 |
| 等値の型（`IoError` を含む型） | `Equality(α)`、`Equal(α, Result[String, IoError])` | E0406 |
| 等値の型（型引数に依存する ADT） | 要約 `depends_on = [0]` の `Box[T]` で、`Equality(Box[fn() -> Unit])` と `Equality(Box[Int])` | 前者だけ E0406 |
| 等値の型（リストの要素へ移す） | `Equality(List[α])`、`Equal(α, fn() -> Unit)` | E0406 |
| 決まらない型変数 | `OneOf(α, ADD)` だけ | 診断なし。`undetermined()` が一つの理由を返す |
| 流れ込む・エフェクトの包含 | `Flow(fn() -> Unit, fn() -> Unit uses IO)` | 診断なし |
| 流れ込む・エフェクトの違反 | `Flow(fn() -> Unit uses IO, fn() -> Unit)`、理由 `CallArg { index: 1 }` | E0401、`found fn() -> Unit uses IO`、注記 `because_call_arg` |
| 流れ込む・順序によらない | 02-05 の `[fn() { () }, fn() { Console.println("a") }]` に当たる制約（要素の型を α として `Flow(fn() -> Unit, α)`、`Flow(fn() -> Unit uses IO, α)`）と、要素の順を入れ替えたもの | どちらも診断なし。`finalize(α)` は `fn() -> Unit uses IO` |
| 後回しの解き直し | `Flow(α, β)`、`Equal(α, fn() -> Unit)` | 診断なし。`finalize(β)` は `fn() -> Unit` |
| エフェクトの最小解 | 02-05 の `choose` の例に当たる制約（ε・ρ と、`EffSub(ρ, {IO} ∪ ε)`、`EffSub({}, ε)`、`EffSub(ε, {})`（理由 `FnUses`）、`EffSub({IO}, ρ)`） | 診断なし。ε は空集合 |
| エフェクトの違反（関数） | 上の `EffSub({}, ε)` を `EffSub({IO}, ε)` に変えたもの | E0501、`effect IO`、補助の位置 `declared` |
| エフェクトの違反（ラムダ） | `EffSub({IO}, {})`、理由 `LambdaUses` | E0502 |
| エフェクト変数の名前 | `EffSub({E0}, {})`、理由 `FnUses`、`effect_params = ["E"]` | E0501、`effect E` |
| 決まっていないエフェクト | `fresh_effect()` の変数に何も加えない | `finalize_effect` は空集合 |

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- `Solver` の公開の関数は 10-05 のシグネチャのとおりで、欄はすべて非公開である

## 難易度の理由

HM の単一化に、流れ込む制約の後回しと解き直し、制約を持つ型変数、エフェクトの最小解、誤りの型による派生の抑止が重なる。どれも 02-05 に手順が書いてあるが、組み合わさったときの振る舞い（解く順序で診断が変わる、後回しの制約が別の制約で片付くなど）は、単純な例では現れにくい。型検査の結果はほかのすべての段の前提になるので、ここでの誤りは後の段の不具合として現れ、原因を辿りにくい。
