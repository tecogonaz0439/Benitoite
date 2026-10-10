C1b を完了しました。`formal/` の `lake build` は **`sorry` の警告なしで成功**し、二つの定理が使う公理は **`propext`・`Classical.choice`・`Quot.sound` の三つだけ**でした。`scripts/check.sh --base HEAD` も、`formal` の検査だけを選んで成功しました。コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

行数は作業終了時のファイル全体の行数です。

| 区分 | ファイル | 行数 | 内容 |
|---|---|---:|---|
| 変更 | [Surface/Syntax.lean](formal/Benitoite/Surface/Syntax.lean) | 139 | `returnE` の注釈の説明を修正 |
| 変更 | [Surface/Typing.lean](formal/Benitoite/Surface/Typing.lean) | 207 | `E_ReturnTail` の修正、`MainReturn` と入口の条件の説明 |
| 変更 | [Surface/Theorems.lean](formal/Benitoite/Surface/Theorems.lean) | 39 | `hsig` の追加と二つの定理の証明 |
| 変更 | [Surface/Examples.lean](formal/Benitoite/Surface/Examples.lean) | 291 | 脱糖したプログラムの実行例を 7 行の表として追加 |
| 新規 | [Surface/Lemmas/Invariants.lean](formal/Benitoite/Surface/Lemmas/Invariants.lean) | 165 | 環境・戻り値型・中間結果の型の不変条件 |
| 新規 | [Surface/Lemmas/ScopedRename.lean](formal/Benitoite/Surface/Lemmas/ScopedRename.lean) | 93 | 任意のエフェクト変数の範囲を保つコアの番号の付け替え |
| 新規 | [Surface/Lemmas/Sequence.lean](formal/Benitoite/Surface/Lemmas/Sequence.lean) | 144 | 引数列の `let`、逆順の変数番号、エフェクトの拡大の補題 |
| 新規 | [Surface/Lemmas/Typing.lean](formal/Benitoite/Surface/Lemmas/Typing.lean) | 208 | 式・引数列・リスト要素列・ブロックの型保存 |
| 新規 | [Surface/Lemmas/Scoped.lean](formal/Benitoite/Surface/Lemmas/Scoped.lean) | 117 | 脱糖による型変数・エフェクト変数の範囲保存 |
| 新規 | [Surface/Lemmas/Program.lean](formal/Benitoite/Surface/Lemmas/Program.lean) | 55 | プログラム全体の三つの性質と入口の型付け |

新規ファイルは計 **782 行**です。既存ファイルの変更は **99 行追加・17 行削除**で、全体では **881 行追加・17 行削除、差し引き 864 行増加**です。

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、61 jobs、警告なし |
| `scripts/check.sh --base HEAD --dry-run` | 変更 10 ファイルに対し `formal` だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| Surface のソースの確認 | `sorry`・`axiom`・`native_decide` なし |
| 公理の確認 | 二つの定理とも指定の三公理だけ |
| レビューの反例の確認 | 新しい `hsig` を満たさないことを Lean で証明 |

公理と反例の検査用ファイルは `formal/` 内に作り、検査後に削除しました。変更は上表の 10 ファイルだけです。`Release`・`Core`、組み込みの `Assumptions`、設計書、AGENTS.md、`formal/README.md` は変更していません。

## 2. `handling.md` の指摘 1・2・4・6・7 への対応

**指摘 1 — シグネチャの範囲条件**

`desugar_typed` に、指定された次の前提を加えました。

```lean
(hsig : ∀ b s, B.sig b = some s → s.Scoped)
```

`surface_effect_soundness` では、`hb.sig_scoped` をそのまま渡しています。組み込みの関数の動作について、新しい仮定は加えていません。

`counterexample-1.lean` の内容を一時ファイルで検査し、既存の脱糖例と表層の型付けの証明が引き続き通ることを確認しました。そのうえで、次の三つを Lean で証明しました。

```lean
¬ (∀ b s, B0.sig b = some s → s.Scoped)
¬ mkSig.Scoped
¬ useSig.Scoped
```

`mkSig` は戻り値に継続型を含み、`useSig` は引数に継続型を含むため、どちらも `PrimSig.Scoped` を満たしません。したがって、レビューの反例は新しい `desugar_typed` の前提を満たしません。元の反例ファイルは変更していません。

**指摘 2 — 継続型を含まないことの不変条件**

採用された案 (a) に従い、型付け規則には前提を足していません。

補題の側に `EnvClean` を定め、局所環境の型と戻り値型が `TyOK` を満たすことを帰納法の前提にしました。`HasType.clean`・`HasBlock.clean` は、表層の導出と範囲条件から、中間結果の型も `TyOK` を満たすことを示します。ここで `TyOK` は既存の `Release.TyOK` であり、型変数が範囲内にあり、継続型を含まないことを表します。

この条件から `clean_notCont` を使い、引数列、リスト要素、非末尾の `return` の脱糖で挿入する変数に `V_Var` を適用しています。関数の入口では、`hwf` の引数型・戻り値型の範囲条件から不変条件を得ています。

**指摘 4 — 末尾の `return` の注釈**

`E_ReturnTail` を、構文の注釈 `a` と戻り値型 `r` を分ける形に修正しました。

```lean
| E_ReturnTail {C Γ r a e ε} :
    HasType D B opPrim C Γ (some r) .tail e r ε →
    HasType D B opPrim C Γ (some r) .tail (.returnE a e) r ε
```

既存の脱糖例は修正せずに通りました。`Syntax.lean` の `returnE` の説明も、末尾の型付けと脱糖では注釈を使わないことが分かるように直しました。

**指摘 6 — Rust の括弧付き `return`**

[crates/benitoite/src/typeck/generate.rs:797](crates/benitoite/src/typeck/generate.rs:797) の `always_expr` を確認しました。

```rust
Expr::Return(_) => true,
Expr::Paren(p) => always_expr(&p.inner),
```

括弧の内側を再帰的に調べるため、Rust は `(return e)` を必ず抜ける式として扱います。Lean の `Expr.Exits` と一致するので、この定義は変更していません。

**指摘 7 — `MainReturn`**

`MainReturn` は残しました。docstring に、01-07「プログラムの入口」の条件の写しであり、健全性の証明には使わないことを明記しています。

入口の型付けを示す `main_typed` は、`HasMain` に含まれる `MainReturn` の証明を使いません。関数の存在、型・エフェクトパラメータと値引数がないこと、エフェクトが空集合に含まれることから型付けを得ます。

## 3. 二つの定理の最終の言明と `#print axioms` の出力

以下は `Theorems.lean` のコードをそのまま示したものです。`Benitoite.Surface` 名前空間内で、`Benitoite.Release` を `open` しています。

```lean
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) :
    (desugarProgram opPrim p).WellFormed ∧
      (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B := by
  exact ⟨desugar_wellFormed hwf hwt, desugar_wellTyped hwf hwt hsig, desugar_effectsOk⟩
```

```lean
theorem surface_effect_soundness {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hb : B.Assumptions (desugarProgram opPrim p))
    (hmain : p.HasMain Eff.empty) :
    ∀ s, Steps (desugarProgram opPrim p) B
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim p) B s (some ev) s') ∧ ¬ UnhandledOp s := by
  obtain ⟨hwf', hwt', heffects⟩ := desugar_typed hwf hwt hb.sig_scoped
  obtain ⟨a, hm⟩ := main_typed (B := B) (op := opPrim) hmain
  exact Release.effect_soundness hwf' hwt' heffects hb hm ⟨⟨trivial, trivial⟩, trivial⟩
```

最終のソースをビルドした後の公理の出力は、次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

`formal/README.md` に挙げられた Core・Release の定理も同じ一時ファイルで確認し、標準の公理以外は現れませんでした。

## 4. 証明の構成

型の保存と範囲の保存を、それぞれ表層の型付けの導出に沿って証明し、最後にプログラム全体の性質へまとめています。

| 主な補題 | 役割 |
|---|---|
| `EnvClean`、`HasType.clean`、`HasBlock.clean` | 局所環境・戻り値型の条件から、中間結果の型が継続型を含まないことを導く |
| `subst_clean`、`substList_clean`、`fnTy_clean` | 型引数による具体化が型の不変条件を保つことを示す |
| `boundVars_typed` | 番号 `n−1, …, 0` の引数列が、逆順に束縛された環境で元の引数型の並びを持つことを示す |
| `CompTypes`、`letChain_typed`、`sequence_typed` | 引数を左から計算し、先行する束縛数だけ番号をずらす脱糖に型を付ける |
| `typedLet`、`typedIfLet` | 部分計算のエフェクトを和集合へ広げ、コアの共通の許容エフェクトを要求する規則に合わせる |
| `directCallee_typed` | 直接呼び出す関数名・組み込み名について、`E_Sub` を含む導出からコアの値の型付けを取り出す |
| `HasType.desugar`、`HasTypes.desugar`、`HasEach.desugar`、`HasBlock.desugar` | C1 の各構文について、脱糖後の型付けを相互再帰で構築する |
| `renameScoped` と各 `desugar_scoped` | 番号の付け替えと脱糖が、型変数・エフェクト変数の範囲を保つことを示す |
| `desugar_wellFormed`、`desugar_wellTyped`、`desugar_effectsOk` | 定義ごとの結果をプログラム全体の三つの結論へまとめる |
| `main_typed` | 純粋な `main[;]()` のコア型付けを得る |

`surface_effect_soundness` は、`desugar_typed` の三つの結論と `main_typed` を既存の `Release.effect_soundness` に渡して証明しています。

追加した実行例は、脱糖したプログラムを `Release.run` で実行し、次の戻り値と事象数を確認します。すべて `decide` で証明しています。

| 例 | 確認する振る舞い | 期待結果 | 事象数 |
|---|---|---|---:|
| `pick(11, 22)` | 引数の順序と逆順の変数番号 | `11` | 0 |
| `capture(5)` | 束縛、捨てる束縛、括弧付きラムダの捕捉 | `10` | 0 |
| `early()` | 非末尾の `return` が関数の境界まで抜ける | `7` | 0 |
| `and()` | 偽の左辺による短絡評価 | `false` | 0 |
| `or()` | 真の左辺による短絡評価 | `true` | 0 |
| `emit()` | 実行した IO 呼び出しの事象 | `Unit` | 1 |
| `main()` | 純粋な入口の終了 | `Unit` | 0 |

## 5. 表層の型付けや脱糖を変えた箇所と理由

表層の型付けの変更は、指摘 4 の **`E_ReturnTail` だけ**です。構文の注釈を戻り値型と一致させる制限を取り除き、末尾の `return` の型を `r` として検査しながら、注釈 `a` を無視する形にしました。脱糖が注釈を使わないことと、レビューで決まった対応に合わせた変更です。

**脱糖の変更はなし**です。`Desugar.lean` は変更していません。

それ以外の型付け規則、範囲条件、`Exits`、定理の前提には変更を加えていません。定理の前提の追加は、指定された `desugar_typed` の `hsig` だけです。

## 6. 後の段階で証明を広げるときの注意

**C2 の `match` とパターン**では、パターンが束縛する型の並びと局所変数番号の対応を、`Release.PatTy`・`binds` と合わせる必要があります。分岐ごとの型付けに加え、コアの `C_Match` が要求する網羅性も導く必要があります。新しい構文には、型保存、範囲保存、中間結果の型の不変条件の各証明を追加します。

**C2 のパイプとプレースホルダ**では、計画どおり直接コアへ移す場合として書けば、`letChain_typed` の既存の束縛 `xs` と番号の付け替えの補題を再利用できます。表層の式を新しく作ってから脱糖する方式を選ぶ場合は、表層の番号の付け替えと型付けの弱化を別に証明する必要があります。

**C4 のハンドラ**では、現在の `EnvClean` をそのまま節の環境に要求できません。現在の条件は環境のすべての型が継続型を含まないことを表しますが、ハンドラの節では継続変数が環境に入ります。通常の値として使える変数と、`resume` の第一引数としてだけ使える継続変数を区別する不変条件へ拡張する必要があります。通常の式の結果型と関数の戻り値型については、継続型を含まない条件を維持できます。

ハンドラの節では型パラメータも増えるため、`C` の長さ、環境の型、戻り値型 `R` のずらしを同時に扱います。今回の範囲保存の補題は任意のエフェクト変数の範囲 `pe` に対して証明してあるので、その部分は拡張できます。型付けの証明には、既存の `Release` の型のずらし・置き換えの補題と `RenOk.clause` を組み合わせる必要があります。