import Benitoite.Surface.Lemmas.Sequence

/-! 構成子の表が等しいプログラム間でのパターンと網羅性。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  theorem PatTy.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
      {pat a δ} (h : PatTy P pat a δ) : PatTy Q pat a δ := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const hf hb hd ho => exact .P_Const hf hb hd ho
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

/-- 既存の単一パターンの分岐は、恒等対応の選択肢として型が付く。 -/
theorem HasArms.single {D B op C Γ R pos pat body rest a b ε εs δ}
    (hv : pat.Valid) (hp : PatTy D.patternProgram pat.toCore a δ)
    (hb : HasBlock D B op C (binds δ ++ Γ) R pos body b ε)
    (hs : HasArms D B op C Γ R pos rest a b εs) :
    HasArms D B op C Γ R pos (Arms.single pat body rest) a b (Eff.union ε εs) := by
  exact .plain (by intro alt hm; simp only [List.mem_singleton] at hm; subst alt; exact hv)
    (PatTy.singleAlt hp) hb hs

/-- 選択肢の型付けは構成子の表だけを読む。 -/
theorem AltsTy.consCongr {P Q : Release.Program} (hc : P.cons = Q.cons)
    {alts a δ} (h : AltsTy P alts a δ) : AltsTy Q alts a δ := by
  refine ⟨h.1, h.2.1, h.2.2.1, ?_⟩
  intro alt hm
  obtain ⟨γ, hp, hs, he⟩ := h.2.2.2 alt hm
  exact ⟨γ, PatTy.consCongr hc hp, hs, he⟩

/-- 束縛の並べ替えは、継続型を含まないという条件を保つ。 -/
theorem AltsTy.clean {P : Release.Program}
    (hw : ∀ c cd, P.cons c = some cd → cd.Scoped)
    {alts a δ n} (h : AltsTy P alts a δ) (ha : TyOK n a) :
    Ty.VarsInList n (fun _ => True) δ := by
  obtain ⟨pat, γ, slots, hp, hs⟩ := h.witness
  have hc := PatTy.clean hw hp ha
  exact Ty.varsInList_of_forall (fun t ht => varsInList_mem hc (selectSlots_mem hs t ht))

/-- 照合対象の let を、最初の選択肢の束縛の外側に挿入する。 -/
theorem HasTypeC.shiftAlts {P B C Γ R m a ε alts t δ}
    (hp : AltsTy P alts t δ)
    (h : HasTypeC P B StoreTy.empty C (binds δ ++ Γ) R m a ε) :
    HasTypeC P B StoreTy.empty C (binds δ ++ some t :: Γ) R
      (m.rename (upRen (Arm.bindersOf alts) (· + 1))) a ε := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.2.1] at hr
  exact h.rename hr

/-- ガードでは同じ付け替えを、継続を隠した二つの環境の間で行う。 -/
theorem HasTypeC.shiftGuard {P B C Γ m alts t δ}
    (hp : AltsTy P alts t δ)
    (h : HasTypeC P B StoreTy.empty C (hideConts (binds δ ++ Γ)) none m (.base .boolean) Eff.empty) :
    HasTypeC P B StoreTy.empty C (hideConts (binds δ ++ some t :: Γ)) none
      (m.rename (upRen (Arm.bindersOf alts) (· + 1))) (.base .boolean) Eff.empty := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.2.1] at hr
  exact h.rename hr.hide

theorem desugarArms_patterns (op : OpPrim) (pos : Position) (arms : Arms) :
    unguardedPats (desugarArms op pos arms) = arms.unguardedPatterns := by
  match arms with
  | .nil => rfl
  | .cons alts guard body rest =>
      cases guard <;> simp only [desugarArms, Arms.unguardedPatterns, unguardedPats,
        desugarArms_patterns op pos rest]

theorem HasTypeC.shiftPattern {P B C Γ R m a ε pat t δ}
    (hp : PatTy P pat t δ)
    (h : HasTypeC P B StoreTy.empty C (binds δ ++ Γ) R m a ε) :
    HasTypeC P B StoreTy.empty C (binds δ ++ some t :: Γ) R
      (m.rename (upRen pat.binders (· + 1))) a ε := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.length_eq] at hr
  exact h.rename hr

end Benitoite.Surface
