**C7b-2 の定義・例・証明を仕上げました。** 性質 1 と表層のエフェクト健全性の証明に `sorry` は残っていません。`lake build`、`lake build desugarDiff`、`scripts/check-formal.sh`、`scripts/check.sh --base HEAD` はすべて成功しました。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

変更は以下の **10 ファイル、追加 375 行・削除 43 行、正味 332 行増**です。新しいソースファイルは作っていません。

| ファイル | 追加 | 削除 | 内容 |
|---|---:|---:|---|
| [Surface/Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | 45 | 7 | 範囲・リスト、選択肢、ガード付き分岐、パターンの条件、網羅性への写像 |
| [Surface/Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | 13 | 7 | `HasArms.plain`・`guarded`、網羅性、パターン束縛の条件 |
| [Surface/Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | 11 | 4 | 選択肢・ガード・本体を `Release.Arm` に移す脱糖 |
| [Surface/WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | 7 | 2 | ガードと最初の選択肢の束縛数を含む範囲条件 |
| [Surface/Lemmas/Patterns.lean](../../../../../formal/Benitoite/Surface/Lemmas/Patterns.lean) | 50 | 4 | 選択肢の型付けの移送、束縛型の条件、ガードと本体の付け替え |
| [Surface/Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean) | 19 | 7 | `HasArms.desugar` のガードなし・ありの証明 |
| [Surface/Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | 7 | 3 | ガードを含む脱糖の範囲条件の証明 |
| [Surface/Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 2 | 2 | パターン束縛の新しい前提に合わせた場合分け |
| [Surface/Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:1752) | 220 | 6 | 既存の分岐の短縮形への移行と、新しい 16 件の例 |
| [Exchange/Convert.lean](../../../../../formal/Benitoite/Exchange/Convert.lean:265) | 1 | 1 | 既存の交換形式を `Arms.single` に読み込む変更 |

例以外は追加 155 行・削除 37 行です。既存の例は削除していません。公理検査の一時ファイルと検査中のログは `formal/` 内に作り、最後に削除しました。差分検査の生成物は [target/desugar-diff/run-41739/](../../../../../target/desugar-diff/run-41739) に残しています。

## 2. `#print axioms` の出力と、`scripts/check-formal.sh` の結果（一致・不一致・対象外の件数）

六定理の公理検査の出力です。

```text
'Benitoite.Release.progress' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.preservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.step_sound' depends on axioms: [propext, Quot.sound]
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

すべて指定された公理の範囲であり、`sorryAx` はありません。

`scripts/check-formal.sh` は終了状態 0 で成功しました。結果は次のとおりです。

| 集計対象 | 一致 | 不一致 | 対象外 | 型検査の失敗による除外 |
|---|---:|---:|---:|---:|
| ゴールデンのプログラム | 247 | 0 | 11 | 265 |
| ゴールデンの関数 | **475** | **0** | 12 | 0 |
| 生成したプログラム | 1,000 | 0 | 0 | 0 |
| 生成した関数 | **57,218** | **0** | 0 | 0 |

**対象の関数の件数は、ゴールデン 475 件・生成 57,218 件を維持しています。** 報告 JSON の `mismatches` も空でした。詳細は [report.json](../../../../../target/desugar-diff/run-41739/report.json) にあります。

Rust 側の書き出しは、1,523 入力について、書き出し 1,256 件・対象外 2 件・型検査の失敗による除外 265 件でした。Rust の検査は 2 件とも成功しました。差分検査全体の所要時間は約 7 分 38 秒で、そのうち Rust 側が 435 秒、Lean 側の比較が 18 秒です。

最後に実行した検査も成功しています。

- `formal/` で `lake build`：成功、警告なし。
- `formal/` で `lake build desugarDiff`：成功。
- `scripts/check.sh --base HEAD --dry-run`：10 ファイルに対して `formal` 検査だけを選択。
- `scripts/check.sh --base HEAD`：`all checks passed`。
- `git diff --check`：成功。
- `formal/Benitoite/`・`formal/DesugarDiff/` の検索：`sorry`・`native_decide` の字句なし。

## 3. 足した表層の構文・型付け・脱糖の定義（Lean の定義をそのまま引用する）と、規則を写すうえで選んだ形と理由

[Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean:82) の `Pattern` に、次の構成子を追加しました。

```lean
  | range (lo hi : Release.Const)
  | list (before : List Pattern) (rest : Option Release.ListRest) (after : List Pattern)
```

`Pattern.toCore` の追加部分です。

```lean
    | .range lo hi => .range lo hi
    | .list before rest after => .list (Pattern.toCoreList before) rest (Pattern.toCoreList after)
```

範囲の両端には `Release.Const` を使いました。負の整数をそのまま表せ、コアへ移す際に別の定数型を変換する必要がないためです。両端の種類の一致と、範囲の型が `Integer` または `Character` であることは、`Release.PatTy` の `P_RangeInt`・`P_RangeChar` が検査します。

大小とリストの形は、表層側の次の述語で検査します。これは分岐の選択肢とパターン束縛の型付けの前提です。

```lean
mutual
  def Pattern.Valid : Pattern → Prop
    | .range (.integer lo) (.integer hi) => lo ≤ hi
    | .range (.character lo) (.character hi) => lo.toNat ≤ hi.toNat
    | .con _ _ ps | .record _ _ _ ps => Pattern.ValidList ps
    | .list before rest after =>
        Pattern.ValidList before ∧ Pattern.ValidList after ∧ (rest = none → after = [])
    | _ => True

  def Pattern.ValidList : List Pattern → Prop
    | [] => True
    | p :: ps => p.Valid ∧ Pattern.ValidList ps
end
```

条件は入れ子の構成子・レコード・リストにも課します。`Character` の大小は、`Release.Const.inRange` と同じ `toNat` の比較です。

リストは構文として `before`・`rest`・`after` を持たせ、残りなしで `after` が空でない形を型付けで除きます。`Release.P_List` と同じ表現を使い、脱糖で形を組み替えずに済むためです。残りは `none`・`some .skip`・`some .bind` の三通りで、束縛順は **前の要素・残り・後の要素**です。

選択肢の定義です。

```lean
structure Alternative where
  pat : Pattern
  slots : List Nat

def Alternative.toCore (alt : Alternative) : Release.Alt := ⟨alt.pat.toCore, alt.slots⟩

def Alternative.toCoreList (alts : List Alternative) : List Release.Alt := alts.map Alternative.toCore

def Alternative.Valid (alts : List Alternative) : Prop := ∀ alt ∈ alts, alt.pat.Valid
```

分岐の定義と、単一選択肢の短縮形です。

```lean
  inductive Arms where
    | nil
    | cons (alts : List Alternative) (guard : Option Expr) (body : Block) (rest : Arms)
```

```lean
def Arms.single (pat : Pattern) (body : Block) (rest : Arms) : Arms :=
  .cons [⟨pat, List.range pat.binders⟩] none body rest
```

`slots` は分岐の変数ごとに使う束縛位置であり、脱糖でそのままコアへ移します。空でないこと、最初の対応の恒等性、各対応の順列性、並べ替え後の束縛型の一致は `Release.AltsTy` に任せています。本体とガードは、最初の選択肢の束縛順による環境を使います。

網羅性に使う関数と、「必ず抜ける」の定義です。

```lean
def Arms.unguardedPatterns : Arms → List Release.Pat
  | .nil => []
  | .cons alts none _ rest => (Alternative.toCoreList alts).map Release.Alt.pat ++ rest.unguardedPatterns
  | .cons _ (some _) _ rest => rest.unguardedPatterns
```

```lean
  def Arms.Exits : Arms → Prop
    | .nil => True
    | .cons _ _ body rest => body.Exits ∧ rest.Exits
```

ガード付きの分岐は網羅性に数えず、ガードなしの分岐はすべての選択肢を数えます。`Arms.Exits` は本体だけを見ます。

[Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean:358) の `HasArms` は次の形です。

```lean
  inductive HasArms (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Position → Arms → Ty → Ty → Eff → Prop
    -- 空の分岐でも結果型の WF を要求する（Release.HasTypeXArms.nil）。
    | nil {C Γ R p a b} : Ty.WF C.length b →
        HasArms D B opPrim C Γ R p .nil a b Eff.empty
    | plain {C Γ R p alts body rest a b ε εs δ} :
        Alternative.Valid alts → AltsTy D.patternProgram (Alternative.toCoreList alts) a δ →
        HasBlock D B opPrim C (binds δ ++ Γ) R p body b ε →
        HasArms D B opPrim C Γ R p rest a b εs →
        HasArms D B opPrim C Γ R p (.cons alts none body rest) a b (Eff.union ε εs)
    | guarded {C Γ R p alts guard body rest a b ε εs δ} :
        Alternative.Valid alts → AltsTy D.patternProgram (Alternative.toCoreList alts) a δ →
        HasType D B opPrim C (hideConts (binds δ ++ Γ)) none .other guard (.base .boolean) Eff.empty →
        HasBlock D B opPrim C (binds δ ++ Γ) R p body b ε →
        HasArms D B opPrim C Γ R p rest a b εs →
        HasArms D B opPrim C Γ R p (.cons alts (some guard) body rest) a b (Eff.union ε εs)
```

ガードは既存の `HasType` で検査し、構文ごとの新しい禁止一覧は作りませんでした。環境の `hideConts` が外側の継続を隠し、`R = none` がその判断での `return`・`try` を拒否します。位置は `.other`、型は `Boolean`、エフェクトは空です。これは指定された P12 と `Release.HasTypeXArms.guarded` の形に対応します。

`E_Match` の現在の規則です。

```lean
    | E_Match {C Γ R p e arms a b εe εarms} :
        arms ≠ .nil →
        HasType D B opPrim C Γ R .other e a εe →
        HasArms D B opPrim C Γ R p arms a b εarms →
        Exhaustive D.patternProgram a arms.unguardedPatterns →
        HasType D B opPrim C Γ R p (.matchE b e arms) b (Eff.union εe εarms)
```

パターン束縛にも `pat.Valid` を加えました。

```lean
    | B_LastPat {C Γ R p k pat t e ε δ} :
        pat.Nontrivial → pat.Valid → PatTy D.patternProgram pat.toCore t δ →
        Exhaustive D.patternProgram t [pat.toCore] →
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C Γ R p (.lastPat k pat t e) (.base .unit) ε
```

```lean
    | B_BindPat {C Γ R p k pat t e rest a ε εs δ} :
        pat.Nontrivial → pat.Valid → PatTy D.patternProgram pat.toCore t δ →
        Exhaustive D.patternProgram t [pat.toCore] →
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C (binds δ ++ Γ) R p rest a εs →
        HasBlock D B opPrim C Γ R p (.bindPat k pat t e rest) a (Eff.union ε εs)
```

**言語との既知の差は残しています。** `Exhaustive` は値の形についての網羅性なので、全 `Character` を覆う範囲は、表層では束縛の左辺にも型が付けられます。01-05 は範囲を「必ず照合する」パターンに数えません。指定どおり、この検査手順の制限は追加せず、広い表層について性質 1 を証明しています。選ばれない分岐の検査も追加していません。

[Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean:330) の分岐の脱糖です。

```lean
  def desugarArms (opPrim : OpPrim) (p : Position) : Arms → List Arm
    | .nil => []
    | .cons alts none body rest =>
        .mk (Alternative.toCoreList alts) none
          ((desugarBlock opPrim p body).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))) ::
          desugarArms opPrim p rest
    | .cons alts (some guard) body rest =>
        .mk (Alternative.toCoreList alts)
          (some ((desugarExpr opPrim .other guard).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))))
          ((desugarBlock opPrim p body).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))) ::
          desugarArms opPrim p rest
```

`Option Expr` は `none`・`some guard` で場合を分け、構造的再帰を保っています。ガードは `.other` で脱糖し、照合対象の `let` のための付け替えは、ガードと本体の両方で最初の選択肢の束縛を保護します。脱糖の文脈に R や `hideConts` は追加していません。

[WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean:94) の範囲条件です。

```lean
  def Arms.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Arms → Prop
    | .nil => True
    | .cons alts none body rest =>
        body.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧ rest.Scoped nt pe nv
    | .cons alts (some guard) body rest =>
        guard.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧
          body.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧ rest.Scoped nt pe nv
```

選択肢には型注釈や自由変数がなく、`slots` の範囲は `AltsTy` が検査します。ガードと本体の局所変数の範囲は `Arm.bindersOf` を使って定めます。

交換形式の読み込みは、次の最小限の変更です。

```lean
  partial def toArms (constants : List (String × Benitoite.Surface.Expr) := []) : List Arm → Except String Benitoite.Surface.Arms
    | [] => return .nil
    | .mk p b :: as => return .single (← p.toSurface) (← b.toSurface constants) (← toArms constants as)
```

## 4. 証明の構成（足した主な補題と役割）。残った `sorry` があれば、その場所と場合

主な補題は [Lemmas/Patterns.lean](../../../../../formal/Benitoite/Surface/Lemmas/Patterns.lean:64) に置きました。

| 補題 | 役割 |
|---|---|
| `HasArms.single` | 単一パターンの型付けから、恒等対応・ガードなしの短縮形の型付けを作る |
| `AltsTy.consCongr` | 構成子の表が等しいプログラム間で、選択肢の型付けを移す |
| `AltsTy.clean` | `AltsTy.witness`、`PatTy.clean`、`selectSlots_mem` から、並べ替え後の束縛型も継続型を含まないことを示す |
| `HasTypeC.shiftAlts` | 本体について、最初の選択肢の束縛を保護して照合対象の `let` を挿入する |
| `HasTypeC.shiftGuard` | ガードについて、継続を隠した環境間で同じ付け替えを行う |
| `desugarArms_patterns` | `unguardedPats (desugarArms op pos arms) = arms.unguardedPatterns` を示す |

`HasTypeC.shiftGuard` には、既存の `RenOk.hide` を使いました。したがって、予想されていた `hideConts` と束縛環境を交換する等式の補題は新しく作っていません。

[HasArms.desugar](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:475) は、`plain`・`guarded` の各場合をコアの同名の規則へ移します。ガードは空のエフェクトの判断を維持し、本体と後続分岐だけを表層のエフェクトの和へ広げます。[HasArms.desugar_scoped](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean:225) にもガードの範囲条件の証明を加えました。

この変更により、既存のプログラム全体の証明を通じて、`Benitoite.Surface.desugar_typed` と `Benitoite.Surface.surface_effect_soundness` が拡張した表層にも成り立ちます。**残った `sorry` はありません。**

新しい例は 16 件です。偽のガードで同じ分岐の残りの選択肢を飛ばして `99` を返す例と、`B(y, x)` が `[1, 0]` によって `x = 20` を返す例は、脱糖した計算を `Release.run` で実行して確認しています。範囲とリストの例には型付けと脱糖の期待値を置き、外側の継続の禁止は、隠した環境のその番号に継続型が存在しない補題で示しました。すべて `rfl`・`decide` 等の通常の証明であり、`native_decide` は使っていません。

## 5. `Release` の定義と、既存の表層の型付けの規則を変えた箇所と理由（なければ「なし」）

**`Release` の定義の変更は、なし。** `Release` の補題にも変更を加えていません。`Benitoite.Core`、六定理の言明と前提、組み込みの `Assumptions` も変更していません。

既存の表層の型付けの変更は、次の三点です。

1. `HasArms.cons` を `plain`・`guarded` に置き換えました。単一の `PatTy` から選択肢列の `AltsTy` に広げ、ガードの判断をコアと対応させるためです。
2. `E_Match` の網羅性の対象を `arms.patterns` から `arms.unguardedPatterns` に替えました。ガード付き分岐を除き、ガードなしの全選択肢を数えるためです。
3. `B_LastPat`・`B_BindPat` に `pat.Valid` を加えました。新しい範囲の大小とリストの形の条件を、束縛の左辺でも検査するためです。

交換形式の定義と処理系の書き出しは変更していません。`docs/`、AGENTS.md、`formal/README.md`、`formal/reviews/`、`crates/`、`scripts/` にも変更はありません。

## 6. C7c で難しくなりそうな箇所の見込み

難しくなりそうなのは、**処理系の `VarId` と Lean の束縛位置を対応させる部分**です。

- 同じ分岐を指す連続した行をまとめ、選択肢の順を保つ必要があります。ガードが偽になったときに、同じ分岐の残りの行を再試行する形に変わらないことも確認が必要です。
- `slots` は、各選択肢のパターンを Lean の照合順に辿って得た `VarId` の位置から求める必要があります。レコードは宣言順、リストは前・残り・後の順です。参照インタプリタの束縛の記録順をそのまま位置番号にすると、リストの残りと後の要素で食い違う可能性があります。
- 最初の選択肢の `slots` を恒等にするため、分岐の変数の基準順と、ガード・本体の de Bruijn 番号を揃える必要があります。`MatchArm.vars` の順をそのまま使えるかは、最初のパターンの正規化後の順と突き合わせて決める必要があります。
- ガードと本体は同じ分岐の環境で読み込み、照合対象の `let` による外側の変数のずれも比較する必要があります。今回の `c7Guard_outer_row` は、パターンの変数を保ち、外側の変数だけをずらす例です。
- 範囲の両端は符号付きの整数・文字の定数として、リストの残りは三通りを区別して交換形式へ足す必要があります。
- TODO-190 が完了するまでは、ガード内で外側の継続を `resume` する関数を既知の差として扱う必要があります。今回の表層の型付けは、その継続を隠します。