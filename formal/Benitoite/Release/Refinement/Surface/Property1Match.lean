import Benitoite.Release.Refinement.Surface.Property1Control
import Benitoite.Release.Refinement.PatternTransport
import Benitoite.Release.Refinement.PatternSemantics
import Benitoite.Release.Refinement.MatchFacts

/-!
# 性質1の照合の補題

照合する値を一つ束縛した文脈で腕を型付ける（設計書 01-05「match の意味」）。表層の腕の本体は照合する値の束縛の外で
型付け、脱糖は腕の束縛の下へ照合する値の束縛を一つ挿入する。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

theorem _root_.Benitoite.Release.Refinement.Exhaustive.shiftV {a ps} (h : Exhaustive P a ps) (k c : Nat) :
    Exhaustive P (a.shiftV k c) ps :=
  fun v hv => h v ((Inhabits.norm_all_iff a v).mpr
    (((Inhabits.norm_all_iff _ v).mp hv).of_shift_values k c a rfl))

/-- 既定の view では、ソースの網羅性から核の網羅性を得る。 -/
theorem ViewExhaustive.exhaustive {D view a ps} (h : ViewExhaustive D view a ps) : Exhaustive D.core a ps :=
  h D.core ⟨fun _ _ hc => hc, fun _ _ hc hn => (by rw [hn] at hc; cases hc), rfl⟩

theorem unguardedPats_desugarArms (op : OpPrim) (p : Position) :
    (arms : Arms) → unguardedPats (desugarArms op p arms) = arms.unguardedPatterns
  | .nil => rfl
  | .cons alts none _ rest => by
    simp [desugarArms, unguardedPats, Arms.unguardedPatterns, unguardedPats_desugarArms op p rest]
  | .cons alts (some _) _ rest => by
    simp [desugarArms, unguardedPats, Arms.unguardedPatterns, unguardedPats_desugarArms op p rest]

/-- 腕の本体を、照合する値の束縛を腕の束縛の下へ挿入した文脈へ移す。 -/
theorem shift_arm {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {L : LocalCtx} {m : Comp} {b : Ty} {ε : Eff}
    {a : Ty} {δ : List Ty} (hA : Builtins.ValueAssumptions P B)
    (h : HasTypeCQ P B StoreTy.empty Q C (bindParams Γ δ) (liftMany δ.length Φ) (R.map (Ty.shiftV δ.length 0)) m
      (b.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) (localExtend δ.length L)) :
    HasTypeCQ P B StoreTy.empty Q C (bindParams (Γ.extend a) (δ.map (Ty.shiftV 1 0)))
      (liftMany δ.length (Φ.map Pred.lift)) (((R.map (Ty.shiftV 1 0))).map (Ty.shiftV δ.length 0))
      (m.rename (upRen δ.length (· + 1))) ((b.shiftV 1 0).shiftV δ.length 0)
      (Eff.shiftV δ.length 0 (Eff.shiftV 1 0 ε)) (localExtend δ.length (localExtend 1 L)) := by
  have hm0 : FullShiftMap 1 0 Γ (Γ.extend a) := by
    simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] using FullShiftMap.outer Γ [a]
  have hm := hm0.underParams δ
  have hf0 : ∀ q ∈ Φ, Entails ((Γ.extend a).facts ++ Φ.map Pred.lift) (q.shiftV 1 0) := by
    simpa using facts_lift Γ Φ a []
  have hf := ShiftMap.conditions_params hm0.values hf0 δ
  have hh := h.shift_values hA storeEmpty_wf (StoreTy.Extends.refl _) hm
    ((LocalCtx.Shift.outer 1 L).localExtend δ.length) (by simpa only [Nat.zero_add] using hf)
  have hR : (R.map (Ty.shiftV δ.length 0)).map (Ty.shiftV 1 (0 + δ.length)) =
      ((R.map (Ty.shiftV 1 0))).map (Ty.shiftV δ.length 0) := by
    cases R with
    | none => rfl
    | some r => exact congrArg some (Ty.shiftV_comm r δ.length 1 0)
  have eb := Ty.shiftV_comm b δ.length 1 0
  have ee := Eff.shiftV_comm ε δ.length 1 0
  simp only [Nat.zero_add] at eb ee hR hh
  rw [eb, ee, hR] at hh
  rw [show (fun x => x + 1) = shiftIndex 1 0 from (shiftIndex_add 1).symm, upRen_shiftIndex, Nat.zero_add]
  exact hh

theorem clauseSig_sameTypes {D : Declarations} {e o sg} (hR : D.Realizes P) (h : ClauseSig D.core B e o sg) :
    ClauseSig P B e o sg := by
  obtain ⟨S, hS, hop, hr⟩ := h
  refine ⟨S, hS, ?_, hr⟩
  cases o with
  | fail => exact hop
  | user o => simpa only [opSigAt, ← hR.types.ops] using hop
  | prim b => exact hop

theorem clauses_ops (op : OpPrim) : (cs : Clauses) → (desugarClauses op cs).map Clause.op = cs.skeleton.map Clause.op
  | .nil => rfl
  | .cons _ _ _ _ rest _ => by simp [desugarClauses, Clauses.skeleton, Clause.op, clauses_ops op rest]

theorem handled_desugarClauses {D : Declarations} {op cs} (hR : D.Realizes P) :
    handled P B (desugarClauses op cs) = handled D.core B cs.skeleton := by
  have hh : handles (desugarClauses op cs) = handles cs.skeleton := by
    funext o
    have e := clauses_ops op cs
    have h1 : (desugarClauses op cs).any (fun c => c.op == o) = ((desugarClauses op cs).map Clause.op).any (· == o) := by
      simp [List.any_map, Function.comp_def]
    have h2 : cs.skeleton.any (fun c => c.op == o) = (cs.skeleton.map Clause.op).any (· == o) := by
      simp [List.any_map, Function.comp_def]
    simp only [handles, h1, h2, e]
  unfold handled effOps
  rw [hh, ← hR.types.effects]

theorem bindParams_two (Γ : Ctx) (x y : Ty) : bindParams Γ [x, y] = (Γ.extend x).extend (y.shiftV 1 0) := by
  have h := bindParams_snoc Γ [x] y
  simpa [bindParams_single] using h

theorem subst_tvar1 (a b : Ty) : (Ty.tvar 1).subst [a, b] [] = b.norm := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt]

/-- 型の正規形が等しければ、二つ移した型の正規形も等しい。 -/
theorem norm_shift2 {a b : Ty} (h : a.norm = b.norm) :
    ((a.shiftV 1 0).shiftV 1 0).norm = ((b.shiftV 1 0).shiftV 1 0).norm := by
  simp only [Ty.norm_shiftV, h]

theorem selectSlots_range' {α : Type} (xs : List α) :
    ∀ m k, k + m = xs.length → selectSlots xs (List.range' k m) = some (xs.drop k)
  | 0, k, h => by simp [selectSlots, ← h]
  | m + 1, k, h => by
    have hk : k < xs.length := by omega
    rw [List.range'_succ]
    simp only [selectSlots]
    rw [List.getElem?_eq_getElem hk, selectSlots_range' xs m (k + 1) (by omega),
      List.drop_eq_getElem_cons hk]
    rfl

/-- 一つのパターンの恒等の束縛対応。 -/
theorem AltsTy.single {p a δ} (h : PatTy P p a δ) : AltsTy P [⟨p, List.range p.binders⟩] a δ := by
  have hl := MatchFacts.PatTy.binders_length h
  refine ⟨by simp, by simp [Arm.bindersOf, hl], by simp, ?_⟩
  intro alt halt
  simp only [List.mem_singleton] at halt
  subst halt
  refine ⟨δ, h, by rw [hl], ?_⟩
  rw [← hl, List.range_eq_range', selectSlots_range' δ δ.length 0 (by simp)]
  simp

end Benitoite.Release.Refinement.Surface
