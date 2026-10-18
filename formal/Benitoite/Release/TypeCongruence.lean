import Benitoite.Release.TypeBounds
import Benitoite.Release.TypeComposition

/-!
# 変数の範囲を用いる代入の一致

型の変数と Fail 内部の行について、実際に現れる像の正規形の一致を使う
（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

mutual
  /-- 型の像を保ち、再帰的に現れる行の像が一致すれば、型の代入結果も一致する。 -/
  theorem Ty.bind_congr_scoped (θ φ : SubstEnv) {n : Nat} (ht : ∀ i < n, (θ.types i).norm = (φ.types i).norm) (t : Ty) (hw : t.RawWF n)
      (h : t.RowsIn (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i)) :
      Ty.bind θ t = Ty.bind φ t := by
    cases t <;> simp only [Ty.RowsIn] at h <;> simp only [Ty.RawWF] at hw <;>
      simp only [Ty.bind, Ty.rawBind, Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.bind_congr_scoped θ φ ht _ hw h)
      | exact congrArg _ (Ty.bindTys_congr_scoped θ φ ht _ hw h)
      | skip
    case tapp i as =>
      apply Ty.rawApplyTo_norm_congr (ht i hw.1)
      exact Ty.bindTys_congr_scoped θ φ ht as hw.2 h
    case fn ns ps r e =>
      rw [show Ty.normTys (Ty.rawBindTys θ ps) = Ty.normTys (Ty.rawBindTys φ ps) from
        Ty.bindTys_congr_scoped θ φ ht ps hw.2.1 h.1,
        show (r.rawBind θ).norm = (r.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht r hw.2.2.1 h.2.1,
        show Eff.norm (Eff.rawBind θ e) = Eff.norm (Eff.rawBind φ e) from Eff.bind_congr_scoped θ φ ht e hw.2.2.2 h.2.2]
    case tvar i => exact ht i hw
    case cont a b e =>
      rw [show (a.rawBind θ).norm = (a.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht a hw.1 h.1,
        show (b.rawBind θ).norm = (b.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht b hw.2.1 h.2.1,
        show Eff.norm (Eff.rawBind θ e) = Eff.norm (Eff.rawBind φ e) from Eff.bind_congr_scoped θ φ ht e hw.2.2 h.2.2]
    case map a b =>
      rw [show (a.rawBind θ).norm = (a.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht a hw.1 h.1,
        show (b.rawBind θ).norm = (b.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht b hw.2 h.2]


  theorem Ty.bindTys_congr_scoped (θ φ : SubstEnv) {n : Nat} (ht : ∀ i < n, (θ.types i).norm = (φ.types i).norm) (ts : List Ty) (hw : Ty.RawWFList n ts)
      (h : Ty.RowsInList (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i) ts) :
      Ty.normTys (Ty.rawBindTys θ ts) = Ty.normTys (Ty.rawBindTys φ ts) := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [Ty.rawBindTys, Ty.normTys]
      rw [show (t.rawBind θ).norm = (t.rawBind φ).norm from Ty.bind_congr_scoped θ φ ht t hw.1 h.1,
        Ty.bindTys_congr_scoped θ φ ht ts hw.2 h.2]

  theorem Eff.bind_congr_scoped (θ φ : SubstEnv) {n : Nat} (ht : ∀ i < n, (θ.types i).norm = (φ.types i).norm) (e : Eff) (hw : Eff.RawWF n e)
      (h : Eff.RowsIn (fun i => Eff.rowImage θ.rows i = Eff.rowImage φ.rows i) e) :
      Eff.bind θ e = Eff.bind φ e := by
    cases e with
    | mk atoms fs =>
      have hfs := Ty.bindTys_congr_scoped θ φ ht fs hw h.2
      apply Eff.norm_ext
      · intro a
        rw [Eff.mem_rawBind_rowImage, Eff.mem_rawBind_rowImage]
        apply or_congr Iff.rfl
        apply exists_congr
        intro i
        apply and_congr_right
        intro hi
        rw [h.1 i hi]
      · intro t
        rw [Eff.memFail_rawBind_rowImage, Eff.memFail_rawBind_rowImage]
        apply or_congr
        · have hm := Iff.of_eq (congrArg (fun xs => t.norm ∈ xs) hfs)
          simpa only [Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.map_map,
            Function.comp_apply, List.mem_map, Eff.fails] using hm
        · apply exists_congr
          intro i
          apply and_congr_right
          intro hi
          rw [h.1 i hi]
end

/-- 型と行をそのまま保つ代入環境。 -/
def SubstEnv.identity : SubstEnv := ⟨Ty.tvar, []⟩

mutual
  theorem Ty.rawBind_identity (t : Ty) : t.rawBind SubstEnv.identity = t := by
    cases t <;> simp only [Ty.rawBind, Ty.rawBind_identity,
      Ty.rawBindTys_identity, Eff.rawBind_identity]
    all_goals rfl

  theorem Ty.rawBindTys_identity (ts : List Ty) : Ty.rawBindTys SubstEnv.identity ts = ts := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.rawBindTys, Ty.rawBind_identity, Ty.rawBindTys_identity]

  theorem Eff.rawBind_identity (e : Eff) : Eff.rawBind SubstEnv.identity e = e := by
    cases e with
    | mk a fs =>
      change EffR.mk (Eff.substAtoms [] a) (Ty.rawBindTys SubstEnv.identity fs ++ []) = _
      rw [Eff.substAtoms_nil, List.append_nil, Ty.rawBindTys_identity]
end

/-- 公開する恒等代入は、入力の正規形を返す。 -/
theorem Ty.bind_identity (t : Ty) : Ty.bind SubstEnv.identity t = t.norm := by
  rw [Ty.bind, Ty.rawBind_identity]

theorem Eff.bind_identity (e : Eff) : Eff.bind SubstEnv.identity e = Eff.norm e := by
  rw [Eff.bind, Eff.rawBind_identity]

theorem Eff.rowImage_normEnv (θ : SubstEnv) (i : Nat) :
    Eff.rowImage θ.norm.rows i = Eff.norm (Eff.rowImage θ.rows i) := by
  cases hi : θ.rows[i]? with
  | none => simp only [Eff.rowImage, SubstEnv.norm, List.getElem?_map, hi, Option.map_none, Option.getD_none]; rfl
  | some e => simp only [Eff.rowImage, SubstEnv.norm, List.getElem?_map, hi, Option.map_some, Option.getD_some]

theorem Ty.bind_normEnv (θ : SubstEnv) (t : Ty) : Ty.bind θ.norm t = Ty.bind θ t :=
  Ty.norm_rawBind_normEnv θ t

/-- 置換像自体の順序・重複を問わず、像の正規形が一致すれば代入結果が一致する。 -/
theorem Ty.bind_congr_scoped_norm (θ φ : SubstEnv) {n : Nat}
    (ht : ∀ i < n, (θ.types i).norm = (φ.types i).norm) (t : Ty) (hw : t.RawWF n)
    (hr : t.RowsIn (fun i => Eff.norm (Eff.rowImage θ.rows i) = Eff.norm (Eff.rowImage φ.rows i))) :
    Ty.bind θ t = Ty.bind φ t := by
  rw [← Ty.bind_normEnv θ, ← Ty.bind_normEnv φ]
  apply Ty.bind_congr_scoped
  · intro i hi
    change (θ.types i).norm.norm = (φ.types i).norm.norm
    rw [Ty.norm_idem, Ty.norm_idem, ht i hi]
  · exact hw
  · exact Ty.RowsIn.mono (fun i hi => by rw [Eff.rowImage_normEnv, Eff.rowImage_normEnv]; exact hi) t hr

end Benitoite.Release
