import Benitoite.Surface.Lemmas.Sequence

/-! 文の束縛のパターンと環境の移動（設計書 01-12「ブロック」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

mutual
  theorem PatTy.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {pat a δ} (h : PatTy P pat a δ) : PatTy Q pat a δ := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const h => exact .P_Const h
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List hb ha hn => exact .P_List (PatTys.consCongr hc hb) (PatTys.consCongr hc ha) hn
    | .P_Con hd ht hs => exact .P_Con (by simpa only [← hc] using hd) ht (PatTys.consCongr hc hs)

  theorem PatTys.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {ps as δ} (h : PatTys P ps as δ) : PatTys Q ps as δ := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (PatTy.consCongr hc h) (PatTys.consCongr hc hs)
end

mutual
  theorem Inhabits.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {a v} (h : Inhabits P a v) : Inhabits Q a v := by
    match h with
    | .const => exact .const
    | .con hd ht hs => exact .con (by simpa only [← hc] using hd) ht (InhabitsAll.consCongr hc hs)
    | .list hs => exact .list (InhabitsEach.consCongr hc hs)
    | .fn => exact .fn
    | .tvar => exact .tvar
    | .reference => exact .reference
    | .lazy => exact .lazy
    | .cont => exact .cont
    | .map => exact .map
    | .set => exact .set
    | .bytes => exact .bytes
    | .dict => exact .dict
    | .tapp => exact .tapp
    | .ctor => exact .ctor

  theorem InhabitsAll.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {as vs} (h : InhabitsAll P as vs) : InhabitsAll Q as vs := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (Inhabits.consCongr hc h) (InhabitsAll.consCongr hc hs)

  theorem InhabitsEach.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {a vs} (h : InhabitsEach P a vs) : InhabitsEach Q a vs := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (Inhabits.consCongr hc h) (InhabitsEach.consCongr hc hs)
end

theorem Exhaustive.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
    {a ps} (h : Exhaustive P a ps) : Exhaustive Q a ps := by
  intro v hv
  exact h v (Inhabits.consCongr hc.symm hv)

theorem HasTypeCQ.shiftPattern {P B C Γ R m a ε pat t δ}
    (hp : PatTy P pat t δ)
    (h : HasTypeCQ P B StoreTy.empty Q C (binds δ ++ Γ) R m a ε) :
    HasTypeCQ P B StoreTy.empty Q C (binds δ ++ some t :: Γ) R
      (m.rename (upRen pat.binders (· + 1))) a ε := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.length_eq] at hr
  exact h.rename hr


end Benitoite.Surface
