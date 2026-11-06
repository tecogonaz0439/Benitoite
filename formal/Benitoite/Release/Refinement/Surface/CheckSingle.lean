import Benitoite.Release.Refinement.Surface.CheckAdmissible

/-! 型の全ての子で、具体化した Fail の型と署名由来の行を検査する
（設計書 01-12「型付きの失敗の表層検査」）。 -/
namespace Benitoite.Release.Refinement.Surface
def SingleFail (Q : NoFailCtx) (e : Eff) : Prop :=
  ∀ t ∈ e.fails, (∀ u ∈ e.fails, u.norm = t.norm) ∧ ∀ i, e.test (.rho i) = true → Q i

mutual
  def SingleTy (Q : NoFailCtx) : Ty → Prop
    | .data _ ts | .tapp _ ts | .external _ ts => SingleTys Q ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t | .refined t _ => SingleTy Q t
    | .fn _ ps r e => SingleTys Q ps ∧ SingleTy Q r ∧ SingleEff Q e
    | .cont a b e => SingleTy Q a ∧ SingleTy Q b ∧ SingleEff Q e
    | .map a b => SingleTy Q a ∧ SingleTy Q b
    | .dependentFn t => SingleTel Q t
    | _ => True
  def SingleTel (Q : NoFailCtx) : Tel → Prop
    | .done r e => SingleTy Q r ∧ SingleEff Q e
    | .param _ a t => SingleTy Q a ∧ SingleTel Q t
  def SingleTys (Q : NoFailCtx) : List Ty → Prop
    | [] => True
    | t :: ts => SingleTy Q t ∧ SingleTys Q ts
  def SingleEff (Q : NoFailCtx) : Eff → Prop
    | .mk a fs => SingleFail Q (.mk a fs) ∧ SingleTys Q fs
end


namespace CheckSingle
open CheckCompare CheckAdmissible
def singleFailCheck (atoms : List Atom) (q : List Bool) (e : Eff) : Bool :=
  e.fails.all fun t => e.fails.all (fun u => normTyEq atoms u t) &&
    noFailCheck atoms q (.mk e.atoms [])

mutual
  def singleTyCheck (atoms : List Atom) (q : List Bool) : Ty → Bool
    | .data _ ts | .tapp _ ts | .external _ ts => singleTysCheck atoms q ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t | .refined t _ => singleTyCheck atoms q t
    | .fn _ ps r e => singleTysCheck atoms q ps && singleTyCheck atoms q r && singleEffCheck atoms q e
    | .cont a b e => singleTyCheck atoms q a && singleTyCheck atoms q b && singleEffCheck atoms q e
    | .map a b => singleTyCheck atoms q a && singleTyCheck atoms q b
    | .dependentFn t => singleTelCheck atoms q t
    | _ => true
  def singleTelCheck (atoms : List Atom) (q : List Bool) : Tel → Bool
    | .done r e => singleTyCheck atoms q r && singleEffCheck atoms q e
    | .param _ a t => singleTyCheck atoms q a && singleTelCheck atoms q t
  def singleTysCheck (atoms : List Atom) (q : List Bool) : List Ty → Bool
    | [] => true
    | t :: ts => singleTyCheck atoms q t && singleTysCheck atoms q ts
  def singleEffCheck (atoms : List Atom) (q : List Bool) : Eff → Bool
    | .mk a fs => singleFailCheck atoms q (.mk a fs) && singleTysCheck atoms q fs
end

theorem singleFailCheck_spec {atoms q e} (he : e.Support (· ∈ atoms)) :
    singleFailCheck atoms q e = true ↔ SingleFail (NoFailCtxOf q) e := by
  cases e with
  | mk a fs =>
    have hr : Eff.Support (· ∈ atoms) (.mk a []) := ⟨he.1, trivial⟩
    simp only [singleFailCheck, List.all_eq_true, Bool.and_eq_true]
    constructor
    · intro h t ht
      refine ⟨fun u hu => (normTyEq_spec (Ty.SupportList.iff.mp he.2 u hu)
        (Ty.SupportList.iff.mp he.2 t ht)).mp ((h t ht).1 u hu), ?_⟩
      exact ((noFailCheck_spec (e := .mk a []) hr.1).mp (h t ht).2).2
    · intro h t ht
      refine ⟨fun u hu => (normTyEq_spec (Ty.SupportList.iff.mp he.2 u hu)
        (Ty.SupportList.iff.mp he.2 t ht)).mpr ((h t ht).1 u hu), ?_⟩
      exact (noFailCheck_spec (e := .mk a []) hr.1).mpr ⟨rfl, (h t ht).2⟩

mutual
  theorem singleTyCheck_spec {atoms q} (t : Ty) (ht : t.Support (· ∈ atoms)) :
      singleTyCheck atoms q t = true ↔ SingleTy (NoFailCtxOf q) t := by
    cases t <;> simp only [Ty.Support] at ht
    all_goals simp only [singleTyCheck, SingleTy, Bool.and_eq_true]
    all_goals first
      | exact iff_of_true rfl trivial
      | exact singleTysCheck_spec _ ht
      | exact singleTyCheck_spec _ ht
      | skip
    case dependentFn t => exact singleTelCheck_spec t ht
    case fn ns ps r e =>
      rw [singleTysCheck_spec ps ht.1, singleTyCheck_spec r ht.2.1, singleEffCheck_spec e ht.2.2]
      exact and_assoc
    case cont a b e =>
      rw [singleTyCheck_spec a ht.1, singleTyCheck_spec b ht.2.1, singleEffCheck_spec e ht.2.2]
      exact and_assoc
    case map a b => rw [singleTyCheck_spec a ht.1, singleTyCheck_spec b ht.2]
  theorem singleTelCheck_spec {atoms q} (t : Tel) (ht : t.Support (· ∈ atoms)) :
      singleTelCheck atoms q t = true ↔ SingleTel (NoFailCtxOf q) t := by
    cases t with
    | done r e => simp only [singleTelCheck, SingleTel, Bool.and_eq_true,
        singleTyCheck_spec r ht.1, singleEffCheck_spec e ht.2]
    | param n a t => simp only [singleTelCheck, SingleTel, Bool.and_eq_true,
        singleTyCheck_spec a ht.1, singleTelCheck_spec t ht.2]
  theorem singleTysCheck_spec {atoms q} (ts : List Ty) (ht : Ty.SupportList (· ∈ atoms) ts) :
      singleTysCheck atoms q ts = true ↔ SingleTys (NoFailCtxOf q) ts := by
    cases ts with
    | nil => simp [singleTysCheck, SingleTys]
    | cons t ts =>
      simp only [singleTysCheck, SingleTys, Bool.and_eq_true,
        singleTyCheck_spec t ht.1, singleTysCheck_spec ts ht.2]
  theorem singleEffCheck_spec {atoms q} (e : Eff) (he : e.Support (· ∈ atoms)) :
      singleEffCheck atoms q e = true ↔ SingleEff (NoFailCtxOf q) e := by
    cases e with
    | mk a fs =>
      simp only [singleEffCheck, SingleEff, Bool.and_eq_true,
        singleFailCheck_spec he, singleTysCheck_spec fs he.2]
end


end CheckSingle
end Benitoite.Release.Refinement.Surface
