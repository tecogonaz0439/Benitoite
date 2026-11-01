import Benitoite.Release.Refinement.LegacyTables

/-! # 旧構文からの値の葉と正規化の限定等号 -/
namespace Benitoite.Release.Refinement
noncomputable section

variable {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred}

theorem embed_const (c : Benitoite.Release.Const) (hc : ConstOK B (embedConst c)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (embedConst c)) (embedTy c.type) := by
  rw [← Const.type_embed]; exact .V_Const hc

theorem embed_bytes (bs : List Nat) (hb : ∀ b ∈ bs, b ≤ 255) :
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) .bytes := .V_Bytes hb

theorem embed_checked {o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked target) (.scoped o k (.fixed (.absolute range))) :=
  .V_Checked hk hc hm

theorem embed_checkedRequest {o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true) (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target (embedVal req))
      (.scoped o .endpoint (.fixed (.absolute range))) := .V_CheckedRequest hk hc ht hg he hm

theorem embed_checked_opaque {o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (embedVal (.checked target)) (embedTy (.opaque o (.fixed range))) :=
  .V_Sub (embed_checked hk hc hm) .scoped_forget trivial trivial trivial

theorem embed_checkedRequest_opaque {o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true) (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (embedVal (.checkedRequest target req)) (embedTy (.opaque o (.fixed range))) :=
  .V_Sub (embed_checkedRequest hk hc ht hg he hm) .scoped_forget trivial trivial trivial

theorem embed_normal_eq_iff (a b : Benitoite.Release.Ty) :
    (embedTy a).norm = (embedTy b).norm ↔ a.norm = b.norm := by
  constructor
  · intro h; exact embedTy_injective (by simpa only [embedTy_norm] using h)
  · intro h; rw [← embedTy_norm, ← embedTy_norm, h]

/- 旧型には値を読む述語がない。文脈の長さと内容への非依存を構文で示す。 -/
mutual
  theorem embedTy_wf_values (a : Benitoite.Release.Ty) (nr nt n m : Nat) :
      (embedTy a).WF nr nt n ↔ (embedTy a).WF nr nt m := by
    cases a <;> simp only [embedTy, Ty.WF, (fun a => embedTy_wf_values a nr nt n m), (fun as => embedTys_wf_values as nr nt n m), (fun e => embedEff_wf_values e nr nt n m)]
  theorem embedTys_wf_values (as : List Benitoite.Release.Ty) (nr nt n m : Nat) :
      Ty.WFList nr nt n (embedTys as) ↔ Ty.WFList nr nt m (embedTys as) := by
    cases as <;> simp only [embedTys, Ty.WFList, (fun a => embedTy_wf_values a nr nt n m), (fun as => embedTys_wf_values as nr nt n m)]
  theorem embedEff_wf_values (e : Benitoite.Release.Eff) (nr nt n m : Nat) :
      (embedEff e).WF nr nt n ↔ (embedEff e).WF nr nt m := by
    cases e; exact embedTys_wf_values _ nr nt n m
end

mutual
  theorem embedTy_sorted (a : Benitoite.Release.Ty) (Γ : Ctx) : (embedTy a).Sorted Γ := by
    cases a <;> simp only [embedTy, Ty.Sorted]
    all_goals first | trivial | exact embedTy_sorted _ Γ | exact embedTys_sorted _ Γ | skip
    case fn ns ps r e => exact ⟨embedTys_sorted ps Γ, embedTy_sorted r Γ, embedEff_sorted e Γ⟩
    case cont a b e => exact ⟨embedTy_sorted a Γ, embedTy_sorted b Γ, embedEff_sorted e Γ⟩
    case map a b => exact ⟨embedTy_sorted a Γ, embedTy_sorted b Γ⟩
  theorem embedTys_sorted (as : List Benitoite.Release.Ty) (Γ : Ctx) : sortedTys Γ (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embedTy_sorted a Γ, embedTys_sorted as Γ⟩
  theorem embedEff_sorted (e : Benitoite.Release.Eff) (Γ : Ctx) : sortedEff Γ (embedEff e) := by
    cases e; exact embedTys_sorted _ Γ
end

mutual
  theorem embedTy_declared_context (a : Benitoite.Release.Ty) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      (embedTy a).Declared P C Γ ↔ (embedTy a).Declared P D Δ := by
    cases a <;> simp only [embedTy, Ty.Declared, (fun a => embedTy_declared_context a P C D Γ Δ), (fun as => embedTys_declared_context as P C D Γ Δ),
      (fun e => embedEff_declared_context e P C D Γ Δ)]
    case ctor c => cases c <;> rfl
  theorem embedTys_declared_context (as : List Benitoite.Release.Ty) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      declaredTys P C Γ (embedTys as) ↔ declaredTys P D Δ (embedTys as) := by
    cases as <;> simp only [embedTys, declaredTys, (fun a => embedTy_declared_context a P C D Γ Δ), (fun as => embedTys_declared_context as P C D Γ Δ)]
  theorem embedEff_declared_context (e : Benitoite.Release.Eff) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      declaredEff P C Γ (embedEff e) ↔ declaredEff P D Δ (embedEff e) := by
    cases e; exact embedTys_declared_context _ P C D Γ Δ
end

theorem LegacyTypesInput.kindArgs {K P0 Δ ts ks} (h : LegacyTypesInput K P0 Δ ts ks) :
    LegacyKindArgs K P0 Δ.kinds ts ks :=
  ⟨h.1, fun i a k ha hk => ⟨(h.2 i a k ha hk).1.1, (h.2 i a k ha hk).2⟩⟩

theorem LegacyTypeInput.annotation {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints (List.replicate Δ.nv none) (embedTy a) :=
  ⟨by simpa only [nr, List.length_replicate, count] using h.2.1, h.2.2.1, h.2.2.2.1⟩

theorem LegacyTypeInput.normal_kind {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k) :
    (embedTy a).norm.HasKind (embedProgramWithKinds K P0) Δ.kinds k := h.1.norm

theorem LegacyTypeInput.annotation_at {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints Γ (embedTy a) := by
  refine ⟨?_, embedTy_sorted a Γ, ?_⟩
  · have moved := (embedTy_wf_values a Δ.nr Δ.kinds.length Δ.nv Γ.length).mp h.2.1
    simpa only [nr, count] using moved
  · exact (embedTy_declared_context a _ _ _ _ _).mp h.2.2.2.1

theorem LegacyTypeInput.annotation_normal {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints Γ (embedTy a).norm :=
  (h.annotation_at nr count Γ).norm

/-- 最上位の範囲の具体化は、同じ長さの列どうしで WF を保つ。型変数は変えない。 -/
theorem embed_instTarget_wf_iff (a : Benitoite.Release.Ty)
    {rs qs : List Scope.Domain.Range} (count : rs.length = qs.length) (nr nt nv : Nat) :
    (embedTy (a.instTarget rs)).WF nr nt nv ↔ (embedTy (a.instTarget qs)).WF nr nt nv := by
  cases a with
  | «opaque» o ix =>
    cases ix with
    | fixed r => rfl
    | rvar i =>
      cases hs : rs[i]? with
      | none =>
        cases ht : qs[i]? with
        | none => simp only [Benitoite.Release.Ty.instTarget, Scope.Signature.Ix.inst, hs, ht]
        | some r =>
          have hle := List.getElem?_eq_none_iff.mp hs
          have hlt := (List.getElem?_eq_some_iff.mp ht).1
          omega
      | some r =>
        cases ht : qs[i]? with
        | none =>
          have hle := List.getElem?_eq_none_iff.mp ht
          have hlt := (List.getElem?_eq_some_iff.mp hs).1
          omega
        | some q => simp only [Benitoite.Release.Ty.instTarget, Scope.Signature.Ix.inst, hs, ht,
            embedTy, embedIx, Ty.WF, RangeIx.WF]
  | _ => rfl

theorem embed_instTargetList_wf_iff (as : List Benitoite.Release.Ty)
    {rs qs : List Scope.Domain.Range} (count : rs.length = qs.length) (nr nt nv : Nat) :
    Ty.WFList nr nt nv (embedTys (as.map (Benitoite.Release.Ty.instTarget rs))) ↔
      Ty.WFList nr nt nv (embedTys (as.map (Benitoite.Release.Ty.instTarget qs))) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.map_cons, embedTys, Ty.WFList,
      embed_instTarget_wf_iff a count nr nt nv, ih]

/-- Top と同じ個数の節の範囲 S は、署名の引数の形成を保持する。 -/
theorem embed_clause_signature_wf (names : List String) (params : List Benitoite.Release.Ty)
    (ret : Benitoite.Release.Ty) (eff : Benitoite.Release.Eff)
    (rs qs : List Scope.Domain.Range) (count : rs.length = qs.length) (nr nt nv : Nat)
    (h : (embedTy (.fn names (params.map (Benitoite.Release.Ty.instTarget rs)) ret eff)).WF nr nt nv) :
    (embedTy (.fn names (params.map (Benitoite.Release.Ty.instTarget qs)) ret eff)).WF nr nt nv := by
  refine ⟨?_, (embed_instTargetList_wf_iff params count nr nt nv).mp h.2.1, h.2.2⟩
  simpa only [NamesWF, embedTys_eq_map, List.length_map] using h.1

/-- opSig の Top に対する形成を、実際に選んだ節の範囲へ渡す。 -/
theorem legacy_opSigAt_signature_wf {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
    {o : Benitoite.Release.OpRef} {topSig selected : Benitoite.Release.OpSig} {S : Scope.Domain.Range}
    (source : Benitoite.Release.opSig P0 B0 o = some topSig)
    (target : Benitoite.Release.opSigAt P0 B0 S o = some selected)
    (h : (embedTy (.fn topSig.names topSig.params topSig.ret
      (Benitoite.Release.Eff.single topSig.eff))).WF 0 topSig.tparams.length 0) :
    (embedTy (.fn selected.names selected.params selected.ret
      (Benitoite.Release.Eff.single selected.eff))).WF 0 selected.tparams.length 0 := by
  cases o with
  | fail => cases source
  | user o =>
    cases ho : P0.ops o with
    | none => simp [Benitoite.Release.opSig, ho] at source
    | some od =>
      simp only [Benitoite.Release.opSig, Benitoite.Release.opSigAt, ho, Option.map_some, Option.some.injEq] at source target
      subst topSig; subst selected; exact h
  | prim b =>
    cases hb : B0.sig b with
    | none => simp [Benitoite.Release.opSig, hb] at source
    | some sg =>
      cases he : sg.opEff with
      | none => simp [Benitoite.Release.opSig, hb, he] at source
      | some effect =>
        simp only [Benitoite.Release.opSig, Benitoite.Release.opSigAt, hb, he, Option.some.injEq] at source target
        subst topSig; subst selected
        exact embed_clause_signature_wf sg.names sg.params sg.ret (Benitoite.Release.Eff.single effect)
          sg.topRanges (List.replicate sg.nranges S) (by simp [Benitoite.Release.PrimSig.topRanges]) 0 sg.tparams.length 0 h

theorem LegacyClausesInput.signature_wf {K P0 B0 B Δ o n k body cs}
    (input : LegacyClausesInput K P0 B0 B Δ (.mk o n k body :: cs))
    {S : Scope.Domain.Range} {sg : Benitoite.Release.OpSig}
    (lookup : Benitoite.Release.opSigAt P0 B0 S o = some sg) :
    (embedTy (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff))).WF 0 sg.tparams.length 0 := by
  obtain ⟨⟨topSig, hs, hk, _, annotation, _⟩, _⟩ := input
  apply legacy_opSigAt_signature_wf hs lookup
  simpa only [List.length_replicate, hk] using annotation.2.1

end
end Benitoite.Release.Refinement
