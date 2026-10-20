import Benitoite.Surface.Lemmas.PatternSupport

/-! 分岐の選択肢とガードの型保存（設計書 01-12「リスト、ラムダ、条件分岐、match」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx} {Δl : LocalCtx}

/-- 既存の単一パターンの分岐は、恒等対応の選択肢として型が付く。 -/
theorem HasArmsQ.single {Δb : BuilderCtx} {D B op C Γ R pos pat body rest a b ε εs δ}
    (hv : pat.Valid) (hp : PatTy D.patternProgram pat.toCore a δ)
    (hb : HasBlockQ D B op Q (List.replicate δ.length none ++ Δb) C (binds δ ++ Γ) R pos body b ε)
    (hs : HasArmsQ D B op Q Δb C Γ R pos rest a b εs) :
    HasArmsQ D B op Q Δb C Γ R pos (Arms.single pat body rest) a b (Eff.union ε εs) := by
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
theorem HasTypeCQ.shiftAlts {P B C Γ R m a ε alts t δ}
    (hp : AltsTy P alts t δ)
    (h : HasTypeCQ P B StoreTy.empty Q C (binds δ ++ Γ) R m a ε (LocalCtx.extend δ.length Δl)) :
    HasTypeCQ P B StoreTy.empty Q C (binds δ ++ some t :: Γ) R
      (m.rename (upRen (Arm.bindersOf alts) (· + 1))) a ε (LocalCtx.extend δ.length (LocalCtx.extend 1 Δl)) := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.2.1] at hr
  exact h.rename hr _ (by simpa only [hp.2.1, binds_length, List.length_cons, List.length_nil] using (LocalRenOk.shift Δl 1).extend δ.length)

/-- ガードでは同じ付け替えを、継続を隠した二つの環境の間で行う。 -/
theorem HasTypeCQ.shiftGuard {P B C Γ m alts t δ}
    (hp : AltsTy P alts t δ)
    (h : HasTypeCQ P B StoreTy.empty Q C (hideConts (binds δ ++ Γ)) none m (.base .boolean) Eff.empty (LocalCtx.extend δ.length Δl)) :
    HasTypeCQ P B StoreTy.empty Q C (hideConts (binds δ ++ some t :: Γ)) none
      (m.rename (upRen (Arm.bindersOf alts) (· + 1))) (.base .boolean) Eff.empty (LocalCtx.extend δ.length (LocalCtx.extend 1 Δl)) := by
  have hr := (RenOk.shift [some t] Γ).up (binds δ)
  rw [binds_length, hp.2.1] at hr
  exact h.rename hr.hide _ (by simpa only [hp.2.1, binds_length, List.length_cons, List.length_nil] using (LocalRenOk.shift Δl 1).extend δ.length)

theorem desugarArms_patterns (op : OpPrim) (pos : Position) (arms : Arms) :
    unguardedPats (desugarArms op pos arms) = arms.unguardedPatterns := by
  match arms with
  | .nil => rfl
  | .cons alts guard body rest =>
      cases guard <;> simp only [desugarArms, Arms.unguardedPatterns, unguardedPats,
        desugarArms_patterns op pos rest]

end Benitoite.Surface
