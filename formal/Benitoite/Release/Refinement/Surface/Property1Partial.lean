import Benitoite.Release.Refinement.Surface.Property1Interp

/-!
# 性質1の部分適用の補題

部分適用は穴を引数とするラムダに脱糖する（設計書 01-12「表層からの脱糖」の前段）。固定の式はラムダの本体で書いた順に
束縛し、穴はラムダの引数を直接参照する。固定の式は継続を隠した元の文脈で型付け、ラムダの引数の下へ移す。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

/-- 穴を含む引数の固定の式の脱糖を、ソース順に並べる。 -/
noncomputable def fixedComps (op : OpPrim) : HoleArgs → List Comp
  | .nil => []
  | .expr _ _ e rest => desugarExpr op .other e :: fixedComps op rest
  | .hole _ _ _ rest => fixedComps op rest

theorem argEvals_desugarHoleArgs (op : OpPrim) (n : Nat) : (args : HoleArgs) →
    argEvals (desugarHoleArgs op n args) = (fixedComps op args).map (Comp.rename (· + n))
  | .nil => rfl
  | .expr _ _ _ rest => by
    simp [desugarHoleArgs, argEvals, fixedComps, argEvals_desugarHoleArgs op n rest]
  | .hole _ _ _ rest => by
    simp [desugarHoleArgs, argEvals, fixedComps, argEvals_desugarHoleArgs op n rest]

theorem fixedComps_length (op : OpPrim) : (args : HoleArgs) → (fixedComps op args).length = args.fixedCount
  | .nil => rfl
  | .expr _ _ _ rest => by simp [fixedComps, HoleArgs.fixedCount, fixedComps_length op rest]
  | .hole _ _ _ rest => by simp [fixedComps, HoleArgs.fixedCount, fixedComps_length op rest]

theorem argValues_desugarHoleArgs (op : OpPrim) (n m : Nat) : (args : HoleArgs) →
    argValues m (desugarHoleArgs op n args) = args.argVals m
  | .nil => rfl
  | .expr _ _ _ rest => by
    simp [desugarHoleArgs, argValues, HoleArgs.argVals, argValues_desugarHoleArgs op n m rest,
      argEvals_desugarHoleArgs, fixedComps_length]
  | .hole _ _ _ rest => by
    simp [desugarHoleArgs, argValues, HoleArgs.argVals, argValues_desugarHoleArgs op n m rest, Val.rename]

theorem localExtend_nil_lookup : ∀ (n i : Nat) (b : BuilderKind), (localExtend n [])[i]? ≠ some (some b)
  | 0, i, b => by simp [localExtend]
  | n + 1, 0, b => by simp [localExtend, LocalCtx.extend]
  | n + 1, i + 1, b => by
    simp only [localExtend, LocalCtx.extend, List.getElem?_cons_succ, List.getElem?_map]
    intro h
    cases hi : (localExtend n [])[i]? with
    | none => simp [hi] at h
    | some x =>
      cases x with
      | none => simp [hi] at h
      | some y => exact localExtend_nil_lookup n i y hi

/-- 引数だけを束縛した局所の文脈は、構築器を持たない。 -/
theorem localExtend_nil_shift (n : Nat) : LocalCtx.Shift 0 0 (localExtend n []) [] :=
  fun i b h => absurd h (localExtend_nil_lookup n i b)

/-- 計算の列を、ラムダの引数を束縛した文脈へ移す。構築器の文脈は空のまま保つ。 -/
theorem CompsTy.shiftParams {Γ Φ R ms as ε} (hA : Builtins.ValueAssumptions P B)
    (h : CompsTy P B StoreTy.empty Q C Γ Φ R [] ms as ε) (ps : List Ty) :
    CompsTy P B StoreTy.empty Q C (bindParams Γ ps) (liftMany ps.length Φ) (R.map (Ty.shiftV ps.length 0)) []
      (ms.map (Comp.rename (· + ps.length))) (as.map (Ty.shiftV ps.length 0)) (Eff.shiftV ps.length 0 ε) := by
  induction h with
  | nil => exact .nil
  | cons hm _ ih =>
    have hh := hm.shift_values hA storeEmpty_wf (StoreTy.Extends.refl _) (FullShiftMap.outer _ ps)
      (LocalCtx.Shift.outer ps.length []) (facts_under _ _ ps)
    simp only [shiftIndex_add] at hh
    exact .cons (HasTypeCQ.local_zero hh (localExtend_nil_shift _)) ih

theorem holeLam_shift (ns : List String) (ps : List Ty) (r : Ty) (ε : Eff) (body : Comp) :
    holeLam ns ps (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) body = .lam ns ps body := by
  have h : ∃ (r0 : Ty) (e0 : Eff), r.shiftV ps.length 0 = r0.shiftV ps.length 0 ∧
      Eff.shiftV ps.length 0 ε = Eff.shiftV ps.length 0 e0 := ⟨r, ε, rfl, rfl⟩
  unfold holeLam
  simp only [h, ite_true]

theorem holeLam_dependent {ns : List String} {ps : List Ty} {r : Ty} {e : Eff} {body : Comp}
    (h : ¬ ∃ (r0 : Ty) (e0 : Eff), r = r0.shiftV ps.length 0 ∧ e = Eff.shiftV ps.length 0 e0) :
    holeLam ns ps r e body = .dependentLam (holeTel ns ps 0 r e) body := by
  unfold holeLam
  simp only [h, ite_false]

/-- 穴を順に束縛した文脈で型付いた本体は、穴の依存列の本体として型付く。 -/
theorem holeTel_body {Γ0 Φ r e body} : ∀ (pre : List Ty) (ns : List String) (ps : List Ty), ns.length = ps.length →
    HasTypeCQ P B StoreTy.empty Q C (bindParams Γ0 (pre ++ ps)) (liftMany (pre.length + ps.length) Φ) (some r) body r e [] →
    TelBodyTy P B StoreTy.empty Q C (bindParams Γ0 pre) (liftMany pre.length Φ) (holeTel ns ps pre.length r e) body
  | pre, [], [], _, h => .done (by simpa using h)
  | pre, n :: ns, a :: ps, hl, h => by
    refine .param ?_
    have ih := holeTel_body (pre ++ [a]) ns ps (by simpa using hl)
      (by simpa [List.append_assoc, Nat.add_assoc, Nat.add_comm 1] using h)
    rw [bindParams_snoc, List.length_append, List.length_singleton] at ih
    exact ih
  | _, [], _ :: _, hl, _ => by simp at hl
  | _, _ :: _, [], hl, _ => by simp at hl

theorem telBinders_holeTel (r : Ty) (e : Eff) : ∀ (ns : List String) (ps : List Ty) (i : Nat),
    ns.length = ps.length → telBinders (holeTel ns ps i r e) = ps.length
  | [], [], _, _ => rfl
  | _ :: ns, _ :: ps, i, h => by
    simp only [holeTel, telBinders, List.length_cons]
    rw [telBinders_holeTel r e ns ps (i + 1) (by simpa using h)]
  | [], _ :: _, _, h => by simp at h
  | _ :: _, [], _, h => by simp at h

/-- 戻り値型を持たない計算の列は、効果を被覆で広げて任意の戻り値型で読める。 -/
theorem CompsTy.retarget {Γ Φ ms as ε ε'} (h : CompsTy P B StoreTy.empty Q C Γ Φ none [] ms as ε)
    (hc : Eff.Covers Γ Φ ε' ε) (R' : Option Ty) : CompsTy P B StoreTy.empty Q C Γ Φ R' [] ms as ε' := by
  induction h with
  | nil => exact .nil
  | cons hm _ ih => exact .cons (.C_Eff (HasTypeCQ.withReturn hm rfl rfl R') hc) (ih hc)

end Benitoite.Release.Refinement.Surface
