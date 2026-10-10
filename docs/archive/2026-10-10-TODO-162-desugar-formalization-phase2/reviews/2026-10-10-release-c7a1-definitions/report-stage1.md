**段①（構文・範囲の条件・置換と構造の補題）まで実装し、ビルドが通る状態で止めました。C7a-1 全体は未完了です。** ガード内の `resume` を処理系に合わせて許すと、指定された `R = none` と既存の継続の場所の型付けが衝突し、値置換の型保存をそのまま拡張できないことを確認しました。②〜④には進んでいません。

`formal/` で `lake build` と `lake build desugarDiff` は成功しました。六つの定理の公理に `sorryAx` はありません。コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

変更したファイルは次の 11 個です。行数は差分の追加・削除で、合計 **追加 210 行・削除 12 行**です。新規ファイルは残していません。

| ファイル（`formal/Benitoite/` 以下） | 追加 | 削除 | 内容 |
|---|---:|---:|---|
| [Release/Syntax.lean](../../../../../formal/Benitoite/Release/Syntax.lean:153) | 36 | 0 | 範囲・リスト、選択肢の対応、`matchX`、相互帰納型 `Arm` |
| [Release/Subst.lean](../../../../../formal/Benitoite/Release/Subst.lean:14) | 49 | 12 | 束縛数、型・名前・値の置換 |
| [Release/WellFormed.lean](../../../../../formal/Benitoite/Release/WellFormed.lean:77) | 7 | 0 | `matchX` と分岐の範囲の条件 |
| [Release/Lemmas/Closed.lean](../../../../../formal/Benitoite/Release/Lemmas/Closed.lean:189) | 57 | 0 | 型置換・単調性・名前の付け替え・値置換が範囲を保つ補題 |
| [Release/Lemmas/SubstTyping.lean](../../../../../formal/Benitoite/Release/Lemmas/SubstTyping.lean:50) | 8 | 0 | `matchX` と分岐の恒等の名前付け替え |
| [Release/Lemmas/PresBase.lean](../../../../../formal/Benitoite/Release/Lemmas/PresBase.lean:64) | 13 | 0 | エフェクト変数の範囲の条件を外す補題の新しい場合 |
| [Surface/Lemmas/ScopedRename.lean](../../../../../formal/Benitoite/Surface/Lemmas/ScopedRename.lean:87) | 15 | 0 | 任意の範囲の条件で名前の付け替えを保つ補題 |
| [Release/Semantics.lean](../../../../../formal/Benitoite/Release/Semantics.lean) | 2 | 0 | 段①の中断地点として、`step` の `matchX` の場合を追加 |
| [Release/Lemmas/Progress.lean](../../../../../formal/Benitoite/Release/Lemmas/Progress.lean:412) | 19 | 0 | 型付け未追加の `matchX` を除外する一時的な補題と場合 |
| [Release/Lemmas/StepSound.lean](../../../../../formal/Benitoite/Release/Lemmas/StepSound.lean:266) | 1 | 0 | `step` の一時的な場合に対応する証明 |
| [Exchange/Convert.lean](../../../../../formal/Benitoite/Exchange/Convert.lean:130) | 3 | 0 | 範囲・リスト・`matchX` を対象外として `throw` |

検証に使った Lean・Benitoite の一時ファイル、公理検査の一時ファイル、ビルドログは、すべて `formal/` 内に作り、最後に削除しました。

## 2. 足した構文の表し方と、処理系のコア IR との対応

パターンには次を追加しました。

```lean
Pat.range (lo hi : Const)
Pat.list (before : List Pat) (rest : Option ListRest) (after : List Pat)
```

リストの残りは三つを区別します。

| 表現 | 意味 |
|---|---|
| `none` | 残りの部分を許さない |
| `some .skip` | 残りの部分を許すが、束縛しない |
| `some .bind` | 残りのリストを一つの変数に束縛する |

これは処理系の `CorePat::List` の残りの有無と、残りの変数の有無に対応します。`Pat.binders` は、**前の要素・残りの変数・後の要素**の順に束縛数を数えます。

拡張した分岐は、`Val`・`Comp`・`Clause` と同じ相互帰納の中に独立した型として追加しました。

```lean
structure Alt where
  pat : Pat
  slots : List Nat

inductive Arm where
  | mk (alts : List Alt) (guard : Option Comp) (body : Comp)

Comp.matchX (v : Val) (arms : List Arm)
```

`Alt.slots` は、分岐の各変数について、選択肢の何番目の束縛を使うかを指定します。例えば、分岐の変数の順が `[x, y]` なら、`A(x, y)` の対応は `[0, 1]`、`B(y, x)` の対応は `[1, 0]` です。`Pat.var` は変更していません。

分岐の束縛数は、最初の選択肢のパターンから得ます。処理系の、最初の選択肢の左から現れる順で分岐の変数を作る方法に対応します。ただし、**対応の範囲・全単射性・最初の対応が恒等であることを検査する型付けは、まだ追加していません**。

処理系の `MatchRow` を分岐ごとにまとめたものが `Arm.alts`、`MatchArm` のガードと本体が `Arm.guard`・`Arm.body` に対応します。既存の `Comp.match` は残しています。

## 3. 足した意味の規則と、仕様との対応

**照合と遷移の拡張は未実装です。** 範囲・リストの照合、選択肢の順次照合と束縛の並べ替え、ガードの枠、偽のときの再開は追加していません。したがって、案 (a)・(b) もまだ選んでいません。

現在の `step` の `matchX` の場合は、段①をビルド可能にするための一時的な定義として `none` を返します。型付け規則も未追加なので、`Progress` では型の付いた計算が `matchX` ではないことを証明して、この場合を除外しています。この一時的な補題は③で通常の逆転補題に置き換える必要があります。

01-05・02-06 に対応する構文と束縛の順は表せましたが、意味の対応を実装で確かめる作業は残っています。01-12 の写しは変更していません。

ガード内の `resume` については、処理系が受理することを確認しました。根拠と、Lean 側で止まった点は第 6 項に記します。

## 4. 足した型付けの規則と網羅性、継続の型付け

**新しい型付け規則・網羅性の写像・ガードの継続の型付けは未実装です。** `Typing.lean` と `ContTy` は変更していません。

このため、次の作業が残っています。

- 範囲・リストの `PatTy`。
- 選択肢の対応で束縛の型を並べ替える判断。
- ガードと本体の型付け。
- ガードのない分岐の選択肢だけを `Exhaustive` に写す定義。
- ガードの枠と、再開する状態の型付け。
- これらに対応する、型付けに関する構造の補題の新しい場合。

今回追加したのは、構文上の名前・値・型の置換と、それらが範囲の条件を保つ補題です。新しい型付け規則を追加した後の、一般の値置換の型保存には、次の障害があります。

## 5. `sorry` の一覧と、公理検査の出力

**`sorry` は追加していません。** `Release` と `Surface` 内の検索でも `sorry` はありませんでした。

`lake env lean` による公理検査の出力は次のとおりです。

```text
'Benitoite.Release.progress' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.preservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Release.step_sound' depends on axioms: [propext, Quot.sound]
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

これは段①の状態での結果です。未実装のパターンの照合・ガードの遷移の健全性を証明したものではありません。

検査結果は次のとおりです。

- `formal/` で `lake build`：成功。
- `formal/` で `lake build desugarDiff`：成功。
- `git diff --check`：成功。
- `scripts/check.sh --base HEAD --dry-run`：今回の 11 ファイルについて `formal` 検査だけを選択。

## 6. 仕様が決めきっていない点と、処理系に合わせた判断

**ガードから継続の変数を隠すことはできません。** 既存の `target/debug/benitoite check` は、次の例を診断なし・終了状態 0 で受理しました。

```text
effect Ask
  function ask() -> Boolean
end effect

function guarded() -> Boolean
  return handle ask() with
    case ask() -> match true with
      case true if resume(true) -> true
      case _ -> false
    end match
  end handle
end function

function main() -> Unit
  bind result <- guarded()
  return ()
end function
```

ソース上も、[ガードの検査](../../../../../crates/benitoite/src/typeck/pattern_ext.rs:162)は `expr_in(..., None)` により戻り値の文脈を外しますが、[expr_in](../../../../../crates/benitoite/src/typeck/context.rs:110) は節の情報を外しません。[resume の検査](../../../../../crates/benitoite/src/typeck/effects/mod.rs:57)は、その節の情報を使います。

Lean 側の障害は、**ガードで `escape` を禁じるための R と、継続の場所に記録した R が、同じ添字として扱われていること**です。

一時的な Lean ファイルで、次の三つを `sorry` なしで証明しました。`Boolean` を `T`、空のエフェクトを `∅` とします。

1. 環境が `[k : Cont(T → T ! ∅)]` なら、`resume k true` は **R が `none` のガードとして**型が付く。
2. `Ψ(0) = cont(T, T, ∅, some T)` のもとで、`k` を `.loc 0` に置き換える置換は、**元の R が `some T` の `SubstOk`** を満たす。
3. 置換後の `resume (.loc 0) true` は、**R が `none` のガードとしては型が付かない**。

第三の事実は、既存の `C_ResumeL` が、場所に記録した R と現在の R の一致を要求するためです。三つの補題の公理は、いずれも `[propext, Quot.sound]` だけでした。

したがって、指定されたガードの判断をそのまま追加しても、`HasTypeC.subst` の新しい場合は証明できません。ガードを `hideConts` で検査すると上の受理例を除外し、ガードを元の R で検査すると `escape` を禁じる条件を別に表す必要があります。どちらも独断では採用していません。`Assumptions` も増やしていません。

## 7. 後半・C7b・差分テストの見込みと、案 (ii)・(i) の比較

続行には、**`escape` を許すかどうかと、継続の場所に記録する元の R を、型付けで区別する表現**を決める必要があります。この区別は、一般の値置換の補題とガードの枠の型付けの両方に関係します。単に照合・保存の新しい場合を C7a-2 の `sorry` に回すだけでは解決せず、C7a-1 で証明する構造の補題の前提に関わります。

その後の見込みは次のとおりです。

- **C7a-2**：ガードが偽になった後にも、再開位置以降にガードのない照合可能な分岐が残ることと、選択肢の対応による並べ替えが値の型を保つことが主要な補題になります。
- **C7b**：選択肢の変数名から `Alt.slots` を作り、最初の対応が恒等であることと、後の対応が束縛の型を保つことを証明する必要があります。ガード内の `resume` を除外せずに表層の性質 1 を保つには、上の R の問題を先に解く必要があります。
- **差分テスト**：連続する行を分岐ごとにまとめ、処理系の `VarId` の対応を `slots` に正規化する必要があります。今回の変更は指定どおり、対象外として `throw` する場合の追加だけです。

定義を書いて確認できた範囲では、案 (ii) は、分岐ごとに本体とガードを一つだけ持ち、選択肢ごとの束縛順の違いも独立した対応として表せます。一方、ガードの計算中に通常の戻り値の文脈を外すことと、外側の継続を再開できることの両立には、既存の型付けの表現を見直す必要がありました。

この問題は、案 (a)・(b) の再開位置の網羅性とは別の問題です。案 (i) に移した場合については今回実装しておらず、ガードを既存の構成へ展開すればこの障害を解消できる、とは確認していません。