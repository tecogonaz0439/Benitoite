import Benitoite.Release.Refinement.Context.Facts
import Benitoite.Release.Refinement.KindInference

/-!
# 宣言順の入力列と宣言で固定した kind

引数型は先行する引数だけを束縛した文脈で読む。型引数の kind は
呼出し元の宣言から一度決め、既存の存在量化した補助判断へ渡す。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def BinderTypes.Annotations (P : Program) (C : TypeCtx) : Ctx → List Ty → Prop
  | _, [] => True
  | Γ, a :: as => Ty.Annotation P C Γ a ∧ BinderTypes.Annotations P C (Γ.extend a) as

theorem BinderTypes.Annotations.wf {P C Γ as} (h : BinderTypes.Annotations P C Γ as) :
    BinderTypes.WF C.length Γ as := by
  induction as generalizing Γ with
  | nil => trivial
  | cons a as ih => exact ⟨h.1.wf, ih h.2⟩

theorem BinderTypes.Annotations.sorted {P C Γ as} (h : BinderTypes.Annotations P C Γ as) :
    BinderTypes.Sorted Γ as := by
  induction as generalizing Γ with
  | nil => trivial
  | cons a as ih => exact ⟨h.1.sorted, ih h.2⟩

theorem BinderTypes.Annotations.extendMany {P C Γ as} (hΓ : Ctx.Regular P C Γ)
    (h : BinderTypes.Annotations P C Γ as) : Ctx.Regular P C (Γ.extendMany as) := by
  induction as generalizing Γ with
  | nil => exact hΓ
  | cons a as ih => exact ih (hΓ.extend h.1) h.2

theorem FactsWF.extendMany {P C Γ Φ} (h : FactsWF P C Γ Φ) (as : List Ty) :
    FactsWF P C (Γ.extendMany as) (liftMany as.length Φ) := by
  induction as generalizing Γ Φ with
  | nil => exact h
  | cons a as ih =>
    have hh := ih (h.extend a)
    have hl : liftMany (as.length+1) Φ = liftMany as.length (Φ.map Pred.lift) := by
      rw [← liftMany_one, liftMany_add]
      congr 1
      omega
    exact hl.symm ▸ hh

theorem BinderTypes.localWF_iff {nt : Nat} {Γ : Ctx} {as : List Ty} :
    BinderTypes.LocalWF nt Γ.length as ↔ BinderTypes.WF nt Γ as := by
  induction as generalizing Γ with
  | nil => rfl
  | cons a as ih =>
    simp only [BinderTypes.LocalWF, BinderTypes.WF, ← ih, Ctx.extend, List.length_cons, List.length_map]

def Tel.inputs : Tel → List Ty
  | .done _ _ => []
  | .param _ a t => a :: t.inputs

def Tel.context (Γ : Ctx) : Tel → Ctx
  | .done _ _ => Γ
  | .param _ a t => t.context (Γ.extend a)

theorem Tel.context_eq_extendMany (t : Tel) (Γ : Ctx) : t.context Γ = Γ.extendMany t.inputs := by
  cases t with
  | done _ _ => rfl
  | param _ _ t => exact t.context_eq_extendMany _

@[simp] theorem Tel.inputs_length (t : Tel) : t.inputs.length = t.arity := by
  cases t with
  | done _ _ => rfl
  | param _ _ t => simpa only [Tel.inputs, Tel.arity, Tel.names, List.length_cons] using congrArg (· + 1) t.inputs_length

theorem Tel.annotation_inputs {P C Γ t} (h : Ty.Annotation P C Γ (.dependentFn t)) :
    BinderTypes.Annotations P C Γ t.inputs := by
  cases t with
  | done _ _ => trivial
  | param n a t =>
    exact ⟨⟨h.wf.1, h.sorted.1, h.declared.1⟩,
      Tel.annotation_inputs ⟨by simpa [Ctx.extend, Ty.WF] using h.wf.2, h.sorted.2, h.declared.2⟩⟩

theorem Tel.annotation_result {P C Γ t} (h : Ty.Annotation P C Γ (.dependentFn t)) :
    Ty.Annotation P C (t.context Γ) (Tel.result t) := by
  cases t with
  | done a e => exact ⟨h.wf.1, h.sorted.1, h.declared.1⟩
  | param n a t =>
    exact Tel.annotation_result (Γ := Γ.extend a) (t := t) ⟨by simpa [Ctx.extend, Ty.WF] using h.wf.2, h.sorted.2, h.declared.2⟩

theorem Tel.annotation_effect {P C Γ t} (h : Ty.Annotation P C Γ (.dependentFn t)) :
    RowAnnotations P C (t.context Γ) [Tel.effect t] := by
  cases t with
  | done a e =>
    intro f hf
    have he : f = e := by simpa only [Tel.effect, List.mem_singleton] using hf
    subst f
    exact ⟨⟨by simp [NamesWF], trivial, trivial, h.wf.2.1, h.wf.2.2⟩,
      ⟨trivial, trivial, h.sorted.2⟩, ⟨trivial, trivial, h.declared.2⟩⟩
  | param n a t =>
    exact Tel.annotation_effect (Γ := Γ.extend a) (t := t) ⟨by simpa [Ctx.extend, Ty.WF] using h.wf.2, h.sorted.2, h.declared.2⟩

theorem Tel.regular_context {P C Γ t} (hΓ : Ctx.Regular P C Γ)
    (h : Ty.Annotation P C Γ (.dependentFn t)) : Ctx.Regular P C (t.context Γ) := by
  rw [Tel.context_eq_extendMany]
  exact (Tel.annotation_inputs h).extendMany hΓ

/-- 一引数を消した後続も、元の注釈と実引数から再検査できる。 -/
theorem Tel.annotation_open {P B Ψ Q C Γ Φ name a t v}
    (hΓ : Ctx.WF 0 C.length Γ) (h : Ty.Annotation P C Γ (.dependentFn (.param name a t)))
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Ty.Annotation P C Γ (.dependentFn (Tel.bind (Tel.argumentsEnv v) t)) := by
  have ha : Ty.Annotation P C Γ a := ⟨h.wf.1, h.sorted.1, h.declared.1⟩
  have ht : Ty.Annotation P C (Γ.extend a) (.dependentFn t) :=
    ⟨by simpa [Ctx.extend, Ty.WF] using h.wf.2, h.sorted.2, h.declared.2⟩
  have hs := (SubstOk.openValue (R := none) hv ha hΓ).telAnnotation ht
  simpa only [valEnv_openValue] using hs

abbrev TypeArgsKindedAt := TypeArgsKinded

theorem TypeArgsKindedAt.forget {P D ts ks} (h : TypeArgsKindedAt P D ts ks) :
    TypeArgsKinded P D ts ks := h

theorem TypeArgsKindedAt.shift {P D ts ks} (h : TypeArgsKindedAt P D ts ks) (k c : Nat) :
    TypeArgsKindedAt P D (ts.map (Ty.shiftV k c)) ks := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a t ha ht
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact ⟨(h.2 i b t hb ht).1.shift_values k c, fun hv =>
    (Ty.ordinary_shiftV _ _ _).mpr ((h.2 i b t hb ht).2 hv)⟩

theorem TypeArgsKindedAt.subst {P D ts ks} (h : TypeArgsKindedAt P D ts ks) (ν : Nat → Val) :
    TypeArgsKindedAt P D (ts.map (substTyValues ν)) ks := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a t ha ht
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  exact ⟨(h.2 i b t hb ht).1.bind_values ν, fun hv =>
    (Ty.ordinary_bind_values _ _).mpr ((h.2 i b t hb ht).2 hv)⟩

structure SignatureInstanceAt (P : Program) (D : List TParamDecl) (Γ : Ctx)
    (t : Tel) (ks : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : (Ty.dependentFn t).WF 0 ks.length 0
  types : TypeAnnotations P D Γ ts
  kinds : TypeArgsKindedAt P D ts ks
  rows : RowAnnotations P D Γ es
  result : Ty.Annotation P D Γ (.dependentFn (instantiatedTel t ts es))

theorem SignatureInstanceAt.forget {P D Γ t ks ts es} (h : SignatureInstanceAt P D Γ t ks ts es) :
    SignatureInstance P D Γ t ks ts es :=
  ⟨h.source, h.types, h.kinds.forget, h.rows, h.result⟩

def OpDecl.SignatureWF (d : OpDecl) : Prop :=
  BinderTypes.LocalWF d.tparams.length 0 d.params ∧ d.ret.WF 0 d.tparams.length d.params.length

def Program.OpSignaturesWF (P : Program) : Prop := ∀ o d, P.ops o = some d → d.SignatureWF

theorem Program.OpSignaturesWF.user {P B S o sg} (h : Program.OpSignaturesWF P)
    (hl : opSigAt P B S (.user o) = some sg) : sg.WF := by
  simp only [opSigAt] at hl
  obtain ⟨d, hd, he⟩ := Option.map_eq_some_iff.mp hl
  cases he
  simpa only [OpSig.WF, OpDecl.SignatureWF, TypeCtx.length_values] using h o d hd

theorem Ty.instTarget_fixed {nt nv a} (h : Ty.WF 0 nt nv a) (rs : List RangeExpr) :
    a.instTarget rs = a := by
  cases a <;> try rfl
  all_goals cases hix : ‹RangeIx› <;> simp_all [Ty.instTarget, Ty.WF, RangeIx.WF]

theorem BinderTypes.LocalWF.instTarget {nt n ps} (h : BinderTypes.LocalWF nt n ps)
    (rs : List RangeExpr) : BinderTypes.LocalWF nt n (ps.map (Ty.instTarget rs)) := by
  induction ps generalizing n with
  | nil => trivial
  | cons a ps ih =>
    simp only [List.map_cons, BinderTypes.LocalWF]
    rw [Ty.instTarget_fixed h.1 rs]
    exact ⟨h.1, ih h.2⟩

/-- 範囲変数は操作の対象の最上位にあり、他の注釈は閉じた範囲を持つ。 -/
def Ty.TargetWF (nr nt nv : Nat) : Ty → Prop
  | .opaque _ (.rvar i) | .scoped _ _ (.rvar i) => i < nr
  | a => a.WF 0 nt nv

theorem Ty.TargetWF.instTarget {nr nt nv a rs} (h : Ty.TargetWF nr nt nv a)
    (hn : rs.length = nr) : (a.instTarget rs).WF 0 nt nv := by
  cases a <;> try exact h
  all_goals
    cases hix : ‹RangeIx› with
    | fixed r => trivial
    | rvar i =>
      have hi : i < rs.length := by simpa only [Ty.TargetWF, hix, hn] using h
      have hr : rs[i]? = some rs[i] := List.getElem?_eq_some_iff.mpr ⟨hi, rfl⟩
      simp [Ty.instTarget, RangeIx.inst, hr, Ty.WF, RangeIx.WF]

def BinderTypes.TargetWF (nr nt : Nat) : Nat → List Ty → Prop
  | _, [] => True
  | n, a :: as => a.TargetWF nr nt n ∧ BinderTypes.TargetWF nr nt (n+1) as

theorem BinderTypes.TargetWF.instTarget {nr nt n ps rs} (h : BinderTypes.TargetWF nr nt n ps)
    (hn : rs.length = nr) : BinderTypes.LocalWF nt n (ps.map (Ty.instTarget rs)) := by
  induction ps generalizing n with
  | nil => trivial
  | cons a ps ih => exact ⟨h.1.instTarget hn, ih h.2⟩

def PrimSig.OperationWF (s : PrimSig) : Prop :=
  BinderTypes.TargetWF s.rkinds.length s.tparams.length 0 s.params ∧
    s.ret.WF 0 s.tparams.length s.params.length

def Builtins.OpSignaturesWF (B : Builtins) : Prop :=
  ∀ b s, B.sig b = some s → s.opEff ≠ none → s.OperationWF

theorem Builtins.OpSignaturesWF.prim {P B S b sg} (h : Builtins.OpSignaturesWF B)
    (hl : opSigAt P B S (.prim b) = some sg) : sg.WF := by
  simp only [opSigAt] at hl
  cases hb : B.sig b with
  | none => simp [hb] at hl
  | some s =>
    rw [hb] at hl
    obtain ⟨e, he, hsg⟩ := Option.map_eq_some_iff.mp hl
    cases hsg
    have hs := h b s hb (by simp [he])
    exact ⟨by simpa only [List.length_map] using hs.1.instTarget (by simp),
      by simpa only [List.length_map] using hs.2⟩

theorem ClauseSig.wf {P B e o sg} (hp : Program.OpSignaturesWF P)
    (hb : Builtins.OpSignaturesWF B) (h : ClauseSig P B e o sg) : sg.WF := by
  obtain ⟨S, _, hl⟩ := h
  cases o with
  | fail => cases hl
  | user o => exact hp.user hl
  | prim b => exact hb.prim hl

private theorem regular_hideMap (Γ : Ctx) : ShiftMap 0 0 Γ (Refinement.hideConts Γ) := by
  refine ⟨by simp [Refinement.hideConts], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

private theorem regular_outerMap (Γ : Ctx) (i : Nat) : ShiftMap 0 0 (Γ.outer i) ((Refinement.hideConts Γ).outer i) := by
  refine ⟨by simp [Refinement.hideConts], ?_⟩
  intro j a hj ho
  obtain ⟨h1, h2⟩ := Ctx.lookup_outer.mp hj
  simpa [shiftIndex_zero, Ty.shiftV_zero] using
    Ctx.lookup_outer.mpr ⟨h1, hideConts_lookup.mpr ⟨h2, ho⟩⟩

/-- 継続を隠した文脈も Regular。 -/
theorem Ctx.Regular.hideConts {P C Γ} (h : Ctx.Regular P C Γ) : Ctx.Regular P C (Refinement.hideConts Γ) := by
  have hm := regular_hideMap Γ
  have ann : ∀ (i : Nat) (a : Ty), (Refinement.hideConts Γ)[i]? = some (some a) → Ty.Annotation P C (Refinement.hideConts Γ) a := by
    intro i a hx
    have hl := (hideConts_lookup.mp hx).1
    simpa [Ty.shiftV_zero] using
      hm.annotation (a := a) ⟨h.wf i a hl, h.sorted i a hl, h.declared i a hl⟩
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro i a hx; simpa [Refinement.hideConts] using (ann i a hx).wf
  · intro i a hx; exact (ann i a hx).sorted
  · intro i a hx; exact (ann i a hx).declared
  · intro i a hx
    have hl := (hideConts_lookup.mp hx).1
    have hr := (regular_outerMap Γ i).references
    have hh := (h.ordered i a hl).rawSubstV hr
    rw [Ty.rawSubstV_eq_rawBind] at hh
    change Ty.References _ (renameTy (shiftIndex 0 0) a) at hh
    simpa only [← Ty.shiftV_eq_renameTy, Ty.shiftV_zero] using hh

/-- 非依存の引数列の文脈も Regular。 -/
theorem Ctx.Regular.bindParams {P C} (n : Nat) : ∀ {ps : List Ty} {Γ : Ctx}, ps.length = n →
    Ctx.Regular P C Γ → TypeAnnotations P C Γ ps → Ctx.Regular P C (bindParams Γ ps) := by
  induction n with
  | zero =>
    intro ps Γ hn h _
    cases ps with
    | nil =>
      have he : (fun x : Option Ty => Option.map (Ty.shiftV 0 0) x) = id := by
        funext x; cases x <;> simp [Ty.shiftV_zero]
      have : List.map (Option.map (Ty.shiftV 0 0)) Γ = Γ := by
        simpa only [List.map_id] using congrArg (fun f => List.map f Γ) he
      simpa [Refinement.bindParams, this] using h
    | cons _ _ => cases hn
  | succ n ih =>
    intro ps Γ hn h ha
    cases ps with
    | nil => cases hn
    | cons a ps =>
      rw [← bindParams_cons]
      apply ih (by simpa using hn) (h.extend (ha a List.mem_cons_self))
      intro b hb
      obtain ⟨c, hc, rfl⟩ := List.mem_map.mp hb
      exact (ShiftMap.outerValue Γ (some (a.shiftV 1 0))).annotation (ha c (List.mem_cons_of_mem _ hc))

end
end Benitoite.Release.Refinement
