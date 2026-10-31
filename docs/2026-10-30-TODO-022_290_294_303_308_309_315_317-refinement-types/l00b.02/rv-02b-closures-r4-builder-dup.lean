import ClosureR4Rows
namespace Benitoite.Release.Refinement.RV4
open Benitoite.Release.Refinement
open Benitoite.Release.Refinement.ClosureR4
open Benitoite.Release.Refinement.ClosureR4Extra
open Benitoite.Release.Refinement.ClosureR4Rows
noncomputable section

abbrev dupΓ : Ctx := rowΓ (fun _ => false)
def dupBody : Comp := .resume (.var 1) (.var 2)
def dupCode : Comp := .builderLet .string dupBody
def dupQ : Closure := .mk opCap dupCode

/-- 節の本体に builderLet を持つ閉包は、重複Failの継続を捕捉したまま型付く。 -/
theorem dup_code_typed (Ψ : StoreTy) :
    HasTypeC polyP polyB Ψ [] dupΓ [] none dupCode (R 2) dupE := by
  refine .C_BuilderLet (kind := .string) ⟨trivial,trivial,trivial⟩
    (kinded _ _ (by simp [BuilderKind.contents,Ty.HasKind])) ?_ (row_R_ann _).declared
  refine .C_Resume (i := 1) rfl (.V_Var (i := 2) rfl
      ((Ty.ordinary_shiftV _ _ _).mpr (by change Ty.Ordinary (.refined scalar (.eq (.var 0) (.integer 7))); simp [Ty.Ordinary]))) ?_
  exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar,rfl,by simp [scalar]⟩⟩⟩

/-- 閉包として ClosureTy を満たす。effect は eps へ広げる必要がないので閉じた像のまま。 -/
theorem dup_closure :
    ClosureTy polyP polyB (rowΨ (fun _ => false)) [] none dupQ (opCap.closeTy (R 2)) (opCap.closeEff dupE) := by
  refine closed_wrap (row_capture _) (dup_code_typed _) ?_
  have h := ec_ann (fun _ => false)
  have hc : opCap.closeEff dupE = ec (fun _ => false) := close_raw _ _
  rw [hc]; exact h

/-- 実際に E_BuilderNew が動く。 -/
theorem dup_step (σ : PathEnv) (k : Cont) :
    Step polyP polyB σ (.run dupQ k rowμ) none
      (.run (Closure.mk dupQ.capture (dupBody.subst builderValueSubst (builderLocalSubst 1))) k
        (rowμ.set 1 (.builder BuilderKind.string.empty))) :=
  Step.E_BuilderNew (kind := .string) (body := dupBody) rfl (by simp [rowμ,Store.set,Store.empty])

/-- その捕捉の文脈は Ctx.WF を満たさないので、builderBody_image の hΓ を供給できない。 -/
theorem hΓ_unavailable : ¬ Ctx.WF 0 0 dupΓ := dup_context_not_wf

/-- 前提の hΓ を除くだけでは足りない。Δ = Γ の SubstOk 自体が偽である。 -/
theorem dup_substOk_false {Ψ : StoreTy} {R0 : Option Ty} :
    ¬ SubstOk polyP polyB Ψ Qempty [] (dupΓ.extendNone) ([].map Pred.lift) dupΓ [] R0 builderValueSubst := by
  intro h
  have hh := h 1 ((Ty.cont refTy (R 2) dupE).shiftV 1 0) rfl
  cases hh with
  | ordinary ho _ => exact ho _ _ _ rfl
  | contLoc _ _ _ hl _ _ => cases hl
  | contVar ha hj hx =>
    cases hj
    have hn : substTyValues builderValueSubst ((Ty.cont refTy (R 2) dupE).shiftV 1 0)
        = (Ty.cont refTy (R 2) dupE).norm := by
      rw [← builderValueSubst_eq]; exact Ty.openValue_shift _ _
    rw [hn] at hx
    have he : Ty.cont refTy (R 2) dupE = Ty.cont refTy.norm (R 2).norm (Eff.norm dupE) :=
      Option.some.inj (Option.some.inj hx)
    have hc : Eff.norm dupE = dupE := (Ty.cont.inj he).2.2.symm
    have hl := congrArg (fun e : Eff => e.fails.length) hc
    change 1 = 2 at hl
    cases hl

/-- 代わりの修正の候補: 継続の項目の行だけを正規化した文脈へ移す。 -/
def normItem : Option Ty → Option Ty
  | some (.cont b t e) => some (.cont b t (Eff.norm e))
  | x => x
def Ctx.normConts (Γ : Ctx) : Ctx := Γ.map normItem

/-- CaptureWF の条件だけから、値の束縛を除いた本体の像を、行を正規化した文脈で型付ける。 -/
theorem builderBody_image_norm {P B Ψ Q C Γ Φ} {R : Option Ty} {body : Comp} {a : Ty} {e : Eff} {L k}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hΓ : Ctx.CaptureWF 0 C.length Γ)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)) :
    HasTypeCQ P B Ψ Q C (Ctx.normConts Γ) Φ ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst))
      (body.subst builderValueSubst LocalRef.bound)
      (substTyValues builderValueSubst (a.shiftV 1 0)) (substEffValues builderValueSubst (e.shiftV 1 0))
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L) := by
  have hs : SubstOk P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (Ctx.normConts Γ) Φ
      ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) builderValueSubst := by
    intro i b hi
    cases i with
    | zero => simp [Ctx.extendNone] at hi
    | succ i =>
      simp only [Ctx.extendNone,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,hh⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hh
      | some t =>
        cases hh
        have hn : substTyValues builderValueSubst (t.shiftV 1 0) = t.norm := by
          rw [← builderValueSubst_eq]; exact Ty.openValue_shift _ _
        by_cases ho : t.Ordinary
        · refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
          have hwf : t.WF 0 C.length Γ.length := (hΓ i t hx).ordinary ho
          rw [hn,Ty.canonical_of_wf hwf]
          refine .V_Var ?_ ho
          simp only [Ctx.normConts,List.getElem?_map,hx,Option.map_some]
          cases t <;> first | rfl | exact False.elim (ho _ _ _ rfl)
        · cases t <;> simp [Ty.Ordinary] at ho
          case cont b t e =>
            refine .contVar rfl rfl ?_
            have hc := hΓ i _ hx
            rw [hn]
            simp only [Ctx.normConts,List.getElem?_map,hx,Option.map_some,normItem]
            change _ = some (some (Ty.cont b.norm t.norm (Eff.norm e)))
            rw [Ty.canonical_of_wf hc.1,Ty.canonical_of_wf hc.2]
  have hf : ∀ p ∈ Φ.map Pred.lift, Entails ((Ctx.normConts Γ).facts ++ Φ)
      (predBind (valEnv builderValueSubst).values p) := by
    intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    rw [←builderValueSubst_eq, Pred.openValue_lift]
    exact .hyp (List.mem_append_right _ hq)
  have hl : LocalSubstOk Ψ (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)
      builderValueSubst LocalRef.bound
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L) := by
    intro i b hi
    cases i with
    | zero =>
      simp only [LocalCtx.extend,List.getElem?_cons_zero,Option.some.injEq] at hi
      cases hi; exact .bound rfl
    | succ i =>
      simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,hh⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hh
      | some c =>
        cases hh
        exact .bound (by simp [imageLocal,hx,imageKind])
  exact hb.subst hA hw hs hf LocalRef.bound hl

/-- 正規化した文脈の継続の項目の閉じた像は元と同じである。 -/
theorem close_normItem (ν : Nat → Val) (b t : Ty) (e : Eff) :
    substTyValues ν (.cont b t (Eff.norm e)) = substTyValues ν (.cont b t e) := by
  refine Ty.rawBind_norm_congr _ ?_
  change Ty.cont b.norm t.norm (Eff.norm (Eff.norm e)) = Ty.cont b.norm t.norm (Eff.norm e)
  rw [Eff.norm_idem]

/-- 文脈を延ばしても、未検査の行を含む型の閉じた像は変わらない（E_Return などの CaptureOk の延長）。 -/
theorem close_extend (cap : Capture) (v : Val) (a : Ty) :
    (cap.extend v).closeTy (a.shiftV 1 0) = cap.closeTy a := by
  simp only [Capture.closeTy, substTyValues, Ty.bind, Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
  change (Ty.rawBind (SubstEnv.mk Ty.tvar [] [] (valEnv (cap.extend v).env).values) _).norm = _
  rw [←Ty.rawSubstV_eq_rawBind, Ty.rawSubstV_comp]
  have he : (fun i => (some (Term.var (shiftIndex 1 0 i))).bind (termBind? (valEnv (cap.extend v).env).values)) =
      (valEnv cap.env).values := by
    funext i
    simp [shiftIndex, termBind?, valEnv, Capture.extend, Capture.env]
    rfl
  rw [he]
  rw [Ty.rawSubstV_eq_rawBind]
  rfl

#print axioms dup_closure
#print axioms dup_step
#print axioms dup_substOk_false
#print axioms builderBody_image_norm
#print axioms close_normItem
#print axioms close_extend
end
end Benitoite.Release.Refinement.RV4
