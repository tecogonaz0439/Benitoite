import Production

namespace P4.Cases
open Benitoite.Release
open Benitoite.Scope.Domain (Target)
open Production
set_option maxHeartbeats 400000

-- none の束縛と経路条件を含む Γ;Φ を、閉じた値の文脈へ実際に置換する。
def sourceTy : RefTy := ⟨.base .integer, withinTen⟩
def targetTy : RefTy := ⟨.base .integer, .and withinTen .truth⟩
def sourceΓ : Ctx := [none, some sourceTy]
def sourceΦ : List Pred := [.le (.lit (.int 0)) (.var 1)]

def values : Nat → Term
  | 1 => .lit (.int 7)
  | i => .var i

variable (P : Program) (B : Builtins) (Ψ : StoreTy) (parse : String → Option Target)

theorem open_V_Sub : Typed (Native P B Ψ parse) sourceΓ sourceΦ (.var 1) targetTy := by
  apply Typed.V_Sub (a := sourceTy)
  · exact .var rfl
  · apply Le.refine (a := sourceTy) (b := targetTy) (Ty.Le.refl _)
    exact .and_intro (.hyp (by simp [sourceTy])) .truth

theorem closed_V_Sub : Typed (Native P B Ψ parse) [] [] (.lit (.int 7)) (targetTy.bind values) := by
  apply (open_V_Sub P B Ψ parse).subst [] [] values
  · intro i a hi
    cases i with
    | zero => simp [sourceΓ] at hi
    | succ i =>
        cases i with
        | zero =>
            have he : sourceTy = a := Option.some.inj (Option.some.inj hi)
            subst a
            exact int_refined P B Ψ parse
        | succ => simp [sourceΓ] at hi
  · intro p hp
    have he : p = .le (.lit (.int 0)) (.var 1) := List.mem_singleton.mp hp
    subst p
    exact .integer (by decide)

theorem moved_V_Sub (bound : RefTy) :
    Typed (Native P B Ψ parse) (sourceΓ.extend bound) (sourceΦ.map Pred.lift)
      (.var 2) (targetTy.bind (fun i => .var (i+1))) :=
  (open_V_Sub P B Ψ parse).shift bound

theorem sourceΓ_wf : sourceΓ.WF 0 0 := by
  intro i a hi
  cases i with
  | zero => simp [sourceΓ] at hi
  | succ i =>
      cases i with
      | zero =>
          have he : sourceTy = a := Option.some.inj (Option.some.inj hi)
          subst a
          simp [sourceTy, RefTy.WF, sourceΓ, withinTen, Pred.WF, Term.WF, Ty.WF]
      | succ => simp [sourceΓ] at hi

-- Γ の埋め込みの事実は、閉じた型付き像の canonical forms から得る。
def runtimeValues : Nat → Value
  | 1 => .int 7
  | _ => .other

include P B Ψ in
theorem embedded_source : Satisfies parse runtimeValues sourceΓ.facts := by
  apply closed_embedding (Native := Native P B Ψ parse) sourceΓ runtimeValues
  intro i a hi
  cases i with
  | zero => simp [sourceΓ] at hi
  | succ i =>
      cases i with
      | zero =>
          have he : sourceTy = a := Option.some.inj (Option.some.inj hi)
          subst a
          exact int_refined P B Ψ parse
      | succ => simp [sourceΓ] at hi

include P B in
theorem list_source_predicate (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) (ρ : Nat → Value) :
    (Pred.le (.lit (.int (-1))) (.length (.var 0))).Holds parse
      (extend ρ (.list [.reference l])) :=
  (M6.relaxed_length_correct (.var 0) parse _).mp (checked_list_canonical P B Ψ parse l hl ρ)

-- 不正な含意を「規則を登録したから」という理由で認めない。
theorem bad_integer_not_entailed : ¬ Entails [] (.le (.lit (.int 1)) (.lit (.int 0))) := by
  intro h
  obtain ⟨x, y, hx, hy, hxy⟩ := h.sound (fun _ => none) (fun _ => .other) (by simp [Satisfies])
  have hxx : (1 : Int) = x := Value.int.inj (Option.some.inj hx)
  have hyy : (0 : Int) = y := Value.int.inj (Option.some.inj hy)
  omega

-- 欄の番号だけ合っても、名目の data が違えば射影を認めない。
example (ρ : Nat → Value) :
    Term.eval ρ (.field "Other" "MkPoint" 0 (.lit (.con "Point" "MkPoint" [.int 7]))) = none := rfl

-- 型と行の像が値を参照する。束縛の下へ入れる際は、その値変数も移動する。
def dependentImages : Derivation.Sub where
  types _ := .refined (.native (.base .integer)) (.eq (.var 0) (.var 1))
  rows _ := .fail (.refined (.native (.base .integer)) (.eq (.var 0) (.var 1)))
  ranges _ := .fixed .top
  values := Term.var

example : dependentImages.up.types 0 =
    .refined (.native (.base .integer)) (.eq (.var 0) (.var 2)) := rfl
example : dependentImages.up.rows 0 =
    .fail (.refined (.native (.base .integer)) (.eq (.var 0) (.var 2))) := rfl

-- if の分岐で束縛の下へ追加した条件も、その束縛を保って置換する。
example (Φ : List Pred) (p : Pred) (σ : Nat → Term) :
    (branchFacts Φ p).map (Pred.bind (upSub σ)) =
      branchFacts (Φ.map (Pred.bind σ)) (p.bind (upSub σ)) := branchFacts_bind σ Φ p

#print axioms closed_V_Sub
#print axioms moved_V_Sub
#print axioms sourceΓ_wf
#print axioms embedded_source
#print axioms list_source_predicate
#print axioms bad_integer_not_entailed
end P4.Cases
