import Benitoite.Release.Refinement.Surface.Program
import Benitoite.Release.Refinement.Surface.OpenSurface
import Benitoite.Release.Refinement.Surface.Scoped
import Benitoite.Release.Refinement.Surface.RangeStandard
import Benitoite.Release.Refinement.ScopeSignatures

/-! # 範囲変数を関数と同種の組込みへ渡す表層の定義 -/
namespace Benitoite.Release.Refinement.Surface.RangeFunctionExamples
noncomputable section
open Scope.Domain

/-- 範囲の種類を保つ、例の対象型。 -/
def targetTy (k : Kind) (ix : RangeIx) : Ty := .scoped "Example.Target" k ix

/-- 対象を調べる純粋組込み。host と endpoint も、引数の範囲を署名の範囲パラメータで表す。 -/
def inspectSig (k : Kind) : PrimSig :=
  ScopeSignatures.pureIn ["target"] [targetTy k (.rvar 0)] (.base .unit) [k]

/-- 対象を受けて Unit を返す、小さい組込みの表。 -/
def builtins (k : Kind) : Builtins where
  sig := fun b => if b = "Example.inspect" then some (inspectSig k) else none
  delta := fun b _ _ _ _ => if b = "Example.inspect" then some (.val (.const .unit)) else none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  valKind := fun o => if o = "Example.Target" then some k else none
  admitsR := fun b rs => b = "Example.inspect" ∧ rs.length = 1

def inspectDecl (k : Kind) : FunDecl where
  tparams := []
  neffs := 0
  names := ["target"]
  params := [targetTy k (.rvar 0)]
  ret := .base .unit
  eff := Eff.empty
  rangeParams := [k]

def declarations (k : Kind) : Declarations where
  funs := fun f => if f = "inspect" then some (inspectDecl k) else none
  cons := fun _ => none

def inspectTel (k : Kind) (ix : RangeIx) : Tel :=
  .param "target" (targetTy k ix) (.done (.base .unit) Eff.empty)

theorem inspectDecl_tel (k : Kind) : (inspectDecl k).tel = inspectTel k (.rvar 0) := rfl

theorem inspectSig_tel (k : Kind) : (inspectSig k).tel = inspectTel k (.rvar 0) := rfl

/-- 例の表の署名は、宣言した範囲・型・行・値の深さを満たす。 -/
theorem inspectSig_scoped (P : Refinement.Program) (k : Kind) :
    PrimSig.Scoped P (inspectSig k) := by
  constructor
  all_goals simp [inspectSig, ScopeSignatures.pureIn, targetTy, PrimSig.tel, signatureTel,
    NamesWF, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped,
    Tel.RangesScoped, rangesScopedTypes, Eff.RangesScoped, Eff.WF,
    Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.HasKind, kindsTel,
    kindsList, kindsEff, TypeCtx.kinds, Tel.Sorted, Ty.Sorted, sortedTys,
    sortedEff, Tel.Declared, Ty.Declared, declaredTys, declaredEff]

/-- 同じ種類の全適格範囲について、表の範囲引数の許容を満たす。 -/
theorem inspect_range (k : Kind) (rs : List RangeExpr) (hr : RangesFit rs [k]) :
    (builtins k).RangeAdmissible "Example.inspect" (inspectSig k) rs := by
  exact ⟨hr.1, hr.2.1, hr.2.2, Or.inr ⟨rfl, hr.1⟩⟩

theorem inspect_annotation (k : Kind) :
    Ty.AnnotationR (declarations k).core [k] [] []
      (.dependentFn (inspectDecl k).tel) := by
  constructor
  all_goals simp [inspectDecl_tel, inspectTel, targetTy, Ty.WF, Tel.WF,
    Ty.WFList, RangeIx.WF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
    Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, Ty.Declared, Tel.Declared,
    declaredTys, declaredEff]

theorem inspect_kinded (k : Kind) :
    Ty.HasKind (declarations k).core [] (.dependentFn (inspectDecl k).tel) .value := by
  simp [inspectDecl_tel, inspectTel, targetTy, Ty.HasKind, kindsTel, kindsEff,
    kindsList, Eff.empty]

def inspectBody : Block :=
  .last (.call (.primName "Example.inspect" [] [] [.rvar 0]) [none] [0]
    (.cons (.local 0) .nil))

/-- R を、同種の対象を受ける組込みの範囲引数へ渡す。 -/
def inspectDef (k : Kind) : Def := ⟨inspectDecl k, inspectBody⟩

def forwardBody : Block :=
  .last (.call (.funName "inspect" [] [] [.rvar 0]) [none] [0]
    (.cons (.local 0) .nil))

/-- R を、別の範囲パラメータ付き関数の範囲引数へ渡す。 -/
def forwardDef (k : Kind) : Def := ⟨inspectDecl k, forwardBody⟩

def instanceRange {k : Kind} (σ : OpenSurface.Instance [k]) : RangeExpr :=
  σ.val.headD .top

theorem instance_val {k : Kind} (σ : OpenSurface.Instance [k]) : σ.val = [instanceRange σ] := by
  obtain ⟨r, hr⟩ := List.length_eq_one_iff.mp σ.property.1
  simp [instanceRange, hr]

private theorem empty_atoms (ρ : Nat → RangeIx) :
    mapRangeAtoms ρ (fun _ => false) = (fun _ => false) := by
  funext a
  simp [mapRangeAtoms]

theorem inspect_instTel (k : Kind) (r : RangeExpr) :
    instantiatedTel (Tel.instR [r] (inspectSig k).tel) [] [] =
      inspectTel k (.fixed r) := by
  simp [inspectSig_tel, inspectTel, targetTy, instantiatedTel, Tel.instR,
    Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges,
    Eff.rawMapRanges, empty_atoms, mapIx, rangeAt, Eff.empty, Tel.norm,
    Ty.norm, Ty.normTys, Eff.norm, Tel.bind, Tel.rawBind, Ty.rawBind,
    Eff.rawBind, typeEnvAt, RangeIx.inst, substAtoms_nil, instAtoms_nil, rowFails]

theorem inspect_primitiveAdmissible (k : Kind) (Γ : Ctx) (Q : NoFailCtx) :
    PrimitiveAdmissible [] Γ.length (inspectSig k) Q [] [] := by
  constructor
  · rfl
  · rfl
  · simp
  · rfl
  · simp
  · simp [inspectSig, ScopeSignatures.pureIn, Eff.empty, Eff.RowsIn, Ty.RowsInList]
  · intro i h
    simp [inspectSig, ScopeSignatures.pureIn, targetTy, Qsig, QTys, QTy,
      QEff, Eff.empty, Benitoite.Release.Qempty] at h
  · intro i h
    simp [inspectSig, ScopeSignatures.pureIn, targetTy, Qsig, QTys, QTy,
      QEff, Eff.empty, Benitoite.Release.Qempty] at h
  · simp [inspectSig, ScopeSignatures.pureIn, targetTy, PrimSig.tel,
      signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.empty]

theorem inspect_signatureInstance (P : Refinement.Program) (k : Kind) (Γ : Ctx)
    (r : RangeExpr) :
    SignatureInstance P [] Γ (Tel.instR [r] (inspectSig k).tel) [] [] [] := by
  constructor
  · simp [inspectSig_tel, inspectTel, targetTy, Tel.instR, Tel.substRAt,
      Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
      empty_atoms, mapIx, rangeAt, Eff.empty, Tel.norm, Ty.norm,
      Ty.normTys, Eff.norm, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
      Eff.WF, Eff.Canonical]
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a kind h; cases h⟩
  · simp [RowAnnotations]
  · simp
  · rw [inspect_instTel]
    constructor
    all_goals simp [inspectTel, targetTy, Ty.WF, Tel.WF, Ty.WFList,
      RangeIx.WF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
      Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, Ty.Declared,
      Tel.Declared, declaredTys, declaredEff]

theorem inspect_admissible (k : Kind) (Γ : Ctx) (Q : NoFailCtx) :
    Admissible (builtins k) [] Γ.length [] 0
      (Qsig [targetTy k (.rvar 0)] (.base .unit) Eff.empty) Q [] [] Eff.empty := by
  have h := inspect_primitiveAdmissible k Γ Q
  exact ⟨⟨rfl, by intro i a p ha; cases ha⟩, h.typeScope, h.rowCount, h.rowScope,
    h.sourceRows, h.sourceQ, h.noFailRows⟩

theorem same_range_argument (k : Kind) : RangeArguments [k] [.rvar 0] [k] := by
  refine ⟨rfl, ?_⟩
  intro i ix kind hi hk
  cases i <;> simp at hi hk
  cases hi; cases hk
  rfl

theorem inspect_openTel (k : Kind) :
    OpenSurface.openRangeTel [.rvar 0] (inspectSig k).tel = (inspectSig k).tel := by
  simp [OpenSurface.openRangeTel, inspectSig_tel, inspectTel, targetTy,
    Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges, empty_atoms,
    mapIx, aliasRangeEnv, Eff.empty, Tel.norm, Ty.norm, Ty.normTys, Eff.norm]

theorem inspect_empty_instantiated (k : Kind) :
    instantiatedTel (inspectSig k).tel [] [] = inspectTel k (.rvar 0) := by
  simp [inspectSig_tel, inspectTel, targetTy, instantiatedTel, Tel.bind,
    Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, RangeIx.inst,
    Eff.empty, substAtoms_nil, instAtoms_nil, rowFails, Tel.norm,
    Ty.norm, Ty.normTys, Eff.norm]

theorem inspect_openSignature (k : Kind) (Γ : Ctx) :
    OpenSurface.Signature (declarations k).core [k] [] Γ (inspectSig k).tel [] [] [] := by
  intro σ
  rw [instance_val σ]
  exact inspect_signatureInstance _ k _ _

theorem inspect_head (k : Kind) (Γ : Ctx) (Q : NoFailCtx) :
    OpenSurface.CallHeadTy (declarations k) (builtins k) [k] Q [] Γ
      (.primName "Example.inspect" [] [] [.rvar 0]) (inspectTel k (.rvar 0)) [] := by
  have h := OpenSurface.CallHeadTy.prim (D := declarations k) (B := builtins k)
    (ks := [k]) (Q := Q) (C := []) (Γ := Γ) (b := "Example.inspect")
    (s := inspectSig k) (ts := []) (es := []) (xs := [.rvar 0]) rfl
    (inspectSig_scoped _ k) (same_range_argument k)
    (by
      intro σ
      rw [instance_val σ]
      simpa [OpenSurface.closeRange, RangeIx.inst] using
        inspect_range k [instanceRange σ] (by rw [← instance_val σ]; exact σ.property))
    (by simp [inspectSig, ScopeSignatures.pureIn, NamesWF])
    (fun _ => inspect_primitiveAdmissible k Γ Q)
    (by rw [inspect_openTel]; exact inspect_openSignature k Γ)
  simpa only [inspect_openTel, inspect_empty_instantiated] using h

theorem forward_head (k : Kind) (Γ : Ctx) (Q : NoFailCtx) :
    OpenSurface.CallHeadTy (declarations k) (builtins k) [k] Q [] Γ
      (.funName "inspect" [] [] [.rvar 0]) (inspectTel k (.rvar 0)) [] := by
  have hsame : (inspectDecl k).tel = (inspectSig k).tel := rfl
  have h := OpenSurface.CallHeadTy.fn (D := declarations k) (B := builtins k)
    (ks := [k]) (Q := Q) (C := []) (Γ := Γ) (f := "inspect")
    (fd := inspectDecl k) (ts := []) (es := []) (xs := [.rvar 0]) rfl rfl
    (by simp [inspectDecl, FunDecl.coreNames, FunDecl.coreParams,
      FunDecl.dictTys, internalNames, NamesWF])
    (same_range_argument k)
    (by
      change Tel.RangesScoped 1 (inspectTel k (.rvar 0))
      simp [inspectTel, targetTy, Tel.RangesScoped, Ty.RangesScoped,
        Eff.RangesScoped, rangesScopedTypes, RangeIx.WF, Eff.empty])
    (inspect_annotation k).wf
    (fun _ => inspect_admissible k Γ Q)
    (by rw [hsame, inspect_openTel]; exact inspect_openSignature k Γ)
  simpa only [hsame, inspect_openTel, inspect_empty_instantiated] using h

/-- 元の呼出しのラベル・引数順・依存列の条件を満たす、表層の有限な呼出し。 -/
theorem source_call (k : Kind) (Q : NoFailCtx) (op : OpPrim) (f : Expr)
    (hh : OpenSurface.CallHeadTy (declarations k) (builtins k) [k] Q []
      (Ctx.extend [] (targetTy k (.rvar 0))) f (inspectTel k (.rvar 0)) []) :
    OpenSurface.HasTypeQ (declarations k) (builtins k) [k] op Q [] []
      (Ctx.extend [] (targetTy k (.rvar 0))) [] (some (.base .unit)) .tail
      (.call f [none] [0] (.cons (.local 0) .nil)) (.base .unit) Eff.empty := by
  apply OpenSurface.HasTypeQ.E_CallDirect (r := .base .unit) (e := Eff.empty) hh
  · simp [CallOk, inspectTel, Tel.names, telBinders]
  · exact .cons (.E_Local rfl (by simp [targetTy, Ordinary, Ty.shiftV])) .nil
  · simp [inspectTel, targetTy, Tel.shiftV, bindParams, liftMany_one, boundVars,
      recordFields, fieldAt, Ctx.extend, Ty.shiftV]
    apply OpenSurface.ValsTel.param
    · exact ⟨by simp [Ty.WF, RangeIx.WF], trivial, trivial⟩
    · exact .var rfl (by simp [Ordinary])
    · exact .refl
    · simpa [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind,
        Eff.rawBind, Eff.empty, valEnv, typeEnvAt, RangeIx.inst,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm,
        Ty.normTys, Eff.norm, Tel.shiftV, Ty.shiftV, Eff.shiftV, targetTy,
        Ctx.extend, liftMany_one] using
        (OpenSurface.ValsTel.done (D := declarations k) (B := builtins k) (ks := [k])
          (C := []) (Γ0 := Ctx.extend [] (targetTy k (.rvar 0))) (k := 1)
          (Γ := [some (targetTy k (.rvar 0)), some (targetTy k (.rvar 0))]) (Φ := [])
          (a := .base .unit) (e := Eff.empty)
          ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩)
  · exact .refl
  · simp [Eff.shiftV, Eff.empty]
    exact Eff.Covers.refl _ _ _
  · exact ⟨trivial, trivial, trivial⟩

theorem inspect_source_body (k : Kind) (Q : NoFailCtx) (op : OpPrim) :
    OpenSurface.BodyTy (declarations k) (builtins k) [k] op Q [] [] []
      (inspectDecl k).tel inspectBody := by
  rw [inspectDecl_tel]
  exact .param (.done (.B_Last (source_call k Q op _ (inspect_head k _ Q))))

theorem forward_source_body (k : Kind) (Q : NoFailCtx) (op : OpPrim) :
    OpenSurface.BodyTy (declarations k) (builtins k) [k] op Q [] [] []
      (inspectDecl k).tel forwardBody := by
  rw [inspectDecl_tel]
  exact .param (.done (.B_Last (source_call k Q op _ (forward_head k _ Q))))

theorem inspect_source_scoped : inspectBody.Scoped 0 0 1 (nr := 1) := by
  simp [inspectBody, Block.Scoped, Expr.Scoped, Exprs.Scoped, RangeIx.WF,
    scopedTypes, scopedRows]

theorem forward_source_scoped : forwardBody.Scoped 0 0 1 (nr := 1) := by
  simp [forwardBody, Block.Scoped, Expr.Scoped, Exprs.Scoped, RangeIx.WF,
    scopedTypes, scopedRows]

/-- 合成表の登録済みの署名には、host の範囲パラメータを持つものがない。 -/
theorem standard_no_host_range (row : StandardModel.Primitive) :
    .host ∉ row.signature.rkinds := by
  cases row <;> decide

def endpointTy (ix : RangeIx) : Ty := .opaque "Http.RequestIn" ix

def endpointTel (ix : RangeIx) : Tel :=
  .param "request" (endpointTy ix) (.done (endpointTy ix) Eff.empty)

def endpointDef : Def where
  tparams := []
  neffs := 0
  names := ["request"]
  params := [endpointTy (.rvar 0)]
  ret := endpointTy (.rvar 0)
  eff := Eff.empty
  rangeParams := [.endpoint]
  body := .last (.call (.primName "Http.widenRequestIn" [] [] [.rvar 0, .rvar 0])
    [none] [0] (.cons (.local 0) .nil))

theorem endpoint_tel : endpointDef.toFunDecl.tel = endpointTel (.rvar 0) := rfl

theorem endpoint_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "Http.widenRequestIn" = some ScopeSignatures.widenRequestIn := by
  rfl

theorem endpoint_primitive_scoped (P : Refinement.Program) :
    PrimSig.Scoped P ScopeSignatures.widenRequestIn := by
  constructor
  all_goals simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn,
    PrimSig.tel, signatureTel, NamesWF, Ty.SourceScoped, Ty.WF, Tel.WF,
    Ty.WFList, RangeIx.WF, Ty.RowsIn, Tel.RowsIn, Ty.RowsInList,
    Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes,
    Eff.RangesScoped, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
    Ty.normTys, Ty.HasKind, kindsTel, kindsList, kindsEff, TypeCtx.kinds,
    Tel.Sorted, Ty.Sorted, sortedTys, sortedEff, Tel.Declared,
    Ty.Declared, declaredTys, declaredEff]

theorem endpoint_range (P : Refinement.Program) (r : RangeExpr)
    (hr : RangesFit [r] [.endpoint]) :
    (StandardModel.builtins P).RangeAdmissible "Http.widenRequestIn"
      ScopeSignatures.widenRequestIn [r, r] := by
  refine ⟨rfl, ?_, ?_, Or.inr ?_⟩
  · intro i r' k hi hk
    cases i with
    | zero =>
      simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn] at hi hk
      cases hi; cases hk
      exact hr.2.1 0 r .endpoint rfl rfl
    | succ i =>
      cases i <;> simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn] at hi hk
      cases hi; cases hk
      exact hr.2.1 0 r .endpoint rfl rfl
  · intro r' hi
    simp only [List.mem_cons, List.not_mem_nil, or_false, or_self] at hi
    subst r'
    exact hr.2.2 r (by simp)
  · change ScopeSignatures.admitsR "Http.widenRequestIn" [r, r]
    exact ⟨r, r, rfl, RangeExpr.Covers.refl _⟩

theorem endpoint_open_instantiated :
    instantiatedTel (OpenSurface.openRangeTel [.rvar 0, .rvar 0]
      ScopeSignatures.widenRequestIn.tel) [] [] = endpointTel (.rvar 0) := by
  simp [OpenSurface.openRangeTel, ScopeSignatures.widenRequestIn,
    ScopeSignatures.pureIn, PrimSig.tel, signatureTel, endpointTel,
    endpointTy, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
    empty_atoms, mapIx, aliasRangeEnv, Eff.empty, Tel.norm, Ty.norm,
    Ty.normTys, Eff.norm, instantiatedTel, Tel.bind, Tel.rawBind,
    Ty.rawBind, Eff.rawBind, typeEnvAt, RangeIx.inst,
    substAtoms_nil, instAtoms_nil, rowFails]

theorem endpoint_signature (P : Refinement.Program) (Γ : Ctx) (r : RangeExpr) :
    SignatureInstance P [] Γ
      (Tel.instR [r] (OpenSurface.openRangeTel [.rvar 0, .rvar 0]
        ScopeSignatures.widenRequestIn.tel)) [] [] [] := by
  have ht : OpenSurface.openRangeTel [.rvar 0, .rvar 0]
      ScopeSignatures.widenRequestIn.tel = endpointTel (.rvar 0) := by
    simp [OpenSurface.openRangeTel, ScopeSignatures.widenRequestIn,
      ScopeSignatures.pureIn, PrimSig.tel, signatureTel, endpointTel,
      endpointTy, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
      empty_atoms, mapIx, aliasRangeEnv, Eff.empty, Tel.norm, Ty.norm,
      Ty.normTys, Eff.norm]
  rw [ht]
  have hi : instantiatedTel (Tel.instR [r] (endpointTel (.rvar 0))) [] [] =
      endpointTel (.fixed r) := by
    simp [endpointTel, endpointTy, instantiatedTel, Tel.instR, Tel.substRAt,
      Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
      empty_atoms, mapIx, rangeAt, Eff.empty, Tel.norm, Ty.norm,
      Ty.normTys, Eff.norm, Tel.bind, Tel.rawBind, Ty.rawBind,
      Eff.rawBind, typeEnvAt, RangeIx.inst, substAtoms_nil, instAtoms_nil, rowFails]
  constructor
  · simp [endpointTel, endpointTy, Tel.instR, Tel.substRAt,
      Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
      empty_atoms, mapIx, rangeAt, Eff.empty, Tel.norm, Ty.norm,
      Ty.normTys, Eff.norm, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
      Eff.WF, Eff.Canonical]
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a kind h; cases h⟩
  · simp [RowAnnotations]
  · simp
  · rw [hi]
    constructor
    all_goals simp [endpointTel, endpointTy, Ty.WF, Tel.WF, Ty.WFList,
      RangeIx.WF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
      Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, Ty.Declared,
      Tel.Declared, declaredTys, declaredEff]

theorem endpoint_primitiveAdmissible (Γ : Ctx) (Q : NoFailCtx) :
    PrimitiveAdmissible [] Γ.length ScopeSignatures.widenRequestIn Q [] [] := by
  constructor
  · rfl
  · rfl
  · simp
  · rfl
  · simp
  · simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn,
      Eff.empty, Eff.RowsIn, Ty.RowsInList]
  · intro i h
    simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn,
      Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at h
  · intro i h
    simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn,
      Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at h
  · simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn,
      PrimSig.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList,
      Eff.RowsIn, Eff.empty]

theorem endpoint_head (P : Refinement.Program) (Γ : Ctx) (Q : NoFailCtx) :
    OpenSurface.CallHeadTy (declarations .endpoint) (StandardModel.builtins P)
      [.endpoint] Q [] Γ (.primName "Http.widenRequestIn" [] [] [.rvar 0, .rvar 0])
      (endpointTel (.rvar 0)) [] := by
  have h := OpenSurface.CallHeadTy.prim (D := declarations .endpoint)
    (B := StandardModel.builtins P) (ks := [.endpoint]) (Q := Q)
    (C := []) (Γ := Γ) (b := "Http.widenRequestIn")
    (s := ScopeSignatures.widenRequestIn) (ts := []) (es := [])
    (xs := [.rvar 0, .rvar 0]) (endpoint_lookup P) (endpoint_primitive_scoped _)
    (by
      refine ⟨rfl, ?_⟩
      intro i ix k hi hk
      cases i with
      | zero =>
        simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn] at hi hk
        cases hi; cases hk; rfl
      | succ i =>
        cases i <;> simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn] at hi hk
        cases hi; cases hk; rfl)
    (by
      intro σ
      rw [instance_val σ]
      simpa [OpenSurface.closeRange, RangeIx.inst] using
        endpoint_range P (instanceRange σ)
          (by rw [← instance_val σ]; exact σ.property))
    (by simp [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn, NamesWF])
    (fun _ => endpoint_primitiveAdmissible Γ Q)
    (by
      intro σ
      rw [instance_val σ]
      exact endpoint_signature _ _ _)
  simpa only [endpoint_open_instantiated] using h

/-- 合成表の Http.widenRequestIn へ、呼出し元の endpoint 範囲 R を両位置で渡す。 -/
theorem endpoint_standard_source_body (P : Refinement.Program) (Q : NoFailCtx) (op : OpPrim) :
    OpenSurface.BodyTy (declarations .endpoint) (StandardModel.builtins P) [.endpoint]
      op Q [] [] [] endpointDef.toFunDecl.tel endpointDef.body := by
  rw [endpoint_tel]
  apply OpenSurface.BodyTy.param
  apply OpenSurface.BodyTy.done
  apply OpenSurface.HasBlockQ.B_Last
  apply OpenSurface.HasTypeQ.E_CallDirect (r := endpointTy (.rvar 0)) (e := Eff.empty)
    (endpoint_head P _ Q)
  · simp [CallOk, endpointTel, Tel.names, telBinders]
  · exact .cons (.E_Local rfl (by simp [endpointTy, Ordinary, Ty.shiftV])) .nil
  · simp [endpointTel, endpointTy, Tel.shiftV, bindParams, liftMany_one,
      boundVars, recordFields, fieldAt, Ctx.extend, Ty.shiftV]
    apply OpenSurface.ValsTel.param
    · exact ⟨by simp [Ty.WF, RangeIx.WF], trivial, trivial⟩
    · exact .var rfl (by simp [Ordinary])
    · exact .refl
    · simpa [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind,
        Eff.rawBind, Eff.empty, valEnv, typeEnvAt, RangeIx.inst,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm,
        Ty.normTys, Eff.norm, Tel.shiftV, Ty.shiftV, Eff.shiftV,
        endpointTy, Ctx.extend, liftMany_one] using
        (OpenSurface.ValsTel.done (D := declarations .endpoint)
          (B := StandardModel.builtins P) (ks := [.endpoint]) (C := [])
          (Γ0 := Ctx.extend [] (endpointTy (.rvar 0))) (k := 1)
          (Γ := [some (endpointTy (.rvar 0)), some (endpointTy (.rvar 0))]) (Φ := [])
          (a := endpointTy (.rvar 0)) (e := Eff.empty)
          ⟨⟨by simp [endpointTy, Ty.WF, RangeIx.WF], trivial, rfl⟩,
            ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩)
  · exact .refl
  · simp [Eff.shiftV, Eff.empty]
    exact Eff.Covers.refl _ _ _
  · exact ⟨by simp [endpointTy, Ty.WF, RangeIx.WF], trivial, trivial⟩

/-- 元の表層の呼出し条件を保った有限導出から、範囲付きの関数定義を受理する。 -/
theorem inspect_def_wellTyped (k : Kind) (op : OpPrim) :
    Def.WellTyped (declarations k) (builtins k) op (inspectDef k) := by
  refine ⟨?_, inspect_kinded k, inspect_annotation k, ?_⟩
  · simp [inspectDef, inspectDecl, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF]
  · change BodyTyR (declarations k) (builtins k) op (QTel (inspectDecl k).tel)
      [k] [] [] [] (inspectDecl k).tel inspectBody
    simpa only [BodyTyR, List.cons_ne_nil, ↓reduceIte] using
      inspect_source_body k (QTel (inspectDecl k).tel) op

/-- 関数から別の範囲パラメータ付き関数へ、同じ rvar を渡す定義の受理。 -/
theorem forward_def_wellTyped (k : Kind) (op : OpPrim) :
    Def.WellTyped (declarations k) (builtins k) op (forwardDef k) := by
  refine ⟨?_, inspect_kinded k, inspect_annotation k, ?_⟩
  · simp [forwardDef, inspectDecl, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF]
  · change BodyTyR (declarations k) (builtins k) op (QTel (inspectDecl k).tel)
      [k] [] [] [] (inspectDecl k).tel forwardBody
    simpa only [BodyTyR, List.cons_ne_nil, ↓reduceIte] using
      forward_source_body k (QTel (inspectDecl k).tel) op

theorem path_forward_def_wellTyped (op : OpPrim) :
    Def.WellTyped (declarations .path) (builtins .path) op (forwardDef .path) :=
  forward_def_wellTyped .path op

theorem host_primitive_def_wellTyped (op : OpPrim) :
    Def.WellTyped (declarations .host) (builtins .host) op (inspectDef .host) :=
  inspect_def_wellTyped .host op

theorem endpoint_primitive_def_wellTyped (op : OpPrim) :
    Def.WellTyped (declarations .endpoint) (builtins .endpoint) op (inspectDef .endpoint) :=
  inspect_def_wellTyped .endpoint op

/-- 標準合成表の Http.widenRequestIn へ、endpoint 範囲変数を渡す関数定義の受理。 -/
theorem endpoint_standard_def_wellTyped (P : Refinement.Program) (op : OpPrim) :
    Def.WellTyped (declarations .endpoint) (StandardModel.builtins P) op endpointDef := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · simp [endpointDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF]
  · simp [endpoint_tel, endpointTel, endpointTy, Ty.HasKind, kindsTel, kindsEff,
      kindsList, Eff.empty, TypeCtx.kinds]
  · change Ty.AnnotationR (declarations .endpoint).core [.endpoint] [] []
      (.dependentFn (endpointTel (.rvar 0)))
    constructor
    all_goals simp [endpointTel, endpointTy, Ty.WF, Tel.WF,
      Ty.WFList, RangeIx.WF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
      Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, Ty.Declared, Tel.Declared,
      declaredTys, declaredEff]
  · change BodyTyR (declarations .endpoint) (StandardModel.builtins P) op
      (QTel endpointDef.toFunDecl.tel) [.endpoint] [] [] [] endpointDef.toFunDecl.tel endpointDef.body
    simpa only [BodyTyR, List.cons_ne_nil, ↓reduceIte] using
      endpoint_standard_source_body P (QTel endpointDef.toFunDecl.tel) op

end
end Benitoite.Release.Refinement.Surface.RangeFunctionExamples
