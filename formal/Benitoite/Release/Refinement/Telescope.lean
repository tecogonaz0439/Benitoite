import Benitoite.Release.Refinement.RangeExchange

/-!
# 非依存関数との対応と依存列の具体化

互換入口の各注釈は、それより前の引数数だけ移動する。
-/
namespace Benitoite.Release.Refinement


def Tel.arity (t : Tel) : Nat := t.names.length



theorem Tel.arity_toTel {ns ps r e} (h : NamesWF ns ps) : (Ty.toTel ns ps r e).arity = ps.length := by
  simp only [Tel.arity, Tel.names_toTel h, h.1]

mutual
  theorem Tel.names_rawBind (t : Tel) (θ : SubstEnv) : (Tel.rawBind θ t).names = t.names := by
    cases t <;> simp only [Tel.rawBind, Tel.names, Tel.names_rawBind]
end

theorem Tel.names_norm (t : Tel) : (Tel.norm t).names = t.names := by
  cases t with
  | done r e => rfl
  | param n a t => simp only [Tel.norm, Tel.names, Tel.names_norm]

theorem Tel.names_shiftV (t : Tel) (k c : Nat) : (Tel.shiftV k c t).names = t.names := by
  cases t with
  | done r e => rfl
  | param n a t => simp only [Tel.shiftV, Tel.names, Tel.names_shiftV]


theorem Tel.bind_toTel (ns ps r e) (θ : SubstEnv) :
    Tel.bind θ (Ty.toTel ns ps r e) =
      Ty.toTel ns (ps.map (Ty.bind θ)) (r.bind θ) (Eff.bind θ e) := by
  simp only [Tel.bind, Tel.rawBind_toTel, Tel.norm_toTel, rawBindTys_eq_map, Ty.normTys_eq_map,
    Ty.bind, Eff.bind, List.map_map]
  rfl


theorem Tel.wf_toTel {nr nt nv ns ps r e}
    (hn : NamesWF ns ps) (hp : Ty.WFList nr nt nv ps) (hr : r.WF nr nt nv)
    (he : Eff.WF nr nt nv e) (hc : Eff.Canonical e) : Tel.WF nr nt nv (Ty.toTel ns ps r e) := by
  induction ns generalizing ps r e nv with
  | nil => cases ps <;> simp_all [Ty.toTel, Tel.WF, NamesWF]
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      refine ⟨hp.1, ih ⟨by simpa [NamesWF] using hn.1, hn.2.of_cons⟩
        (Ty.wfList_shiftV hp.2 1 0) (Ty.wf_shiftV hr 1 0) (Eff.wf_shiftV he 1 0) ?_⟩
      simpa only [Eff.Canonical, Eff.norm_shiftV] using congrArg (Eff.shiftV 1 0) hc

def Tel.argumentsEnv (v : Val) : SubstEnv :=
  valEnv (fun i => match i with | 0 => v | j+1 => .var j)

noncomputable def Tel.instantiate : Tel → List Val → Option (Ty × Eff)
  | .done r e, [] => some (r.norm, Eff.norm e)
  | .param _ _ t, v :: vs => Tel.instantiate (Tel.bind (Tel.argumentsEnv v) t) vs
  | _, _ => none
termination_by _ vs => vs.length

theorem TelLe.names {Γ Φ t u} (h : TelLe Γ Φ t u) : t.names = u.names := by
  match h with
  | .done _ _ => rfl
  | .param _ ht => exact congrArg (List.cons _) ht.names

theorem TelClosure.names {Γ Φ t u} (h : TelClosure Γ Φ t u) : t.names = u.names := by
  match h with
  | .refl => rfl
  | .tail hp hs => exact hp.names.trans hs.names

theorem TelLe.arity {Γ Φ t u} (h : TelLe Γ Φ t u) : t.arity = u.arity := congrArg List.length h.names
theorem TelClosure.arity {Γ Φ t u} (h : TelClosure Γ Φ t u) : t.arity = u.arity := congrArg List.length h.names

noncomputable def Tel.substAt (c : Nat) (ts : List Ty) (es : List Eff) (t : Tel) : Tel :=
  Tel.bind (typeEnvAt c ts es) t
noncomputable def Tel.subst (ts : List Ty) (es : List Eff) (t : Tel) : Tel := Tel.substAt 0 ts es t
noncomputable def Tel.substV (ν : ObservationEnv) (t : Tel) : Tel := Tel.bind (SubstEnv.valuesOnly ν) t
noncomputable def Tel.substVAt (c : Nat) (ν : ObservationEnv) (t : Tel) : Tel := Tel.substV (upTerms c ν) t
noncomputable def Tel.mapRanges (ρ : Nat → RangeIx) (t : Tel) : Tel := Tel.norm (Tel.rawMapRanges ρ t)
noncomputable def Tel.substRAt (c : Nat) (rs : List RangeExpr) (t : Tel) : Tel := Tel.mapRanges (rangeAt c rs) t
noncomputable def Tel.instR (rs : List RangeExpr) (t : Tel) : Tel := Tel.substRAt 0 rs t
noncomputable def Tel.shiftR (k c : Nat) (t : Tel) : Tel := Tel.mapRanges (fun i => .rvar (shiftIndex k c i)) t

theorem TelLe.substV {Γ Φ Δ Ψ t u ν} (h : TelLe Γ Φ t u)
    (hm : Transport (SubstEnv.valuesOnly ν) Γ Φ Δ Ψ) :
    TelLe Δ Ψ (Tel.substV ν t) (Tel.substV ν u) := h.bind _ hm

theorem TelClosure.substV {Γ Φ Δ Ψ t u ν} (h : TelClosure Γ Φ t u)
    (hm : Transport (SubstEnv.valuesOnly ν) Γ Φ Δ Ψ) :
    TelClosure Δ Ψ (Tel.substV ν t) (Tel.substV ν u) := h.bind _ hm

theorem TelLe.substAt {Γ Φ t u} (h : TelLe Γ Φ t u) (c : Nat) (ts : List Ty) (es : List Eff)
    (ho : ∀ a ∈ ts, Ordinary a) :
    TelLe (Γ.bindTypes (typeEnvAt c ts es)) Φ (Tel.substAt c ts es t) (Tel.substAt c ts es u) :=
  h.bind _ (Transport.types Γ Φ _ rfl (typeEnvAt_ordinary c ts es ho))

theorem TelClosure.substAt {Γ Φ t u} (h : TelClosure Γ Φ t u) (c : Nat) (ts : List Ty) (es : List Eff)
    (ho : ∀ a ∈ ts, Ordinary a) :
    TelClosure (Γ.bindTypes (typeEnvAt c ts es)) Φ (Tel.substAt c ts es t) (Tel.substAt c ts es u) :=
  h.bind _ (Transport.types Γ Φ _ rfl (typeEnvAt_ordinary c ts es ho))

theorem TelLe.mapRanges {Γ Φ t u} (h : TelLe Γ Φ t u) (ρ : Nat → RangeIx) :
    TelLe (Γ.mapRanges ρ) Φ (Tel.mapRanges ρ t) (Tel.mapRanges ρ u) := by
  have he := (h.rawMapRanges ρ).norm.context (Ctx.TypeMap.norm (Γ.rawMapRanges ρ))
  have hc : (Γ.rawMapRanges ρ).map (Option.map Ty.norm) = Γ.mapRanges ρ := by
    simp only [Ctx.rawMapRanges, Ctx.mapRanges, List.map_map, Function.comp_def, Option.map_map]
    rfl
  rw [hc] at he
  exact he

theorem TelClosure.mapRanges {Γ Φ t u} (h : TelClosure Γ Φ t u) (ρ : Nat → RangeIx) :
    TelClosure (Γ.mapRanges ρ) Φ (Tel.mapRanges ρ t) (Tel.mapRanges ρ u) := by
  have he := (h.rawMapRanges ρ).norm.context (Ctx.TypeMap.norm (Γ.rawMapRanges ρ))
  have hc : (Γ.rawMapRanges ρ).map (Option.map Ty.norm) = Γ.mapRanges ρ := by
    simp only [Ctx.rawMapRanges, Ctx.mapRanges, List.map_map, Function.comp_def, Option.map_map]
    rfl
  rw [hc] at he
  exact he

theorem Tel.instR_eq_bind (t : Tel) (rs : List RangeExpr) :
    Tel.instR rs t = Tel.bind (SubstEnv.rangesOnly rs) t := by
  simp only [Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawMapRanges_rangesOnly]

theorem Tel.names_bind (t : Tel) (θ : SubstEnv) : (Tel.bind θ t).names = t.names := by
  rw [Tel.bind, Tel.names_norm, Tel.names_rawBind]

theorem Tel.instantiate_length {t vs result} (h : Tel.instantiate t vs = some result) : t.arity = vs.length := by
  induction vs generalizing t with
  | nil => cases t <;> simp_all [Tel.instantiate, Tel.arity, Tel.names]
  | cons v vs ih =>
    cases t with
    | done r e => simp only [Tel.instantiate, reduceCtorEq] at h
    | param n a t =>
      have hh := ih (t := Tel.bind (Tel.argumentsEnv v) t) (by simpa only [Tel.instantiate] using h)
      simpa only [Tel.arity, Tel.names, List.length_cons, Tel.names_bind] using congrArg Nat.succ hh

theorem TelLe.shiftV {Γ Φ t u} (h : TelLe Γ Φ t u) (k c : Nat) :
    TelLe (Γ.shiftV k c) (Φ.map (Pred.shiftV k c)) (Tel.shiftV k c t) (Tel.shiftV k c u) := by
  rw [Tel.shiftV_eq_rawBind, Tel.shiftV_eq_rawBind]
  exact h.rawBind _ (Transport.shiftV Γ Φ k c)

theorem TelClosure.shiftV {Γ Φ t u} (h : TelClosure Γ Φ t u) (k c : Nat) :
    TelClosure (Γ.shiftV k c) (Φ.map (Pred.shiftV k c)) (Tel.shiftV k c t) (Tel.shiftV k c u) := by
  rw [Tel.shiftV_eq_rawBind, Tel.shiftV_eq_rawBind]
  exact h.rawBind _ (Transport.shiftV Γ Φ k c)

end Benitoite.Release.Refinement
