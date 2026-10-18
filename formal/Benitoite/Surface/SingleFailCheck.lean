import Benitoite.Surface.NoFailCheck
import Benitoite.Surface.SingleFail

/-! 具体化と合流の後で実行する単一 Fail の判定。有限支持の範囲で型の等号と一致する。 -/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

def singleFailCheck (atoms : List Atom) (q : List Bool) (e : Eff) : Bool :=
  e.fails.all fun t => e.fails.all (fun u => tyEq atoms u t) &&
    noFailCheck atoms q (.mk e.atoms [])

mutual
  def singleTyCheck (atoms : List Atom) (q : List Bool) : Ty → Bool
    | .data _ ts | .tapp _ ts => singleTysCheck atoms q ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => singleTyCheck atoms q t
    | .fn _ ps r e => singleTysCheck atoms q ps && singleTyCheck atoms q r && singleEffCheck atoms q e
    | .cont a b e => singleTyCheck atoms q a && singleTyCheck atoms q b && singleEffCheck atoms q e
    | .map a b => singleTyCheck atoms q a && singleTyCheck atoms q b
    | _ => true
  def singleTysCheck (atoms : List Atom) (q : List Bool) : List Ty → Bool
    | [] => true
    | t :: ts => singleTyCheck atoms q t && singleTysCheck atoms q ts
  def singleEffCheck (atoms : List Atom) (q : List Bool) : Eff → Bool
    | .mk a fs => singleFailCheck atoms q (.mk a fs) && singleTysCheck atoms q fs
end

theorem singleFailCheck_spec {atoms q e} (he : Eff.AtomsIn atoms e) :
    singleFailCheck atoms q e = true ↔ SingleFail (NoFailCtxOf q) e := by
  cases e with
  | mk a fs =>
    have hr : Eff.Support (· ∈ atoms) (.mk a []) := ⟨he.1, trivial⟩
    simp only [singleFailCheck, List.all_eq_true, Bool.and_eq_true]
    constructor
    · intro h t ht
      refine ⟨fun u hu => tyEq_sound (Ty.SupportList.iff.mp he.2 u hu)
        (Ty.SupportList.iff.mp he.2 t ht) ((h t ht).1 u hu), ?_⟩
      exact ((noFailCheck_spec (e := .mk a []) hr.1).mp (h t ht).2).2
    · intro h t ht
      refine ⟨fun u hu => (Finite.tyEq_spec (Ty.SupportList.iff.mp he.2 u hu)
        (Ty.SupportList.iff.mp he.2 t ht)).mpr ((h t ht).1 u hu), ?_⟩
      exact (noFailCheck_spec (e := .mk a []) hr.1).mpr ⟨rfl, (h t ht).2⟩

mutual
  theorem singleTyCheck_spec {atoms q} (t : Ty) (ht : t.AtomsIn atoms) :
      singleTyCheck atoms q t = true ↔ SingleTy (NoFailCtxOf q) t := by
    cases t <;> simp only [Ty.Support] at ht
    all_goals simp only [singleTyCheck, SingleTy, Bool.and_eq_true]
    all_goals first
      | exact iff_of_true rfl trivial
      | exact singleTysCheck_spec _ ht
      | exact singleTyCheck_spec _ ht
      | skip
    case fn ns ps r e =>
      rw [singleTysCheck_spec ps ht.1, singleTyCheck_spec r ht.2.1, singleEffCheck_spec e ht.2.2]
      exact and_assoc
    case cont a b e =>
      rw [singleTyCheck_spec a ht.1, singleTyCheck_spec b ht.2.1, singleEffCheck_spec e ht.2.2]
      exact and_assoc
    case map a b => rw [singleTyCheck_spec a ht.1, singleTyCheck_spec b ht.2]
  theorem singleTysCheck_spec {atoms q} (ts : List Ty) (ht : Tys.AtomsIn atoms ts) :
      singleTysCheck atoms q ts = true ↔ SingleTys (NoFailCtxOf q) ts := by
    cases ts with
    | nil => simp [singleTysCheck, SingleTys]
    | cons t ts =>
      simp only [singleTysCheck, SingleTys, Bool.and_eq_true,
        singleTyCheck_spec t ht.1, singleTysCheck_spec ts ht.2]
  theorem singleEffCheck_spec {atoms q} (e : Eff) (he : e.AtomsIn atoms) :
      singleEffCheck atoms q e = true ↔ SingleEff (NoFailCtxOf q) e := by
    cases e with
    | mk a fs =>
      simp only [singleEffCheck, SingleEff, Bool.and_eq_true,
        singleFailCheck_spec he, singleTysCheck_spec fs he.2]
end

end Benitoite.Surface.CheckTools
