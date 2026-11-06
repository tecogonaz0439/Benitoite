import Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample
import Benitoite.Release.Refinement.ReferenceCalls

/-! # 組込みの署名の範囲変数と、呼出し元の範囲の具体化

型引数の許容と制約の照合が常に成立しても、署名に宣言されていない範囲変数は
呼出し元の範囲と同時には具体化されない。値の置換の仮定だけでは署名の有効範囲は従わない。
-/
namespace Benitoite.Release.Refinement.Surface.RangeSignatureExample
noncomputable section

abbrev program := RangeAdmissibilityExample.program
abbrev declarations := RangeAdmissibilityExample.declarations
abbrev argument := RangeAdmissibilityExample.argument

/-- 範囲引数を取らず、未宣言の範囲変数を潜在効果に含む参照型を返す署名。 -/
def signature : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .reference argument
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none

def builtins : Builtins :=
  { RangeAdmissibilityExample.builtins with
    sig := fun b => if b = "probe" then some signature else none }

/-- 型引数の許容は範囲の具体化に依存しない。制約の照合も常に成立する。 -/
theorem admits_and_sat (C : List TParam) (ts : List Ty) (rs : List RangeExpr) (a : Ty) (p : TParam) :
    signature.admits C ts ∧ signature.admits C (ts.map (Ty.instR rs)) ∧
    builtins.sat C a p ∧ builtins.sat C (a.instR rs) p := ⟨trivial, trivial, trivial, trivial⟩

theorem values : builtins.ValueAssumptions program where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs _ _ _ _
    have he : sg = signature := by
      simp only [builtins, RangeAdmissibilityExample.builtins] at hs
      split at hs
      · exact (Option.some.inj hs).symm
      · cases hs
    subst sg
    trivial
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    have he : sg = signature := by
      simp only [builtins, RangeAdmissibilityExample.builtins] at hs
      split at hs
      · exact (Option.some.inj hs).symm
      · cases hs
    subst sg
    trivial

private theorem argument_normal : argument.norm = argument := by
  simp [argument, RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
    Ty.norm, Ty.normTys, Eff.norm]

private theorem mapped_atoms (ρ : Nat → RangeIx) :
    mapRangeAtoms ρ (fun a => decide (a = .name "Read" (.rvar 0))) =
      (fun a => decide (a = .name "Read" (ρ 0))) := by
  funext a
  simp [mapRangeAtoms, mapAtomRanges, mapIx, eq_comm]

private theorem mapped_empty (ρ : Nat → RangeIx) :
    mapRangeAtoms ρ (fun _ => false) = (fun _ => false) := by
  funext a
  simp [mapRangeAtoms]

private theorem result_annotation : Ty.Annotation declarations.core [] [] (.reference argument) := by
  constructor <;>
    simp [argument, RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
      Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.norm, Ty.normTys,
      Ty.Sorted, sortedTys, sortedEff, Ty.Declared, declaredTys, declaredEff]

private theorem signature_tel : Tel.instR [] signature.tel = .done (.reference argument) Eff.empty := by
  simp [signature, PrimSig.tel, signatureTel, Tel.instR, Tel.substRAt, Tel.mapRanges,
    Tel.norm,
    Ty.norm, Eff.norm, Eff.empty, argument_normal]

private theorem instantiated_tel : instantiatedTel (Tel.instR [] signature.tel) [] [] =
    .done (.reference argument) Eff.empty := by
  rw [signature_tel]
  simp [instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, argument,
    RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
    typeEnvAt, substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys,
    Eff.norm, Eff.empty]

private theorem admissible : PrimitiveAdmissible [] 0 signature Qempty [] [] := by
  constructor
  · rfl
  · trivial
  · simp
  · rfl
  · simp
  · simp [signature, Eff.empty, Eff.RowsIn, Ty.RowsInList]
  · simp [signature, Qsig, QTys, QTy, QEff, argument, RangeAdmissibilityExample.argument,
      RangeAdmissibilityExample.effect, Eff.empty, Benitoite.Release.Qempty]
  · simp [signature, Qsig, QTys, QTy, QEff, argument, RangeAdmissibilityExample.argument,
      RangeAdmissibilityExample.effect, Eff.empty, Benitoite.Release.Qempty, RowTransport]
  · simp [signature, PrimSig.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, argument,
      RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
      Ty.RowsInList, Eff.RowsIn, Eff.empty]

private theorem signature_instance : SignatureInstance declarations.core [] []
    (Tel.instR [] signature.tel) [] [] [] := by
  constructor
  · rw [signature_tel]
    exact ⟨result_annotation.wf, trivial, rfl⟩
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a k ha; cases i <;> cases ha⟩
  · simp [RowAnnotations]
  · simp
  · rw [instantiated_tel]
    exact ⟨⟨result_annotation.wf, trivial, rfl⟩,
      ⟨result_annotation.sorted, trivial⟩, ⟨result_annotation.declared, trivial⟩⟩

def source : Expr := .primName "probe" [] [] []
def resultType : Ty := .dependentFn (.done (.reference argument) Eff.empty)
def telescope : Tel := .done resultType Eff.empty
def body : Block := .last source

theorem surface_typed (op : OpPrim) {R p} :
    HasTypeQ declarations builtins op Qempty [] [] [] [] R p source resultType Eff.empty := by
  have h := HasTypeQ.E_Prim (D := declarations) (B := builtins) (Q := Qempty)
    (Δ := []) (C := []) (Γ := []) (Φ := []) (opPrim := op) (R := R) (p := p)
    (CallHeadTy.prim (b := "probe") (s := signature) (ts := []) (es := []) (rs := [])
      rfl
      ⟨rfl, by simp, by simp, Or.inl (by simp)⟩
      (by simp [signature, NamesWF]) admissible signature_instance)
  simpa only [List.map_nil, instantiated_tel, source, resultType] using h

theorem body_typed (op : OpPrim) : BodyTy declarations builtins op Qempty [] [] [] telescope body :=
  .done (.B_Last (surface_typed op))

/-- 脱糖した本体は範囲深さ1でソースとして形成される。 -/
theorem code_sourceScoped (op : OpPrim) :
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 := by
  exact ⟨trivial, trivial, by simp⟩

/-- 結果の依存列も範囲深さ1で形成される。 -/
theorem telescope_sourceScoped : (Ty.dependentFn telescope).SourceScoped 1 0 0 0 := by
  constructor
  · simp [telescope, resultType, argument, RangeAdmissibilityExample.argument,
      RangeAdmissibilityExample.effect, Ty.WF, Tel.WF, Ty.WFList, NamesWF,
      Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, Ty.normTys]
  · constructor
    · simp [telescope, resultType, argument, RangeAdmissibilityExample.argument,
        RangeAdmissibilityExample.effect, Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.empty]
    · simp [telescope, resultType, argument, RangeAdmissibilityExample.argument,
        RangeAdmissibilityExample.effect, Ty.RangesScoped, Tel.RangesScoped,
        rangesScopedTypes, Eff.RangesScoped, Eff.empty, RangeIx.WF]

/-- 署名は自身の宣言した範囲深さ0では形成されない。 -/
theorem signature_not_scoped : ¬ signature.Scoped program := by
  intro h
  have hs := h.source.2.2
  simp [signature, PrimSig.tel, signatureTel, argument, RangeAdmissibilityExample.argument,
    RangeAdmissibilityExample.effect, Ty.RangesScoped, Tel.RangesScoped,
    rangesScopedTypes, Eff.RangesScoped, RangeIx.WF] at hs

private theorem closed_argument : argument.instR [RangeExpr.top] =
    .fn [] [] (.base .unit) (RangeAdmissibilityExample.effect (.fixed RangeExpr.top)) := by
  simp [argument, RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
    Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, mapRangesTys, Eff.rawMapRanges,
    mapped_atoms, rangeAt, Ty.norm, Ty.normTys, Eff.norm]

private theorem argument_changes : argument.norm ≠ (argument.instR [RangeExpr.top]).norm := by
  rw [argument_normal, closed_argument]
  intro h
  have he := congrArg (fun (a : Ty) => match a with
    | .fn _ _ _ e => Eff.test e (.name "Read" (.rvar 0))
    | _ => false) h
  simp [argument, RangeAdmissibilityExample.argument, RangeAdmissibilityExample.effect,
    Ty.norm, Ty.normTys, Eff.norm, Eff.test, Eff.atoms] at he

/-- 参照型の不変性により、署名に残った範囲変数と具体化された結果型は結べない。 -/
theorem instantiated_value_rejected {Ψ Q C Γ Φ} :
    ¬ HasTypeVQ program builtins Ψ Q C Γ Φ (.prim "probe" [] [] [])
      (rangeTy [RangeExpr.top] resultType) := by
  intro hv
  obtain ⟨s, u, hs, _, _, _, _, hu, ht⟩ := hv.inv_prim (rs := []) rfl
  have he : s = signature := by simpa [builtins] using hs.symm
  subst s
  rw [instantiated_tel] at ht
  have hcore : (rangeTy [RangeExpr.top] resultType).fnCore =
      some (.done (.reference (argument.instR [RangeExpr.top])) Eff.empty) := by
    simp [rangeTy, resultType, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
      Tel.rawMapRanges, Eff.rawMapRanges, mapped_empty, Eff.empty,
      Ty.norm, Tel.norm, Eff.norm, Ty.fnCore_foldFn]
  rw [hcore] at hu
  cases hu
  obtain ⟨r, e, hr, hle, _⟩ := ht.done_outputs
  cases hr
  obtain ⟨x, hx, heq⟩ := hle.refCore rfl
  have hx' : x = argument.instR [RangeExpr.top] := (Option.some.inj hx).symm
  subst x
  exact argument_changes heq

theorem instantiated_body_rejected (op : OpPrim) :
    ¬ TelBodyTy program builtins StoreTy.empty Qempty [] [] []
      (rangeTel [RangeExpr.top] telescope) ((desugarBlock op .tail body).instR [RangeExpr.top]) := by
  intro h
  have hm : (desugarBlock op .tail body).instR [RangeExpr.top] = .ret (.prim "probe" [] [] []) := by
    simp [body, source, desugarBlock, desugarExpr, Comp.instR, Comp.substR,
      Comp.mapRangesN, Val.mapRangesN]
  have ht : rangeTel [RangeExpr.top] telescope =
      .done (rangeTy [RangeExpr.top] resultType) Eff.empty := by
    simp [rangeTel, telescope, rangeTy, Tel.instR, Tel.substRAt, Tel.mapRanges,
      Tel.rawMapRanges, Eff.rawMapRanges, mapped_empty, Eff.empty, Eff.norm,
      Tel.norm, Ty.instR, Ty.substRAt, Ty.mapRanges]
  rw [ht] at h
  cases h with
  | done hc => exact instantiated_value_rejected (hc.ret_value hm)

/-- 許容の全具体化と値の置換の仮定だけでは、本体の全具体化は従わない。 -/
theorem admissibility_premises_insufficient (op : OpPrim) :
    declarations.Realizes program ∧ builtins.ValueAssumptions program ∧
    (∀ C ts rs a p, signature.admits C ts ∧ signature.admits C (ts.map (Ty.instR rs)) ∧
      builtins.sat C a p ∧ builtins.sat C (a.instR rs) p) ∧
    BodyTy declarations builtins op Qempty [] [] [] telescope body ∧
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 ∧
    (Ty.dependentFn telescope).SourceScoped 1 0 0 0 ∧
    ¬ signature.Scoped program ∧
    RangesFit [RangeExpr.top] [.path] ∧
    ¬ TelBodyTy program builtins StoreTy.empty Qempty [] [] []
      (rangeTel [RangeExpr.top] telescope) ((desugarBlock op .tail body).instR [RangeExpr.top]) :=
  ⟨RangeAdmissibilityExample.realizes, values, admits_and_sat, body_typed op,
    code_sourceScoped op, telescope_sourceScoped, signature_not_scoped,
    RangesFit.top [.path], instantiated_body_rejected op⟩

end
end Benitoite.Release.Refinement.Surface.RangeSignatureExample
