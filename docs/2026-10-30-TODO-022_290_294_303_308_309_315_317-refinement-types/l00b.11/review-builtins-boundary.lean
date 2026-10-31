import Lean
import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.Step

namespace Benitoite.Release.Refinement.ReviewBuiltinBoundary
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth
def sg (kind : PrimKind) : PrimSig :=
  { tparams := [{}],neffs := 0,names := [],params := [],ret := U,eff := Eff.empty,
    admits := fun _ _ => True,kind := kind,opEff := none }
def B (kind : PrimKind) : Builtins :=
  { sig := fun _ => some (sg kind),delta := fun _ _ _ _ _ => some (.val (.const .unit)),
    ioResponse := fun _ _ _ _ out obs => kind = .io ∧ out = .val (.const .unit) ∧ obs = [],
    releaseResponse := fun _ _ => False,isResource := fun _ => false,effects := fun _ => none,
    sat := fun _ _ _ => True,refGet := "get",refSet := "set" }
def P : Program :=
  { defs := fun _ => none,cons := fun _ => none,ops := fun _ => none,
    effects := fun _ => none,classes := fun _ => none,impls := fun _ => none }

theorem raw_annotation : Ty.Annotation P [] [] raw :=
  ⟨⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

theorem src_eq (kind : PrimKind) : Tel.instR [] (sg kind).tel = .done U Eff.empty := by
  simp [Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,PrimSig.tel,sg,signatureTel,
    Tel.norm,Ty.rawMapRanges,Ty.norm,Eff.rawMapRanges,Eff.norm,Eff.empty,Ty.normTys,Order.sortUnique,U]
  funext x
  simp [mapRangeAtoms]

theorem tel_eq (kind : PrimKind) (ts : List Ty) :
    instantiatedTel (Tel.instR [] (sg kind).tel) ts [] = .done U Eff.empty := by
  rw [src_eq]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,U,
    Eff.rawBind,Eff.norm,Eff.empty,typeEnvAt,rowFails,rawBindTys,
    instAtoms_nil,substAtoms_nil,Ty.normTys,Order.sortUnique]

theorem range_args (kind : PrimKind) : (B kind).RangeAdmissible "p" (sg kind) [] :=
  ⟨rfl,by simp,by simp,Or.inl (by simp)⟩

theorem admissible (kind : PrimKind) : PrimitiveAdmissible [] 0 (sg kind) Qempty [raw] [] := by
  refine ⟨rfl,trivial,?_,rfl,by simp,?_,?_,?_⟩
  · intro t ht; cases List.mem_singleton.mp ht
    exact ⟨raw_annotation.wf,by simp [Ordinary,Ty.core]⟩
  · simp [sg,Eff.RowsIn,Eff.empty,Ty.RowsInList]
  · intro i h; exfalso; simpa [Qsig,QTys,QTy,QEff,sg,Eff.empty,U,Qempty] using h
  · intro i h; exfalso; simpa [Qsig,QTys,QTy,QEff,sg,Eff.empty,U,Qempty] using h

theorem signature (kind : PrimKind) :
    SignatureInstance P [] [] (Tel.instR [] (sg kind).tel)
      ((sg kind).tparams.map TParamDecl.kind) [raw] [] := by
  refine ⟨?_,?_,?_,?_,?_⟩
  · rw [src_eq]; exact ⟨trivial,trivial,rfl⟩
  · intro t ht; cases List.mem_singleton.mp ht; exact raw_annotation
  · refine ⟨rfl,[],rfl,?_⟩
    intro i a k ha hk
    cases i with
    | zero =>
      cases Option.some.inj ha
      have hk' : k = .value := by simpa [sg] using hk.symm
      subst k
      simp [Ty.HasKind,Ty.NotContCore,Ty.core]
    | succ i => simp at ha
  · intro e he; cases he
  · rw [tel_eq]; exact ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

theorem prim_typed (kind : PrimKind) (Ψ : StoreTy) :
    HasTypeV P (B kind) Ψ [] [] [] (.prim "p" [raw] [] [])
      (.dependentFn (.done U Eff.empty)) := by
  have h := HasTypeVQ.V_Prim (Ψ := Ψ) (Q := Qempty) (Φ := [])
    (b := "p") rfl (range_args kind) ⟨rfl,List.nodup_nil⟩ (admissible kind) (signature kind)
  simpa only [tel_eq] using h

theorem args_normalized (kind : PrimKind) (Ψ : StoreTy) :
    BuiltinArgs P (B kind) Ψ "p" (sg kind) (Ty.normTys [raw])
      (([] : List Eff).map Eff.norm) [] [] U Eff.empty := by
  apply BuiltinArgs.normalized (admissible kind) (range_args kind) (signature kind)
  · rw [tel_eq]
    exact .done ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  · intro w hw; cases hw

/-- レビューの反例と同じ delta=none の表でも、正規化した BuiltinArgs 自体は作れる。 -/
def originalB : Builtins := { B .pure with delta := fun _ _ _ _ _ => none }

theorem original_args_normalized (Ψ : StoreTy) :
    BuiltinArgs P originalB Ψ "p" (sg .pure) (Ty.normTys [raw])
      (([] : List Eff).map Eff.norm) [] [] U Eff.empty := by
  apply BuiltinArgs.normalized (B := originalB) (admissible .pure) (by exact range_args .pure) (signature .pure)
  · rw [tel_eq]
    exact .done ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  · intro w hw; cases hw

abbrev rawRow : Eff := .mk (fun _ => false) [raw,raw]

theorem nonempty_row_images :
    instantiatedTel (.done U (Eff.row 0)) (Ty.normTys [raw]) ([rawRow].map Eff.norm) =
      instantiatedTel (.done U (Eff.row 0)) [raw] [rawRow] :=
  instantiatedTel_norm_images _ _ _

private theorem args_result {kind Ψ b ts es rs ws a e}
    (h : BuiltinArgs P (B kind) Ψ b (sg kind) ts es rs ws a e) : a = U := by
  have hr : rs = [] := List.eq_nil_of_length_eq_zero h.ranges.1
  have he : es = [] := List.eq_nil_of_length_eq_zero h.admissible.rowCount
  subst rs es
  have hh := h.arguments
  rw [tel_eq] at hh
  cases hh
  rfl

/-- 信頼条件の各欄も構成し、成立しない応答仮定を入力にしない。 -/
theorem responses (kind : PrimKind) (hk : kind = .pure ∨ kind = .io) :
    Builtins.ResponseAssumptions P (B kind) := by
  constructor
  · intro Ψ b s ts es rs ws a e hs hp ha
    cases Option.some.inj hs
    have hargs : BuiltinArgs P (B kind) Ψ b (sg kind) ts es rs ws a e := ha
    have hresult := args_result hargs
    subst a
    exact ⟨.val (.const .unit),rfl,(by intro n hn; cases hn),⟨HasTypeVQ.V_Const trivial,trivial⟩,(fun _ _ _ => True.intro)⟩
  · intro Ψ b s ts es rs ws a e out obs hs hi ha hr
    cases Option.some.inj hs
    have hargs : BuiltinArgs P (B kind) Ψ b (sg kind) ts es rs ws a e := ha
    have hresult := args_result hargs
    subst a
    obtain ⟨_,rfl,_⟩ := hr
    exact ⟨⟨HasTypeVQ.V_Const trivial,trivial⟩,fun _ _ _ => True.intro⟩
  · intro Ψ b s ts es rs ws a e out obs hs ha hr
    cases Option.some.inj hs
    exact Or.inl ⟨hr.1,by intro n hn; rw [hr.2.1] at hn; cases hn⟩
  · intro Ψ b s ts es rs ws a e hs hi ha
    cases Option.some.inj hs
    have hio : kind = .io := by
      rcases hk with hp | hp
      · subst kind; rcases hi with h | h <;> cases h
      · exact hp
    exact ⟨.val (.const .unit),[],hio,rfl,rfl⟩

def rawClosure : Closure := .mk (.mk [some (.prim "p" [raw] [] [])]) (.app (.var 0) [])
theorem raw_view : rawClosure.view = .app (.prim "p" [raw] [] []) [] := rfl

/-- delta_typed を元の raw の値の遷移へ適用する。 -/
theorem delta_entry (Ψ : StoreTy) (σ : PathEnv) (oracle : Oracle) (externalOracle : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) :
    ∃ v, HasTypeV P (B .pure) Ψ [] [] [] (.prim "p" [raw] [] []) (.dependentFn (.done U Eff.empty)) ∧
      Outcome.Typed P (B .pure) Ψ (.val v) U ∧
      step P (B .pure) σ oracle externalOracle rel fresh (.run rawClosure [] Store.empty) =
        some (none,.run (Closure.pure (.ret v)) [] Store.empty) ∧
      Step P (B .pure) σ (.run rawClosure [] Store.empty) none
        (.run (Closure.pure (.ret v)) [] Store.empty) := by
  obtain ⟨out,hd,hn,ht,_⟩ := (responses .pure (Or.inl rfl)).delta_typed
    Ψ "p" (sg .pure) _ _ [] [] U Eff.empty rfl rfl (args_normalized .pure Ψ)
  have he : out = .val (.const .unit) := Option.some.inj hd.symm
  subst out
  exact ⟨.const .unit,prim_typed .pure Ψ,ht,step_prim_val raw_view rfl rfl hd⟩

/-- io_exists の応答は同じ raw の値の IO 遷移に使える。 -/
theorem io_entry (Ψ : StoreTy) (σ : PathEnv) (externalOracle : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) :
    ∃ out obs, HasTypeV P (B .io) Ψ [] [] [] (.prim "p" [raw] [] []) (.dependentFn (.done U Eff.empty)) ∧
      step P (B .io) σ (fun _ _ _ _ => (out,obs)) externalOracle rel fresh (.run rawClosure [] Store.empty) =
        some (some (.io "p" [] out obs),.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      Step P (B .io) σ (.run rawClosure [] Store.empty) (some (.io "p" [] out obs))
        (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  obtain ⟨out,obs,hr⟩ := (responses .io (Or.inr rfl)).io_exists
    Ψ "p" (sg .io) _ _ [] [] U Eff.empty rfl (Or.inl rfl) (args_normalized .io Ψ)
  obtain ⟨_,rfl,rfl⟩ := hr
  exact ⟨.val (.const .unit),[],prim_typed .io Ψ,
    step_io_val raw_view rfl rfl (by intro _ _ hm; cases hm) rfl ⟨rfl,rfl,rfl⟩⟩

end
end Benitoite.Release.Refinement.ReviewBuiltinBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if (name.toString.splitOn ".ReviewBuiltinBoundary.").length > 1 then
      elabCommand (← `(#print axioms $(mkIdent name)))
