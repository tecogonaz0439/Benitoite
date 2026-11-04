import Lean
import Benitoite

/-! F04 の全称命題に対する、引数名と型列の長さが異なる署名の反例。 -/
namespace L50ShapeObstruction
open Benitoite.Release.Refinement
open Benitoite.Scope.Domain
noncomputable section

private def signature : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := [.opaque "Scope.PathIn" (.rvar 0)]
  ret := .base .unit
  eff := .mk (fun a => decide (a = .name "File.Read" (.rvar 0))) []
  admits := fun _ ts => ts = []
  kind := .io
  opEff := some "File.Read"
  rkinds := [.path]
  shape := .single .path 0

private def builtins : Builtins where
  sig := fun _ => some signature
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => some ["bad"]
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := fun _ => some .path
  valKind := fun _ => some .path

private theorem shape_ok : builtins.ShapeOk "bad" signature := by
  refine ⟨"File.Read", ["bad"], rfl, rfl, rfl, by simp, ?_⟩
  exact ⟨rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩

private theorem instantiated :
    instantiatedTel (Tel.instR [.top] signature.tel) [] [] =
      .done (.base .unit) (Eff.single "File.Read") := by
  have atoms : mapRangeAtoms (rangeAt 0 [.top])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" .top)) := by
    funext a
    simp [mapRangeAtoms, mapAtomRanges, mapIx, rangeAt, RangeIx.top, eq_comm]
  simp [atoms, signature, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR,
    Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
    Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys,
    Eff.norm, Eff.single, typeEnvAt, substAtoms_nil, instAtoms_nil,
    rowFails]

private theorem arguments (P : Program) (Ψ : StoreTy) :
    BuiltinArgs P builtins Ψ "bad" signature [] [] [.top] []
      (.base .unit) (Eff.single "File.Read") := by
  constructor
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [signature, Eff.RowsIn, Ty.RowsInList]
    · intro i h; simp [Qsig, signature, QTys, QTy, QEff, Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig, signature, QTys, QTy, QEff, Benitoite.Release.Qempty] at h
    · simp [signature, PrimSig.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn]
  · refine ⟨rfl, ?_, ?_, ?_⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk; trivial
    · intro r hr; simp at hr; subst r; trivial
    · exact Or.inl (by intro r hr; simpa using hr)
  · constructor
    · simp [signature, PrimSig.tel, signatureTel, Tel.instR, Tel.substRAt,
        Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
        Ty.WF, Ty.WFList, Tel.WF, Tel.norm, Ty.norm, Eff.norm, Eff.WF, Eff.Canonical]
    · simp [TypeAnnotations]
    · simp [TypeArgsKinded, signature]
    · simp [RowAnnotations]
    · simp
    · rw [instantiated]
      exact ⟨by trivial, by trivial, by trivial⟩
  · rw [instantiated]; exact .done ⟨by trivial, by trivial, by trivial⟩
  · simp
  · simp
  · simp
  · exact ⟨trivial, rfl⟩
  · exact ⟨by trivial, by simp [Eff.Canonical, Eff.norm, Eff.single]⟩

/-- 全P・全ストア・全σでF04の前提が成立し、その結論が不成立となる。 -/
theorem counterexample (P : Program) (Ψ : StoreTy) (σ : PathEnv) :
    builtins.ShapeOk "bad" signature ∧ signature.shape = .single .path 0 ∧
    BuiltinArgs P builtins Ψ "bad" signature [] [] [.top] []
      (.base .unit) (Eff.single "File.Read") ∧
    (∀ w ∈ ([] : List Val), w.Adequate σ) ∧
    ¬ (∃ r t, ([.top] : List RangeExpr) = [r] ∧
      (([] : List Val)[0]?).bind Val.target? = some t ∧
      r.Mem σ .path t ∧ signature.shapeAt [] = .single .path 0) := by
  refine ⟨shape_ok, rfl, arguments P Ψ, by simp, ?_⟩
  simp

/-- detail.md の F04 と同じ全称命題。成立を仮定する欄ではない。 -/
def F04Type : Prop := ∀ {P B Ψ b sg ts es rs ws a e k p σ},
    B.ShapeOk b sg → sg.shape = .single k p →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ w ∈ ws, w.Adequate σ) →
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p

/-- 前提の成立は宣言表にこの署名が存在する場合にも残る。 -/
theorem signature_lookup : builtins.sig "bad" = some signature := rfl

/-- この反例の署名は、既存の宣言の形成条件では拒否される。 -/
theorem not_scoped (P : Program) : ¬ PrimSig.Scoped P signature := by
  intro h
  have count := h.names.1
  simp [signature] at count

/-- 任意P・ストア・σを使い、F04の全称命題そのものを否定する。 -/
theorem f04_false (P : Program) (Ψ : StoreTy) (σ : PathEnv) : ¬ F04Type := by
  intro claim
  obtain ⟨sh, single, args, adequate, no⟩ := counterexample P Ψ σ
  exact no (claim sh single args adequate)

/-- 名前の形成の追加前提が、元の反例の署名を拒否する。 -/
theorem not_namesWF : ¬ NamesWF signature.names signature.params := by
  intro h
  simp [NamesWF, signature] at h

/-- 名前の形成を前提に追加した完全署名。 -/
def F04WithNamesType : Prop := ∀ {P B Ψ b sg ts es rs ws a e k p σ},
    B.ShapeOk b sg → sg.shape = .single k p → NamesWF sg.names sg.params →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ w ∈ ws, w.Adequate σ) →
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p

/-- 修正した全称命題は、本番の一般証明から成り立つ。 -/
theorem f04_with_names : F04WithNamesType := by
  intro P B Ψ b sg ts es rs ws a e k p σ sh hs hn args had
  exact sh.single_target hs hn args had

end
end L50ShapeObstruction
