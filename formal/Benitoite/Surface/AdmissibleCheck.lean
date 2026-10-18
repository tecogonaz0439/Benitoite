import Benitoite.Surface.NoFailCheck
import Benitoite.Surface.CheckPredicates
import Benitoite.Release.Admissible

/-!
# 呼び出しの型と行の具体化の検査

署名の行の範囲と Q をともに検査する。有限支持の外の原子を見落とさないため、
判定の健全性は既存の AtomsIn を要求する。通常の型制約と admits は呼び出し側で検査する。
-/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

mutual
  def rowsTyCheck (atoms : List Atom) (ne : Nat) : Ty → Bool
    | .data _ ts | .tapp _ ts => rowsTysCheck atoms ne ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => rowsTyCheck atoms ne t
    | .fn _ ps r e => rowsTysCheck atoms ne ps && rowsTyCheck atoms ne r && rowsEffCheck atoms ne e
    | .cont a b e => rowsTyCheck atoms ne a && rowsTyCheck atoms ne b && rowsEffCheck atoms ne e
    | .map a b => rowsTyCheck atoms ne a && rowsTyCheck atoms ne b
    | _ => true
  def rowsTysCheck (atoms : List Atom) (ne : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => rowsTyCheck atoms ne t && rowsTysCheck atoms ne ts
  def rowsEffCheck (atoms : List Atom) (ne : Nat) : Eff → Bool
    | .mk a fs => atoms.all (fun x => match x with
        | .name _ => true
        | .rho i => !a (.rho i) || decide (i < ne)) && rowsTysCheck atoms ne fs
end

private theorem rowsAtoms_spec {atoms : List Atom} {a : Atom → Bool} {ne : Nat}
    (ha : ∀ x, a x = true → x ∈ atoms) :
    atoms.all (fun x => match x with
      | .name _ => true
      | .rho i => !a (.rho i) || decide (i < ne)) = true ↔
      ∀ i, a (.rho i) = true → i < ne := by
  rw [List.all_eq_true]
  constructor
  · intro h i hi
    have ht := h (.rho i) (ha _ hi)
    simpa only [hi, Bool.not_true, Bool.false_or, decide_eq_true_eq] using ht
  · intro h x _
    cases x with
    | name _ => rfl
    | rho i =>
      by_cases hi : a (.rho i) = true
      · simp [hi, h i hi]
      · simp [Bool.eq_false_iff.mpr hi]

mutual
  theorem rowsTyCheck_spec {atoms} (ne : Nat) (t : Ty) (ha : t.AtomsIn atoms) :
      rowsTyCheck atoms ne t = true ↔ t.RowsIn (· < ne) := by
    cases t <;> simp only [Ty.Support] at ha
    all_goals simp only [rowsTyCheck, Ty.RowsIn, Bool.and_eq_true]
    all_goals first | rfl | (simp; done) | exact rowsTyCheck_spec ne _ ha | exact rowsTysCheck_spec ne _ ha | skip
    case fn ns ps r e =>
      rw [rowsTysCheck_spec ne ps ha.1, rowsTyCheck_spec ne r ha.2.1, rowsEffCheck_spec ne e ha.2.2]
      exact and_assoc
    case cont a b e =>
      rw [rowsTyCheck_spec ne a ha.1, rowsTyCheck_spec ne b ha.2.1, rowsEffCheck_spec ne e ha.2.2]
      exact and_assoc
    case map a b => rw [rowsTyCheck_spec ne a ha.1, rowsTyCheck_spec ne b ha.2]
  theorem rowsTysCheck_spec {atoms} (ne : Nat) (ts : List Ty) (ha : Tys.AtomsIn atoms ts) :
      rowsTysCheck atoms ne ts = true ↔ Ty.RowsInList (· < ne) ts := by
    cases ts with
    | nil => simp [rowsTysCheck, Ty.RowsInList]
    | cons t ts =>
      simp only [rowsTysCheck, Ty.RowsInList, Bool.and_eq_true,
        rowsTyCheck_spec ne t ha.1, rowsTysCheck_spec ne ts ha.2]
  theorem rowsEffCheck_spec {atoms} (ne : Nat) (e : Eff) (ha : e.AtomsIn atoms) :
      rowsEffCheck atoms ne e = true ↔ e.RowsIn (· < ne) := by
    cases e with
    | mk a fs =>
      simp only [rowsEffCheck, Eff.RowsIn, Bool.and_eq_true,
        rowsTysCheck_spec ne fs ha.2, rowsAtoms_spec ha.1]
end

/-- 全具体化の個数・範囲・署名からの Q の移送を一度に検査する。 -/
def instantiationCheck (atoms : List Atom) (caller : List Bool) (nt ne : Nat)
    (ps : List Ty) (ret : Ty) (e : Eff) (ts : List Ty) (es : List Eff) : Bool :=
  cleanTys atoms nt ts && es.all (wfEff atoms nt) && decide (es.length = ne) &&
    rowsTysCheck atoms ne ps && rowsTyCheck atoms ne ret && rowsEffCheck atoms ne e &&
    rowTransportCheck atoms (signatureQ ne ps ret e) caller es

/-- 通常の型制約は既存の SatAll の検査から渡す。NoFail を仮定には追加しない。 -/
theorem instantiationCheck_admissible {atoms caller B C tps ne ps ret e ts es}
    (hp : Tys.AtomsIn atoms ps) (hr : ret.AtomsIn atoms) (he : e.AtomsIn atoms)
    (ht : Tys.AtomsIn atoms ts) (hes : ∀ f ∈ es, f.AtomsIn atoms)
    (hs : SatAll B C ts tps)
    (h : instantiationCheck atoms caller C.length ne ps ret e ts es = true) :
    Admissible B C tps ne (Qsig ps ret e) (NoFailCtxOf caller) ts es e := by
  simp only [instantiationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨htc, hec⟩, hn⟩, hpc⟩, hrc⟩, hec'⟩, hq⟩ := h
  have hts := (cleanTys_spec C.length ts ht).mp htc
  have hps := (rowsTysCheck_spec ne ps hp).mp hpc
  have hret := (rowsTyCheck_spec ne ret hr).mp hrc
  have heff := (rowsEffCheck_spec ne e he).mp hec'
  refine ⟨hs, ?_, hn, ?_, ?_, ?_, ?_⟩
  · intro t hm
    have hc := Ty.VarsInList.iff.mp hts t hm
    exact ⟨Ty.VarsIn.wf _ hc, by intro b r e heq; subst t; exact hc⟩
  · intro f hf
    exact ((wfEff_spec C.length f (hes f hf)).mp (List.all_eq_true.mp hec f hf)).1
  · simpa only [hn] using heff
  · simpa only [hn] using Qsig.scoped hps hret heff
  · have hrt := rowTransportCheck_sound hes hq
    intro i hi
    exact hrt i ((signatureQ_scoped hps hret heff i).mpr hi)

/-- 組み込みの型数と admits の従来の検査も保つ。 -/
theorem instantiationCheck_primitive {atoms caller C s ts es}
    (hp : Tys.AtomsIn atoms s.params) (hr : s.ret.AtomsIn atoms) (he : s.eff.AtomsIn atoms)
    (ht : Tys.AtomsIn atoms ts) (hes : ∀ f ∈ es, f.AtomsIn atoms)
    (hcount : ts.length = s.ntys) (hadmits : s.admits C ts)
    (h : instantiationCheck atoms caller C.length s.neffs s.params s.ret s.eff ts es = true) :
    PrimitiveAdmissible C s (NoFailCtxOf caller) ts es := by
  -- 型制約の表は使わず、同じ計算結果から範囲と NoFail だけを取り出す。
  simp only [instantiationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨htc, hec⟩, hn⟩, hpc⟩, hrc⟩, hec'⟩, hq⟩ := h
  have hts := (cleanTys_spec C.length ts ht).mp htc
  have hps := (rowsTysCheck_spec s.neffs s.params hp).mp hpc
  have hret := (rowsTyCheck_spec s.neffs s.ret hr).mp hrc
  have heff := (rowsEffCheck_spec s.neffs s.eff he).mp hec'
  refine ⟨hcount, hadmits, ?_, hn, ?_, ?_, ?_, ?_⟩
  · intro t hm
    have hc := Ty.VarsInList.iff.mp hts t hm
    exact ⟨Ty.VarsIn.wf _ hc, by intro b r e heq; subst t; exact hc⟩
  · intro f hf
    exact ((wfEff_spec C.length f (hes f hf)).mp (List.all_eq_true.mp hec f hf)).1
  · simpa only [hn] using heff
  · simpa only [hn] using Qsig.scoped hps hret heff
  · have hrt := rowTransportCheck_sound hes hq
    intro i hi
    exact hrt i ((signatureQ_scoped hps hret heff i).mpr hi)

/-- メソッドのクラス対象型も、通常の型引数と同じ範囲で検査する。 -/
theorem instantiationCheck_method {atoms caller C ms ss τ es}
    (hp : Tys.AtomsIn atoms ms.params) (hr : ms.ret.AtomsIn atoms) (he : ms.eff.AtomsIn atoms)
    (ht : Tys.AtomsIn atoms (ss ++ [τ])) (hes : ∀ f ∈ es, f.AtomsIn atoms)
    (h : instantiationCheck atoms caller C.length ms.neffs ms.params ms.ret ms.eff (ss ++ [τ]) es = true) :
    (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) ∧
      MethodRowsAdmissible C (NoFailCtxOf caller) ms es := by
  simp only [instantiationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨htc, hec⟩, hn⟩, hpc⟩, hrc⟩, hec'⟩, hq⟩ := h
  have hts := (cleanTys_spec C.length (ss ++ [τ]) ht).mp htc
  have hps := (rowsTysCheck_spec ms.neffs ms.params hp).mp hpc
  have hret := (rowsTyCheck_spec ms.neffs ms.ret hr).mp hrc
  have heff := (rowsEffCheck_spec ms.neffs ms.eff he).mp hec'
  refine ⟨?_, hn, ?_, ?_, ?_, ?_⟩
  · intro t hm
    have hc := Ty.VarsInList.iff.mp hts t hm
    exact ⟨Ty.VarsIn.wf _ hc, by intro b r e heq; subst t; exact hc⟩
  · intro f hf
    exact ((wfEff_spec C.length f (hes f hf)).mp (List.all_eq_true.mp hec f hf)).1
  · simpa only [hn] using heff
  · simpa only [hn] using Qsig.scoped hps hret heff
  · have hrt := rowTransportCheck_sound hes hq
    intro i hi
    exact hrt i ((signatureQ_scoped hps hret heff i).mpr hi)

end Benitoite.Surface.CheckTools
