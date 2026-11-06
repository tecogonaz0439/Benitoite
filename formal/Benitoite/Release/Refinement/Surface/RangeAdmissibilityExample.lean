import Benitoite.Release.Refinement.Surface.Program
import Benitoite.Release.Refinement.AdmissibleMap

/-! # 組込みの型引数の許容と範囲の具体化

値の改名・値の置換に対する許容の保存は、範囲の具体化に対する許容の保存を含まない。
範囲変数を関数型の効果に持つ型引数を使い、値の置換の仮定を満たす表の下でこの差を示す。
-/

namespace Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample
noncomputable section

def effect (ix : RangeIx) : Eff := .mk (fun a => decide (a = .name "Read" ix)) []
def argument : Ty := .fn [] [] (.base .unit) (effect (.rvar 0))

def signature : PrimSig where
  tparams := [TypeCtx.valueParam]
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ ts => ts = [argument]
  kind := .pure
  opEff := none

def builtins : Builtins where
  sig := fun b => if b = "probe" then some signature else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => True
  refGet := "get"
  refSet := "set"

def program : Refinement.Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem atoms (ρ : Nat → RangeIx) : mapRangeAtoms ρ (fun a => decide (a = .name "Read" (.rvar 0))) =
    (fun a => decide (a = .name "Read" (ρ 0))) := by
  funext a
  simp [mapRangeAtoms, mapAtomRanges, mapIx, eq_comm]

private theorem norm_argument : argument.norm = argument := by
  simp [argument, effect, Ty.norm, Ty.normTys, Eff.norm]

private theorem argument_rename (ξ : Nat → Nat) : renameTy ξ argument = argument := by
  simp [argument, effect, renameTy, Ty.rawBind, Eff.rawBind, renEnv, rawBindTys,
    substAtoms_nil, instAtoms_nil, rowFails]

private theorem argument_subst (ν : Nat → Val) : substTyValues ν argument = argument := by
  simp [argument, effect, substTyValues, Ty.bind, Ty.rawBind, Eff.rawBind, valEnv,
    rawBindTys, substAtoms_nil, instAtoms_nil, rowFails, Ty.norm, Ty.normTys, Eff.norm]

theorem values : builtins.ValueAssumptions program where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  admits_rename := by
    intro b sg C Γ Δ ts ξ hsg _ _ _ ha
    have hs : sg = signature := by
      simp only [builtins] at hsg
      split at hsg
      · exact (Option.some.inj hsg).symm
      · cases hsg
    subst sg
    change ts = [argument] at ha
    subst ts
    change [renameTy ξ argument] = [argument]
    rw [argument_rename]
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hsg _ _ ha
    have hs : sg = signature := by
      simp only [builtins] at hsg
      split at hsg
      · exact (Option.some.inj hsg).symm
      · cases hsg
    subst sg
    change ts = [argument] at ha
    subst ts
    change [substTyValues ν argument] = [argument]
    rw [argument_subst]

theorem open_admits : signature.admits [] (Ty.normTys [argument]) := by
  change [argument.norm] = [argument]
  rw [norm_argument]

private theorem instantiated_argument : argument.instR [RangeExpr.top] =
    .fn [] [] (.base .unit) (effect (.fixed RangeExpr.top)) := by
  simp [argument, effect, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, mapRangesTys,
    Eff.rawMapRanges, atoms, rangeAt, Ty.norm, Ty.normTys, Eff.norm]

theorem instantiated_admits_rejected :
    ¬ signature.admits [] (Ty.normTys [argument.instR [RangeExpr.top]]) := by
  rw [instantiated_argument]
  change ¬ [_] = [argument]
  intro h
  have ht := congrArg (fun (xs : List Ty) => match xs with
    | [.fn _ _ _ e] => Eff.test e (.name "Read" (.rvar 0))
    | _ => false) h
  simp [argument, effect, Ty.norm, Ty.normTys, Eff.norm, Eff.test, Eff.atoms] at ht


def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

private theorem argument_annotation : Ty.Annotation declarations.core [] [] argument := by
  refine ⟨?_, ?_, ?_⟩
  · simp [argument, effect, Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.norm, Ty.normTys]
  · simp [argument, effect, Ty.Sorted, sortedTys, sortedEff]
  · simp [argument, effect, Ty.Declared, declaredTys, declaredEff]

theorem argument_sourceScoped : argument.SourceScoped 1 0 0 0 := by
  refine ⟨argument_annotation.wf, ?_, ?_⟩
  · simp [argument, effect, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn]
  · simp [argument, effect, Ty.RangesScoped, rangesScopedTypes, Eff.RangesScoped, RangeIx.WF]

private theorem admissible : PrimitiveAdmissible [] 0 signature Qempty [argument] [] := by
  constructor
  · rfl
  · exact open_admits
  · intro t ht
    cases List.mem_singleton.mp ht
    exact ⟨argument_annotation.wf, by simp [argument, Ordinary, Ty.core]⟩
  · rfl
  · simp
  · simp [signature, Eff.empty, Eff.RowsIn, Ty.RowsInList]
  · intro i hi
    simp [signature, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at hi
  · intro i hi
    simp [signature, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at hi
  · simp [signature, PrimSig.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.empty]

private theorem signature_instance : SignatureInstance declarations.core [] []
    (Tel.instR [] signature.tel) [TyKind.value] [argument] [] := by
  constructor
  · simp [signature, PrimSig.tel, signatureTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Ty.norm, Ty.normTys, Tel.norm, Eff.norm,
      Eff.empty, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm]
  · intro t ht; cases List.mem_singleton.mp ht; exact argument_annotation
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    cases i with
    | succ i => simp at ha
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at ha hk
      subst a k
      exact ⟨by simp [argument, effect, Ty.HasKind, kindsList, kindsEff, NamesWF], by simp [argument, Ordinary, Ty.core]⟩
  · simp [RowAnnotations]
  · simp
  · have hh : instantiatedTel (Tel.instR [] signature.tel) [argument] [] =
        .done (.base .unit) Eff.empty := by
      simp [signature, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges,
        Ty.norm, Ty.normTys,
        Tel.norm, Eff.norm, Eff.empty, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind,
        typeEnvAt, substAtoms_nil, instAtoms_nil, rowFails]
    rw [hh]
    exact ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

def source : Expr := .primName "probe" [argument] [] []

theorem surface_typed (op : OpPrim) {R p} :
    HasTypeQ declarations builtins op Qempty [] [] [] [] R p source
      (.dependentFn (instantiatedTel (Tel.instR [] signature.tel) [argument] [])) Eff.empty := by
  apply HasTypeQ.E_Prim
  exact .prim (s := signature) (rs := []) (by simp [builtins])
    ⟨rfl, by simp, by simp, Or.inl (by simp)⟩ (by simp [signature, NamesWF]) admissible signature_instance

theorem instantiated_value_rejected {Ψ Q C Γ Φ T} :
    ¬ HasTypeVQ program builtins Ψ Q C Γ Φ
      (.prim "probe" [argument.instR [RangeExpr.top]] [] []) T := by
  intro hv
  obtain ⟨s, u, hs, _, _, ha, _, _, _⟩ := hv.inv_prim (rs := []) rfl
  have hs' : s = signature := by simpa [builtins] using hs.symm
  subst s
  exact instantiated_admits_rejected ha.admits

theorem instantiated_source_rejected (op : OpPrim) {Q C Γ Φ R T e L} :
    ¬ HasTypeCQ program builtins StoreTy.empty Q C Γ Φ R
      ((desugarExpr op .other source).instR [RangeExpr.top]) T e L := by
  intro h
  have hm : (desugarExpr op .other source).instR [RangeExpr.top] =
      .ret (.prim "probe" [argument.instR [RangeExpr.top]] [] []) := by
    simp [source, desugarExpr, Comp.instR, Comp.substR, Comp.mapRangesN, Val.mapRangesN,
      Ty.instR, Ty.substRAt]
  exact instantiated_value_rejected (h.ret_value hm)


def resultType : Ty := .dependentFn (instantiatedTel (Tel.instR [] signature.tel) [argument] [])
def telescope : Tel := .done resultType Eff.empty
def body : Block := .last source

theorem body_typed (op : OpPrim) : BodyTy declarations builtins op Qempty [] [] [] telescope body :=
  .done (.B_Last (surface_typed op))

theorem instantiated_body_rejected (op : OpPrim) {Q} :
    ¬ TelBodyTy program builtins StoreTy.empty Q [] [] []
      (rangeTel [RangeExpr.top] telescope) ((desugarBlock op .tail body).instR [RangeExpr.top]) := by
  intro h
  cases h with
  | done hm => exact instantiated_source_rejected op hm

theorem realizes : declarations.Realizes program := by
  refine ⟨⟨rfl, rfl, rfl, rfl, rfl, rfl⟩, ?_, ?_, ?_, ?_⟩
  · intro f fd hf; cases hf
  · intro i id hi; cases hi
  · exact ⟨by simp [program], by intro key decl h; cases h⟩
  · intro f fd hf; cases hf

theorem code_sourceScoped (op : OpPrim) :
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 := by
  exact ⟨⟨argument_sourceScoped, trivial⟩, trivial, by simp⟩

/-- 値の置換の仮定・表層の本体の導出・範囲深さ1でのソースの形成を満たしても、
範囲の具体化後の本体が型付くとは限らない。 -/
theorem existing_premises_insufficient (op : OpPrim) :
    declarations.Realizes program ∧ builtins.ValueAssumptions program ∧
    BodyTy declarations builtins op Qempty [] [] [] telescope body ∧
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 ∧
    RangesFit [RangeExpr.top] [.path] ∧
    ¬ TelBodyTy program builtins StoreTy.empty Qempty [] [] []
      (rangeTel [RangeExpr.top] telescope) ((desugarBlock op .tail body).instR [RangeExpr.top]) :=
  ⟨realizes, values, body_typed op, code_sourceScoped op,
    RangesFit.top [.path], instantiated_body_rejected op⟩

end
end Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample
