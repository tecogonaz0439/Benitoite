import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr
import Benitoite.Release.Refinement.Surface.Property1Match
import Benitoite.Release.Refinement.Surface.NormalContext

/-! # 開いた範囲文脈のハンドラと節列の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeEff_union (rs : List RangeExpr) (e f : Eff) :
    rangeEff rs (Eff.union e f) = Eff.union (rangeEff rs e) (rangeEff rs f) := by
  cases rs with
  | nil => rfl
  | cons r rs => exact (Eff.instR_eq_bind _ _).trans ((Eff.bind_union _ _ _).trans
      (by rw [← Eff.instR_eq_bind, ← Eff.instR_eq_bind]; rfl))

theorem rangeEff_sub {e f : Eff} (h : Eff.Sub e f) (rs : List RangeExpr) :
    Eff.Sub (rangeEff rs e) (rangeEff rs f) := by
  cases rs with
  | nil => exact h
  | cons r rs => simpa only [rangeEff, Eff.instR_eq_bind] using h.bind (.rangesOnly (r :: rs))

theorem rangeEff_noFail {Q e} (h : NoFail Q e) (rs : List RangeExpr) : NoFail Q (rangeEff rs e) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    constructor
    · cases e with
      | mk atoms fails =>
        change Order.sortUnique tyCompare (Ty.normTys (mapRangesTys _ fails)) = []
        have hf : fails = [] := h.1
        simp only [hf, mapRangesTys, Ty.normTys, Order.sortUnique]
    · intro i hi
      apply h.2 i
      change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm).mem (.rho i) at hi
      rw [Eff.mem_norm] at hi
      cases e with
      | mk atoms fails => simpa only [Eff.mem, Eff.test, Eff.atoms, Eff.rawMapRanges, mapRangeAtoms_rho] using hi

theorem clauseSig_rangeEff {P B e o sg} (h : ClauseSig P B e o sg) (rs : List RangeExpr) :
    ClauseSig P B (rangeEff rs e) o sg := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    obtain ⟨S, hS, hop, hr⟩ := h
    refine ⟨S, ?_, hop, hr⟩
    rcases hS with htop | ⟨b, s, l, ho, hs, hl, hrows, hmem, honly⟩
    · exact Or.inl htop
    · refine Or.inr ⟨b, s, l, ho, hs, hl, ?_, ?_, ?_⟩
      · intro i hi
        apply hrows i
        change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm).mem (.rho i) at hi
        rw [Eff.mem_norm] at hi
        cases e with
        | mk atoms fails => simpa only [Eff.mem, Eff.test, Eff.atoms, Eff.rawMapRanges, mapRangeAtoms_rho] using hi
      · change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm).mem (.name l (.fixed S))
        rw [Eff.mem_norm]
        cases e with
        | mk atoms fails => exact (mapRangeAtoms_spec _ _ _).mpr ⟨.name l (.fixed S), hmem, rfl⟩
      · intro ix hi
        change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm).mem (.name l ix) at hi
        rw [Eff.mem_norm] at hi
        cases e with
        | mk atoms fails =>
          obtain ⟨a, ha, he⟩ := (mapRangeAtoms_spec _ _ _).mp hi
          cases a with
          | rho i => cases he
          | name m j =>
            cases he
            have hj := honly j ha
            subst j
            rfl

theorem rangeTy_shiftTypes (rs : List RangeExpr) (a : Ty) (k c : Nat) :
    rangeTy rs (shiftTypes k c a) = shiftTypes k c (rangeTy rs a) := by
  cases rs with
  | nil => rfl
  | cons r rs => exact (congrArg Ty.norm (shiftTypes_mapRanges a k c _)).trans (Ty.norm_shiftTypes _ _ _)

theorem rangeEff_shiftTypes (rs : List RangeExpr) (e : Eff) (k c : Nat) :
    rangeEff rs (shiftRowsTypes k c e) = shiftRowsTypes k c (rangeEff rs e) := by
  cases rs with
  | nil => rfl
  | cons r rs => exact (congrArg Eff.norm (shiftRowsTypes_mapRanges e k c _)).trans (Eff.norm_shiftTypes _ _ _)

theorem rangeCtx_shiftE (rs : List RangeExpr) (Γ : Ctx) (k : Nat) :
    rangeCtx rs (Γ.shiftE k) = (rangeCtx rs Γ).shiftE k := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeCtx, Ctx.mapRanges, Ctx.shiftE, Ctx.shiftEAt, List.map_map, Option.map_map, Function.comp_def]
    congr 1
    funext oa
    cases oa with
    | none => rfl
    | some a => exact congrArg some (rangeTy_shiftTypes (r :: rs) a k 0)

theorem rangeCtx_extendMany (rs : List RangeExpr) (Γ : Ctx) (ps : List Ty) :
    rangeCtx rs (Γ.extendMany ps) = (rangeCtx rs Γ).extendMany (ps.map (rangeTy rs)) := by
  induction ps generalizing Γ with
  | nil => rfl
  | cons a ps ih => simp only [Ctx.extendMany, List.map_cons, ih, rangeCtx_extend]

theorem rangeTy_closed (rs : List RangeExpr) (a : Ty) (hc : a.RangesScoped 0) :
    rangeTy rs a = match rs with | [] => a | _ => a.norm := by
  cases rs with
  | nil => rfl
  | cons r rs => exact congrArg Ty.norm (Ty.rawMapRanges_of_rangesClosed a hc _)

theorem rangeCtx_clauseContext (rs : List RangeExpr) (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) :
    rangeCtx rs (sg.context Γ t e) =
      {sg with params := sg.params.map (rangeTy rs), ret := rangeTy rs sg.ret}.context
        (rangeCtx rs Γ) (rangeTy rs t) (rangeEff rs e) := by
  simp only [OpSig.context, rangeCtx_extend, rangeCtx_extendMany, rangeCtx_shiftE,
    OpSig.continuation, rangeTy_cont, rangeTy_shiftV, rangeTy_shiftTypes, rangeEff_shiftV,
    rangeEff_shiftTypes, List.length_map]

private theorem handler_rangeLocal_nil (rs : List RangeExpr) : rangeLocal rs [] = [] := by cases rs <;> rfl

private theorem handler_rangeCtx_extendNone (rs : List RangeExpr) (Γ : Ctx) :
    rangeCtx rs Γ.extendNone = (rangeCtx rs Γ).extendNone := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeCtx, Ctx.extendNone, Ctx.mapRanges, List.map_cons, List.map_map,
      Option.map_none, Option.map_map, Function.comp_def]
    congr 2
    funext oa
    cases oa with
    | none => rfl
    | some a => exact congrArg some (rangeTy_shiftV (r :: rs) a 1 0)

theorem rangeCtx_failureContext (rs : List RangeExpr) (Γ : Ctx) (E : Ty) :
    rangeCtx rs (failureContext Γ E) = failureContext (rangeCtx rs Γ) (rangeTy rs E) := by
  simp only [failureContext, handler_rangeCtx_extendNone, rangeCtx_extend, rangeCtx_shiftE,
    rangeTy_shiftTypes]

theorem rangeEff_singleFail (rs : List RangeExpr) (a : Ty) :
    rangeEff rs (Eff.singleFail a) = Eff.singleFail (rangeTy rs a) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeEff, rangeTy, Eff.instR, Eff.substRAt, Eff.mapRanges, Eff.singleFail,
      Eff.rawMapRanges, mapRangesTys, Eff.norm, Ty.normTys, Ty.norm_rawMapRanges,
      Order.sortUnique, Order.insertUnique, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.norm_idem]
    congr 1
    funext x
    simp [mapRangeAtoms]

theorem clauses_instR_ops (rs : List RangeExpr) (cs : List Clause) :
    (Clause.instRList rs cs).map Clause.op = cs.map Clause.op := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    induction cs with
    | nil => rfl
    | cons c cs ih => cases c <;> simp only [Clause.instRList, Clause.mapRangesListN, List.map_cons, Clause.op] at ih ⊢ <;> rw [ih]

theorem handled_instR_clauses (rs : List RangeExpr) (P : Refinement.Program) (B : Builtins) (cs : List Clause) :
    handled P B (Clause.instRList rs cs) = handled P B cs := by
  have hh : handles (Clause.instRList rs cs) = handles cs := by
    funext o
    have h1 : (Clause.instRList rs cs).any (fun c => c.op == o) =
        ((Clause.instRList rs cs).map Clause.op).any (· == o) := by simp [List.any_map, Function.comp_def]
    have h2 : cs.any (fun c => c.op == o) = (cs.map Clause.op).any (· == o) := by simp [List.any_map, Function.comp_def]
    simp only [handles, h1, h2, clauses_instR_ops]
  unfold handled
  rw [hh]

theorem rangeEff_handled_sub (rs : List RangeExpr) (P : Refinement.Program) (B : Builtins) (cs : List Clause) :
    Eff.Sub (rangeEff rs (handled P B cs)) (handled P B cs) := by
  cases rs with
  | nil => exact ⟨fun _ h => h, fun _ h => h⟩
  | cons r rs =>
    constructor
    · intro a ha
      change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) (handled P B cs)).norm).mem a at ha
      rw [Eff.mem_norm] at ha
      obtain ⟨x, hx, he⟩ := (mapRangeAtoms_spec _ _ _).mp ha
      cases x with
      | rho i => exact False.elim (Bool.false_ne_true hx)
      | name l ix => cases ix <;> cases he <;> exact hx
    · intro t ht
      change (Eff.rawMapRanges (rangeAt 0 (r :: rs)) (handled P B cs)).norm.memFail t at ht
      rw [Eff.norm_memFail] at ht
      obtain ⟨a, ha, _⟩ := ht
      cases ha

private theorem handler_sub_union_right {a b c d : Eff} (h : Eff.Sub c d) (ha : Eff.Sub a (Eff.union b c)) :
    Eff.Sub a (Eff.union b d) := by
  constructor
  · intro x hx
    rcases (Eff.mem_union_iff _ _ _).mp (ha.1 x hx) with hb | hc
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inl hb)
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inr (h.1 x hc))
  · intro t ht
    rcases (Eff.memFail_union_iff _ _ _).mp (ha.2 t ht) with hb | hc
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inl hb)
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inr (h.2 t hc))

private theorem handler_handle_instR (rs : List RangeExpr) (m : Comp) (cs : List Clause) :
    (Comp.handle m cs).instR rs = .handle (m.instR rs) (Clause.instRList rs cs) := by cases rs <;> rfl

theorem handle_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p body cs t εb ε}
    (hR : D.Realizes P) (σ : Instance ks)
    (hb : BlockCore P B op Q Δ C Γ Φ R .other body t εb σ.val)
    (hsub : Eff.Sub εb (Eff.union ε (handled D.core B cs.skeleton)))
    (hcs : HasTypeClausesQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
      (rangeEff σ.val εb) (Clause.instRList σ.val (desugarClauses op cs)) (rangeTy σ.val t)
      (rangeEff σ.val ε) (rangeLocal σ.val Δ)) :
    ExprCore P B op Q Δ C Γ Φ R p (.handleE body cs) t ε σ.val := by
  unfold ExprCore
  rw [desugarExpr, handler_handle_instR]
  apply HasTypeCQ.C_Handle hb ?_ hcs
  have hs := rangeEff_sub hsub σ.val
  rw [rangeEff_union] at hs
  have hs' := handler_sub_union_right (rangeEff_handled_sub σ.val D.core B cs.skeleton) hs
  simpa only [handled_instR_clauses, handled_desugarClauses hR] using hs'

private theorem handler_fail_instR (rs : List RangeExpr) (a : Ty) (m : Comp) :
    Clause.instRList rs [.fail a m] = [.fail (rangeTy rs a) (m.instR rs)] := by cases rs <;> rfl

theorem handleFail_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p E t body clause eb rest ec}
    (hR : D.Realizes P) (σ : Instance ks)
    (hb : BlockCore P B op Q Δ C Γ Φ R .other body t eb σ.val)
    (hsub : Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) (hnf : NoFail Q rest)
    (hE : Ty.AnnotationR D.core ks C Γ E) (ht : Ty.AnnotationR D.core ks C Γ t)
    (hec : RowAnnotations D.core ks C Γ [ec])
    (hcl : BlockCore P B op Q [] (TypeCtx.valueParam :: C) (failureContext Γ E)
      (liftMany 2 Φ) (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) .other clause
      ((shiftTypes 1 0 t).shiftV 2 0) ((shiftRowsTypes 1 0 ec).shiftV 2 0) σ.val) :
    ExprCore P B op Q Δ C Γ Φ R p (.handleFail E t body clause) t (Eff.union rest ec) σ.val := by
  have hE' := annotation (B := B) (annotation_sameTypes hE hR.types) σ
  have ht' := annotation (B := B) (annotation_sameTypes ht hR.types) σ
  have hec' := annotation (B := B) (annotation_sameTypes (hec ec (by simp)) hR.types) σ
  have her : Refinement.RowAnnotations P C (rangeCtx σ.val Γ) [rangeEff σ.val ec] := by
    intro e he
    simp only [List.mem_singleton] at he
    subst e
    simpa only [rangeTy_fn, List.map_nil,
      show rangeTy σ.val (.base .unit) = .base .unit from by cases σ.val <;> rfl] using hec'
  have hcl' := hcl
  simp only [BlockCore, rangeCtx_failureContext, rangeTy_shiftV, rangeTy_shiftTypes,
    rangeEff_shiftV, rangeEff_shiftTypes, handler_rangeLocal_nil, Option.map_map, Function.comp_def] at hcl'
  rw [← hideBuilders_empty] at hcl'
  unfold ExprCore
  rw [desugarExpr, handler_handle_instR, handler_fail_instR, rangeEff_union]
  apply HasTypeCQ.C_Handle_Fail hb ?_ (rangeEff_noFail hnf σ.val) (.one hE' ht' her (by simpa only [Option.map_map, Function.comp_def] using hcl'))
  simpa only [rangeEff_union, rangeEff_singleFail] using rangeEff_sub hsub σ.val

/-- 節列の保存の結論。相互帰納では再帰した節列の結果をこの形で受け取る。 -/
abbrev ClausesCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff)
    (cs : Clauses) (t : Ty) (e : Eff) (rs : List RangeExpr) : Prop :=
  HasTypeClausesQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
    (rangeEff rs eb) (Clause.instRList rs (desugarClauses op cs)) (rangeTy rs t) (rangeEff rs e) (rangeLocal rs Δ)

theorem clauses_nil_core {P B op Q Δ C Γ Φ R eb t e} (rs : List RangeExpr) :
    ClausesCore P B op Q Δ C Γ Φ R eb .nil t e rs := by
  have hn : Clause.instRList rs [] = [] := by cases rs <;> rfl
  unfold ClausesCore
  rw [desugarClauses, hn]
  exact .nil

/-- 捕捉する操作の宣言の型に、自由な範囲変数を残さない。 -/
def ClauseSyntax (sg : OpSig) : Prop :=
  (∀ a ∈ sg.params, a.RangesScoped 0) ∧ sg.ret.RangesScoped 0

private theorem normCtx_extendMany (Γ : Ctx) (ps : List Ty) :
    (Γ.extendMany ps).map (Option.map Ty.norm) =
      Ctx.extendMany (Γ.map (Option.map Ty.norm)) (ps.map Ty.norm) := by
  induction ps generalizing Γ with
  | nil => rfl
  | cons a ps ih =>
    simp only [Ctx.extendMany, List.map_cons, ih, Ctx.extend, List.map_cons, List.map_map,
      Option.map_some, Option.map_map, Function.comp_def, Ty.norm_shiftV]

/-- 閉じた操作の型は、正規化した文脈で元の署名と照合できる。 -/
theorem rangeCtx_clauseContext_normEq (rs : List RangeExpr) (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff)
    (hs : ClauseSyntax sg) :
    (rangeCtx rs (sg.context Γ t e)).NormEq
      (sg.context (rangeCtx rs Γ) (rangeTy rs t) (rangeEff rs e)) := by
  rw [rangeCtx_clauseContext]
  have hps : (sg.params.map (rangeTy rs)).map Ty.norm = sg.params.map Ty.norm := by
    rw [List.map_map]
    apply List.map_congr_left
    intro a ha
    change (rangeTy rs a).norm = a.norm
    rw [rangeTy_closed rs a (hs.1 a ha)]
    cases rs <;> simp only [Ty.norm_idem]
  have hret : (rangeTy rs sg.ret).norm = sg.ret.norm := by
    rw [rangeTy_closed rs sg.ret hs.2]
    cases rs <;> simp only [Ty.norm_idem]
  simp only [Ctx.NormEq, OpSig.context, Ctx.extend, List.map_cons, Option.map_some,
    OpSig.continuation, List.length_map, Ty.norm, Ty.norm_shiftV, hret]
  congr 1
  have he := congrArg (List.map (Option.map (Ty.shiftV 1 0)))
    ((normCtx_extendMany ((rangeCtx rs Γ).shiftE sg.tparams.length) (sg.params.map (rangeTy rs))).trans
      (by rw [hps, ← normCtx_extendMany]))
  simpa only [List.map_map, Option.map_map, Function.comp_def, Ty.norm_shiftV] using he

private theorem rangeCtx_normal (rs : List RangeExpr) (hne : rs ≠ []) (Γ : Ctx) :
    ∀ (i : Nat) (a : Ty), (rangeCtx rs Γ)[i]? = some (some a) → a.norm = a := by
  cases rs with
  | nil => exact False.elim (hne rfl)
  | cons r rs =>
    intro i a ha
    simp only [rangeCtx, Ctx.mapRanges, List.getElem?_map] at ha
    obtain ⟨oa, _, he⟩ := Option.map_eq_some_iff.mp ha
    cases oa with
    | none => cases he
    | some a => cases he; exact Ty.norm_idem _

private theorem handler_clauses_cons_instR (rs : List RangeExpr) (o : OpRef) (n k : Nat) (m : Comp) (cs : List Clause) :
    Clause.instRList rs (.mk o n k m :: cs) = .mk o n k (m.instR rs) :: Clause.instRList rs cs := by cases rs <;> rfl

theorem clauses_cons_core {D : Declarations} {P B ks op Q Δ C Γ Φ R eb o n ntys body cs t e sg ndicts}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) (_hallowed : ClauseAllowed D B o)
    (hsig : ClauseSig D.core B eb o sg) (hn : NamesWF sg.names sg.params)
    (hcount : ndicts + n = sg.params.length) (hk : ntys = sg.tparams.length) (hw : sg.WF)
    (hs : ClauseSyntax sg)
    (hb : BlockCore P B op Q [] (sg.tparams ++ C) (sg.context Γ t e)
      (liftMany (sg.params.length + 1) Φ)
      (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length + 1) 0))
      .other body ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length + 1) 0)
      ((shiftRowsTypes sg.tparams.length 0 e).shiftV (sg.params.length + 1) 0) σ.val)
    (hrest : ClausesCore P B op Q Δ C Γ Φ R eb cs t e σ.val) :
    ClausesCore P B op Q Δ C Γ Φ R eb (.cons o n ntys body cs ndicts) t e σ.val := by
  have hb' := hb
  simp only [BlockCore, rangeTy_shiftV,
    rangeTy_shiftTypes, rangeEff_shiftV, rangeEff_shiftTypes, handler_rangeLocal_nil,
    Option.map_map, Function.comp_def] at hb'
  rw [← hideBuilders_empty] at hb'
  unfold ClausesCore
  rw [desugarClauses, handler_clauses_cons_instR]
  apply HasTypeClausesQ.cons (clauseSig_sameTypes hR (clauseSig_rangeEff hsig σ.val)) hn hcount hk hw ?_ hrest
  cases hr : σ.val with
  | nil => simpa only [hr, rangeCtx, rangeTy, rangeEff, Option.map_map, Function.comp_def] using hb'
  | cons r rs =>
    have hc := NormalContext.comp hb' hA (by intro l t hl; cases hl)
      (rangeCtx_clauseContext_normEq σ.val sg Γ t e hs)
      (rangeCtx_normal σ.val (by simp [hr]) _)
      (NormalContext.clause_shape hw (rangeCtx_normal σ.val (by simp [hr]) Γ)
        (rangeTy σ.val t) (rangeEff σ.val e))
    simpa only [hr, Option.map_map, Function.comp_def] using hc

end
end Benitoite.Release.Refinement.Surface.OpenSurface
