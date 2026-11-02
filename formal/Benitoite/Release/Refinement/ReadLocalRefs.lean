import Benitoite.Release.Refinement.ContinuationGeneral

/-! # 型付きの捕捉位置と専用参照の有効性 -/
namespace Benitoite.Release.Refinement
noncomputable section

def BuilderLive (μ : Store) (l : Nat) : Prop := ∃ c, μ l = some (.builder c)
def StoreTy.BuilderPlaces (Ψ : StoreTy) (places : Nat → Prop) : Prop :=
  ∀ l kind, Ψ l = some (.builder kind) → places l
def LocalRef.Allowed (depth : Nat) (places : Nat → Prop) : LocalRef → Prop
  | .bound i => i < depth
  | .loc l => places l

def Val.LocalLeaf : Val → Prop
  | .var .. | .const .. | .fnRef .. | .prim .. | .op .. | .raise .. | .loc .. |
    .bytesV .. | .externalRef .. | .externalHandle .. | .pathBases .. |
    .scopePattern .. | .atError .. | .checked .. => True
  | _ => False

mutual
  inductive Val.LocalRefs (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → Val → Prop where
    | leaf {Ψ depth places v} : v.LocalLeaf → Val.LocalRefs P B Ψ depth places v
    | lam {Ψ depth places ns ps body} : Comp.LocalRefs P B (hideBuilders Ψ) ps.length (fun _ => False) body →
        Val.LocalRefs P B Ψ depth places (.lam ns ps body)
    | dependentLam {Ψ depth places t body} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Val.LocalRefs P B Ψ depth places (.dependentLam t body)
    | closure {Ψ depth places runtime cap code Γ Φ t} :
        CaptureOk P B (hideBuilders Ψ) none Γ Φ cap →
        TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ t code →
        Capture.LocalRefs P B (hideBuilders Ψ) Γ Φ cap →
        Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) code →
        Val.LocalRefs P B Ψ depth places (.closure runtime (.mk cap code))
    | con {Ψ depth places c ts vs} : Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefs P B Ψ depth places (.con c ts vs)
    | list {Ψ depth places vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.list vs)
    | setV {Ψ depth places vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.setV vs)
    | dict {Ψ depth places i ts vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.dict i ts vs)
    | mapV {Ψ depth places ks vs} : Val.LocalRefsList P B Ψ depth places ks → Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefs P B Ψ depth places (.mapV ks vs)
    | super {Ψ depth places v cl} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefs P B Ψ depth places (.super v cl)
    | checkedRequest {Ψ depth places t req} : Val.LocalRefs P B Ψ 0 (fun _ => False) req →
        Val.LocalRefs P B Ψ depth places (.checkedRequest t req)
    | checkedAt {Ψ depth places range snapshot target req} :
        (∀ v, req = some v → Val.LocalRefs P B Ψ 0 (fun _ => False) v) →
        Val.LocalRefs P B Ψ depth places (.checkedAt range snapshot target req)
  inductive Val.LocalRefsList (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → List Val → Prop where
    | nil {Ψ depth places} : Val.LocalRefsList P B Ψ depth places []
    | cons {Ψ depth places v vs} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefsList P B Ψ depth places (v::vs)
  inductive Comp.LocalRefs (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → Comp → Prop where
    | builderLet {Ψ depth places kind body} : Comp.LocalRefs P B Ψ (depth+1) places body →
        Comp.LocalRefs P B Ψ depth places (.builderLet kind body)
    | builderOp {Ψ depth places kind op r vs} : LocalRef.Allowed depth places r → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.builderOp kind op r vs)
    | ret {Ψ depth places v} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places (.ret v)
    | escape {Ψ depth places v} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places (.escape v)
    | letIn {Ψ depth places m n} : Comp.LocalRefs P B Ψ depth places m → Comp.LocalRefs P B Ψ (depth+1) places n →
        Comp.LocalRefs P B Ψ depth places (.letIn m n)
    | app {Ψ depth places f vs} : Val.LocalRefs P B Ψ depth places f → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.app f vs)
    | ite {Ψ depth places v m n} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places m →
        Comp.LocalRefs P B Ψ depth places n → Comp.LocalRefs P B Ψ depth places (.ite v m n)
    | matchC {Ψ depth places v arms} : Val.LocalRefs P B Ψ depth places v → Arm.LocalRefsList P B Ψ depth places arms →
        Comp.LocalRefs P B Ψ depth places (.match v arms)
    | lazyC {Ψ depth places m} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) m →
        Comp.LocalRefs P B Ψ depth places (.lazyC m)
    | use {Ψ depth places v m} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places m →
        Comp.LocalRefs P B Ψ depth places (.use v m)
    | handle {Ψ depth places m cs} : Comp.LocalRefs P B Ψ depth places m → Clause.LocalRefsList P B Ψ cs →
        Comp.LocalRefs P B Ψ depth places (.handle m cs)
    | resume {Ψ depth places k v} : Val.LocalRefs P B Ψ depth places k → Val.LocalRefs P B Ψ depth places v →
        Comp.LocalRefs P B Ψ depth places (.resume k v)
    | externalCall {Ψ depth places f ts vs} : Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.externalCall f ts vs)
    | issuePathBases {Ψ depth places b} : Comp.LocalRefs P B Ψ depth places (.issuePathBases b)
    | checkAt {Ψ depth places kind name shape bases pattern input index} :
        (∀ v, bases = some v → Val.LocalRefs P B Ψ depth places v) →
        Val.LocalRefs P B Ψ depth places pattern → Val.LocalRefs P B Ψ depth places input →
        Comp.LocalRefs P B Ψ depth places (.checkAt kind name shape bases pattern input index)
    | meth {Ψ depth places v m ts es vs} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.meth v m ts es vs)
  inductive Arm.LocalRefsList (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → List Arm → Prop where
    | nil {Ψ depth places} : Arm.LocalRefsList P B Ψ depth places []
    | plain {Ψ depth places alts body arms} : Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places body →
        Arm.LocalRefsList P B Ψ depth places arms → Arm.LocalRefsList P B Ψ depth places (.mk alts none body::arms)
    | guarded {Ψ depth places alts guard body arms} : Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places guard →
        Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places body → Arm.LocalRefsList P B Ψ depth places arms →
        Arm.LocalRefsList P B Ψ depth places (.mk alts (some guard) body::arms)
  inductive Clause.LocalRefsList (P : Program) (B : Builtins) : StoreTy → List Clause → Prop where
    | nil {Ψ} : Clause.LocalRefsList P B Ψ []
    | cons {Ψ o n k body cs} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Clause.LocalRefsList P B Ψ cs → Clause.LocalRefsList P B Ψ (.mk o n k body::cs)
    | fail {Ψ e body} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Clause.LocalRefsList P B Ψ [.fail e body]
  /-- 通常値の像だけを再帰して検査する。型・述語・snapshot の参照は Transport が保持する。 -/
  inductive Capture.LocalRefs (P : Program) (B : Builtins) : StoreTy → Ctx → List Pred → Capture → Prop where
    | mk {Ψ Γ Φ cap} : Transport (valEnv cap.env) Γ Φ [] [] →
        (∀ i a, Γ[i]? = some (some a) → a.Ordinary → Val.LocalRefs P B Ψ 0 (fun _ => False) (cap.env i)) →
        Capture.LocalRefs P B Ψ Γ Φ cap
end

def Val.NoFreeBuilders (P : Program) (B : Builtins) (Ψ : StoreTy) (v : Val) : Prop :=
  Val.LocalRefs P B Ψ 0 (fun _ => False) v

def LocalCtx.Resolved (L : LocalCtx) (ρ : Nat → LocalRef) (depth : Nat) (places : Nat → Prop) : Prop :=
  ∀ i kind, L[i]? = some (some kind) → LocalRef.Allowed depth places (ρ i)

theorem LocalCtx.Resolved.empty (ρ) (depth) (places) : LocalCtx.Resolved [] ρ depth places := by
  intro i kind h; cases h

theorem StoreTy.BuilderPlaces.hidden (Ψ : StoreTy) : (hideBuilders Ψ).BuilderPlaces (fun _ => False) := by
  intro l kind hl
  unfold hideBuilders at hl
  cases h : Ψ l with
  | none => simp [h] at hl
  | some x => cases x <;> simp [h] at hl

theorem LocalCtx.Resolved.extend {L ρ depth places} (h : LocalCtx.Resolved L ρ depth places) (x) :
    LocalCtx.Resolved (LocalCtx.extend x L) (upLocalSubst 1 ρ) (depth+1) places := by
  intro i kind hi
  cases i with
  | zero => exact Nat.zero_lt_succ depth
  | succ i =>
    simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
    obtain ⟨ob,hob,he⟩ := Option.map_eq_some_iff.mp hi
    cases ob with
    | none => cases he
    | some b =>
      have hh := h i b hob
      cases hr : ρ i with
      | bound j => simp only [hr,LocalRef.Allowed] at hh; simpa [upLocalSubst,hr,LocalRef.rename,LocalRef.Allowed] using Nat.succ_lt_succ hh
      | loc l => simpa [upLocalSubst,hr,LocalRef.rename,LocalRef.Allowed] using hh

theorem LocalCtx.Resolved.many {L ρ depth places} (h : LocalCtx.Resolved L ρ depth places) (n) :
    LocalCtx.Resolved (localExtend n L) (upLocalSubst n ρ) (depth+n) places := by
  induction n with
  | zero => simpa [localExtend,upLocalSubst_zero] using h
  | succ n ih => simpa only [localExtend,upLocalSubst_add,Nat.add_assoc] using ih.extend none

theorem LocalRef.HasKind.localRefs {Ψ L r kind ρ depth places}
    (h : LocalRef.HasKind Ψ L r kind) (hL : LocalCtx.Resolved L ρ depth places)
    (hΨ : Ψ.BuilderPlaces places) : LocalRef.Allowed depth places (r.subst ρ) := by
  induction h with
  | bound hi => exact hL _ _ hi
  | loc hl => exact hΨ _ _ hl
  | normal _ ih => exact ih

mutual
  theorem HasTypeVQ.localRefs {P B Ψ Q C Γ Φ v a depth places} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
      Val.LocalRefs P B Ψ depth places v := by
    match h with
    | .V_Lam (ps := ps) _ _ _ hb _ =>
      apply Val.LocalRefs.lam
      simpa only [Comp.resolveLocals_id] using HasTypeCQ.localRefs hb
        (LocalCtx.Resolved.empty LocalRef.bound ps.length _) (StoreTy.BuilderPlaces.hidden Ψ)
    | .V_DependentLam _ hb => exact .dependentLam (TelBodyTy.localRefs hb (StoreTy.BuilderPlaces.hidden Ψ))
    | .V_Closure _ _ hb => exact DependentClosureTy.localRefs hb
    | .V_Con _ _ _ _ hs _ => exact .con (HasTypeVsQ.localRefs hs)
    | .V_List hs _ _ _ => exact .list (HasTypeEachQ.localRefs hs)
    | .V_Set hs _ _ => exact .setV (HasTypeEachQ.localRefs hs)
    | .V_Dict _ _ _ _ _ _ hs _ => exact .dict (HasTypeVsQ.localRefs hs)
    | .V_Map hk hv _ _ _ _ => exact .mapV (HasTypeEachQ.localRefs hk) (HasTypeEachQ.localRefs hv)
    | .V_Super hv _ _ _ => exact .super (HasTypeVQ.localRefs hv)
    | .V_CheckedRequest _ _ hv _ _ _ => exact .checkedRequest (HasTypeVQ.localRefs hv)
    | .V_CheckedAt hw => exact .checkedAt (CheckedWitness.localRefs hw)
    | .V_Normal hv | .V_Sub hv .. | .V_Refine hv .. => exact HasTypeVQ.localRefs hv
    | .V_Var .. | .V_Const .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_AtError .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => exact .leaf trivial
  termination_by structural h

  theorem HasTypeVsQ.localRefs {P B Ψ Q C Γ Φ vs as depth places} (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
      Val.LocalRefsList P B Ψ depth places vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (HasTypeVQ.localRefs hv) (HasTypeVsQ.localRefs hs)
  termination_by structural h

  theorem HasTypeEachQ.localRefs {P B Ψ Q C Γ Φ vs a depth places} (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) :
      Val.LocalRefsList P B Ψ depth places vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (HasTypeVQ.localRefs hv) (HasTypeEachQ.localRefs hs)
  termination_by structural h

  theorem HasTypeCQ.localRefs {P B Ψ Q C Γ Φ R m a e L ρ depth places}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
      (hL : LocalCtx.Resolved L ρ depth places) (hΨ : Ψ.BuilderPlaces places) :
      Comp.LocalRefs P B Ψ depth places (m.resolveLocals ρ) := by
    match h with
    | .C_BuilderLet _ _ hb _ => exact .builderLet (HasTypeCQ.localRefs hb (hL.extend _) hΨ)
    | .C_BuilderOp _ _ hr hs =>
      simp only [Comp.resolveLocals,HasTypeVsQ.resolve_id hs]
      exact .builderOp (hr.localRefs hL hΨ) (HasTypeVsQ.localRefs hs)
    | .C_Return hv => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]; exact .ret (HasTypeVQ.localRefs hv)
    | .C_Escape hv _ => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]; exact .escape (HasTypeVQ.localRefs hv)
    | .C_Let hm hn _ => exact .letIn (HasTypeCQ.localRefs hm hL hΨ) (HasTypeCQ.localRefs hn (hL.many 1) hΨ)
    | .C_App hf hs =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hf,HasTypeVsQ.resolve_id hs]
      exact .app (HasTypeVQ.localRefs hf) (HasTypeVsQ.localRefs hs)
    | .C_DependentApp hf hs =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hf,HasTypeTelArgsQ.resolve_id hs]
      exact .app (HasTypeVQ.localRefs hf) (HasTypeTelArgsQ.localRefs hs)
    | .C_If hv _ hm hn =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
      exact .ite (HasTypeVQ.localRefs hv) (HasTypeCQ.localRefs hm hL hΨ) (HasTypeCQ.localRefs hn hL hΨ)
    | .C_Match hv _ ha _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
      exact .matchC (HasTypeVQ.localRefs hv) (HasTypeArmsQ.localRefs ha hL hΨ)
    | .C_Lazy hm _ =>
      simp only [Comp.resolveLocals]
      rw [HasTypeCQ.resolve_id hm ρ (LocalsFixed.empty _)]
      apply Comp.LocalRefs.lazyC
      simpa only [Comp.resolveLocals_id] using HasTypeCQ.localRefs hm
        (LocalCtx.Resolved.empty LocalRef.bound 0 _) (StoreTy.BuilderPlaces.hidden Ψ)
    | .C_Use hv _ hm _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
      exact .use (HasTypeVQ.localRefs hv) (HasTypeCQ.localRefs hm hL hΨ)
    | .C_Handle hm _ hc =>
      simp only [Comp.resolveLocals,HasTypeClausesQ.resolve_id hc]
      exact .handle (HasTypeCQ.localRefs hm hL hΨ) (HasTypeClausesQ.localRefs hc)
    | .C_Handle_Fail hm _ _ hc =>
      simp only [Comp.resolveLocals,HasFailureClause.resolve_id hc]
      exact .handle (HasTypeCQ.localRefs hm hL hΨ) (HasFailureClause.localRefs hc)
    | .C_Resume _ hv _ | .C_ResumeL _ hv _ | .C_ResumeNorm _ hv _ | .C_ResumeLNorm _ _ hv _ =>
      simp only [Comp.resolveLocals,Val.resolveLocals,HasTypeVQ.resolve_id hv]
      exact .resume (.leaf trivial) (HasTypeVQ.localRefs hv)
    | .C_Meth hv _ _ _ _ _ _ _ hs _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeVsQ.resolve_id hs]
      exact .meth (HasTypeVQ.localRefs hv) (HasTypeVsQ.localRefs hs)
    | .C_External _ _ _ hs =>
      simp only [Comp.resolveLocals,HasTypeTelArgsQ.resolve_id hs]
      exact .externalCall (HasTypeTelArgsQ.localRefs hs)
    | .C_IssuePathBases .. => exact .issuePathBases
    | .C_CheckAt ha =>
      obtain ⟨h1,h2,h3⟩ := AtCallAdmissible.resolve_id (ρ := ρ) ha
      have hh := AtCallAdmissible.localRefs (depth := depth) (places := places) ha
      rename_i bs _ _ _
      cases bs with
      | none => simpa only [Comp.resolveLocals,h2,h3] using hh
      | some v => simpa only [Comp.resolveLocals,h1 v rfl,h2,h3] using hh
    | .C_Sub hm .. | .C_Normal hm | .C_Eff hm _ => exact HasTypeCQ.localRefs hm hL hΨ
  termination_by structural h

  theorem HasTypeTelArgsQ.localRefs {P B Ψ Q C Γ Φ vs t a e depth places}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) : Val.LocalRefsList P B Ψ depth places vs := by
    match h with
    | .done _ => exact .nil
    | .param _ hv hs => exact .cons (HasTypeVQ.localRefs hv) (HasTypeTelArgsQ.localRefs hs)
  termination_by structural h

  theorem TelBodyTy.localRefs {P B Ψ Q C Γ Φ t body depth places}
      (h : TelBodyTy P B Ψ Q C Γ Φ t body) (hΨ : Ψ.BuilderPlaces places) :
      Comp.LocalRefs P B Ψ depth places body := by
    match h with
    | .done hb =>
      simpa only [Comp.resolveLocals_id] using HasTypeCQ.localRefs hb
        (LocalCtx.Resolved.empty LocalRef.bound depth places) hΨ
    | .param hb => exact TelBodyTy.localRefs hb hΨ
  termination_by structural h

  theorem DependentClosureTy.localRefs {P B Ψ q t runtime depth places}
      (h : DependentClosureTy P B Ψ q t) : Val.LocalRefs P B Ψ depth places (.closure runtime q) := by
    match h with
    | .mk hc hb _ _ =>
      exact .closure hc hb (CaptureOk.localRefs hc)
        (TelBodyTy.localRefs hb (StoreTy.BuilderPlaces.hidden Ψ))
  termination_by structural h

  theorem CaptureOk.localRefs {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
      Capture.LocalRefs P B Ψ Γ Φ cap := by
    have ht := h.transport
    match h with
    | .mk _ _ _ _ _ _ hi _ => exact .mk ht (fun i a ha ho => ImageOk.localRefs (hi i a ha) ho)
  termination_by structural h

  theorem ImageOk.localRefs {P B Ψ Q C Γ Φ R ν i a} (h : ImageOk P B Ψ Q C Γ Φ R ν i a)
      (ho : a.Ordinary) : Val.LocalRefs P B Ψ 0 (fun _ => False) (ν i) := by
    match h with
    | .ordinary _ hv => exact HasTypeVQ.localRefs hv
    | .hidden hn _ => exact False.elim (hn ho)
    | .contLoc he _ _ _ _ _ | .contVar he _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))
  termination_by structural h

  theorem CheckedWitness.localRefs {P B Ψ o k range snapshot target req}
      (h : CheckedWitness P B Ψ o k range snapshot target req) :
      ∀ v, req = some v → Val.LocalRefs P B Ψ 0 (fun _ => False) v := by
    match h with
    | .plain .. => intro v hv; cases hv
    | .request _ _ hv _ _ _ => intro v he; cases he; exact HasTypeVQ.localRefs hv
  termination_by structural h

  theorem AtCallAdmissible.localRefs {P B Ψ Q C Γ Φ kind name shape bases pattern input index depth places}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      Comp.LocalRefs P B Ψ depth places (.checkAt kind name shape bases pattern input index) := by
    match h with
    | .mk _ _ hb hp _ hi _ _ =>
      exact .checkAt (fun v hv => HasTypeVQ.localRefs (hb v hv)) (HasTypeVQ.localRefs hp) (HasTypeVQ.localRefs hi)
  termination_by structural h

  theorem HasTypeArmsQ.localRefs {P B Ψ Q C Γ Φ R obs arms a b e L ρ depth places}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L)
      (hL : LocalCtx.Resolved L ρ depth places) (hΨ : Ψ.BuilderPlaces places) :
      Arm.LocalRefsList P B Ψ depth places (Arm.resolveLocalsList ρ arms) := by
    match h with
    | .nil _ => exact .nil
    | .plain hp _ hb hs =>
      apply Arm.LocalRefsList.plain
      · simpa only [hp.2.1] using HasTypeCQ.localRefs hb (hL.many _) hΨ
      · exact HasTypeArmsQ.localRefs hs hL hΨ
    | .guarded hp _ _ hg hb hs =>
      apply Arm.LocalRefsList.guarded
      · simpa only [hp.2.1] using HasTypeCQ.localRefs hg (hL.many _) hΨ
      · simpa only [hp.2.1] using HasTypeCQ.localRefs hb (hL.many _) hΨ
      · exact HasTypeArmsQ.localRefs hs hL hΨ
  termination_by structural h

  theorem HasTypeClausesQ.localRefs {P B Ψ Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) : Clause.LocalRefsList P B Ψ cs := by
    match h with
    | .nil => exact .nil
    | .cons _ _ _ _ _ hb hs =>
      have hl := HasTypeCQ.localRefs hb (LocalCtx.Resolved.empty LocalRef.bound 0 _)
        (StoreTy.BuilderPlaces.hidden Ψ)
      exact .cons (by simpa only [Comp.resolveLocals_id] using hl) (HasTypeClausesQ.localRefs hs)
  termination_by structural h

  theorem HasFailureClause.localRefs {P B Ψ Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) : Clause.LocalRefsList P B Ψ cs := by
    match h with
    | .one _ _ _ hb =>
      have hl := HasTypeCQ.localRefs hb (LocalCtx.Resolved.empty LocalRef.bound 0 _)
        (StoreTy.BuilderPlaces.hidden Ψ)
      exact .fail (by simpa only [Comp.resolveLocals_id] using hl)
  termination_by structural h
end

end
end Benitoite.Release.Refinement
