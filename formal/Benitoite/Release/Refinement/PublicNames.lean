import Benitoite.Release.Refinement.StandardModelDeclarations
import Benitoite.Release.Refinement.ScopeSignatures
import Benitoite.Release.Refinement.ScopeDelta
import Benitoite.Release.Refinement.InversionCore
import Benitoite.Release.Refinement.ScopePublic
import Benitoite.Release.Refinement.ScopePublicTyping

/-! # 公開名と内部名・依存列・述語・型の対応

標準ライブラリの公開名を、形式化の内部名（安全な入口の依存列の行、合成表の本体の鍵、組み込みの名前）と、
篩の述語の構成子、型へ対応させる（設計書 07-04「篩を含む形式化の範囲」）。
安全な入口は、内部の19行のそれぞれに公開名を一つ与える。`safeHead`・`safeTail` は既存の
`NonEmptyList.head`・`NonEmptyList.tail` と同じ依存列を持ち、同じ公開名へまとめる。
述語へ写す関数は、篩の中でリテラルを要する引数がリテラルのときだけ述語を返す。 -/
namespace Benitoite.Release.Refinement.PublicNames
open InternalContracts

/-- 安全な入口の公開名の由来。 -/
inductive SafeOrigin where
  /-- 既存の公開名を保ち、結果の型に篩を付ける。 -/
  | existing
  /-- 既存の公開名と同じ依存列の内部の行を、その公開名へまとめる。 -/
  | unified
  /-- 新しい公開名。 -/
  | fresh
  deriving DecidableEq

/-- 安全な入口の一行。`row` は `InternalContracts.all` の行名、`composed` は合成表の精密側の本体の鍵
（合成表に精密側の本体を持たない行は `none`）。 -/
structure SafeEntry where
  row : String
  publicName : String
  origin : SafeOrigin
  composed : Option String
  deriving DecidableEq

/-- 内部の19行と同じ順の公開名の表。 -/
def safeEntries : List SafeEntry := [
  ⟨"safeHead","NonEmptyList.head",.unified,some "Internal.safeHead"⟩,
  ⟨"safeGet","List.at",.fresh,some "Internal.safeGet"⟩,
  ⟨"safeTail","NonEmptyList.tail",.unified,none⟩,
  ⟨"CheckedIndex.get","Range.get",.existing,some "Internal.CheckedIndex.get"⟩,
  ⟨"sameLengthGet","Range.getFrom",.fresh,some "Internal.sameLengthGet"⟩,
  ⟨"Range.minimum","Range.minimum",.existing,some "%Range.minimum.refined"⟩,
  ⟨"Range.maximum","Range.maximum",.existing,some "%Range.maximum.refined"⟩,
  ⟨"Range.value","Range.value",.existing,some "%Range.value.refined"⟩,
  ⟨"Range.lengthMinimum","Range.lengthMinimum",.existing,some "%Range.lengthMinimum.refined"⟩,
  ⟨"Range.lengthMaximum","Range.lengthMaximum",.existing,some "%Range.lengthMaximum.refined"⟩,
  ⟨"Range.checkedLength","Range.checkedLength",.existing,some "%Range.checkedLength.refined"⟩,
  ⟨"Range.lengthValues","Range.lengthValues",.existing,some "%Range.lengthValues.refined"⟩,
  ⟨"Range.indexValue","Range.indexValue",.existing,some "%Range.indexValue.refined"⟩,
  ⟨"Range.indexValues","Range.indexValues",.existing,some "%Range.indexValues.refined"⟩,
  ⟨"NonEmptyList.fromList","NonEmptyList.fromList",.existing,some "Internal.NonEmptyList.fromList"⟩,
  ⟨"NonEmptyList.toList","NonEmptyList.toList",.existing,some "Internal.NonEmptyList.toList"⟩,
  ⟨"NonEmptyList.head","NonEmptyList.head",.existing,some "Internal.NonEmptyList.head"⟩,
  ⟨"NonEmptyList.tail","NonEmptyList.tail",.existing,none⟩,
  ⟨"NonEmptyList.map","NonEmptyList.map",.existing,some "%NonEmptyList.map.refined"⟩]

/-- 表の行名は、内部の19行の名前と同じ順で一致する。 -/
theorem safeEntries_rows (n : Names) (a b : Ty) (e : Eff) :
    safeEntries.map SafeEntry.row = (InternalContracts.all n a b e).map Prod.fst := rfl

/-- 既存の公開名は15、まとめた行は2、新しい公開名は2である。 -/
theorem safeEntries_origins :
    (safeEntries.filter (·.origin = .existing)).length = 15 ∧
    (safeEntries.filter (·.origin = .unified)).length = 2 ∧
    (safeEntries.filter (·.origin = .fresh)).length = 2 := by decide

/-- 異なる公開名は17であり、まとめた2行だけが既存の行と公開名を共有する。 -/
theorem safeEntries_public_names :
    (safeEntries.map SafeEntry.publicName).eraseDups.length = 17 ∧
    ∀ e ∈ safeEntries, e.origin ≠ .unified →
      (safeEntries.filter (fun f => f.publicName = e.publicName)).length =
        if e.publicName = "NonEmptyList.head" ∨ e.publicName = "NonEmptyList.tail" then 2 else 1 := by
  decide

/-- まとめた行は、同じ公開名の既存の行と同じ依存列を持つ。 -/
theorem unified_same_tel (n : Names) (a b : Ty) (e : Eff) :
    (InternalContracts.all n a b e).lookup "safeHead" =
      (InternalContracts.all n a b e).lookup "NonEmptyList.head" ∧
    (InternalContracts.all n a b e).lookup "safeTail" =
      (InternalContracts.all n a b e).lookup "NonEmptyList.tail" := by
  constructor <;> simp [InternalContracts.all, List.lookup]

/-- 衝突18名に入る行の公開名は、合成表の精密側の名前へ写る。 -/
theorem collision_refined :
    ∀ e ∈ safeEntries, e.publicName ∈ FunctionNames.collisionNames →
      e.composed = some (FunctionNames.rename true e.publicName) := by
  decide

/-- 合成表の鍵を持つ行は、合成表の本体の lookup に成功する。 -/
theorem composed_lookup (externals : List (ExternalKey × ExternalDecl)) :
    ∀ e ∈ safeEntries, ∀ k, e.composed = some k →
      ∃ body : StandardModel.Body, body.key = k ∧
        (StandardModel.program externals).defs k = some body.definition := by
  intro e he k hk
  have hit : ∀ body : StandardModel.Body, body.key = k →
      ∃ body : StandardModel.Body, body.key = k ∧
        (StandardModel.program externals).defs k = some body.definition :=
    fun body h => ⟨body, h, h ▸ StandardModel.body_lookup externals body⟩
  simp only [safeEntries, List.mem_cons, List.not_mem_nil, or_false] at he
  rcases he with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl
  all_goals cases hk
  · exact hit .b085 rfl
  · exact hit .b086 rfl
  · exact hit .b087 rfl
  · exact hit .b088 rfl
  · exact hit .b092 rfl
  · exact hit .b093 rfl
  · exact hit .b094 rfl
  · exact hit .b095 rfl
  · exact hit .b096 rfl
  · exact hit .b097 rfl
  · exact hit .b098 rfl
  · exact hit .b099 rfl
  · exact hit .b100 rfl
  · exact hit .b089 rfl
  · exact hit .b090 rfl
  · exact hit .b091 rfl
  · exact hit .b105 rfl

/-- 合成表に精密側の本体を持たないのは、`tail` の二行だけである。 -/
theorem composed_missing :
    (safeEntries.filter (·.composed = none)).map SafeEntry.row = ["safeTail","NonEmptyList.tail"] := by
  decide

/-! ## 起点と At の公開名 -/

/-- `Scope.PathBases` は核の起点の型である。等号・鍵・表示の実装を持たせない。 -/
def pathBasesType : Ty := .pathBases

/-- `Process.pathBases()` は起点を発行する内部の組み込みへ写る。 -/
def processPathBases : PrimName := ScopeSignatures.pathBasesName

/-- 発行の入口の署名は、`C_IssuePathBases` の前提の形を満たす。 -/
theorem processPathBases_signature :
    ScopeSignatures.entries.lookup processPathBases = some ScopeSignatures.pathBases ∧
    ScopeSignatures.pathBases.kind = .pathBases ∧
    ScopeSignatures.pathBases.opEff = some processEnvironmentEff ∧
    ScopeSignatures.pathBases.params = [] ∧ ScopeSignatures.pathBases.ret = pathBasesType ∧
    ScopeSignatures.pathBases.eff = Eff.single processEnvironmentEff := by
  refine ⟨?_, rfl, rfl, rfl, rfl, rfl⟩
  simp [processPathBases, ScopeSignatures.entries, ScopeSignatures.pathBasesName, List.lookup]

/-- `Scope.checkPathInAt(bases:, pattern:, path:)` は、パスの種類の At の計算へ写る。結果は
`Result[Scope.PathIn[R], Scope.ScopeError]` の形を持つ。 -/
def checkPathInAt (bases pattern path : Val) (index : RangeIx) : Comp :=
  .checkAt .path "Scope.PathIn" ScopeDelta.resultShape (some bases) pattern path index

example (bases pattern path : Val) (index : RangeIx) :
    checkPathInAt bases pattern path index =
      .checkAt .path "Scope.PathIn" ScopeDelta.resultShape (some bases) pattern path index := rfl

/-- At の計算の結果の型は、公開の Result と ScopeError の形であり、HTTP の宣言を持つプログラムで宣言される。 -/
theorem checkPathInAt_result :
    ScopeDelta.resultShape.owner = "Result" ∧ ScopeDelta.resultShape.ok = "Result.Ok" ∧
    ScopeDelta.resultShape.error = "Result.Error" ∧ ScopeDelta.resultShape.errorType = atErrorType ∧
    ScopeDelta.resultShape.Declared ScopeDeclarations.program :=
  ⟨rfl, rfl, rfl, rfl, ScopeDelta.result_declared ScopeDeclarations.program_hasHttp⟩

/-- 公開の At の入口は内容型を持たない名前 `Scope.PathIn` を使い、要求の At の名前 `Http.RequestIn` は内容型を
持つ。内容型を持たない名前の At の失敗は九欄の公開形で観測される（`StateTyE.at_prepare_public`・
`StateTyE.at_check_public`）ので、公開形を持たない固定の値で観測されるのは、公開の入口を持たない要求の At の
失敗に限られる。 -/
theorem at_names (delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome)
    (io : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop) :
    (ScopeSignatures.builtins delta io).valContent "Scope.PathIn" = none ∧
    (ScopeSignatures.builtins delta io).valContent "Http.RequestIn" = some TargetTable.clientRequestTy :=
  ⟨rfl, rfl⟩

/-- 公開の At の入口の形の計算の失敗は、型付きの状態で九欄の公開形で観測される。 -/
theorem checkPathInAt_public {P B σ Eb q k μ bases pattern path index detail}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.code = checkPathInAt bases pattern path index)
    (hn : B.valContent "Scope.PathIn" = none)
    (he : AtPrepare B q.capture .path "Scope.PathIn" (some bases) pattern path index = .error detail) :
    ∃ t, detail.publicTree = t ∧ t.Typed (.data "Scope.AtDetail") := by
  obtain ⟨t, _, ht, typed⟩ := StateTyE.at_prepare_public hP hPB hB h hv hn he
  exact ⟨t, ht, typed⟩

/-! ## 一般の check -/

/-- `Refinement.check` の内部の組み込みの名前。 -/
def checkName : PrimName := "Refinement.check"

/-- `Refinement.CheckError { expected: String }` の宣言。 -/
def checkErrorDecl : ConDecl := ⟨"Refinement.CheckError",0,[.base .string]⟩

/-- 一般の check の名前と誤りの型は、範囲付きの組み込みの表とAtの診断の公開形の名前と重ならない。 -/
theorem check_names_fresh :
    (ScopeSignatures.entries.lookup checkName).isNone ∧
    checkErrorDecl.data ∉ ScopePublic.all.map ScopePublic.PublicData.name := by
  refine ⟨?_, by decide⟩
  simp [checkName, ScopeSignatures.entries, ScopeSignatures.pathBasesName, List.lookup]

/-- 型引数 `[T, U]` の許容。正規形で `U` は `T` に篩を一つ付けた型である。`PrimSig.admits` の形の述語で
書けるので、型付けの規則を足さない。 -/
noncomputable def checkAdmits (_ : List TParam) : List Ty → Prop
  | [t, u] => ∃ p, u.norm = (Ty.refined t p).norm
  | _ => False

example (C : List TParam) (p : Pred) :
    checkAdmits C [.base .integer, .refined (.base .integer) p] := ⟨p, rfl⟩

example (C : List TParam) : ¬ checkAdmits C [.base .integer] := id

example (C : List TParam) (p : Pred) :
    ¬ checkAdmits C [.base .string, .refined (.base .integer) p] := by
  rintro ⟨q, h⟩
  have core := congrArg Ty.core h
  simp only [Ty.refined_norm_core] at core
  cases core

/-! ## 述語へ写す関数 -/

/-- Float と Float32 の分類の関数の名前を、核の類の列へ写す。`isInfinite` は二つの類の `or` に当たる。 -/
def floatClasses : String → Option (List FloatClass)
  | "isFinite" => some [.finite]
  | "isNaN" => some [.nan]
  | "isInfinite" => some [.positiveInfinity, .negativeInfinity]
  | "isPositiveInfinity" => some [.positiveInfinity]
  | "isNegativeInfinity" => some [.negativeInfinity]
  | "isPositiveZero" => some [.positiveZero]
  | "isNegativeZero" => some [.negativeZero]
  | _ => none

/-- Float の分類の関数の名前の一覧。Float32 も同じ名前を持つ。 -/
def floatNames : List String :=
  ["isFinite","isNaN","isInfinite","isPositiveInfinity","isNegativeInfinity",
   "isPositiveZero","isNegativeZero"]

/-- 既存の名前。Float は `isNaN`、Float32 は `isNaN`・`isInfinite` を持つ。 -/
def floatExisting : FloatWidth → List String
  | .binary64 => ["isNaN"]
  | .binary32 => ["isNaN","isInfinite"]

/-- 分類の名前を述語へ写す。 -/
def floatPredicate (width : FloatWidth) (name : String) (value : Term) : Option Pred :=
  (floatClasses name).bind fun
    | [] => none
    | c :: cs => some (cs.foldl (fun p c => .or p (.floatClass width c value)) (.floatClass width c value))

/-- 七つの名前はすべて写り、六つの類はそれぞれ一つの一対一の名前を持つ。足す名前は Float が6、Float32 が5。 -/
theorem float_names :
    (∀ n ∈ floatNames, (floatClasses n).isSome) ∧
    (floatNames.filter (fun n => floatClasses n = some [.finite])).length = 1 ∧
    (floatNames.filter (fun n => floatClasses n = some [.nan])).length = 1 ∧
    (floatNames.filter (fun n => floatClasses n = some [.positiveInfinity])).length = 1 ∧
    (floatNames.filter (fun n => floatClasses n = some [.negativeInfinity])).length = 1 ∧
    (floatNames.filter (fun n => floatClasses n = some [.positiveZero])).length = 1 ∧
    (floatNames.filter (fun n => floatClasses n = some [.negativeZero])).length = 1 ∧
    (floatNames.filter (· ∉ floatExisting .binary64)).length = 6 ∧
    (floatNames.filter (· ∉ floatExisting .binary32)).length = 5 := by
  decide

example (v : Term) : floatPredicate .binary64 "isInfinite" v =
    some (.or (.floatClass .binary64 .positiveInfinity v) (.floatClass .binary64 .negativeInfinity v)) := rfl

example (v : Term) : floatPredicate .binary32 "isPositiveZero" v = some (.floatClass .binary32 .positiveZero v) := rfl

example (v : Term) : floatPredicate .binary64 "isNormal" v = none := rfl

/-- `String.charactersIn(text:, minimum:, maximum:)` は、両端がリテラルのときだけ述語へ写る。 -/
def charactersInPredicate (text : Term) : Option Char → Option Char → Option Pred
  | some lo, some hi => some (.charactersIn text lo hi)
  | _, _ => none

example (t : Term) : charactersInPredicate t (some 'a') (some 'z') = some (.charactersIn t 'a' 'z') := rfl
example (t : Term) : charactersInPredicate t none (some 'z') = none := rfl

/-- 範囲への所属の関数の種類。`Scope.pathMatches` はパス、`Scope.hostMatches` はホストである。 -/
def matchesKind : String → Option Scope.Domain.Kind
  | "Scope.pathMatches" => some .path
  | "Scope.hostMatches" => some .host
  | _ => none

/-- 所属の関数は、pattern がリテラルの絶対形で種類に合うときだけ述語へ写る。基準の名前と secrets の形は
At を使う。 -/
def memberPredicate (name : String) (pattern : Option RangeExpr) (value : Term) : Option Pred := do
  let kind ← matchesKind name
  let range ← pattern
  match range with
  | .absolute r => if r.kind? = some kind then some (.member kind value range) else none
  | _ => none

example (w : Scope.Domain.Word) (v : Term) :
    memberPredicate "Scope.pathMatches" (some (.absolute (.path (.tree w)))) v =
      some (.member .path v (.absolute (.path (.tree w)))) := rfl

example (w : Scope.Domain.Word) (v : Term) :
    memberPredicate "Scope.pathMatches" (some (.based .home (.tree w))) v = none := rfl

example (w : Scope.Domain.Word) (v : Term) :
    memberPredicate "Scope.hostMatches" (some (.absolute (.path (.tree w)))) v = none := rfl

example (v : Term) : memberPredicate "Scope.pathMatches" none v = none := rfl

/-- 生成する構成子の判定の関数 `isC` は、構成子の判定の述語へ写る。 -/
def constructorPredicate (value : Term) (constructor : ConName) : Pred := .constructorIs value constructor

example (v : Term) : constructorPredicate v "Shape.Circle" = .constructorIs v "Shape.Circle" := rfl

end Benitoite.Release.Refinement.PublicNames
