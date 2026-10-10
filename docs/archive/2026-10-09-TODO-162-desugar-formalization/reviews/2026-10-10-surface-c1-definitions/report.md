C1a を実装しました。`formal/` の `lake build` は成功し、`sorry` の警告は `desugar_typed` と `surface_effect_soundness` の二つだけです。脱糖の例は **46 個すべて `rfl`** で確認しました。定理の証明本体は、指定どおり C1b に残しています。

## 1. 作ったファイルと行数

| ファイル | 行数 | 内容 |
|---|---:|---|
| [Surface/Syntax.lean](formal/Benitoite/Surface/Syntax.lean) | 138 | 型の情報を付けた表層の構文、宣言、関数、プログラム |
| [Surface/Typing.lean](formal/Benitoite/Surface/Typing.lean) | 206 | 表層の型付け、必ず抜ける文の検査、`main` の条件 |
| [Surface/WellFormed.lean](formal/Benitoite/Surface/WellFormed.lean) | 59 | 型・エフェクト・局所変数の番号の範囲 |
| [Surface/Desugar.lean](formal/Benitoite/Surface/Desugar.lean) | 139 | 式、ブロック、関数、プログラムの脱糖 |
| [Surface/Theorems.lean](formal/Benitoite/Surface/Theorems.lean) | 39 | 二つの定理の言明 |
| [Surface/Examples.lean](formal/Benitoite/Surface/Examples.lean) | 211 | 各行の脱糖と番号のずらしを確認する 46 個の例 |
| **新規ファイルの合計** | **792** | |
| [formal/Benitoite.lean](formal/Benitoite.lean) | 23（6 行追加） | Surface の六つのファイルを import |

検査は次のとおりです。

- `formal/` で `lake build`：成功。Core・Release を含む 55 jobs。
- `scripts/check.sh --base HEAD --dry-run`：今回の変更 7 ファイルに対して、検査は `formal` だけと確認。
- `scripts/check.sh --base HEAD`：成功。
- `git diff --check`：成功。
- Surface のソースの確認：`sorry` は二つの定理の本体だけ。`axiom`・`native_decide` の追加なし。

変更は上記の 7 ファイルだけです。Release・Core、設計書、AGENTS.md、`formal/README.md` は変更していません。`Lemmas/` の作成とコミットも行っていません。

## 2. 表層の構文の表し方の要点

局所変数は `Expr.local i` で表します。番号の並びは Release の `binds` に合わせ、関数やラムダの**最後の引数が番号 0** です。名前のある `bind`・`shadow` の続きでは、新しい束縛が番号 0 になります。`bind _` と式文は、表層の局所環境を増やしません。

多相な名前は、トップレベルの関数を `funName f tys effs`、組み込みの関数を `primName b tys effs` として区別します。構成子の名前と呼び出しも別に持ち、型引数を残します。関数の定義は `List TParam` を持ち、制約を含めて Release にそのまま写します。

構文は `Expr`・`Exprs`・`Block` の相互帰納型です。引数とリスト要素の並びを `Exprs` にしたことで、脱糖もこの三つの構造に沿った相互再帰として定義できました。

脱糖が挿入する変数の番号は、出力側で変更します。

- 引数とリスト要素は、元の環境で脱糖してから、先行する `let` の個数だけ `Comp.rename` でずらします。
- 全引数を束縛した後の `x1, …, xn` は、番号 `n−1, …, 0` です。
- 条件を束縛する `let`、`bind _`、式文の `let` では、後続の計算の自由変数を一つずらします。
- 名前のある `bind`・`shadow` は、表層でも続きに一つ束縛してあるため、その続き全体を追加ではずらしません。
- ラムダの引数や内側の `let` の束縛は、Release の `rename` が使う `upRen` によって保護されます。

## 3. 表層の型付けの判断の形と、01-06 との対応

式の判断は次の形です。

```lean
HasType D B opPrim C Γ R p e a ε
```

`D` は表層の関数・構成子の宣言、`B` は既存の `Release.Builtins`、`C` は型パラメータの制約、`Γ` は局所環境、`R` は最も内側の関数の戻り値型、`p` は末尾位置かどうかです。ブロックには `HasBlock`、引数の並びには `HasTypes`、同じ要素型のリストには `HasEach` を定めました。これらは脱糖の結果を参照しません。

01-06 との対応は次のとおりです。

| 01-06 の規則 | 実装 |
|---|---|
| 式と文の型 | リテラル、呼び出し、リスト、ラムダ、条件分岐、束縛、式文の各構成子 |
| 必ず抜ける文 | `Expr.Exits`・`Block.Exits`。非 `Unit` の関数・ラムダには必ず抜ける本体を要求し、`B_Seq` は必ず抜ける式の後続文を拒否 |
| 式のエフェクト | 部分式のエフェクトを `Eff.union` で合成。呼び出しには関数型のエフェクトも加算 |
| エフェクトの包含 | `E_Sub`・`B_Sub` と既存の `Ty.Le`・`Eff.Sub` |
| 多相・エフェクト変数の具体化 | 関数名には `SatAll`、組み込み名には `admits`、両方に引数の個数と `fnTy` |
| 演算子の型付け・等値の型 | `opPrim` の結果を `B.sig` で引き、`admits` と具体化後の `fnTy` を検査 |

演算子では、二項演算の具体化後の型が純粋な `(T, T) → A`、単項の負号が純粋な `(T) → T` であることを検査します。型の集まりと二項演算の結果型は、指定された組み込みのシグネチャから決めます。`=`・`<>` の型引数は `[T]`、ほかの演算子の型引数は `[]` に限定しています。組み込み関数の `Assumptions` は増やしていません。

末尾の `return` は、01-06 の「その位置で求められる任意の型」を `R` に具体化して判断します。非末尾の `return` は、構文に持たせた任意の結果型を使い、返す式を `R` で検査します。関数本体については、表層の `Unit` という条件と、脱糖後の結果型 `R` の違いを、位置付きの判断と「必ず抜ける本体、または戻り値型が `Unit`」という条件で表しています。

## 4. 性質 1 と `surface_effect_soundness` の言明と、前提ごとの理由

以下は `Benitoite.Surface` 名前空間内のコードをそのまま示したものです。`Benitoite.Release` を `open` しています。

```lean
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim) :
    (desugarProgram opPrim p).WellFormed ∧
      (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B := by
  sorry
```

```lean
theorem surface_effect_soundness {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hb : B.Assumptions (desugarProgram opPrim p))
    (hmain : p.HasMain Eff.empty) :
    ∀ s, Steps (desugarProgram opPrim p) B
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim p) B s (some ev) s') ∧ ¬ UnhandledOp s := by
  sorry
```

前提の理由は次のとおりです。

| 前提 | 理由 |
|---|---|
| `hwf : p.WellFormed` | 番号で表した型変数・エフェクト変数・局所変数の範囲と、項に書ける型を入力側で保証するため |
| `hwt : p.WellTyped B opPrim` | すべての表層の定義が、宣言と型付け規則に適合することを要求するため |
| `hb : B.Assumptions (desugarProgram opPrim p)` | 既存の `Release.effect_soundness` が要求する組み込み関数の動作の仮定。性質 1 には不要 |
| `hmain : p.HasMain Eff.empty` | `main` の存在、型・エフェクトパラメータと値引数がないこと、許される戻り値型、エフェクトが空集合に含まれることを表層の宣言で保証するため |

性質 1 には、脱糖後の型付けや、組み込み関数の動作、`main` の存在を前提として加えていません。`EffectsOk` は、C1 の出力には利用者の操作・エフェクト宣言がないため、脱糖から導く結論に含めています。

健全性の開始状態は `main[;]()` です。結論は既存の Release の定理に合わせ、IO と解放の事象を伴う遷移、および処理されない操作の呼び出しがないことを述べています。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応

C1 対象の **29 行をすべて覆っています**。追加の例では、直接呼び出し、空の引数・リスト、各リテラル、`shadow`、番号のずらしも確認しています。

| 01-12 の節・行 | 脱糖の関数の場合 | 主な例 |
|---|---|---|
| 名前：局所の束縛 | `desugarExpr .local` | `local_row` |
| 名前：トップレベルの関数 | `.funName` | `fun_row` |
| 名前：prelude の関数 | `.primName`。Σ にあるものは `.funName` | `prim_row`・`fun_row` |
| 名前：引数のない構成子 | `.nullCon` | `null_con_row` |
| リテラル | `.literal` | `literal_integer_row`・`literal_float_row`・`literal_string_row`・`literal_char_row`・`literal_bool_row` |
| 整数リテラルへの直接の `-n` | `.negInt` | `neg_int_row` |
| `()` | `.unit` | `unit_row` |
| `(e)` | `.paren` | `paren_row` |
| 構成子の呼び出し | `.conCall` | `con_call_row` |
| そのほかの呼び出し | `.call` | `call_row`・`direct_fun_call_row`・`direct_prim_call_row`・`paren_call_row`・`zero_arg_call_row` |
| 二項演算 `e1 ⊕ e2` | `.binary` | `binary_row`・`eq_row`・`ne_row` |
| 単項の `-e` | `.neg` | `neg_row` |
| `not e` | `.not` | `not_row` |
| `e1 and e2` | `.and` | `and_row` |
| `e1 or e2` | `.or` | `or_row` |
| リスト | `.list` | `list_row`・`empty_list_row` |
| ラムダ | `.lam` | `lambda_row` |
| `else` のある `if` | `.ite` | `if_row` |
| `else if` | `.elseIf` | `else_if_row` |
| `else` のない `if` | `.ifOnly` | `if_only_row` |
| 空のブロック | `desugarBlock .empty` | `empty_block_row` |
| 最後の文が式 | `.last` | `last_expr_row` |
| 最後の文が束縛 | `.lastBind`・`.lastDiscard` | `last_bind_row`・`last_shadow_row`・`last_discard_row` |
| `bind x <- e; s̄`。`shadow` も同じ | `.bind` | `bind_row`・`shadow_row` |
| `bind _ <- e; s̄` | `.discard` | `discard_row` |
| 式文 `e; s̄` | `.seq` | `seq_row` |
| 末尾位置の `return` | `.returnE` の `.tail` | `return_tail_row` |
| 非末尾位置の `return` | `.returnE` の `.other` | `return_other_row`・`return_in_branch_row` |
| トップレベルの関数 | `desugarDef`・`desugarProgram` | `function_row`・`program_row`・`program_con_row` |

## 6. 01-12 との食い違いと、対象から外した要素

**01-12 との食い違いは、指定された名前の直接呼び出しです。** 表の一般の呼び出しは、呼ばれる側を `let y ⇐ ⟦e0⟧` で束縛します。実装では Rust の `prepare` に合わせ、直接書かれたトップレベルの関数名・組み込みの関数名について、この `let` を作らず `.app (.fnRef …) …` または `.app (.prim …) …` を作ります。該当箇所の直前に「01-12 との食い違い」のコメントを置きました。

括弧で囲んだ名前は Rust の `prepare` の直接の名前の条件に当たらないため、`(b)(...)` は一般の呼び出しとして移します。構成子の呼び出しは、表の構成子の行に従って `.conCall` から値を構築します。

**C1 の対象から追加で外した要素はありません。** プランで後の段階に置かれている、引数を持つ構成子を呼ばずに値として使う形、`match`・パターン束縛、パイプ・プレースホルダ、制御の拡張、型クラス、レコード等は今回の構文に含めていません。

`opPrim` が `none` を返す不正な入力では、脱糖関数を全域にするため `Unit` を返します。この場合は `E_Binary`・`E_Neg` の前提を満たせず、性質 1 が対象とする型の付く入力には含まれません。

## 7. 後半（証明）で難しくなりそうな箇所の見込み

最も補題が必要になるのは、**引数列の `let` と環境の対応**です。`letChain` が先行する束縛数だけ自由変数をずらすこと、`boundVars` の逆順の番号が引数の型の並びに対応することを、Release の `RenOk` と型付けの弱化で示す必要があります。`HasTypes` と `HasEach` の両方から使える形にすると、呼び出し・構成子・リスト・二項演算で共有できます。

名前の直接呼び出しでは、`directCallee` が値を返したとき、その値に Release の `HasTypeV` が付くことを示す補題が要ります。表層の導出に `E_Sub` が含まれる場合も扱います。

型とエフェクトの包含では、表層の規則が部分ごとの和集合を使い、Release の `C_Let`・`C_If` は共通の許容エフェクトを使うため、各部分をその和集合まで広げる処理が繰り返し現れます。

範囲条件の保存では、相互再帰する脱糖と `Comp.rename` の組み合わせを扱います。演算子が作る型引数は、等値では入力にある `[T]`、ほかでは空なので、その範囲は入力の `Scoped` と型付けの前提から導ける見込みです。

`surface_effect_soundness` は、性質 1 の三つの結論を得た後、`HasMain Eff.empty` から純粋な `main[;]()` のコア型付けと変数の閉じた条件を導き、既存の `Release.effect_soundness` を適用する形になります。ここでは `Eff.Sub d.eff Eff.empty` から `d.eff = Eff.empty` を得る小さな補題が必要です。