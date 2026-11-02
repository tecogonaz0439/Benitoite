import Benitoite.Release.Refinement.TypeValueExchange
import Benitoite.Release.Refinement.PatternTypeSubst

/-! # 型置換の束縛位置の写像（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem map_typeImages_shiftV_closed {ts : List Ty} (h : ∀ t ∈ ts, t.WF 0 0 0) (n : Nat) :
    ts.map (Ty.shiftV n 0) = ts := by
  conv => rhs; rw [← List.map_id ts]
  exact List.map_congr_left (fun t ht => Ty.shiftV_of_wf_zero (h t ht) n 0)

theorem map_rowImages_shiftV_closed {es : List Eff} (h : ∀ t ∈ es, t.WF 0 0 0) (n : Nat) :
    es.map (Eff.shiftV n 0) = es := by
  conv => rhs; rw [← List.map_id es]
  exact List.map_congr_left (fun t ht => Eff.shiftV_of_wf_zero (h t ht) n 0)

theorem substAt_shiftV_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Ty) (c n : Nat) :
    (a.shiftV n 0).substAt c ts es = (a.substAt c ts es).shiftV n 0 := by
  induction n with
  | zero => simp [Ty.shiftV_zero]
  | succ n ih =>
    have h1 := Ty.substAt_up (a.shiftV n 0) c ts es
    rw [map_typeImages_shiftV_closed ht, map_rowImages_shiftV_closed he, ih] at h1
    rw [show a.shiftV (n+1) 0 = (a.shiftV n 0).shiftV 1 0 from (Ty.shiftV_add a n 1).symm ▸ rfl]
    rw [h1, Ty.shiftV_add]

theorem eff_substAt_shiftV_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Eff) (c n : Nat) :
    Eff.substAt c ts es (Eff.shiftV n 0 a) = Eff.shiftV n 0 (Eff.substAt c ts es a) := by
  induction n with
  | zero => simp [Eff.shiftV_zero]
  | succ n ih =>
    have h1 := Eff.substAt_up (Eff.shiftV n 0 a) c ts es
    rw [map_typeImages_shiftV_closed ht, map_rowImages_shiftV_closed he, ih] at h1
    rw [show Eff.shiftV (n+1) 0 a = Eff.shiftV 1 0 (Eff.shiftV n 0 a) from (Eff.shiftV_add a n 1).symm ▸ rfl]
    rw [h1, Eff.shiftV_add]


theorem cont_rawBind {a : Ty} {b t e} (h : a.core = .cont b t e) (θ : SubstEnv) :
    ∃ b' t' e', (a.rawBind θ).core = .cont b' t' e' := by
  cases a <;> simp_all [Ty.rawBind, Ty.core]
  case refined a p => exact cont_rawBind (a := a) h θ

theorem not_ord {a : Ty} (h : ¬ Ordinary a) : ∃ b t e, a.core = .cont b t e := by
  apply Classical.byContradiction
  intro hn
  exact h (fun b t e he => hn ⟨b, t, e, he⟩)

theorem cont_bind {a : Ty} (h : ¬ Ordinary a) (θ : SubstEnv) : ¬ Ordinary (a.bind θ) := by
  intro hb
  obtain ⟨b, t, e, hc⟩ := not_ord h
  obtain ⟨b', t', e', hd⟩ := cont_rawBind hc θ
  exact (Ty.ordinary_norm _).mp hb _ _ _ hd

theorem hide_entry (x : Option Ty) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    Option.map (Ty.bind θ) (match x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none) =
    (match Option.map (Ty.bind θ) x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none) := by
  cases x with
  | none => rfl
  | some a =>
    simp only [Option.map_some]
    by_cases h : Ordinary a
    · have h2 : Ordinary (a.bind θ) := Ty.ordinary_bind h θ ho
      cases hc : a.core <;> cases hd : (a.bind θ).core <;>
        first | rfl | exact False.elim (h _ _ _ hc) | exact False.elim (h2 _ _ _ hd)
    · have h2 := cont_bind h θ
      obtain ⟨b, t, e, hc⟩ := not_ord h
      obtain ⟨b', t', e', hd⟩ := not_ord h2
      simp [hc, hd]

theorem Ctx.bindTypes_hideConts (Γ : Ctx) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    (hideConts Γ).bindTypes θ = hideConts (Γ.bindTypes θ) := by
  simp only [Ctx.bindTypes, hideConts, List.map_map]
  apply List.map_congr_left
  intro x _
  exact hide_entry x θ ho

theorem Ctx.bindTypes_params {ts es} (ht : ∀ t ∈ ts, t.WF 0 0 0) (he : ∀ t ∈ es, t.WF 0 0 0)
    (Γ : Ctx) (ps : List Ty) (c : Nat) :
    (bindParams Γ ps).bindTypes (typeEnvAt c ts es) =
      bindParams (Γ.bindTypes (typeEnvAt c ts es)) (ps.map (Ty.substAt c ts es)) := by
  have hb : ∀ a : Ty, (a.shiftV ps.length 0).bind (typeEnvAt c ts es) =
      (a.bind (typeEnvAt c ts es)).shiftV ps.length 0 := fun a => substAt_shiftV_closed ht he a c _
  simp only [bindParams, Ctx.bindTypes, List.map_append, List.map_map, List.length_map, List.map_reverse]
  congr 1
  · congr 1
    apply List.map_congr_left
    intro a _
    simp [hb, Ty.substAt, substTypeAt]
  · apply List.map_congr_left
    intro x _
    cases x <;> simp [hb]

mutual
  private theorem bind_shift_source (a : Ty) (θ : SubstEnv) (k : Nat) :
      (shiftTypes k 0 a).rawBind θ =
        a.rawBind {θ with types := fun i => θ.types (i+k)} := by
    cases a <;> simp only [shiftTypes,Ty.rawBind,Nat.not_lt_zero,↓reduceIte,
      bind_shift_source,bind_shift_source_tys,bind_shift_source_eff,bind_shift_source_tel]
  private theorem bind_shift_source_tys (as : List Ty) (θ : SubstEnv) (k : Nat) :
      rawBindTys θ (shiftTypesList k 0 as) =
        rawBindTys {θ with types := fun i => θ.types (i+k)} as := by
    cases as <;> simp only [shiftTypesList,rawBindTys,bind_shift_source,bind_shift_source_tys]
  private theorem bind_shift_source_eff (e : Eff) (θ : SubstEnv) (k : Nat) :
      Eff.rawBind θ (shiftRowsTypes k 0 e) =
        Eff.rawBind {θ with types := fun i => θ.types (i+k)} e := by
    cases e; simp only [shiftRowsTypes,Eff.rawBind,bind_shift_source_tys]
  private theorem bind_shift_source_tel (t : Tel) (θ : SubstEnv) (k : Nat) :
      Tel.rawBind θ (shiftTelTypes k 0 t) =
        Tel.rawBind {θ with types := fun i => θ.types (i+k)} t := by
    cases t with
    | done r e => simp only [shiftTelTypes,Tel.rawBind,bind_shift_source,bind_shift_source_eff]
    | param n a t => simp only [shiftTelTypes,Tel.rawBind,bind_shift_source,bind_shift_source_tel]; rfl
end

private theorem typeEnv_prefix {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (c k : Nat) :
    {typeEnvAt (c+k) ts es with types := fun i => (typeEnvAt (c+k) ts es).types (i+k)} =
      (typeEnvAt c ts es).mapTypeIndices k 0 := by
  have closedT (n : Nat) : ts.map (shiftTypes n 0) = ts := by
    conv => rhs; rw [←List.map_id ts]
    exact List.map_congr_left (fun a ha => Ty.shiftTypes_of_wf_zero (h.typeWF a ha) n 0)
  have closedE (n : Nat) : es.map (shiftRowsTypes n 0) = es := by
    conv => rhs; rw [←List.map_id es]
    exact List.map_congr_left (fun e he => Eff.shiftTypes_of_wf_zero (h.rowWF e he) n 0)
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i
    by_cases hic : i < c
    · simp only [typeEnvAt,show i+k<c+k from by omega,
        hic,↓reduceIte,shiftTypes,Nat.not_lt_zero]
    · have hbig : ¬ i+k < c+k := by omega
      have sub : i+k-(c+k)=i-c := by omega
      simp only [typeEnvAt,hbig,hic,↓reduceIte,sub]
      split
      · rename_i hit
        rw [List.getElem?_eq_getElem hit]
        simp only [Option.getD_some]
        rw [Ty.shiftTypes_of_wf_zero (h.typeWF _ (List.getElem_mem hit)),
          Ty.shiftTypes_of_wf_zero (h.typeWF _ (List.getElem_mem hit)),
          Ty.shiftTypes_of_wf_zero (h.typeWF _ (List.getElem_mem hit))]
      · rename_i hit
        simp only [shiftTypes,Nat.not_lt_zero,↓reduceIte]
        congr 1; omega
  · simp only [typeEnvAt,closedE]

theorem Ty.substAt_shift_types {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (a : Ty) (c k : Nat) :
    (shiftTypes k 0 a).substAt (c+k) ts es = shiftTypes k 0 (a.substAt c ts es) := by
  change ((shiftTypes k 0 a).rawBind _).norm = shiftTypes k 0 (a.bind _)
  rw [bind_shift_source,typeEnv_prefix h,Ty.shiftTypes_bind]
  rfl

theorem Eff.substAt_shift_types {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (e : Eff) (c k : Nat) :
    Eff.substAt (c+k) ts es (shiftRowsTypes k 0 e) = shiftRowsTypes k 0 (Eff.substAt c ts es e) := by
  change (Eff.rawBind _ (shiftRowsTypes k 0 e)).norm = shiftRowsTypes k 0 (Eff.bind _ e)
  rw [bind_shift_source_eff,typeEnv_prefix h]
  simp only [Eff.bind,←Eff.norm_shiftTypes,Eff.shiftTypes_rawBind]

theorem Ctx.bindTypes_extend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (a : Ty) (c : Nat) :
    (Γ.extend a).bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extend (a.substAt c ts es) := by
  have hb (a : Ty) : (a.shiftV 1 0).bind (typeEnvAt c ts es) =
      (a.bind (typeEnvAt c ts es)).shiftV 1 0 := substAt_shiftV_closed h.typeWF h.rowWF a c 1
  simp only [Ctx.extend,Ctx.bindTypes,List.map_cons,Option.map_some,List.map_map,
    Function.comp_def,Option.map_map]
  congr 1
  · exact congrArg some (hb a)
  · apply List.map_congr_left
    intro a _
    cases a <;> simp [hb]

theorem Ctx.bindTypes_extendNone {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (c : Nat) :
    Γ.extendNone.bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extendNone := by
  simp only [Ctx.extendNone,Ctx.bindTypes,List.map_cons,Option.map_none,List.map_map,
    Function.comp_def,Option.map_map]
  congr 1
  apply List.map_congr_left
  intro a _
  cases a with
  | none => rfl
  | some a => exact congrArg some (substAt_shiftV_closed h.typeWF h.rowWF a c 1)

theorem Ctx.bindTypes_extendMany {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (as : List Ty) (c : Nat) :
    (Γ.extendMany as).bindTypes (typeEnvAt c ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).extendMany (as.map (Ty.substAt c ts es)) := by
  induction as generalizing Γ with
  | nil => rfl
  | cons a as ih =>
    simp only [Ctx.extendMany,List.map_cons,ih,Ctx.bindTypes_extend h]

theorem Ctx.bindTypes_shiftE {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (c k : Nat) :
    (Γ.shiftE k).bindTypes (typeEnvAt (c+k) ts es) =
      (Γ.bindTypes (typeEnvAt c ts es)).shiftE k := by
  simp only [Ctx.shiftE,Ctx.shiftEAt,Ctx.bindTypes,List.map_map,Function.comp_def,Option.map_map]
  apply List.map_congr_left
  intro a _
  cases a with
  | none => rfl
  | some a => exact congrArg some (Ty.substAt_shift_types h a c k)

noncomputable def OpSig.substAt (c : Nat) (ts : List Ty) (es : List Eff) (sg : OpSig) : OpSig :=
  {sg with params := sg.params.map (Ty.substAt c ts es),ret := sg.ret.substAt c ts es}

theorem OpSig.context_typeSubst {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) (c : Nat) :
    (sg.context Γ t e).bindTypes (typeEnvAt (c+sg.tparams.length) ts es) =
      (sg.substAt (c+sg.tparams.length) ts es).context
        (Γ.bindTypes (typeEnvAt c ts es)) (t.substAt c ts es) (Eff.substAt c ts es e) := by
  simp only [OpSig.context,Ctx.bindTypes_extend h,Ctx.bindTypes_extendMany h,Ctx.bindTypes_shiftE h,
    OpSig.substAt]
  congr 1
  change (Ty.cont sg.ret ((shiftTypes sg.tparams.length 0 t).shiftV sg.params.length 0)
    ((shiftRowsTypes sg.tparams.length 0 e).shiftV sg.params.length 0)).substAt
      (c+sg.tparams.length) ts es = _
  simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm]
  change Ty.cont _ ((shiftTypes sg.tparams.length 0 t).shiftV sg.params.length 0 |>.substAt
    (c+sg.tparams.length) ts es)
    (Eff.substAt (c+sg.tparams.length) ts es
      ((shiftRowsTypes sg.tparams.length 0 e).shiftV sg.params.length 0)) = _
  rw [substAt_shiftV_closed h.typeWF h.rowWF,eff_substAt_shiftV_closed h.typeWF h.rowWF,
    Ty.substAt_shift_types h,Eff.substAt_shift_types h]
  simp only [OpSig.continuation,List.length_map,Ty.substAt,substTypeAt,Ty.bind]

theorem failureContext_typeSubst {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (Γ : Ctx) (E : Ty) (c : Nat) :
    (failureContext Γ E).bindTypes (typeEnvAt (c+1) ts es) =
      failureContext (Γ.bindTypes (typeEnvAt c ts es)) (E.substAt c ts es) := by
  simp only [failureContext,Ctx.bindTypes_extendNone h,Ctx.bindTypes_extend h,
    Ctx.bindTypes_shiftE h,Ty.substAt_shift_types h]

theorem BuilderKind.substAt_rename_shift {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (b : BuilderKind) (c n : Nat) :
    BuilderKind.substAt c ts es (renameKind (shiftIndex n 0) b) =
      renameKind (shiftIndex n 0) (BuilderKind.substAt c ts es b) := by
  cases b <;> simp only [renameKind_shift,BuilderKind.substAt]
  exact congrArg BuilderKind.list (substAt_shiftV_closed h.typeWF h.rowWF _ c n)

theorem LocalCtx.typeSubst_extend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (L : LocalCtx) (b : Option BuilderKind) (c : Nat) :
    (LocalCtx.extend b L).map (Option.map (BuilderKind.substAt c ts es)) =
      LocalCtx.extend (b.map (BuilderKind.substAt c ts es))
        (L.map (Option.map (BuilderKind.substAt c ts es))) := by
  simp only [LocalCtx.extend,List.map_cons,List.map_map,Function.comp_def,Option.map_map]
  congr 1
  apply List.map_congr_left
  intro a _
  cases a with
  | none => rfl
  | some a => exact congrArg some (BuilderKind.substAt_rename_shift h a c 1)

theorem LocalCtx.typeSubst_localExtend {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (L : LocalCtx) (c n : Nat) :
    (localExtend n L).map (Option.map (BuilderKind.substAt c ts es)) =
      localExtend n (L.map (Option.map (BuilderKind.substAt c ts es))) := by
  induction n with
  | zero => rfl
  | succ n ih => simp only [localExtend,LocalCtx.typeSubst_extend h,Option.map_none,ih]

theorem return_typeSubst_shiftV {P B C0 C1 ts es} (h : TypeSubstInput P B C0 C1 ts es)
    (R : Option Ty) (c n : Nat) :
    (R.map (Ty.shiftV n 0)).map (Ty.substAt c ts es) =
      (R.map (Ty.substAt c ts es)).map (Ty.shiftV n 0) := by
  cases R with
  | none => rfl
  | some a => exact congrArg some (substAt_shiftV_closed h.typeWF h.rowWF a c n)

theorem TypeSubstCode.binders {es : List Eff} {source child : Nat → Nat → Nat → Nat → Prop}
    (h : TypeSubstCode es source) (k n : Nat)
    (hc : ∀ nr nt ne nv, source nr nt ne nv → child nr (nt+k) ne (nv+n)) :
    TypeSubstCode es child :=
  h.imp id (fun ⟨nr,nt,ne,nv,hs⟩ => ⟨nr,nt+k,ne,nv+n,hc nr nt ne nv hs⟩)

theorem S02Internal.C.under_types (ih : S02Internal.C) {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ R m a e L ts es} (extra : TypeCtx)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (ht : HasTypeCQ P B Ψ Q (extra ++ C1 ++ C0) Γ Φ R m a e L) :
    HasTypeCQ P B Ψ Q' (extra ++ C1)
      (Γ.bindTypes (typeEnvAt (extra ++ C1).length ts es)) Φ
      (R.map (Ty.substAt (extra ++ C1).length ts es))
      (m.substTyAt (extra ++ C1).length ts es) (a.substAt (extra ++ C1).length ts es)
      (Eff.substAt (extra ++ C1).length ts es e)
      (L.map (Option.map (BuilderKind.substAt (extra ++ C1).length ts es))) := by
  have out := ih hf (hi.under hf.2.2.1 extra) hc hq (by simpa only [List.append_assoc] using ht)
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro b _
  cases b with
  | none => rfl
  | some b => cases b <;> rfl

end
theorem Ty.rawBind_shift_source (a : Ty) (θ : SubstEnv) (k : Nat) :
    (shiftTypes k 0 a).rawBind θ = a.rawBind {θ with types := fun i => θ.types (i+k)} :=
  bind_shift_source a θ k

end Benitoite.Release.Refinement
