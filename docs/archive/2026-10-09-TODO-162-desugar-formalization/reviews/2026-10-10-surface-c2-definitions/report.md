C2a を実装した。`formal/` の **`lake build` は成功**し、共通検査の `scripts/check.sh --base HEAD` も通った。追加した脱糖の例は **26 個すべて `rfl`** で確認できた。二つの定理の言明と C1 の証明分岐を維持し、証明待ちの `sorry` は C2a で追加した 30 分岐だけに置いた。コミットはしていない。

## 1. 変えたファイル・作ったファイルと行数

行数は作業終了時のファイル全体の行数である。新規ファイルはなく、次の 9 ファイルを変更した。

| ファイル | 行数 | 追加／削除 | 内容 |
|---|---:|---:|---|
| [Surface/Syntax.lean](formal/Benitoite/Surface/Syntax.lean) | 220 | +85／−4 | 基本パターン、構成子値、パイプ、プレースホルダ、分岐列、パターン束縛 |
| [Surface/Typing.lean](formal/Benitoite/Surface/Typing.lean) | 295 | +89／−1 | 新しい構文の型付け、引数列・分岐列の判断 |
| [Surface/WellFormed.lean](formal/Benitoite/Surface/WellFormed.lean) | 77 | +19／−1 | 新しい型注釈と局所変数の範囲条件 |
| [Surface/Desugar.lean](formal/Benitoite/Surface/Desugar.lean) | 202 | +65／−2 | 新しい各行の脱糖、穴の引数列と分岐列の相互再帰 |
| [Surface/Theorems.lean](formal/Benitoite/Surface/Theorems.lean) | 39 | +2／−2 | 対象範囲のコメントを C1・C2 に更新 |
| [Surface/Examples.lean](formal/Benitoite/Surface/Examples.lean) | 442 | +152／−1 | C2 の脱糖例 26 個 |
| [Surface/Lemmas/Invariants.lean](formal/Benitoite/Surface/Lemmas/Invariants.lean) | 177 | +12／−0 | 新しい場合の結果型の不変条件を証明待ちとして追加 |
| [Surface/Lemmas/Scoped.lean](formal/Benitoite/Surface/Lemmas/Scoped.lean) | 129 | +12／−0 | 新しい場合の範囲保存を証明待ちとして追加 |
| [Surface/Lemmas/Typing.lean](formal/Benitoite/Surface/Lemmas/Typing.lean) | 220 | +12／−0 | 新しい場合の型保存を証明待ちとして追加 |
| **合計** | **1,801** | **+448／−11** | **差し引き 437 行増加** |

検査結果は次のとおりである。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功。追加した例も検査済み |
| `scripts/check.sh --base HEAD --dry-run` | 変更 9 ファイルに対し、`formal` の検査だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| ソースの確認 | `sorry` は追加分岐の 30 箇所だけ。`axiom`・`native_decide` の追加なし |

変更は上表のファイルだけである。`Release`・`Core`、組み込みの `Assumptions`、`docs/design/`、AGENTS.md、`formal/README.md` は変更していない。

## 2. 足した構文の表し方

表層のパターンは、独立した帰納型 `Pattern` とした。ワイルドカード、変数、非負の整数、`-n`、文字列、文字、真偽値、Unit、構成子を持ち、浮動小数点数は持たない。構成子は表示用の修飾 `Option DataName` と、名前解決済みの一意な構成子名を持つ。`Pattern.toCore` は修飾を除き、`-n` を負の整数定数にして `Release.Pat` へ移す。

分岐列は、`Expr`・`Exprs`・`Block` と同じ相互帰納の中に置いた `Arms` で表した。パターンの型付けが返す束縛型の並びを `δ` とすると、分岐本体とパターン束縛の続きの環境は、どちらも **`Release.binds δ ++ Γ`** である。照合で左から集める束縛のうち、最後の束縛が番号 0 になる。

脱糖が加える照合対象の変数については、本体を次の形でずらす。

```lean
(desugarBlock opPrim p body).rename
  (upRen pat.toCore.binders (· + 1))
```

これにより、パターンが束縛する変数を保護し、外側の変数だけを一つずらす。`Pair`・`Triple` は通常の構成子パターンとして扱う。

パイプは `Expr.pipe lhs rhs` として保持した。プレースホルダは `Expr.partialCall`・`Expr.partialCon` と、専用の相互帰納型 `HoleArgs` で保持した。`HoleArgs` は非穴の式と型注釈付きの穴を区別するため、穴をリスト要素などへ直接置く構文は作れない。穴の型は左から集め、展開後のラムダの引数型とする。

構成子を値として使う形は `Expr.conValue c tys params`、パターン束縛は `Block.bindPat`・`Block.lastPat` とした。束縛には `BindKind` を持たせ、`bind` と `shadow` を同じ脱糖へ移す。

## 3. 足した表層の型付けの規則と、01-05・01-06 との対応

| 規則・判断 | 対応する仕様と検査内容 |
|---|---|
| `E_ConValue` | 構成子の宣言と型引数の個数を確認し、`params = cd.args.map (Ty.subst ts [])` と `params ≠ []` を要求する。純粋な関数型を与える |
| `E_Match`・`HasArms` | 01-05「match の意味」と 01-06「式と文の型」に対応する。全分岐を共通の結果型で検査し、分岐のエフェクトを合成する |
| `HasArms.cons` | `Release.PatTy` が返す束縛型の並びの下で、分岐本体を検査する |
| `HasArms.nil` | `Release.HasTypeArms.nil` と同じく、空の分岐列でも結果型の `Ty.WF` を要求する |
| `B_BindPat`・`B_LastPat` | 01-05「必ず照合するパターン」に対応する。変数と `_` を除き、一分岐の網羅性を要求する |
| `E_PipeCall`・`E_PipeConCall` | 01-02 の規則 1 に従い、左辺を第 1 引数とする呼び出しとして型を決める |
| `E_PipeConValue`・`E_PipeApply` | 01-02 の規則 2 に従い、一引数の適用として型を決める。括弧付きの式とプレースホルダの呼び出しもここに含む |
| `E_PartialCall`・`E_PartialCon`・`HasHoleArgs` | 01-06 の「展開した式として型を決める」に従い、展開後のラムダ本体として検査する |

パターンの判断には、新しい独自の型付けを作らず、`Release.PatTy D.patternProgram pat.toCore a δ` を使った。`Declarations.patternProgram` は、表層の `D.cons` だけを持つ `Release.Program` である。

網羅性は `Release.Exhaustive` で表した。`match` では分岐の全パターンについて要求し、パターン束縛では次を要求する。

```lean
Exhaustive D.patternProgram t [pat.toCore]
```

プレースホルダの呼び出しでは、呼ぶ関数と非穴の引数を **`hideConts Γ`、`R = some r`** の下で検査する。`r` は展開後の呼び出し結果の型である。構成子版では `some (.data cd.data ts)` を使う。新しく作る引数はソースに見えないため、この検査の環境には加えず、脱糖の出力側で番号をずらす。

型とエフェクトの包含には C1 の `E_Sub`・`B_Sub` を引き続き使う。`Expr.Exits` には `match` を追加し、すべての分岐本体が必ず抜ける場合に必ず抜けるものとした。

## 4. 定理の言明と、`sorry` を置いた箇所の一覧

**`desugar_typed` と `surface_effect_soundness` の言明は C1 のまま**である。前提は追加していない。`Theorems.lean` の変更は対象範囲のコメントだけで、二つの定理の証明本体も維持した。

`sorry` は次の追加分岐だけにある。

| ファイル・補題 | 箇所 | 分岐数 |
|---|---|---:|
| `Lemmas/Invariants.lean` — `HasType.clean` | 122〜129 行 | 8 |
| 同 — `HasBlock.clean` | 164・165 行 | 2 |
| `Lemmas/Scoped.lean` — `HasType.desugar_scoped` | 30〜37 行 | 8 |
| 同 — `HasBlock.desugar_scoped` | 115・116 行 | 2 |
| `Lemmas/Typing.lean` — `HasType.desugar` | 36〜43 行 | 8 |
| 同 — `HasBlock.desugar` | 195・196 行 | 2 |

各式の補題に置いた 8 分岐は、`E_ConValue`、`E_PipeCall`、`E_PipeConCall`、`E_PipeConValue`、`E_PipeApply`、`E_PartialCall`、`E_PartialCon`、`E_Match` である。各ブロックの補題に置いた 2 分岐は、`B_LastPat` と `B_BindPat` である。

新しい補題全体を `sorry` にした箇所はない。相互再帰のため既存の補題にも警告が出るが、C1 の分岐の証明を `sorry` に置き換えた箇所はない。公理の確認は指定どおり C2b に残した。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応

C2 の追加対象をすべて覆った。プレースホルダと `pi'` は、表の前段の規則・説明として含めている。

| 01-12 の行・規則 | 脱糖の関数の場合 | 対応する例 |
|---|---|---|
| 引数を持つ構成子を値として使う | `desugarExpr .conValue` | `con_value_row` |
| 組み込みの関数を値として使う | C1 の `.primName` を継続使用 | C1 の `prim_row` |
| パイプ：右辺が穴のない呼び出し | `.pipe` の `.call`・`.conCall` | `pipe_fun_call_row`、`pipe_prim_call_row`、`pipe_con_call_row`、`pipe_indirect_call_row`、`pipe_outer_call_row` |
| パイプ：右辺が裸の名前・その他の式 | `.pipe` の `.conValue`・その他の分岐 | `pipe_fun_name_row`、`pipe_prim_name_row`、`pipe_con_name_row`、`pipe_value_row`、`pipe_paren_call_row` |
| プレースホルダの関数呼び出し | `.partialCall`・`desugarHoleArgs` | `partial_call_row`、`partial_prim_row`、`partial_indirect_row`、`partial_return_row` |
| プレースホルダの構成子呼び出し | `.partialCon`・`desugarHoleArgs` | `partial_con_row` |
| パイプとプレースホルダの組み合わせ | `.pipe` と上記の呼び出しの分岐 | `pipe_partial_row`、`pipe_nested_partial_row` |
| `match` | `.matchE`・`desugarArms` | `match_row`、`match_pair_scope_row`、`match_empty_row` |
| パターン `pi'` | `Pattern.toCore`・`Pattern.toCoreList` | `pattern_rows` |
| `{ bind p <- e; s̄ }` | `desugarBlock .bindPat` | `bind_pattern_row`、`bind_triple_pattern_row` |
| `{ bind p <- e }` | `desugarBlock .lastPat` | `last_pattern_row`、`last_unit_pattern_row` |

期待値には、脱糖の補助関数で作った結果を使わず、コアの項を直接書いた。既存の C1 の脱糖例と実行例も引き続き通っている。

## 6. パイプとプレースホルダの脱糖の形、01-02 の展開との一致、Rust との差

パイプは左辺を先に一度だけ評価し、その値を右辺へ渡す。例えば `e1 |> f(a)` は、名前で表すと次の形になる。

```text
let t ⇐ ⟦e1⟧ in
let x ⇐ ⟦a⟧ in
f(t, x)
```

一般の呼ぶ関数の式では、`t` を得た後、呼ぶ関数、残りの引数の順に評価する。右辺が括弧付きの呼び出しなら、その呼び出しの結果を `t` に適用する。呼び出しを重ねた右辺では、最も外側の呼び出しにだけ `t` を加える。引数内に入れ子になったプレースホルダは、第 1 引数の挿入を妨げない。

01-02 の展開後に 01-12 の一般の引数列の規則を文字どおり適用すると、差し込んだ `t` にも `let x ⇐ return t` を作る。今回は指定に従い、**この再束縛を省いた**。そのため、Rust の `pipe` と同じく、左辺の値をそのまま引数として渡す。元の規則との違いは、値の再束縛の有無である。

プレースホルダは、例えば `f(_, a)` を次の形へ移す。

```text
return λ(p:A).
  let x ⇐ return p in
  let y ⇐ ⟦a⟧ in
  f(x, y)
```

呼ぶ関数が名前以外の式なら、その計算もラムダ本体の先頭に置く。したがって、呼ぶ関数と非穴の引数は、部分適用の式を作った時点では評価されず、展開後のラムダを呼んだ時点で評価される。これは 01-02 の評価時期の規則に従い、Rust の `placeholder` が作る本体とも同じ構成になる。

穴の引数については、**`let x ⇐ return p` の再束縛を残した**。番号は、穴の総数を `n`、左から既に通った穴の個数を `i` として `n - 1 - i` とする。非穴の式はまずラムダ引数の `n` 個分ずらし、その後、先行する `let` の個数分ずらす。

非穴の `return` はラムダ本体内の `escape` になる。型付けも新しいラムダの戻り値型で行うため、事前に報告された Rust の型検査の不具合には追随していない。脱糖の構造は 01-02 に従っている。

## 7. 01-12 との食い違いと、対象から外した要素

食い違いと、写しへの反映が必要な点は次のとおりである。

- **パイプの値の再束縛を省いた。** 01-12 の展開結果へ一般の引数の規則を適用した形にある `let x ⇐ return t` を省く。該当箇所に「01-12 との食い違い」のコメントを置いた。
- **プレースホルダを直接コアへ移す場合にした。** 01-02 のラムダ展開を表層の木として作らず、同じ評価順序と評価時期になるコアのラムダを作る。
- **網羅性は 01-05 の検査より広い。** `Release.Exhaustive` は値の形に属する値について照合を要求するため、値を作れない型では空の分岐も網羅しうる。`Character` を列挙し尽くす場合も認める。また、選ばれない分岐の検査を表さない。C2b の性質 1 は、この広い側の型付けについて証明する言明になっている。
- **パターンの名前の条件は入力の前提である。** 名前解決済みの構文として、変数名の重複やシャドーイングを検査し直さず、束縛の並びと番号で表す。C1 の名前の扱いと同じ境界である。

**C2 の対象から外した要素はない。** ガード・選択肢・範囲・リストなどのパターンの拡張は、計画どおり C7 に残っており、今回追加した基本パターンには含めていない。

## 8. 後半（証明）で難しくなりそうな箇所の見込み

最も補題が必要になるのは、パターンの束縛と挿入した変数の環境の対応である。`PatTy` が返す `δ` の長さと `Pat.binders` が一致すること、`δ` の型が範囲内で継続型を含まないことを得て、`upRen` による付け替えを型付けの弱化へ結び付ける必要がある。

網羅性には、`D.patternProgram` と脱糖後のプログラムで構成子の表が同じであることを使う。`PatTy`・`Inhabits`・`Exhaustive` がこの表だけに依存することを示せば、表層の前提をコアの `C_Match` へ渡せる。

プレースホルダでは、`desugarHoleArgs` の再帰に対して、**「既に通った穴の個数＋残る穴の個数＝穴の総数」**という不変条件が要る。これを使って、穴の番号が `binds args.holeTypes` に対応することを示す。非穴の式と呼ぶ関数については、`hideConts Γ` で得た導出を、ラムダ引数の下へ弱化する。

パイプでは、差し込んだ左辺の値を再束縛しないため、`letChain_typed` の既存の束縛 `xs` を使う形が適している。間接呼び出しでは左辺と呼ぶ関数の二つが先に束縛されるので、それぞれの番号と引数列の番号を区別する必要がある。

分岐列・穴の引数列の証明は、既存の相互再帰補題に `HasArms`・`HasHoleArgs` の補題を加える形が見込まれる。C1 の `sequence`、`letChain`、`boundVars`、番号の付け替えの補題は、そのまま再利用できる。