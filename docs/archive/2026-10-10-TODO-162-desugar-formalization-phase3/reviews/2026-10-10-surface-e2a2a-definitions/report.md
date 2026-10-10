E2a-2a の実装を完了した。指定の三つのビルドと130件の例が通り、既存の主要11定理の公理は作業前と一致した。写しの等式と網羅性の包みは証明済みで、`sorryAx` に依存しない。直接の `sorry` は、許可された範囲に9件残している。

## 1. 変えたファイル・作ったファイルと行数

| ファイル | 変更 | 行数 |
|---|---|---:|
| [CheckTools.lean](../../../../../formal/Benitoite/Surface/CheckTools.lean) | 新規。原子集合、エフェクト・型の比較、型操作の写し、組み込みの制約の判定契約 | 421 |
| [CheckPredicates.lean](../../../../../formal/Benitoite/Surface/CheckPredicates.lean) | 新規。表層の規則の前提の判定 | 351 |
| [CheckPatterns.lean](../../../../../formal/Benitoite/Surface/CheckPatterns.lean) | 新規。パターンの束縛型の計算と網羅性の包み | 154 |
| [CheckToolsExamples.lean](../../../../../formal/Benitoite/Surface/CheckToolsExamples.lean) | 新規。130件の例 | 224 |
| [Benitoite.lean](../../../../../formal/Benitoite.lean) | 上記4ファイルの import を追加 | 全31行、4行追加 |

`formal/` で次の検査がすべて通った。

- `lake build`
- `lake build desugarDiff`
- `lake build builtinCheck`
- 既存11定理と新しい71定理についての `#print axioms`
- `git diff --check`

既存11定理の公理は作業前と同じで、`propext`・`Classical.choice`・`Quot.sound` の範囲に収まっている。公理確認の一時ファイルは `formal/` 内に作り、最後に削除した。コミットは行っていない。指定どおり `scripts/check.sh` と `scripts/check-formal.sh` は実行していない。

## 2. 判定の道具の一覧

`AtomsIn` は `Benitoite.Release`、判定の関数と補題は `Benitoite.Surface.CheckTools` に置いた。以下の表の `A` は `List Atom` を表す。

| 名前 | 型・役割 | 言明と証明の状態 |
|---|---|---|
| `Eff.AtomsIn` | `A → Eff → Prop` | 指定の全称述語 |
| `Ty.AtomsIn`・`Tys.AtomsIn` | `A → Ty → Prop`、`A → List Ty → Prop` | 型と型リストについての相互に構造的な述語 |
| `effSub` | `A → Eff → Eff → Bool` | `effSub_sound`：小さい側の `AtomsIn` と成功から `Eff.Sub`。証明済み |
| `effEq` | `A → Eff → Eff → Bool` | `effEq_sound`：両側の `AtomsIn` と成功から等式。証明済み |
| `emptyEff` | `Eff` | `emptyEff_atoms`。証明済み |
| `singleEff` | `A → Atom → Eff` | 原子が `atoms.contains` を通る場合だけ作る。`singleEff_atoms`・名前の単一集合との `singleEff_eq` は証明済み |
| `unionEff` | `A → Eff → Eff → Eff` | `A` に切り詰めた和。`unionEff_atoms`、両入力の `AtomsIn` のもとでの `unionEff_eq` は証明済み |
| `tyConEq` | `TyCon → TyCon → Bool` | `tyConEq_sound`。証明済み |
| `tyEq`・`tysEq` | `A → Ty → Ty → Bool`、`A → List Ty → List Ty → Bool` | 両側の `AtomsIn` と成功から等式。`tyEq_sound`・`tysEq_sound` は証明済み |
| `tyLe` | `A → Ty → Ty → Bool` | 外側の関数型だけエフェクトの包含を許す。`tyLe_sound` は証明済み |
| `shiftTy`・`shiftTys` | `Nat → Nat → Ty/List Ty → Ty/List Ty` | `shiftTy_eq`・`shiftTys_eq` は証明済み |
| `substTyAt`・`substTysAt` | `Nat → List Ty → List Eff → Ty/List Ty → Ty/List Ty` | `substTyAt_eq`・`substTysAt_eq` は証明済み |
| `substTy` | `List Ty → List Eff → Ty → Ty` | 深さ0の置換。`substTy_eq` は証明済み |
| `applyToTy` | `Ty → List Ty → Ty` | `applyToTy_eq` は `rfl` で証明済み |
| `fnTyCheck` | `List Ty → Ty → Eff → List Ty → List Eff → Ty` | 評価用の関数型の具体化。`fnTyCheck_eq` は証明済み |
| `SatDec` | `List TParam → Ty → TParam → Bool` | 検査が受け取る判定の型 |
| `AdmitsDec` | `PrimName → List TParam → List Ty → Bool` | 検査が受け取る判定の型 |
| `SatDecSound`・`AdmitsDecSound` | `Builtins` と判定の関数との契約を表す `Prop` | 任意の `B` に対する明示的な前提。`Assumptions` には追加していない |
| `satAll` | `SatDec → List TParam → List Ty → List TParam → Bool` | `SatDecSound` と成功から `SatAll`。`satAll_sound` は証明済み |
| `patTy`・`patTys` | `Release.Program → Pat/List Pat → Ty/List Ty → Option (List Ty)` | `patTy_sound`・`patTys_sound` は `sorry` |
| `surfacePatTy` | `Declarations → Pattern → Ty → Option (List Ty)` | `toCore` 後の束縛型を求める。健全性の証明本体は記述済みだが、`patTy_sound` に依存 |
| `ConAtomsIn` | `A → Release.Program → Prop` | 宣言済みの構成子の全フィールド型に対する `AtomsIn` |
| `checkAlt`・`checkAlts` | 原子集合・プログラム・入力型・束縛型を受け取る `Bool` の判定 | `checkAlts_sound` は `sorry` |
| `altsTy` | `A → Release.Program → List Alt → Ty → Option (List Ty)` | 最初の選択肢から束縛型を計算する。`altsTy_sound` は `sorry` |

`shiftTy` と `substTyAt` は、型と型リストの相互に構造的な再帰で書いた。再帰呼び出しを `List.map`・`all`・`attach`・添字で取り出した型の上には置いていない。`applyToTy` は既存の `Ty.applyTo` と同じく、型の頭だけを見て引数を挿入するため、再帰を必要としない。

**直接の `sorry` は次の9件である。**

| ファイル | 定理 |
|---|---|
| `CheckTools.lean` | `substRho_atoms`、`shift_atoms`、`applyTo_atoms`、`substAt_atoms` |
| `CheckPatterns.lean` | `patTy_sound`、`patTys_sound`、`patTy_atoms`、`checkAlts_sound`、`altsTy_sound` |

次の10件は証明本体を記述したが、上記の未証明定理を通じて `sorryAx` に依存する。

- `subst_atoms`
- `shiftTy_atoms`・`shiftTys_atoms`
- `applyToTy_atoms`
- `substTyAt_atoms`・`substTysAt_atoms`・`substTy_atoms`
- `fnTyCheck_atoms`
- `stringAddOk_sound`
- `surfacePatTy_sound`

通常の `Eff.union` の原子集合の保存は `union_atoms` として証明済みである。

## 3. Prop の一覧と、規則ごとの使われ方

表層の型付けの74規則を確認した。`CheckPredicates.lean` の各判定には、元の述語との `↔` を証明した。`stringAddOk` だけは成功からの一方向の健全性で、その証明は原子集合の保存の未証明補題に依存する。

| 規則の前提 | 真偽値の版 | 使う規則 |
|---|---|---|
| `Ty.WF`・`Ty.WFList` | `wfTy`・`wfTys` | `E_List`、`E_ListSpread`、`E_ReturnOther`、`HasArms.nil`。`wfTys` は内部の補助 |
| `Expr.Exits`・`Block.Exits`・`Arms.Exits` | `exprExits`・`blockExits`・`armsExits` | `B_Seq` の否定、`E_Lam` の条件。相互に参照する三つを実装 |
| `body.Exits ∨ r = .base .unit` | `lamBodyOk` | `E_Lam`。定義全体の検査にも使える |
| `Pattern.Valid`・`Pattern.ValidList` | `patternValid`・`patternsValid` | `B_LastPat`、`B_BindPat`。入れ子のパターンも検査 |
| `Alternative.Valid` | `alternativesValid` | `HasArms.plain`、`HasArms.guarded` |
| `IsIf` | `isIf` | `E_ElseIf` |
| `Pattern.Nontrivial` | `nontrivial` | `B_LastPat`、`B_BindPat` |
| `Expr.PipeValue` | `pipeValue` | `E_PipeApply` |
| `∃ h, directCallee f = some h` | `isDirect` | `E_ListSpread`。成功時の具体的な `h` は `directCallee` から取り出す |
| `Exprs.AllDirect` | `allDirect` | `E_Interpolation` |
| `InterpPart.Allowed` | `interpAllowed`・補助の `convertedAllowed` | `E_Interpolation` |
| `∀ b t ε, a ≠ .cont b t ε` | `notCont` | `E_Local` |
| 値引数の先頭が辞書型でないこと | `headNotDict` | `E_MethName` |
| `t = .base .unit` | `isUnit` | `E_Lam` の条件の補助 |
| `arms ≠ .nil` | `nonemptyArms` | `E_Match` |
| リストが空でないこと | `nonemptyList` | `E_FunDicts`、`E_ConValue`、`E_RecordUpdate`、`E_PartialCall`、`E_PartialCon` |
| 自然数リストの順列 | `natPerm` | `E_Record`、`AltsTy` の位置の順列 |
| 位置の重複がないこと | `natNodup` | `E_RecordUpdate` |
| `∀ i ∈ positions, i < n` | `positionsInRange` | `E_RecordUpdate` |
| `StringAddOk` | `stringAddOk` | `E_Interpolation`。部分数が2以上の場合に検査 |
| `Ty.Le` | `tyLe` | `E_PartialCall`、`E_PartialCon`、`E_Sub`、`B_Sub`、`HasHoleArgs.hole` |
| `Eff.Sub` | `effSub` | `E_PartialCall`、`E_Handle`、`E_Sub`、`B_Sub` |
| `SatAll` | `satAll` | `E_Fun`、`E_FunDicts`、`E_MethName`、`E_Op`、`DictEv.HasType.impl` |
| `s.admits C ts` | 引数として受け取る `admitsDec` | `E_Prim`、`E_Binary`、`E_Neg`、補間の `StringAddOk` |
| `PatTy`・`AltsTy` | `patTy`・`checkAlts`・`altsTy` | 束縛のパターンと `HasArms.plain`・`guarded` |
| `Exhaustive` | 次節の包み | `E_Match`、`E_TryResult`、`E_TryOption`、`B_LastPat`、`B_BindPat`、`E_RecordUpdate` |

自然数・名前の等しさ、長さ、空リスト、`s ∈ cd.supers` などは、Lean の既存の `decide`・`BEq`・リストの操作で判定できる。宣言表や `Γ`、`R`、`opSig` の参照が `some` を返すという前提は、参照結果を `match` して得る。型を含む等式には `tyEq`・`tysEq` を使う。

任意の `Builtins.sat` と `PrimSig.admits` は一般の `Prop` なので、それ自体から判定を計算していない。指定どおり `satDec`・`admitsDec` と、それらが表の述語を満たすという契約を受け取る形にした。`Exhaustive` も値についての全称述語であり、今回の包みは手順の成功から網羅性を導く一方向の判定である。

`HasType`・`HasBlock`・`HasArms` などの型付けの判断そのものは、次の E2a-2b の対象として残している。

## 4. 網羅性の包みの形と、照合する型の決め方の案

共通の `exhaustive` は次の形である。

```lean
(useful D.patternProgram ctors [a]
  (ps.map fun p => [p]) [.wild]).isNone
```

`exhaustive_sound` は `useful_singleton_none_sound` から `Exhaustive` を証明した。各包みは `CtorsComplete D.patternProgram ctors` を前提にする。

| 包み | 型・パターン | E2a-2b での型の決め方 |
|---|---|---|
| `matchExhaustive` | `a` と `arms.unguardedPatterns` | 照合する式の検査が求めた型 `a` を使う。結果型の注釈とは区別する |
| `tryResultExhaustive` | `.data d [t, errTy]`、`Ok(var)` と `Error(var)` | 入力式から成功型 `t` を求め、戻り値型 `R` と宣言の条件からエラー型を照合する。戻り値側の成功型 `u` を入力型に使わない |
| `tryOptionExhaustive` | `.data d [t]`、`Some(var)` と `None()` | 入力式の要素型 `t` を使う。戻り値側の要素型 `u` と区別する |
| `bindingExhaustive` | `a` と `[p.toCore]`。内部は `irrefutable` | `B_LastPat`・`B_BindPat` の注釈 `boundTy` に入力式を受け入れた後、その注釈型で検査する |
| `recordUpdateExhaustive` | `.data cd.data ts` と `recordUpdatePattern c n positions`。内部は `irrefutable` | 宣言から得た `cd.data` と構文の型引数 `ts` を使い、base の検査にも同じ型を要求する |

これらの健全性の定理はすべて証明済みで、`sorryAx` に依存しない。

`Arms.unguardedPatterns` はすでに `List Release.Pat` を返すため、ここでは `Pattern.toCore` を再度適用しない。`checkMatch` は使用していない。選ばれない分岐の検査も追加していない。

## 5. 例の一覧

[CheckToolsExamples.lean](../../../../../formal/Benitoite/Surface/CheckToolsExamples.lean) の130件がすべて通った。比較は真偽値または `atoms` 上の型比較で行った。既存の整礎再帰との一致の例では、既存定義の等式で展開してから `rfl`・`simp` で確認した。

| 例のまとまり | 件数 | 主な場合 |
|---|---:|---|
| エフェクト | 11 | 包含の成功・失敗、等しさ、名前と `rho` の単一集合、集合外の原子の除外、和、`substRho` の置換と保持 |
| 型比較と包含 | 10 | 型の全構成、型リストの長さ違い、型構成子の不一致、外側の関数のエフェクトの拡大、入れ子の関数の拡大の拒否 |
| 型操作の写し | 11 | cutoff、置換後の shift、エフェクトの具体化、高カインドの適用、型引数が足りない適用、`fnTyCheck` |
| 既存操作との一致 | 4 | `Ty.shift`、`Ty.substAt`、`Ty.applyTo`、`Coverage.substTy` との一致 |
| 規則の前提 | 49 | WF、三つの Exits、範囲・リスト・入れ子の Valid、IsIf、Nontrivial、PipeValue、直接の頭、補間型、継続型・辞書型の除外、空・順列・重複・範囲 |
| パターンと選択肢 | 23 | 定数・範囲・リスト・構成子、宣言順のレコード、省略フィールド、型引数の数、不明な構成子、恒等対応、並べ替えの成功・型不一致・不正な位置 |
| 網羅性 | 12 | Boolean の true だけの失敗、true と false の成功、ガードの除外、束縛、Result・Option の二行、レコード更新 |
| 補間の連結演算子 | 5 | 成功、`admitsDec` の失敗、演算子・組み込み表の欠落、戻り値型の不一致 |
| `SatAll` | 5 | 一般の判定の成功・失敗・長さ違い、既存の `satB` を渡す場合 |

## 6. 次の E2a-2b で使うときの注意

- **`AtomsIn` は比較する型の出どころ全体に必要である。** 式の注釈だけでなく、宣言表、組み込み表、`Γ`、`R` から取り出す型も対象にする。`effSub_sound` は小さい側だけを要求するが、`effEq_sound`・`tyEq_sound`・`tysEq_sound` は両側を要求する。
- **評価する経路には写しを使う。** 型操作は `shiftTy`・`substTyAt`・`substTy`・`fnTyCheck` を使い、健全性の証明で `_eq` 補題を適用して既存規則に接続する。
- **切り詰めたエフェクトを既存のエフェクトに接続する前提を保つ。** `unionEff_eq` には両入力の `AtomsIn`、`singleEff_eq` にはその名前の原子の所属が必要である。特に `E_With` の `State` と `E_Op` の宣言した名前を原子集合に含める。
- **`patTy` と Valid はそれぞれ検査する。** `patTy` は `PatTy` の規則を計算する。範囲の大小など、表層が別の前提として要求する条件は `patternValid`・`alternativesValid` で検査する。
- **選択肢では最初の恒等対応を維持する。** `altsTy` は最初のパターンから束縛型を求め、`checkAlts` が恒等対応・全位置の順列・並べ替え後の型を検査する。健全性には入力型の `AtomsIn` と `ConAtomsIn` を要求している。
- **組み込みの判定は任意の表に渡せる。** 検査全体は `satDec : SatDec` と `admitsDec : AdmitsDec` を受け取り、健全性に `SatDecSound B satDec`・`AdmitsDecSound B admitsDec` を置く。`mkBuiltins` 固有の実装には結び付けていない。
- **`ite` の結びと `handle` の不動点は次の作業で組み立てる。** 今回は、それらが使う型比較・包含・有限集合上の和を用意した。`Exits` の判定は既存の構文上の定義と同値であり、呼び出しやオペランドの内側を新たに辿る判定にはしていない。