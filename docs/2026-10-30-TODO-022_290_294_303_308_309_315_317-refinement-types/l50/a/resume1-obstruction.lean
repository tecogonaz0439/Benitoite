import Lean
import Benitoite

/-! 名前の形成を前提に持たない観測許容の全称命題の反例。 -/
namespace L50ObservationObstruction
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

private def range : RangeExpr := .absolute (.path (.exact []))
private def observed : Target := .path ["outside"]
private def effect : Eff := .mk (fun a => decide (a = .name "File.Read" (.fixed range))) []

private def builtins : Builtins where
  sig := fun _ => some signature
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ ws out obs => ws = [] ∧ out = .val (.const .unit) ∧ obs = [observed]
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => some ["bad"]
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := fun _ => some .path
  valKind := fun _ => some .path
  admitsR := fun _ _ => True

private theorem shape_ok : builtins.ShapeOk "bad" signature := by
  refine ⟨"File.Read", ["bad"], rfl, rfl, rfl, by simp, ?_⟩
  exact ⟨rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩

private theorem instantiated :
    instantiatedTel (Tel.instR [range] signature.tel) [] [] =
      .done (.base .unit) effect := by
  have atoms : mapRangeAtoms (rangeAt 0 [range])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed range))) := by
    funext a
    simp [mapRangeAtoms, mapAtomRanges, mapIx, rangeAt, eq_comm]
  simp [atoms, signature, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR,
    Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges,
    Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys,
    Eff.norm, effect, typeEnvAt, substAtoms_nil, instAtoms_nil,
    rowFails]

private theorem arguments (P : Program) (Ψ : StoreTy) :
    BuiltinArgs P builtins Ψ "bad" signature [] [] [range] []
      (.base .unit) effect := by
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
      cases hr; cases hk; exact (by decide : range.FitsKind .path)
    · intro r hr; simp at hr; subst r; exact ⟨by decide, by decide⟩
    · exact Or.inr trivial
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
  · exact ⟨by trivial, by simp [Eff.Canonical, Eff.norm, effect, Ty.normTys]⟩


/-- 全ての型付き応答について同じ TargetAgreement が成り立つ。 -/
theorem target_agreement (P : Program) : builtins.TargetAgreement P := by
  constructor
  intro Ψ b sg ts es rs ws a e out obs hs _ _ response
  have hsg : sg = signature := Option.some.inj hs.symm
  subst sg
  obtain ⟨rfl,rfl,rfl⟩ := response
  simp [PrimSig.shapeAt, signature, Benitoite.Scope.Signature.ShapeTargets, observed, Target.kind]

/-- 型付きで適格な空入力と、実際の応答があり、観測先は宣言の範囲外である。 -/
theorem counterexample (P : Program) (Ψ : StoreTy) (σ : PathEnv) :
    builtins.ShapeOk "bad" signature ∧ builtins.TargetAgreement P ∧
    builtins.sig "bad" = some signature ∧
    (signature.kind = .io ∨ signature.kind = .exit) ∧
    BuiltinArgs P builtins Ψ "bad" signature [] [] [range] [] (.base .unit) effect ∧
    (∀ w ∈ ([] : List Val), w.Adequate σ) ∧
    builtins.ioResponse "bad" [] [] [] (.val (.const .unit)) [observed] ∧
    ¬ (∃ l, signature.opEff = some l ∧ ∀ t ∈ [observed],
      Eff.Allows σ builtins.effKind effect l t) := by
  refine ⟨shape_ok,target_agreement P,rfl,Or.inl rfl,arguments P Ψ,by simp,
    ⟨rfl,rfl,rfl⟩,?_⟩
  rintro ⟨l,hl,all⟩
  have hl : l = "File.Read" := Option.some.inj hl.symm
  subst l
  obtain ⟨k,r,hk,hm,ht⟩ := all observed (by simp)
  have hk : k = .path := Option.some.inj hk.symm
  subst k
  have hr : r = range := by
    have eq := of_decide_eq_true hm
    exact (Atom.name.inj eq).2 |> RangeIx.fixed.inj
  subst r
  simp [RangeExpr.Mem, RangeExpr.resolve, range, observed, Range.Mem,
    PathPattern.Matches] at ht

/-- F05 の指定された完全署名をそのまま量化した命題。 -/
def F05Type : Prop := ∀ {P B Ψ b sg ts es rs ws a e out obs σ},
    B.ShapeOk b sg → B.TargetAgreement P → B.sig b = some sg →
    (sg.kind = .io ∨ sg.kind = .exit) → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ w ∈ ws, w.Adequate σ) → B.ioResponse b ts es ws out obs →
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t

theorem f05_false (P : Program) (Ψ : StoreTy) (σ : PathEnv) : ¬ F05Type := by
  intro claim
  obtain ⟨sh,ht,hs,hk,args,had,response,no⟩ := counterexample P Ψ σ
  exact no (claim sh ht hs hk args had response)

/-- 元の反例の名前列は、追加した形成の前提を満たさない。 -/
theorem not_namesWF : ¬ NamesWF signature.names signature.params := by
  simp [NamesWF, signature]

/-- 名前の形成を加えた全称の型。ほかの前提と結論は元のままである。 -/
def F05WithNamesType : Prop := ∀ {P B Ψ b sg ts es rs ws a e out obs σ},
    B.ShapeOk b sg → B.TargetAgreement P → B.sig b = some sg →
    (sg.kind = .io ∨ sg.kind = .exit) → NamesWF sg.names sg.params →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ w ∈ ws, w.Adequate σ) → B.ioResponse b ts es ws out obs →
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t

theorem f05_with_names : F05WithNamesType := by
  intro P B Ψ b sg ts es rs ws a e out obs σ sh ht hs hk hn ha had hr
  exact Builtins.TargetAgreement.obs_allowed sh ht hs hk hn ha had hr

end
end L50ObservationObstruction
