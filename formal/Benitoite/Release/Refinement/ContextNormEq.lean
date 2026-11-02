import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.Narrowing

/-! # 正規形が等しい文脈の対応（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement

/-- None の位置と、各束縛型の正規形を保つ。 -/
def Ctx.NormEq (Γ Δ : Ctx) : Prop :=
  Γ.map (Option.map Ty.norm) = Δ.map (Option.map Ty.norm)

theorem Ctx.NormEq.refl (Γ : Ctx) : Γ.NormEq Γ := rfl

theorem Ctx.NormEq.symm {Γ Δ : Ctx} (h : Γ.NormEq Δ) : Δ.NormEq Γ := Eq.symm h

theorem Ctx.NormEq.length {Γ Δ : Ctx} (h : Γ.NormEq Δ) : Γ.length = Δ.length := by
  have hh := congrArg List.length h
  simpa only [List.length_map] using hh

theorem Ctx.NormEq.lookup {Γ Δ : Ctx} (h : Γ.NormEq Δ) {i : Nat} {a : Ty}
    (ha : Γ[i]? = some (some a)) :
    ∃ b, Δ[i]? = some (some b) ∧ a.norm = b.norm := by
  have hh := congrArg (fun (xs : Ctx) => xs[i]?) h
  simp only [List.getElem?_map,ha,Option.map_some] at hh
  cases hb : Δ[i]? with
  | none => simp [hb] at hh
  | some b => cases b with
    | none => simp [hb] at hh
    | some b => exact ⟨b,rfl,by simpa only [hb,Option.map_some,Option.some.injEq] using hh⟩

theorem substTyValues_var (a : Ty) : substTyValues Val.var a = a.norm := by
  change (a.rawBind (valEnv Val.var)).norm = a.norm
  have he : valEnv Val.var = renEnv id := rfl
  rw [he,Ty.rawBind_id]

theorem substEffValues_var (e : Eff) : substEffValues Val.var e = e.norm := by
  change (Eff.rawBind (valEnv Val.var) e).norm = e.norm
  have he : valEnv Val.var = renEnv id := rfl
  rw [he,Eff.rawBind_id]

theorem Ctx.NormEq.valueImages {P B Ψ Q C Γ Δ Φ} (h : Γ.NormEq Δ) :
    TypedValueImages P B Ψ Q C Γ Δ Φ Val.var := by
  intro i a hi ho
  obtain ⟨b,hb,he⟩ := h.lookup hi
  rw [substTyValues_var,he]
  exact .V_Normal (.V_Var hb ((Ty.ordinary_norm b).mp (he ▸ (Ty.ordinary_norm a).mpr ho)))

theorem Ctx.NormEq.substOk {P B Ψ Q C Γ Δ Φ R} (h : Γ.NormEq Δ)
    (hc : ∀ (i : Nat) (b t : Ty) (e : Eff), Γ[i]? = some (some (.cont b t e)) →
      ∃ (b' t' : Ty) (e' : Eff), Δ[i]? = some (some (.cont b' t' e'))) :
    SubstOk P B Ψ Q C Γ Φ Δ Φ R Val.var := by
  intro i a hi
  by_cases ho : a.Ordinary
  · exact .ordinary ho (h.valueImages i a hi ho)
  · by_cases hs : ∃ b t e, a = .cont b t e
    · obtain ⟨b,t,e,rfl⟩ := hs
      obtain ⟨b',t',e',hb⟩ := hc i b t e hi
      obtain ⟨other,he,hEq⟩ := h.lookup hi
      rw [hb] at he
      cases he
      exact .contVar rfl rfl ⟨b',t',e',hb,by rw [substTyValues_var]; exact hEq.symm⟩
    · exact .hidden ho (by intro b t e he; exact hs ⟨b,t,e,he⟩)

theorem Ctx.NormEq.sortMap {Γ Δ : Ctx} (h : Γ.NormEq Δ) : SortMap Γ Δ := by
  constructor
  intro i a hi
  obtain ⟨b,hb,he⟩ := h.lookup hi
  refine ⟨b,hb,?_,?_⟩
  · intro sort hs
    exact (Ty.hasSort_norm b sort).mp (he ▸ (Ty.hasSort_norm a sort).mpr hs)
  · intro ho
    exact (Ty.ordinary_norm b).mp (he ▸ (Ty.ordinary_norm a).mpr ho)

theorem Ctx.NormEq.declaration {P C Γ Δ} {B : Builtins} (h : Γ.NormEq Δ) :
    DeclarationImages P C Γ Δ (fun i => some (.var i)) := by
  constructor
  · intro i a hi ho t ht
    cases ht
    exact (h.valueImages (P := P) (B := B) (Ψ := StoreTy.empty)
      (Q := Qempty) (C := C) (Φ := []) i a hi ho).observation_declared rfl
  · intro i a d ts hi hd
    rw [bindDataArgs_id, Ty.dataCore_args_norm hd]
    exact (h.valueImages (P := P) (B := B) (Ψ := StoreTy.empty)
      (Q := Qempty) (C := C) (Φ := []) i a hi (Ty.ordinary_of_dataCore hd)).data_observation
      (by simpa only [substTyValues_var,Ty.norm_idem] using hd) rfl

theorem Ctx.NormEq.annotation {P C Γ Δ a} {B : Builtins} (h : Γ.NormEq Δ)
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Δ a := by
  exact ⟨by simpa only [h.length] using ha.wf,ha.sorted.sortMap h.sortMap,
    ha.declared.context (h.declaration (B := B))⟩

theorem Ctx.facts_map_norm (Γ : Ctx) : Ctx.facts (Γ.map (Option.map Ty.norm)) = Γ.facts := by
  simp only [Ctx.facts,List.zipIdx_map,List.flatMap_map]
  congr 1
  funext pair
  obtain ⟨a,i⟩ := pair
  cases a <;> simp [Ty.assume_norm]

theorem Ctx.NormEq.facts {Γ Δ : Ctx} (h : Γ.NormEq Δ) : Γ.facts = Δ.facts := by
  rw [←Ctx.facts_map_norm Γ,←Ctx.facts_map_norm Δ,h]

theorem Ctx.NormEq.shiftV {Γ Δ : Ctx} (h : Γ.NormEq Δ) (k c : Nat) :
    Ctx.NormEq (Γ.map (Option.map (Ty.shiftV k c))) (Δ.map (Option.map (Ty.shiftV k c))) := by
  have hh := congrArg (List.map (Option.map (Ty.shiftV k c))) h
  simpa only [Ctx.NormEq,List.map_map,Option.map_map,Function.comp_def,Ty.norm_shiftV] using hh

theorem Ctx.norm_bindParams (Γ : Ctx) (ps : List Ty) :
    (bindParams Γ ps).map (Option.map Ty.norm) =
      bindParams (Γ.map (Option.map Ty.norm)) (ps.map Ty.norm) := by
  simp only [bindParams,List.map_append,List.map_map,List.map_reverse,List.length_map,
    Option.map_some,Option.map_map,Function.comp_def,Ty.norm_shiftV]

theorem Ctx.NormEq.params {Γ Δ : Ctx} (h : Γ.NormEq Δ) (ps : List Ty) :
    (bindParams Γ ps).NormEq (bindParams Δ (ps.map Ty.norm)) := by
  change (bindParams Γ ps).map (Option.map Ty.norm) = _
  rw [Ctx.norm_bindParams,Ctx.norm_bindParams,h]
  simp only [List.map_map,Function.comp_def,Ty.norm_idem]

theorem Ctx.norm_hideConts (Γ : Ctx) :
    (hideConts Γ).map (Option.map Ty.norm) = hideConts (Γ.map (Option.map Ty.norm)) := by
  simp only [hideConts,List.map_map]
  apply List.map_congr_left
  intro oa hmem
  cases oa with
  | none => rfl
  | some a =>
    dsimp only [Function.comp_def,Option.map_some]
    by_cases ho : Ordinary a
    · have hon := (Ty.ordinary_norm a).mpr ho
      have hs : hideConts [some a] = [some a] := by
        cases he : a.core <;> simp only [hideConts,List.map_cons,List.map_nil,he]
        all_goals first | rfl | exact False.elim (ho _ _ _ he)
      have ht : hideConts [some a.norm] = [some a.norm] := by
        cases he : a.norm.core <;> simp only [hideConts,List.map_cons,List.map_nil,he]
        all_goals first | rfl | exact False.elim (hon _ _ _ he)
      have hs' := congrArg (fun (xs : Ctx) => xs[0]?) hs
      have ht' := congrArg (fun (xs : Ctx) => xs[0]?) ht
      simp only [hideConts,List.map_cons,List.map_nil,List.getElem?_cons_zero,Option.some.injEq] at hs' ht'
      rw [hs',ht']
      rfl
    · have hon : ¬ Ordinary a.norm := fun h => ho ((Ty.ordinary_norm a).mp h)
      have hs : hideConts [some a] = [none] := by
        cases he : a.core <;> simp only [hideConts,List.map_cons,List.map_nil,he]
        all_goals first | rfl | exact False.elim (ho (by simp [Ordinary,he]))
      have ht : hideConts [some a.norm] = [none] := by
        cases he : a.norm.core <;> simp only [hideConts,List.map_cons,List.map_nil,he]
        all_goals first | rfl | exact False.elim (hon (by simp [Ordinary,he]))
      have hs' := congrArg (fun (xs : Ctx) => xs[0]?) hs
      have ht' := congrArg (fun (xs : Ctx) => xs[0]?) ht
      simp only [hideConts,List.map_cons,List.map_nil,List.getElem?_cons_zero,Option.some.injEq] at hs' ht'
      rw [hs',ht']
      rfl

theorem Ctx.NormEq.hide {Γ Δ : Ctx} (h : Γ.NormEq Δ) :
    (hideConts Γ).NormEq (hideConts Δ) := by
  change (hideConts Γ).map (Option.map Ty.norm) = _
  rw [Ctx.norm_hideConts,Ctx.norm_hideConts,h]

theorem substKind_var (b : BuilderKind) : substKind Val.var b = b.norm := by
  cases b <;> simp only [substKind,BuilderKind.norm,substTyValues_var]

theorem Ctx.NormEq.comp {P B Ψ Q C Γ Δ Φ R m a e L}
    (h : Γ.NormEq Δ)
    (hc : ∀ (i : Nat) (b t : Ty) (e : Eff), Γ[i]? = some (some (.cont b t e)) →
      ∃ (b' t' : Ty) (e' : Eff), Δ[i]? = some (some (.cont b' t' e')))
    (ha : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (ht : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    HasTypeCQ P B Ψ Q C Δ Φ (R.map Ty.norm) (m.subst Val.var LocalRef.bound)
      a.norm (Eff.norm e) (L.map (Option.map BuilderKind.norm)) := by
  have hL : LocalSubstOk Ψ L Val.var LocalRef.bound (L.map (Option.map BuilderKind.norm)) := by
    intro i b hb
    rw [substKind_var]
    exact .bound (by simp only [List.getElem?_map,hb,Option.map_some])
  have hh := ht.subst ha hw (h.substOk hc)
    (fun p hp => by simpa only [valEnv,Val.toTerm?,predBind_id] using
      (Entails.hyp (List.mem_append_right Δ.facts hp))) LocalRef.bound hL
  rw [show substTyValues Val.var = Ty.norm from funext substTyValues_var] at hh
  simpa only [substEffValues_var] using hh

theorem Ctx.NormEq.variable {P B Ψ Q C Φ i a} {Γ Δ : Ctx} (h : Γ.NormEq Δ)
    (hi : Γ[i]? = some (some a)) (ho : Ordinary a) :
    HasTypeVQ P B Ψ Q C Δ Φ (.var i) a.norm := by
  simpa only [substTyValues_var] using h.valueImages (P := P) (B := B) (Ψ := Ψ)
    (Q := Q) (C := C) (Φ := Φ) i a hi ho

theorem Ctx.NormEq.resume {P B Ψ Q C Γ Δ Φ i v b t e} {R : Option Ty} {L : LocalCtx} (h : Γ.NormEq Δ)
    (hc : ∀ (i : Nat) (b t : Ty) (e : Eff), Γ[i]? = some (some (.cont b t e)) →
      ∃ (b' t' : Ty) (e' : Eff), Δ[i]? = some (some (.cont b' t' e')))
    (ha : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (hi : Γ[i]? = some (some (.cont b t e)))
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v b) (hd : Ty.Declared P C Γ t) :
    HasTypeCQ P B Ψ Q C Δ Φ (R.map Ty.norm)
      (.resume (.var i) (v.subst Val.var LocalRef.bound)) t.norm (Eff.norm e)
      (L.map (Option.map BuilderKind.norm)) := by
  exact h.comp hc ha hw (.C_Resume hi hv hd)

theorem Ctx.NormEq.lambda {P B Ψ Q C Γ Δ Φ ns ps body r e} (h : Γ.NormEq Δ)
    (hc : ∀ (i : Nat) (b t : Ty) (e : Eff), Γ[i]? = some (some (.cont b t e)) →
      ∃ (b' t' : Ty) (e' : Eff), Δ[i]? = some (some (.cont b' t' e')))
    (ha : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hn : NamesWF ns ps)
    (hAnn : Ty.Annotation P C Γ (.fn ns ps r e))
    (hb : HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps)
      (liftMany ps.length Φ) (some (r.shiftV ps.length 0)) body
      (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 e) []) :
    HasTypeVQ P B Ψ Q C Δ Φ ((Val.lam ns ps body).subst Val.var LocalRef.bound)
      (Ty.fn ns ps r e).norm := by
  have hs := HasTypeVQ.V_Lam hn hAnn.wf hAnn.sorted hb hAnn.declared
  have out := hs.subst ha hw (h.substOk (R := none) hc)
    (fun p hp => by simpa only [valEnv,Val.toTerm?,predBind_id] using
      (Entails.hyp (List.mem_append_right Δ.facts hp))) LocalRef.bound
  simpa only [substTyValues_var] using out

end Benitoite.Release.Refinement
