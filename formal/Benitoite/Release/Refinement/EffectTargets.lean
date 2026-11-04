import Benitoite.Release.Refinement.ShapeTargets
import Benitoite.Release.Refinement.EffectFacts
import Benitoite.Release.Refinement.TypeSubstAux

/-! # 同じ実行環境での効果の許容と応答の観測 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

/-- 固定範囲の原子を覆うのは、同じ名前の固定範囲の原子だけである。 -/
theorem Atom.covers_fixed_iff {a : Atom} {l : EffName} {r : RangeExpr} :
    a.Covers (.name l (.fixed r)) ↔
    ∃ s, a = .name l (.fixed s) ∧ s.Covers r := by
  rcases a with ⟨m, s | i⟩ | i <;> simp only [Atom.Covers]
  · constructor
    · rintro ⟨rfl, hc⟩; exact ⟨s, rfl, hc⟩
    · rintro ⟨s', he, hc⟩; cases he; exact ⟨rfl, hc⟩
  · simp
  · simp

theorem Eff.allows_of_mem {σ κ e l k r t} (hk : κ l = some k)
    (hm : e.mem (.name l (.fixed r))) (ht : r.Mem σ k t) :
    Eff.Allows σ κ e l t := ⟨k, r, hk, hm, ht⟩

theorem Eff.Allows.kind {σ κ e l t} (h : Eff.Allows σ κ e l t) :
    κ l = some t.kind := by
  obtain ⟨k, r, hk, _, ht⟩ := h
  rw [hk, ht.1]

theorem Eff.not_allows_of_kind_none {σ κ e l t} (hk : κ l = none) :
    ¬ Eff.Allows σ κ e l t := by
  intro h
  rw [h.kind] at hk
  cases hk

theorem Eff.allows_of_nameTop {σ κ e l t} (hm : e.mem (.nameTop l))
    (hk : κ l = some t.kind) : Eff.Allows σ κ e l t :=
  Eff.allows_of_mem hk hm ⟨rfl, .top, by simp, trivial⟩

theorem Eff.allows_single_iff {σ κ l m t} :
    Eff.Allows σ κ (Eff.single l) m t ↔ m = l ∧ κ l = some t.kind := by
  constructor
  · rintro h
    have hk := h.kind
    obtain ⟨k, r, _, hm, _⟩ := h
    have he : Atom.name m (.fixed r) = .nameTop l := of_decide_eq_true hm
    cases he
    exact ⟨rfl, hk⟩
  · rintro ⟨rfl, hk⟩
    exact Eff.allows_of_nameTop (by simp [Eff.single, Eff.mem, Eff.test, Eff.atoms]) hk

theorem Eff.Allows.mono {σ κ e f l t} (h : Eff.Allows σ κ e l t)
    (hs : Eff.Sub e f) : Eff.Allows σ κ f l t := by
  obtain ⟨k, r, hk, hm, ht⟩ := h
  exact Eff.allows_of_mem hk (hs.1 _ hm) ht

theorem Eff.allows_union {σ κ e f l t} :
    Eff.Allows σ κ (e.union f) l t ↔ Eff.Allows σ κ e l t ∨ Eff.Allows σ κ f l t := by
  simp only [Eff.Allows, Eff.mem_union_iff]
  constructor
  · rintro ⟨k, r, hk, hm | hm, ht⟩
    · exact .inl ⟨k, r, hk, hm, ht⟩
    · exact .inr ⟨k, r, hk, hm, ht⟩
  · rintro (⟨k, r, hk, hm, ht⟩ | ⟨k, r, hk, hm, ht⟩)
    · exact ⟨k, r, hk, .inl hm, ht⟩
    · exact ⟨k, r, hk, .inr hm, ht⟩

theorem Eff.not_allows_empty {σ κ l t} : ¬ Eff.Allows σ κ Eff.empty l t := by
  rintro ⟨_, _, _, hm, _⟩
  cases hm

theorem Eff.not_allows_row {σ κ i l t} : ¬ Eff.Allows σ κ (Eff.row i) l t := by
  rintro ⟨_, _, _, hm, _⟩
  cases hm

/-- 被覆は同じ実行環境で同じ名前の対象の許容を保つ。 -/
theorem Eff.Covers.allows {Γ Φ e f σ κ l t} (h : Eff.Covers Γ Φ e f)
    (ha : Eff.Allows σ κ f l t) : Eff.Allows σ κ e l t := by
  obtain ⟨k, r, hk, hm, ht⟩ := ha
  obtain ⟨b, hb, hc⟩ := h.1 _ hm
  obtain ⟨s, rfl, hs⟩ := Atom.covers_fixed_iff.mp hc
  exact Eff.allows_of_mem hk hb (hs.mem σ ht)

theorem Eff.allows_of_mem_covers {σ κ e l ix r k t} (hk : κ l = some k)
    (hm : e.mem (.name l ix)) (hc : (Atom.name l ix).Covers (.name l (.fixed r)))
    (ht : r.Mem σ k t) : Eff.Allows σ κ e l t := by
  obtain ⟨s, he, hs⟩ := Atom.covers_fixed_iff.mp hc
  cases he
  exact Eff.allows_of_mem hk hm (hs.mem σ ht)

/-- 元の名前の原子の範囲を具体化し、行の像は同じ像のまま読む。Fail は許容を与えない。 -/
theorem Eff.allows_bind (θ : SubstEnv) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (Eff.bind θ e) l t ↔
      (∃ k ix r, κ l = some k ∧ e.mem (.name l ix) ∧
        ix.inst θ.ranges = .fixed r ∧ r.Mem σ k t) ∨
      ∃ i f, θ.rows[i]? = some f ∧ e.mem (.rho i) ∧ Eff.Allows σ κ f l t := by
  simp only [Eff.bind, Eff.Allows, Eff.mem_norm]
  constructor
  · rintro ⟨k, r, hk, hm, ht⟩
    rcases (Eff.mem_rawBind θ e _).mp hm with ⟨b, hb, he, _⟩ | ⟨i, f, hf, hi, hm⟩
    · cases b with
      | rho i => cases he
      | name m ix =>
        change Atom.name m (ix.inst θ.ranges) = .name l (.fixed r) at he
        simp only [Atom.name.injEq] at he
        obtain ⟨hl, hi⟩ := he
        subst m
        exact .inl ⟨k, ix, r, hk, hb, hi, ht⟩
    · exact .inr ⟨i, f, hf, hi, k, r, hk, hm, ht⟩
  · rintro (⟨k, ix, r, hk, hm, hi, ht⟩ | ⟨i, f, hf, hi, k, r, hk, hm, ht⟩)
    · exact ⟨k, r, hk, (Eff.mem_rawBind θ e _).mpr
        (.inl ⟨.name l ix, hm, congrArg (Atom.name l) hi, trivial⟩), ht⟩
    · exact ⟨k, r, hk, (Eff.mem_rawBind θ e _).mpr (.inr ⟨i, f, hf, hi, hm⟩), ht⟩

/-- 行像がないときも、元の範囲変数の具体化を保持する。 -/
theorem Eff.allows_bind_of_rows_nil {θ : SubstEnv} (hr : θ.rows = []) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (Eff.bind θ e) l t ↔
      ∃ k ix r, κ l = some k ∧ e.mem (.name l ix) ∧
        ix.inst θ.ranges = .fixed r ∧ r.Mem σ k t := by
  rw [Eff.allows_bind]
  simp [hr]

/-- 範囲像も行像もない置換は、対象の許容を変えない。 -/
theorem Eff.allows_bind_of_rows_ranges_nil {θ : SubstEnv} (hr : θ.rows = [])
    (hg : θ.ranges = []) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (Eff.bind θ e) l t ↔ Eff.Allows σ κ e l t := by
  rw [Eff.allows_bind_of_rows_nil hr]
  simp only [hg, RangeIx.inst_nil]
  constructor
  · rintro ⟨k, ix, r, hk, hm, rfl, ht⟩; exact ⟨k, r, hk, hm, ht⟩
  · rintro ⟨k, r, hk, hm, ht⟩; exact ⟨k, .fixed r, r, hk, hm, rfl, ht⟩

theorem Eff.allows_substAt_nil (c : Nat) (ts : List Ty) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (e.substAt c ts []) l t ↔ Eff.Allows σ κ e l t :=
  Eff.allows_bind_of_rows_ranges_nil (θ := typeEnvAt c ts []) rfl rfl e

example {σ κ l t} (hk : κ l = some t.kind) :
    Eff.Allows σ κ (Eff.single l) l t ∧
    ¬ Eff.Allows σ κ Eff.empty l t :=
  ⟨Eff.allows_single_iff.mpr ⟨rfl, hk⟩, Eff.not_allows_empty⟩

example {σ κ e f l t} (h : Eff.Allows σ κ e.norm l t) (hs : Eff.Sub e f) :
    Eff.Allows σ κ f l t := (Eff.allows_norm.mp h).mono hs

example {σ κ e l t} :
    Eff.Allows σ κ (e.union Eff.empty) l t ↔ Eff.Allows σ κ e l t := by
  rw [Eff.allows_union]
  exact or_iff_left Eff.not_allows_empty

example {σ κ l t} (hk : κ l = none) (e : Eff) :
    ¬ Eff.Allows σ κ e.norm l t := Eff.not_allows_of_kind_none hk

example {σ κ i l t} : ¬ Eff.Allows σ κ ((Eff.row i).union Eff.empty) l t := by
  rw [Eff.allows_union]
  exact fun h => h.elim Eff.not_allows_row Eff.not_allows_empty

example (θ : SubstEnv) (T : Ty) {σ κ l t} :
    ¬ Eff.Allows σ κ (Eff.bind θ (.mk (fun _ => false) [T, T])) l t := by
  rw [Eff.allows_bind]
  simp [Eff.mem, Eff.test, Eff.atoms]

example (f : Eff) (rs : List RangeExpr) (types : Nat → Ty) (values : ObservationEnv)
    {σ κ l t} : Eff.Allows σ κ (Eff.bind ⟨types, [f], rs, values⟩ (Eff.row 0)) l t ↔
    Eff.Allows σ κ f l t := by
  rw [Eff.allows_bind]
  simp only [Eff.row, Eff.mem, Eff.test, Eff.atoms, Bool.false_eq_true, false_and,
    and_false, exists_false, false_or, decide_eq_true_eq]
  constructor
  · rintro ⟨i, g, hg, rfl, ha⟩
    have he : f = g := Option.some.inj hg
    cases he
    exact ha
  · intro ha; exact ⟨0, f, rfl, rfl, ha⟩

example (rs : List RangeExpr) (types : Nat → Ty) (values : ObservationEnv)
    (i : Nat) {r : RangeExpr} (hi : rs[i]? = some r) {σ κ l k t}
    (hk : κ l = some k) (hm : r.Mem σ k t) :
    Eff.Allows σ κ (Eff.bind ⟨types, [], rs, values⟩
      (.mk (fun a => decide (a = .name l (.rvar i))) [])) l t := by
  apply (Eff.allows_bind_of_rows_nil rfl _).mpr
  exact ⟨k, .rvar i, r, hk, by simp [Eff.mem, Eff.test, Eff.atoms],
    by simp [RangeIx.inst, hi], hm⟩

example (rs : List RangeExpr) (types : Nat → Ty) (values : ObservationEnv)
    (i : Nat) (hi : rs[i]? = none) {σ κ l t} :
    ¬ Eff.Allows σ κ (Eff.bind ⟨types, [], rs, values⟩
      (.mk (fun a => decide (a = .name l (.rvar i))) [])) l t := by
  rw [Eff.allows_bind_of_rows_nil rfl]
  simp [Eff.mem, Eff.test, Eff.atoms, RangeIx.inst, hi]

example (c : Nat) (ts : List Ty) {σ κ e l t}
    (ha : Eff.Allows σ κ e l t) : Eff.Allows σ κ (e.substAt c ts []) l t :=
  (Eff.allows_substAt_nil c ts e).mpr ha

example (es : List Eff) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (Eff.substRho es e) l t ↔
      Eff.Allows σ κ e l t ∨ ∃ i f, (typeEnvAt 0 [] es).rows[i]? = some f ∧
        e.mem (.rho i) ∧ Eff.Allows σ κ f l t := by
  change Eff.Allows σ κ (Eff.bind (typeEnvAt 0 [] es) e) l t ↔ _
  rw [Eff.allows_bind]
  apply or_congr ?_ Iff.rfl
  simp only [typeEnvAt, RangeIx.inst_nil]
  constructor
  · rintro ⟨k, ix, r, hk, hm, rfl, ht⟩; exact ⟨k, r, hk, hm, ht⟩
  · rintro ⟨k, r, hk, hm, ht⟩; exact ⟨k, .fixed r, r, hk, hm, rfl, ht⟩

example (Γ : Ctx) (Φ : List Pred) (σ : PathEnv) {κ e l k t}
    (b : PathBase) {p q : PathPattern} (hc : p.Covers q)
    (hk : κ l = some k) (he : e.mem (.name l (.fixed (.based b p))))
    (hm : (RangeExpr.based b q).Mem σ k t) :
    Eff.Allows σ κ e l t := by
  have hcov : Eff.Covers Γ Φ e
      (.mk (fun a => decide (a = .name l (.fixed (.based b q)))) []) := by
    constructor
    · intro a ha
      have ha : a = .name l (.fixed (.based b q)) := of_decide_eq_true ha
      subst a
      exact ⟨_, he, rfl, .inr ⟨rfl, hc⟩⟩
    · rintro _ ⟨_, h, _⟩; cases h
  exact hcov.allows (Eff.allows_of_mem hk
    (by simp [Eff.mem, Eff.test, Eff.atoms]) hm)

example (σ : PathEnv) {κ e l k r s t} (hk : κ l = some k)
    (he : e.mem (.name l (.fixed s))) (hc : s.Covers r) (hm : r.Mem σ k t) :
    Eff.Allows σ κ e l t := Eff.allows_of_mem_covers hk he ⟨rfl, hc⟩ hm

private inductive EffectAtom (l : EffName) (ix : RangeIx) : Tel → Prop where
  | done {e : Eff} : e.mem (.name l ix) → EffectAtom l ix (.done a e)
  | param : EffectAtom l ix t → EffectAtom l ix (.param n a t)
private theorem EffectAtom.norm {l ix t} (h : EffectAtom l ix t) : EffectAtom l ix t.norm := by
  induction h with
  | done hm => exact .done (by simpa using hm)
  | param h ih => exact .param ih
private theorem EffectAtom.bind {l ix t} (h : EffectAtom l ix t) (θ : SubstEnv) :
    EffectAtom l (ix.inst θ.ranges) (Tel.bind θ t) := by
  unfold Tel.bind
  apply EffectAtom.norm
  induction h generalizing θ with
  | done hm => exact .done ((Eff.mem_rawBind θ _ _).mpr (.inl ⟨_,hm,rfl,trivial⟩))
  | param h ih => exact .param (ih θ.up)
private theorem EffectAtom.signature {ns ps a l ix} {e : Eff} (h : e.mem (.name l ix)) :
    EffectAtom l ix (signatureTel ns ps a e) := by
  induction ns generalizing ps with
  | nil => exact .done h
  | cons n ns ih => cases ps with
    | nil => exact .done h
    | cons p ps => exact .param ih
private theorem EffectAtom.arguments {P B Ψ Q C Γ Φ ws t a e l r}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e)
    (hm : EffectAtom l (.fixed r) t) : e.mem (.name l (.fixed r)) := by
  induction ws generalizing t with
  | nil => cases h; cases hm with | done hm => exact hm
  | cons v vs ih => cases h with
    | param ha hv hs => cases hm with
      | param hm => exact ih hs (hm.bind (Tel.argumentsEnv v))
private theorem effect_atom {P B Ψ b sg ts es rs ws a e l ix}
    (h : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hm : sg.eff.mem (.name l ix)) (r : RangeExpr)
    (hr : ix.inst rs = .fixed r) : e.mem (.name l (.fixed r)) := by
  have sig : EffectAtom l ix sg.tel := EffectAtom.signature hm
  have ran : EffectAtom l (ix.inst rs) (Tel.instR rs sg.tel) := by
    rw [Tel.instR_eq_bind]; exact sig.bind (.rangesOnly rs)
  rw [hr] at ran
  exact EffectAtom.arguments h.arguments (ran.bind (typeEnvAt 0 ts es))

theorem Builtins.TargetAgreement.obs_allowed {P B Ψ b sg ts es rs ws a e out obs σ}
    (hsh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hkind : sg.kind = .io ∨ sg.kind = .exit)
    (names : NamesWF sg.names sg.params)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : B.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t := by
  have agree := ht.io_target _ _ _ _ _ _ _ _ _ _ _ hs hkind ha hr
  obtain ⟨l,bs,ho,hn,he,hb,sh⟩ := hsh
  refine ⟨l,ho,?_⟩
  cases shape : sg.shape with
  | untargeted =>
    have empty : obs = [] := by simpa [PrimSig.shapeAt,shape,Scope.Signature.ShapeTargets] using agree
    simp [empty]
  | topTargeted k =>
    rw [shape] at sh
    intro t hm
    have kind : t.kind = k := by
      exact (show Scope.Signature.ShapeTargets Val.target? (.topTargeted k) ws obs from
        by simpa [PrimSig.shapeAt,shape] using agree) t hm
    refine ⟨k,.top,sh.1,?_,?_⟩
    · apply effect_atom ha (ix := .top) _ .top rfl
      simp [sh.2.2,Eff.single,Eff.mem,Eff.test,Eff.atoms]
    · exact ⟨kind, .top, by simp, trivial⟩
  | single k p =>
    have shapeok : B.ShapeOk b sg := ⟨l,bs,ho,hn,he,hb,sh⟩
    obtain ⟨r,t,hrs,hw,hm,hshape⟩ := shapeok.single_target shape names ha had
    rw [shape] at sh
    rw [hshape] at agree
    obtain ⟨t',hw',rfl⟩ := agree
    have tt : t' = t := Option.some.inj (hw'.symm.trans hw)
    subst t'
    intro u hu
    have ut : u = t := List.mem_singleton.mp hu
    subst u
    refine ⟨k,r,sh.1,?_,hm⟩
    apply effect_atom ha (ix := .rvar 0) _ r (by simp [hrs,RangeIx.inst])
    simp [sh.2.2.1,Eff.mem,Eff.test,Eff.atoms]
/-- 実表の名前の形成を、観測の許容へ渡す。 -/
example {P B Ψ b sg ts es rs ws a e out obs σ}
    (sc : PrimSig.Scoped P sg) (sh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (hr : B.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t :=
  Builtins.TargetAgreement.obs_allowed sh ht hs hk sc.namesWF ha had hr

/-- 同じ応答の観測を、被覆する周囲の効果へ渡す。 -/
example {P B Ψ b sg ts es rs ws a e out obs σ Γ Φ upper}
    (sc : PrimSig.Scoped P sg) (sh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (hr : B.ioResponse b ts es ws out obs)
    (hc : Eff.Covers Γ Φ upper e) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind upper l t := by
  obtain ⟨l, hl, allowed⟩ := Builtins.TargetAgreement.obs_allowed sh ht hs hk sc.namesWF ha had hr
  exact ⟨l, hl, fun t hm => hc.allows (allowed t hm)⟩

/-- 二段の代入を、元の原子・最初の行像・残った行変数の三経路へ分解する。 -/
theorem Eff.allows_bind_comp (θ φ : SubstEnv) (e : Eff) {σ κ l t} :
    Eff.Allows σ κ (Eff.bind φ (Eff.bind θ e)) l t ↔
      (∃ k ix r, κ l = some k ∧ e.mem (.name l ix) ∧
        (ix.inst θ.ranges).inst φ.ranges = .fixed r ∧ r.Mem σ k t) ∨
      (∃ i f, θ.rows[i]? = some f ∧ e.mem (.rho i) ∧ Eff.Allows σ κ (Eff.bind φ f) l t) ∨
      (∃ i f, θ.rows.length ≤ i ∧ e.mem (.rho i) ∧ φ.rows[i]? = some f ∧ Eff.Allows σ κ f l t) := by
  rw [Eff.allows_bind]
  constructor
  · rintro (⟨k,ix,r,hk,hm,hi,ht⟩ | ⟨j,g,hg,hm,ha⟩)
    · have raw : (Eff.rawBind θ e).mem (.name l ix) := (Eff.mem_norm _ _).mp hm
      rcases (Eff.mem_rawBind θ e _).mp raw with ⟨a,he,eq,_⟩ | ⟨i,f,hf,he,hh⟩
      · cases a with
        | rho i => cases eq
        | name m jx =>
          change Atom.name m (jx.inst θ.ranges) = .name l ix at eq
          cases eq
          exact Or.inl ⟨k,jx,r,hk,he,hi,ht⟩
      · exact Or.inr (Or.inl ⟨i,f,hf,he,(Eff.allows_bind φ f).mpr
          (Or.inl ⟨k,ix,r,hk,hh,hi,ht⟩)⟩)
    · have raw : (Eff.rawBind θ e).mem (.rho j) := (Eff.mem_norm _ _).mp hm
      rcases (Eff.mem_rawBind θ e _).mp raw with ⟨a,he,eq,hleft⟩ | ⟨i,f,hf,he,hh⟩
      · cases a with
        | name m ix => cases eq
        | rho i => cases eq; exact Or.inr (Or.inr ⟨j,g,hleft,he,hg,ha⟩)
      · exact Or.inr (Or.inl ⟨i,f,hf,he,(Eff.allows_bind φ f).mpr (Or.inr ⟨j,g,hg,hh,ha⟩)⟩)
  · rintro (⟨k,ix,r,hk,he,hi,ht⟩ | ⟨i,f,hf,he,ha⟩ | ⟨i,f,hl,he,hf,ha⟩)
    · refine Or.inl ⟨k,ix.inst θ.ranges,r,hk,?_,hi,ht⟩
      exact (Eff.mem_norm _ _).mpr ((Eff.mem_rawBind θ e _).mpr
        (Or.inl ⟨.name l ix,he,rfl,trivial⟩))
    · rcases (Eff.allows_bind φ f).mp ha with ⟨k,ix,r,hk,hh,hi,ht⟩ | ⟨j,g,hg,hh,hgA⟩
      · exact Or.inl ⟨k,ix,r,hk,(Eff.mem_norm _ _).mpr ((Eff.mem_rawBind θ e _).mpr
          (Or.inr ⟨i,f,hf,he,hh⟩)),hi,ht⟩
      · exact Or.inr ⟨j,g,hg,(Eff.mem_norm _ _).mpr ((Eff.mem_rawBind θ e _).mpr
          (Or.inr ⟨i,f,hf,he,hh⟩)),hgA⟩
    · exact Or.inr ⟨i,f,hf,(Eff.mem_norm _ _).mpr ((Eff.mem_rawBind θ e _).mpr
        (Or.inl ⟨.rho i,he,rfl,hl⟩)),ha⟩

/-- 行像と範囲像のどちらの経路も、任意の二段の代入で同じ対象を許す。 -/
example (θ φ : SubstEnv) (e : Eff) {σ κ l t i f}
    (hf : θ.rows[i]? = some f) (he : e.mem (.rho i))
    (ha : Eff.Allows σ κ (Eff.bind φ f) l t) :
    Eff.Allows σ κ (Eff.bind φ (Eff.bind θ e)) l t :=
  (Eff.allows_bind_comp θ φ e).mpr (Or.inr (Or.inl ⟨i,f,hf,he,ha⟩))

end Benitoite.Release.Refinement
