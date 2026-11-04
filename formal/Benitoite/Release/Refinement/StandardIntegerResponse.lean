import Benitoite.Release.Refinement.StandardInteger
import Benitoite.Release.Refinement.CanonicalValues

namespace Benitoite.Release.Refinement.StandardIntegerResponse
open Benitoite.Interval StandardScalar

-- 七整数型の実名と a/b の引数を持つ有限表（設計書 01-12「標準契約と数値の正常応答」）。
def minMaxName (k : IntKind) (maximum : Bool) : String :=
  integerModule k ++ if maximum then ".maximum" else ".minimum"

def minMaxSig (k : IntKind) : PrimSig :=
  ⟨[],0,["a","b"],[embedTy k.type,embedTy k.type],embedTy k.type,
    Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem integer_shape {P B Ψ v} (k : IntKind)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (embedTy k.type)) :
    ∃ n : IntegerValue k, v = .const (embedConst (IntegerValue.toConst k n)) := by
  cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar rfl
  all_goals cases c <;> cases ht
  all_goals first
    | exact ⟨_,rfl⟩
    | exact ⟨⟨_,hc⟩,rfl⟩

private theorem minMax_instantiated (k : IntKind) :
    instantiatedTel (Tel.instR [] (minMaxSig k).tel) [] [] =
      .param "a" (embedTy k.type) (.param "b" (embedTy k.type)
        (.done (embedTy k.type) Eff.empty)) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases k <;> simp [emptyRange,minMaxSig,embedTy,IntKind.type,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem minMax_bind (k : IntKind) (value : Val) (name : String) :
    Tel.bind (Tel.argumentsEnv value)
      (Tel.param name (embedTy k.type) (.done (embedTy k.type) Eff.empty)) =
      .param name (embedTy k.type) (.done (embedTy k.type) Eff.empty) := by
  cases k <;> simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
    Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
    rowFails,rawBindTys,embedTy,IntKind.type]

private theorem minMax_done_bind (k : IntKind) (value : Val) :
    Tel.bind (Tel.argumentsEnv value) (.done (embedTy k.type) Eff.empty) =
      .done (embedTy k.type) Eff.empty := by
  cases k <;> simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
    Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
    rowFails,rawBindTys,embedTy,IntKind.type]


private theorem minMax_arguments {P B Ψ ts es rs ws a e} (k : IntKind) (maximum : Bool)
    (args : BuiltinArgs P B Ψ (minMaxName k maximum) (minMaxSig k) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = embedTy k.type ∧ e = Eff.empty ∧
    ∃ left right : IntegerValue k,
      ws = [.const (embedConst (IntegerValue.toConst k left)),
        .const (embedConst (IntegerValue.toConst k right))] := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [minMax_instantiated] at values
  cases values with
  | param _ hl rest =>
    obtain ⟨left,rfl⟩ := integer_shape k hl
    rw [minMax_bind] at rest
    cases rest with
    | param _ hr done =>
      obtain ⟨right,rfl⟩ := integer_shape k hr
      rw [minMax_done_bind] at done
      cases done
      exact ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩

-- 同じ二入力と同じ応答を数学上の min/max へ接続する。
theorem minMax_math (k : IntKind) (maximum : Bool) (left right : IntegerValue k) :
    ∃ value : IntegerValue k,
      integerMinMaxDelta k maximum left right =
        .val (.const (embedConst (IntegerValue.toConst k value))) ∧
      value.toInt = (if maximum then max left.toInt right.toInt else min left.toInt right.toInt) := by
  refine ⟨if maximum then (if left.toInt < right.toInt then right else left)
      else (if left.toInt ≤ right.toInt then left else right),rfl,?_⟩
  cases maximum <;> simp only [Bool.false_eq_true,ite_false,ite_true]
  all_goals split <;> simp_all [Int.max_def,Int.min_def] <;> omega

-- 実引数の型付けを逆転し、具体δから応答を構成する。
theorem minMax_response {P B Ψ ts es rs ws a e} (k : IntKind) (maximum : Bool)
    (args : BuiltinArgs P B Ψ (minMaxName k maximum) (minMaxSig k) ts es rs ws a e) :
    ∃ out, integerDelta (minMaxName k maximum) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
      ∃ left right : IntegerValue k,
        ws = [.const (embedConst (IntegerValue.toConst k left)),
          .const (embedConst (IntegerValue.toConst k right))] ∧
        integerMinMaxDelta k maximum left right = out ∧
        ∃ value : IntegerValue k,
          out = .val (.const (embedConst (IntegerValue.toConst k value))) ∧
          value.toInt = (if maximum then max left.toInt right.toInt else min left.toInt right.toInt) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := minMax_arguments k maximum args
  obtain ⟨value,reply,selected,typed⟩ := integerMinMax_typed P B Ψ k maximum left right
  obtain ⟨mathValue,mathReply,mathValueEq⟩ := minMax_math k maximum left right
  refine ⟨_,(integerDelta_minMax k maximum left right).trans (congrArg some reply),
    ⟨typed,?_⟩,?_,by intro i; simp,left,right,rfl,reply,mathValue,?_,mathValueEq⟩
  · cases k <;> trivial
  · intro σ _ _; cases k <;> trivial
  · exact reply.symm.trans mathReply

private def canonicalKinds : List IntKind :=
  [.integer8,.integer16,.integer32,.integer64,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64]

-- canonical 七型 × 二演算の十四実名を収集する。
def minMaxLookup (name : String) : Option PrimSig :=
  canonicalKinds.findSome? fun k =>
    if name = minMaxName k false ∨ name = minMaxName k true then some (minMaxSig k) else none

theorem minMax_lookup (k : IntKind) (maximum : Bool) :
    minMaxLookup (minMaxName k maximum) = some (minMaxSig k) := by
  cases k <;> cases maximum <;> simp [minMaxLookup,minMaxName,canonicalKinds,
    integerModule,List.findSome?]

-- 他の欄を保持し、実名の有限な署名表と既存の integerDelta を使う。
def minMaxTable (base : Builtins) : Builtins :=
  {base with sig := minMaxLookup, delta := integerDelta}

theorem minMax_model_response {P base Ψ ts es rs ws a e} (k : IntKind) (maximum : Bool)
    (args : BuiltinArgs P (minMaxTable base) Ψ (minMaxName k maximum) (minMaxSig k) ts es rs ws a e) :
    (minMaxTable base).sig (minMaxName k maximum) = some (minMaxSig k) ∧
    ∃ out, (minMaxTable base).delta (minMaxName k maximum) ts es rs ws = some out ∧
      Outcome.Typed P (minMaxTable base) Ψ out a ∧ AdequateResult ws out ∧
      (∀ i, out ≠ .exit i) := by
  refine ⟨minMax_lookup k maximum,?_⟩
  obtain ⟨out,delta,typed,adequate,nonexit,_⟩ := minMax_response k maximum args
  exact ⟨out,delta,typed,adequate,nonexit⟩

-- 全十四実名を同じ表の引数・応答契約として読む。
example {P base Ψ ts es rs ws a e} (k : IntKind) (maximum : Bool)
    (args : BuiltinArgs P (minMaxTable base) Ψ (minMaxName k maximum)
      (minMaxSig k) ts es rs ws a e) :
    (minMaxTable base).sig (minMaxName k maximum) = some (minMaxSig k) ∧
    ∃ out, (minMaxTable base).delta (minMaxName k maximum) ts es rs ws = some out ∧
      Outcome.Typed P (minMaxTable base) Ψ out a ∧ AdequateResult ws out ∧
      (∀ i, out ≠ .exit i) :=
  minMax_model_response k maximum args

end Benitoite.Release.Refinement.StandardIntegerResponse
