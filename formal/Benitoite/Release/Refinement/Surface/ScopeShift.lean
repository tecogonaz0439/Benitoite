import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.TypeSupport
import Benitoite.Release.Refinement.TypeVariables
import Benitoite.Release.Refinement.TypeRows

/-!
# ソースの有効範囲と値の束縛の挿入

値の名前空間に束縛を挿入した計算は、同じ範囲・型・行の上限と、挿入した数だけ増えた値の上限でソースの有効範囲を持つ
（設計書 07-04「01-12 との対応」）。脱糖が部分式を let の下へ移す操作に使う。
-/

namespace Benitoite.Release.Refinement

theorem Ty.SourceScoped.shiftV {nr nt ne nv a} (h : Ty.SourceScoped nr nt ne nv a) (k c : Nat) :
    (a.shiftV k c).SourceScoped nr nt ne (nv + k) := by
  obtain ⟨hw, hr, hs⟩ := h
  have hw' := Ty.wf_shiftV hw k c
  refine ⟨hw', ?_, ?_⟩
  · exact (Ty.rowsIn_iff_support _ _).mpr ((Ty.support_shiftV_iff _ a k c).mpr ((Ty.rowsIn_iff_support _ _).mp hr))
  · exact (Ty.rangesScoped_iff_support _ hw').mpr ((Ty.support_shiftV_iff _ a k c).mpr
      ((Ty.rangesScoped_iff_support _ hw).mp hs))

theorem Eff.SourceScoped.shiftV {nr nt ne nv e} (h : Eff.SourceScoped nr nt ne nv e) (k c : Nat) :
    (Eff.shiftV k c e).SourceScoped nr nt ne (nv + k) := by
  obtain ⟨hw, hr, hs⟩ := h
  have hw' := Eff.wf_shiftV hw k c
  refine ⟨hw', ?_, ?_⟩
  · exact (Eff.rowsIn_iff_support _ _).mpr ((Eff.support_shiftV_iff _ e k c).mpr ((Eff.rowsIn_iff_support _ _).mp hr))
  · exact (Eff.rangesScoped_iff_support _ hw').mpr ((Eff.support_shiftV_iff _ e k c).mpr
      ((Eff.rangesScoped_iff_support _ hw).mp hs))

theorem scopedTypes_shiftV {nr nt ne nv k c} : ∀ {ts : List Ty}, scopedTypes nr nt ne nv ts →
    scopedTypes nr nt ne (nv + k) (ts.map (renameTy (shiftIndex k c)))
  | [], _ => trivial
  | t :: ts, h => ⟨by rw [renameTy_shiftIndex]; exact h.1.shiftV k c, scopedTypes_shiftV h.2⟩

theorem scopedRows_shiftV {nr nt ne nv k c} : ∀ {es : List Eff}, scopedRows nr nt ne nv es →
    scopedRows nr nt ne (nv + k) (es.map (renameEff (shiftIndex k c)))
  | [], _ => trivial
  | e :: es, h => ⟨by rw [renameEff_shiftIndex]; exact h.1.shiftV k c, scopedRows_shiftV h.2⟩

theorem BuilderKind.SourceScoped.shiftV {nr nt ne nv b} (h : BuilderKind.SourceScoped nr nt ne nv b) (k c : Nat) :
    (renameKind (shiftIndex k c) b).SourceScoped nr nt ne (nv + k) := by
  cases b with
  | list a => simpa [renameKind, BuilderKind.SourceScoped, renameTy_shiftIndex] using Ty.SourceScoped.shiftV h k c
  | string | bytes => trivial

theorem telBinders_shiftV : (t : Tel) → (k c : Nat) → telBinders (Tel.shiftV k c t) = telBinders t
  | .done _ _, _, _ => rfl
  | .param _ _ t, k, c => by simp only [Tel.shiftV, telBinders, telBinders_shiftV t k (c + 1)]

theorem shiftIndex_lt {k c nv i} (h : i < nv) : shiftIndex k c i < nv + k := by
  unfold shiftIndex; split <;> omega

mutual
  theorem Val.SourceScoped.shift {nr ne k : Nat} : ∀ {nt nv c : Nat} {v : Val}, c ≤ nv → v.SourceScoped nr nt ne nv →
      (v.rename (shiftIndex k c)).SourceScoped nr nt ne (nv + k)
    | _, _, _, .var _, _, h => shiftIndex_lt h
    | _, _, _, .const _, _, h | _, _, _, .bytesV _, _, h => h
    | _, _, _, .fnRef _ _ _ _, _, h => ⟨scopedTypes_shiftV h.1, scopedRows_shiftV h.2.1, h.2.2⟩
    | _, _, _, .prim _ _ _ _, _, h => ⟨scopedTypes_shiftV h.1, scopedRows_shiftV h.2.1, h.2.2⟩
    | _, nv, c, .lam ns ps body, hc, h => by
        refine ⟨⟨by simpa using h.1.1, h.1.2⟩, scopedTypes_shiftV h.2.1, ?_⟩
        have hb := Comp.SourceScoped.shift (k := k) (nv := nv + ps.length) (c := c + ps.length) (by omega) h.2.2
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm] using hb
    | _, nv, c, .dependentLam t body, hc, h => by
        refine ⟨?_, ?_⟩
        · have := Ty.SourceScoped.shiftV h.1 k c
          simpa [Ty.shiftV, Tel.shiftV_eq_rawBind] using this
        · have hb := Comp.SourceScoped.shift (k := k) (nv := nv + telBinders t) (c := c + telBinders t) (by omega) h.2
          rw [upRen_shiftIndex, show telBinders (Tel.rawBind (renEnv (shiftIndex k c)) t) = telBinders t by
            rw [← Tel.shiftV_eq_rawBind]; exact telBinders_shiftV t k c]
          simpa [Nat.add_right_comm] using hb
    | _, _, _, .con _ _ vs, hc, h | _, _, _, .dict _ _ vs, hc, h => ⟨scopedTypes_shiftV h.1, scopedValues.shift hc h.2⟩
    | _, _, _, .list _, hc, h | _, _, _, .setV _, hc, h => scopedValues.shift hc h
    | _, _, _, .op _ _, _, h | _, _, _, .externalRef _ _, _, h => scopedTypes_shiftV h
    | _, _, _, .raise _ _, _, h => ⟨by rw [renameTy_shiftIndex]; exact h.1.shiftV k _,
        by rw [renameTy_shiftIndex]; exact h.2.shiftV k _⟩
    | _, _, _, .mapV _ _, hc, h => ⟨scopedValues.shift hc h.1, scopedValues.shift hc h.2⟩
    | _, _, _, .super v _, hc, h => Val.SourceScoped.shift (v := v) hc h
    | _, _, _, .scopePattern _, _, h => h
    | _, _, _, .closure _ _, _, h | _, _, _, .loc _, _, h | _, _, _, .externalHandle _ _, _, h | _, _, _, .pathBases _, _, h
    | _, _, _, .checkedAt _ _ _ _, _, h | _, _, _, .atError _, _, h | _, _, _, .checked _, _, h
    | _, _, _, .checkedRequest _ _, _, h => h.elim
  theorem scopedValues.shift {nr ne k : Nat} : ∀ {nt nv c : Nat} {vs : List Val}, c ≤ nv →
      scopedValues nr nt ne nv vs → scopedValues nr nt ne (nv + k) (Val.renameList (shiftIndex k c) vs)
    | _, _, _, [], _, _ => trivial
    | _, _, _, v :: vs, hc, h => ⟨Val.SourceScoped.shift (v := v) hc h.1, scopedValues.shift (vs := vs) hc h.2⟩
  theorem Comp.SourceScoped.shift {nr ne k : Nat} : ∀ {nt nv c : Nat} {m : Comp}, c ≤ nv → m.SourceScoped nr nt ne nv →
      (m.rename (shiftIndex k c)).SourceScoped nr nt ne (nv + k)
    | _, nv, c, .builderLet kd body, hc, h => by
        refine ⟨h.1.shiftV k c, ?_⟩
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (m := body) (nv := nv + 1) (c := c + 1) (by omega) h.2
    | _, _, _, .builderOp _ _ r _, hc, h => by
        refine ⟨h.1.shiftV k _, ?_, scopedValues.shift hc h.2.2⟩
        cases r with
        | bound i => exact shiftIndex_lt h.2.1
        | loc _ => exact h.2.1.elim
    | _, _, _, .ret v, hc, h | _, _, _, .escape v, hc, h => Val.SourceScoped.shift (v := v) hc h
    | _, nv, c, .letIn m n, hc, h => by
        refine ⟨Comp.SourceScoped.shift (m := m) hc h.1, ?_⟩
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (m := n) (nv := nv + 1) (c := c + 1) (by omega) h.2
    | _, _, _, .app v vs, hc, h => ⟨Val.SourceScoped.shift (v := v) hc h.1, scopedValues.shift hc h.2⟩
    | _, _, _, .ite v m n, hc, h => ⟨Val.SourceScoped.shift (v := v) hc h.1, Comp.SourceScoped.shift (m := m) hc h.2.1,
        Comp.SourceScoped.shift (m := n) hc h.2.2⟩
    | _, _, _, .match v arms, hc, h => ⟨Val.SourceScoped.shift (v := v) hc h.1, scopedArms.shift (arms := arms) hc h.2⟩
    | _, _, _, .lazyC m, hc, h => Comp.SourceScoped.shift (m := m) hc h
    | _, _, _, .use v m, hc, h => ⟨Val.SourceScoped.shift (v := v) hc h.1, Comp.SourceScoped.shift (m := m) hc h.2⟩
    | _, _, _, .handle m cs, hc, h => ⟨Comp.SourceScoped.shift (m := m) hc h.1, scopedClauses.shift (cs := cs) hc h.2⟩
    | _, _, _, .resume kv v, hc, h => ⟨Val.SourceScoped.shift (v := kv) hc h.1, Val.SourceScoped.shift (v := v) hc h.2⟩
    | _, _, _, .externalCall _ _ vs, hc, h => ⟨scopedTypes_shiftV h.1, scopedValues.shift hc h.2⟩
    | _, _, _, .issuePathBases _, _, h => h.elim
    | _, _, _, .checkAt _ _ sh none p v ix, hc, h => by
        simp only [Comp.rename, Comp.SourceScoped] at h ⊢
        exact ⟨by rw [renameTy_shiftIndex]; exact h.1.shiftV k _, h.2.1, trivial,
          Val.SourceScoped.shift (v := p) hc h.2.2.2.1, Val.SourceScoped.shift (v := v) hc h.2.2.2.2⟩
    | _, _, _, .checkAt _ _ sh (some b) p v ix, hc, h => by
        simp only [Comp.rename, Comp.SourceScoped] at h ⊢
        exact ⟨by rw [renameTy_shiftIndex]; exact h.1.shiftV k _, h.2.1, Val.SourceScoped.shift (v := b) hc h.2.2.1,
          Val.SourceScoped.shift (v := p) hc h.2.2.2.1, Val.SourceScoped.shift (v := v) hc h.2.2.2.2⟩
    | _, _, _, .meth d _ _ _ vs, hc, h => ⟨Val.SourceScoped.shift (v := d) hc h.1, scopedTypes_shiftV h.2.1,
        scopedRows_shiftV h.2.2.1, scopedValues.shift hc h.2.2.2⟩
  theorem scopedArms.shift {nr ne k : Nat} : ∀ {nt nv c : Nat} {arms : List Arm}, c ≤ nv →
      scopedArms nr nt ne nv arms → scopedArms nr nt ne (nv + k) (Arm.renameList (shiftIndex k c) arms)
    | _, _, _, [], _, _ => trivial
    | _, nv, c, .mk alts none body :: arms, hc, h => by
        refine ⟨trivial, ?_, scopedArms.shift (arms := arms) hc h.2.2⟩
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (m := body)
          (nv := nv + Benitoite.Release.Arm.bindersOf alts) (c := c + Benitoite.Release.Arm.bindersOf alts) (by omega) h.2.1
    | _, nv, c, .mk alts (some g) body :: arms, hc, h => by
        refine ⟨?_, ?_, scopedArms.shift (arms := arms) hc h.2.2⟩
        · rw [upRen_shiftIndex]
          simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (m := g)
            (nv := nv + Benitoite.Release.Arm.bindersOf alts) (c := c + Benitoite.Release.Arm.bindersOf alts) (by omega) h.1
        · rw [upRen_shiftIndex]
          simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (m := body)
            (nv := nv + Benitoite.Release.Arm.bindersOf alts) (c := c + Benitoite.Release.Arm.bindersOf alts) (by omega) h.2.1
  theorem scopedClauses.shift {nr ne k : Nat} : ∀ {nt nv c : Nat} {cs : List Clause}, c ≤ nv →
      scopedClauses nr nt ne nv cs → scopedClauses nr nt ne (nv + k) (Clause.renameList (shiftIndex k c) cs)
    | _, _, _, [], _, _ => trivial
    | nt, nv, c, .mk _ n ntys body :: cs, hc, h => by
        refine ⟨?_, scopedClauses.shift (cs := cs) hc h.2⟩
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm, Nat.add_assoc] using Comp.SourceScoped.shift (k := k) (m := body) (nt := nt + ntys)
          (nv := nv + n + 1) (c := c + (n + 1)) (by omega) h.1
    | _, nv, c, .fail e body :: cs, hc, h => by
        refine ⟨by rw [renameTy_shiftIndex]; exact h.1.shiftV k _, ?_, scopedClauses.shift (cs := cs) hc h.2.2⟩
        rw [upRen_shiftIndex]
        simpa [Nat.add_right_comm] using Comp.SourceScoped.shift (k := k) (m := body) (nt := _ + 1) (nv := nv + 2)
          (c := c + 2) (by omega) h.2.1
end

end Benitoite.Release.Refinement
