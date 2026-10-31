import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.LocalResolveLemmas

/-!
# 捕捉の型付き像と依存する引数列の接続

実引数による一束縛の具体化を、文脈の正則性と型付きの値から作る。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def openValue (v : Val) : Nat → Val
  | 0 => v
  | i+1 => .var i

theorem valEnv_openValue (v : Val) : valEnv (openValue v) = Tel.argumentsEnv v := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1

theorem Ty.openValue_shift (a : Ty) (v : Val) :
    substTyValues (openValue v) (a.shiftV 1 0) = a.norm := by
  simp only [substTyValues, Ty.bind, Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
  change (Ty.rawBind (SubstEnv.mk Ty.tvar [] [] (valEnv (openValue v)).values) _).norm = _
  rw [←Ty.rawSubstV_eq_rawBind, Ty.rawSubstV_comp]
  have he : (fun i => (some (Term.var (shiftIndex 1 0 i))).bind (termBind? (valEnv (openValue v)).values)) =
      (fun i => some (Term.var i)) := by
    funext i
    simp [shiftIndex, termBind?, valEnv, openValue, Val.toTerm?]
  rw [he]
  have hid := renameTy_eq_rawSubstV id a
  simp only [id_eq,renameTy_id] at hid
  rw [←hid]

theorem Pred.openValue_lift (p : Pred) (v : Val) :
    predBind (valEnv (openValue v)).values p.lift = p := by
  simp only [Pred.lift, predBind_comp]
  have he : (fun i => (some (Term.var (i+1))).bind (termBind? (valEnv (openValue v)).values)) =
      (fun i => some (Term.var i)) := by
    funext i; rfl
  rw [he, predBind_id]

theorem HasTypeVQ.notContCore {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hw : Ctx.WF 0 C.length Γ) : a.NotContCore := by
  match h with
  | .V_Var hi ho => exact Ty.notContCore_of_wf_ordinary (hw _ _ hi) ho
  | .V_Sub hv hl _ _ _ => exact hl.notContCore.mp (hv.notContCore hw)
  | .V_Refine hv .. => exact hv.notContCore hw
  | .V_AtError hs => rw [hs.errorType_eq]; simp [Ty.NotContCore,Ty.core,atErrorType]
  | .V_Const (c := c) _ => cases c <;> simp [Ty.NotContCore,Ty.core,Const.type]
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. | .V_List .. => simp [Ty.NotContCore,Ty.core]

theorem SubstOk.openValue {P B Ψ Q C Γ Φ v a R}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) (ha : Ty.Annotation P C Γ a)
    (hΓ : Ctx.WF 0 C.length Γ) :
    SubstOk P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) Γ Φ R (openValue v) := by
  intro i b hi
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr (hv.notContCore hΓ).ordinary) ?_
    rw [Ty.openValue_shift, Ty.canonical_of_wf ha.wf]
    exact hv
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨x,hx,he⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases he
    | some t =>
      cases he
      by_cases ho : t.Ordinary
      · refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
        rw [Ty.openValue_shift, Ty.canonical_of_wf (hΓ _ _ hx)]
        exact .V_Var hx ho
      · cases t <;> simp [Ty.Ordinary] at ho
        case cont b t e =>
          refine .contVar rfl rfl ?_
          have hw := hΓ _ _ hx
          have hn : (Ty.cont b t e).norm = .cont b t e := by
            change Ty.cont b.norm t.norm (Eff.norm e) = .cont b t e
            rw [Ty.canonical_of_wf hw.1,Ty.canonical_of_wf hw.2.1,hw.2.2.2]
          rw [Ty.openValue_shift,hn]
          exact hx

theorem SubstOk.annotation {P B Ψ Q C Γ Φ Δ Ξ R ν a}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R ν) (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Δ (substTyValues ν a) := by
  have ht := h.transport (Φ := []) (by simp)
  refine ⟨h.wf ha.wf ha.sorted, ?_, ha.declared.bind_values h.declaration⟩
  simpa only [substTyValues, valEnv_valuesOnly] using
    Ty.sorted_bind_values ha.sorted (valEnv ν).values ht.values ht.references

theorem HasTypeTelArgsQ.of_arguments {P B Ψ Q C Γ Φ vs t as a e}
    (hargs : Tel.arguments t vs = some (as,a,e))
    (hvs : HasTypeVsQ P B Ψ Q C Γ Φ vs as)
    (ht : Ty.Annotation P C Γ (.dependentFn t)) (hΓ : Ctx.WF 0 C.length Γ) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e := by
  induction vs generalizing t as a e with
  | nil =>
    cases t with
    | param n x rest => simp [Tel.arguments] at hargs
    | done r eff =>
      simp only [Tel.arguments, Option.some.injEq, Prod.mk.injEq] at hargs
      obtain ⟨rfl,rfl,rfl⟩ := hargs
      have hn : r.norm = r := Ty.canonical_of_wf ht.wf.1
      rw [hn, ht.wf.2.2]
      exact .done ht
  | cons v vs ih =>
    cases t with
    | done r eff => simp [Tel.arguments] at hargs
    | param n x rest =>
      simp only [Tel.arguments] at hargs
      obtain ⟨⟨as',r',e'⟩,hr,he⟩ := Option.map_eq_some_iff.mp hargs
      cases he
      cases hvs with
      | cons hv hs =>
        have hx : Ty.Annotation P C Γ x := ⟨ht.wf.1, ht.sorted.1, ht.declared.1⟩
        have hv' : HasTypeVQ P B Ψ Q C Γ Φ v x := by
          have hn : x.norm = x := Ty.canonical_of_wf hx.wf
          rw [hn] at hv
          exact hv
        have hs0 : SubstOk P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift) Γ Φ none (openValue v) :=
          SubstOk.openValue hv' hx hΓ
        have hb : Ty.Annotation P C (Γ.extend x) (.dependentFn rest) := ⟨by simpa [Ctx.extend,Ty.WF] using ht.wf.2,ht.sorted.2,ht.declared.2⟩
        have hb' := hs0.annotation hb
        rw [substTyValues_eq_bind, valEnv_openValue] at hb'
        exact .param hx hv' (ih hr hs hb')

theorem CaptureOk.substOk {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    SubstOk P B Ψ Qempty [] Γ Φ [] [] R cap.env := by
  cases h with
  | mk _ _ _ _ _ _ hi _ => exact hi

theorem CaptureOk.conditions {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    ∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p) := by
  cases h with
  | mk _ _ _ _ _ _ _ hf => exact hf

theorem CaptureOk.transport {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    Transport (valEnv cap.env) Γ Φ [] [] :=
  h.substOk.transport (fun p hp => h.conditions p (List.mem_append_right _ hp))

theorem Tel.bind_values_of_wf_zero {nr nt t} (hw : Tel.WF nr nt 0 t) (ν : Nat → Val) :
    Tel.bind (valEnv ν) t = t := by
  have hn : Tel.norm t = t := by
    have he := Ty.canonical_of_wf (show (Ty.dependentFn t).WF nr nt 0 from hw)
    exact Ty.dependentFn.inj he
  simp only [Tel.bind,valEnv,←Tel.rawSubstV_eq_rawBind,Tel.rawSubstV_of_wf_zero hw,hn]

theorem Capture.closeTel_instantiate (cap : Capture) (t : Tel) (vs : List Val) :
    Tel.instantiate (cap.closeTel t) (Val.substList cap.env vs) =
      (Tel.instantiate t vs).map (fun (a,e) => (cap.closeTy a,cap.closeEff e)) :=
  Tel.instantiate_subst t vs cap.env LocalRef.bound


theorem Tel.SameInputs.refl (t : Tel) : t.SameInputs t := by
  cases t with
  | done => trivial
  | param n a t => exact ⟨rfl,rfl,Tel.SameInputs.refl t⟩

theorem Tel.SameInputs.bind {t u} (h : t.SameInputs u) (θ : SubstEnv) :
    (Tel.bind θ t).SameInputs (Tel.bind θ u) := by
  cases t with
  | done r e => cases u <;> simp_all [Tel.SameInputs,Tel.bind_done]
  | param n a rest =>
    cases u with
    | done => cases h
    | param m b tail =>
      obtain ⟨rfl,rfl,hh⟩ := h
      simp only [Tel.bind_param,Tel.SameInputs]
      exact ⟨trivial,trivial,Tel.SameInputs.bind hh θ.up⟩

theorem Tel.SameInputs.toTel (ns : List String) (ps : List Ty) (r s : Ty) (e f : Eff) :
    (Ty.toTel ns ps r e).SameInputs (Ty.toTel ns ps s f) := by
  induction ns generalizing ps r s e f with
  | nil => cases ps <;> trivial
  | cons n ns ih =>
    cases ps with
    | nil => trivial
    | cons a ps => exact ⟨rfl,rfl,ih _ _ _ _ _⟩

theorem bindParams_cons (Γ : Ctx) (a : Ty) (ps : List Ty) :
    bindParams (Γ.extend a) (ps.map (Ty.shiftV 1 0)) = bindParams Γ (a::ps) := by
  simp [bindParams,Ctx.extend,List.reverse_cons,List.map_append,List.map_map,List.map_reverse,
    Function.comp_def,Ty.shiftV_add,Nat.add_comm,Option.map_map]

theorem Eff.shiftV_add (e : Eff) (m n : Nat) :
    (e.shiftV m 0).shiftV n 0 = e.shiftV (m+n) 0 := by
  simp only [Eff.shiftV_eq_renameEff,renameEff_comp]
  congr 1
  funext i; simp [shiftIndex,Nat.add_assoc]

theorem TelBodyTy.toTel_iff {P B Ψ Q C Γ Φ ns ps r e body}
    (hn : NamesWF ns ps) :
    TelBodyTy P B Ψ Q C Γ Φ (Ty.toTel ns ps r e) body ↔
      HasTypeCQ P B Ψ Q C (bindParams Γ ps) (liftMany ps.length Φ)
        (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (e.shiftV ps.length 0) [] := by
  induction ns generalizing ps Γ Φ r e with
  | nil =>
    cases ps with
    | nil =>
      have ht0 : Ty.shiftV 0 0 = id := funext (fun a => a.shiftV_zero 0)
      have hp0 : Pred.shiftV 0 0 = id := funext (fun p => p.shiftV_zero 0)
      simp only [Ty.toTel,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
        List.length_nil,liftMany_eq,ht0,hp0,Option.map_id,List.map_id,Ty.shiftV_zero,Eff.shiftV_zero]
      exact ⟨fun h => by cases h with | done hb => exact hb, TelBodyTy.done⟩
    | cons a ps => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF,shiftVTys_eq_map] using Nat.succ.inj hn.1,hn.2.of_cons⟩
      have hh := ih (Γ := Γ.extend a) (Φ := Φ.map Pred.lift) (r := r.shiftV 1 0) (e := e.shiftV 1 0) hn'
      simp only [shiftVTys_eq_map,List.length_map,bindParams_cons,Ty.shiftV_add,Eff.shiftV_add,
        ←liftMany_one,liftMany_add,Nat.add_comm 1] at hh
      change TelBodyTy P B Ψ Q C Γ Φ (.param n a _) body ↔ _
      constructor
      · intro h
        cases h with
        | param hb => simpa only [List.length_cons] using hh.mp (by simpa only [shiftVTys_eq_map,liftMany_one] using hb)
      · intro hb
        apply TelBodyTy.param
        simpa only [shiftVTys_eq_map,liftMany_one] using hh.mpr (by simpa only [List.length_cons] using hb)

mutual
  theorem closeVal_observation (cap : Capture) (v : Val) :
      (closeVal cap v).toTerm? = (v.subst cap.env).toTerm? := by
    cases v <;> try rfl
    all_goals simp only [closeVal,Val.subst,Val.toTerm?,closeVals_observations]
  theorem closeVals_observations (cap : Capture) (vs : List Val) :
      Val.toTermSlots (closeVals cap vs) = Val.toTermSlots (Val.substList cap.env vs) := by
    cases vs <;> simp only [closeVals,Val.substList,Val.toTermSlots,closeVal_observation,closeVals_observations]
end

theorem Tel.instantiate_observations (t : Tel) {vs ws : List Val}
    (h : Val.toTermSlots vs = Val.toTermSlots ws) : Tel.instantiate t vs = Tel.instantiate t ws := by
  induction vs generalizing t ws with
  | nil => cases ws <;> simp_all [Val.toTermSlots]
  | cons v vs ih =>
    cases ws with
    | nil => simp [Val.toTermSlots] at h
    | cons w ws =>
      simp only [Val.toTermSlots,List.cons.injEq] at h
      cases t with
      | done => simp only [Tel.instantiate]
      | param n a rest =>
        have he : Tel.argumentsEnv v=Tel.argumentsEnv w := by
          simp only [argumentsEnv_eq,h.1]
        simp only [Tel.instantiate,he]
        exact ih _ h.2

theorem Capture.closeTel_instantiate_runtime (cap : Capture) (t : Tel) (vs : List Val) :
    Tel.instantiate (cap.closeTel t) (closeVals cap vs) =
      (Tel.instantiate t vs).map (fun (a,e) => (cap.closeTy a,cap.closeEff e)) := by
  rw [Tel.instantiate_observations _ (closeVals_observations cap vs)]
  exact cap.closeTel_instantiate t vs


theorem CaptureOk.wf {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) : Ctx.CaptureWF 0 0 Γ := by
  cases h with | mk hw _ _ _ _ _ _ _ => exact hw

theorem CaptureOk.declared {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.CaptureDeclared P [] Γ := by
  cases h with | mk _ _ _ hd _ _ _ _ => exact fun i a hi => (hd i a hi).2

theorem Ty.WF.capture {a : Ty} {nr nt nv} (h : a.WF nr nt nv) : a.CaptureWF nr nt nv := by
  cases a <;> first | exact ⟨h.1,h.2.1⟩ | exact h

theorem Ty.Sorted.capture {a : Ty} {Γ} (h : a.Sorted Γ) : a.CaptureSorted Γ := by
  cases a <;> first | exact ⟨h.1,h.2.1⟩ | exact h

theorem Ty.Declared.capture {P C Γ} {a : Ty} (h : a.Declared P C Γ) : a.CaptureDeclared P C Γ := by
  cases a <;> first | exact ⟨h.1,h.2.1⟩ | exact h

theorem Ty.CaptureWF.ordinary {a : Ty} {nr nt nv} (h : a.CaptureWF nr nt nv) (ho : a.Ordinary) : a.WF nr nt nv := by
  cases a <;> first | exact h | cases ho _ _ _ rfl

theorem CaptureOk.wf_ordinary {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Ordinary) : Ctx.WF 0 0 Γ := by
  intro i a hi; exact (h.wf i a hi).ordinary (ho i a hi)

theorem CaptureOk.continuation_image_wf {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
    {Γ : Ctx} {Φ : List Pred} {cap : Capture} {i : Nat} {b t : Ty} {e : Eff}
    (h : CaptureOk P B Ψ R Γ Φ cap) (hi : Γ[i]? = some (some (.cont b t e))) :
    (substTyValues cap.env (.cont b t e)).WF 0 0 0 := by
  have hh := h.substOk i _ hi
  cases hh with
  | ordinary ho _ => exact False.elim (ho b t e rfl)
  | contLoc _ _ hw _ _ _ => exact hw
  | contVar _ _ hx => cases hx

theorem ClosureTy.annotation {P B Ψ ps R q a e} (h : ClosureTy P B Ψ ps R q a e) :
    Ty.Annotation P [] (bindParams [] ps) (.dependentFn (.done a e)) := by
  cases h with | mk _ _ _ _ _ _ _ _ ha _ _ => exact ha

theorem DependentClosureTy.annotation {P B Ψ q t} (h : DependentClosureTy P B Ψ q t) :
    Ty.Annotation P [] [] (.dependentFn t) := by
  cases h with | mk _ _ _ ha => exact ha


theorem CaptureOk.empty (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty) :
    CaptureOk P B Ψ R [] [] Capture.empty := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; cases hi
  · intro i a hi; cases hi
  · intro i a hi; cases hi
  · intro p hp; cases hp
  · intro ov ho; cases ho
  · intro i a hi; cases hi
  · intro p hp; cases hp

theorem CaptureLocals.empty (Ψ : StoreTy) (ν : Nat → Val) (ρ : Nat → LocalRef) : CaptureLocals Ψ ν [] ρ := by
  intro i kind hi; cases hi

theorem CaptureLocals.substOk {Ψ ν L ρ} (h : CaptureLocals Ψ ν L ρ) : LocalSubstOk Ψ L ν ρ [] := by
  intro i kind hi; obtain ⟨l,he,ht⟩ := h i kind hi; rw [he]; exact .loc ht

theorem CaptureLocals.localExtend {Ψ ν L ρ} (h : CaptureLocals Ψ ν L ρ) (hw : Ψ.WF) :
    CaptureLocals Ψ (upSubst 1 ν) (localExtend 1 L) (upLocalSubst 1 ρ) := by
  intro i kind hi
  cases i with
  | zero => cases hi
  | succ i =>
    simp only [Refinement.localExtend,LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
    obtain ⟨x,hx,he⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases he
    | some b =>
      cases he
      obtain ⟨l,hr,ht⟩ := h i b hx
      refine ⟨l,?_,?_⟩
      · simp [upLocalSubst,hr,LocalRef.rename]
      · rw [substKind_shift,renameKind_closed (hw l _ ht)]; exact ht

theorem CaptureLocals.localExtend_many {Ψ ν L ρ} (h : CaptureLocals Ψ ν L ρ) (hw : Ψ.WF) (n : Nat) :
    CaptureLocals Ψ (upSubst n ν) (Refinement.localExtend n L) (upLocalSubst n ρ) := by
  induction n with
  | zero => simpa only [upSubst_zero,upLocalSubst_zero,Refinement.localExtend] using h
  | succ n ih => simpa only [upSubst_add,upLocalSubst_add,Refinement.localExtend] using ih.localExtend hw

theorem CaptureLocals.pushBuilder {Ψ ν L ρ kind l} (h : CaptureLocals Ψ ν L ρ)
    (hl : Ψ l = some (.builder (substKind ν kind))) :
    CaptureLocals Ψ ν (some kind :: L) (pushLocal (.loc l) ρ) := by
  intro i b hi
  cases i with
  | zero => cases hi; exact ⟨l,rfl,hl⟩
  | succ i => exact h i b hi

theorem ClosureTy.pure {P B Ψ R body a e}
    (hb : HasTypeC P B Ψ [] [] [] R body a e)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hr : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] []) :
    ClosureTy P B Ψ [] R (Closure.pure body) a e := by
  have hca : Capture.empty.closeTyAt 0 a = a := Ty.subst_values_of_wf_zero ha.wf.1 _
  have hce : Capture.empty.closeEffAt 0 e = e := Eff.subst_values_of_wf_zero ha.wf.2.1 ha.wf.2.2 _
  have hR : Capture.empty.closeRAt 0 R = R := by
    cases h : R with
    | none => rfl
    | some r => exact congrArg some (Ty.subst_values_of_wf_zero (hr r h).1 _)
  have hh := ClosureTy.mk (ss := []) (Rs := R) (a := a) (e := e) (CaptureOk.empty P B Ψ R) hb
    (CaptureLocals.empty _ _ _) (Comp.resolveLocals_id body).symm
    (by simp [TypeAnnotations]) (by simp [TypeAnnotations]) hR
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca] using (show Ty.Annotation P [] [] a from ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩))
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca,hce] using ha)
    (fun r h => (hr r h).2) (fun r h => (hr r h).2)
  simpa only [Closure.pure,List.map_nil,List.length_nil,hca,hce] using hh

theorem ClosureTy.capture_resolved {P B Ψ R Rs Γ Φ cap body a e L ρ}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hb : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs body a e L)
    (hl : CaptureLocals Ψ cap.env L ρ)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.done a e)))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap (body.resolveLocals ρ)) (cap.closeTy a) (cap.closeEff e) := by
  have ht := hc.substOk.annotation ha
  change Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) at ht
  have hr' : ∀ r, R = some r → r.Declared P [] [] := by
    intro r hh
    cases hs : Rs with
    | none => simp [Capture.closeR,hs] at hR; rw [←hR] at hh; cases hh
    | some rs =>
      have he : cap.closeTy rs = r := by simpa [Capture.closeR,hs,hh] using hR
      rw [←he]; exact (hr rs hs).bind_values hc.substOk.declaration
  have hb' : HasTypeCQ P B Ψ Qempty [] (bindParams Γ []) (liftMany 0 Φ) Rs body a e L := by
    simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,liftMany_eq,
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb
  have hh := ClosureTy.mk (ss := []) (Rs := Rs) (a := a) (e := e) hc hb'
    (by simpa only [List.length_nil,upSubst_zero] using hl) rfl
    (by simp [TypeAnnotations]) (by simp [TypeAnnotations])
    (by simpa [Capture.closeRAt,Capture.closeR,Capture.closeTyAt,Capture.closeTy,upSubst_zero] using hR)
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeTy,upSubst_zero]
        using (show Ty.Annotation P [] [] (cap.closeTy a) from ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩))
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using ht)
    (by simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hr) hr'
  simpa only [List.map_nil,List.length_nil,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using hh

theorem ClosureTy.capture {P B Ψ R Rs Γ Φ cap body a e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hb : HasTypeC P B Ψ [] Γ Φ Rs body a e)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.done a e)))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap body) (cap.closeTy a) (cap.closeEff e) := by
  simpa only [Comp.resolveLocals_id] using
    ClosureTy.capture_resolved hc hb (CaptureLocals.empty _ _ LocalRef.bound) ha hR hr

/-- Telの終端にある、全入力を束縛した位置の結果と効果。 -/
def Tel.result : Tel → Ty
  | .done a _ => a
  | .param _ _ t => t.result

def Tel.effect : Tel → Eff
  | .done _ e => e
  | .param _ _ t => t.effect

theorem Capture.openTel (cap : Capture) (v : Val) (t : Tel) :
    Tel.bind (Tel.argumentsEnv v) (Tel.bind (valEnv cap.env).up t) = (cap.extend v).closeTel t := by
  have hup : (valEnv cap.env).up = SubstEnv.valuesOnly (upValues (valEnv cap.env).values) := rfl
  rw [hup,argumentsEnv_eq,Tel.bind_values_comp]
  have he : (fun i => (upValues (valEnv cap.env).values i).bind (termBind? (openingEnv v.toTerm?))) =
      (valEnv (cap.extend v).env).values := by
    funext i
    cases i with
    | zero => rfl
    | succ i =>
      simp only [upValues]
      cases h : (valEnv cap.env).values i with
      | none => exact h.symm
      | some t =>
        simp only [Option.map_some,Option.bind_some,termBind_shift_open]
        exact h.symm
  rw [he]
  rfl

/-- 依存βの逐次具体化と、実行が行う捕捉環境の延長は同じ契約を返す。 -/
theorem Ty.open_up (cap : Capture) (v : Val) (a : Ty) :
    Ty.bind (Tel.argumentsEnv v) (a.bind (valEnv cap.env).up) = (cap.extend v).closeTy a := by
  have h := Capture.openTel cap v (.done a Eff.empty)
  simp only [Capture.closeTel,Tel.bind_done] at h
  exact (Tel.done.inj h).1

/-- 閉じた像なら、未束縛の位置に実際の値を入れても像は変わらない。 -/
theorem substKind_apply (cap : Capture) (v : Val) (k : BuilderKind)
    (hw : LocTy.WF (.builder (substKind (upSubst 1 cap.env) k))) :
    substKind (cap.extend v).env k = substKind (upSubst 1 cap.env) k := by
  cases k with
  | string | bytes => rfl
  | list a =>
    have ha : (substTyValues (upSubst 1 cap.env) a).WF 0 0 0 := hw
    have he : substTyValues (upSubst 1 cap.env) a = a.bind (valEnv cap.env).up := by
      rw [substTyValues,valEnv_upSubst_one]
    have h := Ty.open_up cap v a
    rw [←he] at h
    have hs : Ty.bind (Tel.argumentsEnv v) (substTyValues (upSubst 1 cap.env) a) =
        substTyValues (upSubst 1 cap.env) a := by
      rw [←valEnv_openValue]; exact Ty.subst_values_of_wf_zero ha _
    rw [hs] at h
    exact congrArg BuilderKind.list h.symm

/-- E_Return: 入力1個の閉包に実際の値を渡す。L は同じまま。 -/
theorem CaptureLocals.apply_one {Ψ : StoreTy} {cap : Capture} {L ρ} (h : CaptureLocals Ψ (upSubst 1 cap.env) L ρ)
    (hw : Ψ.WF) (v : Val) : CaptureLocals Ψ (cap.extend v).env L ρ := by
  intro i k hi
  obtain ⟨l,hr,ht⟩ := h i k hi
  exact ⟨l,hr,by rw [substKind_apply cap v k (hw l _ ht)]; exact ht⟩

/-- E_MatchBody 等: 腕の束縛の下へ入る。 -/
theorem CaptureLocals.extendMany {Ψ : StoreTy} (hw : Ψ.WF) (ws : List Val) :
    ∀ {cap : Capture} {L : LocalCtx} {ρ}, CaptureLocals Ψ cap.env L ρ →
    CaptureLocals Ψ (cap.extendMany ws).env (Refinement.localExtend ws.length L) (upLocalSubst ws.length ρ) := by
  induction ws with
  | nil =>
    intro cap L ρ h
    simpa only [Capture.extendMany,List.foldl_nil,List.length_nil,Refinement.localExtend,upLocalSubst_zero] using h
  | cons w ws ih =>
    intro cap L ρ h
    have h1 : CaptureLocals Ψ (cap.extend w).env (Refinement.localExtend 1 L) (upLocalSubst 1 ρ) :=
      (h.localExtend hw).apply_one hw w
    have h2 := ih h1
    have hL : ∀ n, Refinement.localExtend n (Refinement.localExtend 1 L) = Refinement.localExtend (n+1) L := by
      intro n; induction n with
      | zero => rfl
      | succ n ih => simp only [Refinement.localExtend] at ih ⊢; rw [ih]
    simpa only [Capture.extendMany,List.foldl_cons,List.length_cons,hL,upLocalSubst_add,Nat.add_comm] using h2

theorem Capture.instantiate (cap : Capture) (t : Tel) (vs : List Val) (hn : vs.length = t.arity) :
    Tel.instantiate (cap.closeTel t) vs =
      some ((cap.extendMany vs).closeTy t.result,(cap.extendMany vs).closeEff t.effect) := by
  induction vs generalizing cap t with
  | nil =>
    cases t with
    | done a e =>
      simp only [Capture.closeTel,Tel.bind_done,Tel.instantiate,Capture.extendMany,List.foldl_nil,
        Tel.result,Tel.effect,Capture.closeTy,Capture.closeEff,substTyValues,substEffValues,
        Ty.bind,Eff.bind,Ty.norm_idem,Eff.norm_idem]
    | param n a t => simp [Tel.arity,Tel.names] at hn
  | cons v vs ih =>
    cases t with
    | done a e => simp [Tel.arity,Tel.names] at hn
    | param n a t =>
      have hl : vs.length = t.arity := Nat.succ.inj hn
      simp only [Capture.closeTel,Tel.bind_param,Tel.instantiate]
      rw [Capture.openTel]
      exact ih (cap.extend v) t hl


def imageKind (b : BuilderKind) : BuilderKind := substKind builderValueSubst (renameKind (shiftIndex 1 0) b)
def imageLocal (L : LocalCtx) : LocalCtx := L.map (Option.map imageKind)

theorem builderValueSubst_eq : openValue (.const .unit) = builderValueSubst := by funext j; cases j <;> rfl

/-- 前提 hR・ha・he・hk・hL を外し、結論を像で述べた形。 -/
theorem HasTypeCQ.builderBody_image {P B Ψ Q C Γ Φ} {R : Option Ty} {body : Comp} {a : Ty} {e : Eff} {L k}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hΓ : Ctx.WF 0 C.length Γ)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)) :
    HasTypeCQ P B Ψ Q C Γ Φ ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst))
      (body.subst builderValueSubst LocalRef.bound)
      (substTyValues builderValueSubst (a.shiftV 1 0)) (substEffValues builderValueSubst (e.shiftV 1 0))
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L) := by
  have hs : SubstOk P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) Γ Φ
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
        have hn : substTyValues builderValueSubst (t.shiftV 1 0) = t := by
          have := Ty.openValue_shift t (.const .unit)
          rw [Ty.canonical_of_wf (hΓ _ _ hx),builderValueSubst_eq] at this
          exact this
        by_cases ho : t.Ordinary
        · refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
          rw [hn]; exact .V_Var hx ho
        · cases t <;> simp [Ty.Ordinary] at ho
          case cont b t e => exact .contVar rfl rfl (by rw [hn]; exact hx)
  have hf : ∀ p ∈ Φ.map Pred.lift, Entails (Γ.facts ++ Φ)
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

/-- 閉じる像は正規化を区別しない: 像の L で CaptureLocals を作り直せる。 -/
theorem substKind_image (ν : Nat → Val) (b : BuilderKind) : substKind ν (imageKind b) = substKind ν b := by
  cases b with
  | string | bytes => rfl
  | list a =>
    have h := Ty.openValue_shift a (.const .unit)
    rw [builderValueSubst_eq] at h
    simp only [imageKind,substKind,renameKind_shift,h]
    exact congrArg BuilderKind.list (Ty.rawBind_norm_congr _ (Ty.norm_idem a))



theorem CaptureLocals.imageLocal {Ψ ν L ρ} (h : CaptureLocals Ψ ν L ρ) :
    CaptureLocals Ψ ν (imageLocal L) ρ := by
  intro i b hi
  simp only [Refinement.imageLocal,List.getElem?_map] at hi
  obtain ⟨x,hx,he⟩ := Option.map_eq_some_iff.mp hi
  cases x with
  | none => cases he
  | some k =>
    cases he
    obtain ⟨l,hr,ht⟩ := h i k hx
    exact ⟨l,hr,by rw [substKind_image]; exact ht⟩

theorem Capture.closeTy_builder_image (cap : Capture) (a : Ty) :
    cap.closeTy (substTyValues builderValueSubst (a.shiftV 1 0)) = cap.closeTy a := by
  have h := Ty.openValue_shift a (.const .unit)
  rw [builderValueSubst_eq] at h
  rw [h]
  exact Ty.rawBind_norm_congr _ (Ty.norm_idem a)

theorem Eff.openValue_shift (e : Eff) (v : Val) :
    substEffValues (openValue v) (e.shiftV 1 0) = e.norm := by
  have h := Ty.openValue_shift (.dependentFn (.done (.base .unit) e)) v
  change Ty.dependentFn (.done (.base .unit) (substEffValues (openValue v) (e.shiftV 1 0))) =
    Ty.dependentFn (.done (.base .unit) e.norm) at h
  exact (Tel.done.inj (Ty.dependentFn.inj h)).2

theorem Capture.closeEff_builder_image (cap : Capture) (e : Eff) :
    cap.closeEff (substEffValues builderValueSubst (e.shiftV 1 0)) = cap.closeEff e := by
  have h := Eff.openValue_shift e (.const .unit)
  rw [builderValueSubst_eq] at h
  rw [h]
  exact Eff.norm_rawBind _ _

theorem wfList_mem {nr nt nv} : ∀ {as : List Ty}, Ty.WFList nr nt nv as ↔ ∀ a ∈ as, a.WF nr nt nv
  | [] => by simp [Ty.WFList]
  | a :: as => by simp [Ty.WFList,wfList_mem (as := as)]

theorem sortedTys_mem {Γ} : ∀ {as : List Ty}, sortedTys Γ as ↔ ∀ a ∈ as, a.Sorted Γ
  | [] => by simp [sortedTys]
  | a :: as => by simp [sortedTys,sortedTys_mem (as := as)]

theorem declaredTys_mem {P C Γ} : ∀ {as : List Ty}, declaredTys P C Γ as ↔ ∀ a ∈ as, a.Declared P C Γ
  | [] => by simp [declaredTys]
  | a :: as => by simp [declaredTys,declaredTys_mem (as := as)]

theorem Eff.canonical_mem {e : Eff} (hc : e.Canonical) {x : Ty} (hx : x ∈ e.fails) : x.norm = x := by
  cases e with
  | mk p fs =>
    have hf := congrArg Eff.fails hc
    simp only [Eff.norm,Ty.normTys_eq_map] at hf
    change Order.sortUnique tyCompare (fs.map Ty.norm) = fs at hf
    change x ∈ fs at hx
    rw [←hf] at hx
    obtain ⟨y,_,rfl⟩ := List.mem_map.mp (Order.mem_sortUnique.mp hx)
    exact Ty.norm_idem y

/-- 外側の閉じた Annotation と被覆から、内側の閉じた行の Annotation が得られる。Fail だけを読むので原子は要らない。 -/
theorem done_annotation_of_covers {P : Program} {a : Ty} {e1 ec : Eff}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e1)))
    (hc : Eff.Covers [] [] e1 ec) (hn : ec.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done a ec)) := by
  have hsub : ∀ x ∈ ec.fails, x ∈ e1.fails := by
    intro x hx
    obtain ⟨y,hy,he⟩ := hc.2 x ⟨x,hx,rfl⟩
    have hyw : y.WF 0 0 0 := by
      cases e1 with
      | mk p fs => exact wfList_mem.mp ha.wf.2.1 y hy
    have : y = x := by
      rw [←Ty.canonical_of_wf hyw,he,Eff.canonical_mem hn hx]
    exact this ▸ hy
  obtain ⟨hw,hs,hd⟩ := ha
  obtain ⟨hw1,hw2,_⟩ := hw
  obtain ⟨hs1,hs2⟩ := hs
  obtain ⟨hd1,hd2⟩ := hd
  cases e1 with
  | mk p fs =>
    cases ec with
    | mk q gs =>
      refine ⟨⟨hw1,wfList_mem.mpr fun x hx => wfList_mem.mp hw2 x (hsub x hx),hn⟩,
        ⟨hs1,sortedTys_mem.mpr fun x hx => sortedTys_mem.mp hs2 x (hsub x hx)⟩,
        ⟨hd1,declaredTys_mem.mpr fun x hx => declaredTys_mem.mp hd2 x (hsub x hx)⟩⟩


/-- 節の原子を枠の下の原子へ広げ、Failは節のまま保つ。 -/
theorem Eff.Covers.widen_atoms {Γ Φ outer inner} (h : Eff.Covers Γ Φ outer inner) :
    Eff.Covers Γ Φ (.mk outer.atoms inner.fails) inner ∧
    Eff.Sub (.mk outer.atoms inner.fails) outer := by
  cases outer; cases inner
  exact ⟨⟨h.1,fun _ hx => hx⟩,⟨fun _ hx => hx,h.2⟩⟩

theorem done_annotation_with_atoms {P : Program} {a : Ty} {e : Eff}
    (h : Ty.Annotation P [] [] (.dependentFn (.done a e))) (atoms : Atom → Bool) :
    Ty.Annotation P [] [] (.dependentFn (.done a (.mk atoms e.fails))) := by
  cases e with
  | mk p fs =>
    obtain ⟨⟨hw,hf,hc⟩,hs,hd⟩ := h
    have hc' := congrArg Eff.fails hc
    exact ⟨⟨hw,hf,congrArg (fun fs => (EffR.mk atoms fs : Eff)) hc'⟩,hs,hd⟩

end
end Benitoite.Release.Refinement
