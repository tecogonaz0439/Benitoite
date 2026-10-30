import Benitoite

/-!
公開する構文と補助契約の境界の局所照合。閉じた評価・主定理の検査とは分ける。
-/
namespace Benitoite.Release.Refinement.L00b02aBoundary

-- None と継続は snapshot の内側からも参照できない。
theorem no_none_snapshot :
    ¬ (Term.listValue [some (.var 0)]).HasSort [none] .list := by
  rintro ⟨h, _⟩
  obtain ⟨a, ha, _⟩ := h.1
  cases ha

theorem no_cont_snapshot (b t : Ty) (e : Eff) :
    ¬ (Term.listValue [some (.var 0)]).HasSort [some (.cont b t e)] .list := by
  rintro ⟨h, _⟩
  obtain ⟨a, ha, ho⟩ := h.1
  have he : a = .cont b t e := Option.some.inj (Option.some.inj ha.symm)
  exact ho b t e he

-- sort のない関数型の位置は参照できる。消える像はスロットの none にする。
theorem function_snapshot :
    (Term.listValue [some (.var 0)]).HasSort
      [some (.fn [] [] (.base .unit) Eff.empty)] .list := by
  exact ⟨⟨⟨_, rfl, by simp [Ordinary]⟩, trivial⟩, rfl⟩

theorem missing_image_preserves_slot :
    termBind (fun _ => none) (.listValue [none, some (.var 0)]) = .listValue [none, none] := rfl

theorem self_preserved_when_outer_missing :
    termBind (upValues (fun _ => none)) (.listValue [some (.var 0), some (.var 1)]) =
      .listValue [some (.var 0), none] := rfl

-- 数値の観測を、整数への暗黙変換にしない。
theorem float_not_integer (Γ : Ctx) (bits : UInt64) : ¬ (Term.float64 bits).HasSort Γ .integer := by
  rintro ⟨_, h⟩
  cases h

theorem character_not_integer (Γ : Ctx) (c : Char) : ¬ (Term.character c).HasSort Γ .integer := by
  rintro ⟨_, h⟩
  cases h

-- 宣言表にない欄と、ctor でない構成子像は信用しない。
theorem missing_field {P : Program} {C : List TParam} {Γ : Ctx} {receiver : Term} {ref : FieldRef} (hm : P.cons ref.constructor = none) :
    ¬ FieldRef.Declared P C Γ receiver ref := by
  rintro ⟨_, cd, _, _, hc, _⟩
  rw [hm] at hc
  cases hc

theorem refined_not_constructor (P : Program) (K : KindCtx) (a : Ty) (p : Pred) (n : Nat) :
    ¬ (Ty.refined a p).HasKind P K (.constructor n) := id

-- 二つの既存引数の下で、元の外側の var 0 を var 2 として読む。
theorem old_function_outer_reference :
    Ty.toTel ["x", "y"] [.base .integer, .base .unit]
      (.refined (.base .integer) (.eq (.var 0) (.var 1))) Eff.empty =
      .param "x" (.base .integer) (.param "y" (.base .unit)
        (.done (.refined (.base .integer) (.eq (.var 0) (.var 3))) Eff.empty)) := rfl

end Benitoite.Release.Refinement.L00b02aBoundary
