import Benitoite.Surface.Lemmas.Sequence
import Benitoite.Release.Lemmas.Canonical

/-! 呼び出しの共通の型付けと範囲保存。挿入引数はすでに評価された値である。 -/
namespace Benitoite.Surface
open Benitoite.Release

theorem desugarPipeValue {op pos lhs rhs} (h : rhs.PipeValue) :
    desugarExpr op pos (.pipe lhs rhs) = .letIn (desugarExpr op .other lhs)
      (callComp 1 [.var 0] rhs (desugarExpr op .other rhs) []) := by
  cases rhs <;> first | rfl | exact False.elim h

/-- 頭の型付けは、辞書を除いた値引数と呼び出しの結果を表す。
`meth` の引数の型の等式は、`Ty.Le` が最も外側の関数型のエフェクトだけを広げることに依る。
`Ty.Le` を深い部分型に広げるときは、C-Meth の型を `Ty.Le` で広げた形に直す。 -/
inductive CallHead.HasType (P : Release.Program) (B : Builtins) (C : List TParam)
    (Γ : List (Option Ty)) : CallHead → List Ty → Ty → Eff → Prop
  | app {v ds dtys as a ε} :
      HasTypeV P B StoreTy.empty C Γ v (.fn (dtys ++ as) a ε) →
      HasTypeVs P B StoreTy.empty C Γ ds dtys →
      CallHead.HasType P B C Γ (.app v ds) as a ε
  | meth {d cl τ cd m ms ss es us utys as ε} :
      HasTypeV P B StoreTy.empty C Γ d (.dict cl τ) →
      P.classes cl = some cd → cd.methods m = some ms →
      SatAll B C ss ms.tparams → es.length = ms.neffs →
      HasTypeVs P B StoreTy.empty C Γ us utys →
      ms.params.map (Ty.subst (ss ++ [τ]) es) = utys ++ as →
      Eff.Sub (Eff.substRho es ms.eff) ε →
      CallHead.HasType P B C Γ (.meth d m ss es us) as
        (ms.ret.subst (ss ++ [τ]) es) ε

theorem CallHead.HasType.apply {P B C Γ h as a ε R ws}
    (hh : CallHead.HasType P B C Γ h as a ε)
    (hw : HasTypeVs P B StoreTy.empty C Γ ws as) :
    HasTypeC P B StoreTy.empty C Γ R (h.apply ws) a ε := by
  cases hh with
  | app hv hd => exact .C_App hv (hd.append hw)
  | meth hd hc hm ht he hu hp hs =>
      apply HasTypeC.weakenEff (HasTypeC.C_Meth hd hc hm ht he ?_) hs
      rw [hp]; exact hu.append hw

theorem CallHead.HasType.rename {P B C Γ Δ h as a ε ξ}
    (hh : CallHead.HasType P B C Γ h as a ε) (hr : RenOk Γ Δ ξ) :
    CallHead.HasType P B C Δ (h.rename ξ) as a ε := by
  cases hh with
  | app hv hd => exact .app (hv.rename hr) (hd.rename hr)
  | meth hd hc hm ht he hu hp hs => exact .meth (hd.rename hr) hc hm ht he (hu.rename hr) hp hs

theorem CallHead.HasType.weakenEff {P B C Γ h as a ε δ}
    (hh : CallHead.HasType P B C Γ h as a ε) (hs : Eff.Sub ε δ) :
    CallHead.HasType P B C Γ h as a δ := by
  cases hh with
  | app hv hd => exact .app (.V_Sub hv (Or.inr ⟨_, _, _, _, rfl, rfl, hs⟩)) hd
  | meth hd hc hm ht he hu hp heff => exact .meth hd hc hm ht he hu hp (heff.trans hs)

/-- 型とエフェクトの変数の範囲。局所変数の番号は rename が扱う。 -/
def CallHead.Scoped (nt : Nat) (pe : Nat → Prop) : CallHead → Prop
  | .app v ds => Val.VarsIn nt pe v ∧ Val.VarsInList nt pe ds
  | .meth d _ ss es us => Val.VarsIn nt pe d ∧ Ty.VarsInList nt pe ss ∧
      Eff.RhosInList pe es ∧ Val.VarsInList nt pe us

theorem CallHead.Scoped.rename {nt pe} {h : CallHead} (hh : h.Scoped nt pe) (ξ : Nat → Nat) :
    (h.rename ξ).Scoped nt pe := by
  cases h with
  | app v ds => exact ⟨Val.VarsIn.renameScoped _ _ hh.1, Val.VarsInList.renameScoped _ _ hh.2⟩
  | meth d m ss es us => exact ⟨Val.VarsIn.renameScoped _ _ hh.1, hh.2.1, hh.2.2.1,
      Val.VarsInList.renameScoped _ _ hh.2.2.2⟩

theorem CallHead.Scoped.apply {nt pe ws} {h : CallHead} (hh : h.Scoped nt pe)
    (hw : Val.VarsInList nt pe ws) : Comp.VarsIn nt pe (h.apply ws) := by
  cases h with
  | app v ds => exact ⟨hh.1, Val.VarsInList.append hh.2 hw⟩
  | meth d m ss es us => exact ⟨hh.1, hh.2.1, hh.2.2.1, Val.VarsInList.append hh.2.2.2 hw⟩

/-- handled は節の本体を読まないので、脱糖前の操作の並びで計算できる。 -/
theorem desugarClauses_handles (op : OpPrim) (cs : Clauses) (o : OpRef) :
    handles (desugarClauses op cs) o = handles cs.skeleton o := by
  match cs with
  | .nil => rfl
  | .cons _ _ _ _ rest =>
      simpa only [desugarClauses, Clauses.skeleton, handles, List.any_cons, Clause.op] using
        congrArg (fun b => _ || b) (desugarClauses_handles op rest o)

theorem desugarClauses_handled (op : OpPrim) (p : Program) (B : Builtins) (cs : Clauses) :
    handled (desugarProgram op p) B (desugarClauses op cs) =
      handled p.declarations.patternProgram B cs.skeleton := by
  have hh : handles (desugarClauses op cs) = handles cs.skeleton :=
    funext (desugarClauses_handles op cs)
  funext a
  cases a with
  | rho _ => rfl
  | name l =>
      simp only [handled, hh]
      rfl

theorem callComp_typed {P B C Γ R shift inserted f callee ms ps ips a ε εcall}
    (xs : List (Option Ty)) (hlen : xs.length = inserted.length)
    (hf : HasTypeC P B StoreTy.empty C (xs ++ Γ) R (callee.rename (· + shift))
      (.fn (ips ++ ps) a εcall) ε)
    (hd : ∀ h, directCallee f = some h → ∀ ys : List (Option Ty),
      CallHead.HasType P B C (ys ++ xs ++ Γ)
        (h.rename (· + (shift + ys.length))) (ips ++ ps) a εcall)
    (hi : HasTypeVs P B StoreTy.empty C (xs ++ Γ) inserted ips)
    (hms : CompTypes P B C Γ R ε ms ps)
    (hc : Ty.VarsInList C.length (fun _ => True) ps) (he : Eff.Sub εcall ε) :
    HasTypeC P B StoreTy.empty C (xs ++ Γ) R (callComp shift inserted f callee ms) a ε := by
  unfold callComp
  split
  · rename_i h hh
    rw [← hlen]
    apply letChain_typed hms xs
    rw [hms.length]
    apply HasTypeC.weakenEff (δ := ε)
    · apply CallHead.HasType.apply
      · simpa only [binds_length] using hd h hh (binds ps)
      · simpa only [binds_length, List.append_assoc] using
          ((hi.rename (RenOk.shift (binds ps) (xs ++ Γ))).append (boundVars_typed (Γ := xs ++ Γ) hc))
    · exact he
  · apply HasTypeC.C_Let hf
    rw [← hlen]
    have hh := letChain_typed hms (some (.fn (ips ++ ps) a εcall) :: xs) (a := a) (body :=
      .app (.var ms.length) (Val.renameList (· + (ms.length + 1)) inserted ++ boundVars ms.length))
    apply hh
    rw [hms.length]
    apply HasTypeC.weakenEff (δ := ε)
    · apply HasTypeC.C_App (as := ips ++ ps) (ε := εcall)
      · apply HasTypeV.V_Var
        · rw [List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
          simp [binds_length]
        · intro _ _ _ h; cases h
      · apply HasTypeVs.append
        · have hr := hi.rename (RenOk.shift (binds ps ++ [some (.fn (ips ++ ps) a εcall)]) (xs ++ Γ))
          simpa only [List.length_append, binds_length, List.length_singleton,
            List.append_assoc, List.singleton_append, List.cons_append, List.nil_append] using hr
        · simpa only [List.append_assoc, List.cons_append] using
            (boundVars_typed (Γ := some (.fn (ips ++ ps) a εcall) :: (xs ++ Γ)) hc)
    · exact he

theorem callComp_scoped {nt pe shift inserted f callee ms}
    (hf : Comp.VarsIn nt pe callee)
    (hd : ∀ h, directCallee f = some h → h.Scoped nt pe)
    (hi : Val.VarsInList nt pe inserted)
    (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m) :
    Comp.VarsIn nt pe (callComp shift inserted f callee ms) := by
  unfold callComp
  split
  · rename_i h hh
    apply letChain_scoped hm
    exact (CallHead.Scoped.rename (hd h hh) _).apply
      (Val.VarsInList.append (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _))
  · refine ⟨Comp.VarsIn.renameScoped _ callee hf, ?_⟩
    apply letChain_scoped hm
    exact ⟨trivial,
      Val.VarsInList.append (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _)⟩

end Benitoite.Surface
