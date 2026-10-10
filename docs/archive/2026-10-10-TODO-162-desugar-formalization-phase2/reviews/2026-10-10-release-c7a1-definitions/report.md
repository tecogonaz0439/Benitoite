**C7a-1 の段②〜④を実装しました。** 段①の一時的な `step` と進行の補題を置き換え、照合・実行規則・型付け・構造の補題・実行例を追加しました。

`formal/` で **`lake build` と `lake build desugarDiff` が成功**しました。`Benitoite.Surface.desugar_typed` の公理に `sorryAx` はありません。残る `sorry` は、指定された照合・進行・保存の新しい場合だけです。コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

以下はコミット `1afd008` からの今回の差分です。**18 ファイル、追加 594 行・削除 27 行、正味 567 行増**です。新規ファイルは残していません。

| ファイル（`formal/Benitoite/` 以下） | 追加 | 削除 | 内容 |
|---|---:|---:|---|
| [Release/Subst.lean](../../../../../formal/Benitoite/Release/Subst.lean) | 68 | 1 | 範囲・リストの照合、束縛の並べ替え、選択肢の選択、網羅性への写像 |
| [Release/Typing.lean](../../../../../formal/Benitoite/Release/Typing.lean) | 47 | 0 | `PatTy`、`AltsTy`、`C_MatchX`、`HasTypeXArms` |
| [Release/Semantics.lean](../../../../../formal/Benitoite/Release/Semantics.lean) | 59 | 2 | 実行中の照合状態、ガードの枠、遷移、継続と状態の型付け |
| [Release/Examples.lean](../../../../../formal/Benitoite/Release/Examples.lean:248) | 65 | 0 | 新しい構成を実行する9個の例 |
| [Release/Lemmas/Canonical.lean](../../../../../formal/Benitoite/Release/Lemmas/Canonical.lean) | 5 | 0 | 照合の型保存と範囲の条件の新しい場合 |
| [Release/Lemmas/ContLemmas.lean](../../../../../formal/Benitoite/Release/Lemmas/ContLemmas.lean) | 29 | 0 | ガードの枠の逆転・ストアの拡大・継続の接続と分割など |
| [Release/Lemmas/Inversion.lean](../../../../../formal/Benitoite/Release/Lemmas/Inversion.lean) | 23 | 0 | `inv_matchX` と既存の逆転補題の新しい場合 |
| [Release/Lemmas/OuterC.lean](../../../../../formal/Benitoite/Release/Lemmas/OuterC.lean) | 16 | 0 | 型パラメータの外側への環境の拡張 |
| [Release/Lemmas/PresHelpers.lean](../../../../../formal/Benitoite/Release/Lemmas/PresHelpers.lean) | 13 | 0 | `StateTyE` と `stateTy_iff`、継続の R の正しさ |
| [Release/Lemmas/PresMain.lean](../../../../../formal/Benitoite/Release/Lemmas/PresMain.lean) | 8 | 0 | 保存の新しい8場合 |
| [Release/Lemmas/Progress.lean](../../../../../formal/Benitoite/Release/Lemmas/Progress.lean) | 17 | 21 | 一時補題の削除、ガードと実行中の照合の進行 |
| [Release/Lemmas/Regularity.lean](../../../../../formal/Benitoite/Release/Lemmas/Regularity.lean) | 37 | 0 | パターン・選択肢・分岐の型の正しさ |
| [Release/Lemmas/Rename.lean](../../../../../formal/Benitoite/Release/Lemmas/Rename.lean) | 42 | 0 | 束縛数、名前の付け替え、ストアの拡大 |
| [Release/Lemmas/StepSound.lean](../../../../../formal/Benitoite/Release/Lemmas/StepSound.lean) | 47 | 3 | `step_sound` の新しい場合の証明 |
| [Release/Lemmas/SubstTyping.lean](../../../../../formal/Benitoite/Release/Lemmas/SubstTyping.lean) | 28 | 0 | 値の置換の型保存 |
| [Release/Lemmas/TySubstMain.lean](../../../../../formal/Benitoite/Release/Lemmas/TySubstMain.lean) | 69 | 0 | パターン・選択肢・分岐の型置換 |
| [Surface/Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 18 | 0 | `PatTy.clean` の新しい場合 |
| [Surface/Lemmas/Patterns.lean](../../../../../formal/Benitoite/Surface/Lemmas/Patterns.lean) | 3 | 0 | `PatTy.consCongr` の新しい場合 |

実行例の追加は 65 行です。それ以外の定義と証明は、追加 529 行・削除 27 行です。既存の例は削除していません。

検証結果は次のとおりです。

- 段②・段③・段④の終わりの `lake build`：成功。
- 最終状態の `lake build`、`lake build desugarDiff`：成功。
- `git diff --check`：成功。
- `scripts/check.sh --base HEAD --dry-run`：変更した18ファイルについて `formal` 検査だけを選択。
- 公理検査の一時ファイル：`formal/` 内に作り、検査後に削除。

## 2. 足した構文の表し方と、処理系のコア IR との対応

段①で追加された構文をそのまま使い、今回、その意味と型付けを実装しました。

```lean
Pat.range (lo hi : Const)
Pat.list (before : List Pat) (rest : Option ListRest) (after : List Pat)

Alt.pat   : Pat
Alt.slots : List Nat

Arm.mk (alts : List Alt) (guard : Option Comp) (body : Comp)
Comp.matchX (v : Val) (arms : List Arm)
```

リストの残りは、`none` が残りなし、`some .skip` が残りを許すが束縛しない場合、`some .bind` が残りのリストを束縛する場合です。束縛の順は **前の要素・残りの変数・後の要素**です。

`Alt.slots` は、分岐の変数ごとに、その選択肢の何番目の束縛を使うかを表します。例えば、分岐の変数が `[x, y]` なら、`A(x, y)` は `[0, 1]`、`B(y, x)` は `[1, 0]` です。今回追加した `AltsTy` が、最初の対応の恒等性と、各対応の順列としての正しさを検査します。

処理系では、選択肢ごとの `MatchRow` が同じ `MatchArm` を参照します。Lean では、その連続した行を `Arm.alts` にまとめ、ガードと本体を分岐ごとに一つ持ちます。`VarId` による束縛の対応を、Lean では位置の並び `slots` で表しています。

既存の `Comp.match` は維持しています。

## 3. 足した意味の規則と、01-05・01-12・02-06 との対応

範囲の照合は、同じ種類の `Integer` または `Character` の定数について、両端を含む比較で定めました。リストの照合は、残りがなければ長さの一致、残りがあれば必要な長さ以上であることを要求します。前と後の要素を照合し、残りを束縛する場合は、その間の部分を `Val.list` として束縛します。

`matchX` の実行は次の手順です。

1. `E_MatchXStart` で、分岐全体と位置 `0` を持つ `State.matchRun` に移る。
2. 現在の分岐の選択肢を `firstAlt` で左から調べる。
3. 照合した束縛を `selectSlots` で分岐の変数の順に並べ替える。
4. ガードがなければ、束縛を置換した本体を実行する。
5. ガードがあれば、`Frame.guardF` に分岐全体・次の分岐の位置・置換済みの本体を保存し、ガードを実行する。
6. ガードが真なら本体へ、偽なら保存した位置の `matchRun` へ移る。

これにより、ガードが偽のときは、**同じ分岐の残りの選択肢を試さず、次の分岐へ進みます**。01-05 の意味と、02-06・参照インタプリタの手順に対応します。実行時エラーと終了の状態がガードの枠を通る規則も追加しました。

再開先の表現には **案 (a)** を採りました。

```lean
State.matchRun v arms next k σ
Frame.guardF v arms next body
```

状態の型付けは、残りの分岐だけでなく、**分岐全体の `matchX` の型付けと網羅性を保持**します。加えて `MatchPrefix` は、再開位置より前に、ガードのない照合可能な分岐がないことを要求します。

ここでは、ガード付き分岐の偽という評価履歴を型付けに記録せず、網羅性に必要な部分だけを不変条件にしました。ガード付き分岐を飛ばす条件は遷移規則で定め、型付けでは、網羅性の根拠になるガードのない分岐を飛ばしていないことを保持します。この表現なら、残りの分岐に通常の `C_MatchX` の網羅性を要求する必要がありません。この不変条件から再開先の進行を導く証明は、C7a-2 に残しています。

ガードの環境には、P12 の決定どおり `hideConts` を適用しました。処理系が現在受理するガード内の `resume` との食い違いは、TODO-190 で修正する既知の差として扱っています。

追加した実行例は9個で、7個を `decide`、2個を `rfl` で確かめています。特にガードの偽の例は、最初の選択肢が `false`、後の選択肢が `true` を束縛する形にし、誤って同じ分岐の次の選択肢へ進む実装を検出できるようにしました。

## 4. 足した型付けの規則と網羅性、継続の型付け

`PatTy` に、整数範囲・文字範囲・リストの三つの場合を加えました。リストの前と後のパターンは、同じ要素型で検査し、残りを束縛するときだけ `List` の型を一つ加えます。

`AltsTy` は、次を要求します。

- 選択肢が空でないこと。
- 分岐の変数の個数が、最初のパターンの束縛数と一致すること。
- 最初の選択肢の `slots` が恒等であること。
- 各選択肢に `PatTy` が付き、`slots` がその束縛位置の順列であること。
- 各選択肢の束縛の型を並べ替えると、分岐の変数の型の並びと一致すること。

`HasTypeXArms.guarded` のガードと本体は、次の判断で検査します。

```text
ガード:
  hideConts (binds δ ++ Γ); none ⊢ guard : Boolean ! Eff.empty

本体:
  binds δ ++ Γ; R ⊢ body : b ! ε
```

この形にしたことで、ガードの値置換には、持ち上げた置換に対する既存の `SubstOk.hide none` を使えます。段①で報告された R の不一致を避け、値置換の型保存の新しい場合を `sorry` なしで証明しました。

網羅性には `unguardedPats` を使います。ガード付き分岐を除き、ガードのない分岐の各選択肢を別々のパターンとして、既存の `Exhaustive` に渡します。`Inhabits` は変更していません。01-05 の検査手順にある、範囲を整数・文字の網羅とみなさない制限と、選ばれない分岐の検査は追加していません。

継続には `K_Guard` を加えました。入力は **`R = none`・空のエフェクト・`Boolean`** とし、本体と再開先では元の R と許容エフェクトに戻します。`ContTy.inv_guard`、ストアの拡大、継続の接続・分割などの新しい場合も証明済みです。

名前・値・型の置換、型の正しさ、逆転、Surface 側の `PatTy.clean`・`PatTy.consCongr` の新しい場合には、`sorry` を使っていません。

## 5. `sorry` の一覧と、公理検査の出力

残る `sorry` は **14箇所**です。

| 場所 | 新しい場合 | 個数 |
|---|---|---:|
| [Canonical.lean:215](../../../../../formal/Benitoite/Release/Lemmas/Canonical.lean:215) | `PatTy.match_typed` の `P_RangeInt`・`P_RangeChar`・`P_List` | 3 |
| [Canonical.lean:274](../../../../../formal/Benitoite/Release/Lemmas/Canonical.lean:274) | `Pat.matchVal_closed` の範囲・リスト | 2 |
| [Progress.lean:467](../../../../../formal/Benitoite/Release/Lemmas/Progress.lean:467) | `progressE` の `matchRun` | 1 |
| [PresMain.lean:145](../../../../../formal/Benitoite/Release/Lemmas/PresMain.lean:145) | `E_MatchXStart`・`E_MatchXSkip`・`E_MatchXBody`・`E_MatchXGuard`・`E_GuardT`・`E_GuardF`・`E_ErrPopGuard`・`E_ExitPopGuard` | 8 |

`StepSound` と `ContLemmas` に `sorry` は残っていません。Release の四つの定理の言明は変更していません。

六つの定理の `#print axioms` の出力は次のとおりです。

```text
'Benitoite.Release.progress' depends on axioms: [propext, sorryAx, Classical.choice, Quot.sound]
'Benitoite.Release.preservation' depends on axioms: [propext, sorryAx, Classical.choice, Quot.sound]
'Benitoite.Release.effect_soundness' depends on axioms: [propext, sorryAx, Classical.choice, Quot.sound]
'Benitoite.Release.step_sound' depends on axioms: [propext, Quot.sound]
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, sorryAx, Classical.choice, Quot.sound]
```

したがって、性質1の `desugar_typed` は、今回残した段階 B の未証明部分に依存していません。

## 6. 01-05 などが決めきっていない点と、処理系に合わせた判断

今回、新たに言語仕様の判断を必要とする点は見つかりませんでした。ガード内の `resume` は、処理系の現在の受理範囲よりも、**設計者が決めた P12 の規則**を採っています。

範囲の下端が上端より大きいことを拒否する前提は、依頼で省略が認められていたため、`PatTy` に入れていません。その範囲は、照合でどの値にも一致しません。01-05 のソース言語の検査は、それより厳しいままです。

`Assumptions` は増やしていません。範囲は定数を比較し、リストは `Val.list` を直接調べるので、照合のための組み込み関数の仮定は不要でした。

差分テストの `Exchange/Convert.lean` は、段①ですでに新しい構成を対象外として拒否しており、今回は追加変更が不要でした。

## 7. C7a-2・C7b・差分テストの見込みと、案 (ii)・案 (i) の比較

C7a-2 の中心は、次の証明です。

- リストの照合が返す前・残り・後の値について、型、束縛数、範囲の条件を保つこと。
- 型の付いた選択肢では、`slots` による並べ替えが成功し、値の型を保つこと。
- 分岐全体の網羅性と `MatchPrefix` から、再開位置以降にガードのない照合可能な分岐が残ること。
- 分岐を飛ばす遷移とガードの偽の遷移で、`MatchPrefix` を保つこと。
- 選択したガードと本体への束縛の置換から、`K_Guard` と遷移先の型付けを組み立てること。

ガードの枠の逆転、継続の接続・分割、`step_sound` の新しい場合は証明済みなので、それらは後半に残っていません。

C7b では、表層の変数名から `slots` を作り、最初の対応が恒等で、後の対応が順列となり、並べ替え後の型が一致することを示す必要があります。ガードには、分岐の変数を加えた後の環境全体を隠す対応が必要です。処理系側では、TODO-190 の修正までガード内の `resume` が既知の差になります。

差分テストでは、処理系の連続した行を分岐ごとにまとめ、各行の `VarId` を束縛位置の `slots` に正規化する作業が残ります。リストの束縛も、Lean の「前・残り・後」の順に対応させる必要があります。

今回定義を書いて確認できた案 (ii) の利点は、**本体とガードを分岐ごとに一つ保持したまま、選択肢ごとの束縛順の違いと、ガードが偽のときの移動を直接表せること**です。再開位置を持つ実行状態を追加すれば、分岐全体の網羅性も保持できます。一方、その状態とガードの枠を加えるため、継続・進行・保存の証明に新しい場合が必要になります。

案 (i) は今回実装していません。比較資料が挙げる残りの分岐の複製や組み込み関数への展開を避け、処理系のコア IR に近い形で定義できたことは確認できました。案 (ii) の正式な採用判断は、予定どおり定義のレビューに委ねます。