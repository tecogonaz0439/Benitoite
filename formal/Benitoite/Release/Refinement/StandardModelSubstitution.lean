import Benitoite.Release.Refinement.StandardModelIORows

/-! # 合成表の制約と許容の八つの保存則

合成表の制約の判定は、合成プログラムの宣言の要約を読む制約の骨格（`ModelConstraints.sat`）である。
組込みの許容は、List.sortの行を除き、型パラメータの制約の列による同じ骨格の判定
（`ModelConstraints.admits`）と同値である。List.sortの行は、一つの型引数が順序を持つ基本型である
ことを追加で検査し、その条件は型・値の改名・置換で保たれる。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 合成表の制約の判定が読む宣言の要約。 -/
def summaries : Benitoite.Release.SummaryTable :=
  Benitoite.Release.dataSummaries (declarations.map StandardKeyTyping.DataDecl.summaryInput)

/-- 許容が、型パラメータの制約の列による、要約の表 S の制約の骨格の判定と同値であること。 -/
def AdmitsSatWith (S : Benitoite.Release.SummaryTable) (s : PrimSig) : Prop :=
  ∀ C ts, s.admits C ts ↔ ModelConstraints.admits S (s.tparams.map TParamDecl.constraints) C ts

/-- 許容が、型パラメータの制約の列による制約の骨格の判定と同値であること。 -/
abbrev AdmitsSat (s : PrimSig) : Prop := AdmitsSatWith summaries s

private theorem closed_admits {S : Benitoite.Release.SummaryTable} (s : PrimSig) (ht : s.tparams = [])
    (ha : ∀ C ts, s.admits C ts ↔ ts = []) : AdmitsSatWith S s := by
  intro C ts
  rw [ha, ht]
  simp [ModelConstraints.admits, List.length_eq_zero_iff]

private theorem single_admits {S : Benitoite.Release.SummaryTable} (s : PrimSig) (ht : s.tparams = [TypeCtx.valueParam])
    (ha : ∀ C ts, s.admits C ts ↔ ts.length = 1) : AdmitsSatWith S s := by
  intro C ts
  rw [ha, ht]
  simp only [ModelConstraints.admits, List.map_cons, List.map_nil, List.length_cons, List.length_nil]
  constructor
  · intro h
    refine ⟨h, ?_⟩
    intro i a p _ hp
    cases i with
    | zero => cases Option.some.inj hp; exact ModelConstraints.sat_unconstrained _ _ _
    | succ i => simp at hp
  · exact And.left

private theorem exact_admits {S : Benitoite.Release.SummaryTable} (s : PrimSig)
    (ha : ∀ C ts, s.admits C ts ↔ ts.length = s.tparams.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]? = some t → (s.tparams.map TParamDecl.constraints)[i]? = some p → ModelConstraints.sat S C t p) :
    AdmitsSatWith S s := by
  intro C ts
  rw [ha]
  simp only [ModelConstraints.admits, List.length_map]

private theorem list_remaining_admits {S : Benitoite.Release.SummaryTable} (api : StandardListRemainingResponse.API)
    (sort : api ≠ .sort) : AdmitsSatWith S (StandardListRemainingResponse.API.signature (ModelConstraints.sat S) api) := by
  intro C ts
  cases api
  case sort => exact absurd rfl sort
  case contains =>
    simp only [StandardListRemainingResponse.API.signature, StandardListRemainingResponse.API.constraint,
      ModelConstraints.admits, List.map_cons, List.map_nil, List.length_cons, List.length_nil]
    constructor
    · rintro ⟨h, hc, _⟩
      exact ⟨h, hc trivial⟩
    · rintro ⟨h, hc⟩
      refine ⟨h, ?_, ?_⟩
      all_goals first | exact hc | exact fun _ => hc | (intro hs; cases hs) | trivial
  all_goals
    simp only [StandardListRemainingResponse.API.signature, StandardListRemainingResponse.API.constraint,
      ModelConstraints.admits, List.map_cons, List.map_nil, List.length_cons, List.length_nil]
    constructor
    · rintro ⟨h, contains, _⟩
      refine ⟨h, ?_⟩
      intro i a p ha hp
      first
        | exact contains i a p ha hp
        | exact contains rfl i a p ha hp
        | (cases i with
           | zero => cases Option.some.inj hp; exact ModelConstraints.sat_unconstrained _ _ _
           | succ i => simp at hp)
    · rintro ⟨h, all⟩
      refine ⟨h, ?_, ?_⟩
      all_goals first
        | (intro i a p ha hp; exact all i a p ha hp)
        | (intro _ i a p ha hp; exact all i a p ha hp)
        | (intro hs; cases hs)
        | trivial

/-- 要約の表 S の制約で作った署名の、List.sort以外の全行の許容は、S の制約の骨格の判定と同値である。 -/
theorem admits_formWith (S : Benitoite.Release.SummaryTable) (row : Primitive) :
    AdmitsSatWith S (row.signatureWith (ModelConstraints.sat S)) ∨ row = .p266 := by
  cases row
  case p266 => exact Or.inr rfl
  case p257 => exact Or.inl (list_remaining_admits .contains (by decide))
  case p258 => exact Or.inl (list_remaining_admits .drop (by decide))
  case p259 => exact Or.inl (list_remaining_admits .get (by decide))
  case p268 => exact Or.inl (list_remaining_admits .take (by decide))
  all_goals first
    | exact Or.inl (closed_admits _ rfl (fun _ _ => Iff.rfl))
    | exact Or.inl (single_admits _ rfl (fun _ _ => Iff.rfl))
    | exact Or.inl (exact_admits _ (fun _ _ => Iff.rfl))

/-- 合成表のList.sort以外の全行の許容は、制約の骨格の判定と同値である。 -/
theorem admits_form (row : Primitive) : AdmitsSat row.signature ∨ row = .p266 := by
  have h := admits_formWith summaries row
  have he : row.signatureWith (ModelConstraints.sat summaries) = row.signature := Primitive.signatureWith_base row
  rwa [he] at h

/-! ## List.sortの行の順序の検査 -/

private theorem scalar_core : (a : Ty) → StandardScalar.scalarTypeCore a = StandardScalar.scalarTypeCore a.core
  | .refined a _ => by rw [StandardScalar.scalarTypeCore, Ty.core]; exact scalar_core a
  | .base _ | .opaque _ _ | .data _ _ | .list _ | .fn _ _ _ _ | .tvar _ | .reference _ | .lazy _
  | .cont _ _ _ | .map _ _ | .set _ | .bytes | .dict _ _ | .tapp _ _ | .ctor _ | .dependentFn _
  | .external _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ => rfl

private theorem core_rawBind (θ : SubstEnv) (b : BaseTy) : (a : Ty) → a.core = .base b →
    (a.rawBind θ).core = .base b
  | .refined a _, h => by rw [Ty.rawBind, Ty.core]; exact core_rawBind θ b a h
  | .base _, h => h
  | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h
  | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h | .ctor _, h
  | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h | .scopePattern _, h => by
    cases h

private theorem core_rawRenameTypes (ρ : Nat → Nat) (b : BaseTy) : (a : Ty) → a.core = .base b →
    (a.rawRenameTypes ρ).core = .base b
  | .refined a _, h => by rw [Ty.rawRenameTypes, Ty.core]; exact core_rawRenameTypes ρ b a h
  | .base _, h => h
  | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h
  | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h | .ctor _, h
  | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h | .scopePattern _, h => by
    cases h

private theorem ordered_base : (a : Ty) → StandardListRemainingResponse.orderedType a → ∃ b, a.core = .base b
  | .refined a _, h => ordered_base a h
  | .base b, _ => ⟨b, rfl⟩
  | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h
  | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h | .ctor _, h
  | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h | .scopePattern _, h => by
    simp [StandardListRemainingResponse.orderedType, StandardScalar.scalarTypeCore] at h

private theorem ordered_of_core {a b : Ty} (same : a.core = b.core) (h : StandardListRemainingResponse.orderedType b) :
    StandardListRemainingResponse.orderedType a := by
  unfold StandardListRemainingResponse.orderedType at h ⊢
  rw [scalar_core] at h ⊢
  rwa [same]

private theorem ordered_rawBind (θ : SubstEnv) {a : Ty} (h : StandardListRemainingResponse.orderedType a) :
    StandardListRemainingResponse.orderedType (a.rawBind θ) := by
  obtain ⟨b, hb⟩ := ordered_base a h
  exact ordered_of_core ((core_rawBind θ b a hb).trans hb.symm) h

private theorem ordered_bind (θ : SubstEnv) {a : Ty} (h : StandardListRemainingResponse.orderedType a) :
    StandardListRemainingResponse.orderedType (a.bind θ) := by
  obtain ⟨b, hb⟩ := ordered_base a h
  exact ordered_of_core (by rw [Ty.bind, Ty.core_norm, core_rawBind θ b a hb, hb]; rfl) h

private theorem ordered_renameTypes (ρ : Nat → Nat) {a : Ty} (h : StandardListRemainingResponse.orderedType a) :
    StandardListRemainingResponse.orderedType (a.renameTypes ρ) := by
  obtain ⟨b, hb⟩ := ordered_base a h
  exact ordered_of_core (by rw [Ty.renameTypes, Ty.core_norm, core_rawRenameTypes ρ b a hb, hb]; rfl) h

private theorem sort_admits {S : Benitoite.Release.SummaryTable} {C ts} :
    (Primitive.p266.signatureWith (ModelConstraints.sat S)).admits C ts ↔
      ts.length = 1 ∧ ∀ t ∈ ts, StandardListRemainingResponse.orderedType t := by
  show (ts.length = 1 ∧ _ ∧ _) ↔ _
  simp [ModelConstraints.sat, Benitoite.Release.satB]

private theorem sort_map {S : Benitoite.Release.SummaryTable} {C D ts} (f : Ty → Ty)
    (preserve : ∀ a, StandardListRemainingResponse.orderedType a → StandardListRemainingResponse.orderedType (f a))
    (h : (Primitive.p266.signatureWith (ModelConstraints.sat S)).admits C ts) :
    (Primitive.p266.signatureWith (ModelConstraints.sat S)).admits D (ts.map f) := by
  rw [sort_admits] at h ⊢
  refine ⟨by simpa using h.1, ?_⟩
  intro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact preserve a (h.2 a ha)

private theorem admits_map {S : Benitoite.Release.SummaryTable} {s : PrimSig} {C D ts} (f : Ty → Ty)
    (form : AdmitsSatWith S s)
    (preserve : ∀ a p, ModelConstraints.sat S C a p → ModelConstraints.sat S D (f a) p)
    (h : s.admits C ts) : s.admits D (ts.map f) :=
  (form D _).mpr (ModelConstraints.admits_map preserve ((form C ts).mp h))

/-- 合成表の制約と全行の許容は、値の改名・値の置換・型パラメータの改名・閉じた型の具体化で保たれる。 -/
theorem substitution_assumptions (P : Program) : (builtins P).SubstitutionAssumptions P where
  sat_rename := by
    intro C Γ Δ a p ξ _ _ _ h
    exact (ModelConstraints.sat_rename _ _ a p ξ).mpr h
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs _ _ _ h
    obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b sg).mp hs
    rcases admits_form row with form | rfl
    · exact admits_map _ form (fun a p ha => (ModelConstraints.sat_rename _ _ a p ξ).mpr ha) h
    · exact sort_map _ (fun a ha => ordered_rawBind _ ha) h
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ h
    obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b sg).mp hs
    rcases admits_form row with form | rfl
    · exact admits_map _ form (fun a p ha => (ModelConstraints.sat_values _ _ a p ν).mpr ha) h
    · exact sort_map _ (fun a ha => ordered_bind _ ha) h
  sat_renameTypes := by
    intro C D Γ Δ a p ρ ren _ _ h
    exact ModelConstraints.sat_renameTypes ren h
  admits_renameTypes := by
    intro b sg C D Γ Δ ts ρ hs ren _ _ h
    obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b sg).mp hs
    rcases admits_form row with form | rfl
    · exact (form _ _).mpr (ModelConstraints.admits_renameTypes ren ((form _ ts).mp h))
    · exact sort_map _ (fun a ha => ordered_renameTypes _ ha) h
  sat_subst := by
    intro C0 C1 a p ts es h wf images count
    exact ModelConstraints.sat_subst h wf images count
  admits_subst := by
    intro b sg C0 C1 ts ts' es' hs h wf images count
    obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b sg).mp hs
    rcases admits_form row with form | rfl
    · exact (form _ _).mpr (ModelConstraints.admits_subst ((form _ ts).mp h) wf images count)
    · exact sort_map _ (fun a ha => ordered_bind _ ha) h

/-- 組込みの許容は、同じ型引数列の制約と個数も満たす。 -/
theorem admits_sat (P : Program) :
    ∀ b s C ts, (builtins P).sig b = some s → s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
      SatAll (builtins P) C ts (s.tparams.map TParamDecl.constraints) := by
  intro b s C ts hs h
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp hs
  rcases admits_form row with form | rfl
  · obtain ⟨count, all⟩ := (form _ _).mp h
    refine ⟨by simpa [Ty.normTys_eq_map] using count, ?_⟩
    intro i t p ht hp
    have := all i t.norm p (by simp [Ty.normTys_eq_map, ht]) hp
    exact this
  · replace h := (sort_admits (S := summaries)).mp h
    have count := h.1
    rw [Ty.normTys_eq_map, List.length_map] at count
    have params : Primitive.p266.signature.tparams.map TParamDecl.constraints = [{}] := rfl
    refine ⟨by rw [params]; exact count, ?_⟩
    intro i t p _ hp
    rw [params] at hp
    cases i with
    | zero => cases Option.some.inj hp; exact ModelConstraints.sat_unconstrained _ _ _
    | succ i => simp at hp

/-! ## 要約の表 S の制約で作った署名の許容の保存則

利用者のプログラムの宣言の一覧で制約を作った表の合成済みの名前の行について、置換の八欄のうち許容の四欄と
`admits_sat` を述べる。 -/

theorem admits_rename_with (S : Benitoite.Release.SummaryTable) (row : Primitive) {C ts} (ξ : Nat → Nat)
    (h : (row.signatureWith (ModelConstraints.sat S)).admits C ts) :
    (row.signatureWith (ModelConstraints.sat S)).admits C (ts.map (renameTy ξ)) := by
  rcases admits_formWith S row with form | rfl
  · exact admits_map _ form (fun a p ha => (ModelConstraints.sat_rename _ _ a p ξ).mpr ha) h
  · exact sort_map _ (fun a ha => ordered_rawBind _ ha) h

theorem admits_values_with (S : Benitoite.Release.SummaryTable) (row : Primitive) {C ts} (ν : Nat → Val)
    (h : (row.signatureWith (ModelConstraints.sat S)).admits C ts) :
    (row.signatureWith (ModelConstraints.sat S)).admits C (ts.map (substTyValues ν)) := by
  rcases admits_formWith S row with form | rfl
  · exact admits_map _ form (fun a p ha => (ModelConstraints.sat_values _ _ a p ν).mpr ha) h
  · exact sort_map _ (fun a ha => ordered_bind _ ha) h

theorem admits_renameTypes_with (S : Benitoite.Release.SummaryTable) (row : Primitive) {C C' ts ρ}
    (ren : TypeParamRenaming C C' ρ)
    (h : (row.signatureWith (ModelConstraints.sat S)).admits (TypeCtx.constraints C) ts) :
    (row.signatureWith (ModelConstraints.sat S)).admits (TypeCtx.constraints C')
      (ts.map (fun a => a.renameTypes ρ)) := by
  rcases admits_formWith S row with form | rfl
  · exact (form _ _).mpr (ModelConstraints.admits_renameTypes ren ((form _ ts).mp h))
  · exact sort_map _ (fun a ha => ordered_renameTypes _ ha) h

theorem admits_subst_with (S : Benitoite.Release.SummaryTable) (row : Primitive) {B : Builtins}
    (hs : B.sat = ModelConstraints.sat S) {C0 C1 ts ts' es'}
    (h : (row.signatureWith (ModelConstraints.sat S)).admits (TypeCtx.constraints (C1 ++ C0)) ts)
    (wf : ∀ t ∈ ts', t.WF 0 0 0) (images : SatAll B C1 ts' (TypeCtx.constraints C0))
    (count : ts'.length = C0.length) :
    (row.signatureWith (ModelConstraints.sat S)).admits (TypeCtx.constraints C1)
      (ts.map (Ty.substAt C1.length ts' es')) := by
  rcases admits_formWith S row with form | rfl
  · rw [SatAll, hs] at images
    exact (form _ _).mpr (ModelConstraints.admits_subst ((form _ ts).mp h) wf images count)
  · exact sort_map _ (fun a ha => ordered_bind _ ha) h

theorem admits_sat_with (S : Benitoite.Release.SummaryTable) (row : Primitive) {B : Builtins}
    (hs : B.sat = ModelConstraints.sat S) {C ts}
    (h : (row.signatureWith (ModelConstraints.sat S)).admits (TypeCtx.constraints C) (Ty.normTys ts)) :
    SatAll B C ts ((row.signatureWith (ModelConstraints.sat S)).tparams.map TParamDecl.constraints) := by
  rcases admits_formWith S row with form | rfl
  · obtain ⟨count, all⟩ := (form _ _).mp h
    refine ⟨by simpa [Ty.normTys_eq_map] using count, ?_⟩
    intro i t p ht hp
    rw [hs]
    exact all i t.norm p (by simp [Ty.normTys_eq_map, ht]) hp
  · replace h := (sort_admits (S := S)).mp h
    have count := h.1
    rw [Ty.normTys_eq_map, List.length_map] at count
    have params : (Primitive.p266.signatureWith (ModelConstraints.sat S)).tparams.map TParamDecl.constraints =
        [{}] := rfl
    refine ⟨by rw [params]; exact count, ?_⟩
    intro i t p _ hp
    rw [params] at hp
    rw [hs]
    cases i with
    | zero => cases Option.some.inj hp; exact ModelConstraints.sat_unconstrained _ _ _
    | succ i => simp at hp

end
end Benitoite.Release.Refinement.StandardModel
